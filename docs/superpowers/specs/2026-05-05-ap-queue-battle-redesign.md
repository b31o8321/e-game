# AP 队列战斗系统 + 本地语音后端 — 知识神塔

> 状态：v1（玩家头脑风暴定型）
> 上下文：替换现有"线性多选题战斗"为**有序 AP 队列连线战斗**；引入本地 TTS/STT（Piper + whisper.cpp）；修复卡手 bug；加玩家反馈系统。

---

## 设计目标

1. **连线机制**：手牌 + 题板同框，玩家拖卡到题上建立"连线"，连线本身就是出牌
2. **AP 队列**：每回合 N 个有序槽位（默认 3），buff 类放前面让后续攻击受益
3. **完美连击**：所有连线都对 → 下回合 +1 AP（滚雪球激励）
4. **专业本地语音**：MVP 用 Piper（TTS）+ whisper.cpp（STT），抽象后端接口预留 Coqui/SpeechBrain 升级路径
5. **零卡手**：题板填充失败时降级用全 pool（标"略难"）
6. **玩家反馈**：每题旁有 🚩 按钮，反馈持久化到 jsonl 供开发者优化

非目标：
- ❌ MVP 不做 Coqui/SpeechBrain（包体太大，Phase 3 处理）
- ❌ MVP 不做"完整口语题战斗"（Whisper API 接口预留，实战集成 Phase 3）
- ❌ 不改现有内容包数据格式（卡片/题目数据兼容）

---

## 核心机制：AP 队列连线战斗

### 战斗界面三层结构

```
┌────────────────────────────────────────────────────┐
│  TopBar: 楼层 / Act / 战斗 N/M  [📜日志] [⚙撤退]    │
├────────────────────────────────────────────────────┤
│  EnemyArea: 立绘 / HP / 弱点 / 能力图标             │
├────────────────────────────────────────────────────┤
│  AP 执行队列（顺序条）：                             │
│   [1] ──→ [2] ──→ [3]    [⚙ 重排] [🎯 提交]         │
│    ⚡buff   ⚔攻击   ⚔攻击                            │
│    Q3       Q1     Q2     ← 题                       │
│    the      brave  is     ← 卡                       │
├────────────────────────────────────────────────────┤
│  题板（3 题，每题可点 🚩 反馈 / 📌 留下）：           │
│   ┌Q1─🚩─📌─┐ ┌Q2─🚩─📌─┐ ┌Q3─🚩─📌─┐              │
│   │I am ___│ │She is __│ │___-t   │                │
│   │⚔ 卡攻击 │ │💚 治疗+15│ │⚡ buff │                │
│   └────────┘ └────────┘ └────────┘                  │
├────────────────────────────────────────────────────┤
│  PlayerStatus: 守护者 HP / 🛡盾 / 连击 / 词晶        │
├────────────────────────────────────────────────────┤
│  手牌（5 张，可右键 📌 保留 ≤3）：                   │
│   [brave] [is] [the] [run] [a]                      │
│  💡 拖卡到题，进入下个 AP；拖 AP 块重排              │
└────────────────────────────────────────────────────┘
```

### 资源系统

| 资源 | 默认 | 上限/扩展机制 |
|------|------|------------|
| AP 槽位 | 3 | 装备/技能至 5；完美连击下回合 +1 |
| 手牌容量 | 5 | 装备 +1 / +2 |
| 手牌 📌 保留 | ≤3 | 装备至 5 |
| 题 📌 留下 | ≤1 | 装备至 3 |
| 卡片消耗 | 用过即弃 | — |
| 题目效果 | 多种（攻击/治疗/护盾/抽题/抽卡/连击充能/弱点克制）| 题目数据决定 |

### 一回合完整流程

