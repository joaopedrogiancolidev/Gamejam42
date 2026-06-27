extends Node2D

# ============================================================
#  MINIGAME EMOCIONAL  -  ritmo estilo Rift of the Necrodancer,
#  só que DEITADO: as emoções fluem da DIREITA pra ESQUERDA.
#  3 lanes -> teclas  J  K  L.
#  Trate cada emoção no tempo certo, quando ela cruzar a
#  LINHA DE REGULAÇÃO (a barra vertical da esquerda).
#
#  COMO TESTAR: abra esta cena e aperte F6 (rodar cena atual).
#  Roda SEM música - o tempo é um relógio manual (ver _process).
#
#  >>> PRA SINCRONIZAR COM UMA MÚSICA DE VERDADE (recomendado):
#      1) adicione um nó AudioStreamPlayer com a faixa, dê play()
#         no início, e troque a linha "song_time += delta" por:
#         var t = $AudioStreamPlayer.get_playback_position()
#         t += AudioServer.get_time_since_last_mix()
#         t -= AudioServer.get_output_latency()
#         song_time = t
#      2) ajuste BPM e o array de notas pra bater com a música.
#  Isso evita o "drift" (o jogo desencaixar da música com o tempo).
# ============================================================

enum Estado { TOCANDO, FALHA, COMPLETO }

# ---- música / tempo ----
const BPM: float = 120.0
var beat_dur: float = 60.0 / BPM
const LEAD: float = 1.8          # segundos de "prepare-se" antes da 1a nota
var song_time: float = -LEAD     # relógio da música (comeca negativo)

# ---- pista ----
const STRIKE_X: float = 250.0    # onde fica a linha de regulação
const VEL: float = 430.0         # px/segundo que a nota viaja pra esquerda
const JANELA_PERFEITO: float = 0.045
const JANELA_BOM: float = 0.10

const W: float = 1280.0
const H: float = 720.0

# 3 lanes (J em cima, L embaixo) - cor POR LANE pra leitura ser fácil
var LANES := [
	{"key": KEY_J, "label": "J", "y": 230.0, "cor": Color("ff7bbf"), "flash": 0.0, "held": false},
	{"key": KEY_K, "label": "K", "y": 370.0, "cor": Color("c850ff"), "flash": 0.0, "held": false},
	{"key": KEY_L, "label": "L", "y": 510.0, "cor": Color("ff6a3d"), "flash": 0.0, "held": false},
]

# ---- estado ----
var estado: int = Estado.TOCANDO
var notas: Array = []
var fim_chart: float = 0.0

var score: int = 0
var combo: int = 0
var combo_max: int = 0
var estab: float = 60.0           # estabilidade emocional (0 = falha)
var n_perfeito: int = 0
var n_bom: int = 0
var n_erro: int = 0

var _popups: Array = []
var _dano_flash: float = 0.0
var _font: Font


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font
	_gerar_chart()


# ------------------------------------------------------------
#  CHART (a "partitura"). Gerado proceduralmente pra rodar já.
#  Cada nota: beat em que deve ser tratada. hold = segurar.
# ------------------------------------------------------------
func _gerar_chart() -> void:
	notas.clear()
	var b: float = 6.0
	while b < 70.0:
		var lane: int = randi() % 3
		var r: float = randf()
		if r < 0.13:
			# nota de SEGURAR (respiração) - 2 beats
			notas.append(_nova_nota(b, lane, true, b + 2.0))
			b += 2.5
		elif r < 0.42 and b > 16.0:
			# duas notas seguidas (meio beat) em lanes diferentes -> mais denso
			notas.append(_nova_nota(b, lane, false, 0.0))
			var lane2: int = (lane + 1 + randi() % 2) % 3
			notas.append(_nova_nota(b + 0.5, lane2, false, 0.0))
			b += 1.0
		else:
			notas.append(_nova_nota(b, lane, false, 0.0))
			b += 1.0

	# fim do chart = ultima nota + folga
	var ult: float = 0.0
	for nota in notas:
		ult = maxf(ult, nota.beat_fim if nota.hold else nota.beat)
	fim_chart = ult * beat_dur + 2.5


func _nova_nota(beat: float, lane: int, hold: bool, beat_fim: float) -> Dictionary:
	return {
		"beat": beat, "beat_fim": beat_fim, "lane": lane, "hold": hold,
		"acertou": false, "errou": false, "segurando": false
	}


