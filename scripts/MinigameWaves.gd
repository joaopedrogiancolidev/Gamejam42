extends Node2D

# ============================================================
#  MINIGAME WAVES  -  LADO DIREITO (emocional)  -  teclas J K L
#  Versão integrada: largura 640, pontua por manter as ondas
#  estáveis (score/META) e falha por colapso (falhou). O Hub
#  decide o fim.
# ============================================================

const LARGURA: float = 640.0
const H: float = 720.0

const NIVEL_PX: float = 56.0
const AGIT_PX: float = 52.0
const ZONA: float = 26.0

const PULL_NIVEL: float = 2.2      # TUNE (puxada mais forte)
const PULL_AGIT: float = 2.0       # TUNE
const DRAIN: float = 16.0          # TUNE (gasta menos foco)
const RECUP_FOCO: float = 24.0     # TUNE (recupera mais rápido)
const RED_THRESH: float = 0.70

const RATE_SCORE: float = 110.0    # TUNE: pontos/s quando 100% estável

# --- contrato com o Hub ---
var META: int = 3000
var score: int = 0
var ativo: bool = true
var falhou: bool = false

var CANAIS := [
	{"code": KEY_J, "label": "J", "emo": "ANSIEDADE", "cor": Color("ff7bbf"), "base": 200.0, "nivel": 0.0, "agit": 0.0, "fase": 0.0, "held": false, "flash": 0.0},
	{"code": KEY_K, "label": "K", "emo": "TRISTEZA",  "cor": Color("c850ff"), "base": 360.0, "nivel": 0.0, "agit": 0.0, "fase": 1.0, "held": false, "flash": 0.0},
	{"code": KEY_L, "label": "L", "emo": "RAIVA",     "cor": Color("ff6a3d"), "base": 520.0, "nivel": 0.0, "agit": 0.0, "fase": 2.0, "held": false, "flash": 0.0},
]

const FALAS := [
	"...não consigo desligar a cabeça.",
	"...sinto que decepciono todos.",
	"...tem dias que nada importa.",
	"...por que sempre comigo?",
	"...eu devia estar melhor.",
	"...não sei se isso adianta.",
]

var tempo: float = 0.0
var foco: float = 100.0
var colapso: float = 0.0
var dist_timer: float = 3.5
var _score_f: float = 0.0

var _popups: Array = []
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font


func reset() -> void:
	tempo = 0.0
	foco = 100.0
	colapso = 0.0
	dist_timer = 3.5
	score = 0
	_score_f = 0.0
	ativo = true
	falhou = false
	_popups.clear()
	for c in CANAIS:
		c.nivel = 0.0
		c.agit = 0.0
		c.held = false
		c.flash = 0.0


func _process(delta: float) -> void:
	for p in _popups:
		p.t -= delta
	_popups = _popups.filter(func(p): return p.t > 0.0)
	for c in CANAIS:
		c.flash = maxf(0.0, c.flash - delta * 3.0)
		c.fase += delta * (2.0 + c.agit * 6.0)

	queue_redraw()

	if not ativo:
		return

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

	# pontua por estabilidade
	_score_f += (1.0 - clampf(pior, 0.0, 1.0)) * RATE_SCORE * delta
	score = int(_score_f)

	if colapso >= 100.0:
		colapso = 100.0
		falhou = true


func _instab(c) -> float:
	return clampf(absf(c.nivel) * 0.55 + c.agit * 0.78, 0.0, 1.5)


func _perturbar(dif: float) -> void:
	var i: int = randi() % CANAIS.size()
	var c = CANAIS[i]
	c.agit = clampf(c.agit + randf_range(0.15, 0.30) * dif, 0.0, 1.4)
	c.nivel = clampf(c.nivel + randf_range(-0.3, 0.3) * dif, -1.3, 1.3)
	c.flash = 1.0
	_popups.append({"x": 40.0, "y": c.base - 64.0, "txt": FALAS[randi() % FALAS.size()], "cor": c.cor, "t": 2.4})


