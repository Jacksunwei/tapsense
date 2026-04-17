import sys
import os
import argparse

# Add current directory to path to ensure imports work
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from preprocess import main as run_preprocess
from train import train as run_train
from convert_to_coreml import convert as run_convert

def main():
    parser = argparse.ArgumentParser(description="TapSense Training Pipeline CLI")
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Preprocess command
    preprocess_parser = subparsers.add_parser("preprocess", help="Preprocess data")
    preprocess_parser.add_argument("--file", help="Path to JSONL file to process")
    
    # Train command
    train_parser = subparsers.add_parser("train", help="Train model")
    
    # Convert command
    convert_parser = subparsers.add_parser("convert", help="Convert model to CoreML")
    
    args = parser.parse_args()
    
    if args.command == "preprocess":
        run_preprocess(args.file)
    elif args.command == "train":
        run_train()
    elif args.command == "convert":
        run_convert()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
