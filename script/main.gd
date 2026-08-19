extends Node2D

@onready var music_player: RhythmMusicPlayer = $MusicPlayer
@onready var metronome: Metronome = $Metronome
@onready var chart: RhythmChart = $Chart
@onready var display: RhythmDisplay = $Display
@onready var judge: RhythmJudge = $Judge
@onready var player_input: PlayerInput = $PlayerInput

func _ready() -> void:
	Global.reset_run()
	metronome.configure_fixed_bpm(103.0)
	chart.load_chart(metronome)
	display.configure(chart, music_player)
	judge.configure(music_player, display, player_input)
	music_player.play_song()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if music_player.is_song_playing(): music_player.pause_song()
			else: music_player.resume_song()
		elif event.keycode == KEY_R:
			restart_song()

func restart_song() -> void:
	Global.reset_run()
	display.reset_notes()
	music_player.stop_song()
	music_player.play_song()
