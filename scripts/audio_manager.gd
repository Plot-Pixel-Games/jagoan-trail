extends Node

@onready var bgm: AudioStreamPlayer = $BGM

func play_music():
	if not bgm.playing:
		bgm.play()

func stop_music():
	bgm.stop()
