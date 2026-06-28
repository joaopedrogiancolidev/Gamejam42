extends Node2D

# ============================================================
#  MINIGAME DANCE  -  LADO ESQUERDO (racional)  -  teclas S D F
#  Versão com cena editável: posições e parâmetros ajustáveis
#  no inspetor do Godot. O Hub coordena o fim de jogo.
# ============================================================

# --- Parâmetros de ritmo (editáveis no inspetor) ---
@export var BPM: float = 90.0
@export var LEAD: float = 3.0          # tempo de preparação antes das notas
@export var APPROACH: float = 2.5      # duração da viagem de cada nota ao alvo
@export var BEAT_INICIAL: float = 8.0  # beat em que a primeira nota é gerada

# --- Janelas de acerto (quanto maior, mais perdoador) ---
@export var JANELA_PERFEITO: float = 0.10
@export var JANELA_BOM: float = 0.23

# --- Geração de notas ---
@export var CHANCE_HOLD: float = 0.0    # holds REMOVIDOS: não nasce mais nota de segurar
@export var CHANCE_ACORDE: float = 0.20  # acordes simultâneos (S+D etc) — mecânica destaque

# --- Visuais ---
@export_enum("estrela", "circulo") var ESTILO_NOTA: String = "estrela"
@export var R_ALVO: float = 40.0
@export var R_NOTA: float = 28.0

# --- Contrato com o Hub ---
@export var META: int = 5600
var score: int = 0
var ativo: bool = true
var falhou: bool = false

# --- Referências aos nós da cena ---
@onready var _centro        := $Centro
@onready var _alvo_s        := $Alvos/AlvoS
@onready var _alvo_d        := $Alvos/AlvoD
@onready var _alvo_f        := $Alvos/AlvoF
@onready var _score_label   := $HUD/ScoreLabel
@onready var _combo_label   := $HUD/ComboLabel
@onready var _fill_score    := $HUD/BarraScoreFill
@onready var _prepare_label := $HUD/PrepareLabel

# --- Dados dos alvos (tecla, cor; posição lida da cena em _ready) ---
var ALVOS := [
	{"code": KEY_S, "label": "S", "cor": Color("6ad0ff"), "pos": Vector2.ZERO, "flash": 0.0, "held": false},
	{"code": KEY_D, "label": "D", "cor": Color("8a7bff"), "pos": Vector2.ZERO, "flash": 0.0, "held": false},
	{"code": KEY_F, "label": "F", "cor": Color("46d6a0"), "pos": Vector2.ZERO, "flash": 0.0, "held": false},
]

# --- Estado interno ---
var beat_dur: float = 0.0
var C: Vector2 = Vector2.ZERO  # posição do centro (lida do nó $Centro)
var song_time: float = 0.0
var notas: Array = []
var prox_beat: float = 0.0
var _grupo_id: int = 0

var combo: int = 0
var combo_max: int = 0
var n_perfeito: int = 0
var n_bom: int = 0
var n_erro: int = 0

var _popups: Array = []
var _bursts: Array = []
var _core: float = 0.0
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font
	beat_dur = 60.0 / BPM
	song_time = -LEAD
	prox_beat = BEAT_INICIAL

	# Lê posições dos nós da cena — mova os nós no editor para reposicionar
	C = _centro.position
	ALVOS[0].pos = _alvo_s.position
	ALVOS[1].pos = _alvo_d.position
	ALVOS[2].pos = _alvo_f.position


func reset() -> void:
	song_time = -LEAD
	notas.clear()
	prox_beat = BEAT_INICIAL
	_grupo_id = 0
	score = 0
	combo = 0
	combo_max = 0
	n_perfeito = 0
	n_bom = 0
	n_erro = 0
	_popups.clear()
	_bursts.clear()
	ativo = true
	falhou = false
	for a in ALVOS:
		a.held = false
		a.flash = 0.0


func _gerar() -> void:
	while prox_beat * beat_dur - APPROACH <= song_time + 0.4:
		if song_time > 6.0 and randf() < CHANCE_ACORDE:
			_criar_acorde(prox_beat)
		else:
			_criar_nota(prox_beat, randi() % 3, randf() < CHANCE_HOLD, -1)
		prox_beat += 1.0


