extends Node2D

# ============================================================
#  CYBER PSICOLOGO  -  v3  (Godot 4)
#  Loop: JOGA uma area da mente -> DECISAO clinica (texto + escolhas)
#        -> ganha um power-up e inclina o diagnostico -> proxima area.
#
#  ESQUERDA = S D F   |   DIREITA = J K L
#  RAIVA: SEGURE a tecla pra respirar junto.
#  Na DECISAO: aperte 1, 2 ou 3 pra escolher.
# ============================================================

enum Estado { INTRO, JOGANDO, DECISAO, GAME_OVER, FIM }

@export var spawn_inicial: float = 1.7
@export var spawn_minimo: float = 0.5
@export var escalacao_base: float = 0.15
@export var dano_colapso: float = 12.0
@export var colapso_maximo: float = 100.0

const TOTAL_NIVEIS: int = 4
const W: float = 1280.0
const H: float = 720.0
const LANE_Y: float = 380.0
const KEY_Y: float = 488.0

# Areas da mente (nome do nivel + cor de fundo) -> a "cutscene" de clima
const NIVEIS := [
	{"nome": "EMOÇÕES",    "cor": Color("0a0e18")},
	{"nome": "MEMÓRIAS",   "cor": Color("120a16")},
	{"nome": "CRENÇAS",    "cor": Color("0a1014")},
	{"nome": "AUTOIMAGEM", "cor": Color("160a0e")},
]

# Casos clinicos (texto + 2-4 escolhas). Cada escolha inclina um EIXO e da um POWER.
const EVENTOS := [
	{
		"texto": "João sente o coração disparar sem motivo e evita sair de casa. Repete que \"algo ruim vai acontecer\".",
		"escolhas": [
			{"txt": "Ensinar a respirar e nomear o medo", "eixo": "Ansiedade",  "power": "respiracao"},
			{"txt": "Buscar a origem nas memórias antigas", "eixo": "Trauma",     "power": "escuta"},
			{"txt": "Questionar o \"algo ruim vai acontecer\"", "eixo": "Autoimagem", "power": "reenquadre"},
		]
	},
	{
		"texto": "Surge uma lembrança de infância que ele evitava. Toda vez que ela aparece, ele muda de assunto na hora.",
		"escolhas": [
			{"txt": "Ir devagar, criando segurança antes", "eixo": "Trauma",     "power": "vinculo"},
			{"txt": "Confrontar a lembrança de frente", "eixo": "Ansiedade",  "power": "foco"},
			{"txt": "Ligar a lembrança à autoimagem de hoje", "eixo": "Autoimagem", "power": "reenquadre"},
		]
	},
	{
		"texto": "Ele repete baixinho: \"eu estrago tudo\". A frase sempre aparece antes de decisões importantes.",
		"escolhas": [
			{"txt": "Procurar evidências contra a crença", "eixo": "Autoimagem", "power": "reenquadre"},
			{"txt": "Ver de onde a crença nasceu", "eixo": "Trauma",     "power": "escuta"},
			{"txt": "Baixar a ansiedade da decisão primeiro", "eixo": "Ansiedade",  "power": "respiracao"},
		]
	},
	{
		"texto": "João começa a notar a própria voz interior e pergunta: \"e se eu não for o problema?\".",
		"escolhas": [
			{"txt": "Reforçar essa nova narrativa", "eixo": "Autoimagem", "power": "vinculo"},
			{"txt": "Treinar regular a emoção sozinho", "eixo": "Ansiedade",  "power": "foco"},
			{"txt": "Integrar a memória ao presente", "eixo": "Trauma",     "power": "escuta"},
		]
	},
]

const POWER_NOME := {
	"escuta": "Escuta Ativa",
	"reenquadre": "Reenquadramento",
	"respiracao": "Respiração Guiada",
	"vinculo": "Vínculo Terapêutico",
	"foco": "Foco Clínico",
}
const POWER_DESC := {
	"escuta": "glitches escalam mais devagar",
	"reenquadre": "+25% de score por glitch",
	"respiracao": "Raiva acalma mais rápido",
	"vinculo": "o colapso recua sozinho",
	"foco": "glitches mais espaçados",
}
const DIAG_TEXTO := {
	"Ansiedade":  "O sistema vive em alerta. O caminho é segurança e respiro.",
	"Trauma":     "Há um loop preso no passado. O caminho é reprocessar com cuidado.",
	"Autoimagem": "A voz interior aprendeu a se diminuir. O caminho é reescrever a crença.",
}