```
A. 回合开始
   1. 抽手牌至 HAND_SIZE（kept-question-aware：先保证 kept 题答案在手）
   2. 题板补满 BOARD_SIZE（hand-aware；不够 → 降级 unfiltered pool 标"略难"）
   3. 重置 AP 队列（默认 3 槽，完美连击 +1 临时槽）

B. 规划阶段（无副作用）
   1. 玩家拖手牌到题的某个槽位
      → 自动占用下一个空 AP 槽位
      → 多槽题需多 AP（每槽 1 AP，全槽都对才触发题效果）
   2. 玩家拖 AP 队列方块 → 重排顺序
   3. 玩家可点 AP 块 → 撤销该连线（卡回手）
   4. 玩家可标 📌 留下题 / 📌 保留卡（限额内）
   5. 玩家可点 🚩 → 反馈弹窗
   6. 实时显示预览：AP 队列每条连线展示预估伤害/效果

C. 提交结算（点提交按钮）
   按 AP 槽位顺序 1 → 2 → 3 ... 逐条结算：
     for each connection:
       if validator.can_place(card, slot):
         apply card.ability_pre_submit
         mark slot as filled
         if 该 connection 是题最后一个槽 + 该题所有槽都对:
           apply ChallengeEffects(template).result
           question.consumed → 题板腾出
       else:
         弹答错模态（中文释义 / 例句 / 正确答案）
         question.failed → 灰显锁定
       card → discard pile
   所有连线播完 →

D. 完美评估
   if all connections in queue 都对:
     设置 next_turn_ap_bonus = 1
     界面飘字 "完美连击！下回合 +1 AP"

E. 敌人回合
   1. 触发敌方 turn_start ability（regen/shield/extra_action）
   2. 敌人攻击 N 次（多动 ability 的 N）
   3. 玩家护盾抵伤 → HP 扣减
   4. 触发玩家 ability turn_end（hook 留位，MVP 暂空）

F. 回合结束
   1. 弃手非 📌 卡到 discard pile
   2. 题板：📌 题保留；非 📌 失败题清；其余按情况
   3. 进入下一回合 A
```

### 多槽题处理

例：`"She is so ___ but he is ___"` 两个槽都要 positive_personality。
- 占用 2 个 AP 槽位
- 玩家在题上各放一张卡（连续/分开均可）
- 提交时：两条连线分别结算
  - 第 1 条对 / 第 2 条错 → 题失败（仍弹错卡的答错模态）
  - 两条都对 → 触发题效果

### 题目效果与卡片能力叠加（沿用现有）

```
final_damage = (sum(card.base_damage * mastery) * card_modifier * combo_modifier * weakness_modifier)
final_effects = card_abilities (apply_pre_submit) + question.effect_type
```

详见现有 `damage_calculator.gd` / `card_abilities.gd` / `challenge_effects.gd`，**不变**。

---

## TTS/STT 后端抽象

### 接口

```gdscript
# 引擎层
class_name IVoiceTtsBackend extends RefCounted
    func is_available() -> bool: pass
    func get_id() -> String: pass
    func synthesize(text: String, lang: String = "en") -> AudioStream: pass  # await-able
    func get_cache_path(text: String, lang: String) -> String: pass

class_name IVoiceSttBackend extends RefCounted
    func is_available() -> bool: pass
    func get_id() -> String: pass
    func transcribe(audio: AudioStream, lang: String = "en") -> String: pass

# 路由器
class_name VoiceClient extends Node
    var tts_backend: IVoiceTtsBackend
    var stt_backend: IVoiceSttBackend
    
    func tts(text, lang) -> AudioStream  # 自动缓存 + 回退
    func stt(audio, lang) -> String
    func switch_backend(tts_id, stt_id)
```

### MVP 后端实现

**TTS — Piper（默认）：**
- 二进制 + onnxruntime + 一个中等模型（en_US-lessac-medium ~50MB）
- 路径：`{app_resources}/piper/piper` + `{app_resources}/piper/models/`
- 调用：`OS.execute("piper", ["--model", model_path, "--output_file", out_wav], stdin=text)`
- 缓存：`user://tts_cache/<sha256(text+lang)>.wav`
- 首次合成 ~50-150ms；缓存命中 ~10ms

