class_name ChordPlayer
extends Node

@export var base_player: AudioStreamPlayer

const NOTES: Dictionary = {
	"C": 1.0,
	"E": 1.25992,
	"G": 1.49831,
}

const LOOP_START: float = 1.2
const LOOP_END:   float = 4.5

var _players: Dictionary = {}  # note -> AudioStreamPlayer

func _ready() -> void:
	if base_player == null:
		push_error("ChordPlayer: assign an AudioStream in the Inspector")
		return
	for note in NOTES:
		var p := AudioStreamPlayer.new()
		p.stream = base_player.stream
		p.pitch_scale = NOTES[note]
		add_child.call_deferred(p)
		_players[note] = p

func _process(_delta: float) -> void:
	for note in _players:
		var p: AudioStreamPlayer = _players[note]
		if p.playing and p.get_playback_position() >= LOOP_END:
			p.seek(LOOP_START)

func press(note: String) -> void:
	if not _players.has(note):
		push_error("ChordPlayer: unknown note '%s'" % note)
		return
	var p: AudioStreamPlayer = _players[note]
	p.play()

func release(note: String) -> void:
	if not _players.has(note):
		push_error("ChordPlayer: unknown note '%s'" % note)
		return
	pass

func press_chord(notes: Array) -> void:
	for note in notes:
		press(note)

func release_all() -> void:
	for note in _players:
		release(note)

func stop_all() -> void:
	for note in _players:
		_players[note].stop()
