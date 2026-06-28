extends Node2D

# ============================================================
#  OVERLAY  -  LÓGICA PURA (cronômetro + moldura/divisória estáticas)
#
#  As telas de final NÃO ficam mais aqui: viraram 4 cenas próprias
#  (FinalFeliz/Racional/Emocional/Gameover) que o Hub instancia.
#
#  Este script só atualiza o Cronometro (texto + urgência nos
#  últimos segundos). Moldura e Divisoria são nós estáticos.
# ============================================================

const URGENCIA: float = 5.0   # segundos finais em que o cronômetro fica vermelho

@onready var _cronometro: Label = $Cronometro


func _process(_delta: float) -> void:
	if owner.estado == "fim":
		_cronometro.visible = false
		return

	_cronometro.visible = true
	# usa a duração da partida do Hub (owner), pra não divergir do real
	var restante: int = max(0, int(ceil(owner.DURACAO - owner.tempo)))
	_cronometro.text = str(restante)

	if restante <= URGENCIA:
		var p: float = 1.0 + 0.18 * sin(owner.tempo * 12.0)
		_cronometro.scale = Vector2(p, p)
		_cronometro.modulate = Color(1.0, 0.4, 0.4)
	else:
		_cronometro.scale = Vector2.ONE
		_cronometro.modulate = Color.WHITE
