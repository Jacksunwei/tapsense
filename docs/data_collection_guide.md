# Data Collection Guide for TapSense ML

This guide explains how to collect labeled accelerometer data to train the machine learning model for tap detection.

## 📋 Prerequisites

1.  **Build the Data Collector**: Make sure you have built the `data-collector` tool.
    ```bash
    cd data-collector
    swift build
    ```
2.  **Root Privileges**: You must run the collector with `sudo` to access the MacBook's internal accelerometer.

---

## 🛑 Important Tips Before You Start

*   **Wait between gestures**: Wait at least **2 seconds** between each tap gesture. This makes it much easier for the preprocessing script to segment the data later.
*   **Pace Feedback**: The CLI will count your taps and provide feedback (e.g., "Too fast", "Good pace") to help you maintain the 2-second interval!
*   **Be consistent**: Try to perform the gestures as you would naturally when using the app.
*   **Save your data**: You must press **Ctrl+C** to stop the recording and ensure the file is properly closed.

---

## 🛠 Step-by-Step Collection Protocol

We need to collect data for 5 different categories. All data files will be saved in the `training-pipeline` folder.

From the project root, run the following commands:

### 1. Collect Single Taps
Record single taps on the palm rest.
```bash
sudo ./data-collector/.build/debug/data-collector ./training-pipeline/single_taps.jsonl
```
*   **Action**: Perform about **300 single taps** on the palm rest.
*   **Interval**: Wait 2 seconds between taps.
*   **Stop**: Press `Ctrl+C` when done.

### 2. Collect Double Taps
Record double taps on the palm rest.
```bash
sudo ./data-collector/.build/debug/data-collector ./training-pipeline/double_taps.jsonl
```
*   **Action**: Perform about **300 double taps** on the palm rest.
*   **Interval**: Wait 2 seconds between each double tap.
*   **Stop**: Press `Ctrl+C` when done.

### 3. Collect Triple Taps
Record triple taps on the palm rest.
```bash
sudo ./data-collector/.build/debug/data-collector ./training-pipeline/triple_taps.jsonl
```
*   **Action**: Perform about **300 triple taps** on the palm rest.
*   **Interval**: Wait 2 seconds between each triple tap.
*   **Stop**: Press `Ctrl+C` when done.

### 4. Collect Desk Taps (Supported Mode)
Record taps on the desk surface near the laptop (useful for when using an external keyboard).
```bash
sudo ./data-collector/.build/debug/data-collector ./training-pipeline/desk_taps.jsonl
```
*   **Action**: Perform about **300 taps** (mix of single, double, triple if you want to support all) on the desk surface near the laptop.
*   **Interval**: Wait 2 seconds between gestures.
*   **Stop**: Press `Ctrl+C` when done.

### 5. Collect General Noise
Record normal activities to teach the model what *not* to trigger on.
```bash
sudo ./data-collector/.build/debug/data-collector ./training-pipeline/noise.jsonl
```
*   **Action**: Perform normal activities for 3 to 5 minutes:
    *   Type normally on the keyboard.
    *   Rest your palms heavily on the palm rest.
    *   Move the laptop slightly on the desk.
    *   Bump the table gently.
*   **Stop**: Press `Ctrl+C` when done.

---

## ⏭ Next Steps
After collecting these 5 files, we will use a Python script in the `training-pipeline` folder to:
1.  Load this raw data.
2.  Segment it into 1-second windows.
3.  Resample it to 200 Hz.
4.  Train the CNN model.
