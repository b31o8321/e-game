# AP 队列战斗系统 + 本地语音后端 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有"线性单题战斗"改造成"有序 AP 队列连线战斗 + 本地 TTS/STT + 玩家反馈"。

**Architecture:**
1. 引擎层抽象 voice backend 接口（IVoiceTtsBackend/IVoiceSttBackend），实现 Piper + whisper.cpp + Stub + LocalMp3Cache 四个后端，VoiceClient 路由
2. BattleController 加 ap_queue 状态机（add/remove/reorder/submit_all），按槽位顺序批量结算
3. BattleScene 重做三层 UI（AP 顺序条 + 题板 + 手牌），原生拖拽（Control._get_drag_data 系列）
4. FeedbackSystem 是 autoload，jsonl append-only，每题加 🚩 按钮，设置页可导出

**Tech Stack:** Godot 4.6 GDScript, GUT 测试框架, Piper TTS (onnxruntime), whisper.cpp, OS.execute() 跑二进制, sha256 缓存

**Spec：** `docs/superpowers/specs/2026-05-05-ap-queue-battle-redesign.md`

---

## 文件结构概览

### 新增文件

```
src/voice/
├─ i_voice_tts_backend.gd        # TTS 接口
├─ i_voice_stt_backend.gd        # STT 接口
├─ voice_client.gd               # autoload 路由
├─ stub_tts_backend.gd           # 静音兜底
├─ stub_stt_backend.gd           # 总返回 target
├─ local_mp3_cache_backend.gd    # 现有 mp3 重用
├─ piper_tts_backend.gd          # Piper 子进程封装
├─ whisper_cpp_stt_backend.gd    # whisper.cpp 子进程封装
└─ voice_paths.gd                # 二进制/模型路径解析

src/battle/
├─ ap_connection.gd              # 连线数据
├─ ap_queue.gd                   # 队列管理
├─ ap_block_view.tscn + .gd      # 队列槽位视图（可拖拽重排）

src/feedback/
├─ feedback_system.gd            # autoload
├─ feedback_modal.tscn + .gd     # 反馈弹窗

scripts/
└─ download_voice_deps.sh        # 下载 Piper/whisper.cpp 二进制 + 模型

tests/
├─ test_voice_backends.gd
├─ test_voice_client.gd
├─ test_ap_queue.gd
├─ test_ap_submit.gd
├─ test_perfect_combo.gd
├─ test_empty_board_fallback.gd
├─ test_feedback_system.gd
└─ test_battle_scene_drag.gd
```

### 修改文件

```
src/battle/battle_controller.gd     # 加 ap_queue/submit_all/perfect_combo
src/battle/battle_scene.gd + .tscn  # 大改：3 层 UI + 拖拽
src/battle/cards/card_view.gd       # 加 _get_drag_data
src/battle/cards/challenge_template.gd  # 运行时态 is_warn
src/run/run_state.gd                # 加 next_turn_ap_bonus 持久化
src/ui/settings_scene.tscn + .gd    # 加"反馈管理"标签页
project.godot                        # +VoiceClient +FeedbackSystem 两个 autoload
build.sh                             # 含 voice 资源
```

---

## 任务执行顺序

```
Phase 1: Voice 后端抽象层（独立，可先做）
  Task 1 → 2 → 3
Phase 2: Voice 后端实现
  Task 4 → 5 → 6 → 7 → 8
Phase 3: AP 队列核心逻辑（独立 from voice）
  Task 9 → 10 → 11 → 12 → 13
Phase 4: 战斗 UI 重做
  Task 14 → 15 → 16 → 17
Phase 5: 反馈系统
  Task 18 → 19 → 20
Phase 6: 构建 + 部署
  Task 21 → 22
Phase 7: 集成 + 收尾
  Task 23 → 24
```

Phase 1+2 与 Phase 3+4 互不依赖；Phase 5 独立；Phase 6+7 收尾。

---

## Phase 1: Voice 后端抽象层

### Task 1: IVoiceTtsBackend / IVoiceSttBackend 接口

**Files:**
- Create: `src/voice/i_voice_tts_backend.gd`
- Create: `src/voice/i_voice_stt_backend.gd`
- Test: `tests/test_voice_backend_interfaces.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_voice_backend_interfaces.gd`:
```gdscript
extends GutTest

const IVoiceTtsBackend = preload("res://src/voice/i_voice_tts_backend.gd")
const IVoiceSttBackend = preload("res://src/voice/i_voice_stt_backend.gd")

func test_tts_base_class_has_required_methods():
	var b = IVoiceTtsBackend.new()
	assert_has_method(b, "is_available")
	assert_has_method(b, "get_id")
	assert_has_method(b, "synthesize")
	assert_has_method(b, "get_cache_path")

func test_stt_base_class_has_required_methods():
	var b = IVoiceSttBackend.new()
	assert_has_method(b, "is_available")
	assert_has_method(b, "get_id")
	assert_has_method(b, "transcribe")
```

- [ ] **Step 2: 运行验证失败**

```
/opt/homebrew/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_voice_backend_interfaces.gd -gexit
```
Expected: FAIL — 文件不存在

- [ ] **Step 3: 实现接口**

`src/voice/i_voice_tts_backend.gd`:
```gdscript
## TTS 后端接口。子类实现：
##   - is_available()  返回是否可用（二进制存在/网络通等）
##   - get_id()        返回唯一标识，例如 "piper" / "stub"
##   - synthesize()    text 合成 AudioStream，async
##   - get_cache_path() 缓存文件路径（sha256(text+lang)）
class_name IVoiceTtsBackend extends RefCounted

func is_available() -> bool:
	return false

func get_id() -> String:
	push_error("IVoiceTtsBackend.get_id() not overridden")
	return ""

## 合成音频；子类必须 override
func synthesize(_text: String, _lang: String = "en") -> AudioStream:
	push_error("IVoiceTtsBackend.synthesize() not overridden")
	return null

func get_cache_path(text: String, lang: String = "en") -> String:
	var key = "%s|%s|%s" % [get_id(), lang, text]
	var hash = key.sha256_text()
	return "user://tts_cache/%s.wav" % hash
```

`src/voice/i_voice_stt_backend.gd`:
```gdscript
class_name IVoiceSttBackend extends RefCounted

func is_available() -> bool:
	return false

func get_id() -> String:
	push_error("IVoiceSttBackend.get_id() not overridden")
	return ""

func transcribe(_audio: AudioStream, _lang: String = "en") -> String:
	push_error("IVoiceSttBackend.transcribe() not overridden")
	return ""
```

- [ ] **Step 4: 运行测试通过**

Expected: PASS（GUT 6/6 asserts）

- [ ] **Step 5: 提交**

```bash
git add src/voice/i_voice_tts_backend.gd src/voice/i_voice_stt_backend.gd \
       tests/test_voice_backend_interfaces.gd
git commit -m "feat(voice): add IVoiceTtsBackend/IVoiceSttBackend interfaces"
```

---

### Task 2: VoicePaths 工具

**Files:**
- Create: `src/voice/voice_paths.gd`
- Test: `tests/test_voice_paths.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const VoicePaths = preload("res://src/voice/voice_paths.gd")

func test_get_voice_dir_returns_non_empty():
	var p = VoicePaths.get_voice_dir()
	assert_true(p.length() > 0)

func test_get_piper_binary_returns_path_under_voice_dir():
	var p = VoicePaths.get_piper_binary()
	var v = VoicePaths.get_voice_dir()
	assert_true(p.begins_with(v))

func test_get_whisper_binary_returns_path():
	var p = VoicePaths.get_whisper_binary()
	assert_true(p.length() > 0)

func test_get_piper_default_model_path():
	var p = VoicePaths.get_piper_default_model()
	assert_true(p.ends_with(".onnx"))
```

- [ ] **Step 2: 运行验证 FAIL**

- [ ] **Step 3: 实现**

