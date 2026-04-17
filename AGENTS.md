# TapSense AI Assistant Context

This file provides context and guidelines for AI assistants (like Antigravity) working on the TapSense project. It outlines the project's architecture, ML pipeline, and key considerations for making changes.

## Project Overview

TapSense is a project that uses a MacBook's built-in accelerometer to detect physical gestures (taps) and trigger commands in VS Code. It bridges physical interactions with editor automation.

## Core Architecture

TapSense consists of several distinct components:

1.  **VS Code Extension (`tapsense-vscode`)**: The user interface and command execution layer within VS Code.
2.  **macOS App (`tapsense-app`)**: A menu bar app that manages the lifecycle of the sidecar and handles user configuration.
3.  **Native Sidecar (`tapsense-sidecar`)**: A Swift-based daemon that reads accelerometer data, processes it, and classifies gestures.
4.  **Training Pipeline (`training-pipeline`)**: A Python-based pipeline using PyTorch to train the gesture classification models.
5.  **Data Collector (`data-collector`)**: A tool for gathering accelerometer data to train the models.

## Machine Learning Pipeline

TapSense relies on a "Trigger-then-Classify" ML architecture.

### 1. Data Collection
- Accelerometer data is sampled at a high frequency.
- The `data-collector` tool is used to record samples for different gestures.
- Data is organized in `raw_data/` and processed into `training_data/`.

### 2. Training
- The pipeline in `training-pipeline` uses PyTorch to train a 1D CNN model.
- The target sampling rate is consistently **200 Hz**.
- Models are evaluated for accuracy (target is ~96% or better).

### 3. Classification
- The trained model is converted to Core ML format.
- The Swift sidecar (`tapsense-sidecar`) uses `CoreML` and a fixed-grid `Resampler` to process incoming data and classify it using the model.

## Current Status & Critical Gotchas

- **ML Integration Reversion**: As of v0.2.1, the native sidecar ML integration was reverted due to unresolved resource loading issues with the Core ML model in the sidecar context. The codebase contains both the fallback heuristic detection and the target ML architecture. AI assistants should refer to the documented target design when working on ML integration.
- **Hardware Access**: The sidecar requires elevated privileges (admin elevation) to access the MacBook accelerometer. Automated scripts handle this.
- **Sampling Rate Consistency**: Maintain a strict 200 Hz sampling grid across data collection, training, and real-time inference.

## Guidelines for AI Assistants

When working on this codebase, adhere to the following principles:

1.  **Maintain Documentation Integrity**: Preserve existing comments and docstrings unless explicitly modifying the behavior they describe.
2.  **Verification Driven**: Do not assume code works. If testing infrastructure is available, propose running tests to verify changes.
3.  **No Placeholder Aesthetics**: If asked to create UI elements or documentation with visual elements, do not use generic placeholders.
4.  **Adhere to Framework Patterns**: Respect the distinction between the Swift sidecar, Python training scripts, and the VS Code extension. Do not introduce cross-language ad-hoc patterns.
