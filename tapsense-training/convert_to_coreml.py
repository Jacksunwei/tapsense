import os
import torch
import coremltools as ct
from train import TapCNN

def convert():
    base_dir = os.path.dirname(__file__)
    data_dir = os.path.join(os.path.dirname(base_dir), "tapsense-data")
    model_path = os.path.join(data_dir, "models", "tap_model_best.pth")
    
    if not os.path.exists(model_path):
        print(f"Model file not found: {model_path}")
        return
        
    # Load model
    model = TapCNN()
    model.load_state_dict(torch.load(model_path))
    model.eval()
    
    # Create dummy input (batch_size=1, channels=3, sequence_length=200)
    dummy_input = torch.randn(1, 3, 200)
    
    # Trace the model
    traced_model = torch.jit.trace(model, dummy_input)
    
    # Convert to CoreML
    print("Converting to CoreML...")
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="input", shape=dummy_input.shape)],
        classifier_config=ct.ClassifierConfig(["no_tap", "single_tap", "double_tap"])
    )
    
    # Save as .mlpackage (modern format)
    output_path = os.path.join(data_dir, "models", "tap_model.mlpackage")
    coreml_model.save(output_path)
    print(f"Saved CoreML model to {output_path}")

if __name__ == "__main__":
    convert()
