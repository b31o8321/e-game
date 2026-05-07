#!/usr/bin/env bash
# generate_bgm.sh — 用 ffmpeg lavfi 合成"轻柔氛围 BGM"占位音频。
# 每首 30 秒柔和和弦 + 慢速颤音，方便循环；体积都在 ~150KB 量级。
# 风格暗示：和声主和弦 + 五度叠加 + 微弱噪声床，营造梦幻氛围。
# 这是"占位 BGM"，我们自行生成 → CC0 / public domain。
set -euo pipefail

OUT="$(cd "$(dirname "$0")/.." && pwd)/src/content/english/audio/bgm"
mkdir -p "$OUT"

# Helper: synthesize 30s ambient pad from 3 sine tones (root, fifth, octave) + tremolo.
# Args: out_path, root_freq
synth() {
  local out="$1"
  local f1="$2"   # root
  local f2="$3"   # often perfect fifth
  local f3="$4"   # often octave (or third)
  local trem_hz="${5:-0.18}"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "sine=frequency=${f1}:duration=30" \
    -f lavfi -i "sine=frequency=${f2}:duration=30" \
    -f lavfi -i "sine=frequency=${f3}:duration=30" \
    -filter_complex "
      [0:a]volume=0.32[a0];
      [1:a]volume=0.20[a1];
      [2:a]volume=0.14[a2];
      [a0][a1][a2]amix=inputs=3:duration=longest[mix];
      [mix]tremolo=f=${trem_hz}:d=0.25,
           afade=t=in:st=0:d=2,afade=t=out:st=28:d=2[out]
    " -map "[out]" -ac 2 -ar 44100 -c:a libmp3lame -b:a 96k "$out"
  echo "✓ $out"
}

# 主菜单：温柔大七和弦（C–E–G–B），梦幻
synth "$OUT/main_menu.mp3" 261.63 392.00 523.25 0.16

# 知识城：F 大三和弦 + 五度（F–A–C），暖
synth "$OUT/city.mp3" 174.61 261.63 349.23 0.18

# 0F 字母厅：D 小三和弦上行（D–F–A），清亮
synth "$OUT/0f_alphabet.mp3" 146.83 220.00 293.66 0.20

# 1F 图书馆：A 小三和弦（A–C–E），神秘
synth "$OUT/1f_library.mp3" 110.00 164.81 220.00 0.14

# 2F 家庭厅：G 大三和弦（G–B–D），温馨
synth "$OUT/2f_home.mp3" 196.00 246.94 392.00 0.17

# Boss 战：D 小七和弦低音（D–F–C），紧张
synth "$OUT/boss_battle.mp3" 73.42 110.00 146.83 0.32

# 完成结算：高五度悬浮（C–G–E5），轻盈
synth "$OUT/settlement.mp3" 329.63 493.88 659.25 0.13

echo ""
echo "Total size:"
du -sh "$OUT"
