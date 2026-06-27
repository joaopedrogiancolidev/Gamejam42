extends Node2D

# ============================================================
#  MINIGAME WAVES  -  LÓGICA PURA (lado emocional / J K L)
# ============================================================

# refs de áudio
var _som_j: AudioStreamPlayer2D
var _som_k: AudioStreamPlayer2D
var _som_l: AudioStreamPlayer2D
var _som_ruido: AudioStreamPlayer2D

# desenho das ondas (relativo ao nó do canal -> posição vem da cena)
@export var largura_onda: float = 640.0
const NIVEL_PX: float = 56.0
const AGIT_PX: float = 52.0

# regulação / dificuldade
@export var PULL_NIVEL: float = 2.2
@export var PULL_AGIT: float = 2.0
@export var DRAIN: float = 16.0
@export var RECUP_FOCO: float = 24.0
@export var RED_THRESH: float = 0.70
@export var RATE_SCORE: float = 110.0

# --- contrato com o Hub ---
@export var META: int = 1800
var score: int = 0
var ativo: bool = true
var falhou: bool = false

var CANAIS := [
	{"nome": "CanalJ", "code": KEY_J, "label": "J", "emo": "ANSIEDADE", "cor": Color("ff7bbf"), "nivel": 0.0, "agit": 0.0, "fase": 0.0, "held": false},
	{"nome": "CanalK", "code": KEY_K, "label": "K", "emo": "TRISTEZA",  "cor": Color("c850ff"), "nivel": 0.0, "agit": 0.0, "fase": 1.0, "held": false},
	{"nome": "CanalL", "code": KEY_L, "label": "L", "emo": "RAIVA",     "cor": Color("ff6a3d"), "nivel": 0.0, "agit": 0.0, "fase": 2.0, "held": false},
]

const FALAS := [
	"...não consigo desligar a cabeça.",
	"...sinto que decepciono todos.",
	"...tem dias que nada importa.",
	"...por que sempre comigo?",
	"...eu devia estar melhor.",
	"...não sei si isso adianta.",
]

var tempo: float = 0.0
var foco: float = 100.0
var colapso: float = 0.0
var dist_timer: float = 3.5
var _score_f: float = 0.0
var _fala_t: float = 0.0

# refs de nós (resolvidos no _ready)
var _score_label: Label
var _fala_label: Label
var _fill_score: ColorRect
var _fill_foco: ColorRect
var _fill_colapso: ColorRect


func _ready() -> void:
	randomize()
	# pega os nós visuais de cada canal
	for c in CANAIS:
		var node := $Canais.get_node(c.nome)
		c["onda"] = node.get_node("Onda")
		c["zona"] = node.get_node("Zona")
		c["tecla"] = node.get_node("Tecla")
		c["status"] = node.get_node("Status")
		c.tecla.text = c.label
		var emo: Label = node.get_node("Emo")
		emo.text = c.emo
		emo.modulate = Color(c.cor.r, c.cor.g, c.cor.b, 0.7)
		c.onda.default_color = c.cor
		
	_score_label = $HUD/ScoreLabel
	_fala_label = $HUD/FalaLabel
	_fill_score = $HUD/BarraScoreFill
	_fill_foco = $HUD/BarraFocoFill
	_fill_colapso = $HUD/BarraColapsoFill
	
	# Amarração segura dos nós de som usando caminhos relativos verificados
	if has_node("SomJ"): _som_j = $SomJ
	if has_node("SomK"): _som_k = $SomK
	if has_node("SomL"): _som_l = $SomL
	if has_node("SomRuido"): _som_ruido = $SomRuido
	
	# Inicialização do loop de estresse sonoro
	if _som_ruido:
		_som_ruido.volume_db = -80.0
		if not _som_ruido.playing:
			_som_ruido.play()


func reset() -> void:
	tempo = 0.0
	foco = 100.0
	colapso = 0.0
	dist_timer = 3.5
	score = 0
	_score_f = 0.0
	_fala_t = 0.0
	ativo = true
	falhou = false
	for c in CANAIS:
		c.nivel = 0.0
		c.agit = 0.0
		c.held = false


# ------------------------------------------------------------
#  LÓGICA
# ------------------------------------------------------------
func _process(delta: float) -> void:
	for c in CANAIS:
		c.fase += delta * (2.0 + c.agit * 6.0)
	if _fala_t > 0.0:
		_fala_t -= delta

	if ativo:
		_atualizar_logica(delta)

	_aplicar_visual()


