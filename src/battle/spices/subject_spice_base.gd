## SubjectSpiceBase — 学科特色机制 (Spice) 引擎层基类
##
## 每个学科内容包可以提供 0..N 个 Spice：战斗中触发的全屏交互机制
## （如英语口语卷轴 / 听写、数学速算 / 估算、化学方程式配平等）。
##
## 引擎流程：
##   1. BattleController.invoke_spice(spice_id)
##   2. spice = pack.get_spice(id)
##   3. ui = spice.get_ui_scene().instantiate()
##   4. ui 收集玩家输入 → 通过 signal 回传 input_data
##   5. result = spice.evaluate(input_data)
##   6. BattleController 应用 result.effect_payload
##
## 子类至少需要 override：get_id / get_display_name / get_ui_scene / evaluate。
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
class_name SubjectSpiceBase extends Resource


## Spice 唯一标识，如 "voice_scroll" / "dictation"
func get_id() -> String:
	push_warning("SubjectSpiceBase.get_id() not overridden by " + get_class())
	return ""


## 显示名称，如 "口语卷轴"
func get_display_name() -> String:
	push_warning("SubjectSpiceBase.get_display_name() not overridden by " + get_class())
	return ""


## 简短描述；UI 可显示为 tooltip
func get_description() -> String:
	push_warning("SubjectSpiceBase.get_description() not overridden by " + get_class())
	return ""


## Spice 触发时实例化的全屏 modal 场景
func get_ui_scene() -> PackedScene:
	push_warning("SubjectSpiceBase.get_ui_scene() not overridden by " + get_class())
	return null


## 评估玩家输入，返回 SpiceResult。
## input_data 结构由具体 Spice 决定（语音 = String transcript，
## 听写 = String 用户输入，速算 = float 答案 等）。
func evaluate(_input_data) -> SpiceResult:
	push_warning("SubjectSpiceBase.evaluate() not overridden by " + get_class())
	return SpiceResult.make(false, 0.0, {})
