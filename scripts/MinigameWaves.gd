extends Node2D

# ============================================================
#  MINIGAME - REGULAÇÃO DE ONDAS EMOCIONAIS  (J K L)
#
#  3 ondas (ansiedade / tristeza / raiva). O objetivo é mantê-las
#  ESTÁVEIS (calmas e centradas na zona verde). Conforme a sessão
#  avança e o paciente FALA, as ondas ficam irregulares e saem do
#  centro. SEGURE J/K/L pra "puxar" a onda de volta.
#
#  Pegadinha: puxar gasta FOCO (barra). Você NÃO consegue regular
#  as 3 ao mesmo tempo - tem que escolher qual está pior.
#  Sobreviva até o fim da sessão sem deixar o COLAPSO encher.
#
#  TESTAR: abra a cena e aperte F6.
#  (os números marcados com TUNE são pra vocês balancearem)
# ============================================================

enum Estado { SESSAO, FALHA, VITORIA }

const W: float = 1280.0
const H: float = 720.0
const DURACAO: float = 55.0        # TUNE: tamanho da sessão (segundos)

# escalas de desenho
const NIVEL_PX: float = 60.0       # quanto o desvio do centro vira pixels
const AGIT_PX: float = 55.0        # amplitude da onda agitada
const ZONA: float = 28.0           # meia-altura da zona estável (verde)

# regulação / foco  (TUNE)
const PULL_NIVEL: float = 1.5      # força de recentralizar
const PULL_AGIT: float = 1.4       # força de acalmar
const DRAIN: float = 26.0          # foco gasto por tecla segurada / s
const RECUP_FOCO: float = 16.0     # foco recuperado / s

# perturbações (TUNE)
const RED_THRESH: float = 0.62     # acima disso a onda está "instável"

var CANAIS := [
	{"code": KEY_J, "label": "J", "emo": "ANSIEDADE", "cor": Color("ff7bbf"), "base": 210.0, "nivel": 0.0, "agit": 0.0, "fase": 0.0, "held": false, "flash": 0.0},
	{"code": KEY_K, "label": "K", "emo": "TRISTEZA",  "cor": Color("c850ff"), "base": 370.0, "nivel": 0.0, "agit": 0.0, "fase": 1.0, "held": false, "flash": 0.0},
	{"code": KEY_L, "label": "L", "emo": "RAIVA",     "cor": Color("ff6a3d"), "base": 530.0, "nivel": 0.0, "agit": 0.0, "fase": 2.0, "held": false, "flash": 0.0},
]

const FALAS := [
	"...eu não consigo desligar a cabeça.",
	"...sinto que decepciono todo mundo.",
	"...tem dias que nada importa.",
	"...por que sempre comigo?",
	"...eu devia estar melhor a essa altura.",
	"...não sei se isso adianta.",
]

var estado: int = Estado.SESSAO
var tempo: float = 0.0
var foco: float = 100.0
var colapso: float = 0.0
var dist_timer: float = 2.0

var _popups: Array = []
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font


