#!/bin/bash
set -e

echo "Cleaning Flutter build artifacts..."
flutter clean

echo "Getting Flutter dependencies..."
flutter pub get

echo "Resetting CocoaPods for iOS..."
cd ios
pod deintegrate
pod install
cd ..

echo "Resetting CocoaPods for macOS..."
cd macos
pod deintegrate
pod install
cd ..

echo "Clearing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "Building for iOS..."
flutter build ios

echo "Building for macOS..."
flutter build macos

echo "Done! Now open the appropriate workspace in Xcode for each platform." 