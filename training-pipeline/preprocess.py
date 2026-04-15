import json
import numpy as np
import os
import sys

def load_jsonl(file_path):
    """Loads data from a JSONL file."""
    data = []
    with open(file_path, 'r') as f:
        for line in f:
            try:
                data.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"Warning: Skipping invalid JSON line in {file_path}")
                continue
    return data

def load_data(file_path):
    """Loads data from a JSONL file and returns as a dict of numpy arrays."""
    print(f"Loading {file_path}...")
    data = load_jsonl(file_path)
    
    if not data:
        print("Error: No data loaded.")
        return None
    
    t = np.array([d['t'] for d in data])
    x = np.array([d['x'] for d in data])
    y = np.array([d['y'] for d in data])
    z = np.array([d['z'] for d in data])
    
    return {'t': t, 'x': x, 'y': y, 'z': z}

def resample_data(raw_data, target_fs=200):
    """Resamples accelerometer data to a target sampling rate."""
    t = raw_data['t']
    x = raw_data['x']
    y = raw_data['y']
    z = raw_data['z']
    
    # Calculate original sampling rate
    dt = np.diff(t)
    avg_dt = np.mean(dt)
    orig_fs = 1.0 / avg_dt
    print(f"Original average sampling rate: {orig_fs:.2f} Hz")
    print(f"Total raw samples: {len(t)}")
    
    # Create regular time grid at target_fs
    t_start = t[0]
    t_end = t[-1]
    num_target_samples = int((t_end - t_start) * target_fs)
    t_target = np.linspace(t_start, t_end, num_target_samples)
    
    # Interpolate
    print(f"Resampling to {target_fs} Hz...")
    x_resampled = np.interp(t_target, t, x)
    y_resampled = np.interp(t_target, t, y)
    z_resampled = np.interp(t_target, t, z)
    
    print(f"Resampled to {len(t_target)} samples.")
    
    return {
        't': t_target,
        'x': x_resampled,
        'y': y_resampled,
        'z': z_resampled
    }

def detect_peaks(raw_data, threshold=1.05, min_distance=1.5):
    """Detects peaks in the raw accelerometer magnitude."""
    x = raw_data['x']
    y = raw_data['y']
    z = raw_data['z']
    t = raw_data['t']
    
    # Calculate magnitude
    magnitude = np.sqrt(x**2 + y**2 + z**2)
    
    # Find local maxima
    is_peak = (magnitude[1:-1] > magnitude[:-2]) & (magnitude[1:-1] > magnitude[2:])
    peak_indices = np.where(is_peak)[0] + 1
    
    # Filter by threshold
    peak_indices = peak_indices[magnitude[peak_indices] > threshold]
    
    # Estimate sampling rate for min_distance
    dt = np.diff(t)
    avg_dt = np.mean(dt)
    orig_fs = 1.0 / avg_dt
    
    # Filter by minimum distance (in samples)
    min_dist_samples = int(min_distance * orig_fs)
    filtered_peaks = []
    
    for idx in peak_indices:
        if not filtered_peaks or idx - filtered_peaks[-1] >= min_dist_samples:
            filtered_peaks.append(idx)
            
    print(f"Detected {len(filtered_peaks)} peaks in raw data.")
    return np.array(filtered_peaks)
def segment_data(resampled_data, peak_times, target_fs=200, window_duration=1.0):
    """Segments resampled data into windows around peak times."""
    t_target = resampled_data['t']
    x = resampled_data['x']
    y = resampled_data['y']
    z = resampled_data['z']
    
    window_size = int(window_duration * target_fs)
    half_window = window_size // 2
    
    segments = []
    valid_peak_times = []
    
    print(f"Segmenting into {window_duration}s windows ({window_size} samples)...")
    
    for peak_t in peak_times:
        # Find closest index in resampled data
        idx = np.argmin(np.abs(t_target - peak_t))
        
        start_idx = idx - half_window
        end_idx = idx + half_window
        
        # Check bounds
        if start_idx >= 0 and end_idx <= len(t_target):
            # Extract segment
            seg_x = x[start_idx:end_idx]
            seg_y = y[start_idx:end_idx]
            seg_z = z[start_idx:end_idx]
            
            # Stack as (window_size, 3)
            segment = np.stack([seg_x, seg_y, seg_z], axis=1)
            segments.append(segment)
            valid_peak_times.append(peak_t)
            
    segments = np.array(segments)
    print(f"Successfully segmented {len(segments)} windows.")
    return segments, np.array(valid_peak_times)
