extends Node2D

# ============================================================
#  MINIGAME (estilo Persona 4: Dancing) - 3 botões  [v2]
#
#  As notas NASCEM NO CENTRO e VOAM PRA FORA rumo a 3 alvos
#  radiais (J esq-baixo, K topo, L dir-baixo). Aperte a tecla
#  do alvo quando a nota chega.
#  Mecânicas: TOQUE, SEGURAR e agora ACORDES (2 notas juntas
#  em alvos diferentes = um "passo de dança", ligadas por linha).
#
#  >>> ESTILO_NOTA: troque entre "estrela" e "circulo" pra mudar
#      a aparência das notas. (deixei variável como você quis)
#
#  TESTAR: abra a cena e aperte F6. Roda sem música.
#  MÚSICA: troque "song_time += delta" pela posição do
#  AudioStreamPlayer (evita drift).
# ============================================================

enum Estado { JOGANDO, COMPLETO }

const ESTILO_NOTA: String = "estrela"   # "estrela" ou "circulo"

const META_PONTOS: int = 6000
const BPM: float = 125.0
var beat_dur: float = 60.0 / BPM
const LEAD: float = 1.8
const APPROACH: float = 1.1
const R_ALVO: float = 42.0
const R_NOTA: float = 30.0
const RAIO: float = 250.0
const JANELA_PERFEITO: float = 0.05
const JANELA_BOM: float = 0.11
const CHANCE_HOLD: float = 0.18
const CHANCE_ACORDE: float = 0.20

const W: float = 1280.0
const H: float = 720.0
var C := Vector2(W / 2, H / 2 + 20)

var ALVOS := [
	{"code": KEY_J, "label": "J", "cor": Color("ff7bbf"), "ang": deg_to_rad(150), "pos": Vector2.ZERO, "flash": 0.0, "held": false},
	{"code": KEY_K, "label": "K", "cor": Color("c850ff"), "ang": deg_to_rad(270), "pos": Vector2.ZERO, "flash": 0.0, "held": false},
	{"code": KEY_L, "label": "L", "cor": Color("ff6a3d"), "ang": deg_to_rad(30),  "pos": Vector2.ZERO, "flash": 0.0, "held": false},
]

var estado: int = Estado.JOGANDO
var song_time: float = -LEAD
var notas: Array = []
var prox_beat: float = 4.0
var _grupo_id: int = 0

var score: int = 0
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
	for a in ALVOS:
		a.pos = C + Vector2(cos(a.ang), sin(a.ang)) * RAIO


func _gerar() -> void:
	while prox_beat * beat_dur - APPROACH <= song_time + 0.4:
		if song_time > 6.0 and randf() < CHANCE_ACORDE:
			_criar_acorde(prox_beat)
		else:
			_criar_nota(prox_beat, randi() % 3, randf() < CHANCE_HOLD, -1)
			if song_time > 8.0 and randf() < 0.26:
				_criar_nota(prox_beat + 0.5, randi() % 3, false, -1)
		prox_beat += 1.0


func _criar_nota(beat: float, key: int, hold: bool, grupo: int) -> void:
	var n := {
		"hit_time": beat * beat_dur, "end_time": 0.0, "key": key, "hold": hold, "grupo": grupo,
		"resolvido": false, "acertou": false, "segurando": false
	}
	if hold:
		n.end_time = n.hit_time + randf_range(0.8, 1.2)
	notas.append(n)


# Acorde: 2 notas no MESMO tempo, em alvos diferentes.
func _criar_acorde(beat: float) -> void:
	var k1: int = randi() % 3
	var k2: int = (k1 + 1 + randi() % 2) % 3
	_grupo_id += 1
	_criar_nota(beat, k1, false, _grupo_id)
	_criar_nota(beat, k2, false, _grupo_id)


# ------------------------------------------------------------
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

	queue_redraw()

	if estado != Estado.JOGANDO:
		return

	# >>> trocar por get_playback_position() se usar música
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

	if score >= META_PONTOS:
		estado = Estado.COMPLETO


