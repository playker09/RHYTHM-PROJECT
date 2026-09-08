extends Node2D

@onready var music_player: RhythmMusicPlayer = $MusicPlayer
@onready var display: RhythmDisplay = $Display
@onready var menu: RhythmMenu = $Menu

func _ready() -> void:
	Global.reset_run()
	Metronome.configure_fixed_bpm(103.0)
	Chart.load_chart(Metronome)
	display.configure(Chart, music_player)
	Judge.configure(music_player, display, PlayerInput)
	music_player.volume_db = Global.master_volume_db
	menu.start_requested.connect(start_game)
	menu.settings_changed.connect(_apply_settings)
	menu.show_start_screen()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if music_player.is_song_playing(): music_player.pause_song()
			else: music_player.resume_song()
		elif event.keycode == KEY_R:
			if music_player.is_song_playing(): restart_song()
		elif event.keycode == KEY_ESCAPE:
			if music_player.is_song_playing():
				music_player.pause_song()
				menu.show_start_screen()

func start_game() -> void:
	Global.reset_run()
	Metronome.configure_fixed_bpm(103.0)
	Chart.load_chart(Metronome)
	display.reset_notes()
	music_player.stop_song()
	music_player.play_song()
	menu.hide_menu()

func _apply_settings() -> void:
	music_player.volume_db = Global.master_volume_db

func restart_song() -> void:
	start_game()
