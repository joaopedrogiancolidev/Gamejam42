extends Node2D

# ============================================================
#  GLITCH MANAGER  -  GIMMICK ASSIMÉTRICO DO HUB
#
#  Durante a partida, "glitches" nascem na FAIXA DO TOPO e
#  ATRAPALHAM um dos lados (embaralham/escondem a tela daquele
#  minigame: tremor + estática + notas piscando).
#
#  A pegada: quem sofre o glitch NÃO consegue consertar sozinho.
#  Só o OUTRO LADO conserta, SEGURANDO uma tecla extra ~1.5s
#  (uma tarefinha a mais enquanto ainda tem que jogar o próprio
#  minigame). O botão quebrado vai se restaurando (frames 5->0)
#  conforme o anel de progresso enche.
#
#   - Glitch na ESQUERDA (Dance/azul)  -> direita SEGURA [I]
#   - Glitch na DIREITA  (Waves/vermelho) -> esquerda SEGURA [E]
#
#  Sem acoplamento com a lógica dos minigames: só mexo na
#  position/modulate do nó-raiz de cada lado (tremor + piscada).
# ============================================================

# regiões de cada lado (batem com o layout do Hub.tscn)
const REGIAO_ESQ := Rect2(0, 144, 640, 576)
const REGIAO_DIR := Rect2(640, 144, 640, 576)

# teclas de conserto (uma por jogador; o jogador conserta o lado OPOSTO)
const TECLA_REPARO_ESQ := KEY_E   # jogador esquerdo -> conserta glitch da DIREITA
const TECLA_REPARO_DIR := KEY_I   # jogador direito  -> conserta glitch da ESQUERDA

# ritmo de spawn
const PRIMEIRO_SPAWN := 3.5
const SPAWN_MIN := 4.0
const SPAWN_MAX := 6.5

const HOLD_TIME := 1.7            # segundos segurando pra consertar
const DECAY := 0.9               # quão rápido o progresso regride ao soltar
const JITTER := 8.0              # amplitude do tremor (px)

@onready var _font: Font = ThemeDB.fallback_font

var _dance: Node2D
var _waves: Node2D
var _base_esq: Vector2
var _base_dir: Vector2

var _frames_azul: Array[Texture2D] = []
var _frames_verm: Array[Texture2D] = []

# estado do glitch atual (um por vez, pra ficar legível)
var _ativo: bool = false
var _lado: String = ""           # "esq" | "dir"
var _progresso: float = 0.0
var _spawn_t: float = PRIMEIRO_SPAWN
var _pulse: float = 0.0
var _prev_estado: String = "rodando"


func _ready() -> void:
	_dance = owner.get_node("Dance")
	_waves = owner.get_node("Waves")
	_base_esq = _dance.position
	_base_dir = _waves.position
	_frames_azul = _carregar_frames("res://assets/broken_botton_blue/broken_botton_blue")
	_frames_verm = _carregar_frames("res://assets/broken_botton_red/broken_botton_red")


func _carregar_frames(prefixo: String) -> Array[Texture2D]:
	var fs: Array[Texture2D] = []
	for i in range(16):
		var caminho := "%s%d.png" % [prefixo, i]
		if ResourceLoader.exists(caminho):
			fs.append(load(caminho) as Texture2D)
		elif fs.size() > 0:
			break
	return fs


func _process(delta: float) -> void:
	var estado: String = owner.estado

	# partida acabou -> limpa tudo e some
	if estado != "rodando":
		if _ativo or _prev_estado == "rodando":
			_limpar()
		_prev_estado = estado
		queue_redraw()
		return

	# voltou a rodar (reinício) -> reseta o relógio de spawn
	if _prev_estado != "rodando":
		_spawn_t = PRIMEIRO_SPAWN
	_prev_estado = estado

	_pulse += delta

	if _ativo:
		_atualizar_glitch(delta)
	else:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_tentar_spawn()

	queue_redraw()


# ------------------------------------------------------------
#  SPAWN
# ------------------------------------------------------------
func _tentar_spawn() -> void:
	# só ataca um lado que ainda está jogando
	var pode_esq: bool = _dance.ativo
	var pode_dir: bool = _waves.ativo
	if not pode_esq and not pode_dir:
		_spawn_t = SPAWN_MIN
		return

	if pode_esq and pode_dir:
		_lado = "esq" if randf() < 0.5 else "dir"
	else:
		_lado = "esq" if pode_esq else "dir"

	_ativo = true
	_progresso = 0.0