`src/voice/voice_paths.gd`:
```gdscript
## 解析 voice 二进制 + 模型路径
##
## 编辑器/headless：res://builds/voice/...
## 打包后 macOS：app/Contents/Resources/voice/...
## 打包后 Win/Linux：exe 同级 voice/...
class_name VoicePaths extends RefCounted

const PIPER_BINARY := "piper/piper"
const PIPER_DEFAULT_MODEL := "piper/models/en_US-lessac-medium.onnx"
const WHISPER_BINARY := "whisper/whisper-cli"
const WHISPER_DEFAULT_MODEL := "whisper/models/ggml-tiny.en.bin"


static func get_voice_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://builds/voice/")
	var exe_dir := OS.get_executable_path().get_base_dir()
	if OS.get_name() == "macOS":
		return exe_dir.path_join("../Resources/voice/")
	return exe_dir.path_join("voice/")


static func _join(rel: String) -> String:
	return get_voice_dir().path_join(rel)


static func get_piper_binary() -> String:
	return _join(PIPER_BINARY)


static func get_piper_default_model() -> String:
	return _join(PIPER_DEFAULT_MODEL)


static func get_whisper_binary() -> String:
	return _join(WHISPER_BINARY)


static func get_whisper_default_model() -> String:
	return _join(WHISPER_DEFAULT_MODEL)
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/voice/voice_paths.gd tests/test_voice_paths.gd
git commit -m "feat(voice): add VoicePaths helper for binary/model resolution"
```

---

### Task 3: StubTtsBackend / StubSttBackend

**Files:**
- Create: `src/voice/stub_tts_backend.gd`
- Create: `src/voice/stub_stt_backend.gd`
- Test: `tests/test_stub_backends.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const StubTtsBackend = preload("res://src/voice/stub_tts_backend.gd")
const StubSttBackend = preload("res://src/voice/stub_stt_backend.gd")

func test_stub_tts_is_available():
	assert_true(StubTtsBackend.new().is_available())

func test_stub_tts_id():
	assert_eq(StubTtsBackend.new().get_id(), "stub_tts")

func test_stub_tts_synthesize_returns_silent_stream():
	var b = StubTtsBackend.new()
	var stream = await b.synthesize("hello")
	assert_not_null(stream)
	assert_true(stream is AudioStreamWAV)

func test_stub_stt_is_available():
	assert_true(StubSttBackend.new().is_available())

func test_stub_stt_returns_target_phrase():
	var b = StubSttBackend.new()
	b.target_phrase_hint = "I am strong"
	var t = await b.transcribe(null)
	assert_eq(t, "I am strong")
```

- [ ] **Step 2: 验证 FAIL**

- [ ] **Step 3: 实现**

`src/voice/stub_tts_backend.gd`:
```gdscript
## 静音 TTS 兜底：无法获取真实音频时返回 0.5 秒静音流
class_name StubTtsBackend extends IVoiceTtsBackend

func is_available() -> bool:
	return true

func get_id() -> String:
	return "stub_tts"

func synthesize(_text: String, _lang: String = "en") -> AudioStream:
	var stream = AudioStreamWAV.new()
	# 0.5 秒 22050Hz mono 静音
	var samples := PackedByteArray()
	samples.resize(22050 * 2 / 2)  # 0.5s
	samples.fill(0)
	stream.data = samples
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	return stream
```

`src/voice/stub_stt_backend.gd`:
```gdscript
## STT 兜底：直接返回目标短语（dev mode 走成功路径）
class_name StubSttBackend extends IVoiceSttBackend

var target_phrase_hint: String = ""

func is_available() -> bool:
	return true

func get_id() -> String:
	return "stub_stt"

func transcribe(_audio: AudioStream, _lang: String = "en") -> String:
	return target_phrase_hint
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/voice/stub_tts_backend.gd src/voice/stub_stt_backend.gd \
       tests/test_stub_backends.gd
git commit -m "feat(voice): add Stub TTS/STT backends (silent + target phrase)"
```

---

## Phase 2: Voice 后端实现

### Task 4: LocalMp3CacheBackend

**Files:**
- Create: `src/voice/local_mp3_cache_backend.gd`
- Test: `tests/test_local_mp3_cache_backend.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const LocalMp3CacheBackend = preload("res://src/voice/local_mp3_cache_backend.gd")

func test_id():
	assert_eq(LocalMp3CacheBackend.new().get_id(), "local_mp3_cache")

func test_is_available_when_audio_dir_exists():
	var b = LocalMp3CacheBackend.new()
	# 默认指 res://src/content/english/audio/
	assert_true(b.is_available())

func test_synthesize_existing_word_returns_loaded_stream():
	var b = LocalMp3CacheBackend.new()
	# 假设 cat.mp3 存在
	var stream = await b.synthesize("cat")
	assert_not_null(stream)

func test_synthesize_unknown_word_returns_null():
	var b = LocalMp3CacheBackend.new()
	var stream = await b.synthesize("xyz_doesnt_exist")
	assert_null(stream)

func test_letter_lookup():
	var b = LocalMp3CacheBackend.new()
	var stream = await b.synthesize("a")
	# 'a' is letter, should hit letters/a.mp3
	assert_not_null(stream)
```

- [ ] **Step 2: 验证 FAIL**

- [ ] **Step 3: 实现**

`src/voice/local_mp3_cache_backend.gd`:
```gdscript
## 在内置 mp3 词表里查找；命中返回 AudioStream，未命中返回 null
class_name LocalMp3CacheBackend extends IVoiceTtsBackend

const WORDS_DIR := "res://src/content/english/audio/words/"
const LETTERS_DIR := "res://src/content/english/audio/letters/"

func is_available() -> bool:
	return DirAccess.dir_exists_absolute(WORDS_DIR)

func get_id() -> String:
	return "local_mp3_cache"

func synthesize(text: String, _lang: String = "en") -> AudioStream:
	var lower := text.to_lower()
	var fname := lower.replace(" ", "_") + ".mp3"
	var candidates := [LETTERS_DIR, WORDS_DIR] if lower.length() == 1 else [WORDS_DIR, LETTERS_DIR]
	for dir in candidates:
		var path := dir.path_join(fname)
		if ResourceLoader.exists(path):
			return load(path)
	return null
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/voice/local_mp3_cache_backend.gd tests/test_local_mp3_cache_backend.gd
git commit -m "feat(voice): add LocalMp3CacheBackend (read existing audio files)"
```

---

### Task 5: PiperTtsBackend（子进程调用）

**Files:**
- Create: `src/voice/piper_tts_backend.gd`
- Test: `tests/test_piper_tts_backend.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const PiperTtsBackend = preload("res://src/voice/piper_tts_backend.gd")

func test_id():
	assert_eq(PiperTtsBackend.new().get_id(), "piper")

func test_not_available_when_binary_missing():
	# 假设测试环境没有 piper 二进制
	var b = PiperTtsBackend.new()
	b._binary_path_override = "/tmp/nonexistent_piper"
	assert_false(b.is_available())

func test_cache_hit_skips_subprocess():
	var b = PiperTtsBackend.new()
	# 提前在 user://tts_cache 写一个伪缓存文件
	var path = b.get_cache_path("hello")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(_make_silent_wav())
	f.close()
	var stream = await b.synthesize("hello")
	assert_not_null(stream)
	# 不应调用子进程（命中缓存）
	# 测试通过的前提：能加载

func _make_silent_wav() -> PackedByteArray:
	# RIFF header for 0.1s mono 22050Hz silence
	var data = PackedByteArray()
	data.append_array("RIFF".to_utf8_buffer())
	data.resize(44 + 4410)  # 4410 samples = 0.1s
	return data
```

- [ ] **Step 2: 验证 FAIL**

- [ ] **Step 3: 实现**

