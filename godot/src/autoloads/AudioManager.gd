extends Node
## Music / SFX playback + placeholder voice lines via OS text-to-speech.
## Real recorded/AI voice lines replace speak() at Week 5.

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _voice_next := 0
var _current_music: AudioStream


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Voice"
		add_child(p)
		_voice_pool.append(p)


func play_music(stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null or stream == _current_music:
		return
	_current_music = stream
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_current_music = null
	_music.stop()


func play_sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Placeholder TTS — OS voices until Week 5 audio pass.
func speak(text: String) -> void:
	if not Settings.get_value("tts_voice_lines"):
		return
	var p := _voice_pool[_voice_next]
	_voice_next = (_voice_next + 1) % _voice_pool.size()
	if p.playing:
		p.stop()
	DisplayServer.tts_speak(text, "", -6.0, 1.0, 0, true)


func stop_voice() -> void:
	DisplayServer.tts_stop()
