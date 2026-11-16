class_name EffectTrack
extends RefCounted
## 채보의 연출(effects)을 곡 시간으로 계산한다. 상태가 없다: 같은 시간이면 항상 같은 값.
## 판정과 무관한 순수 비주얼. 연출이 끝나면 모든 값이 0 으로 돌아온다.

const FLASH_RELEASE_MS := 450.0     # 발광이 사그라드는 시간
const GLITCH_MIN_MS := 120.0        # duration 0 인 글리치의 길이

var _effects: Array[Dictionary] = []

func setup(effects: Array[Dictionary]) -> void:
	_effects = effects

## {flash_l, flash_r, glitch: 0~1, spin: 라디안(+ = 화면에서 반시계)}
func sample(now_ms: float) -> Dictionary:
	var out := {"flash_l": 0.0, "flash_r": 0.0, "glitch": 0.0, "spin": 0.0}
	for e in _effects:
		var t: float = now_ms - float(e["time"])
		if t < 0.0:
			break                       # time 오름차순이므로 뒤는 전부 아직
		var dur: float = e["duration"]
		match e["type"]:
			"flash":
				var v: float = _burst(t, dur, FLASH_RELEASE_MS) * clampf(e["strength"], 0.0, 1.0)
				if e["side"] != "right":
					out["flash_l"] = maxf(out["flash_l"], v)
				if e["side"] != "left":
					out["flash_r"] = maxf(out["flash_r"], v)
			"glitch":
				var span: float = maxf(dur, GLITCH_MIN_MS)
				if t < span:
					var tail: float = 1.0 - smoothstep(0.8, 1.0, t / span)
					out["glitch"] = maxf(out["glitch"], clampf(e["strength"], 0.0, 1.0) * tail)
			"spin":
				var p: float = t / maxf(dur, 1.0)
				if p < 1.0:
					var way: float = 1.0 if e["dir"] == "ccw" else -1.0
					out["spin"] += way * float(e["turns"]) * TAU * p * p * (3.0 - 2.0 * p)
	return out

## duration 동안 1 을 유지하고 그 뒤 release 동안 0 으로 떨어진다
static func _burst(t: float, dur: float, release: float) -> float:
	if t <= dur:
		return 1.0
	var r: float = clampf(1.0 - (t - dur) / release, 0.0, 1.0)
	return r * r