func _atualizar_glitch(delta: float) -> void:
	var no_afetado: Node2D = _dance if _lado == "esq" else _waves

	# se o lado afetado terminou no meio do glitch, cancela
	if not no_afetado.ativo:
		_resolver()
		return

	# conserto: o OUTRO lado segura a tecla dele
	var tecla: int = TECLA_REPARO_DIR if _lado == "esq" else TECLA_REPARO_ESQ
	if Input.is_key_pressed(tecla):
		_progresso += delta / HOLD_TIME
	else:
		_progresso = maxf(0.0, _progresso - delta * DECAY)

	if _progresso >= 1.0:
		_resolver()
		return

	# aplica o estrago visual no lado afetado (tremor + piscada)
	var base: Vector2 = _base_esq if _lado == "esq" else _base_dir
	var tremor := Vector2(randf_range(-JITTER, JITTER), randf_range(-JITTER, JITTER))
	no_afetado.position = base + tremor
	no_afetado.modulate.a = 0.25 if randf() < 0.14 else 1.0


func _resolver() -> void:
	_ativo = false
	_progresso = 0.0
	# devolve o lado afetado ao normal
	_dance.position = _base_esq
	_dance.modulate = Color.WHITE
	_waves.position = _base_dir
	_waves.modulate = Color.WHITE
	_spawn_t = randf_range(SPAWN_MIN, SPAWN_MAX)


func _limpar() -> void:
	_ativo = false
	_progresso = 0.0
	if _dance:
		_dance.position = _base_esq
		_dance.modulate = Color.WHITE
	if _waves:
		_waves.position = _base_dir
		_waves.modulate = Color.WHITE


# ------------------------------------------------------------
#  DESENHO  -  estática sobre o lado + botão quebrado + prompt
# ------------------------------------------------------------
func _draw() -> void:
	if not _ativo:
		return

	var regiao: Rect2 = REGIAO_ESQ if _lado == "esq" else REGIAO_DIR
	var cor: Color = Color(0.45, 0.7, 1.0) if _lado == "esq" else Color(1.0, 0.35, 0.35)

	_desenhar_estatica(regiao, cor)
	_desenhar_botao_e_prompt(cor)


func _desenhar_estatica(regiao: Rect2, cor: Color) -> void:
	# bandas horizontais aleatórias = ruído de sinal
	for i in 18:
		var y: float = regiao.position.y + randf() * regiao.size.y
		var h: float = randf_range(2.0, 14.0)
		var a: float = randf_range(0.05, 0.20)
		draw_rect(Rect2(regiao.position.x, y, regiao.size.x, h), Color(cor.r, cor.g, cor.b, a))

	# RGB-split: dois slivers brilhantes deslocados
	for i in 3:
		var y: float = regiao.position.y + randf() * regiao.size.y
		var off: float = randf_range(-6.0, 6.0)
		draw_rect(Rect2(regiao.position.x + off, y, regiao.size.x, 2.0), Color(1.0, 0.2, 0.4, 0.35))
		draw_rect(Rect2(regiao.position.x - off, y + 2.0, regiao.size.x, 2.0), Color(0.2, 1.0, 1.0, 0.35))


func _desenhar_botao_e_prompt(cor: Color) -> void:
	var frames: Array[Texture2D] = _frames_azul if _lado == "esq" else _frames_verm
	# o aviso aparece do lado de QUEM CONSERTA (o lado oposto ao do glitch),
	# pra chamar a atenção do outro jogador
	var centro := Vector2(1130, 64) if _lado == "esq" else Vector2(150, 64)

	# botão quebrado: frame 0 = inteiro, último = quebrado.
	# progresso conserta -> volta pro frame 0.
	if not frames.is_empty():
		var idx: int = int(round((1.0 - _progresso) * (frames.size() - 1)))
		idx = clampi(idx, 0, frames.size() - 1)
		var tex: Texture2D = frames[idx]
		var p: float = 1.0 + 0.06 * sin(_pulse * 8.0)
		var tam := Vector2(86, 86) * p
		draw_texture_rect(tex, Rect2(centro - tam * 0.5, tam), false)

	# anel de progresso do conserto
	var ang_fim: float = -PI / 2.0 + TAU * clampf(_progresso, 0.0, 1.0)
	draw_arc(centro, 52.0, 0, TAU, 40, Color(1, 1, 1, 0.10), 3.0)
	draw_arc(centro, 52.0, -PI / 2.0, ang_fim, 40, Color(0.5, 1.0, 0.7), 5.0, true)

	# prompt: quem conserta e qual tecla segurar
	if _font == null:
		return
	var txt: String
	if _lado == "esq":
		txt = "DIREITA: SEGURE [I]"
	else:
		txt = "ESQUERDA: SEGURE [E]"
	var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var brilho: float = 0.6 + 0.4 * sin(_pulse * 6.0)
	draw_string(_font, Vector2(centro.x - w / 2.0, centro.y + 70.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(cor.r, cor.g, cor.b, brilho))
