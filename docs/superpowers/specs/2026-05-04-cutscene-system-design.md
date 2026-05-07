# Cutscene 系统设计 — 知识神塔（引擎层）

> 状态：v1（接口定型，集成点确定）
> 上下文：本 spec 与战斗 / Run / 知识城 / 内容包接口 spec 并列。引擎层"通用剧情面板播放器"，**完全不含具体故事内容**——所有剧情数据由内容包提供。

---

## 设计目标

- **引擎层零具体内容**：不写死任何角色、台词、世界观；仅提供"播放面板"的通用机制。
- **内容包驱动**：剧情面板数据（图、文、立绘、BGM）全部来自当前激活的 ContentPack。
- **统一格式**：开篇 / 楼层简介 / Boss 战前后 / 通关结局 / NPC 对话**全部用同一种面板结构**。
- **可跳过、可重读**：玩家可任意时刻跳过整段剧情；已读剧情入图鉴可重看。
- **多手段触发**：点击 / 自动 N 秒 / 按继续键，可由内容指定。

---

## 面板数据结构

### CutscenePanel（资源类）

```gdscript
class_name CutscenePanel extends Resource

@export var id: String                       # "intro_1"
@export var background_image_path: String    # 满屏背景图（可空，沿用上一张）
@export var background_color: Color = Color.BLACK
@export var bgm_path: String                 # 播放此面板时切换 BGM（可空，沿用）
@export var sfx_path: String                 # 进入面板时播放音效（可空）

# 立绘（一张面板支持最多 2 个角色立绘）
@export var portrait_left_path: String       # 可空
@export var portrait_left_emotion: String    # "normal" / "happy" / "sad" / "angry"
@export var portrait_right_path: String
@export var portrait_right_emotion: String

# 文本
@export var speaker_name: String             # 空 = 旁白模式
@export var speaker_position: String         # "left" / "right" / "center" / ""
@export var text: String                     # 主文本（支持 BBCode）
@export var text_speed: float = 30.0         # 字/秒；0 = 全部立即显示

# 进入/离开转场
@export var transition_in: String            # "fade" / "slide" / "instant"
@export var transition_out: String

# 推进
@export var advance_on: String               # "click" / "auto_3s" / "auto_5s" / "auto_<n>s"
@export var next_panel_id: String            # 下一面板；空 = 序列结束

# 元数据
@export var lore_codex_id: String            # 解锁此剧情图鉴条目（空 = 不入图鉴）
@export var tags: Array[String]              # ["main_story", "boss_dialogue", ...]
```

### 面板序列（JSON 持久化格式）

```jsonc
[
  {
    "id": "intro_1",
    "background_image_path": "res://content/english/assets/lore/intro_1.png",
    "bgm_path": "res://content/english/audio/bgm/prologue.ogg",
    "speaker_name": "",
    "text": "很久以前，世界上有一座知识神塔。",
    "advance_on": "click",
    "next_panel_id": "intro_2",
    "lore_codex_id": "lore_intro"
  },
  {
    "id": "intro_2",
    "background_image_path": "res://content/english/assets/lore/intro_2.png",
    "speaker_name": "",
    "text": "直到一天，遗忘之主降临。",
    "transition_in": "fade",
    "advance_on": "click",
    "next_panel_id": "intro_3"
  }
]
```

---

## CutscenePlayer 系统

### 节点

