#!/bin/bash
# Run this after template download completes to install them
set -e

GODOT_VERSION="4.6.2.stable"
TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
TPZ_FILE="/tmp/godot_templates.tpz"

if [ ! -f "$TPZ_FILE" ]; then
    echo "Template file not found at $TPZ_FILE"
    echo "Download it first: curl -L https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz -o /tmp/godot_templates.tpz"
    exit 1
fi

echo "Installing templates to $TEMPLATES_DIR..."
mkdir -p "$TEMPLATES_DIR"
cd /tmp && unzip -o godot_templates.tpz
mv /tmp/templates/* "$TEMPLATES_DIR/" 2>/dev/null || cp -r /tmp/templates/. "$TEMPLATES_DIR/"
echo "Done! Templates installed."
ls "$TEMPLATES_DIR" | head -10