# ------------------------------------------------------------
#  LOOP
# ------------------------------------------------------------
func _process(delta: float) -> void:
	# fx que rodam sempre
	for lane in LANES:
		if lane.flash > 0.0:
			lane.flash = maxf(0.0, lane.flash - delta * 5.0)
	for p in _popups:
		p.t -= delta
		p.y -= delta * 30.0
	_popups = _popups.filter(func(p): return p.t > 0.0)
	if _dano_flash > 0.0:
		_dano_flash = maxf(0.0, _dano_flash - delta * 2.0)

	queue_redraw()

	if estado != Estado.TOCANDO:
		return

	# >>> SE FOR USAR ÁUDIO, troque a linha abaixo (ver topo do arquivo)
	song_time += delta

	# resolve notas perdidas e holds em andamento
	for nota in notas:
		if nota.acertou or nota.errou:
			continue
		var nt: float = nota.beat * beat_dur
		if nota.hold and nota.segurando:
			var endt: float = nota.beat_fim * beat_dur
			if song_time >= endt:
				nota.segurando = false
				nota.acertou = true
				_hold_completo(nota)
			elif not LANES[nota.lane].held:
				nota.segurando = false
				nota.errou = true
				_errou(nota, "SOLTOU CEDO")
		else:
			if song_time > nt + JANELA_BOM:
				nota.errou = true
				_errou(nota, "ERROU")

	# fim / falha
	if estab <= 0.0:
		estado = Estado.FALHA
	elif song_time > fim_chart:
		estado = Estado.COMPLETO


# ------------------------------------------------------------
#  INPUT
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	if estado != Estado.TOCANDO:
		if event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_reiniciar()
		return

	for i in LANES.size():
		if event.keycode == LANES[i].key:
			if event.pressed:
				_press(i)
			else:
				LANES[i].held = false
			return


func _press(li: int) -> void:
	LANES[li].held = true
	LANES[li].flash = 1.0
	if song_time < 0.0:
		return
	# acha a nota mais próxima nesta lane que ainda não foi resolvida
	var melhor = null
	var md: float = 999.0
	for nota in notas:
		if nota.lane == li and not nota.acertou and not nota.errou and not nota.segurando:
			var dt: float = absf(nota.beat * beat_dur - song_time)
			if dt < md:
				md = dt
				melhor = nota
	if melhor != null and md <= JANELA_BOM:
		_julgar(melhor, md)


func _julgar(nota, dt: float) -> void:
	var pos := Vector2(STRIKE_X, LANES[nota.lane].y)
	combo += 1
	combo_max = max(combo_max, combo)
	var mult: int = 1 + combo / 10
	if dt <= JANELA_PERFEITO:
		n_perfeito += 1
		score += 100 * mult
		estab = minf(100.0, estab + 2.5)
		_popup(pos, "PERFEITO!", Color(0.4, 1.0, 0.7))
	else:
		n_bom += 1
		score += 50 * mult
		estab = minf(100.0, estab + 1.0)
		_popup(pos, "bom", Color(1.0, 0.85, 0.4))
	if nota.hold:
		nota.segurando = true   # começou a segurar; completa quando segurar até o fim
	else:
		nota.acertou = true


func _hold_completo(nota) -> void:
	combo += 1
	combo_max = max(combo_max, combo)
	score += 150
	estab = minf(100.0, estab + 5.0)
	_popup(Vector2(STRIKE_X, LANES[nota.lane].y), "RESPIROU", Color(0.45, 0.8, 1.0))


func _errou(nota, txt: String) -> void:
	combo = 0
	n_erro += 1
	estab = maxf(0.0, estab - 7.0)
	_dano_flash = 0.5
	_popup(Vector2(STRIKE_X, LANES[nota.lane].y), txt, Color(1.0, 0.4, 0.4))


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	_popups.append({"x": pos.x, "y": pos.y - 40.0, "txt": txt, "cor": cor, "t": 0.8})


func _reiniciar() -> void:
	song_time = -LEAD
	estado = Estado.TOCANDO
	score = 0
	combo = 0
	combo_max = 0
	estab = 60.0
	n_perfeito = 0
	n_bom = 0
	n_erro = 0
	_popups.clear()
	for lane in LANES:
		lane.held = false
		lane.flash = 0.0
	_gerar_chart()