```gdscript
class_name CutscenePlayer extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)
signal panel_advanced(panel_id: String)
signal cutscene_skipped(cutscene_id: String)

var _scene_instance: CutsceneScene = null
var _current_panels: Array[CutscenePanel] = []
var _current_index: int = 0
var _cutscene_id: String = ""

# 主入口
func play(cutscene_id: String, panels: Array[CutscenePanel]) -> void:
    _cutscene_id = cutscene_id
    _current_panels = panels
    _current_index = 0
    _ensure_scene_loaded()
    cutscene_started.emit(cutscene_id)
    _show_current_panel()

func skip() -> void:
    if _current_panels.is_empty(): return
    _record_remaining_codex_entries()
    cutscene_skipped.emit(_cutscene_id)
    _finish()

func advance() -> void:
    if _current_index >= _current_panels.size() - 1:
        _finish()
        return
    _current_index += 1
    _show_current_panel()

# 内部
func _show_current_panel() -> void:
    var panel = _current_panels[_current_index]
    _scene_instance.render_panel(panel)
    if not panel.lore_codex_id.is_empty():
        CodexSystem.unlock_lore(panel.lore_codex_id)
    panel_advanced.emit(panel.id)

func _finish() -> void:
    _scene_instance.fade_out()
    cutscene_finished.emit(_cutscene_id)
    _current_panels = []
    _cutscene_id = ""
```

### Cutscene UI 场景结构

```
CutsceneScene (CanvasLayer，置顶)
├── BackgroundLayer
│   └── BackgroundImage (TextureRect, 满屏)
├── PortraitLayer
│   ├── PortraitLeft (Sprite2D, anchor 左下)
│   └── PortraitRight (Sprite2D, anchor 右下)
├── DialogueLayer
│   ├── SpeakerNameLabel
│   ├── TextLabel (RichTextLabel, 支持 BBCode + 打字机效果)
│   └── ContinueIndicator (▼ 闪烁箭头)
├── ControlLayer
│   ├── SkipButton (右上角"跳过 ▶")
│   └── BgClickArea (全屏 Button，点击推进)
└── AudioPlayers
    ├── BgmStream (AudioStreamPlayer)
    └── SfxStream (AudioStreamPlayer)
```

**关键 UX**：
- 点击 / 空格 → 推进（如果文字还在打字 → 立即显示完，再点一次 → 下一面板）
- 长按 → 加速（×4 倍速）
- ESC / 跳过键 → 弹"跳过整段?" 确认 → 跳过
- 已经看过的剧情：右上角直接显示"跳过"按钮，点击不需要确认

---

## 集成点

### 1. 主菜单 → 开始新游戏

```gdscript
# main_menu.gd
func _on_start_button_pressed() -> void:
    var pack = ContentLoader.get_active_pack()
    var intro_panels = pack.get_intro_panels()
    CutscenePlayer.play("intro", intro_panels)
    await CutscenePlayer.cutscene_finished
    get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
```

### 2. 知识城 → 启程登塔（楼层简介）

```gdscript
# tower_gate_controller.gd
func _on_floor_selected(floor_id: String) -> void:
    var pack = ContentLoader.get_active_pack()
    var panels = pack.get_floor_intro_panels(floor_id)
    if not panels.is_empty():
        CutscenePlayer.play("floor_intro_" + floor_id, panels)
        await CutscenePlayer.cutscene_finished
    _show_pre_run_setup()
```

### 3. Boss 战前后

```gdscript
# boss_battle_controller.gd
func _ready() -> void:
    var pack = ContentLoader.get_active_pack()
    var pre_panels = pack.get_boss_pre_panels(_boss_id)
    if not pre_panels.is_empty():
        CutscenePlayer.play("boss_pre_" + _boss_id, pre_panels)
        await CutscenePlayer.cutscene_finished
    _start_battle()

func _on_battle_won() -> void:
    var pack = ContentLoader.get_active_pack()
    var post_panels = pack.get_boss_post_panels(_boss_id)
    if not post_panels.is_empty():
        CutscenePlayer.play("boss_post_" + _boss_id, post_panels)
        await CutscenePlayer.cutscene_finished
    _go_to_next_node()
```

### 4. 楼层通关

```gdscript
func _on_final_boss_defeated() -> void:
    var pack = ContentLoader.get_active_pack()
    var panels = pack.get_floor_complete_panels(_floor_id)
    if not panels.is_empty():
        CutscenePlayer.play("floor_complete_" + _floor_id, panels)
        await CutscenePlayer.cutscene_finished
    _show_run_summary()
```

### 5. 终局结局

```gdscript
# 终极 Boss 倒下
func _on_final_ending() -> void:
    var pack = ContentLoader.get_active_pack()
    var panels = pack.get_ending_panels()
    CutscenePlayer.play("ending", panels)
```