# ---------- estado de jogo ----------
var lanes: Array = []
var estado: int = Estado.INTRO
var nivel: int = 1
var quota: int = 8
var tratados_nivel: int = 0
var tempo_nivel: float = 0.0
var intro_timer: float = 0.0
var evento_atual = null

var score: int = 0
var combo: int = 0
var melhor_combo: int = 0
var colapso: float = 0.0
var spawn_timer: float = 1.0

# diagnostico
var eixos := {"Ansiedade": 0, "Trauma": 0, "Autoimagem": 0}

# power-ups / modificadores
var mod_escalacao: float = 1.0
var mod_score: float = 1.0
var mod_hold: float = 1.0
var mod_decaimento: float = 0.0
var mod_spawn: float = 1.0
var powerups_ativos: Array = []

# fx
var _shake: float = 0.0
var _popups: Array = []
var _bg_dots: Array = []
var _bg_t: float = 0.0
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font
	_criar_lanes()
	_gerar_bg()
	_reset_mods()
	_preparar_intro()


func _criar_lanes() -> void:
	lanes = [
		{"key": KEY_S, "label": "S", "x": 215.0,  "lado": "E", "glitch": null, "flash": 0.0, "held": false},
		{"key": KEY_D, "label": "D", "x": 375.0,  "lado": "E", "glitch": null, "flash": 0.0, "held": false},
		{"key": KEY_F, "label": "F", "x": 535.0,  "lado": "E", "glitch": null, "flash": 0.0, "held": false},
		{"key": KEY_J, "label": "J", "x": 745.0,  "lado": "D", "glitch": null, "flash": 0.0, "held": false},
		{"key": KEY_K, "label": "K", "x": 905.0,  "lado": "D", "glitch": null, "flash": 0.0, "held": false},
		{"key": KEY_L, "label": "L", "x": 1065.0, "lado": "D", "glitch": null, "flash": 0.0, "held": false},
	]


func _gerar_bg() -> void:
	_bg_dots.clear()
	for i in 30:
		_bg_dots.append({"x": randf() * W, "y": randf() * H, "f": randf_range(0.2, 0.8), "ph": randf() * TAU})


func _reset_mods() -> void:
	mod_escalacao = 1.0
	mod_score = 1.0
	mod_hold = 1.0
	mod_decaimento = 0.0
	mod_spawn = 1.0
	powerups_ativos.clear()


# ---------------- fluxo de niveis ----------------
func _preparar_intro() -> void:
	estado = Estado.INTRO
	intro_timer = 1.7


func _comecar_nivel() -> void:
	estado = Estado.JOGANDO
	tratados_nivel = 0
	tempo_nivel = 0.0
	quota = 6 + nivel * 2
	spawn_timer = spawn_inicial
	_limpar_campo()


func _entrar_decisao() -> void:
	estado = Estado.DECISAO
	_limpar_campo()
	evento_atual = EVENTOS[(nivel - 1) % EVENTOS.size()]


func _escolher(idx: int) -> void:
	if evento_atual == null:
		return
	var escolhas: Array = evento_atual.escolhas
	if idx < 0 or idx >= escolhas.size():
		return
	var esc = escolhas[idx]
	eixos[esc.eixo] += 1
	_aplicar_power(esc.power)
	nivel += 1
	if nivel > TOTAL_NIVEIS:
		estado = Estado.FIM
	else:
		_preparar_intro()


func _aplicar_power(p: String) -> void:
	match p:
		"escuta": mod_escalacao *= 0.85
		"reenquadre": mod_score *= 1.25
		"respiracao": mod_hold *= 0.8
		"vinculo": mod_decaimento += 2.5
		"foco": mod_spawn *= 1.15
	powerups_ativos.append(POWER_NOME[p])


func _dificuldade() -> float:
	return 1.0 + (nivel - 1) * 0.4 + tempo_nivel / 90.0


func _limpar_campo() -> void:
	for lane in lanes:
		if lane.glitch != null and is_instance_valid(lane.glitch):
			lane.glitch.queue_free()
		lane.glitch = null
		lane.held = false
		lane.flash = 0.0


# ---------------- loop ----------------
func _process(delta: float) -> void:
	_bg_t += delta

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		position = Vector2.ZERO

	for p in _popups:
		p.t -= delta
		p.y -= delta * 32.0
	_popups = _popups.filter(func(p): return p.t > 0.0)

	for lane in lanes:
		if lane.flash > 0.0:
			lane.flash = maxf(0.0, lane.flash - delta * 4.0)
		var g = lane.glitch
		if g != null and is_instance_valid(g) and g.requer_hold:
			g.segurando = lane.held

	queue_redraw()

	match estado:
		Estado.INTRO:
			intro_timer -= delta
			if intro_timer <= 0.0:
				_comecar_nivel()
		Estado.JOGANDO:
			tempo_nivel += delta
			if mod_decaimento > 0.0:
				colapso = maxf(0.0, colapso - mod_decaimento * delta)
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawnar_glitch()
				spawn_timer = maxf(spawn_minimo, spawn_inicial / _dificuldade() * mod_spawn)


