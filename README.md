# streakfreak

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Fixing macOS Code-Sign Error: Stripping Extended Attributes

If you encounter the error:

    resource fork, Finder information, or similar detritus not allowed
    Command CodeSign failed with a nonzero exit code

when building the macOS Runner target, follow these steps to fix it:

### 1. Open the Project in Xcode
- Open `macos/Runner.xcworkspace` in Xcode.

### 2. Add a Run Script Phase
- Select the **Runner (macOS)** target.
- Go to the **Build Phases** tab.
- Click the **+** button and choose **New Run Script Phase**.
- Name it: `Strip extended attributes`.
- Drag it so to the bottom
- Code:
  - if [ -r "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" ]; then
      "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
    fi

### 3. Input and Output Files
- **Input File Lists:**
  - `$(SRCROOT)/Flutter/ephemeral/FlutterInputs.xcfilelist`
- **Output Files:**
  - `$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME.cleaned`

### 4. Uncheck "Based on dependency analysis"
- Uncheck the box labeled **Based on dependency analysis** to ensure the script runs every build.

### 5. Clean and Rebuild
In your terminal, run:

```sh
flutter clean
flutter pub get
flutter run -d macos
```

This will ensure the build finishes without the extended-attributes code-sign error on macOS.
