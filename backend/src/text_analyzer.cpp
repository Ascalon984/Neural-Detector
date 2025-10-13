#include "text_analyzer.h"
#include <tensorflow/lite/kernels/register.h>
#include <algorithm>
#include <stdexcept>

TextAnalyzer::TextAnalyzer() {
    loadModel("models/text_analysis_model.tflite");
}

void TextAnalyzer::loadModel(const std::string& model_path) {
    model = tflite::FlatBufferModel::BuildFromFile(model_path.c_str());
    if (!model) {
        throw std::runtime_error("Failed to load model");
    }
    
    tflite::ops::builtin::BuiltinOpResolver resolver;
    tflite::InterpreterBuilder builder(*model, resolver);
    
    if (builder(&interpreter) != kTfLiteOk || !interpreter) {
        throw std::runtime_error("Failed to build interpreter");
    }
    
    // Optimize for 3GB RAM systems
    interpreter->SetNumThreads(2);  // Limit threads for memory efficiency
    
    if (interpreter->AllocateTensors() != kTfLiteOk) {
        throw std::runtime_error("Failed to allocate tensors");
    }

    // Attempt to discover input indices (useful if model expects token ids)
    discoverInputIndices();
}

bool TextAnalyzer::loadModelFromPath(const std::string& model_path) {
    try {
        loadModel(model_path);
        return true;
    } catch (const std::exception& e) {
        // swallow and return false for callers
        return false;
    }
}

void TextAnalyzer::discoverInputIndices() {
    // Reset
    inputIdsInputIndex = -1;
    attentionMaskInputIndex = -1;
    seqLen = 0;

    if (!interpreter) return;

    // Iterate input tensors and try to infer names
    int nInputs = interpreter->inputs().size();
    for (int i = 0; i < nInputs; ++i) {
        int tensorIndex = interpreter->inputs()[i];
        const TfLiteTensor* t = interpreter->tensor(tensorIndex);
        if (!t || !t->name) continue;
        std::string name(t->name);
        // common names: "input_ids", "input_ids:0", "input_ids_input"
        if (name.find("input_ids") != std::string::npos || name.find("input") != std::string::npos) {
            inputIdsInputIndex = i;
            if (t->dims->size >= 2) seqLen = t->dims->data[1];
            continue;
        }
        if (name.find("attention_mask") != std::string::npos || name.find("attention") != std::string::npos) {
            attentionMaskInputIndex = i;
            if (seqLen == 0 && t->dims->size >= 2) seqLen = t->dims->data[1];
            continue;
        }
    }
    // If we didn't find, fall back to defaults (0 and 1)
    if (inputIdsInputIndex == -1 && interpreter->inputs().size() >= 1) inputIdsInputIndex = 0;
    if (attentionMaskInputIndex == -1 && interpreter->inputs().size() >= 2) attentionMaskInputIndex = 1;
}

TextAnalyzer::AnalysisResult TextAnalyzer::analyzeTokenIds(const std::vector<int>& input_ids, const std::vector<int>& attention_mask) {
    if (!interpreter) {
        throw std::runtime_error("Interpreter not initialized");
    }

    if (input_ids.size() != attention_mask.size()) {
        throw std::runtime_error("input_ids and attention_mask must be same length");
    }

    int len = static_cast<int>(input_ids.size());
    if (seqLen == 0) seqLen = len; // fallback
    if (len > seqLen) {
        // truncate
    }

    // Prepare input buffers
    // TFLite interop: inputs() returns tensor indices in order expected
    // We'll copy into the tensor buffers directly
    // Input ids
    int inputTensorIndex = interpreter->inputs()[inputIdsInputIndex];
    TfLiteTensor* input_tensor = interpreter->tensor(inputTensorIndex);
    if (!input_tensor) throw std::runtime_error("Failed to get input_ids tensor");

    // Determine element type; commonly int32 for token ids
    if (input_tensor->type == kTfLiteInt32) {
        int32_t* data_ptr = interpreter->typed_tensor<int32_t>(inputTensorIndex);
        // zero pad/truncate
        for (int i = 0; i < seqLen; ++i) {
            int32_t v = (i < len) ? static_cast<int32_t>(input_ids[i]) : 0;
            data_ptr[i] = v;
        }
    } else if (input_tensor->type == kTfLiteInt16) {
        int16_t* data_ptr = interpreter->typed_tensor<int16_t>(inputTensorIndex);
        for (int i = 0; i < seqLen; ++i) {
            int16_t v = (i < len) ? static_cast<int16_t>(input_ids[i]) : 0;
            data_ptr[i] = v;
        }
    } else {
        throw std::runtime_error("Unsupported input_ids tensor type");
    }

    // Attention mask
    int maskTensorIndex = interpreter->inputs()[attentionMaskInputIndex];
    TfLiteTensor* mask_tensor = interpreter->tensor(maskTensorIndex);
    if (!mask_tensor) throw std::runtime_error("Failed to get attention_mask tensor");

    if (mask_tensor->type == kTfLiteInt32) {
        int32_t* mask_ptr = interpreter->typed_tensor<int32_t>(maskTensorIndex);
        for (int i = 0; i < seqLen; ++i) {
            int32_t v = (i < len) ? static_cast<int32_t>(attention_mask[i]) : 0;
            mask_ptr[i] = v;
        }
    } else if (mask_tensor->type == kTfLiteUInt8) {
        uint8_t* mask_ptr = interpreter->typed_tensor<uint8_t>(maskTensorIndex);
        for (int i = 0; i < seqLen; ++i) {
            uint8_t v = (i < len) ? static_cast<uint8_t>(attention_mask[i]) : 0;
            mask_ptr[i] = v;
        }
    } else {
        throw std::runtime_error("Unsupported attention_mask tensor type");
    }

    if (interpreter->Invoke() != kTfLiteOk) {
        throw std::runtime_error("Failed to invoke interpreter");
    }

    // Assuming first output is float logits/prob
    float* output = interpreter->typed_output_tensor<float>(0);
    if (!output) throw std::runtime_error("Failed to get output tensor");

    return interpretResults(output);
}

TextAnalyzer::AnalysisResult TextAnalyzer::analyzeText(const std::string& text) {
    auto input_data = preprocessText(text);
    
    float* input_tensor = interpreter->typed_input_tensor<float>(0);
    if (!input_tensor) {
        throw std::runtime_error("Failed to get input tensor");
    }
    
    std::copy(input_data.begin(), input_data.end(), input_tensor);
    
    if (interpreter->Invoke() != kTfLiteOk) {
        throw std::runtime_error("Failed to invoke interpreter");
    }
    
    float* output = interpreter->typed_output_tensor<float>(0);
    if (!output) {
        throw std::runtime_error("Failed to get output tensor");
    }
    
    return interpretResults(output);
}

std::vector<float> TextAnalyzer::preprocessText(const std::string& text) {
    std::vector<float> processed;
    processed.reserve(512); // Preallocate for efficiency
    
    // Simple character-level vectorization
    for (char c : text) {
        processed.push_back(static_cast<float>(c) / 255.0f);
    }
    
    // Pad or truncate to fixed length
    processed.resize(512, 0.0f);
    return processed;
}

TextAnalyzer::AnalysisResult TextAnalyzer::interpretResults(const float* output_data) {
    // Ensure probabilities sum to 1
    float ai_prob = std::max(0.0f, std::min(1.0f, output_data[0]));
    float human_prob = 1.0f - ai_prob;
    
    return AnalysisResult{
        .ai_probability = ai_prob,
        .human_probability = human_prob
    };
}