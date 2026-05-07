#!/bin/bash
# Generate TTS audio for all English vocabulary cards using macOS `say` + ffmpeg.
# Single-letter cards (A-Z) go to audio/letters/, words/phrases go to audio/words/.
set -e
cd "$(dirname "$0")/.."

VOICE="${VOICE:-Karen}"   # Australian female; alternatives: Samantha (US), Daniel (UK)
WORDS_DIR="src/content/english/audio/words"
LETTERS_DIR="src/content/english/audio/letters"
mkdir -p "$WORDS_DIR" "$LETTERS_DIR"

GENERATED=0
SKIPPED=0
TMPAIFF="$(mktemp -t zhishi_tts_XXXX).aiff"
trap "rm -f \"$TMPAIFF\"" EXIT

while IFS= read -r word; do
    [ -z "$word" ] && continue

    # Single-letter (A-Z, a-z) → letters dir; otherwise words dir
    if [[ "$word" =~ ^[A-Za-z]$ ]]; then
        TARGET_DIR="$LETTERS_DIR"
        # Lowercase for filename consistency
        FNAME="$(echo "$word" | tr '[:upper:]' '[:lower:]').mp3"
    else
        TARGET_DIR="$WORDS_DIR"
        FNAME="$(echo "$word" | tr '[:upper:] ' '[:lower:]_').mp3"
    fi

    OUTFILE="$TARGET_DIR/$FNAME"
    if [ -f "$OUTFILE" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    /usr/bin/say -v "$VOICE" -o "$TMPAIFF" "$word"
    /opt/homebrew/bin/ffmpeg -hide_banner -loglevel error -y -i "$TMPAIFF" -c:a libmp3lame -q:a 4 "$OUTFILE"
    GENERATED=$((GENERATED + 1))
done < /tmp/words_to_tts.txt

echo "TTS done: generated=$GENERATED skipped=$SKIPPED"