`src/voice/piper_tts_backend.gd`:
```gdscript
## Piper TTS 后端：通过 OS.execute 调用本地 piper 二进制 + onnx 模型
##
## 用法：
##   var b := PiperTtsBackend.new()
##   if b.is_available():
##     var stream = await b.synthesize("brave")
##
## 缓存策略：sha256(id|lang|text) → user://tts_cache/<hash>.wav
class_name PiperTtsBackend extends IVoiceTtsBackend

const VoicePaths = preload("res://src/voice/voice_paths.gd")

var _binary_path_override: String = ""   # 测试用
var _model_path_override: String = ""

func get_id() -> String:
	return "piper"

func is_available() -> bool:
	return FileAccess.file_exists(_binary_path()) and FileAccess.file_exists(_model_path())

func _binary_path() -> String:
	if _binary_path_override != "":
		return _binary_path_override
	return VoicePaths.get_piper_binary()

func _model_path() -> String:
	if _model_path_override != "":
		return _model_path_override
	return VoicePaths.get_piper_default_model()

func synthesize(text: String, lang: String = "en") -> AudioStream:
	var cache_path := get_cache_path(text, lang)
	if FileAccess.file_exists(cache_path):
		return _load_wav(cache_path)
	if not is_available():
		return null
	# 子进程调用
	DirAccess.make_dir_recursive_absolute(cache_path.get_base_dir())
	var args := [
		"--model", _model_path(),
		"--output_file", ProjectSettings.globalize_path(cache_path),
	]
	# 通过 stdin 传 text
	var output := []
	# OS.execute 不直接支持 stdin，临时解决：用 echo 管道（仅 mac/linux）
	# Windows 用法不同；后续可写 helper 脚本
	var cmd := "echo %s | %s --model %s --output_file %s" % [
		text.replace("\"", "\\\""),
		_binary_path(),
		_model_path(),
		ProjectSettings.globalize_path(cache_path)
	]
	var ec := OS.execute("bash", ["-c", cmd], output, true, false)
	if ec != 0:
		push_error("Piper failed (ec=%d): %s" % [ec, "\n".join(output)])
		return null
	if not FileAccess.file_exists(cache_path):
		push_error("Piper produced no output file")
		return null
	return _load_wav(cache_path)

func _load_wav(path: String) -> AudioStream:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var data = f.get_buffer(f.get_length())
	f.close()
	var stream := AudioStreamWAV.new()
	# 简化：假定 piper 输出 22050Hz 16-bit mono
	# 实际需解析 WAV header；MVP 直接读 data chunk
	# 完整实现见 _parse_wav_header
	return _parse_wav_to_stream(data)

static func _parse_wav_to_stream(raw: PackedByteArray) -> AudioStream:
	# 跳过 RIFF header (44 bytes 标准格式)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = raw.slice(44)
	return stream
```

- [ ] **Step 4: 测试通过（无 piper 时跳过 synthesize 测试）**

- [ ] **Step 5: 提交**

```bash
git add src/voice/piper_tts_backend.gd tests/test_piper_tts_backend.gd
git commit -m "feat(voice): add PiperTtsBackend (subprocess + cache)"
```

---

### Task 6: WhisperCppSttBackend

**Files:**
- Create: `src/voice/whisper_cpp_stt_backend.gd`
- Test: `tests/test_whisper_cpp_stt_backend.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const WhisperCppSttBackend = preload("res://src/voice/whisper_cpp_stt_backend.gd")

func test_id():
	assert_eq(WhisperCppSttBackend.new().get_id(), "whisper_cpp")

func test_not_available_when_binary_missing():
	var b = WhisperCppSttBackend.new()
	b._binary_path_override = "/tmp/nonexistent_whisper"
	assert_false(b.is_available())

func test_audio_to_temp_wav():
	var b = WhisperCppSttBackend.new()
	# 伪 stream
	var s = AudioStreamWAV.new()
	s.data = PackedByteArray([0, 0, 0, 0])
	s.mix_rate = 16000
	var path = b._write_temp_wav(s)
	assert_true(FileAccess.file_exists(path))
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: 验证 FAIL**

- [ ] **Step 3: 实现**

`src/voice/whisper_cpp_stt_backend.gd`:
```gdscript
## STT 后端：调用本地 whisper-cli 二进制 + ggml 模型
##
## 输入：AudioStream（先序列化为临时 WAV 文件）
## 输出：transcript 字符串
class_name WhisperCppSttBackend extends IVoiceSttBackend

const VoicePaths = preload("res://src/voice/voice_paths.gd")

const TEMP_WAV := "user://stt_temp.wav"
const TEMP_TXT := "user://stt_temp.wav.txt"

var _binary_path_override: String = ""
var _model_path_override: String = ""

func get_id() -> String:
	return "whisper_cpp"

func is_available() -> bool:
	return FileAccess.file_exists(_binary_path()) and FileAccess.file_exists(_model_path())

func _binary_path() -> String:
	if _binary_path_override != "":
		return _binary_path_override
	return VoicePaths.get_whisper_binary()

func _model_path() -> String:
	if _model_path_override != "":
		return _model_path_override
	return VoicePaths.get_whisper_default_model()

func transcribe(audio: AudioStream, _lang: String = "en") -> String:
	if not is_available() or audio == null:
		return ""
	var wav_path := _write_temp_wav(audio)
	if wav_path == "":
		return ""
	var args := [
		"-m", _model_path(),
		"-f", ProjectSettings.globalize_path(wav_path),
		"-otxt",
		"-nt",       # no timestamps
		"-of", ProjectSettings.globalize_path(TEMP_TXT.replace(".txt", "")),
	]
	var output := []
	var ec := OS.execute(_binary_path(), args, output, true, false)
	if ec != 0:
		push_error("whisper-cli failed (ec=%d)" % ec)
		return ""
	var f = FileAccess.open(TEMP_TXT, FileAccess.READ)
	if not f:
		return ""
	var transcript = f.get_as_text().strip_edges()
	f.close()
	return transcript

