import os
import numpy as np
import torch
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
    
    # Load data
    single_taps = np.load(os.path.join(base_dir, "single_taps_segments.npy"))
    double_taps = np.load(os.path.join(base_dir, "double_taps_segments.npy"))
    single_noise = np.load(os.path.join(base_dir, "single_taps_noise_segments.npy"))
    double_noise = np.load(os.path.join(base_dir, "double_taps_noise_segments.npy"))
    dedicated_noise = np.load(os.path.join(base_dir, "noise_noise_segments.npy"))
    
    noise = np.concatenate([single_noise, double_noise, dedicated_noise], axis=0)
    
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

if __name__ == "__main__":
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
        print(f"Epoch {epoch+1}/{num_epochs}: Loss: {epoch_loss:.4f} | Acc: {epoch_acc:.2f}%")
        
    print("Training complete.")
    
    # Evaluate on test set
    model.eval()
    test_loss = 0.0
    correct = 0
    total = 0
    
    with torch.no_grad():
        for inputs, targets in test_loader:
            inputs, targets = inputs.to(device), targets.to(device)
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            
            test_loss += loss.item()
            _, predicted = outputs.max(1)
            total += targets.size(0)
            correct += predicted.eq(targets).sum().item()
            
    test_loss /= len(test_loader)
    test_acc = 100. * correct / total
    print(f"Test Loss: {test_loss:.4f} | Test Acc: {test_acc:.2f}%")
    
    # Save model
    model_path = os.path.join(os.path.dirname(__file__), "tap_model.pth")
    torch.save(model.state_dict(), model_path)
    print(f"Saved model to {model_path}")