**STT — whisper.cpp（默认）：**
- 二进制 + ggml 模型（tiny.en 或 base.en，~75-150MB）
- 路径：`{app_resources}/whisper/whisper-cli`
- 调用：`OS.execute("whisper-cli", ["-m", model_path, "-f", input_wav, "-otxt"])`
- 解析 stdout → transcript
- 首次 ~500ms-2s（取决于音频长度 + 模型）

**StubBackend（开发/兜底）：**
- TTS：返回静音 AudioStreamWAV
- STT：返回 target_phrase（success path）
- 当 Piper / whisper-cli 不可用时自动切换

**LocalMp3CacheBackend（兼容现有）：**
- 读取 `src/content/english/audio/words/*.mp3`
- TTS 退路 1：先查文件 → 命中即返回
- 适合内置词表

### 后端选择策略

```
启动时:
  扫描 {app_resources}/piper/ → 存在 → tts_backend = PiperBackend
  扫描 {app_resources}/whisper/ → 存在 → stt_backend = WhisperBackend
  否则:
    检查 settings.openai_api_key
      → 设了 → 用 OpenAITtsBackend / WhisperApiBackend
      → 没设 → tts_backend = LocalMp3CacheBackend；stt_backend = StubBackend
  
设置页可手动切换。
```

### 包体影响（macOS 估算）

| 项 | 大小 |
|---|------|
| 当前 dmg | 67 MB |
| Piper 二进制 + onnxruntime | +25 MB |
| Piper 模型 lessac-medium | +50 MB |
| whisper-cli 二进制 | +5 MB |
| ggml-tiny.en.bin | +75 MB |
| **新 dmg 估算** | **~220 MB** |

### Phase 3 升级路径（接口已留）

```gdscript
# 未来：
class CoquiTtsBackend extends IVoiceTtsBackend:
    # 通过 Python sidecar HTTP 服务器
    func synthesize(text, lang):
        return await http_post("http://127.0.0.1:5555/tts", text)

class SpeechBrainSttBackend extends IVoiceSttBackend:
    # 同 sidecar 不同端点
    ...
```

只需新增类 + 切换 `voice_client.switch_backend("coqui", "speechbrain")`，**核心引擎零改动**。

---

## 卡手 bug 修复

```gdscript
func refill_board() -> void:
    var pool = pack.get_challenges_for_topic(_enemy.topic_id)
    var solvable = pool.filter(_can_solve_with_hand)
    
    var keepers = available_challenges.filter(_is_kept)
    var slots_needed = BOARD_SIZE - keepers.size()
    
    var fill: Array[Challenge] = []
    
    if solvable.size() >= slots_needed:
        # 正常分支：全部从 solvable 抽
        fill = _pick_random(solvable, slots_needed)
    else:
        # 降级：solvable 不够 → 先全用 solvable 再补 unfiltered
        fill = solvable.duplicate()
        var rest = pool.filter(p => not (p in solvable))
        fill.append_array(_pick_random(rest, slots_needed - solvable.size()))
        # 标记降级题
        for ch in fill:
            ch.is_warn = (ch.template not in solvable)
    
    available_challenges = keepers + fill

# UI 渲染时：if challenge.is_warn → 显示 🟡 "略难" badge
```

效果：
- 题板**绝不全空**（除非 pool 整个为 0，那是数据 bug）
- 玩家看到"略难"标记知道这题可能没解，自行决定是 留下 / 失败 / 跳过

---

## 玩家反馈系统

### 数据存储

`user://feedback.jsonl`（append-only JSON Lines）

每条：
```json
{
  "timestamp": "2026-05-05T13:45:30Z",
  "type": "question",
  "id": "1F_emotion_blank_v1",
  "reason": "answer_unclear",
  "comment": "正确答案 brave 和 happy 应该都通"
}
```

