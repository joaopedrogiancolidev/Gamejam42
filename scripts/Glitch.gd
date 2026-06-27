class_name Glitch
extends Node2D

# ============================================================
#  UM GLITCH  (v2 - agora com "psicologia")
#
#  A grande mudanca: cada tipo pede um GESTO diferente, e cada
#  glitch tem uma VOZ INTERIOR (pensamento intrusivo) que, ao
#  ser tratado, e RESSIGNIFICADA numa frase mais gentil.
#
#  Exemplo desta fatia:
#   - RAIVA  -> nao se trata com toque. Voce SEGURA a tecla
#               pra "respirar junto" e baixar a escalacao.
#   - Resto  -> toque (como antes), mas agora com voz/ressignificacao.
# ============================================================

enum Tipo { MEDO, CULPA, TRAUMA, VAZIO, RAIVA, DISTORCAO }

const CORES := {
	Tipo.MEDO:      Color("c850ff"),
	Tipo.CULPA:     Color("ff5577"),
	Tipo.TRAUMA:    Color("46d6a0"),
	Tipo.VAZIO:     Color("9aa6b2"),
	Tipo.RAIVA:     Color("ff6a3d"),
	Tipo.DISTORCAO: Color("e3e34b"),
}

const NOMES := {
	Tipo.MEDO: "MEDO",
	Tipo.CULPA: "CULPA",
	Tipo.TRAUMA: "TRAUMA",
	Tipo.VAZIO: "VAZIO",
	Tipo.RAIVA: "RAIVA",
	Tipo.DISTORCAO: "DISTORÇÃO",
}

# Pensamentos intrusivos (a "voz interior")
const FRASES := {
	Tipo.MEDO:      ["E se der tudo errado?", "Não vou dar conta.", "Algo ruim vai acontecer."],
	Tipo.CULPA:     ["A culpa é minha.", "Eu estrago tudo.", "Eu não mereço isso."],
	Tipo.TRAUMA:    ["Está acontecendo de novo.", "Eu nunca vou superar."],
	Tipo.VAZIO:     ["Nada faz sentido.", "Tanto faz.", "Pra que tentar?"],
	Tipo.RAIVA:     ["Ninguém me escuta!", "Eu não aguento mais!", "Por que sempre comigo?"],
	Tipo.DISTORCAO: ["Todo mundo me odeia.", "Eu sempre falho.", "Nunca dá certo."],
}

# A ressignificacao (o "voce integra")
const REFRAMES := {
	Tipo.MEDO:      "Eu estou seguro agora.",
	Tipo.CULPA:     "Eu fiz o que pude.",
	Tipo.TRAUMA:    "Aquilo passou. Eu sobrevivi.",
	Tipo.VAZIO:     "Pequenos passos contam.",
	Tipo.RAIVA:     "Eu posso sentir e respirar.",
	Tipo.DISTORCAO: "É um pensamento, não um fato.",
}

signal tratado(glitch)
signal corrompido(glitch)

var tipo: int = Tipo.MEDO
var lane_index: int = 0
var raio: float = 36.0

var escalacao: float = 0.0
var velocidade_escalacao: float = 0.18
var presses_necessarios: int = 1
var presses_feitos: int = 0
var morto: bool = false

# voz interior
var frase: String = ""
var reframe: String = ""

# gesto de SEGURAR (raiva)
var requer_hold: bool = false
var segurando: bool = false        # o Main atualiza isso todo frame
var hold_progresso: float = 0.0    # 0..1
var tempo_hold: float = 1.1        # segundos segurando pra tratar

var _pulse: float = 0.0
var _jitter: Vector2 = Vector2.ZERO
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func configurar(p_tipo: int, p_lane: int, p_vel: float) -> void:
	tipo = p_tipo
	lane_index = p_lane
	velocidade_escalacao = p_vel
	presses_necessarios = 2 if tipo == Tipo.TRAUMA else 1
	requer_hold = (tipo == Tipo.RAIVA)

	if tipo == Tipo.RAIVA:
		velocidade_escalacao *= 1.5
	elif tipo == Tipo.VAZIO:
		velocidade_escalacao *= 0.55

	var pool: Array = FRASES[tipo]
	frase = pool[randi() % pool.size()]
	reframe = REFRAMES[tipo]


func _process(delta: float) -> void:
	if morto:
		return
	_pulse += delta * 6.0
	if tipo == Tipo.DISTORCAO:
		_jitter = Vector2(randf_range(-3, 3), randf_range(-3, 3))

	if requer_hold:
		# RAIVA: respirar junto. Segurando -> acalma. Soltou -> volta a subir.
		if segurando:
			hold_progresso += delta / tempo_hold
			escalacao = maxf(0.0, escalacao - delta * 0.45)
			if hold_progresso >= 1.0:
				morto = true
				tratado.emit(self)
				_morrer_visual()
				return
		else:
			hold_progresso = maxf(0.0, hold_progresso - delta * 0.6)
			escalacao += velocidade_escalacao * delta
	else:
		escalacao += velocidade_escalacao * delta

	queue_redraw()
	if escalacao >= 1.0:
		morto = true
		corrompido.emit(self)
		_morrer_visual()


# Toque na tecla da lane. Raiva ignora toque (precisa segurar).
func tratar() -> bool:
	if morto or requer_hold:
		return false
	presses_feitos += 1
	if presses_feitos >= presses_necessarios:
		morto = true
		tratado.emit(self)
		_morrer_visual()
		return true
	escalacao = maxf(0.0, escalacao - 0.18)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.06)
	t.tween_property(self, "scale", Vector2(1, 1), 0.10)
	return false


func _morrer_visual() -> void:
	set_process(false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(2.0, 2.0), 0.20)
	t.tween_property(self, "modulate:a", 0.0, 0.20)
	t.set_parallel(false)
	t.tween_callback(queue_free)


func _draw() -> void:
	if tipo == Tipo.DISTORCAO:
		draw_set_transform(_jitter, 0.0, Vector2.ONE)

	var cor: Color = CORES[tipo]
	var pulse_r: float = raio + sin(_pulse) * 3.0

	draw_circle(Vector2.ZERO, pulse_r + 10.0, Color(cor.r, cor.g, cor.b, 0.12))
	draw_circle(Vector2.ZERO, pulse_r, Color(cor.r, cor.g, cor.b, 0.85))
	draw_circle(Vector2.ZERO, raio * 0.5, Color(0.04, 0.04, 0.09, 0.95))

	# anel de PERIGO
	var ang_fim: float = -PI / 2.0 + TAU * escalacao
	var cor_perigo: Color = Color(0.3, 1.0, 0.4).lerp(Color(1.0, 0.25, 0.25), escalacao)
	draw_arc(Vector2.ZERO, raio + 9.0, -PI / 2.0, ang_fim, 48, cor_perigo, 4.0, true)

	# anel de RESPIRACAO (raiva) - azul calmo, por dentro
	if requer_hold:
		draw_arc(Vector2.ZERO, raio - 5.0, -PI / 2.0, -PI / 2.0 + TAU * hold_progresso, 40, Color(0.45, 0.8, 1.0, 0.95), 5.0, true)

	if _font == null:
		return

	# label embaixo
	var label: String = NOMES[tipo]
	if requer_hold:
		label = "RAIVA - SEGURE"
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, Vector2(-w / 2.0, raio + 30.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))

	# TRAUMA: presses que faltam
	if presses_necessarios > 1:
		var s: String = "x%d" % (presses_necessarios - presses_feitos)
		var ws: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(_font, Vector2(-ws / 2.0, 6.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