func _unhandled_input(event: InputEvent) -> void:
	if not ativo or not (event is InputEventKey) or event.echo:
		return
	for c in CANAIS:
		if event.keycode == c.code:
			c.held = event.pressed
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, LARGURA, H), Color("0a0a12"))

	for c in CANAIS:
		_desenhar_canal(c)

	_texto("EMOCIONAL  (J K L)", Vector2(28, 40), 22, Color("c850ff"))
	_texto("SCORE: %d" % score, Vector2(LARGURA - 200, 40), 20, Color.WHITE)
	var pb := Vector2(40, 70)
	draw_rect(Rect2(pb.x, pb.y, 560, 10), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pb.x, pb.y, 560 * clampf(float(score) / META, 0.0, 1.0), 10), Color("46d6a0"))

	# FOCO
	var pf := Vector2(40, 636)
	_texto("FOCO", Vector2(pf.x, pf.y - 8), 14, Color(0.8, 0.85, 1.0))
	draw_rect(Rect2(pf.x, pf.y, 560, 14), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pf.x, pf.y, 560 * (foco / 100.0), 14), Color(0.4, 0.7, 1.0).lerp(Color(1.0, 0.5, 0.3), 1.0 - foco / 100.0))
	# COLAPSO
	var pc := Vector2(40, 678)
	_texto("RISCO DE COLAPSO", Vector2(pc.x, pc.y - 8), 14, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pc.x, pc.y, 560, 14), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pc.x, pc.y, 560 * (colapso / 100.0), 14), Color(0.3, 1.0, 0.5).lerp(Color(1.0, 0.2, 0.2), colapso / 100.0))

	for p in _popups:
		var a: float = clampf(p.t / 2.4, 0.0, 1.0)
		var col: Color = p.cor
		col.a = a
		_texto("« %s »" % p.txt, Vector2(p.x, p.y), 17, col)


func _desenhar_canal(c) -> void:
	var inst: float = _instab(c)
	var cor_zona: Color = Color(0.3, 1.0, 0.5, 0.08).lerp(Color(1.0, 0.3, 0.3, 0.14), clampf(inst, 0.0, 1.0))
	draw_rect(Rect2(0, c.base - ZONA, LARGURA, ZONA * 2), cor_zona)
	draw_line(Vector2(0, c.base), Vector2(LARGURA, c.base), Color(1, 1, 1, 0.10), 1.0)
	if c.held:
		draw_rect(Rect2(0, c.base - ZONA, LARGURA, ZONA * 2), Color(0.45, 0.8, 1.0, 0.10))

	draw_polyline(_pontos_onda(c), c.cor, 3.0)

	if _font:
		var cor_lbl: Color = Color.WHITE if c.held else c.cor
		draw_string(_font, Vector2(20, c.base + 8), c.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, cor_lbl)
		draw_string(_font, Vector2(54, c.base + 6), c.emo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(c.cor.r, c.cor.g, c.cor.b, 0.7))
		if inst > RED_THRESH:
			draw_string(_font, Vector2(LARGURA - 130, c.base + 6), "INSTÁVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.4, 0.4))
		elif c.held:
			draw_string(_font, Vector2(LARGURA - 130, c.base + 6), "PUXANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.5, 0.85, 1.0))


func _pontos_onda(c) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var base_y: float = c.base + c.nivel * NIVEL_PX
	var amp: float = (0.06 + c.agit) * AGIT_PX
	var x: float = 0.0
	while x <= LARGURA:
		var t: float = x * 0.014 + c.fase
		var y: float = base_y + sin(t) * amp
		y += sin(t * 2.4 + 1.0) * amp * 0.5 * c.agit
		y += randf_range(-1.0, 1.0) * amp * 0.3 * c.agit
		pts.append(Vector2(x, y))
		x += 6.0
	return pts


func _texto(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
