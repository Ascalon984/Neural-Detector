#include "text_analyzer.h"
#include <cstring>

extern "C" {

struct CAnalysisResult {
    double aiProbability;
    double humanProbability;
};

// Singleton analyzer
static TextAnalyzer* g_analyzer = nullptr;

// Initialize analyzer (loads default model)
void initialize_analyzer() {
    if (!g_analyzer) {
        g_analyzer = new TextAnalyzer();
    }
}

// Analyze a UTF-8 string. Returns a CAnalysisResult by value.
CAnalysisResult analyzeText(const char* text) {
    if (!g_analyzer) initialize_analyzer();
    if (!g_analyzer) return {0.0, 1.0};
    try {
        auto res = g_analyzer->analyzeText(std::string(text ? text : ""));
        return {static_cast<double>(res.ai_probability), static_cast<double>(res.human_probability)};
    } catch (...) {
        return {0.0, 1.0};
    }
}

// Load model at runtime. Returns 1 on success, 0 on failure.
int loadModelFromPath(const char* path) {
    if (!g_analyzer) initialize_analyzer();
    if (!g_analyzer) return 0;
    try {
        return g_analyzer->loadModelFromPath(std::string(path ? path : "")) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

// Analyze token ids. ids and mask point to int32 arrays of length len.
CAnalysisResult analyzeTokenIds(const int* ids, const int* mask, int len) {
    if (!g_analyzer) initialize_analyzer();
    if (!g_analyzer) return {0.0, 1.0};
    try {
        std::vector<int> v_ids(ids, ids + len);
        std::vector<int> v_mask(mask, mask + len);
        auto res = g_analyzer->analyzeTokenIds(v_ids, v_mask);
        return {static_cast<double>(res.ai_probability), static_cast<double>(res.human_probability)};
    } catch (...) {
        return {0.0, 1.0};
    }
}

} // extern "C"
