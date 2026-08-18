extends Node2D
@onready var left_lane = $LeftLane
@onready var right_lane = $RightLane



@onready var music: AudioStreamPlayer2D = $Music
@onready var notes_container: Node2D = $Note


# ==========================================
# 게임 상태
# ==========================================

var chart: Array = []
var next_note_index := 0
var active_lane := Global.Lane.LEFT
var score := 0
var combo := 0


# ==========================================
# 음악 시간
# ==========================================

var song_time := 0.0


# ==========================================
# 시작
# ==========================================

func _ready() -> void:
	chart = Charts.get_chart()

	# 채보가 시간순으로 정렬되어 있다고 가정
	chart.sort_custom(_sort_notes)

	music.play()


func _sort_notes(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] < b["time"]


# ==========================================
# 게임 업데이트
# ==========================================

func _process(delta: float) -> void:
	update_song_time()
	update_lane()
	spawn_notes()
	update_notes()
	check_judgement()


# ==========================================
# 음악 시간
# ==========================================

func update_song_time() -> void:
	if music.playing:
		song_time = music.get_song_time()


# ==========================================
# 마우스 → 레인
# ==========================================

func update_lane() -> void:
	var mouse_x := get_viewport().get_mouse_position().x
	var center_x := get_viewport_rect().size.x / 2.0

	if mouse_x < center_x:
		active_lane = Global.Lane.LEFT
	else:
		active_lane = Global.Lane.RIGHT


# ==========================================
# 노트 생성
# ==========================================

func spawn_notes() -> void:

	while next_note_index < chart.size():

		var note_data: Dictionary = chart[next_note_index]

		var hit_time: float = note_data["time"]

		# 아직 노트를 생성할 시간이 아니라면 종료
		if song_time < hit_time - Global.APPROACH_TIME:
			break

		create_note(note_data)

		next_note_index += 1


func create_note(note_data: Dictionary) -> void:

	var note := preload("res://script/note.gd").new()

	notes_container.add_child(note)

	note.setup(
		note_data["time"],
		note_data["lane"]
	)


# ==========================================
# 노트 위치 업데이트
# ==========================================

func update_notes() -> void:

	for note in notes_container.get_children():

		note.update_position(song_time)


# ==========================================
# 판정
# ==========================================

func check_judgement() -> void:

	for note in notes_container.get_children():

		if note.judged:
			continue

		var time_error: float = song_time - note.hit_time
		var absolute_error: float = abs(time_error)


		# ==================================
		# 판정창을 완전히 지나감
		# ==================================

		if time_error > Global.OKAY_WINDOW:

			judge_miss(note)

			continue


		# ==================================
		# 아직 판정창에 들어오지 않음
		# ==================================

		if time_error < -Global.OKAY_WINDOW:
			continue


		# ==================================
		# 레인 확인
		# ==================================

		if active_lane != note.lane:
			continue


		# ==================================
		# 시간 판정
		# ==================================

		if absolute_error <= Global.PERFECT_WINDOW:

			judge_perfect(note)

		elif absolute_error <= Global.GOOD_WINDOW:

			judge_good(note)

		elif absolute_error <= Global.OKAY_WINDOW:

			judge_okay(note)


# ==========================================
# 판정 결과
# ==========================================

func judge_perfect(note) -> void:

	score += 300
	combo += 1

	print("PERFECT!  Error: ", (song_time - note.hit_time) * 1000.0, " ms")

	note.mark_judged()


func judge_good(note) -> void:

	score += 200
	combo += 1

	print("GOOD!     Error: ", (song_time - note.hit_time) * 1000.0, " ms")

	note.mark_judged()


func judge_okay(note) -> void:

	score += 100
	combo += 1

	print("OKAY!     Error: ", (song_time - note.hit_time) * 1000.0, " ms")

	note.mark_judged()


func judge_miss(note) -> void:

	combo = 0

	print("MISS!")

	note.mark_judged()
