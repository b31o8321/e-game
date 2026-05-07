## CutscenePanel — 剧情面板资源
##
## 引擎层通用剧情面板数据结构。每个面板包含背景、立绘、文本、推进逻辑等信息。
## 内容包通过 JSON 提供面板序列，不在引擎层硬编码任何具体故事内容。
##
## 参考: docs/superpowers/specs/2026-05-04-cutscene-system-design.md
class_name CutscenePanel extends Resource

# ---- 标识 ----
@export var id: String = ""                              # "intro_1"

# ---- 背景 ----
@export var background_image_path: String = ""           # 满屏背景图（空 = 沿用上一张）
@export var background_color: Color = Color.BLACK

# ---- 音频 ----
@export var bgm_path: String = ""                        # 切换 BGM（空 = 沿用）
@export var sfx_path: String = ""                        # 进入面板时播放音效（空 = 不播）

# ---- 立绘（最多 2 个角色）----
@export var portrait_left_path: String = ""
@export var portrait_left_emotion: String = "normal"     # "normal" / "happy" / "sad" / "angry"
@export var portrait_right_path: String = ""
@export var portrait_right_emotion: String = "normal"

# ---- 文本 ----
@export var speaker_name: String = ""                    # 空 = 旁白模式
@export var speaker_position: String = ""                # "left" / "right" / "center" / ""
@export var text: String = ""                            # 主文本（支持 BBCode）
@export var text_speed: float = 30.0                     # 字/秒；0 = 立即显示

# ---- 转场 ----
@export var transition_in: String = "instant"            # "fade" / "slide" / "instant"
@export var transition_out: String = "instant"

# ---- 推进 ----
@export var advance_on: String = "click"                 # "click" / "auto_3s" / "auto_5s" / "auto_<n>s"
@export var next_panel_id: String = ""                   # 下一面板；空 = 序列结束

# ---- 元数据 ----
@export var lore_codex_id: String = ""                   # 解锁此剧情图鉴条目（空 = 不入图鉴）
@export var tags: Array[String] = []                     # ["main_story", "boss_dialogue", ...]


## 从 Dictionary 创建 CutscenePanel（用于 JSON 加载）
static func from_dict(data: Dictionary) -> CutscenePanel:
	var panel: CutscenePanel = CutscenePanel.new()
	panel.id = data.get("id", "")
	panel.background_image_path = data.get("background_image_path", "")
	if data.has("background_color"):
		var c = data["background_color"]
		if c is Color:
			panel.background_color = c
		elif c is String:
			panel.background_color = Color(c)
	panel.bgm_path = data.get("bgm_path", "")
	panel.sfx_path = data.get("sfx_path", "")
	panel.portrait_left_path = data.get("portrait_left_path", "")
	panel.portrait_left_emotion = data.get("portrait_left_emotion", "normal")
	panel.portrait_right_path = data.get("portrait_right_path", "")
	panel.portrait_right_emotion = data.get("portrait_right_emotion", "normal")
	panel.speaker_name = data.get("speaker_name", "")
	panel.speaker_position = data.get("speaker_position", "")
	panel.text = data.get("text", "")
	panel.text_speed = float(data.get("text_speed", 30.0))
	panel.transition_in = data.get("transition_in", "instant")
	panel.transition_out = data.get("transition_out", "instant")
	panel.advance_on = data.get("advance_on", "click")
	panel.next_panel_id = data.get("next_panel_id", "")
	panel.lore_codex_id = data.get("lore_codex_id", "")
	var tag_arr: Array[String] = []
	for t in data.get("tags", []):
		tag_arr.append(String(t))
	panel.tags = tag_arr
	return panel


## 序列化为 Dictionary（用于持久化或测试 round-trip）
func to_dict() -> Dictionary:
	return {
		"id": id,
		"background_image_path": background_image_path,
		"background_color": background_color.to_html(),
		"bgm_path": bgm_path,
		"sfx_path": sfx_path,
		"portrait_left_path": portrait_left_path,
		"portrait_left_emotion": portrait_left_emotion,
		"portrait_right_path": portrait_right_path,
		"portrait_right_emotion": portrait_right_emotion,
		"speaker_name": speaker_name,
		"speaker_position": speaker_position,
		"text": text,
		"text_speed": text_speed,
		"transition_in": transition_in,
		"transition_out": transition_out,
		"advance_on": advance_on,
		"next_panel_id": next_panel_id,
		"lore_codex_id": lore_codex_id,
		"tags": tags,
	}