func _atualizar_logica(delta: float) -> void:
	tempo += delta
	var dificuldade: float = 1.0 + tempo / 70.0

	var segurando: int = 0
	for c in CANAIS:
		if c.held:
			segurando += 1
	foco = clampf(foco + RECUP_FOCO * delta - segurando * DRAIN * delta, 0.0, 100.0)
	var foco_frac: float = foco / 100.0

	for c in CANAIS:
		c.agit = maxf(0.0, c.agit - 0.10 * delta)
		c.nivel = move_toward(c.nivel, 0.0, 0.10 * delta)
		if c.held and foco > 3.0:
			c.agit = maxf(0.0, c.agit - PULL_AGIT * foco_frac * delta)
			c.nivel = move_toward(c.nivel, 0.0, PULL_NIVEL * foco_frac * delta)
		c.agit = clampf(c.agit, 0.0, 1.4)
		c.nivel = clampf(c.nivel, -1.3, 1.3)

	dist_timer -= delta
	if dist_timer <= 0.0:
		_perturbar(dificuldade)
		dist_timer = randf_range(2.6, 4.0) / dificuldade

	var pior: float = 0.0
	var soma_dano: float = 0.0
	for c in CANAIS:
		var b: float = _instab(c)
		pior = maxf(pior, b)
		if b > RED_THRESH:
			soma_dano += (b - RED_THRESH)
			
	if soma_dano > 0.0:
		colapso = minf(100.0, colapso + soma_dano * 45.0 * delta)
	elif pior < 0.45:
		colapso = maxf(0.0, colapso - 26.0 * delta)

	_score_f += (1.0 - clampf(pior, 0.0, 1.0)) * RATE_SCORE * delta
	score = int(_score_f)

	if colapso >= 100.0:
		colapso = 100.0
		falhou = true

	# --- CONTROLE DE ÁUDIO DO RUÍDO POR INSTABILIDADE ---
	if _som_ruido:
		if pior > RED_THRESH:
			var instabilidade_extra: float = (pior - RED_THRESH) / (1.5 - RED_THRESH)
			var energia_audio: float = lerpf(0.05, 1.0, instabilidade_extra)
			_som_ruido.volume_db = linear_to_db(energia_audio)
		else:
			_som_ruido.volume_db = move_toward(_som_ruido.volume_db, -80.0, 100.0 * delta)


func _instab(c) -> float:
	return clampf(absf(c.nivel) * 0.55 + c.agit * 0.78, 0.0, 1.5)


func _perturbar(dif: float) -> void:
	var c = CANAIS[randi() % CANAIS.size()]
	c.agit = clampf(c.agit + randf_range(0.15, 0.30) * dif, 0.0, 1.4)
	c.nivel = clampf(c.nivel + randf_range(-0.3, 0.3) * dif, -1.3, 1.3)
	if _fala_label:
		_fala_label.text = "« %s »" % FALAS[randi() % FALAS.size()]
		_fala_label.modulate = Color(c.cor.r, c.cor.g, c.cor.b, 1.0)
		_fala_t = 2.4


func _unhandled_input(event: InputEvent) -> void:
	if not ativo or not (event is InputEventKey) or event.echo:
		return
	for c in CANAIS:
		if event.keycode == c.code:
			c.held = event.pressed
			
			# Dispara o áudio correspondente no exato instante do clique
			if event.pressed:
				match c.label:
					"J": if _som_j: _som_j.play()
					"K": if _som_k: _som_k.play()
					"L": if _som_l: _som_l.play()
			return


# ------------------------------------------------------------
#  ALIMENTA OS NÓS (sem desenhar nada)
# ------------------------------------------------------------
func _aplicar_visual() -> void:
	for c in CANAIS:
		var pts := PackedVector2Array()
		var amp: float = (0.06 + c.agit) * AGIT_PX
		var off: float = c.nivel * NIVEL_PX
		var x: float = 0.0
		while x <= largura_onda:
			var t: float = x * 0.014 + c.fase
			var y: float = off + sin(t) * amp + sin(t * 2.4 + 1.0) * amp * 0.5 * c.agit
			y += randf_range(-1.0, 1.0) * amp * 0.3 * c.agit
			pts.append(Vector2(x, y))
			x += 6.0
		c.onda.points = pts

		var inst: float = _instab(c)
		c.zona.color = Color(0.3, 1.0, 0.5, 0.08).lerp(Color(1.0, 0.3, 0.3, 0.14), clampf(inst, 0.0, 1.0))
		c.tecla.modulate = Color.WHITE if c.held else c.cor
		if inst > RED_THRESH:
			c.status.text = "INSTÁVEL"
			c.status.modulate = Color(1.0, 0.4, 0.4)
		elif c.held:
			c.status.text = "PUXANDO"
			c.status.modulate = Color(0.5, 0.85, 1.0)
		else:
			c.status.text = ""

	if _score_label:
		_score_label.text = "SCORE: %d" % score
	if _fill_score:
		_fill_score.scale.x = clampf(float(score) / META, 0.0, 1.0)
	if _fill_foco:
		_fill_foco.scale.x = foco / 100.0
	if _fill_colapso:
		_fill_colapso.scale.x = colapso / 100.0
	if _fala_label:
		_fala_label.modulate.a = clampf(_fala_t / 2.4, 0.0, 1.0)