func _pos_nota(n) -> Vector2:
	var alvo = ALVOS[n.key]
	var prog: float = clampf((song_time - (n.hit_time - APPROACH)) / APPROACH, 0.0, 1.0)
	return C.lerp(alvo.pos, prog)


# ------------------------------------------------------------
#  INPUT
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	if estado == Estado.COMPLETO:
		if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()
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
		score += 100 * mult
		_popup(pos, "PERFEITO!", Color(0.4, 1.0, 0.7))
		_burst(pos, Color(0.4, 1.0, 0.7))
	else:
		n_bom += 1
		score += 50 * mult
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
	score += 150 * mult
	_popup(ALVOS[n.key].pos, "SEGUROU!", Color(0.45, 0.8, 1.0))
	_burst(ALVOS[n.key].pos, Color(0.45, 0.8, 1.0))


func _errar(n, txt: String) -> void:
	combo = 0
	n_erro += 1
	_popup(ALVOS[n.key].pos, txt, Color(1.0, 0.4, 0.4))


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 50.0, "txt": txt, "cor": cor, "t": 0.8})


func _burst(pos: Vector2, cor: Color) -> void:
	_bursts.append({"x": pos.x, "y": pos.y, "cor": cor, "t": 0.4})


func _reiniciar() -> void:
	song_time = -LEAD
	estado = Estado.JOGANDO
	notas.clear()
	prox_beat = 4.0
	_grupo_id = 0
	score = 0
	combo = 0
	combo_max = 0
	n_perfeito = 0
	n_bom = 0
	n_erro = 0
	_popups.clear()
	_bursts.clear()
	for a in ALVOS:
		a.held = false
		a.flash = 0.0


# ------------------------------------------------------------
#  DESENHO
# ------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("0a0a12"))

	# núcleo pulsante (a "mente")
	var pr: float = 26.0 + sin(_core * 4.0) * 4.0
	draw_circle(C, pr + 14, Color(0.5, 0.4, 0.8, 0.10))
	draw_circle(C, pr, Color(0.5, 0.4, 0.8, 0.35))
	draw_circle(C, pr * 0.5, Color(0.9, 0.85, 1.0, 0.5))

	for a in ALVOS:
		_desenhar_alvo(a)

	# linhas dos acordes (liga as 2 notas do mesmo grupo)
	var grupos := {}
	for n in notas:
		if (n.resolvido and not n.segurando) or n.grupo < 0:
			continue
		var p: Vector2 = _pos_nota(n)
		if grupos.has(n.grupo):
			grupos[n.grupo].append(p)
		else:
			grupos[n.grupo] = [p]
	for g in grupos.values():
		if g.size() >= 2:
			draw_line(g[0], g[1], Color(1, 1, 1, 0.30), 3.0)

	for n in notas:
		_desenhar_nota(n)

	for bu in _bursts:
		var prog: float = 1.0 - bu.t / 0.4
		var rr: float = 12.0 + prog * 55.0
		var c: Color = bu.cor
		c.a = (1.0 - prog) * 0.8
		draw_arc(Vector2(bu.x, bu.y), rr, 0, TAU, 40, c, 3.0)

	# HUD
	_texto("RITMO EMOCIONAL  (J K L)", Vector2(40, 50), 24, Color("c850ff"))
	_texto("SCORE: %d" % score, Vector2(W - 250, 45), 22, Color.WHITE)
	_texto("COMBO: %d" % combo, Vector2(W - 250, 75), 18, Color("ffd24a"))
	var pb := Vector2(W / 2 - 250, 60)
	_texto("META", Vector2(pb.x, pb.y - 8), 14, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pb.x, pb.y, 500, 14), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pb.x, pb.y, 500 * clampf(float(score) / META_PONTOS, 0.0, 1.0), 14), Color("46d6a0"))
	draw_rect(Rect2(pb.x, pb.y, 500, 14), Color(1, 1, 1, 0.2), false, 2.0)

	for p in _popups:
		var a2: float = clampf(p.t / 0.8, 0.0, 1.0)
		var c2: Color = p.cor
		c2.a = a2
		_texto_centro_em(p.txt, Vector2(p.x, p.y), 22, c2)

	if song_time < 0.0 and estado == Estado.JOGANDO:
		_texto_centro("PREPARE-SE", 150, 38, Color(0.9, 0.9, 1.0))
		_texto_centro(str(max(int(ceil(-song_time)), 1)), 210, 50, Color("c850ff"))

	if estado == Estado.COMPLETO:
		_overlay()


