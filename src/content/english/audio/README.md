# 英语内容包占位音频目录

此目录承载 `cards.json` / `challenges.json` 引用的发音 / 听写音频。

## 目录约定

```
audio/
├── words/
│   └── <word>.ogg      # 单词朗读, e.g. cat.ogg / brave.ogg
├── letters/
│   └── <letter>.ogg    # 字母朗读, e.g. b.ogg / k.ogg
└── README.md
```

## 缺失文件时的行为

引擎已在以下路径做了"静默兜底"：

| 调用点 | 缺失文件时 |
|--------|------------|
| `dictation_ui._play_audio` | 显示"音频缺失，请直接拼写"，不报错 |
| `cutscene_scene._apply_audio` | `push_warning` + 不切 BGM / 不播 SFX |
| `voice_scroll_ui` | 录音不依赖资源音频，自身用麦克风 |

## 后续接入 TTS 流程（建议）

1. **macOS 本地 TTS（开发期最快）**：
   ```bash
   say -v "Karen" -o cat.aiff "cat" && \
     ffmpeg -i cat.aiff -c:a libvorbis cat.ogg
   ```
   适合给 `cards.json` 中所有 `text` 字段批量生成。

2. **Edge TTS / Azure / OpenAI TTS（线上质量）**：
   走外部脚本生成 .ogg，提交时只提交音频文件，不进引擎。
   建议在 `tools/` 下写一个独立脚本，读 `cards.json` → 调 API → 落盘。

3. **运行时 TTS（如果学科支持）**：
   未来可在 `ContentPackBase.get_audio(text)` 接口里走 STTClient
   的兄弟 TTSClient（暂未实现）。

## 本目录是否需要提交

- 真实音频文件 (.ogg) → 提交到 git LFS（视项目规模）
- 占位空文件 → 不提交，CI 自动跑 TTS 生成
- 当前阶段：`cards.json` / `challenges.json` 中已写明路径但文件未提交，
  引擎会静默降级；玩家看到"音频缺失"提示但不会崩溃。
