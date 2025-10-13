#pragma once
#include <tensorflow/lite/interpreter.h>
#include <tensorflow/lite/model.h>
#include <nlohmann/json.hpp>
#include <string>
#include <memory>
#include <vector>

class TextAnalyzer {
public:
    struct AnalysisResult {
        float ai_probability;
        float human_probability;
        nlohmann::json toJson() const {
            return {
                {"ai_detection", ai_probability * 100},
                {"human_written", human_probability * 100}
            };
        }
    };

    TextAnalyzer();
    ~TextAnalyzer() = default;
    
    AnalysisResult analyzeText(const std::string& text);
    // Load a specific tflite model at runtime (e.g. MiniLM int8) and reinitialize interpreter.
    bool loadModelFromPath(const std::string& model_path);

    // Analyze pre-tokenized input. input_ids and attention_mask must be length==seq_len.
    AnalysisResult analyzeTokenIds(const std::vector<int>& input_ids, const std::vector<int>& attention_mask);

private:
    std::unique_ptr<tflite::FlatBufferModel> model;
    std::unique_ptr<tflite::Interpreter> interpreter;
    // cached mapping of input positions in the interpreter's input list
    int inputIdsInputIndex = -1;
    int attentionMaskInputIndex = -1;
    int seqLen = 0;
    
    void loadModel(const std::string& model_path);
    std::vector<float> preprocessText(const std::string& text);
    AnalysisResult interpretResults(const float* output_data);
    // Helper to discover input tensor positions by name
    void discoverInputIndices();
};