# ------------------------------------------------------------
#  DESENHO
# ------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("0a0a12"))

	# faixas das lanes
	for lane in LANES:
		draw_rect(Rect2(0, lane.y - 52, W, 104), Color(lane.cor.r, lane.cor.g, lane.cor.b, 0.05))
		draw_line(Vector2(0, lane.y - 52), Vector2(W, lane.y - 52), Color(1, 1, 1, 0.04), 1.0)

	# grade de beats (ajuda a ler o ritmo)
	var b0: int = int(floor(song_time / beat_dur))
	for k in range(b0, b0 + 7):
		var x: float = STRIKE_X + (k * beat_dur - song_time) * VEL
		if x > STRIKE_X and x < W:
			draw_line(Vector2(x, 178), Vector2(x, 562), Color(1, 1, 1, 0.05), 1.0)

	# linha de regulação + alvos (com pulso no beat)
	var frac: float = song_time / beat_dur
	frac = frac - floor(frac)
	var pulso: float = 1.0 - frac
	draw_line(Vector2(STRIKE_X, 170), Vector2(STRIKE_X, 570), Color(0.8, 0.8, 1.0, 0.5), 3.0)
	for lane in LANES:
		var rr: float = 30.0 + pulso * 8.0
		draw_arc(Vector2(STRIKE_X, lane.y), rr, 0, TAU, 40, Color(lane.cor.r, lane.cor.g, lane.cor.b, 0.4 + lane.flash * 0.6), 3.0)
		# tecla à esquerda
		if _font:
			var c: Color = Color.WHITE if lane.flash > 0.1 else lane.cor
			draw_string(_font, Vector2(STRIKE_X - 150, lane.y + 12), lane.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, c)

	# notas
	for nota in notas:
		_desenhar_nota(nota)

	# HUD
	_texto("REGULAÇÃO EMOCIONAL  (lado direito - J K L)", Vector2(40, 50), 24, Color("c850ff"))
	_texto("SCORE: %d" % score, Vector2(W - 260, 45), 24, Color.WHITE)
	_texto("COMBO: %d" % combo, Vector2(W - 260, 78), 18, Color("ffd24a"))
	_desenhar_barra_estab()

	# popups
	for p in _popups:
		var a: float = clampf(p.t / 0.8, 0.0, 1.0)
		var c2: Color = p.cor
		c2.a = a
		_texto_centro_em(p.txt, Vector2(p.x, p.y), 22, c2)

	# prepare-se
	if song_time < 0.0 and estado == Estado.TOCANDO:
		var n: int = int(ceil(-song_time))
		_texto_centro("PREPARE-SE", H / 2 - 40, 40, Color(0.9, 0.9, 1.0))
		_texto_centro(str(max(n, 1)), H / 2 + 30, 60, Color("c850ff"))

	# flash de dano
	if _dano_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.2, 0.2, _dano_flash * 0.25))

	if estado == Estado.FALHA:
		_overlay_fim("SOBRECARGA EMOCIONAL", Color("ff3b3b"))
	elif estado == Estado.COMPLETO:
		_overlay_fim("SESSÃO REGULADA", Color("46d6a0"))


func _desenhar_nota(nota) -> void:
	if nota.acertou or nota.errou:
		return
	var ly: float = LANES[nota.lane].y
	var cor: Color = LANES[nota.lane].cor
	var nt: float = nota.beat * beat_dur
	var x: float = STRIKE_X + (nt - song_time) * VEL

	if nota.hold:
		var endt: float = nota.beat_fim * beat_dur
		var xe: float = STRIKE_X + (endt - song_time) * VEL
		if nota.segurando:
			# cabeça presa na linha, cauda encolhendo (respirando)
			draw_line(Vector2(STRIKE_X, ly), Vector2(maxf(STRIKE_X, xe), ly), Color(0.45, 0.8, 1.0, 0.55), 30.0)
			draw_circle(Vector2(STRIKE_X, ly), 26.0, Color(0.45, 0.8, 1.0))
			if _font:
				draw_string(_font, Vector2(STRIKE_X - 22, ly - 40), "SEGURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 1.0))
		elif x < W + 60 and xe > -60:
			draw_line(Vector2(x, ly), Vector2(xe, ly), Color(cor.r, cor.g, cor.b, 0.4), 30.0)
			draw_circle(Vector2(x, ly), 28.0, cor)
			draw_circle(Vector2(x, ly), 14.0, Color(0.05, 0.05, 0.1))
	else:
		if x > -60 and x < W + 60:
			draw_circle(Vector2(x, ly), 27.0, cor)
			draw_circle(Vector2(x, ly), 13.0, Color(0.05, 0.05, 0.1))


func _desenhar_barra_estab() -> void:
	var pos := Vector2(W / 2 - 200, 620)
	_texto("ESTABILIDADE EMOCIONAL", Vector2(pos.x, pos.y - 8), 16, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(pos.x, pos.y, 400, 20), Color(0.12, 0.12, 0.2))
	var frac: float = clampf(estab / 100.0, 0.0, 1.0)
	draw_rect(Rect2(pos.x, pos.y, 400 * frac, 20), Color(1.0, 0.3, 0.3).lerp(Color(0.3, 1.0, 0.5), frac))
	draw_rect(Rect2(pos.x, pos.y, 400, 20), Color(1, 1, 1, 0.2), false, 2.0)


func _overlay_fim(titulo: String, cor: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.76))
	_texto_centro(titulo, 190, 46, cor)
	var total: int = n_perfeito + n_bom + n_erro
	var acc: float = 0.0
	if total > 0:
		acc = 100.0 * float(n_perfeito + n_bom) / float(total)
	_texto_centro("Perfeitos: %d    Bons: %d    Erros: %d" % [n_perfeito, n_bom, n_erro], 270, 24, Color.WHITE)
	_texto_centro("Precisão: %.1f%%    Combo máx: %d" % [acc, combo_max], 310, 24, Color(0.85, 0.9, 1.0))
	_texto_centro("Score: %d" % score, 360, 28, Color("ffd24a"))
	_texto_centro("ENTER pra jogar de novo", 440, 22, Color(0.8, 0.8, 0.9))


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
