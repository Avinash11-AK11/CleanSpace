#!/bin/bash
set -e

echo "=== CleanSpace Release / TestFlight Archive Tool ==="

# 1. Regenerate Xcode project
echo "Step 1: Generating Xcode project with XcodeGen..."
xcodegen generate

# 2. Archive target CleanSpace
ARCHIVE_PATH="./build_derived/CleanSpace.xcarchive"
echo "Step 2: Archiving CleanSpace to $ARCHIVE_PATH..."

xcodebuild archive \
  -project CleanSpace.xcodeproj \
  -scheme CleanSpace \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  SWIFT_VERSION=5.9

echo "=== Archive Successfully Created at $ARCHIVE_PATH ==="
echo "To distribute to TestFlight, configure an Apple Developer Team ID and run:"
echo "xcodebuild -exportArchive -archivePath $ARCHIVE_PATH -exportPath ./build_derived/Export -exportOptionsPlist ExportOptions.plist"
