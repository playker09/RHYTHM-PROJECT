extends Node

const SONGS: Array[Dictionary] = [
	{
		"id": "jackpot",
		"title": "JACKPOT",
		"artist": "RHYTHM PROJECT",
		"bpm": 174,
		"preview_time": 2.0,
		"charts": {
			Global.Difficulty.EASY: {
				"level": 3,
				"notes": [
					{"time": 2.00, "lane": 0},
					{"time": 2.69, "lane": 1},
					{"time": 3.38, "lane": 2},
					{"time": 4.07, "lane": 3},
					# 중앙에서 우측으로 휘어지는 레버 롱노트
					{"time": 4.76, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 1.4, "start_x": 0.0, "end_x": 0.6},
					{"time": 5.10, "lane": 0},
					{"time": 5.80, "lane": 1},
					# 좌측 레버 플릭
					{"time": 6.80, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.4},
					{"time": 7.50, "lane": 2},
					{"time": 8.20, "lane": 3},
					# 우측에서 좌측으로 휘어지는 레버 롱노트
					{"time": 8.90, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 1.5, "start_x": 0.5, "end_x": -0.5},
					{"time": 9.60, "lane": 1},
					# 우측 레버 플릭
					{"time": 10.80, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.4},
					{"time": 11.50, "lane": 0, "type": Global.NoteType.HOLD, "duration": 0.8},
					{"time": 12.60, "lane": 3, "type": Global.NoteType.HOLD, "duration": 1.0},
					{"time": 14.00, "lane": 1},
					{"time": 14.50, "lane": 2}
				]
			},
			Global.Difficulty.NORMAL: {
				"level": 6,
				"notes": [
					{"time": 1.80, "lane": 0},
					{"time": 2.14, "lane": 1},
					{"time": 2.49, "lane": 2},
					{"time": 2.83, "lane": 3},
					# 좌측 레버 플릭
					{"time": 3.20, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.5},
					# 우측으로 부드럽게 이동하는 레버 커브 홀드
					{"time": 3.80, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 1.6, "start_x": -0.5, "end_x": 0.6},
					{"time": 4.10, "lane": 1},
					{"time": 4.45, "lane": 2},
					{"time": 4.80, "lane": 0},
					{"time": 5.15, "lane": 3},
					# 우측 레버 플릭
					{"time": 5.80, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.5},
					{"time": 6.20, "lane": 1, "type": Global.NoteType.HOLD, "duration": 0.7},
					{"time": 7.00, "lane": 2, "type": Global.NoteType.HOLD, "duration": 0.7},
					# S자형 레버 커브 홀드
					{"time": 7.80, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 2.0, "start_x": 0.4, "end_x": -0.6},
					{"time": 8.15, "lane": 0},
					{"time": 8.50, "lane": 1},
					{"time": 8.85, "lane": 2},
					{"time": 9.20, "lane": 3},
					# 연속 플릭
					{"time": 10.00, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.6},
					{"time": 10.60, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.6},
					{"time": 11.20, "lane": 0},
					{"time": 11.55, "lane": 1},
					{"time": 11.90, "lane": 2},
					{"time": 12.25, "lane": 3},
					{"time": 12.70, "lane": 0, "type": Global.NoteType.HOLD, "duration": 1.0},
					{"time": 12.70, "lane": 3, "type": Global.NoteType.HOLD, "duration": 1.0},
					{"time": 14.20, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.0}
				]
			},
			Global.Difficulty.HARD: {
				"level": 9,
				"notes": [
					{"time": 1.66, "lane": 0},
					{"time": 1.83, "lane": 1},
					{"time": 2.00, "lane": 2},
					{"time": 2.17, "lane": 3},
					{"time": 2.34, "lane": 2},
					{"time": 2.52, "lane": 1},
					{"time": 2.69, "lane": 0},
					# 고속 플릭
					{"time": 3.00, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.6},
					{"time": 3.40, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.6},
					# 다이나믹 레버 커브 홀드 + 4키 동시치기
					{"time": 3.80, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 2.2, "start_x": -0.6, "end_x": 0.7},
					{"time": 4.00, "lane": 1, "type": Global.NoteType.HOLD, "duration": 0.5},
					{"time": 4.60, "lane": 2, "type": Global.NoteType.HOLD, "duration": 0.5},
					{"time": 5.20, "lane": 0},
					{"time": 5.40, "lane": 3},
					{"time": 5.70, "lane": 1},
					{"time": 5.90, "lane": 2},
					# 고난도 연속 레버 플릭
					{"time": 6.30, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.5},
					{"time": 6.70, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.5},
					{"time": 7.10, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.5},
					# 역방향 레버 커브 홀드
					{"time": 7.60, "type": Global.NoteType.LEVER_CURVE_HOLD, "duration": 2.4, "start_x": 0.6, "end_x": -0.7},
					{"time": 7.80, "lane": 0},
					{"time": 8.00, "lane": 1},
					{"time": 8.20, "lane": 2},
					{"time": 8.40, "lane": 3},
					{"time": 8.70, "lane": 1, "type": Global.NoteType.HOLD, "duration": 0.8},
					{"time": 9.60, "lane": 2, "type": Global.NoteType.HOLD, "duration": 0.8},
					# 피날레 복합 플릭 & 4키
					{"time": 10.60, "type": Global.NoteType.LEVER_FLICK_LEFT, "x": -0.7},
					{"time": 11.00, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.7},
					{"time": 11.40, "lane": 0},
					{"time": 11.60, "lane": 1},
					{"time": 11.80, "lane": 2},
					{"time": 12.00, "lane": 3},
					{"time": 12.30, "lane": 0, "type": Global.NoteType.HOLD, "duration": 1.2},
					{"time": 12.30, "lane": 3, "type": Global.NoteType.HOLD, "duration": 1.2},
					{"time": 13.80, "type": Global.NoteType.LEVER_FLICK_RIGHT, "x": 0.0}
				]
			}
		}
	}
]

func get_song(index: int) -> Dictionary:
	if index < 0 or index >= SONGS.size():
		return SONGS[0]
	return SONGS[index]

func get_chart(song_index: int, difficulty: Global.Difficulty) -> Dictionary:
	var song: Dictionary = get_song(song_index)
	var charts: Dictionary = song.get("charts", {})
	if charts.has(difficulty):
		return charts[difficulty]
	return charts.get(Global.Difficulty.NORMAL, {"level": 1, "notes": []})
