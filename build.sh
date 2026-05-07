#!/bin/bash
# 知识神塔 Build Script
# Usage: ./build.sh [mac|win|android|all]

set -e

GODOT="/opt/homebrew/bin/godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TARGET="${1:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_godot() {
    if ! command -v "$GODOT" &>/dev/null; then
        echo -e "${RED}Error: Godot not found at $GODOT${NC}"
        echo "Install with: brew install --cask godot"
        exit 1
    fi
    echo -e "${GREEN}Godot: $($GODOT --version)${NC}"
}

check_templates() {
    TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates"
    if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls -A "$TEMPLATES_DIR" 2>/dev/null)" ]; then
        echo -e "${RED}Error: Export templates not installed.${NC}"
        echo "Run: open /Applications/Godot.app → Editor → Manage Export Templates → Download"
        echo "Or wait for background template download to finish and run: ./install_templates.sh"
        exit 1
    fi
}

ensure_voice_deps() {
    if [ ! -f "$PROJECT_DIR/builds/voice/piper/piper" ] || \
       [ ! -f "$PROJECT_DIR/builds/voice/whisper/whisper-cli" ] || \
       [ ! -f "$PROJECT_DIR/builds/voice/piper/models/en_US-lessac-medium.onnx" ] || \
       [ ! -f "$PROJECT_DIR/builds/voice/whisper/models/ggml-tiny.en.bin" ]; then
        echo -e "${YELLOW}Voice deps missing — invoking download_voice_deps.sh${NC}"
        bash "$PROJECT_DIR/scripts/download_voice_deps.sh"
    fi
}

export_mac() {
    echo -e "${YELLOW}Building macOS...${NC}"
    ensure_voice_deps
    mkdir -p "$PROJECT_DIR/builds/mac"

    # Step 1: Godot exports a raw DMG (no Applications shortcut)
    local RAW_DMG="$PROJECT_DIR/builds/mac/_raw.dmg"
    local FINAL_DMG="$PROJECT_DIR/builds/mac/知识神塔.dmg"
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "macOS" "$RAW_DMG" 2>&1

    # Step 2: Extract .app from raw DMG
    local MOUNT_PT="/tmp/zhishi_mount_$$"
    local STAGING="/tmp/zhishi_staging_$$"
    mkdir -p "$MOUNT_PT" "$STAGING"
    hdiutil attach "$RAW_DMG" -nobrowse -quiet -mountpoint "$MOUNT_PT"
    cp -R "$MOUNT_PT/知识神塔.app" "$STAGING/"
    hdiutil detach "$MOUNT_PT" -quiet

    # Step 3: Embed voice resources (piper + whisper binaries and models) into .app
    local APP_DIR="$STAGING/知识神塔.app"
    if [ -d "$APP_DIR/Contents" ]; then
        echo -e "${YELLOW}Embedding voice resources into .app...${NC}"
        mkdir -p "$APP_DIR/Contents/Resources/voice"
        if [ -d "$PROJECT_DIR/builds/voice/piper" ]; then
            cp -R "$PROJECT_DIR/builds/voice/piper" "$APP_DIR/Contents/Resources/voice/"
        fi
        if [ -d "$PROJECT_DIR/builds/voice/whisper" ]; then
            cp -R "$PROJECT_DIR/builds/voice/whisper" "$APP_DIR/Contents/Resources/voice/"
        fi
        # Re-set executable bits (cp may strip them)
        chmod +x "$APP_DIR/Contents/Resources/voice/piper/piper" 2>/dev/null || true
        chmod +x "$APP_DIR/Contents/Resources/voice/whisper/whisper-cli" 2>/dev/null || true
    fi

    # Step 4: Add Applications symlink and repack as proper installer DMG
    ln -s /Applications "$STAGING/Applications"
    local RW_DMG="/tmp/zhishi_rw_$$.dmg"
    hdiutil create -srcfolder "$STAGING" -volname "知识神塔" -fs HFS+ -format UDRW -size 250m "$RW_DMG" -quiet
    rm -f "$FINAL_DMG"
    hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet

    # Cleanup
    rm -f "$RAW_DMG" "$RW_DMG"
    rm -rf "$MOUNT_PT" "$STAGING"

    echo -e "${GREEN}macOS build: builds/mac/知识神塔.dmg (带 Applications 快捷方式)${NC}"
}

export_win() {
    echo -e "${YELLOW}Building Windows...${NC}"
    mkdir -p "$PROJECT_DIR/builds/win"
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "Windows Desktop" \
        "$PROJECT_DIR/builds/win/知识神塔.exe" 2>&1
    echo -e "${GREEN}Windows build: builds/win/知识神塔.exe${NC}"
}

export_android() {
    echo -e "${YELLOW}Building Android...${NC}"
    if [ -z "$ANDROID_HOME" ] && [ ! -d "$HOME/Library/Android/sdk" ]; then
        echo -e "${RED}Error: Android SDK not found.${NC}"
        echo "Install Android Studio: https://developer.android.com/studio"
        echo "Or: brew install --cask android-studio"
        exit 1
    fi
    mkdir -p "$PROJECT_DIR/builds/android"
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "Android" \
        "$PROJECT_DIR/builds/android/知识神塔.apk" 2>&1
    echo -e "${GREEN}Android build: builds/android/知识神塔.apk${NC}"
}

check_godot
check_templates

case "$BUILD_TARGET" in
    mac)     export_mac ;;
    win)     export_win ;;
    android) export_android ;;
    all)
        export_mac
        export_win
        export_android
        ;;
    *)
        echo "Usage: $0 [mac|win|android|all]"
        exit 1
        ;;
esac

echo -e "${GREEN}Done!${NC}"
