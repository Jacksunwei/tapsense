import os
import numpy as np
import torch
import glob
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split

class TapDataset(Dataset):
    def __init__(self, data, labels):
        self.data = torch.from_numpy(data).float()
        self.labels = torch.from_numpy(labels).long()
        
        # PyTorch CNNs expect (channels, sequence_length)
        # Our data is (num_samples, sequence_length, channels) -> (num_samples, 200, 3)
        # We need to permute to (num_samples, 3, 200)
        self.data = self.data.permute(0, 2, 1)
        
    def __len__(self):
        return len(self.data)
        
    def __getitem__(self, idx):
        return self.data[idx], self.labels[idx]

def load_dataset():
    base_dir = os.path.dirname(__file__)
    
    processed_dir = os.path.join(os.path.dirname(base_dir), "tapsense-data", "processed")
    
    single_taps_list = []
    double_taps_list = []
    noise_list = []
    
    # Find all matching files
    for f in glob.glob(os.path.join(processed_dir, "*_segments.npy")):
        if "noise" in f:
            noise_list.append(np.load(f))
        elif "double" in f:
            double_taps_list.append(np.load(f))
        elif "single" in f:
            single_taps_list.append(np.load(f))
            
    # Concatenate lists into arrays
    single_taps = np.concatenate(single_taps_list, axis=0) if single_taps_list else np.zeros((0, 200, 3))
    double_taps = np.concatenate(double_taps_list, axis=0) if double_taps_list else np.zeros((0, 200, 3))
    noise = np.concatenate(noise_list, axis=0) if noise_list else np.zeros((0, 200, 3))
    
    print(f"Loaded {len(single_taps)} single taps.")
    print(f"Loaded {len(double_taps)} double taps.")
    print(f"Loaded {len(noise)} noise samples.")
    
    # Create labels
    # 0: No Tap, 1: Single Tap, 2: Double Tap
    y_noise = np.zeros(len(noise))
    y_single = np.ones(len(single_taps))
    y_double = np.ones(len(double_taps)) * 2
    
    # Combine
    X = np.concatenate([noise, single_taps, double_taps], axis=0)
    y = np.concatenate([y_noise, y_single, y_double], axis=0)
    
    return X, y

import torch.nn as nn
import torch.nn.functional as F

class TapCNN(nn.Module):
    def __init__(self, num_classes=3):
        super(TapCNN, self).__init__()
        self.conv1 = nn.Conv1d(in_channels=3, out_channels=16, kernel_size=5, stride=1, padding=2)
        self.pool1 = nn.MaxPool1d(kernel_size=2, stride=2)
        
        self.conv2 = nn.Conv1d(in_channels=16, out_channels=32, kernel_size=5, stride=1, padding=2)
        self.pool2 = nn.MaxPool1d(kernel_size=2, stride=2)
        
        self.conv3 = nn.Conv1d(in_channels=32, out_channels=64, kernel_size=3, stride=1, padding=1)
        self.pool3 = nn.MaxPool1d(kernel_size=2, stride=2)
        
        # After 3 pools of size 2, sequence length goes from 200 -> 100 -> 50 -> 25
        self.fc1 = nn.Linear(64 * 25, 128)
        self.fc2 = nn.Linear(128, num_classes)
        
    def forward(self, x):
        x = self.pool1(F.relu(self.conv1(x)))
        x = self.pool2(F.relu(self.conv2(x)))
        x = self.pool3(F.relu(self.conv3(x)))
        
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return x

def train():
    X, y = load_dataset()
    
    # Split into train and test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    print(f"Train set size: {len(X_train)}")
    print(f"Test set size: {len(X_test)}")
    
    # Create datasets
    train_dataset = TapDataset(X_train, y_train)
    test_dataset = TapDataset(X_test, y_test)
    
    # Create dataloaders
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False)
    
    # Check a batch
    data, labels = next(iter(train_loader))
    print(f"Batch data shape: {data.shape}")  # Should be (32, 3, 200)
    print(f"Batch labels shape: {labels.shape}")
    
    # Test model
    model = TapCNN()
    output = model(data)
    print(f"Model output shape: {output.shape}")  # Should be (32, 3)
    
    # Training setup
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    
    num_epochs = 50
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    
    print(f"Training on {device}...")
    
    best_acc = 0.0
    models_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "tapsense-data", "models")
    os.makedirs(models_dir, exist_ok=True)
    
    for epoch in range(num_epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        
        for batch_idx, (inputs, targets) in enumerate(train_loader):
            inputs, targets = inputs.to(device), targets.to(device)
            
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            _, predicted = outputs.max(1)
            total += targets.size(0)
            correct += predicted.eq(targets).sum().item()
            
        epoch_loss = running_loss / len(train_loader)
        epoch_acc = 100. * correct / total
        
        # Evaluate on test set per epoch
        model.eval()
        test_loss = 0.0
        test_correct = 0
        test_total = 0
        
        with torch.no_grad():
            for inputs, targets in test_loader:
                inputs, targets = inputs.to(device), targets.to(device)
                outputs = model(inputs)
                loss = criterion(outputs, targets)
                
                test_loss += loss.item()
                _, predicted = outputs.max(1)
                test_total += targets.size(0)
                test_correct += predicted.eq(targets).sum().item()
                
        test_loss /= len(test_loader)
        test_acc = 100. * test_correct / test_total
        
        print(f"Epoch {epoch+1}/{num_epochs}: Loss: {epoch_loss:.4f} | Acc: {epoch_acc:.2f}% | Test Loss: {test_loss:.4f} | Test Acc: {test_acc:.2f}%")
        
        # Save best model
        if test_acc > best_acc:
            best_acc = test_acc
            best_model_path = os.path.join(models_dir, "tap_model_best.pth")
            torch.save(model.state_dict(), best_model_path)
            print(f"  --> Saved best model with Test Acc: {best_acc:.2f}%")
            
        # Save periodic checkpoint
        if (epoch + 1) % 10 == 0:
            checkpoint_path = os.path.join(models_dir, f"tap_model_epoch_{epoch+1}.pth")
            torch.save(model.state_dict(), checkpoint_path)
            print(f"  --> Saved periodic checkpoint to {checkpoint_path}")
        
    print("Training complete.")
    
    # Load best model for final evaluation
    best_model_path = os.path.join(models_dir, "tap_model_best.pth")
    if os.path.exists(best_model_path):
        model.load_state_dict(torch.load(best_model_path))
        print(f"Loaded best model from {best_model_path} for final evaluation.")
    
    # Final evaluation for classification report
    model.eval()
    all_targets = []
    all_predicted = []
    
    with torch.no_grad():
        for inputs, targets in test_loader:
            inputs, targets = inputs.to(device), targets.to(device)
            outputs = model(inputs)
            _, predicted = outputs.max(1)
            
            all_targets.extend(targets.cpu().numpy())
            all_predicted.extend(predicted.cpu().numpy())
            
    from sklearn.metrics import classification_report
    print("\nFinal Classification Report (on BEST model):")
    print(classification_report(all_targets, all_predicted, target_names=["no_tap", "single_tap", "double_tap"]))
    
    # Save final model (we still save the state after loop as final)
    final_model_path = os.path.join(models_dir, "tap_model.pth")
    torch.save(model.state_dict(), final_model_path)
    print(f"Saved final model to {final_model_path}")