func _desenhar_alvo(a: Dictionary) -> void:
	var pos: Vector2 = a.pos
	var cor: Color = a.cor
	var frac: float = song_time / beat_dur
	frac = frac - floor(frac)
	var glow: float = (1.0 - frac) * 0.4 + a.flash * 0.6
	draw_arc(pos, R_ALVO, 0, TAU, 44, Color(cor.r, cor.g, cor.b, 0.35 + glow), 3.0)
	draw_circle(pos, R_ALVO - 4, Color(cor.r, cor.g, cor.b, 0.08 + a.flash * 0.3))
	if _font:
		var c: Color = Color.WHITE if a.flash > 0.1 else cor
		var w: float = _font.get_string_size(a.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y + 11), a.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)


func _desenhar_nota(n) -> void:
	if n.resolvido and not n.segurando:
		return
	var alvo = ALVOS[n.key]
	var cor: Color = alvo.cor

	if n.hold and n.segurando:
		var resta: float = clampf((n.end_time - song_time) / maxf(n.end_time - n.hit_time, 0.001), 0.0, 1.0)
		draw_arc(alvo.pos, R_ALVO + 8, -PI / 2, -PI / 2 + TAU * resta, 48, Color(0.45, 0.8, 1.0), 6.0)
		draw_circle(alvo.pos, R_NOTA, Color(0.45, 0.8, 1.0, 0.85))
		_letra(alvo.label, alvo.pos)
		return

	var pos: Vector2 = _pos_nota(n)
	draw_line(C, pos, Color(cor.r, cor.g, cor.b, 0.18), 2.0)
	_forma_nota(pos, cor)
	_letra(alvo.label, pos)
	if n.hold:
		draw_arc(pos, R_NOTA + 6, 0, TAU, 32, Color(0.45, 0.8, 1.0, 0.7), 2.0)


func _forma_nota(pos: Vector2, cor: Color) -> void:
	if ESTILO_NOTA == "estrela":
		var rot: float = _core * 1.5
		draw_colored_polygon(_estrela(pos, R_NOTA + 6, (R_NOTA + 6) * 0.46, 5, rot), cor)
	else:
		draw_circle(pos, R_NOTA, cor)
		draw_circle(pos, R_NOTA - 5, Color(0.06, 0.06, 0.12, 0.9))


func _estrela(centro: Vector2, r_out: float, r_in: float, pontas: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var total: int = pontas * 2
	for i in total:
		var ang: float = rot + PI * i / pontas - PI / 2
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(centro + Vector2(cos(ang), sin(ang)) * r)
	return pts


func _letra(label: String, pos: Vector2) -> void:
	if _font:
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _overlay() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.78))
	_texto_centro("META ALCANÇADA!", 220, 46, Color("46d6a0"))
	var total: int = n_perfeito + n_bom + n_erro
	var acc: float = 100.0 * float(n_perfeito + n_bom) / float(max(total, 1))
	_texto_centro("Perfeitos: %d    Bons: %d    Erros: %d" % [n_perfeito, n_bom, n_erro], 300, 22, Color.WHITE)
	_texto_centro("Precisão: %.1f%%    Combo máx: %d    Score: %d" % [acc, combo_max, score], 340, 22, Color(0.85, 0.9, 1.0))
	_texto_centro("ENTER pra jogar de novo", 410, 22, Color(0.8, 0.8, 0.9))


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