# ------------------------------------------------------------
func _process(delta: float) -> void:
	for p in _popups:
		p.t -= delta
	_popups = _popups.filter(func(p): return p.t > 0.0)
	for c in CANAIS:
		c.flash = maxf(0.0, c.flash - delta * 3.0)
		c.fase += delta * (2.0 + c.agit * 6.0)

	queue_redraw()

	if estado != Estado.SESSAO:
		return

	tempo += delta
	var dificuldade: float = 1.0 + tempo / 28.0

	# foco: gasta por tecla segurada, recupera sempre um pouco
	var segurando: int = 0
	for c in CANAIS:
		if c.held:
			segurando += 1
	foco = clampf(foco + RECUP_FOCO * delta - segurando * DRAIN * delta, 0.0, 100.0)
	var foco_frac: float = foco / 100.0

	# atualiza cada onda
	for c in CANAIS:
		# decaimento natural lento (emoção não se regula sozinha rápido)
		c.agit = maxf(0.0, c.agit - 0.05 * delta)
		c.nivel = move_toward(c.nivel, 0.0, 0.06 * delta)
		# puxar (segurando + com foco)
		if c.held and foco > 3.0:
			c.agit = maxf(0.0, c.agit - PULL_AGIT * foco_frac * delta)
			c.nivel = move_toward(c.nivel, 0.0, PULL_NIVEL * foco_frac * delta)
		c.agit = clampf(c.agit, 0.0, 1.4)
		c.nivel = clampf(c.nivel, -1.3, 1.3)

	# perturbações = o paciente falando
	dist_timer -= delta
	if dist_timer <= 0.0:
		_perturbar(dificuldade)
		dist_timer = randf_range(1.6, 2.6) / dificuldade

	# colapso sobe com ondas instáveis, recua quando tudo calmo
	var pior: float = 0.0
	var soma_dano: float = 0.0
	for c in CANAIS:
		var b: float = _instab(c)
		pior = maxf(pior, b)
		if b > RED_THRESH:
			soma_dano += (b - RED_THRESH)
	if soma_dano > 0.0:
		colapso = minf(100.0, colapso + soma_dano * 75.0 * delta)
	elif pior < 0.45:
		colapso = maxf(0.0, colapso - 16.0 * delta)
	colapso = clampf(colapso, 0.0, 100.0)

	if colapso >= 100.0:
		estado = Estado.FALHA
	elif tempo >= DURACAO:
		estado = Estado.VITORIA


func _instab(c) -> float:
	return clampf(absf(c.nivel) * 0.55 + c.agit * 0.78, 0.0, 1.5)


func _perturbar(dif: float) -> void:
	var i: int = randi() % CANAIS.size()
	var c = CANAIS[i]
	c.agit = clampf(c.agit + randf_range(0.3, 0.55) * dif, 0.0, 1.4)
	c.nivel = clampf(c.nivel + randf_range(-0.5, 0.5) * dif, -1.3, 1.3)
	c.flash = 1.0
	_popups.append({"x": 70.0, "y": c.base - 70.0, "txt": FALAS[randi() % FALAS.size()], "cor": c.cor, "t": 2.4})


# ------------------------------------------------------------
#  INPUT
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	if estado != Estado.SESSAO:
		if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()
		return

	for c in CANAIS:
		if event.keycode == c.code:
			c.held = event.pressed
			return


func _reiniciar() -> void:
	estado = Estado.SESSAO
	tempo = 0.0
	foco = 100.0
	colapso = 0.0
	dist_timer = 2.0
	_popups.clear()
	for c in CANAIS:
		c.nivel = 0.0
		c.agit = 0.0
		c.held = false
		c.flash = 0.0