### 6. NPC 对话

```gdscript
# city npc click
func _on_npc_clicked(npc_id: String) -> void:
    var pack = ContentLoader.get_active_pack()
    var panels = pack.get_npc_dialogue_panels(npc_id)
    CutscenePlayer.play("npc_" + npc_id, panels)
```

---

## 主菜单组件（引擎提供 + 包提供数据）

### 主菜单场景结构

```
MainMenuScene (CanvasLayer)
├── BackgroundImage (TextureRect, 来自 pack.get_main_menu_bg_path())
├── BgmPlayer (来自 pack.get_main_menu_bgm_path())
├── TitleVBox
│   ├── TitleLabel (来自 pack.get_game_title())
│   └── SubtitleLabel (来自 pack.get_game_subtitle())
├── ButtonsVBox
│   ├── StartButton ("开始新冒险")
│   ├── ContinueButton ("继续旅程")
│   ├── CodexButton ("图鉴馆")
│   ├── SettingsButton ("设置")
│   └── AboutButton ("关于")
└── VersionLabel (右下，引擎版本 + pack 版本)
```

### 按钮行为（引擎层）

| 按钮 | 行为 |
|------|------|
| 开始新冒险 | 检测有存档 → 弹确认覆盖；无存档 → CutscenePlayer.play(intro) → 知识城 |
| 继续旅程 | 加载 active pack 的存档 → 知识城 |
| 图鉴馆 | 跳转图鉴场景 |
| 设置 | 跳转设置场景（含学科切换 UI 框架）|
| 关于 | 跳转关于场景（版本、致谢、家长信息）|

### 标题/背景从包取

```gdscript
# main_menu.gd
func _ready() -> void:
    var pack = ContentLoader.get_active_pack()
    $TitleVBox/TitleLabel.text = pack.get_game_title()
    $TitleVBox/SubtitleLabel.text = pack.get_game_subtitle()
    $BackgroundImage.texture = load(pack.get_main_menu_bg_path())
    $BgmPlayer.stream = load(pack.get_main_menu_bgm_path())
    $BgmPlayer.play()
```

→ 同一个引擎，**英语包标题"知识神塔"**，**数学包标题"数海传说"**，背景图各异。

---

## 已读状态 / 剧情图鉴

### LoreCodexSystem（新增）

```gdscript
class_name LoreCodexSystem extends Node

var unlocked_lore_ids: Dictionary = {}   # id → unlocked_at_timestamp

func unlock_lore(lore_id: String) -> void:
    if not unlocked_lore_ids.has(lore_id):
        unlocked_lore_ids[lore_id] = Time.get_unix_time_from_system()
        SaveSystem.queue_save()

func is_unlocked(lore_id: String) -> bool:
    return unlocked_lore_ids.has(lore_id)

func get_all_unlocked() -> Array[String]:
    return unlocked_lore_ids.keys()
```

### 在图鉴馆里展示

`图鉴馆 → 剧情碎片` 标签页：
- 列出所有已解锁 lore_id（按楼层分组）
- 点击 → 重新播放对应的面板序列（不切 BGM、有跳过按钮）
- 未解锁 lore_id 显示 "?"（数量提示总量）

---

## 跳过策略

### 第一次播放的剧情
- 跳过按钮显示 "跳过 ▶"
- 点击 → 弹确认 modal："跳过这段剧情吗?（之后可在图鉴重看）"
- 确认 → 调用 `skip()`，记录所有 codex_id 为已读

### 已经看过的剧情（重玩 / 图鉴重看）
- 跳过按钮显示 "跳过 ⏩"
- 点击 → 直接跳过（不询问）

### 自动推进
- `advance_on = "auto_3s"` → 显示完文字后等 3 秒自动下一面板
- 这期间点击 → 立即推进
- 跳过按钮永远在右上角

---

## 文本动画

### 打字机效果

