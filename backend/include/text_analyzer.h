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

private:
    std::unique_ptr<tflite::FlatBufferModel> model;
    std::unique_ptr<tflite::Interpreter> interpreter;
    
    void loadModel(const std::string& model_path);
    std::vector<float> preprocessText(const std::string& text);
    AnalysisResult interpretResults(const float* output_data);
};