func _criar_nota(beat: float, key: int, hold: bool, grupo: int) -> void:
	var n := {
		"hit_time": beat * beat_dur, "end_time": 0.0, "key": key, "hold": hold, "grupo": grupo,
		"resolvido": false, "acertou": false, "segurando": false
	}
	if hold:
		n.end_time = n.hit_time + randf_range(0.8, 1.2)
	notas.append(n)


func _criar_acorde(beat: float) -> void:
	var k1: int = randi() % 3
	var k2: int = (k1 + 1 + randi() % 2) % 3
	_grupo_id += 1
	_criar_nota(beat, k1, false, _grupo_id)
	_criar_nota(beat, k2, false, _grupo_id)


func _process(delta: float) -> void:
	_core += delta
	for a in ALVOS:
		if a.flash > 0.0:
			a.flash = maxf(0.0, a.flash - delta * 5.0)
	for p in _popups:
		p.t -= delta
		p.y -= delta * 28.0
	_popups = _popups.filter(func(p): return p.t > 0.0)
	for bu in _bursts:
		bu.t -= delta
	_bursts = _bursts.filter(func(bu): return bu.t > 0.0)

	_aplicar_visual()
	queue_redraw()

	if not ativo:
		return

	song_time += delta
	if song_time >= 0.0:
		_gerar()

	for n in notas:
		if n.resolvido:
			continue
		if n.hold and n.segurando:
			if song_time >= n.end_time:
				n.resolvido = true
				n.acertou = true
				_hold_ok(n)
		else:
			if song_time > n.hit_time + JANELA_BOM:
				n.resolvido = true
				_errar(n, "ERROU")

	notas = notas.filter(func(n): return not n.resolvido or n.segurando)

	if score >= META:
		score = META
		ativo = false


func _aplicar_visual() -> void:
	_score_label.text = "SCORE: %d" % score
	_combo_label.text = "COMBO: %d" % combo
	_fill_score.scale.x = clampf(float(score) / META, 0.0, 1.0)

	# Mostra contagem regressiva antes das notas começarem
	if song_time < 0.0 and ativo:
		_prepare_label.visible = true
		_prepare_label.text = "PREPARE-SE\n%d" % max(int(ceil(-song_time)), 1)
	else:
		_prepare_label.visible = false

	# Atualiza cor das letras dos alvos conforme o flash (tecla pressionada)
	var teclas := [
		_alvo_s.get_node("Tecla"),
		_alvo_d.get_node("Tecla"),
		_alvo_f.get_node("Tecla"),
	]
	for i in ALVOS.size():
		if ALVOS[i].flash > 0.1:
			teclas[i].modulate = Color.WHITE
		else:
			teclas[i].modulate = ALVOS[i].cor


func _pos_nota(n) -> Vector2:
	var alvo = ALVOS[n.key]
	var prog: float = clampf((song_time - (n.hit_time - APPROACH)) / APPROACH, 0.0, 1.0)
	return C.lerp(alvo.pos, prog)


func _unhandled_input(event: InputEvent) -> void:
	if not ativo or not (event is InputEventKey) or event.echo:
		return
	for i in ALVOS.size():
		if event.keycode == ALVOS[i].code:
			if event.pressed:
				ALVOS[i].held = true
				ALVOS[i].flash = 1.0
				_press(i)
			else:
				ALVOS[i].held = false
				_release(i)
			return


func _press(ki: int) -> void:
	if song_time < 0.0:
		return
	var melhor = null
	var md: float = 999.0
	for n in notas:
		if n.key == ki and not n.resolvido and not n.segurando:
			var dt: float = absf(n.hit_time - song_time)
			if dt < md:
				md = dt
				melhor = n
	if melhor != null and md <= JANELA_BOM:
		_julgar(melhor, md)


func _release(ki: int) -> void:
	for n in notas:
		if n.hold and n.segurando and n.key == ki and not n.resolvido:
			if song_time >= n.end_time - JANELA_BOM:
				n.resolvido = true
				n.acertou = true
				_hold_ok(n)
			else:
				n.resolvido = true
				n.segurando = false
				_errar(n, "SOLTOU CEDO")
			return