func _spawnar_glitch() -> void:
	var livres: Array = []
	for i in lanes.size():
		if lanes[i].glitch == null:
			livres.append(i)
	if livres.is_empty():
		return
	var idx: int = livres[randi() % livres.size()]

	var g := Glitch.new()
	g.position = Vector2(lanes[idx].x, LANE_Y)
	g.configurar(randi() % 6, idx, escalacao_base * _dificuldade() * mod_escalacao)
	g.tempo_hold = 1.1 * mod_hold
	g.tratado.connect(_on_glitch_tratado)
	g.corrompido.connect(_on_glitch_corrompido)
	add_child(g)
	lanes[idx].glitch = g


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	match estado:
		Estado.JOGANDO:
			for lane in lanes:
				if event.keycode == lane.key:
					if event.pressed:
						lane.held = true
						_apertar_lane(lane)
					else:
						lane.held = false
					return
		Estado.DECISAO:
			if event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_escolher(event.keycode - KEY_1)
		Estado.GAME_OVER, Estado.FIM:
			if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_reiniciar()


func _apertar_lane(lane: Dictionary) -> void:
	lane.flash = 1.0
	var g = lane.glitch
	if g != null and not g.morto:
		g.tratar()


func _on_glitch_tratado(g) -> void:
	lanes[g.lane_index].glitch = null
	combo += 1
	melhor_combo = max(melhor_combo, combo)
	var mult: int = 1 + combo / 5
	var ganho: int = int(round(10 * mult * mod_score))
	score += ganho
	colapso = maxf(0.0, colapso - 1.0)
	_popup(g.position + Vector2(0, -28), g.reframe, Color(0.55, 1.0, 0.75), 1.7)
	_popup(g.position, "+%d" % ganho, Glitch.CORES[g.tipo], 0.8)
	tratados_nivel += 1
	if estado == Estado.JOGANDO and tratados_nivel >= quota:
		_entrar_decisao()


func _on_glitch_corrompido(g) -> void:
	lanes[g.lane_index].glitch = null
	combo = 0
	colapso += dano_colapso
	_shake = 8.0
	_popup(g.position, "\"%s\"" % g.frase, Color(1.0, 0.4, 0.4), 1.4)
	if colapso >= colapso_maximo:
		colapso = colapso_maximo
		estado = Estado.GAME_OVER
		_limpar_campo()


func _popup(pos: Vector2, txt: String, cor: Color, dur: float = 0.9) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 50.0, "txt": txt, "cor": cor, "t": dur, "dur": dur})


func _reiniciar() -> void:
	_limpar_campo()
	_popups.clear()
	score = 0
	combo = 0
	melhor_combo = 0
	colapso = 0.0
	nivel = 1
	eixos = {"Ansiedade": 0, "Trauma": 0, "Autoimagem": 0}
	_reset_mods()
	_preparar_intro()


# ============================================================
#  DESENHO
# ============================================================
func _draw() -> void:
	var cor_fundo: Color = NIVEIS[clampi(nivel - 1, 0, NIVEIS.size() - 1)].cor
	draw_rect(Rect2(0, 0, W, H), cor_fundo)
	_desenhar_bg()

	match estado:
		Estado.INTRO:
			_desenhar_tabuleiro()
			_desenhar_intro()
		Estado.JOGANDO:
			_desenhar_tabuleiro()
		Estado.DECISAO:
			_desenhar_decisao()
		Estado.GAME_OVER:
			_desenhar_tabuleiro()
			_desenhar_game_over()
		Estado.FIM:
			_desenhar_fim()


func _desenhar_bg() -> void:
	for d in _bg_dots:
		var yy: float = d.y + sin(_bg_t * d.f + d.ph) * 12.0
		var a: float = 0.05 + 0.05 * (0.5 + 0.5 * sin(_bg_t * d.f + d.ph))
		draw_circle(Vector2(d.x, yy), 2.0, Color(0.6, 0.5, 0.9, a))


