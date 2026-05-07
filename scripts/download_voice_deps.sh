#!/bin/bash
# 下载 Piper TTS + whisper.cpp 二进制 + 模型，置入 builds/voice/
# Usage: bash scripts/download_voice_deps.sh
set -e

cd "$(dirname "$0")/.."
mkdir -p builds/voice/piper/models builds/voice/whisper/models

# Detect arch
ARCH=$(uname -m)
case "$ARCH" in
    arm64) ARCH_STR="aarch64" ;;
    x86_64) ARCH_STR="x86_64" ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

echo "Detected architecture: $ARCH ($ARCH_STR)"

# ────────────────────────────────────────────────────────────────
# Piper TTS
# ────────────────────────────────────────────────────────────────
PIPER_VERSION="2023.11.14-2"
if [ ! -f builds/voice/piper/piper ]; then
    echo "→ Downloading Piper $PIPER_VERSION ($ARCH_STR)..."
    PIPER_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_macos_${ARCH_STR}.tar.gz"
    if curl -fL "$PIPER_URL" -o /tmp/piper.tar.gz 2>&1; then
        tar xzf /tmp/piper.tar.gz -C builds/voice/
        chmod +x builds/voice/piper/piper
        rm -f /tmp/piper.tar.gz
        echo "  ✓ Piper installed"
    else
        echo "  ✗ Failed to download Piper from $PIPER_URL"
        echo "  → Manual install: download from https://github.com/rhasspy/piper/releases"
    fi
else
    echo "✓ Piper already installed (skipping)"
fi

# ────────────────────────────────────────────────────────────────
# Piper en_US-lessac-medium model
# ────────────────────────────────────────────────────────────────
PIPER_MODEL_DIR="builds/voice/piper/models"
if [ ! -f "$PIPER_MODEL_DIR/en_US-lessac-medium.onnx" ]; then
    echo "→ Downloading Piper model en_US-lessac-medium..."
    BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium"
    curl -fL "$BASE/en_US-lessac-medium.onnx" \
         -o "$PIPER_MODEL_DIR/en_US-lessac-medium.onnx" || {
        echo "  ✗ Failed model download"
    }
    curl -fL "$BASE/en_US-lessac-medium.onnx.json" \
         -o "$PIPER_MODEL_DIR/en_US-lessac-medium.onnx.json" || {
        echo "  ✗ Failed model.json download"
    }
    echo "  ✓ Piper model installed"
else
    echo "✓ Piper model already installed"
fi

# ────────────────────────────────────────────────────────────────
# whisper.cpp
# ────────────────────────────────────────────────────────────────
WHISPER_DIR="builds/voice/whisper"
if [ ! -f "$WHISPER_DIR/whisper-cli" ]; then
    echo "→ Building whisper.cpp from source (no prebuilt mac available)..."
    if [ ! -d /tmp/whisper.cpp ]; then
        git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp
    fi
    (
        cd /tmp/whisper.cpp
        # Build the main / whisper-cli binary using makefile
        make clean 2>/dev/null || true
        make -j$(sysctl -n hw.ncpu) 2>&1 | tail -5
    )
    # whisper.cpp builds to ./main; recent versions also produce ./build/bin/whisper-cli
    if [ -f /tmp/whisper.cpp/build/bin/whisper-cli ]; then
        cp /tmp/whisper.cpp/build/bin/whisper-cli "$WHISPER_DIR/whisper-cli"
    elif [ -f /tmp/whisper.cpp/main ]; then
        cp /tmp/whisper.cpp/main "$WHISPER_DIR/whisper-cli"
    else
        echo "  ✗ whisper.cpp build did not produce expected binary"
        exit 1
    fi
    chmod +x "$WHISPER_DIR/whisper-cli"
    echo "  ✓ whisper.cpp installed"
else
    echo "✓ whisper.cpp already installed"
fi

# ────────────────────────────────────────────────────────────────
# Whisper tiny.en model
# ────────────────────────────────────────────────────────────────
WHISPER_MODEL_DIR="$WHISPER_DIR/models"
if [ ! -f "$WHISPER_MODEL_DIR/ggml-tiny.en.bin" ]; then
    echo "→ Downloading Whisper tiny.en model..."
    curl -fL "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin" \
         -o "$WHISPER_MODEL_DIR/ggml-tiny.en.bin"
    echo "  ✓ Whisper model installed"
else
    echo "✓ Whisper model already installed"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "Voice deps ready in builds/voice/"
echo ""
ls -la builds/voice/piper/ 2>/dev/null
echo ""
ls -la builds/voice/whisper/ 2>/dev/null