`type` 枚举：`question` / `card` / `enemy` / `boss` / `general`
`reason` 枚举（与 type 联动）：
- question: `dialogue_unclear` / `answer_unreasonable` / `translation_wrong` / `audio_missing` / `other`
- card: `meaning_wrong` / `tag_wrong` / `pronunciation_wrong` / `other`

### UI

**战斗中：**
每个题面板加 🚩 按钮（与 📌 同行）
点击 → 弹模态：

```
┌─────────────────────────────┐
│  🚩 反馈这题                 │
├─────────────────────────────┤
│  题目 ID：1F_emotion_blank   │
│  题干："I am very ___"       │
│                              │
│  问题类型：                   │
│  ◯ 题目描述不清               │
│  ◯ 答案不合理                 │
│  ◯ 中文翻译有错               │
│  ◯ 音频缺失/错误              │
│  ◯ 其他                       │
│                              │
│  备注（选填）：                │
│  ┌───────────────────────┐   │
│  │                        │   │
│  └───────────────────────┘   │
│                              │
│  [提交]   [取消]              │
└─────────────────────────────┘
```

**设置页：**
新增"反馈管理"标签页：
- 显示历史反馈条数
- [导出 JSON] 按钮 → 复制到剪贴板 / 保存到桌面
- [清空] 按钮（带确认）

---

## 数据结构改动

### 新增 / 修改

```gdscript
# 战斗状态：
class BattleController:
    # 新增
    var ap_queue: Array[APConnection] = []
    var ap_max: int = 3
    var ap_bonus_next_turn: int = 0    # 完美连击的临时 +1
    var pending_perfect_combo: bool = true  # 默认 true，遇到错变 false
    
    # 现有保留
    var available_challenges, kept_template_ids, _hand, _retained_card_ids ...

class APConnection:
    var slot_index: int           # 当前在队列的位置（0-based）
    var card: Card
    var challenge_index: int       # 题板上哪道题
    var question_slot_index: int   # 题里的具体槽位
    var preview: Dictionary        # {damage: 12, effect: "heal+15", note: "..."}

# 题数据加：
class ChallengeTemplate:
    # 现有保留
    # 新增（运行时态）：
    var is_warn: bool = false      # 降级标记，渲染时显示 🟡

# 反馈：
class FeedbackSystem extends Node:
    func report(type: String, id: String, reason: String, comment: String)
    func get_all() -> Array[Dictionary]
    func export_json() -> String
    func clear() -> void
```

### 现有迁移

| 现有概念 | 新概念 | 改动 |
|---------|--------|------|
| `submit_challenge(idx)` | `submit_all_ap()` | 改为批量结算 |
| `try_place_card(card, slot, ch_idx)` | `add_to_ap_queue(card, ch_idx, slot_idx)` | 改为入队，不立即生效 |
| 立即结算单题 | 提交后顺序结算 | 行为变化 |
| 错卡红闪退回 | 入队预览 + 提交时验证 | 错的也先入队，提交才暴露 |

---

## UI 拖拽实现

Godot 4.6 内建 `Control._get_drag_data` / `_can_drop_data` / `_drop_data`：

```gdscript
# 手牌卡 (CardView)
func _get_drag_data(at_position):
    return {"type": "card", "card_id": _card.id, "ref": _card}

# 题板槽位 (SlotPanel)
func _can_drop_data(at_position, data):
    return data.get("type") == "card" and _is_empty
func _drop_data(at_position, data):
    BattleController.add_to_ap_queue(data.ref, _challenge_idx, _slot_idx)

# AP 队列方块 (ApBlockView)
func _get_drag_data(at_position):
    return {"type": "ap_block", "from_index": _slot_index}
func _can_drop_data(at_position, data):
    return data.get("type") == "ap_block"
func _drop_data(at_position, data):
    BattleController.reorder_ap(data.from_index, _slot_index)
```

