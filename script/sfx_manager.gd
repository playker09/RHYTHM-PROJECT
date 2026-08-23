extends Node

# 프로시저럴 효과음(SFX) 매니저
# 외부 사운드 파일 없이도 즉각적인 타격음 및 UI 피드백 제공

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const POOL_SIZE := 16

var sfx_tap: AudioStreamWAV
var sfx_flick: AudioStreamWAV
var sfx_hold_tick: AudioStreamWAV
var sfx_ui_move: AudioStreamWAV
var sfx_ui_select: AudioStreamWAV
var sfx_miss: AudioStreamWAV

func _ready() -> void:
	# 오디오 플레이어 풀 생성 (동시 타격 시 끊김 방지)
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	
	_generate_sfx()

func _generate_sfx() -> void:
	sfx_tap = _create_synth_sound(880.0, 0.08, 0.5, "percussive")
	sfx_flick = _create_synth_sound(1200.0, 0.12, 0.6, "flick")
	sfx_hold_tick = _create_synth_sound(1400.0, 0.04, 0.3, "tick")
	sfx_ui_move = _create_synth_sound(587.33, 0.05, 0.3, "ui")
	sfx_ui_select = _create_synth_sound(987.77, 0.12, 0.45, "percussive")
	sfx_miss = _create_synth_sound(160.0, 0.15, 0.4, "miss")

func _create_synth_sound(base_freq: float, duration: float, volume: float, type: String) -> AudioStreamWAV:
	var sample_rate := 44100
	var total_samples := int(sample_rate * duration)
	var byte_array := PackedByteArray()
	byte_array.resize(total_samples * 2) # 16-bit mono
	
	for i in range(total_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var sample_val := 0.0
		
		match type:
			"percussive":
				# 크리스탈 탭 어택 + 사인파 디케이
				var env := exp(-progress * 22.0)
				var freq := base_freq * (1.0 + exp(-progress * 35.0) * 1.5)
				var wave1 := sin(2.0 * PI * freq * t)
				var wave2 := sin(4.0 * PI * freq * t) * 0.4
				var noise := (randf() * 2.0 - 1.0) * exp(-progress * 50.0) * 0.35
				sample_val = (wave1 + wave2 + noise) * env
			"flick":
				# 고주파 스위시 레이저 사운드
				var env := exp(-progress * 15.0)
				var freq := base_freq * (2.2 - progress * 1.2)
				var wave := sin(2.0 * PI * freq * t)
				var noise := (randf() * 2.0 - 1.0) * exp(-progress * 25.0) * 0.5
				sample_val = (wave * 0.7 + noise) * env
			"tick":
				# 짧은 클릭 사운드
				var env := exp(-progress * 45.0)
				var wave := sin(2.0 * PI * base_freq * t)
				sample_val = wave * env
			"ui":
				var env := exp(-progress * 25.0)
				var wave := sin(2.0 * PI * base_freq * t)
				sample_val = wave * env
			"miss":
				var env := exp(-progress * 12.0)
				var wave := sin(2.0 * PI * base_freq * t) * 0.8 + sin(2.0 * PI * (base_freq * 0.75) * t) * 0.5
				sample_val = wave * env
		
		# 16-bit PCM 정규화 및 클리핑
		sample_val = clampf(sample_val * volume, -1.0, 1.0)
		var int_val := int(sample_val * 32767.0)
		byte_array.encode_s16(i * 2, int_val)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav

func play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := _players[_player_index]
	_player_index = (_player_index + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.play()

func play_tap(pitch: float = 1.0) -> void:
	play_sfx(sfx_tap, pitch)

func play_flick() -> void:
	play_sfx(sfx_flick, 1.0)

func play_tick() -> void:
	play_sfx(sfx_hold_tick, 1.0)

func play_ui_move() -> void:
	play_sfx(sfx_ui_move, 1.0)

func play_ui_select() -> void:
	play_sfx(sfx_ui_select, 1.0)

func play_miss() -> void:
	play_sfx(sfx_miss, 1.0)