def extract_noise_segments(resampled_data, peak_times, target_fs=200, window_duration=1.0):
    """Extracts segments between peaks to use as 'no tap' noise."""
    t_target = resampled_data['t']
    x = resampled_data['x']
    y = resampled_data['y']
    z = resampled_data['z']
    
    window_size = int(window_duration * target_fs)
    half_window = window_size // 2
    
    # Find indices of peaks in resampled data
    peak_indices = []
    for peak_t in peak_times:
        idx = np.argmin(np.abs(t_target - peak_t))
        peak_indices.append(idx)
    
    peak_indices = np.sort(peak_indices)
    segments = []
    
    print(f"Extracting noise segments from gaps...")
    
    # Check gap before first peak
    if len(peak_indices) > 0 and peak_indices[0] >= window_size:
        num_windows = peak_indices[0] // window_size
        for i in range(num_windows):
            start_idx = i * window_size
            end_idx = start_idx + window_size
            if start_idx >= 0 and end_idx <= len(t_target):
                segments.append(np.stack([x[start_idx:end_idx], y[start_idx:end_idx], z[start_idx:end_idx]], axis=1))
            
    # Check gaps between peaks
    for i in range(len(peak_indices) - 1):
        idx1 = peak_indices[i]
        idx2 = peak_indices[i+1]
        
        gap = idx2 - idx1
        if gap >= 2 * window_size:
            # We can fit multiple windows. Leave half window buffer on each side.
            available_gap = gap - window_size
            num_windows = available_gap // window_size
            
            for j in range(num_windows):
                start_idx = idx1 + half_window + j * window_size
                end_idx = start_idx + window_size
                if start_idx >= 0 and end_idx <= len(t_target):
                    segments.append(np.stack([x[start_idx:end_idx], y[start_idx:end_idx], z[start_idx:end_idx]], axis=1))
                
    # Check gap after last peak
    if len(peak_indices) > 0:
        last_idx = peak_indices[-1]
        gap = len(t_target) - last_idx
        if gap >= window_size:
            num_windows = gap // window_size
            for i in range(num_windows):
                start_idx = last_idx + half_window + i * window_size
                end_idx = start_idx + window_size
                if start_idx >= 0 and end_idx <= len(t_target):
                    segments.append(np.stack([x[start_idx:end_idx], y[start_idx:end_idx], z[start_idx:end_idx]], axis=1))
            
    segments = np.array(segments)
    print(f"Extracted {len(segments)} noise segments.")
    return segments

if __name__ == "__main__":
    # Default to single_taps.jsonl in the same directory
    default_file = os.path.join(os.path.dirname(__file__), "single_taps.jsonl")
    
    file_to_process = sys.argv[1] if len(sys.argv) > 1 else default_file
    
    if os.path.exists(file_to_process):
        raw_data = load_data(file_to_process)
        if raw_data:
            print("Data loaded successfully.")
            
            print("Starting Peak Detection on raw data...")
            # Lowered threshold to 1.002 as suggested by user
            peaks = detect_peaks(raw_data, threshold=1.002)
            
            t_raw = raw_data['t']
            peak_times = t_raw[peaks]
            
            print("Starting Resampling...")
            resampled_data = resample_data(raw_data)
            
            print("Starting Step 3: Segmentation (Taps)...")
            segments, valid_times = segment_data(resampled_data, peak_times)
            
            base_name = os.path.splitext(os.path.basename(file_to_process))[0]
            output_file = os.path.join(os.path.dirname(file_to_process), f"{base_name}_segments.npy")
            np.save(output_file, segments)
            print(f"Saved tap segments to {output_file}")
            
            print("Extracting Noise Segments...")
            noise_segments = extract_noise_segments(resampled_data, peak_times)
            if len(noise_segments) > 0:
                noise_output_file = os.path.join(os.path.dirname(file_to_process), f"{base_name}_noise_segments.npy")
                np.save(noise_output_file, noise_segments)
                print(f"Saved noise segments to {noise_output_file}")
                print(f"Shape of noise array: {noise_segments.shape}")
            
    else:
        print(f"File not found: {file_to_process}")
        print(f"Usage: python {sys.argv[0]} [path_to_jsonl_file]")
