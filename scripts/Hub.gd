extends Node2D

# ============================================================
#  HUB  -  cola os dois minigames e decide o final
#
#  Esquerda  = Dance  (racional / S D F)
#  Direita   = Waves  (emocional / J K L)
#
#  Regras dos 4 finais (quando alguém atinge a META):
#   - diferença entre os 2 (normalizados) < 25%  -> FELIZ
#   - racional bem maior                          -> RACIONAL
#   - emocional bem maior                         -> EMOCIONAL
#  E se qualquer um FALHAR a qualquer momento     -> GAME OVER
# ============================================================

@onready var dance = $Dance
@onready var waves = $Waves

var estado: String = "rodando"     # "rodando" | "fim"
var final_tipo: String = ""        # "feliz" | "racional" | "emocional" | "gameover"


func _process(_delta: float) -> void:
	if estado != "rodando":
		return

	# falha tem prioridade
	if dance.falhou or waves.falhou:
		_terminar("gameover")
		return

	# alguém bateu a meta -> avalia
	if dance.score >= dance.META or waves.score >= waves.META:
		_avaliar()


func _avaliar() -> void:
	var r: float = float(dance.score) / float(dance.META)   # racional
	var e: float = float(waves.score) / float(waves.META)   # emocional
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


func _input(event: InputEvent) -> void:
	if estado == "fim" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()


func _reiniciar() -> void:
	estado = "rodando"
	final_tipo = ""
	dance.reset()
	waves.reset()


# fundo de tela cheia (desenhado ATRÁS dos jogos) -> preenche as margens
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("06060d"))
