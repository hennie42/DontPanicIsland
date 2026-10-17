extends Node
class_name Sfx

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _sfx_players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _dig_index: int = 0

const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"

func _ready() -> void:
	_setup_buses()
	_setup_music()
	_setup_sfx_players()
	_load_sounds()

	music_player.play()
	GameEvent.marker("MUSIC_START")

func _setup_buses() -> void:
	var music_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, MUSIC_BUS)

	var sfx_idx := AudioServer.get_bus_index(SFX_BUS)
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, SFX_BUS)

func _setup_music() -> void:
	add_child(music_player)
	music_player.bus = MUSIC_BUS
	var stream = load("res://audio/music_loop.wav")
	if stream:
		music_player.stream = stream
	else:
		push_error("Sfx: Failed to load music loop at res://audio/music_loop.wav")

func _setup_sfx_players() -> void:
	# Create a pool of 8 players to allow overlapping sounds
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)

func _load_sounds() -> void:
	_sounds = {
		"dig": [
			"res://assets/kenney/impact-sounds/Audio/footstep_grass_000.ogg",
			"res://assets/kenney/impact-sounds/Audio/footstep_grass_002.ogg"
		],
		"flag": "res://assets/kenney/rpg-audio/Audio/cloth1.ogg",
		"boom": "res://assets/kenney/desert-shooter-pack/Sounds/explosion-a.ogg",
		"coin": "res://assets/kenney/desert-shooter-pack/Sounds/coin-a.ogg",
		"click": "res://assets/kenney/interface-sounds/Audio/click_001.ogg",
		"ufo": "res://assets/kenney/sci-fi-sounds/Audio/spaceEngineLow_000.ogg",
		"drop": "res://assets/kenney/interface-sounds/Audio/drop_001.ogg",
		"tool": "res://assets/kenney/digital-audio/Audio/powerUp2.ogg",
		"lose": "res://assets/kenney/desert-shooter-pack/Sounds/lose-a.ogg",
		"win": "res://assets/kenney/music-jingles/Audio/Hit jingles/jingles_HIT00.ogg"
	}

	# Preload sounds
	var loaded_sounds: Dictionary = {}
	for name in _sounds:
		var path = _sounds[name]
		if path is Array:
			var arr: Array[AudioStream] = []
			for p in path:
				var s = load(p)
				if s: arr.append(s)
			loaded_sounds[name] = arr
		else:
			var s = load(path)
			if s: loaded_sounds[name] = s
	_sounds = loaded_sounds

func play(name: String) -> void:
	GameEvent.marker("SFX " + name)

	if not _sounds.has(name):
		push_warning("Sfx: Sound not found: ", name)
		return

	var sound_to_play: AudioStream
	if _sounds[name] is Array:
		# Handle alternating sounds (like dig)
		var arr := _sounds[name] as Array[AudioStream]
		if arr.is_empty(): return
		sound_to_play = arr[_dig_index % arr.size()]
		_dig_index += 1
	else:
		sound_to_play = _sounds[name]

	if not sound_to_play:
		return

	# Find an available player
	for p in _sfx_players:
		if not p.playing:
			p.stream = sound_to_play
			p.play()
			return

	# If all are busy, just use the first one (will interrupt)
	_sfx_players[0].stream = sound_to_play
	_sfx_players[0].play()
