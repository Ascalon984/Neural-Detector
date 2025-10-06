cmake_minimum_required(VERSION 3.10)
project(ai_text_analyzer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(TensorFlowLite REQUIRED)
find_package(nlohmann_json REQUIRED)

# Add library
add_library(text_analyzer
    src/text_analyzer.cpp
)

# Include directories
target_include_directories(text_analyzer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${TensorFlowLite_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(text_analyzer
    PRIVATE
        tensorflow-lite
        nlohmann_json::nlohmann_json
)

# Optimization flags for memory efficiency
target_compile_options(text_analyzer
    PRIVATE
        $<$<CONFIG:Release>:-O2>
)