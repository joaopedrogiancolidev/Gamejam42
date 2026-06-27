extends Node2D

# ============================================================
#  HUB  -  cola os dois minigames e decide o final
#
#  Esquerda = Dance (racional / S D F)
#  Direita  = Waves (emocional / J K L)
#
#  Partida de 20s. No fim, compara os scores e ABRE uma das 4
#  CENAS de final (cada uma é uma cena animada própria):
#   - diferença < 25%        -> FinalFeliz
#   - racional bem maior     -> FinalRacional
#   - emocional bem maior    -> FinalEmocional
#   - alguém COLAPSA          -> FinalGameover
# ============================================================

const DURACAO: float = 20.0

const CENAS_FINAL := {
	"feliz": preload("res://scenes/FinalFeliz.tscn"),
	"racional": preload("res://scenes/FinalRacional.tscn"),
	"emocional": preload("res://scenes/FinalEmocional.tscn"),
	"gameover": preload("res://scenes/FinalGameover.tscn"),
}

@onready var dance = $Dance
@onready var waves = $Waves

var estado: String = "rodando"     # "rodando" | "fim"
var final_tipo: String = ""
var tempo: float = 0.0
var _cena_final: Node = null


func _process(delta: float) -> void:
	if estado != "rodando":
		return

	tempo += delta

	if dance.falhou or waves.falhou:
		_terminar("gameover")
		return

	if tempo >= DURACAO:
		_avaliar()


func _avaliar() -> void:
	var r: float = float(dance.score) / float(dance.META)
	var e: float = float(waves.score) / float(waves.META)
	var diff: float = absf(r - e)
	if diff < 0.25:
		_terminar("feliz")
	elif r > e:
		_terminar("racional")
	else:
		_terminar("emocional")


func _terminar(tipo: String) -> void:
	final_tipo = tipo
	estado = "fim"
	dance.ativo = false
	waves.ativo = false

	# instancia a cena de final (animada) por cima de tudo
	_cena_final = CENAS_FINAL[tipo].instantiate()
	$UI.add_child(_cena_final)

	# preenche os scores se a cena tiver esse label
	var sc = _cena_final.get_node_or_null("Conteudo/Scores")
	if sc:
		var r: int = int(float(dance.score) / float(dance.META) * 100.0)
		var e: int = int(float(waves.score) / float(waves.META) * 100.0)
		sc.text = "Racional: %d%%      Emocional: %d%%" % [r, e]


func _input(event: InputEvent) -> void:
	if estado == "fim" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()


func _reiniciar() -> void:
	if _cena_final and is_instance_valid(_cena_final):
		_cena_final.queue_free()
	_cena_final = null
	estado = "rodando"
	final_tipo = ""
	tempo = 0.0
	dance.reset()
	waves.reset()


# fundo de tela cheia (atrás dos jogos) -> preenche a margem de cima
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("06060d"))
