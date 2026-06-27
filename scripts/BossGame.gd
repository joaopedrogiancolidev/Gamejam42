extends Node2D

# ============================================================
#  BOSS EMOCIONAL  -  timing estilo OSU (anel de aproximação)
#  nas teclas  J  K  L.
#
#  Você encara UMA emoção (o boss). Cada vez que um alvo pulsa,
#  um ANEL encolhe até o círculo: aperte a tecla no momento exato.
#   - acerto no tempo  -> dano no boss
#   - erro             -> sua ESTABILIDADE cai
#   - nota de SEGURAR  -> prenda a tecla até o fim (respirar junto)
#  Boss zera o HP -> emoção regulada (vitória).
#  Sua estabilidade zera -> você é dominado (derrota).
#
#  TESTAR: abra a cena e aperte F6. Roda sem música.
#  SINCRONIZAR COM MÚSICA: igual ao outro minigame - troque
#  "song_time += delta" por get_playback_position() do
#  AudioStreamPlayer (evita drift).
#
#  >>> Hoje os ataques são gerados na grade de beats (pra rodar
#      já). Pra um boss "coreografado", troque _gerar_ataques()
#      por uma lista fixa de {hit_time, key, hold, dur}.
# ============================================================

enum Estado { LUTANDO, FALHA, VITORIA }

const BPM: float = 125.0
var beat_dur: float = 60.0 / BPM
const LEAD: float = 1.8
var song_time: float = -LEAD

const APPROACH: float = 1.05      # segundos que o anel leva pra encolher
const R_HIT: float = 36.0
const R_MAX: float = 120.0
const JANELA_PERFEITO: float = 0.05
const JANELA_BOM: float = 0.11

const W: float = 1280.0
const H: float = 720.0

# 3 alvos = J K L (em linha, embaixo)
var ALVOS := [
	{"key": KEY_J, "label": "J", "x": W / 2 - 220, "y": 540.0, "cor": Color("ff7bbf"), "flash": 0.0, "held": false},
	{"key": KEY_K, "label": "K", "x": W / 2,        "y": 540.0, "cor": Color("c850ff"), "flash": 0.0, "held": false},
	{"key": KEY_L, "label": "L", "x": W / 2 + 220, "y": 540.0, "cor": Color("ff6a3d"), "flash": 0.0, "held": false},
]

# fases do boss (cor + nome) conforme o HP cai -> raiva crescente
const FASES := [
	{"nome": "INQUIETAÇÃO", "cor": Color("c850ff")},
	{"nome": "TENSÃO",      "cor": Color("ff6a3d")},
	{"nome": "EXPLOSÃO",    "cor": Color("ff3b3b")},
]

var estado: int = Estado.LUTANDO
var ataques: Array = []
var prox_beat: float = 4.0

var boss_hp: float = 100.0
var estab: float = 100.0
var score: int = 0
var combo: int = 0
var combo_max: int = 0
var n_perfeito: int = 0
var n_bom: int = 0
var n_erro: int = 0

var _boss_shake: float = 0.0
var _boss_flash: float = 0.0
var _boss_bob: float = 0.0
var _dano_flash: float = 0.0
var _popups: Array = []
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font


func _fase() -> int:
	if boss_hp > 66.0:
		return 0
	elif boss_hp > 33.0:
		return 1
	return 2


# ------------------------------------------------------------
#  Gera ataques na grade de beats, mais densos conforme a fase.
# ------------------------------------------------------------
func _gerar_ataques() -> void:
	# cria todos os ataques cujo anel já deveria estar aparecendo
	while prox_beat * beat_dur - APPROACH <= song_time + 0.4:
		var key: int = randi() % 3
		var hold: bool = randf() < 0.15
		var dur: float = 1.5 if hold else 0.0
		ataques.append({
			"hit_time": prox_beat * beat_dur, "key": key, "hold": hold, "dur": dur,
			"resolvido": false, "acertou": false, "segurando": false
		})
		var passo: float = [1.0, 0.75, 0.5][_fase()]
		if hold:
			passo = maxf(passo, 1.5)
		prox_beat += passo