func _desenhar_tabuleiro() -> void:
	draw_rect(Rect2(W / 2 - 2, 130, 4, 430), Color(0.5, 0.3, 0.8, 0.25))
	_texto("ESQUERDA  -  S D F", Vector2(120, 168), 22, Color("8a7bff"))
	_texto("DIREITA  -  J K L", Vector2(W - 330, 168), 22, Color("ff7bbf"))

	_desenhar_voz_interior()
	for lane in lanes:
		_desenhar_keycap(lane)

	# HUD
	_texto("CYBER PSICOLOGO", Vector2(40, 50), 28, Color("c850ff"))
	var area: String = NIVEIS[clampi(nivel - 1, 0, NIVEIS.size() - 1)].nome
	_texto("ÁREA: %s   (nível %d/%d)" % [area, nivel, TOTAL_NIVEIS], Vector2(40, 80), 16, Color(0.7, 0.7, 0.85))
	_texto("SCORE: %d" % score, Vector2(W - 270, 45), 24, Color.WHITE)
	_texto("COMBO: x%d" % (1 + combo / 5), Vector2(W - 270, 75), 18, Color("ffd24a"))
	_texto("TRATADOS: %d/%d" % [tratados_nivel, quota], Vector2(W - 270, 102), 16, Color("8affc0"))

	# power-ups ativos
	if powerups_ativos.size() > 0:
		_texto("ATIVOS: " + ", ".join(powerups_ativos), Vector2(40, 110), 14, Color(0.6, 0.85, 0.7))

	_texto("Toque pra tratar. RAIVA: SEGURE pra respirar.", Vector2(W / 2 - 230, 668), 15, Color(0.55, 0.55, 0.66))
	_desenhar_barra_colapso(Vector2(W / 2 - 200, 612), 400, 22)

	for p in _popups:
		var a: float = clampf(p.t / p.dur, 0.0, 1.0)
		var c: Color = p.cor
		c.a = a
		_texto(p.txt, Vector2(p.x - 24, p.y), 22, c)


func _desenhar_intro() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	var area: String = NIVEIS[clampi(nivel - 1, 0, NIVEIS.size() - 1)].nome
	_texto_centro("EXPLORANDO:", H / 2 - 50, 22, Color(0.7, 0.7, 0.85))
	_texto_centro(area, H / 2 + 10, 56, Color("c850ff"))


func _desenhar_decisao() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
	var px: float = W / 2 - 380
	var pw: float = 760.0
	var box := Rect2(px, 120, pw, 480)
	draw_rect(box, Color(0.07, 0.07, 0.13, 0.96))
	draw_rect(box, Color(0.45, 0.35, 0.65, 0.7), false, 2.0)

	_texto("ANOTAÇÕES DA SESSÃO", Vector2(px + 28, 165), 18, Color("c850ff"))
	_texto_multi(evento_atual.texto, Vector2(px + 28, 200), pw - 56, 22, Color(0.92, 0.92, 0.96))

	var y: float = 320.0
	var escolhas: Array = evento_atual.escolhas
	for i in escolhas.size():
		var esc = escolhas[i]
		var linha := Rect2(px + 24, y - 26, pw - 48, 52)
		draw_rect(linha, Color(0.12, 0.12, 0.2, 0.9))
		draw_rect(linha, Color(0.4, 0.5, 0.8, 0.5), false, 1.0)
		_texto("%d  ▸  %s" % [i + 1, esc.txt], Vector2(px + 40, y - 2), 20, Color.WHITE)
		_texto("→ %s: %s" % [POWER_NOME[esc.power], POWER_DESC[esc.power]], Vector2(px + 40, y + 18), 13, Color(0.6, 0.8, 0.7))
		y += 72.0

	_texto("Aperte 1, 2 ou 3 para escolher a abordagem.", Vector2(px + 28, 575), 15, Color(0.6, 0.6, 0.72))
	# inclinacao atual
	var diag: String = _eixo_dominante()
	_texto("Diagnóstico tende a: %s" % diag, Vector2(px + 420, 575), 15, Color("ffd24a"))


func _desenhar_game_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.74))
	_texto_centro("COLAPSO MENTAL", H / 2 - 70, 48, Color("ff3b3b"))
	_texto_centro("A sessão foi interrompida na área %s." % NIVEIS[clampi(nivel - 1, 0, NIVEIS.size() - 1)].nome, H / 2 - 10, 22, Color.WHITE)
	_texto_centro("Score: %d   -   Melhor combo: x%d" % [score, 1 + melhor_combo / 5], H / 2 + 30, 20, Color(0.85, 0.85, 0.9))
	_texto_centro("ENTER pra recomeçar a sessão", H / 2 + 80, 22, Color(0.8, 0.8, 0.9))