func _write_temp_wav(audio: AudioStream) -> String:
	if not audio is AudioStreamWAV:
		push_error("Only AudioStreamWAV supported")
		return ""
	var s: AudioStreamWAV = audio
	# 写 RIFF WAV header + data
	var f = FileAccess.open(TEMP_WAV, FileAccess.WRITE)
	if not f:
		return ""
	var data := s.data
	var sample_rate := s.mix_rate
	var bits := 16 if s.format == AudioStreamWAV.FORMAT_16_BITS else 8
	var channels := 2 if s.stereo else 1
	var byte_rate = sample_rate * channels * bits / 8
	# RIFF
	f.store_buffer("RIFF".to_utf8_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_utf8_buffer())
	# fmt
	f.store_buffer("fmt ".to_utf8_buffer())
	f.store_32(16)        # chunk size
	f.store_16(1)         # PCM
	f.store_16(channels)
	f.store_32(sample_rate)
	f.store_32(byte_rate)
	f.store_16(channels * bits / 8)
	f.store_16(bits)
	# data
	f.store_buffer("data".to_utf8_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return TEMP_WAV
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/voice/whisper_cpp_stt_backend.gd tests/test_whisper_cpp_stt_backend.gd
git commit -m "feat(voice): add WhisperCppSttBackend (subprocess + WAV ser)"
```

---

### Task 7: VoiceClient autoload + 后端选择

**Files:**
- Create: `src/voice/voice_client.gd`
- Test: `tests/test_voice_client.gd`
- Modify: `project.godot`（加 autoload）

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const VoiceClientScript = preload("res://src/voice/voice_client.gd")

func _make_client() -> Node:
	var c = VoiceClientScript.new()
	add_child_autofree(c)
	return c

func test_default_backends_picked():
	var c = _make_client()
	c._init_backends()
	assert_not_null(c.tts_backend)
	assert_not_null(c.stt_backend)

func test_tts_falls_back_to_local_then_stub():
	var c = _make_client()
	c._init_backends()
	# 在大多数 dev 环境下，piper 没装 → 应退到 local_mp3_cache 或 stub
	var ids = ["piper", "local_mp3_cache", "stub_tts"]
	assert_true(c.tts_backend.get_id() in ids)

func test_switch_backend_replaces_active():
	var c = _make_client()
	c.switch_tts("stub_tts")
	assert_eq(c.tts_backend.get_id(), "stub_tts")

func test_tts_returns_audio_stream():
	var c = _make_client()
	c.switch_tts("stub_tts")
	var stream = await c.tts("hello")
	assert_not_null(stream)
```

- [ ] **Step 2: 验证 FAIL**

- [ ] **Step 3: 实现 VoiceClient**

`src/voice/voice_client.gd`:
```gdscript
## VoiceClient — TTS/STT 路由 autoload
##
## 启动时按优先级选最佳可用后端：
##   TTS: Piper > LocalMp3Cache > Stub
##   STT: WhisperCpp > Stub
##
## 提供统一调用入口：
##   await VoiceClient.tts("brave")
##   await VoiceClient.stt(audio_stream)
##
## 设置切换：VoiceClient.switch_tts("stub_tts") / switch_stt(...)
extends Node

const PiperTtsBackend = preload("res://src/voice/piper_tts_backend.gd")
const LocalMp3CacheBackend = preload("res://src/voice/local_mp3_cache_backend.gd")
const StubTtsBackend = preload("res://src/voice/stub_tts_backend.gd")
const WhisperCppSttBackend = preload("res://src/voice/whisper_cpp_stt_backend.gd")
const StubSttBackend = preload("res://src/voice/stub_stt_backend.gd")

const TTS_PRIORITY := ["piper", "local_mp3_cache", "stub_tts"]
const STT_PRIORITY := ["whisper_cpp", "stub_stt"]

var tts_backend: IVoiceTtsBackend = null
var stt_backend: IVoiceSttBackend = null

var _all_tts: Dictionary = {}
var _all_stt: Dictionary = {}


func _ready() -> void:
	_init_backends()


func _init_backends() -> void:
	_all_tts = {
		"piper": PiperTtsBackend.new(),
		"local_mp3_cache": LocalMp3CacheBackend.new(),
		"stub_tts": StubTtsBackend.new(),
	}
	_all_stt = {
		"whisper_cpp": WhisperCppSttBackend.new(),
		"stub_stt": StubSttBackend.new(),
	}
	tts_backend = _pick_first_available(_all_tts, TTS_PRIORITY)
	stt_backend = _pick_first_available(_all_stt, STT_PRIORITY)


static func _pick_first_available(map: Dictionary, priority: Array) -> Resource:
	for id in priority:
		var b = map.get(id, null)
		if b and b.is_available():
			return b
	# 退化到第一个
	for id in priority:
		if map.has(id):
			return map[id]
	return null


func switch_tts(id: String) -> bool:
	if not _all_tts.has(id):
		return false
	tts_backend = _all_tts[id]
	return true


func switch_stt(id: String) -> bool:
	if not _all_stt.has(id):
		return false
	stt_backend = _all_stt[id]
	return true


func tts(text: String, lang: String = "en") -> AudioStream:
	if tts_backend == null:
		return null
	return await tts_backend.synthesize(text, lang)


func stt(audio: AudioStream, lang: String = "en") -> String:
	if stt_backend == null:
		return ""
	return await stt_backend.transcribe(audio, lang)
```

- [ ] **Step 4: 注册 autoload**

`project.godot` 在 `[autoload]` 段加：
```
VoiceClient="*res://src/voice/voice_client.gd"
```

- [ ] **Step 5: 测试通过 + 提交**

```bash
git add src/voice/voice_client.gd tests/test_voice_client.gd project.godot
git commit -m "feat(voice): add VoiceClient autoload with backend routing"
```

---

### Task 8: 战斗中 🔊 按钮调用 VoiceClient

**Files:**
- Modify: `src/battle/battle_scene.gd`

- [ ] **Step 1: 找到 _play_challenge_audio**

```bash
grep -n "_play_challenge_audio" src/battle/battle_scene.gd
```

- [ ] **Step 2: 写测试**

`tests/test_battle_audio_routing.gd`:
```gdscript
extends GutTest

func test_play_audio_falls_back_to_voice_client_tts(p):
	# 当 challenge.audio_path 为空但有 audio_text 时，调 VoiceClient.tts
	# 这是设计假设：未来 challenge 用 audio_text 字段，audio_path 是缓存
	pass  # 集成测试占位
```

- [ ] **Step 3: 修改 battle_scene.gd**

把 `_play_challenge_audio(path)` 改为：
```gdscript
func _play_challenge_audio(template: ChallengeTemplate) -> void:
	if template == null:
		return
	# 优先用文件 (LocalMp3Cache 风格)
	var path = template.audio_path
	if not path.is_empty() and ResourceLoader.exists(path):
		_play_stream(load(path))
		return
	# 退到 VoiceClient（Piper / Stub）
	# 用 dialogue 中除 ___ 外的文本作 hint，或题目专属 audio_text 字段
	var text := _extract_audio_text(template)
	if text.is_empty():
		return
	var stream = await VoiceClient.tts(text)
	if stream:
		_play_stream(stream)

func _play_stream(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _extract_audio_text(template: ChallengeTemplate) -> String:
	# 听力题：取 perfect_match_card_ids[0] 对应卡的 text，或 audio_path 文件名
	if template.audio_path.is_empty():
		# Fallback: 取 dialogue 不包含 ___ 的部分
		return template.dialogue.replace("___", "").strip_edges()
	# 用 audio_path 推断单词
	return template.audio_path.get_file().get_basename()
```

- [ ] **Step 4: 跑 battle 测试**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_scene.gd tests/test_battle_audio_routing.gd
git commit -m "feat(voice): wire VoiceClient.tts() into battle audio playback"
```

---

## Phase 3: AP 队列核心逻辑

### Task 9: APConnection 数据类

**Files:**
- Create: `src/battle/ap_connection.gd`
- Test: `tests/test_ap_connection.gd`

- [ ] **Step 1: 测试**

```gdscript
extends GutTest

const APConnection = preload("res://src/battle/ap_connection.gd")

func test_create_basic():
	var c = APConnection.new()
	c.slot_index = 0
	c.challenge_index = 1
	c.question_slot_index = 0
	assert_eq(c.slot_index, 0)

func test_to_dict_roundtrip():
	var c = APConnection.new()
	c.slot_index = 2
	c.challenge_index = 1
	c.question_slot_index = 0
	c.preview = {"damage": 12}
	var d = c.to_dict()
	assert_eq(d["slot_index"], 2)
	assert_eq(d["preview"]["damage"], 12)
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

`src/battle/ap_connection.gd`:
```gdscript
## APConnection — 玩家在 AP 队列里的一条连线
##
## 字段：
##   slot_index           队列位置（0-based）
##   card                 出的卡
##   challenge_index      题板上的题索引
##   question_slot_index  题里的具体槽
##   preview              结算前预估 {damage, heal, ...}
class_name APConnection extends RefCounted

var slot_index: int = 0
var card: Card = null
var challenge_index: int = -1
var question_slot_index: int = 0
var preview: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"slot_index": slot_index,
		"card_id": card.id if card else "",
		"challenge_index": challenge_index,
		"question_slot_index": question_slot_index,
		"preview": preview.duplicate(),
	}
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/ap_connection.gd tests/test_ap_connection.gd
git commit -m "feat(battle): add APConnection data class"
```

---

### Task 10: BattleController.add_to_ap_queue / remove / reorder

**Files:**
- Modify: `src/battle/battle_controller.gd`
- Test: `tests/test_ap_queue.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const BattleController = preload("res://src/battle/battle_controller.gd")
const APConnection = preload("res://src/battle/ap_connection.gd")

func _make_ctrl() -> BattleController:
	var c = BattleController.new()
	c.ap_max = 3
	add_child_autofree(c)
	return c

func test_add_to_ap_queue_appends():
	var c = _make_ctrl()
	var card = _make_card("test")
	c._hand = [card]
	c.add_to_ap_queue(card, 0, 0)
	assert_eq(c.ap_queue.size(), 1)
	assert_eq(c.ap_queue[0].slot_index, 0)
	assert_eq(c.ap_queue[0].card.id, "test")

func test_add_to_ap_queue_full_rejects():
	var c = _make_ctrl()
	c.ap_max = 2
	var c1 = _make_card("a")
	var c2 = _make_card("b")
	var c3 = _make_card("c")
	c._hand = [c1, c2, c3]
	assert_true(c.add_to_ap_queue(c1, 0, 0))
	assert_true(c.add_to_ap_queue(c2, 1, 0))
	assert_false(c.add_to_ap_queue(c3, 2, 0))
	assert_eq(c.ap_queue.size(), 2)

func test_remove_from_ap_queue_returns_card():
	var c = _make_ctrl()
	var card = _make_card("a")
	c._hand = [card]
	c.add_to_ap_queue(card, 0, 0)
	# 卡进入队列后从手牌移出
	assert_eq(c._hand.size(), 0)
	c.remove_from_ap_queue(0)
	assert_eq(c.ap_queue.size(), 0)
	assert_eq(c._hand.size(), 1)
	assert_eq(c._hand[0].id, "a")

func test_reorder_ap_queue():
	var c = _make_ctrl()
	var c1 = _make_card("a")
	var c2 = _make_card("b")
	var c3 = _make_card("c")
	c._hand = [c1, c2, c3]
	c.add_to_ap_queue(c1, 0, 0)
	c.add_to_ap_queue(c2, 1, 0)
	c.add_to_ap_queue(c3, 2, 0)
	c.reorder_ap_queue(2, 0)  # 把 idx 2 移到 idx 0
	assert_eq(c.ap_queue[0].card.id, "c")
	assert_eq(c.ap_queue[1].card.id, "a")
	assert_eq(c.ap_queue[2].card.id, "b")
	# slot_index 也应该重排
	for i in c.ap_queue.size():
		assert_eq(c.ap_queue[i].slot_index, i)

func _make_card(id: String) -> Card:
	var c = Card.new()
	c.id = id
	c.text = id
	c.type = "word"
	c.pos = "adjective"
	c.tags = ["positive_emotion"]
	c.base_damage = 5
	return c
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

In `src/battle/battle_controller.gd`，加：
```gdscript
const APConnection = preload("res://src/battle/ap_connection.gd")

var ap_queue: Array = []   # Array[APConnection]
var ap_max: int = 3
var ap_bonus_next_turn: int = 0   # 完美连击的临时奖励


func add_to_ap_queue(card: Card, challenge_index: int, slot_index: int) -> bool:
	if ap_queue.size() >= ap_max + ap_bonus_next_turn:
		return false
	# 卡从 _hand 移出
	if not (card in _hand):
		return false
	_hand.erase(card)
	var conn := APConnection.new()
	conn.slot_index = ap_queue.size()
	conn.card = card
	conn.challenge_index = challenge_index
	conn.question_slot_index = slot_index
	conn.preview = _compute_preview(card, challenge_index, slot_index)
	ap_queue.append(conn)
	hand_changed.emit()
	board_changed.emit()
	return true


func remove_from_ap_queue(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= ap_queue.size():
		return false
	var conn = ap_queue[slot_index]
	_hand.append(conn.card)
	ap_queue.remove_at(slot_index)
	# 重新编号
	for i in ap_queue.size():
		ap_queue[i].slot_index = i
	hand_changed.emit()
	board_changed.emit()
	return true


func reorder_ap_queue(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or from_idx >= ap_queue.size():
		return false
	if to_idx < 0 or to_idx >= ap_queue.size():
		return false
	var conn = ap_queue[from_idx]
	ap_queue.remove_at(from_idx)
	ap_queue.insert(to_idx, conn)
	for i in ap_queue.size():
		ap_queue[i].slot_index = i
	board_changed.emit()
	return true


func _compute_preview(card: Card, ch_idx: int, slot_idx: int) -> Dictionary:
	if ch_idx < 0 or ch_idx >= available_challenges.size():
		return {}
	var ch = available_challenges[ch_idx]
	if ch == null:
		return {}
	# 简单预览：基础伤害
	var base = card.base_damage
	return {"damage": base, "card_id": card.id, "template_id": ch.template.template_id}
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_controller.gd tests/test_ap_queue.gd
git commit -m "feat(battle): add ap_queue + add/remove/reorder methods"
```

---

### Task 11: BattleController.submit_all_ap（按顺序结算）

**Files:**
- Modify: `src/battle/battle_controller.gd`
- Test: `tests/test_ap_submit.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const BattleController = preload("res://src/battle/battle_controller.gd")

func _make_ctrl_with_two_challenges() -> BattleController:
	var c = BattleController.new()
	add_child_autofree(c)
	# Setup with mock pack/enemy/decks
	# ... see existing test_battle_system_v2.gd patterns
	return c

func test_submit_all_correct_applies_effects():
	var c = _make_ctrl_with_two_challenges()
	# Enqueue two correct connections
	# Submit
	# Assert: enemy HP reduced, perfect_combo set
	# (full setup with mocks)
	pass  # 完整 setup 见 实施时

func test_submit_with_one_wrong_marks_failed():
	# 1 对 1 错
	# Submit
	# 对的应用，错的标记 failed
	# combo 重置
	pass

func test_submit_all_correct_grants_next_turn_ap_bonus():
	# 全对
	# 检查 ap_bonus_next_turn = 1
	pass
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现 submit_all_ap**

```gdscript
func submit_all_ap() -> void:
	if ap_queue.is_empty():
		end_player_turn()
		return
	var perfect := true
	# 按 slot_index 顺序结算
	var ordered = ap_queue.duplicate()
	ordered.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	for conn in ordered:
		var ok = _resolve_connection(conn)
		if not ok:
			perfect = false
	# 完美连击
	if perfect and ordered.size() > 0:
		ap_bonus_next_turn = 1
		_log("[color=yellow]完美连击！下回合 +1 AP[/color]")
	else:
		ap_bonus_next_turn = 0
	ap_queue.clear()
	# 进入敌人回合
	end_player_turn()


func _resolve_connection(conn: APConnection) -> bool:
	if conn.challenge_index < 0 or conn.challenge_index >= available_challenges.size():
		return false
	var ch = available_challenges[conn.challenge_index]
	if ch == null:
		return false
	var slot = ch.template.slots[conn.question_slot_index]
	# 验证
	if not CardValidator.can_place(conn.card, slot):
		# 错连：弹答错模态 + 标 failed
		_mark_challenge_failed(conn.challenge_index, ch.template)
		_combo.reset()
		_discard.append(conn.card)
		return false
	# 对的：填充槽位
	if conn.question_slot_index >= ch.filled_slots.size():
		ch.filled_slots.resize(conn.question_slot_index + 1)
	ch.filled_slots[conn.question_slot_index] = conn.card
	# 检查这题是否全部填完且全对
	var all_filled = true
	var all_correct = true
	for i in ch.template.slots.size():
		var fs = ch.filled_slots[i] if i < ch.filled_slots.size() else null
		if fs == null:
			all_filled = false
			break
		if not CardValidator.can_place(fs, ch.template.slots[i]):
			all_correct = false
	if all_filled and all_correct:
		_apply_question_effect(ch)
		_remove_challenge(conn.challenge_index)
	_discard.append(conn.card)
	return true


func _apply_question_effect(ch: Challenge) -> void:
	# 计算总伤害（来自所有 filled_slots）
	var base_damage = 0
	for c in ch.filled_slots:
		base_damage += c.base_damage
	var pre = CardAbilities.apply_pre_submit(self, ch.filled_slots, base_damage)
	base_damage = int(round(base_damage * pre.damage_modifier))
	var result = ChallengeEffects.apply(self, ch.template, base_damage)
	# 应用伤害 / 治疗 / 护盾
	if result.damage_to_enemy > 0:
		enemy_hp = max(0, enemy_hp - result.damage_to_enemy)
		damage_dealt.emit(result.damage_to_enemy, false, false)
	if result.heal_player > 0:
		var max_hp = GameState.player_max_hp
		GameState.player_hp = min(max_hp, GameState.player_hp + result.heal_player)
		healed.emit(result.heal_player)
	if result.shield_added > 0:
		player_shield += result.shield_added
		shielded.emit(result.shield_added)
	# 抽卡 / 抽题等其它效果
	if result.cards_drawn > 0:
		_draw_cards(result.cards_drawn)
	if result.questions_drawn > 0:
		_queued_for_next_turn += result.questions_drawn
	# 触发战斗结束
	if enemy_hp <= 0:
		_on_enemy_dead()
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_controller.gd tests/test_ap_submit.gd
git commit -m "feat(battle): submit_all_ap with ordered resolution + perfect combo"
```

---

### Task 12: 完美连击 +1 AP 持久化

**Files:**
- Modify: `src/battle/battle_controller.gd`
- Test: `tests/test_perfect_combo.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

func test_perfect_combo_sets_bonus():
	var c = _make_ctrl()
	# 全对的 submit_all_ap → ap_bonus_next_turn == 1
	pass

func test_imperfect_clears_bonus():
	var c = _make_ctrl()
	# 1 错 → ap_bonus_next_turn == 0
	pass

func test_next_turn_ap_max_includes_bonus():
	var c = _make_ctrl()
	c.ap_bonus_next_turn = 1
	c._draw_to_full_hand()  # 模拟 turn start
	c.refill_board()
	assert_eq(c.ap_max + c.ap_bonus_next_turn, 4)
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

In `_run_enemy_turn` 或 turn start:
```gdscript
# 在 add_to_ap_queue 检查时已经用了 ap_max + ap_bonus_next_turn
# 这里只需保证 ap_bonus_next_turn 在 turn end 后传递到下个 turn

# 进入新回合时（turn_start）：bonus 已经在使用，结束时清零
func _start_new_turn() -> void:
	# bonus 已被这回合使用，下回合得重新挣
	# 实际：ap_bonus_next_turn 在 submit_all_ap 时已设；在 _run_enemy_turn 之后什么都不做
	pass
```

确保 `submit_all_ap` 末尾清掉错的情况：
- perfect=true → ap_bonus_next_turn = 1（下回合用）
- perfect=false → ap_bonus_next_turn = 0

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_controller.gd tests/test_perfect_combo.gd
git commit -m "feat(battle): perfect combo grants +1 AP next turn"
```

---

### Task 13: 题板降级填充（修卡手）

**Files:**
- Modify: `src/battle/battle_controller.gd`
- Modify: `src/battle/cards/challenge_template.gd`（加 is_warn 运行时态）
- Test: `tests/test_empty_board_fallback.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

func test_refill_uses_solvable_first():
	# 全部 solvable → 全选 solvable
	pass

func test_refill_falls_back_to_unfiltered_when_solvable_not_enough():
	# solvable < BOARD_SIZE → 用全部 + 标 is_warn
	pass

func test_warn_marked_when_unfiltered():
	# 降级题应有 is_warn = true
	pass

func test_refill_never_empty_when_pool_nonempty():
	# 即使 solvable 为 0，pool 有就不空
	pass
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

修改 `refill_board`:
```gdscript
func refill_board() -> void:
	if _enemy == null or _pack == null:
		return
	var pool: Array = _pack.get_challenges_for_topic(_enemy.topic_id)
	var solvable: Array = []
	for tmpl in pool:
		if _can_solve_with_hand(tmpl, _hand):
			solvable.append(tmpl)
	
	# 保留 kept
	var keepers = []
	var kept_ids = []
	for ch in available_challenges:
		if ch and ch.template and ch.template.template_id in kept_template_ids:
			keepers.append(ch)
			kept_ids.append(ch.template.template_id)
	
	var slots_needed = BOARD_SIZE - keepers.size()
	var fill: Array[Challenge] = []
	
	# 1) 从 solvable 抽
	var picked_solvable = _pick_random_n(solvable, min(slots_needed, solvable.size()))
	for tmpl in picked_solvable:
		var ch = _make_challenge(tmpl)
		ch.template.is_warn = false
		fill.append(ch)
	
	# 2) 不够 → 从 pool（去掉 picked_solvable + keepers 的 template）抽
	if fill.size() < slots_needed:
		var rest = pool.filter(func(t):
			if t in picked_solvable: return false
			if t.template_id in kept_ids: return false
			return true
		)
		var pickedl = _pick_random_n(rest, slots_needed - fill.size())
		for tmpl in pickedl:
			var ch = _make_challenge(tmpl)
			ch.template.is_warn = true   # 标"略难"
			fill.append(ch)
	
	available_challenges = keepers + fill
	kept_template_ids = kept_ids
	_failed_challenge_indices.clear()
	selected_challenge_index = 0 if not available_challenges.is_empty() else -1
	board_changed.emit()
```

In `src/battle/cards/challenge_template.gd` 末尾：
```gdscript
# Runtime-only flag, not serialized
var is_warn: bool = false
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_controller.gd src/battle/cards/challenge_template.gd \
       tests/test_empty_board_fallback.gd
git commit -m "fix(battle): board fallback to unfiltered pool with warn flag"
```

---

## Phase 4: 战斗 UI 重做

### Task 14: APBlockView 视图

**Files:**
- Create: `src/battle/ap_block_view.tscn`
- Create: `src/battle/ap_block_view.gd`
- Test: `tests/test_ap_block_view.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const APBlockViewScene = preload("res://src/battle/ap_block_view.tscn")

func test_render_with_connection():
	var v = APBlockViewScene.instantiate()
	add_child_autofree(v)
	var conn = APConnection.new()
	conn.slot_index = 0
	conn.card = _make_card("brave")
	conn.challenge_index = 1
	conn.preview = {"damage": 8}
	v.render(conn)
	assert_eq(v.get_node("Label").text.contains("brave"), true)
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 创建场景 + 脚本**

`src/battle/ap_block_view.tscn`：PanelContainer 含 VBox（slot_index 数字、icon、card_text、preview_value）

`src/battle/ap_block_view.gd`:
```gdscript
extends PanelContainer

var connection: APConnection = null

@onready var slot_label: Label = $VBox/SlotLabel
@onready var card_label: Label = $VBox/CardLabel
@onready var preview_label: Label = $VBox/PreviewLabel


func render(c: APConnection) -> void:
	connection = c
	slot_label.text = "[%d]" % (c.slot_index + 1)
	card_label.text = c.card.text if c.card else "—"
	if c.preview.has("damage"):
		preview_label.text = "⚔ %d" % c.preview.damage
	else:
		preview_label.text = ""


# 拖拽支持
func _get_drag_data(_at_position: Vector2) -> Variant:
	if connection == null:
		return null
	return {"type": "ap_block", "from_index": connection.slot_index}


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type") == "ap_block"


func _drop_data(_at_position: Vector2, data) -> void:
	# 通过信号通知 BattleScene 处理
	emit_signal("reorder_requested", data.from_index, connection.slot_index)


signal reorder_requested(from_index: int, to_index: int)
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/battle/ap_block_view.gd src/battle/ap_block_view.tscn \
       tests/test_ap_block_view.gd
git commit -m "feat(battle): add APBlockView with drag-reorder support"
```

---

### Task 15: BattleScene 三层 UI 重做

**Files:**
- Modify: `src/battle/battle_scene.tscn`
- Modify: `src/battle/battle_scene.gd`
- Test: `tests/test_battle_scene_layout.gd`

> 这是大改造，需要谨慎：保留所有现有功能（HP/连击/敌人立绘/题板渲染）的同时加 AP 顺序条。

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const BattleSceneScene = preload("res://src/battle/battle_scene.tscn")

func test_loads_three_layers():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	assert_not_null(s.get_node("ApRow"))
	assert_not_null(s.get_node("ChallengeBoardPanel"))
	assert_not_null(s.get_node("HandRow"))
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 修改 .tscn**

新增 ApRow 节点（PanelContainer，水平 BoxContainer 内含 N 个 APBlockView 槽位 + Submit 按钮）。anchor_top=0.20 anchor_bottom=0.32（在 EnemyArea 下面，ChallengeBoardPanel 上面）。

布局重新分配：
- TopBar: 0 → 44px
- EnemyArea: 0.06 → 0.18
- ApRow: 0.20 → 0.32   ← NEW
- ChallengeBoardPanel: 0.34 → 0.58
- PlayerStatus: 0.59 → 0.65
- HandLabel: 0.66 → 0.69
- HandRow: 0.70 → 0.95
- ActionRow: 0.96 → 1.00

- [ ] **Step 4: 修改 battle_scene.gd**

```gdscript
@onready var _ap_row: HBoxContainer = $ApRow/HBox
@onready var _submit_button: Button = $ApRow/SubmitButton

func _ready():
	# ... 现有逻辑
	_submit_button.pressed.connect(_on_submit_pressed)
	_render_ap_row()

func _render_ap_row():
	for child in _ap_row.get_children():
		child.queue_free()
	for conn in _controller.ap_queue:
		var v = preload("res://src/battle/ap_block_view.tscn").instantiate()
		v.render(conn)
		v.reorder_requested.connect(_on_ap_reorder_requested)
		_ap_row.add_child(v)
	# 占位：空位
	for i in range(_controller.ap_queue.size(), _controller.ap_max + _controller.ap_bonus_next_turn):
		var empty = PanelContainer.new()
		var label = Label.new()
		label.text = "[%d]\n空" % (i + 1)
		empty.add_child(label)
		_ap_row.add_child(empty)

func _on_ap_reorder_requested(from_idx: int, to_idx: int):
	_controller.reorder_ap_queue(from_idx, to_idx)
	_render_ap_row()

func _on_submit_pressed():
	if _controller.ap_queue.is_empty():
		_set_status_hint("还没安排连线")
		return
	_controller.submit_all_ap()
	_render_all()  # 完整重渲染
```

- [ ] **Step 5: 测试通过 + 提交**

```bash
git add src/battle/battle_scene.tscn src/battle/battle_scene.gd \
       tests/test_battle_scene_layout.gd
git commit -m "feat(battle): rebuild battle scene to 3-layer UI with AP row"
```

---

### Task 16: 拖卡 → 题板 → 自动入 AP 队列

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/cards/card_view.gd`（加 _get_drag_data）

- [ ] **Step 1: 测试拖卡 -> 入 AP**

```gdscript
extends GutTest

func test_drop_card_on_slot_calls_add_to_ap_queue():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# 模拟卡 + 题
	# 模拟拖入
	# 断言 controller.ap_queue 增加一个
	pass
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现拖卡 + 槽位 _drop_data**

`src/battle/cards/card_view.gd` 加：
```gdscript
func _get_drag_data(_at_position: Vector2) -> Variant:
	if _card == null:
		return null
	return {"type": "card", "card_id": _card.id, "ref": _card}
```

`src/battle/battle_scene.gd` 中槽位 PanelContainer 加：
```gdscript
panel.set_meta("challenge_index", ch_idx)
panel.set_meta("slot_index", slot_idx)
panel._can_drop_data = func(_at_pos, data):
	return data is Dictionary and data.get("type") == "card"
panel._drop_data = func(_at_pos, data):
	var ch_i = panel.get_meta("challenge_index")
	var sl_i = panel.get_meta("slot_index")
	_controller.add_to_ap_queue(data.ref, ch_i, sl_i)
	_render_all()
```

实际不能 lambda override `_drop_data`；要在 panel 实例上写一个子类。简化方案：每个 slot panel 是 `SlotDropZone`（自定义 PanelContainer）。

- [ ] **Step 4: 测试**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_scene.gd src/battle/cards/card_view.gd
git commit -m "feat(battle): drag card from hand to challenge slot enqueues to AP"
```

---

### Task 17: 提交按钮 + 顺序播放动画

**Files:**
- Modify: `src/battle/battle_scene.gd`

- [ ] **Step 1: 写测试**

提交后的 UI 应：
- 按 slot_index 顺序逐个高亮 AP 块
- 每个 0.4s 间隔
- 错连开模态
- 全部结束 → 触发完美连击 floating text

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

```gdscript
func _on_submit_pressed():
	if _controller.ap_queue.is_empty():
		return
	# 禁用 UI
	_submit_button.disabled = true
	_disable_drag()
	# 顺序播放
	for i in _controller.ap_queue.size():
		var conn = _controller.ap_queue[i]
		_highlight_ap_block(i)
		await get_tree().create_timer(0.4).timeout
		# 这里只是动画；实际结算在 submit_all_ap 内
	# 真正提交（同步处理）
	_controller.submit_all_ap()
	_submit_button.disabled = false
	_enable_drag()
	_render_all()
```

- [ ] **Step 4: 测试**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_scene.gd
git commit -m "feat(battle): submit button with sequential AP block animation"
```

---

## Phase 5: 反馈系统

### Task 18: FeedbackSystem autoload

**Files:**
- Create: `src/feedback/feedback_system.gd`
- Test: `tests/test_feedback_system.gd`
- Modify: `project.godot`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const FeedbackSystemScript = preload("res://src/feedback/feedback_system.gd")

func _make() -> Node:
	var n = FeedbackSystemScript.new()
	add_child_autofree(n)
	n._persist_path_override = "user://test_feedback.jsonl"
	# 清空旧测试数据
	if FileAccess.file_exists(n._persist_path_override):
		DirAccess.remove_absolute(n._persist_path_override)
	return n

func test_report_writes_jsonl():
	var n = _make()
	n.report("question", "1F_emo", "answer_unreasonable", "正确答案不合理")
	var lines = n.get_all()
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["type"], "question")
	assert_eq(lines[0]["id"], "1F_emo")

func test_export_returns_valid_json():
	var n = _make()
	n.report("card", "card_brave", "meaning_wrong", "")
	var s = n.export_json()
	var parsed = JSON.parse_string(s)
	assert_not_null(parsed)
	assert_true(parsed is Array)

func test_clear_empties():
	var n = _make()
	n.report("question", "x", "other", "")
	assert_eq(n.get_all().size(), 1)
	n.clear()
	assert_eq(n.get_all().size(), 0)
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 实现**

`src/feedback/feedback_system.gd`:
```gdscript
## FeedbackSystem — autoload，记录玩家对题/卡/敌人的反馈
##
## 持久化：append-only JSON Lines @ user://feedback.jsonl
extends Node

const _DEFAULT_PATH := "user://feedback.jsonl"

var _persist_path_override: String = ""

func _path() -> String:
	return _persist_path_override if _persist_path_override != "" else _DEFAULT_PATH


func report(type: String, id: String, reason: String, comment: String = "") -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"type": type,
		"id": id,
		"reason": reason,
		"comment": comment,
	}
	var path := _path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("FeedbackSystem: cannot write " + path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(entry))
	f.close()


func get_all() -> Array:
	var path := _path()
	if not FileAccess.file_exists(path):
		return []
	var f = FileAccess.open(path, FileAccess.READ)
	var entries := []
	while not f.eof_reached():
		var line = f.get_line()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed:
			entries.append(parsed)
	f.close()
	return entries


func export_json() -> String:
	return JSON.stringify(get_all(), "  ")


func clear() -> void:
	var path := _path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
```

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 注册 autoload + 提交**

`project.godot`:
```
FeedbackSystem="*res://src/feedback/feedback_system.gd"
```

```bash
git add src/feedback/feedback_system.gd tests/test_feedback_system.gd project.godot
git commit -m "feat(feedback): add FeedbackSystem autoload + jsonl persistence"
```

---

### Task 19: FeedbackModal 弹窗

**Files:**
- Create: `src/feedback/feedback_modal.tscn`
- Create: `src/feedback/feedback_modal.gd`
- Test: `tests/test_feedback_modal.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

const FeedbackModalScene = preload("res://src/feedback/feedback_modal.tscn")

func test_setup_with_question():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	m.setup("question", "1F_emo", "I am very ___")
	assert_true(m.get_node("Card/VBox/HeaderLabel").text.contains("question"))

func test_submit_emits_signal():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	m.setup("question", "1F_emo", "I am very ___")
	var emitted = false
	var rec_type = ""
	m.submitted.connect(func(t, r, c): emitted = true; rec_type = t)
	m._on_submit("answer_unreasonable", "测试评论")
	assert_true(emitted)
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 创建 .tscn + .gd**

`src/feedback/feedback_modal.gd`:
```gdscript
## 反馈弹窗
extends Control

signal submitted(type: String, reason: String, comment: String)
signal canceled

var _type: String = ""
var _id: String = ""

@onready var _header: Label = $Card/VBox/HeaderLabel
@onready var _content: Label = $Card/VBox/ContentLabel
@onready var _reason_options: VBoxContainer = $Card/VBox/ReasonOptions
@onready var _comment: TextEdit = $Card/VBox/CommentEdit
@onready var _submit_btn: Button = $Card/VBox/HBox/SubmitButton
@onready var _cancel_btn: Button = $Card/VBox/HBox/CancelButton

const REASONS_QUESTION := [
	{"id": "dialogue_unclear", "label": "题目描述不清"},
	{"id": "answer_unreasonable", "label": "答案不合理"},
	{"id": "translation_wrong", "label": "中文翻译有错"},
	{"id": "audio_missing", "label": "音频缺失/错误"},
	{"id": "other", "label": "其他"},
]

func _ready():
	_submit_btn.pressed.connect(_on_submit_clicked)
	_cancel_btn.pressed.connect(func(): canceled.emit(); queue_free())


func setup(type: String, id: String, content: String) -> void:
	_type = type
	_id = id
	_header.text = "🚩 反馈这%s" % ("题" if type == "question" else "卡")
	_content.text = content
	for child in _reason_options.get_children():
		child.queue_free()
	for r in REASONS_QUESTION:
		var btn = CheckBox.new()
		btn.text = r.label
		btn.set_meta("reason_id", r.id)
		_reason_options.add_child(btn)


func _on_submit_clicked():
	var picked = ""
	for child in _reason_options.get_children():
		if child is CheckBox and child.button_pressed:
			picked = child.get_meta("reason_id")
			break
	_on_submit(picked, _comment.text)


func _on_submit(reason: String, comment: String) -> void:
	submitted.emit(_type, reason, comment)
	# autoload 写入
	if Engine.has_singleton("FeedbackSystem"):
		FeedbackSystem.report(_type, _id, reason, comment)
	queue_free()
```

`feedback_modal.tscn`：CanvasLayer + Control（PRESET_FULL_RECT, 半透明黑底）+ Card（中央）

- [ ] **Step 4: 测试通过**

- [ ] **Step 5: 提交**

```bash
git add src/feedback/feedback_modal.gd src/feedback/feedback_modal.tscn \
       tests/test_feedback_modal.gd
git commit -m "feat(feedback): add FeedbackModal scene with reason picker"
```

---

### Task 20: 战斗中 🚩 按钮 + 设置页导出

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/ui/settings_scene.tscn` + `.gd`

- [ ] **Step 1: 写测试**

```gdscript
extends GutTest

func test_flag_button_opens_modal():
	# 战斗场景每个题面板有 🚩 按钮
	# 点击 → 弹 FeedbackModal
	pass

func test_settings_export_button_returns_json():
	# 设置页 [导出反馈] 按钮 → 拷贝 JSON 到剪贴板
	pass
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: 战斗场景加 🚩 按钮**

In `_make_challenge_card`：
```gdscript
var flag_btn := Button.new()
flag_btn.text = "🚩"
flag_btn.flat = true
flag_btn.pressed.connect(_on_flag_pressed.bind(challenge.template))
header.add_child(flag_btn)

func _on_flag_pressed(template: ChallengeTemplate):
	var modal = preload("res://src/feedback/feedback_modal.tscn").instantiate()
	get_tree().root.add_child(modal)
	modal.setup("question", template.template_id, template.dialogue)
```

In `src/ui/settings_scene.tscn`：加 [导出反馈] 按钮。

In `src/ui/settings_scene.gd`：
```gdscript
func _on_export_feedback_pressed():
	var json = FeedbackSystem.export_json()
	DisplayServer.clipboard_set(json)
	OS.alert("反馈数据已复制到剪贴板，请粘贴到给开发者的反馈邮件中。", "导出成功")
```

- [ ] **Step 4: 测试**

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_scene.gd src/ui/settings_scene.tscn src/ui/settings_scene.gd
git commit -m "feat(feedback): add 🚩 button in battle + export in settings"
```

---

## Phase 6: 构建 + 部署

### Task 21: download_voice_deps.sh

**Files:**
- Create: `scripts/download_voice_deps.sh`

- [ ] **Step 1: 写脚本**

```bash
#!/bin/bash
# 下载 Piper TTS + whisper.cpp 二进制 + 模型，置入 builds/voice/
set -e

cd "$(dirname "$0")/.."
mkdir -p builds/voice/piper/models builds/voice/whisper/models

# Piper for macOS x64
PIPER_VERSION=2023.11.14-2
if [ ! -f builds/voice/piper/piper ]; then
    echo "Downloading Piper..."
    curl -L "https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_macos_x64.tar.gz" \
         -o /tmp/piper.tar.gz
    tar xzf /tmp/piper.tar.gz -C builds/voice/
    chmod +x builds/voice/piper/piper
fi

# Piper en_US-lessac-medium model
if [ ! -f builds/voice/piper/models/en_US-lessac-medium.onnx ]; then
    echo "Downloading Piper model..."
    curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx" \
         -o builds/voice/piper/models/en_US-lessac-medium.onnx
    curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" \
         -o builds/voice/piper/models/en_US-lessac-medium.onnx.json
fi

# whisper.cpp binary (macOS prebuilt)
if [ ! -f builds/voice/whisper/whisper-cli ]; then
    echo "Downloading whisper.cpp..."
    # 注：实际仓库可能不直接提供 macOS 预编译；这里示意
    curl -L "https://github.com/ggerganov/whisper.cpp/releases/download/v1.5.4/whisper-cpp-macos-x64.tar.gz" \
         -o /tmp/whisper.tar.gz || {
        echo "Falling back to building whisper.cpp from source"
        git clone https://github.com/ggerganov/whisper.cpp /tmp/whisper.cpp
        cd /tmp/whisper.cpp && make
        cp main "$OLDPWD/builds/voice/whisper/whisper-cli"
        cd "$OLDPWD"
    }
    [ -f /tmp/whisper.tar.gz ] && tar xzf /tmp/whisper.tar.gz -C builds/voice/whisper/
    chmod +x builds/voice/whisper/whisper-cli
fi

# Whisper tiny.en model
if [ ! -f builds/voice/whisper/models/ggml-tiny.en.bin ]; then
    echo "Downloading Whisper tiny.en..."
    curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin" \
         -o builds/voice/whisper/models/ggml-tiny.en.bin
fi

echo "Voice deps ready in builds/voice/"
ls -la builds/voice/piper/ builds/voice/whisper/
```

- [ ] **Step 2: 跑一次**

```bash
chmod +x scripts/download_voice_deps.sh
bash scripts/download_voice_deps.sh
ls builds/voice/
```

Expected: 看到 piper 和 whisper 都在

- [ ] **Step 3: 提交**

```bash
git add scripts/download_voice_deps.sh
git commit -m "build: add download_voice_deps.sh for Piper + whisper.cpp binaries"
```

---

### Task 22: build.sh 集成 voice 资源

**Files:**
- Modify: `build.sh`
- Modify: `export_presets.cfg`（导出时含 voice）

- [ ] **Step 1: 修改 build.sh**

在 `export_mac()` 前加：
```bash
ensure_voice_deps() {
    if [ ! -f "$PROJECT_DIR/builds/voice/piper/piper" ]; then
        echo "Voice deps missing, downloading..."
        bash "$PROJECT_DIR/scripts/download_voice_deps.sh"
    fi
}
# ... 在 check_godot 之后
ensure_voice_deps
```

After Godot export to .app, 复制 voice 文件夹到 `app/Contents/Resources/voice/`：
```bash
# 在 export_mac() 内 hdiutil convert 之前：
APP_DIR="$STAGING/知识神塔.app"
mkdir -p "$APP_DIR/Contents/Resources/voice"
cp -R "$PROJECT_DIR/builds/voice/piper" "$APP_DIR/Contents/Resources/voice/"
cp -R "$PROJECT_DIR/builds/voice/whisper" "$APP_DIR/Contents/Resources/voice/"
```

- [ ] **Step 2: 跑一次 build**

```bash
./build.sh mac
```

Expected: dmg 含 voice 目录，~220MB

- [ ] **Step 3: 验证**

挂载 dmg，检查 .app/Contents/Resources/voice/piper/piper 存在。

- [ ] **Step 4: 提交**

```bash
git add build.sh
git commit -m "build: include voice resources (piper + whisper) in macOS dmg"
```

---

## Phase 7: 集成 + 收尾

### Task 23: 完整链路集成测试

**Files:**
- Test: `tests/test_e2e_battle_flow.gd`

- [ ] **Step 1: 写完整集成测试**

```gdscript
extends GutTest
## 端到端：从战斗开始到完美连击 → 下回合 +1 AP

func test_full_battle_flow():
	# 1. setup BattleController + mock pack/enemy/deck
	# 2. start_battle → 题板补 3 题
	# 3. 把 3 张正确卡 add_to_ap_queue
	# 4. submit_all_ap
	# 5. 断言：3 题清空、enemy 受伤、ap_bonus_next_turn = 1
	# 6. 进下一回合
	# 7. 断言：available AP slots = ap_max + ap_bonus_next_turn
	pass
```

- [ ] **Step 2: 写完测试通过**

- [ ] **Step 3: 提交**

```bash
git add tests/test_e2e_battle_flow.gd
git commit -m "test: e2e battle flow integration test"
```

---

### Task 24: 全套测试 + dmg 验证

- [ ] **Step 1: 跑全部测试**

```bash
/opt/homebrew/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gexit 2>&1 | tail -10
```

Expected: ≥ 388 通过

- [ ] **Step 2: 跑构建**

```bash
rm -rf ~/Library/Application\ Support/Godot/app_userdata/知识神塔/
./build.sh mac
```

Expected: dmg ~220MB

- [ ] **Step 3: 挂载验证**

```bash
hdiutil attach builds/mac/知识神塔.dmg
ls /Volumes/知识神塔/知识神塔.app/Contents/Resources/voice/
```

- [ ] **Step 4: 写收尾文档**

更新 `docs/architecture.md` 加 voice + AP queue 章节。

- [ ] **Step 5: 提交**

```bash
git add docs/architecture.md
git commit -m "docs: update architecture with AP queue + voice backends"
```

---

## 验收清单

实施完成时验证：

- [ ] AP 顺序条 + 题板 + 手牌三层 UI 渲染正常，无重叠
- [ ] 拖卡到题 → 自动占用下一个 AP 槽位
- [ ] AP 块拖动 → 重排顺序生效
- [ ] 提交 → 按顺序逐条结算 + 动画
- [ ] 错连 → 答错模态显示中文释义 + 例句
- [ ] 全对 → 完美连击 floating text + 下回合 ap_max + 1
- [ ] 多槽题 → 占多 AP，全槽对才触发题效果
- [ ] 题板填不满 → 降级用全 pool 标 🟡 略难
- [ ] 听力题 🔊 → Piper 合成（命中缓存即时）
- [ ] 题板 🚩 → 反馈模态 → user://feedback.jsonl 多一行
- [ ] 设置页"导出反馈"→ 剪贴板含 JSON
- [ ] dmg 内 voice/piper/piper 二进制 + onnx 模型存在
- [ ] dmg 内 voice/whisper/whisper-cli 二进制 + ggml 模型存在
- [ ] 全套 GUT 测试通过 ≥ 388 条
- [ ] dmg 包体 ~ 220 MB