---

## 测试策略

### 单元测试

`tests/test_ap_queue.gd`:
- add_to_ap_queue 顺序入队
- 队列满 → 拒绝新连接
- remove + 卡回手
- reorder 调换顺序
- submit_all 顺序触发
- buff 在前 → 后续攻击受益
- 完美连击 next_turn_ap_bonus = 1
- 错连不影响后续对的连接

`tests/test_voice_backends.gd`:
- IVoiceTtsBackend 接口契约
- StubBackend 返回静音 AudioStream
- LocalMp3CacheBackend 命中已有文件
- VoiceClient 自动选择 + 回退

`tests/test_feedback_system.gd`:
- report 写 jsonl
- get_all 读所有
- export_json 格式正确
- clear 清空

### 集成测试

- 完整一回合：抽牌 → 规划 3 连线 → 提交 → 结算 → 完美 → 下回合 +1 AP
- 错连场景：1 对 2 错 → 部分效果 + 2 个答错模态 → combo 0 (没奖励)
- 题板降级：手牌空匹配池子 → 标"略难"显示 → 强行答错也走流程
- TTS：调用 → 缓存写入 → 第二次命中缓存

### 手动测试

- macOS: 完整一局走通到 Boss
- 拖拽手感：手牌 → 题板 → AP 自动入队
- AP 重排：上下/左右拖动
- 反馈按钮：弹窗 → 提交 → 保存到 jsonl
- 切换 TTS 后端：设置里换 PiperBackend ↔ StubBackend

---

## 现有代码影响

| 文件 | 处置 |
|------|------|
| `src/battle/battle_controller.gd` | **大改**：加 ap_queue 状态机 + submit_all |
| `src/battle/battle_scene.gd` + `.tscn` | **大改**：3 层 UI（AP 顺序条 + 题板 + 手牌）+ 拖拽 |
| `src/battle/cards/card_view.gd` | **改**：加 `_get_drag_data` |
| `src/battle/challenge_*` | 保留 + 加拖入逻辑 |
| `src/battle/damage_calculator.gd` | 保留（伤害公式不变）|
| `src/battle/card_abilities.gd` | 保留（apply_pre_submit 接入新流程）|
| `src/battle/challenge_effects.gd` | 保留 |
| `src/battle/wrong_answer_modal.gd` | 保留（每条错连接独立调用）|
| `src/run/run_state.gd` | 加 next_turn_ap_bonus 持久化 |

新增：
- `src/voice/i_voice_tts_backend.gd` + `i_voice_stt_backend.gd`
- `src/voice/voice_client.gd`（autoload）
- `src/voice/piper_tts_backend.gd`
- `src/voice/whisper_cpp_stt_backend.gd`
- `src/voice/local_mp3_cache_backend.gd`
- `src/voice/stub_backends.gd`
- `src/feedback/feedback_system.gd`（autoload）
- `src/feedback/feedback_modal.tscn` + `.gd`
- `src/battle/ap_queue.gd`
- `src/battle/ap_connection.gd`
- `src/battle/ap_block_view.tscn` + `.gd`

---

## 打包与依赖

### 二进制下载脚本

`scripts/download_voice_deps.sh`：
```bash
# Piper for macOS
curl -L https://github.com/rhasspy/piper/releases/.../piper_macos_x86_64.tar.gz -o piper.tar.gz
tar xzf piper.tar.gz -C builds/voice/

# Piper model
curl -L https://huggingface.co/rhasspy/.../en_US-lessac-medium.onnx -o builds/voice/models/en_US-lessac-medium.onnx
curl -L https://huggingface.co/rhasspy/.../en_US-lessac-medium.onnx.json -o builds/voice/models/en_US-lessac-medium.onnx.json

# whisper.cpp
curl -L https://github.com/ggerganov/whisper.cpp/releases/.../whisper-cli-macos.zip -o whisper.zip
unzip whisper.zip -d builds/voice/

# Whisper model
curl -L https://huggingface.co/ggerganov/.../ggml-tiny.en.bin -o builds/voice/models/ggml-tiny.en.bin
```

