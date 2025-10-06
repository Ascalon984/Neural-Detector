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