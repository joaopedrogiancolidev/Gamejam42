extends Node2D

# ============================================================
#  MINIGAME (osu!-like)  -  duas mecânicas:
#   1) TOQUE: a bolinha tem um ANEL que encolhe. Aperte a tecla
#      mostrada DENTRO da bolinha no instante em que o anel
#      encosta no círculo.
#   2) SEGURAR: aperte, SEGURE pelo tempo do anel azul, e SOLTE
#      no fim (apertar -> segurar -> soltar).
#
#  As bolinhas aparecem em posições ALEATÓRIAS dentro da área
#  delimitada. A tecla necessária (J/K/L) aparece dentro de cada
#  uma. O jogo termina ao atingir a META de pontos (~30s de teste).
#
#  TESTAR: abra a cena e aperte F6. Roda sem música.
#  SINCRONIZAR COM MÚSICA: troque "song_time += delta" pela
#  posição do AudioStreamPlayer (evita drift). Ver comentário.
# ============================================================

enum Estado { JOGANDO, COMPLETO }

# ---- ajuste fino (mexa à vontade) ----
const META_PONTOS: int = 6000      # alvo pra terminar (~30s jogando bem)
const BPM: float = 125.0
var beat_dur: float = 60.0 / BPM
const LEAD: float = 1.8
const APPROACH: float = 1.05       # tempo do anel encolher (Approach Rate)
const R_HIT: float = 38.0
const R_MAX: float = 120.0
const JANELA_PERFEITO: float = 0.05
const JANELA_BOM: float = 0.11
const CHANCE_HOLD: float = 0.22

const W: float = 1280.0
const H: float = 720.0
# área delimitada onde as bolinhas podem nascer
const AREA := Rect2(250, 200, 780, 380)

var KEYS := [
	{"code": KEY_J, "label": "J", "cor": Color("ff7bbf"), "held": false},
	{"code": KEY_K, "label": "K", "cor": Color("c850ff"), "held": false},
	{"code": KEY_L, "label": "L", "cor": Color("ff6a3d"), "held": false},
]

var estado: int = Estado.JOGANDO
var song_time: float = -LEAD
var bolinhas: Array = []
var prox_beat: float = 4.0

var score: int = 0
var combo: int = 0
var combo_max: int = 0
var n_perfeito: int = 0
var n_bom: int = 0
var n_erro: int = 0

var _popups: Array = []
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font


# ------------------------------------------------------------
#  Geração: na grade de beats, posição aleatória, tecla aleatória.
# ------------------------------------------------------------
func _gerar() -> void:
	while prox_beat * beat_dur - APPROACH <= song_time + 0.4:
		_criar_bolinha(prox_beat)
		var passo: float = 1.0
		# de vez em quando adensa com meia-batida
		if song_time > 8.0 and randf() < 0.3:
			_criar_bolinha(prox_beat + 0.5)
		prox_beat += passo


func _criar_bolinha(beat: float) -> void:
	var key: int = randi() % 3
	var hold: bool = randf() < CHANCE_HOLD
	var pos: Vector2 = _pos_livre()
	var b := {
		"hit_time": beat * beat_dur, "end_time": 0.0, "key": key,
		"x": pos.x, "y": pos.y, "hold": hold,
		"resolvido": false, "acertou": false, "segurando": false
	}
	if hold:
		b.end_time = b.hit_time + randf_range(0.8, 1.2)
	bolinhas.append(b)


func _pos_livre() -> Vector2:
	var melhor := Vector2(AREA.position.x + randf() * AREA.size.x, AREA.position.y + randf() * AREA.size.y)
	for _i in 12:
		var p := Vector2(AREA.position.x + randf() * AREA.size.x, AREA.position.y + randf() * AREA.size.y)
		var ok := true
		for b in bolinhas:
			if not b.resolvido and Vector2(b.x, b.y).distance_to(p) < R_HIT * 2.6:
				ok = false
				break
		if ok:
			return p
	return melhor


# ------------------------------------------------------------
#  LOOP
# ------------------------------------------------------------
func _process(delta: float) -> void:
	for p in _popups:
		p.t -= delta
		p.y -= delta * 30.0
	_popups = _popups.filter(func(p): return p.t > 0.0)

	queue_redraw()

	if estado != Estado.JOGANDO:
		return

	# >>> trocar por get_playback_position() se usar música
	song_time += delta

	if song_time >= 0.0:
		_gerar()

	for b in bolinhas:
		if b.resolvido:
			continue
		if b.hold and b.segurando:
			# segurou até o fim?
			if song_time >= b.end_time:
				b.resolvido = true
				b.acertou = true
				_hold_ok(b)
		else:
			# nunca apertou no tempo -> erro
			if song_time > b.hit_time + JANELA_BOM:
				b.resolvido = true
				_errar(b, "ERROU")

	bolinhas = bolinhas.filter(func(b): return not b.resolvido or b.segurando)

	if score >= META_PONTOS:
		estado = Estado.COMPLETO


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

	for i in KEYS.size():
		if event.keycode == KEYS[i].code:
			if event.pressed:
				KEYS[i].held = true
				_press(i)
			else:
				KEYS[i].held = false
				_release(i)
			return


func _press(ki: int) -> void:
	if song_time < 0.0:
		return
	# acha a bolinha desta tecla mais próxima no tempo
	var melhor = null
	var md: float = 999.0
	for b in bolinhas:
		if b.key == ki and not b.resolvido and not b.segurando:
			var dt: float = absf(b.hit_time - song_time)
			if dt < md:
				md = dt
				melhor = b
	if melhor != null and md <= JANELA_BOM:
		_julgar(melhor, md)


