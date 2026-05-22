#!/usr/bin/env bash
set -euo pipefail

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_image_1024x1024.png> <output_icns_path>"
    exit 1
fi

INPUT_PNG="$1"
OUTPUT_ICNS="$2"
ICONSET_DIR="AppIcon.iconset"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_ICNS")"

# Create temporary iconset directory
mkdir -p "$ICONSET_DIR"

echo "Rescaling images to create iconset..."
# Scale PNG to standard macOS icon sizes
sips -z 16 16     "$INPUT_PNG" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$INPUT_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$INPUT_PNG" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$INPUT_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$INPUT_PNG" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$INPUT_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$INPUT_PNG" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$INPUT_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$INPUT_PNG" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$INPUT_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

echo "Converting iconset to ICNS..."
# Convert using iconutil
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Cleanup
rm -rf "$ICONSET_DIR"
echo "Success! Generated: $OUTPUT_ICNS"