```gdscript
# CutsceneScene.gd
func render_panel(panel: CutscenePanel) -> void:
    # ... background, portraits, audio ...
    
    var label = $DialogueLayer/TextLabel
    label.text = ""
    label.visible_characters = 0
    label.set_text(panel.text)  # full text but visible_characters limits display
    
    if panel.text_speed > 0:
        var total_chars = panel.text.length()
        var duration = total_chars / panel.text_speed
        var tween = create_tween()
        tween.tween_property(label, "visible_characters", total_chars, duration)
        await tween.finished
    else:
        label.visible_characters = panel.text.length()
    
    _show_continue_indicator()
```

**点击中途**：
- 文字打字中 → 立即显示完整文字（取消 tween）
- 文字已显示完 → 推进到下一面板

---

## 现有代码处置

| 现有 | 处置 |
|------|------|
| 无相关现有代码 | — |

新增：
- `src/cutscene/cutscene_player.gd` — autoload 单例
- `src/cutscene/cutscene_scene.tscn` + `cutscene_scene.gd`
- `src/cutscene/cutscene_panel.gd` — 资源类
- `src/cutscene/lore_codex_system.gd` — autoload
- `src/cutscene/cutscene_loader.gd` — 从 JSON 加载面板序列工具

---

## MVP 范围

### 必做
- CutscenePanel 资源类 + JSON 加载
- CutscenePlayer 通用播放器
- CutsceneScene UI（背景 / 立绘 / 对白框 / 跳过 / 打字机）
- LoreCodexSystem 已读保存
- 主菜单组件（标题/背景/BGM 从 pack 取）
- 6 个集成点（主菜单 / 楼层简介 / Boss 战前 / Boss 战后 / 楼层通关 / NPC）
- 跳过策略（含确认 modal 和已读直跳）
- 自动推进 + 打字机效果

### 不做（推迟）
- 多角色同框立绘动画（surprise 弹出 / 摇晃等）
- 复杂转场（涟漪 / 故障 / 万花筒）
- 配音（仅文字 + BGM）
- 分支选项（剧情对白选择 → 影响走向）

---

## 测试策略

### 单元测试（GUT）
- `CutscenePanel.from_dict()` JSON 加载边界
- `CutscenePlayer.play()` → `advance()` → `cutscene_finished` 信号顺序
- `CutscenePlayer.skip()` 触发 codex 解锁所有 lore_id
- `LoreCodexSystem.unlock_lore()` / `is_unlocked()` / 持久化

### 集成测试
- 主菜单 → 开始 → intro 播放 → 知识城（无 mock）
- 楼层简介 → 备战 → 启程
- Boss 战前 → 战斗 → 战后
- 跳过流程：第一次跳 → 确认 → 跳到结尾，所有 codex_id 入图鉴

### 手动测试
- 文字打字速度感觉
- 中途点击立即显示
- BGM 切换平滑
- 立绘渲染清晰
- 跳过按钮始终可见

---

## 验收标准

- [ ] CutscenePlayer 接受 panels 数组并按序播放
- [ ] 主菜单 "开始新冒险" → 播放 intro 面板 → 知识城
- [ ] 楼层选择 → 播放 floor_intro 面板 → 备战
- [ ] Boss 节点进入 → 播放 boss_pre → 战斗 → 播放 boss_post
- [ ] 玩家点击跳过 → 弹确认 modal → 跳到结尾，所有 codex_id 已解锁
- [ ] 图鉴馆 → 剧情碎片 标签页可看已解锁 lore，点击重播
- [ ] 主菜单标题/背景/BGM 来自当前 pack
- [ ] 单测覆盖 CutscenePlayer / LoreCodexSystem ≥80%
- [ ] 切换学科后主菜单显示新 pack 的标题/背景/BGM

---

## 未决事项（依赖其他 spec）

- **内容包接口 spec**：`get_intro_panels()` / `get_boss_pre_panels()` 等接口已声明，本 spec 仅消费
- **存档 spec**：LoreCodexSystem 写入 save.json 的具体字段
- **图鉴馆 UI spec**：剧情碎片标签页的具体布局