# ------------------------------------------------------------
#  LOOP
# ------------------------------------------------------------
func _process(delta: float) -> void:
	for alvo in ALVOS:
		if alvo.flash > 0.0:
			alvo.flash = maxf(0.0, alvo.flash - delta * 5.0)
	for p in _popups:
		p.t -= delta
		p.y -= delta * 30.0
	_popups = _popups.filter(func(p): return p.t > 0.0)
	_boss_shake = maxf(0.0, _boss_shake - delta * 30.0)
	_boss_flash = maxf(0.0, _boss_flash - delta * 4.0)
	_dano_flash = maxf(0.0, _dano_flash - delta * 2.0)
	_boss_bob += delta

	queue_redraw()

	if estado != Estado.LUTANDO:
		return

	# >>> trocar por get_playback_position() se usar música
	song_time += delta

	if song_time >= 0.0:
		_gerar_ataques()

	# resolve ataques (miss / hold)
	for a in ataques:
		if a.resolvido:
			continue
		if a.hold and a.segurando:
			if song_time >= a.hit_time + a.dur:
				a.segurando = false
				a.resolvido = true
				a.acertou = true
				_hold_completo(a)
			elif not ALVOS[a.key].held:
				a.segurando = false
				a.resolvido = true
				_errar(a, "SOLTOU CEDO")
		else:
			if song_time > a.hit_time + JANELA_BOM:
				a.resolvido = true
				_errar(a, "ERROU")

	# limpa lixo antigo
	ataques = ataques.filter(func(a): return not a.resolvido or a.segurando)

	if estab <= 0.0:
		estab = 0.0
		estado = Estado.FALHA
	elif boss_hp <= 0.0:
		boss_hp = 0.0
		estado = Estado.VITORIA


# ------------------------------------------------------------
#  INPUT
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	if estado != Estado.LUTANDO:
		if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()
		return

	for i in ALVOS.size():
		if event.keycode == ALVOS[i].key:
			if event.pressed:
				_press(i)
			else:
				ALVOS[i].held = false
			return


func _press(li: int) -> void:
	ALVOS[li].held = true
	ALVOS[li].flash = 1.0
	if song_time < 0.0:
		return
	var melhor = null
	var md: float = 999.0
	for a in ataques:
		if a.key == li and not a.resolvido and not a.segurando:
			var dt: float = absf(a.hit_time - song_time)
			if dt < md:
				md = dt
				melhor = a
	if melhor != null and md <= JANELA_BOM:
		_julgar(melhor, md)


func _julgar(a, dt: float) -> void:
	var pos := Vector2(ALVOS[a.key].x, ALVOS[a.key].y)
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	_boss_flash = 1.0
	_boss_shake = 6.0
	if dt <= JANELA_PERFEITO:
		n_perfeito += 1
		score += 100 * mult
		boss_hp = maxf(0.0, boss_hp - 2.6)
		_popup(pos, "PERFEITO!", Color(0.4, 1.0, 0.7))
	else:
		n_bom += 1
		score += 50 * mult
		boss_hp = maxf(0.0, boss_hp - 1.2)
		_popup(pos, "bom", Color(1.0, 0.85, 0.4))
	if a.hold:
		a.segurando = true
	else:
		a.resolvido = true
		a.acertou = true


func _hold_completo(a) -> void:
	combo += 1
	combo_max = max(combo_max, combo)
	score += 200
	boss_hp = maxf(0.0, boss_hp - 4.0)
	estab = minf(100.0, estab + 2.0)
	_boss_flash = 1.0
	_popup(Vector2(ALVOS[a.key].x, ALVOS[a.key].y), "RESPIROU", Color(0.45, 0.8, 1.0))


func _errar(a, txt: String) -> void:
	combo = 0
	n_erro += 1
	estab = maxf(0.0, estab - 9.0)
	_dano_flash = 0.6
	_popup(Vector2(ALVOS[a.key].x, ALVOS[a.key].y), txt, Color(1.0, 0.4, 0.4))


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 50.0, "txt": txt, "cor": cor, "t": 0.8})


func _reiniciar() -> void:
	song_time = -LEAD
	estado = Estado.LUTANDO
	ataques.clear()
	prox_beat = 4.0
	boss_hp = 100.0
	estab = 100.0
	score = 0
	combo = 0
	combo_max = 0
	n_perfeito = 0
	n_bom = 0
	n_erro = 0
	_popups.clear()
	for alvo in ALVOS:
		alvo.held = false
		alvo.flash = 0.0


# ------------------------------------------------------------
#  DESENHO
# ------------------------------------------------------------
func _draw() -> void:
	var fase: int = _fase()
	var cor_fase: Color = FASES[fase].cor
	draw_rect(Rect2(0, 0, W, H), Color("0a0a12"))

	_desenhar_boss(cor_fase)

	# alvos + anéis
	for a in ataques:
		_desenhar_ataque(a)
	for alvo in ALVOS:
		_desenhar_alvo(alvo)

	# HUD
	_texto("BOSS EMOCIONAL  -  %s" % FASES[fase].nome, Vector2(40, 50), 24, cor_fase)
	_texto("SCORE: %d" % score, Vector2(W - 250, 45), 22, Color.WHITE)
	_texto("COMBO: %d" % combo, Vector2(W - 250, 75), 18, Color("ffd24a"))
	_barra("HP DA EMOÇÃO", Vector2(W / 2 - 300, 100), 600, 18, boss_hp / 100.0, cor_fase, true)
	_barra("SUA ESTABILIDADE", Vector2(W / 2 - 200, 650), 400, 18, estab / 100.0, Color(0.3, 1.0, 0.5), false)

	for p in _popups:
		var alfa: float = clampf(p.t / 0.8, 0.0, 1.0)
		var c: Color = p.cor
		c.a = alfa
		_texto_centro_em(p.txt, Vector2(p.x, p.y), 22, c)

	if song_time < 0.0 and estado == Estado.LUTANDO:
		_texto_centro("PREPARE-SE", H / 2 - 20, 38, Color(0.9, 0.9, 1.0))
		_texto_centro(str(max(int(ceil(-song_time)), 1)), H / 2 + 40, 56, cor_fase)

	if _dano_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.2, 0.2, _dano_flash * 0.22))

	if estado == Estado.FALHA:
		_overlay("VOCÊ FOI DOMINADO", Color("ff3b3b"))
	elif estado == Estado.VITORIA:
		_overlay("EMOÇÃO REGULADA", Color("46d6a0"))


