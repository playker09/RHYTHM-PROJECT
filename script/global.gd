extends Node

enum Lane { LEFT, RIGHT }
const PERFECT_WINDOW := 0.030
const GOOD_WINDOW := 0.080
const BAD_WINDOW := 0.150

var score := 0
var combo := 0
var current_lane: Lane = Lane.LEFT
var selected_song := "JACKPOT"
var note_speed := 3.0
var timing_offset_ms := 0.0
var master_volume_db := -20.0

func reset_run() -> void:
	score = 0
	combo = 0
	current_lane = Lane.LEFT