func _julgar(n, dt: float) -> void:
	var pos: Vector2 = ALVOS[n.key].pos
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	if dt <= JANELA_PERFEITO:
		n_perfeito += 1
		score += 400 * mult
		_popup(pos, "PERFEITO!", Color(0.4, 1.0, 0.7))
		_burst(pos, Color(0.4, 1.0, 0.7))
	else:
		n_bom += 1
		score += 200 * mult
		_popup(pos, "bom", Color(1.0, 0.85, 0.4))
		_burst(pos, ALVOS[n.key].cor)
	if n.hold:
		n.segurando = true
	else:
		n.resolvido = true
		n.acertou = true


func _hold_ok(n) -> void:
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	score += 600 * mult
	_popup(ALVOS[n.key].pos, "SEGUROU!", Color(0.45, 0.8, 1.0))
	_burst(ALVOS[n.key].pos, Color(0.45, 0.8, 1.0))


func _errar(n, _txt: String) -> void:
	combo = 0
	n_erro += 1
	_popup(ALVOS[n.key].pos, _txt, Color(1.0, 0.4, 0.4))


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 50.0, "txt": txt, "cor": cor, "t": 0.8})


func _burst(pos: Vector2, cor: Color) -> void:
	_bursts.append({"x": pos.x, "y": pos.y, "cor": cor, "t": 0.4})


# ------------------------------------------------------------
#  DESENHO  —  apenas elementos dinâmicos (notas, efeitos)
#  O fundo e o HUD são nós da cena atualizados por _aplicar_visual()
# ------------------------------------------------------------
func _draw() -> void:
	if C == Vector2.ZERO:
		return  # aguarda _ready() inicializar

	# Pulso central animado
	var pr: float = 24.0 + sin(_core * 4.0) * 4.0
	draw_circle(C, pr + 12, Color(0.4, 0.55, 0.8, 0.10))
	draw_circle(C, pr, Color(0.4, 0.55, 0.8, 0.35))
	draw_circle(C, pr * 0.5, Color(0.85, 0.9, 1.0, 0.5))

	# Alvos (círculos nas posições dos nós; letras são Labels da cena)
	for a in ALVOS:
		_desenhar_alvo(a)

	# Acordes (estilo Persona 4 Dancing All Night): as duas notas ficam
	# LIGADAS por um traço neon grosso que ENGROSSA conforme se aproxima
	# das extremidades, avisando que precisam ser apertadas JUNTAS.
	var grupos := {}
	for n in notas:
		if n.resolvido or n.grupo < 0:
			continue
		var info = grupos.get(n.grupo, {"pts": [], "prog": 0.0})
		info.pts.append(_pos_nota(n))
		info.prog = clampf((song_time - (n.hit_time - APPROACH)) / APPROACH, 0.0, 1.0)
		grupos[n.grupo] = info
	for info in grupos.values():
		if info.pts.size() >= 2:
			_desenhar_acorde(info.pts[0], info.pts[1], info.prog)

	# Notas em movimento
	for n in notas:
		_desenhar_nota(n)

	# Efeitos de burst ao acertar
	for bu in _bursts:
		var prog: float = 1.0 - bu.t / 0.4
		var c: Color = bu.cor
		c.a = (1.0 - prog) * 0.8
		draw_arc(Vector2(bu.x, bu.y), 12.0 + prog * 55.0, 0, TAU, 40, c, 3.0)

	# Textos flutuantes de feedback (PERFEITO, bom, ERROU…)
	for p in _popups:
		var a2: float = clampf(p.t / 0.8, 0.0, 1.0)
		var c2: Color = p.cor
		c2.a = a2
		_texto_centro_em(p.txt, Vector2(p.x, p.y), 20, c2)


func _desenhar_alvo(a: Dictionary) -> void:
	var pos: Vector2 = a.pos
	var cor: Color = a.cor
	var frac: float = song_time / beat_dur if beat_dur > 0.0 else 0.0
	frac = frac - floor(frac)
	var glow: float = (1.0 - frac) * 0.4 + a.flash * 0.6
	draw_arc(pos, R_ALVO, 0, TAU, 44, Color(cor.r, cor.g, cor.b, 0.35 + glow), 3.0)
	draw_circle(pos, R_ALVO - 4, Color(cor.r, cor.g, cor.b, 0.08 + a.flash * 0.3))
	# Letra do alvo renderizada pelo Label filho do nó na cena


