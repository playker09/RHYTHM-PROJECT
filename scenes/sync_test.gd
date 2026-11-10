extends Control
## 1단계 싱크 검증 씬.
## - 곡 시간/박자 표시, 박마다 화면 플래시
## - 아무 키(Space 권장)로 박자에 맞춰 탭 -> 평균 오차 표시
## - [ / ] : 오프셋 -/+ 5ms,  Enter: 저장,  R: 탭 기록 초기화

const BPM := 120.0
const AUDIO_PATH := "res://charts/sample/song.wav"

var conductor: Conductor
var label: Label
var flash: ColorRect
var taps: Array[float] = []
var load_failed: bool = false

func _ready() -> void:
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.BLACK
	add_child(flash)

	label = Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)

	conductor = Conductor.new()
	add_child(conductor)
	var stream: AudioStream = load(AUDIO_PATH)
	if stream == null:
		load_failed = true
		label.text = "오디오를 불러오지 못했습니다: " + AUDIO_PATH
		return
	conductor.play(stream)

func _process(_delta: float) -> void:
	if load_failed:
		return
	var t: float = conductor.get_song_time_ms()
	var beat_ms: float = 60000.0 / BPM
	var beat_f: float = t / beat_ms
	var phase: float = beat_f - floorf(beat_f)
	var accent: bool = int(floorf(beat_f)) % 4 == 0
	var base: float = 0.6 if accent else 0.35
	flash.color = Color(base, base, base) * (1.0 - phase)

	var avg: float = 0.0
	if taps.size() > 0:
		for v in taps:
			avg += v
		avg /= taps.size()
	label.text = "곡 시간: %9.1f ms\n박자: %d  (BPM %.0f)\n오프셋: %+.0f ms\n\n탭 %d회  평균 오차: %+.1f ms\n(+ = 박보다 늦게 침)\n\n[Space] 박자에 맞춰 탭   [ ] 오프셋 -/+5ms   [Enter] 저장   [R] 초기화" % [
		t, int(floorf(beat_f)) + 1, BPM, Settings.offset_ms, taps.size(), avg]

func _input(event: InputEvent) -> void:
	if load_failed or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_BRACKETLEFT:
			Settings.offset_ms -= 5.0
		KEY_BRACKETRIGHT:
			Settings.offset_ms += 5.0
		KEY_ENTER:
			Settings.save_settings()
		KEY_R:
			taps.clear()
		_:
			# 입력 이벤트 시점의 곡 시간으로 가장 가까운 박과의 차이를 구한다
			var t: float = conductor.get_song_time_ms()
			var beat_ms: float = 60000.0 / BPM
			var err: float = t - roundf(t / beat_ms) * beat_ms
			taps.append(err)
			if taps.size() > 16:
				taps.pop_front()