func _desenhar_boss(cor: Color) -> void:
	var bob: float = sin(_boss_bob * 2.0) * 8.0
	var sh := Vector2(randf_range(-_boss_shake, _boss_shake), randf_range(-_boss_shake, _boss_shake))
	var c := Vector2(W / 2, 270 + bob) + sh
	var cor_final: Color = cor.lerp(Color.WHITE, _boss_flash * 0.7)
	# halo
	draw_circle(c, 130, Color(cor.r, cor.g, cor.b, 0.10))
	# corpo
	draw_circle(c, 95, Color(cor_final.r, cor_final.g, cor_final.b, 0.9))
	draw_circle(c, 60, Color(0.05, 0.05, 0.1, 0.92))
	# "olhos" reagindo
	var olho := 12.0 + _boss_flash * 4.0
	draw_circle(c + Vector2(-26, -6), olho, cor_final)
	draw_circle(c + Vector2(26, -6), olho, cor_final)


func _desenhar_ataque(a) -> void:
	var alvo = ALVOS[a.key]
	var pos := Vector2(alvo.x, alvo.y)
	var cor: Color = alvo.cor

	if a.hold and a.segurando:
		var resta: float = clampf((a.hit_time + a.dur - song_time) / maxf(a.dur, 0.001), 0.0, 1.0)
		draw_arc(pos, R_HIT + 6, -PI / 2, -PI / 2 + TAU * resta, 40, Color(0.45, 0.8, 1.0), 6.0)
		draw_circle(pos, R_HIT * 0.6, Color(0.45, 0.8, 1.0, 0.8))
		return

	var prog: float = clampf((song_time - (a.hit_time - APPROACH)) / APPROACH, 0.0, 1.0)
	var ring_r: float = lerpf(R_MAX, R_HIT, prog)
	# anel que encolhe (osu)
	draw_arc(pos, ring_r, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	# marcador no centro
	draw_circle(pos, R_HIT * 0.45, Color(cor.r, cor.g, cor.b, 0.9))
	if a.hold and _font:
		draw_string(_font, Vector2(pos.x - 24, pos.y - R_HIT - 14), "SEGURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 1.0))


func _desenhar_alvo(alvo: Dictionary) -> void:
	var pos := Vector2(alvo.x, alvo.y)
	var cor: Color = alvo.cor
	draw_arc(pos, R_HIT, 0, TAU, 40, Color(cor.r, cor.g, cor.b, 0.35 + alvo.flash * 0.6), 3.0)
	if _font:
		var c: Color = Color.WHITE if alvo.flash > 0.1 else cor
		var w: float = _font.get_string_size(alvo.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y + 80), alvo.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, c)


func _barra(titulo: String, pos: Vector2, largura: float, altura: float, frac: float, cor: Color, do_topo: bool) -> void:
	var ty: float = pos.y - 8 if do_topo else pos.y - 8
	_texto(titulo, Vector2(pos.x, ty), 14, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pos.x, pos.y, largura, altura), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pos.x, pos.y, largura * clampf(frac, 0.0, 1.0), altura), cor)
	draw_rect(Rect2(pos.x, pos.y, largura, altura), Color(1, 1, 1, 0.2), false, 2.0)


func _overlay(titulo: String, cor: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.76))
	_texto_centro(titulo, 220, 46, cor)
	var total: int = n_perfeito + n_bom + n_erro
	var acc: float = 100.0 * float(n_perfeito + n_bom) / float(max(total, 1))
	_texto_centro("Perfeitos: %d    Bons: %d    Erros: %d" % [n_perfeito, n_bom, n_erro], 300, 22, Color.WHITE)
	_texto_centro("Precisão: %.1f%%    Combo máx: %d    Score: %d" % [acc, combo_max, score], 340, 22, Color(0.85, 0.9, 1.0))
	_texto_centro("ENTER pra encarar de novo", 410, 22, Color(0.8, 0.8, 0.9))


func _texto(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _texto_centro(txt: String, y: float, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(W / 2 - w / 2, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _texto_centro_em(txt: String, pos: Vector2, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