func _desenhar_nota(n) -> void:
	if n.resolvido and not n.segurando:
		return
	var alvo = ALVOS[n.key]
	var cor: Color = alvo.cor
	if n.hold and n.segurando:
		# Nota sendo segurada: arco de progresso ao redor do alvo
		var resta: float = clampf((n.end_time - song_time) / maxf(n.end_time - n.hit_time, 0.001), 0.0, 1.0)
		draw_arc(alvo.pos, R_ALVO + 8, -PI / 2, -PI / 2 + TAU * resta, 48, Color(0.45, 0.8, 1.0), 6.0)
		draw_circle(alvo.pos, R_NOTA, Color(0.45, 0.8, 1.0, 0.85))
		# Letra omitida aqui — o Label da cena já exibe no alvo
		return
	var pos: Vector2 = _pos_nota(n)
	draw_line(C, pos, Color(cor.r, cor.g, cor.b, 0.18), 2.0)
	_forma_nota(pos, cor)
	_letra(alvo.label, pos)  # letra acompanha a nota em movimento
	if n.hold:
		draw_arc(pos, R_NOTA + 6, 0, TAU, 32, Color(0.45, 0.8, 1.0, 0.7), 2.0)


func _desenhar_acorde(a: Vector2, b: Vector2, prog: float) -> void:
	# traço neon rosa/magenta vibrante pra destacar do resto
	var cor := Color(1.0, 0.35, 0.85)
	# a grossura cresce conforme as notas se aproximam dos alvos
	var w: float = lerpf(4.0, 16.0, prog)
	var pulso: float = 0.85 + 0.15 * sin(_core * 8.0)
	# glow neon: camadas largas e translúcidas + núcleo branco brilhante
	draw_line(a, b, Color(cor.r, cor.g, cor.b, 0.12 * pulso), w * 2.6)
	draw_line(a, b, Color(cor.r, cor.g, cor.b, 0.30 * pulso), w * 1.7)
	draw_line(a, b, Color(cor.r, cor.g, cor.b, 0.95), w)
	draw_line(a, b, Color(1, 1, 1, 0.9), maxf(2.0, w * 0.35))
	# "AO MESMO TEMPO" em cima do traço, no mesmo ângulo da linha
	if _font and prog > 0.15:
		var tam: int = int(lerpf(12.0, 22.0, prog))
		var alpha: float = clampf((prog - 0.15) / 0.5, 0.0, 1.0)
		_texto_na_linha("AO MESMO TEMPO", a, b, w, tam, Color(1.0, 0.6, 0.95, alpha))


# Desenha um texto centralizado SOBRE a linha a->b, girado no ângulo dela.
func _texto_na_linha(txt: String, a: Vector2, b: Vector2, larg_linha: float, tam: int, cor: Color) -> void:
	if _font == null:
		return
	var ang: float = (b - a).angle()
	# mantém o texto sempre legível (nunca de cabeça pra baixo)
	if ang > PI / 2.0 or ang < -PI / 2.0:
		ang += PI
	var meio: Vector2 = (a + b) * 0.5
	# desloca perpendicularmente pra ficar EM CIMA do traço (acima dele)
	var perp := Vector2(cos(ang - PI / 2.0), sin(ang - PI / 2.0))
	var base: Vector2 = meio + perp * (larg_linha * 0.5 + 6.0)
	var w_txt: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_set_transform(base, ang, Vector2.ONE)
	draw_string(_font, Vector2(-w_txt / 2.0, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # reseta a transform do canvas


func _forma_nota(pos: Vector2, cor: Color) -> void:
	if ESTILO_NOTA == "estrela":
		draw_colored_polygon(_estrela(pos, R_NOTA + 6, (R_NOTA + 6) * 0.46, 5, _core * 1.5), cor)
	else:
		draw_circle(pos, R_NOTA, cor)
		draw_circle(pos, R_NOTA - 5, Color(0.06, 0.06, 0.12, 0.9))


func _estrela(centro: Vector2, r_out: float, r_in: float, pontas: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in pontas * 2:
		var ang: float = rot + PI * i / pontas - PI / 2
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(centro + Vector2(cos(ang), sin(ang)) * r)
	return pts


func _letra(label: String, pos: Vector2) -> void:
	if _font:
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _texto_centro_em(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