# ------------------------------------------------------------
#  DESENHO
# ------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("0a0a12"))

	for c in CANAIS:
		_desenhar_canal(c)

	# HUD
	_texto("ESPECTRO EMOCIONAL  (segure J K L pra regular)", Vector2(40, 44), 22, Color("c850ff"))

	# barra de FOCO
	var pf := Vector2(40, 640)
	_texto("FOCO", Vector2(pf.x, pf.y - 8), 15, Color(0.8, 0.85, 1.0))
	draw_rect(Rect2(pf.x, pf.y, 360, 18), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pf.x, pf.y, 360 * (foco / 100.0), 18), Color(0.4, 0.7, 1.0).lerp(Color(1.0, 0.5, 0.3), 1.0 - foco / 100.0))
	draw_rect(Rect2(pf.x, pf.y, 360, 18), Color(1, 1, 1, 0.2), false, 2.0)

	# barra de COLAPSO
	var pc := Vector2(W - 400, 640)
	_texto("RISCO DE COLAPSO", Vector2(pc.x, pc.y - 8), 15, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pc.x, pc.y, 360, 18), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pc.x, pc.y, 360 * (colapso / 100.0), 18), Color(0.3, 1.0, 0.5).lerp(Color(1.0, 0.2, 0.2), colapso / 100.0))
	draw_rect(Rect2(pc.x, pc.y, 360, 18), Color(1, 1, 1, 0.2), false, 2.0)

	# progresso da SESSÃO
	var ps := Vector2(W / 2 - 250, 678)
	_texto("SESSÃO", Vector2(ps.x, ps.y - 8), 14, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(ps.x, ps.y, 500, 12), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(ps.x, ps.y, 500 * clampf(tempo / DURACAO, 0.0, 1.0), 12), Color("46d6a0"))

	# falas do paciente
	for p in _popups:
		var a: float = clampf(p.t / 2.4, 0.0, 1.0)
		var col: Color = p.cor
		col.a = a
		_texto("« %s »" % p.txt, Vector2(p.x, p.y), 18, col)

	if estado == Estado.FALHA:
		_overlay("O PACIENTE ENTROU EM COLAPSO", Color("ff3b3b"))
	elif estado == Estado.VITORIA:
		_overlay("SESSÃO ESTABILIZADA", Color("46d6a0"))


func _desenhar_canal(c) -> void:
	var inst: float = _instab(c)
	var instavel: bool = inst > RED_THRESH

	# zona estável (verde quando calmo, vermelha quando instável)
	var cor_zona: Color = Color(0.3, 1.0, 0.5, 0.08).lerp(Color(1.0, 0.3, 0.3, 0.14), clampf(inst, 0.0, 1.0))
	draw_rect(Rect2(0, c.base - ZONA, W, ZONA * 2), cor_zona)
	draw_line(Vector2(0, c.base), Vector2(W, c.base), Color(1, 1, 1, 0.10), 1.0)

	# destaque quando segurando (puxando)
	if c.held:
		draw_rect(Rect2(0, c.base - ZONA, W, ZONA * 2), Color(0.45, 0.8, 1.0, 0.10))

	# a onda
	draw_polyline(_pontos_onda(c), c.cor, 3.0)

	# rótulo
	if _font:
		var cor_lbl: Color = Color.WHITE if c.held else c.cor
		draw_string(_font, Vector2(24, c.base + 8), c.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, cor_lbl)
		draw_string(_font, Vector2(60, c.base + 6), c.emo, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(c.cor.r, c.cor.g, c.cor.b, 0.7))
		if instavel:
			draw_string(_font, Vector2(W - 150, c.base + 6), "INSTÁVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.4, 0.4))
		elif c.held:
			draw_string(_font, Vector2(W - 150, c.base + 6), "PUXANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.85, 1.0))


func _pontos_onda(c) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var base_y: float = c.base + c.nivel * NIVEL_PX
	var amp: float = (0.06 + c.agit) * AGIT_PX
	var x: float = 0.0
	while x <= W:
		var t: float = x * 0.013 + c.fase
		var y: float = base_y + sin(t) * amp
		# harmônico + jitter aparecem conforme a agitação (fica irregular)
		y += sin(t * 2.4 + 1.0) * amp * 0.5 * c.agit
		y += randf_range(-1.0, 1.0) * amp * 0.3 * c.agit
		pts.append(Vector2(x, y))
		x += 6.0
	return pts


func _overlay(titulo: String, cor: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.76))
	_texto_centro(titulo, H / 2 - 30, 42, cor)
	_texto_centro("Sessão: %d%%    Estabilidade final: %d%%" % [int(tempo / DURACAO * 100.0), int(100.0 - colapso)], H / 2 + 30, 22, Color.WHITE)
	_texto_centro("ENTER pra recomeçar", H / 2 + 80, 22, Color(0.8, 0.8, 0.9))


func _texto(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _texto_centro(txt: String, y: float, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(W / 2 - w / 2, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
