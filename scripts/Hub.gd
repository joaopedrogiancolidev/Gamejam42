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
#   - emocional bem maior    -> FinalEmocao
#   - alguém COLAPSA          -> FinalGameover
# ============================================================

const DURACAO: float = 60.0
const DURACAO_REF: float = 60.0   # duração para a qual as METAs foram balanceadas

# pulsação do background ("respiração do cérebro")
const BG_PULSO_VEL: float = 1.1   # rad/s (~5.7s por ciclo)
const BG_PULSO_AMP: float = 0.12  # quanto o alpha sobe/desce

const CENAS_FINAL := {
	"feliz": preload("res://scenes/FinalFeliz.tscn"),
	"racional": preload("res://scenes/FinalRacional.tscn"),
	"emocional": preload("res://scenes/FinalEmocao.tscn"),
	"gameover": preload("res://scenes/FinalGameover.tscn"),
}

# --- Regras de final ---
const COLAPSO_MIN: int = 1500     # emocional abaixo disso -> Colapso Mental (gameover)
const VAR_LIMITE: float = 0.10    # variação < 10% (em fração da META) -> Integração

# --- Sons curtos de término (todo o resto fica mudo no fim) ---
const SOM_FINAL_POS: AudioStream = preload("res://assets/sfx/musical-fx-roman-stinger-01.mp3")  # Integração
const SOM_FINAL_NEG: AudioStream = preload("res://assets/sfx/miss.mp3")                          # os outros 3

@onready var dance = $Dance
@onready var waves = $Waves
@onready var _background2: Sprite2D = $Background2
@onready var bg_music: AudioStreamPlayer = $bg_music

var estado: String = "rodando"     # "rodando" | "fim"
var final_tipo: String = ""
var tempo: float = 0.0
var _cena_final: Node = null
var _bg_alpha_base: float = 0.2
var _som_final: AudioStreamPlayer = null


func _ready() -> void:
	# o tempo do emocional acompanha a duração da partida
	waves.TEMPO_LIMITE = DURACAO
	# as metas de score escalam com a duração (balanceadas para DURACAO_REF),
	# pra barrinha continuar enchível na mesma proporção
	var fator: float = DURACAO / DURACAO_REF
	dance.META = int(round(dance.META * fator))
	waves.META = int(round(waves.META * fator))
	if _background2:
		_bg_alpha_base = _background2.self_modulate.a
	if not bg_music.playing:
		bg_music.play()


func _process(delta: float) -> void:
	if estado != "rodando":
		return

	tempo += delta
	_pulsar_background()

	# colapso/falha encerra a partida, mas o final depende dos scores
	# (ver _avaliar): só vira "Colapso Mental" se o emocional < 1500.
	if dance.falhou or waves.falhou:
		_avaliar()
		return

	# os dois bateram a pontuação máxima -> acaba na hora (por enquanto)
	if dance.score >= dance.META and waves.score >= waves.META:
		_avaliar()
		return

	if tempo >= DURACAO:
		_avaliar()


# alpha do background sobe e desce devagar = sensação de estar
# "dentro do cérebro" pulsando
func _pulsar_background() -> void:
	if not _background2:
		return
	var a: float = _bg_alpha_base + BG_PULSO_AMP * sin(tempo * BG_PULSO_VEL)
	_background2.self_modulate.a = clampf(a, 0.0, 1.0)


func _avaliar() -> void:
	var rac: int = dance.score
	var emo: int = waves.score

	# DEBUG: mostra os números reais que decidem o final (ver no painel Output)
	print("[FINAL] racional=%d/%d  emocional=%d/%d  colapso=%.0f  tempo=%.1fs" % [
		rac, dance.META, emo, waves.META, waves.colapso, tempo])

	# 1) emocional não segurou a mente -> Colapso Mental
	if emo < COLAPSO_MIN:
		_terminar("gameover")
		return

	# 2) compara em fração da META (ambas = 2000)
	var r: float = float(rac) / float(dance.META)
	var e: float = float(emo) / float(waves.META)
	var diff: float = e - r          # >0: emoção na frente | <0: razão na frente

	if absf(diff) < VAR_LIMITE:
		_terminar("feliz")           # Integração (variação < 10%)
	elif diff > 0.0:
		_terminar("emocional")       # emoção > 10% maior
	else:
		_terminar("racional")        # razão > 10% maior


func _terminar(tipo: String) -> void:
	final_tipo = tipo
	estado = "fim"
	dance.ativo = false
	waves.ativo = false

	# no fim, tudo fica mudo e toca só um som curto de término
	_silenciar_audio()
	_tocar_som_final(tipo)

	# instancia a cena de final (animada) por cima de tudo
	_cena_final = CENAS_FINAL[tipo].instantiate()
	$UI.add_child(_cena_final)

	# preenche os scores se a cena tiver esse label
	var sc = _cena_final.get_node_or_null("Conteudo/Scores")
	if sc:
		var r: int = mini(100, int(float(dance.score) / float(dance.META) * 100.0))
		var e: int = mini(100, int(float(waves.score) / float(waves.META) * 100.0))
		sc.text = "Racional: %d%%      Emocional: %d%%" % [r, e]


# OBS: no fim da partida, quem trata o ENTER é a própria cena de final
# (TemplateLore -> proxima_cena = Menu). O Hub não reinicia mais no ENTER,
# pra não conflitar com o "voltar ao menu".


# para TODOS os sons da partida (música de fundo + qualquer player na árvore
# do jogo: sfx do dance, ondas, ruído etc.)
func _silenciar_audio() -> void:
	bg_music.stop()
	for p in _todos_audio_players(self):
		if p != _som_final and p.playing:
			p.stop()


func _todos_audio_players(node: Node) -> Array:
	var res: Array = []
	for c in node.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D:
			res.append(c)
		res += _todos_audio_players(c)
	return res


# som curto de término: positivo no Integração, negativo nos outros 3
func _tocar_som_final(tipo: String) -> void:
	if _som_final and is_instance_valid(_som_final):
		_som_final.queue_free()
	_som_final = AudioStreamPlayer.new()
	_som_final.bus = &"Master"
	_som_final.stream = SOM_FINAL_POS if tipo == "feliz" else SOM_FINAL_NEG
	add_child(_som_final)
	_som_final.play()


func _reiniciar() -> void:
	if _cena_final and is_instance_valid(_cena_final):
		_cena_final.queue_free()
	_cena_final = null
	if _som_final and is_instance_valid(_som_final):
		_som_final.queue_free()
	_som_final = null
	estado = "rodando"
	final_tipo = ""
	tempo = 0.0
	dance.reset()
	waves.reset()
	# religa a música de fundo (foi parada no fim da partida)
	if not bg_music.playing:
		bg_music.play()


# fundo de tela cheia (atrás dos jogos) -> preenche a margem de cima
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("06060d"))