func _release(ki: int) -> void:
	# se havia um hold desta tecla sendo segurado, julga a soltura
	for b in bolinhas:
		if b.hold and b.segurando and b.key == ki and not b.resolvido:
			if song_time >= b.end_time - JANELA_BOM:
				b.resolvido = true
				b.acertou = true
				_hold_ok(b)
			else:
				b.resolvido = true
				b.segurando = false
				_errar(b, "SOLTOU CEDO")
			return


func _julgar(b, dt: float) -> void:
	var pos := Vector2(b.x, b.y)
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	if dt <= JANELA_PERFEITO:
		n_perfeito += 1
		score += 100 * mult
		_popup(pos, "PERFEITO!", Color(0.4, 1.0, 0.7))
	else:
		n_bom += 1
		score += 50 * mult
		_popup(pos, "bom", Color(1.0, 0.85, 0.4))
	if b.hold:
		b.segurando = true   # começou a segurar; completa ao soltar no fim
	else:
		b.resolvido = true
		b.acertou = true


func _hold_ok(b) -> void:
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	score += 150 * mult
	_popup(Vector2(b.x, b.y), "SEGUROU!", Color(0.45, 0.8, 1.0))


func _errar(b, txt: String) -> void:
	combo = 0
	n_erro += 1
	_popup(Vector2(b.x, b.y), txt, Color(1.0, 0.4, 0.4))


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 50.0, "txt": txt, "cor": cor, "t": 0.8})


func _reiniciar() -> void:
	song_time = -LEAD
	estado = Estado.JOGANDO
	bolinhas.clear()
	prox_beat = 4.0
	score = 0
	combo = 0
	combo_max = 0
	n_perfeito = 0
	n_bom = 0
	n_erro = 0
	_popups.clear()
	for k in KEYS:
		k.held = false


# ------------------------------------------------------------
#  DESENHO
# ------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("0a0a12"))
	# área delimitada
	draw_rect(AREA, Color(1, 1, 1, 0.02))
	draw_rect(AREA, Color(0.4, 0.4, 0.6, 0.25), false, 2.0)

	for b in bolinhas:
		_desenhar_bolinha(b)

	# HUD
	_texto("REGULAÇÃO EMOCIONAL  (J K L)", Vector2(40, 50), 24, Color("c850ff"))
	_texto("SCORE: %d" % score, Vector2(W - 250, 45), 22, Color.WHITE)
	_texto("COMBO: %d" % combo, Vector2(W - 250, 75), 18, Color("ffd24a"))
	# progresso até a meta
	var pos_barra := Vector2(W / 2 - 250, 110)
	_texto("META", Vector2(pos_barra.x, pos_barra.y - 8), 14, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pos_barra.x, pos_barra.y, 500, 16), Color(0.12, 0.12, 0.2))
	draw_rect(Rect2(pos_barra.x, pos_barra.y, 500 * clampf(float(score) / META_PONTOS, 0.0, 1.0), 16), Color("46d6a0"))
	draw_rect(Rect2(pos_barra.x, pos_barra.y, 500, 16), Color(1, 1, 1, 0.2), false, 2.0)

	for p in _popups:
		var a: float = clampf(p.t / 0.8, 0.0, 1.0)
		var c: Color = p.cor
		c.a = a
		_texto_centro_em(p.txt, Vector2(p.x, p.y), 22, c)

	if song_time < 0.0 and estado == Estado.JOGANDO:
		_texto_centro("PREPARE-SE", H / 2 - 20, 38, Color(0.9, 0.9, 1.0))
		_texto_centro(str(max(int(ceil(-song_time)), 1)), H / 2 + 40, 56, Color("c850ff"))

	if estado == Estado.COMPLETO:
		_overlay()


func _desenhar_bolinha(b) -> void:
	var pos := Vector2(b.x, b.y)
	var cor: Color = KEYS[b.key].cor
	var label: String = KEYS[b.key].label

	if b.hold and b.segurando:
		# segurando: anel azul que esvazia mostrando quanto falta
		var resta: float = clampf((b.end_time - song_time) / maxf(b.end_time - b.hit_time, 0.001), 0.0, 1.0)
		draw_arc(pos, R_HIT + 8, -PI / 2, -PI / 2 + TAU * resta, 48, Color(0.45, 0.8, 1.0), 6.0)
		draw_circle(pos, R_HIT, Color(0.45, 0.8, 1.0, 0.85))
		_letra(label, pos)
		return

	# anel de aproximação (encolhe até R_HIT no hit_time)
	var prog: float = clampf((song_time - (b.hit_time - APPROACH)) / APPROACH, 0.0, 1.0)
	var ring_r: float = lerpf(R_MAX, R_HIT, prog)
	draw_arc(pos, ring_r, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)

	# círculo-alvo
	draw_circle(pos, R_HIT, Color(cor.r, cor.g, cor.b, 0.9))
	draw_circle(pos, R_HIT - 5, Color(0.06, 0.06, 0.12, 0.9))
	_letra(label, pos)

	# marca de "segurar"
	if b.hold:
		draw_arc(pos, R_HIT + 4, 0, TAU, 40, Color(0.45, 0.8, 1.0, 0.7), 2.0)
		if _font:
			draw_string(_font, Vector2(pos.x - 24, pos.y - R_HIT - 12), "SEGURAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.9, 1.0))


func _letra(label: String, pos: Vector2) -> void:
	if _font:
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(_font, Vector2(pos.x - w / 2, pos.y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)


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