`build.sh` 改：
```bash
# 在 export 前确保 voice 二进制就位
[ ! -d builds/voice/piper ] && bash scripts/download_voice_deps.sh

# Godot 导出预设里把 builds/voice/* 标记为 "include in pack"
# 或：复制到 .app/Contents/Resources/voice/
```

### Godot 路径解析

```gdscript
# 运行时定位:
func _get_voice_dir() -> String:
    if OS.has_feature("editor"):
        return "res://builds/voice/"
    var exe_dir = OS.get_executable_path().get_base_dir()
    return exe_dir.path_join("../Resources/voice/")  # macOS .app
    # Windows: exe_dir.path_join("voice/")
    # Linux: exe_dir.path_join("voice/")
```

---

## MVP 范围

### 必做（这一刀）

- AP 队列系统：拖卡入队 / 重排 / 提交批量结算 / 错连模态
- 完美连击下回合 +1 AP buff
- buff/attack 顺序敏感执行
- IVoiceTtsBackend / IVoiceSttBackend 抽象
- PiperTtsBackend 实现 + 缓存
- WhisperCppSttBackend 实现 + 缓存（接口实现，集成到口语题留 Phase 3）
- LocalMp3CacheBackend + StubBackend（兜底）
- 题板降级填充（修卡手）
- FeedbackSystem 全套（autoload + 反馈模态 + 设置页导出）
- build.sh 集成 voice 二进制 + 模型
- 单元测试 + 集成测试

### 推迟

- Coqui/SpeechBrain 后端实现（Phase 3）
- 真口语题战斗机制（Phase 3）
- 反馈数据可视化看板（Phase 3）
- 多语言切换（仅英语 / 中文 MVP）
- 玩家技能 ability 实际效果（仅留 hook）

---

## 验收标准

- [ ] 玩家进入战斗后看到 AP 顺序条 + 题板 + 手牌三层 UI
- [ ] 拖手牌到题上 → 自动占用下一个 AP 槽位
- [ ] 拖 AP 槽位方块 → 重排顺序
- [ ] 点提交 → 按顺序逐条结算（buff 先，攻击后）
- [ ] 错连 → 弹答错模态显示正解，不影响后续对连
- [ ] 全对一回合 → 下回合实际多 1 AP 槽位
- [ ] 题板填不满时显示"略难"标
- [ ] 听力题点 🔊 → Piper 合成 + 播放（命中缓存即时）
- [ ] 题旁 🚩 → 反馈模态 → 提交 → user://feedback.jsonl 出现一行
- [ ] 设置页"反馈管理"可导出 JSON
- [ ] 单测 ≥ 350 通过（基线 348 + 新增 ~40 = 388）
- [ ] dmg 包体 ≤ 250 MB
- [ ] 完整一局通关时长 15-20 分钟

---

## 工作量

| 模块 | 代码 | 测试 |
|------|------|------|
| AP 队列状态机 | ~250 行 | 12 |
| 拖拽 UI | ~300 行 | 5 |
| AP 块视图 + 重排 | ~150 行 | 3 |
| 提交批量结算 | ~120 行 | 8 |
| 完美连击 buff | ~50 行 | 3 |
| Piper backend | ~150 行 | 4 |
| whisper.cpp backend | ~150 行 | 4 |
| Stub + Local backend | ~100 行 | 3 |
| VoiceClient 路由 | ~80 行 | 3 |
| FeedbackSystem | ~100 行 | 4 |
| 反馈模态 UI | ~120 行 | 2 |
| 题板降级 | ~50 行 | 3 |
| build.sh + 下载脚本 | ~80 行 bash | — |
| **总计** | **~1700 行** | **~54 测试** |
