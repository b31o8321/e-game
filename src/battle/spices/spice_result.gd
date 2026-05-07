## SpiceResult — Spice 评估返回结果
##
## 由 SubjectSpiceBase.evaluate() 返回；BattleController / SpiceModal
## 据此决定播放成功 / 失败动画并应用 effect_payload（buff、伤害、回血等）。
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
class_name SpiceResult extends Resource

## 是否成功（影响动画 / 战斗判定）
@export var success: bool = false

## 完成质量，0.0 ~ 1.0；用于细粒度奖励（暴击触发、buff 强度缩放等）
@export var quality: float = 0.0

## 效果载荷，如 {"buff": {"id": "atk_up", "value": 30, "duration": 3}}
## 或 {"counter_attack": 25}；空 dict 表示无效果。
@export var effect_payload: Dictionary = {}


## 静态构造助手；推荐外部代码用这个生成 SpiceResult 而非手动 new + 设置字段。
static func make(p_success: bool, p_quality: float, p_payload: Dictionary) -> SpiceResult:
	var r := SpiceResult.new()
	r.success = p_success
	r.quality = p_quality
	r.effect_payload = p_payload
	return r