func _desenhar_fim() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.78))
	var diag: String = _eixo_dominante()
	_texto_centro("SESSÃO CONCLUÍDA", 180, 46, Color("46d6a0"))
	_texto_centro("Você ajudou João a atravessar 4 áreas da mente.", 240, 22, Color(0.9, 0.9, 0.95))
	_texto_centro("Diagnóstico provável: %s" % diag, 320, 32, Color("ffd24a"))
	_texto_multi_centro(DIAG_TEXTO.get(diag, ""), 360, 700, 22, Color(0.85, 0.85, 0.95))
	_texto_centro("Score final: %d" % score, 460, 24, Color.WHITE)
	if powerups_ativos.size() > 0:
		_texto_centro("Ferramentas usadas: " + ", ".join(powerups_ativos), 500, 16, Color(0.6, 0.85, 0.7))
	_texto_centro("ENTER para uma nova sessão", 580, 22, Color(0.8, 0.8, 0.9))


func _eixo_dominante() -> String:
	var melhor: String = "Ansiedade"
	var maxv: int = -1
	for k in eixos.keys():
		if eixos[k] > maxv:
			maxv = eixos[k]
			melhor = k
	return melhor


func _desenhar_voz_interior() -> void:
	var loud = null
	var maxe: float = -1.0
	for lane in lanes:
		var g = lane.glitch
		if g != null and is_instance_valid(g) and not g.morto:
			if g.escalacao > maxe:
				maxe = g.escalacao
				loud = g
	var box := Rect2(W / 2 - 250, 210, 500, 56)
	draw_rect(box, Color(0.08, 0.08, 0.14, 0.85))
	draw_rect(box, Color(0.4, 0.35, 0.6, 0.5), false, 2.0)
	_texto("VOZ INTERIOR", Vector2(box.position.x + 14, box.position.y + 22), 14, Color(0.7, 0.7, 0.85))
	if loud != null:
		var cor := Color(0.9, 0.9, 0.95).lerp(Color(1.0, 0.4, 0.4), clampf(maxe, 0.0, 1.0))
		_texto("\"%s\"" % loud.frase, Vector2(box.position.x + 14, box.position.y + 46), 20, cor)
	else:
		_texto("paciente estável...", Vector2(box.position.x + 14, box.position.y + 46), 18, Color(0.5, 0.6, 0.55))


func _desenhar_keycap(lane: Dictionary) -> void:
	var x: float = lane.x
	var base := Vector2(x, KEY_Y)
	var lado_cor: Color = Color("6a5bff") if lane.lado == "E" else Color("ff5ba8")

	draw_line(Vector2(x, LANE_Y + 40), Vector2(x, base.y - 28), Color(lado_cor.r, lado_cor.g, lado_cor.b, 0.3), 2.0)
	if lane.glitch == null:
		draw_arc(Vector2(x, LANE_Y), 40, 0, TAU, 40, Color(1, 1, 1, 0.08), 2.0)

	var fundo: Color = Color(0.10, 0.10, 0.18).lerp(lado_cor, 0.25 + lane.flash * 0.5)
	if lane.held:
		fundo = fundo.lerp(Color(0.45, 0.8, 1.0), 0.4)
	var r := Rect2(base.x - 34, base.y - 28, 68, 56)
	draw_rect(r, fundo)
	draw_rect(r, lado_cor, false, 2.0)
	if _font:
		var s: String = lane.label
		var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(_font, Vector2(base.x - w / 2, base.y + 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)


func _desenhar_barra_colapso(pos: Vector2, largura: float, altura: float) -> void:
	_texto("RISCO DE COLAPSO", Vector2(pos.x, pos.y - 8), 16, Color(0.8, 0.8, 0.9))
	var fundo := Rect2(pos.x, pos.y, largura, altura)
	draw_rect(fundo, Color(0.12, 0.12, 0.2))
	var frac: float = clampf(colapso / colapso_maximo, 0.0, 1.0)
	draw_rect(Rect2(pos.x, pos.y, largura * frac, altura), Color(0.3, 1.0, 0.5).lerp(Color(1.0, 0.2, 0.2), frac))
	draw_rect(fundo, Color(1, 1, 1, 0.2), false, 2.0)


func _texto(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _texto_centro(txt: String, y: float, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(W / 2 - w / 2, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _texto_multi(txt: String, pos: Vector2, largura: float, tam: int, cor: Color) -> void:
	if _font:
		draw_multiline_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, largura, tam, -1, cor)


func _texto_multi_centro(txt: String, y: float, largura: float, tam: int, cor: Color) -> void:
	if _font:
		draw_multiline_string(_font, Vector2(W / 2 - largura / 2, y), txt, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, -1, cor)
