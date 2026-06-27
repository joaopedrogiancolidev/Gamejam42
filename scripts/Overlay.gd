extends Node2D

# ============================================================
#  OVERLAY  -  desenha por cima dos dois minigames.
#  Fica numa CanvasLayer pra garantir que aparece na frente.
#  Lê o estado do Hub (a raiz da cena) via 'owner'.
# ============================================================

const W: float = 1280.0
const H: float = 720.0

# textos dos 4 finais
const FINAIS := {
	"feliz": {
		"titulo": "INTEGRAÇÃO",
		"cor": "46d6a0",
		"texto": "Razão e emoção em equilíbrio. João sai da sessão inteiro:\nsente o que precisa sentir e entende o que precisa entender."
	},
	"racional": {
		"titulo": "RACIONALIZAÇÃO",
		"cor": "8ad0ff",
		"texto": "João entende tudo sobre si mesmo, mas não se permite sentir.\nA lógica blindou a dor — e também a vida."
	},
	"emocional": {
		"titulo": "TRANSBORDAMENTO",
		"cor": "ff7bbf",
		"texto": "João sente com intensidade, mas se perde sem a razão pra ancorar.\nA emoção tomou conta e ele afundou nela."
	},
	"gameover": {
		"titulo": "COLAPSO MENTAL",
		"cor": "ff3b3b",
		"texto": "A mente não aguentou a pressão da sessão.\nFoi preciso interromper antes que piorasse."
	},
}

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# área de jogo = miolo central (margem de 20% em cada lado)
	var mx: float = W * 0.20
	var my: float = H * 0.20
	var area := Rect2(mx, my, W - mx * 2, H - my * 2)

	# moldura da área (a margem em volta fica livre pra coisas futuras)
	draw_rect(area, Color(0.4, 0.4, 0.6, 0.25), false, 2.0)

	# divisória central (corpo caloso) só na altura da área
	draw_line(Vector2(W / 2, area.position.y), Vector2(W / 2, area.position.y + area.size.y), Color(0.5, 0.4, 0.8, 0.5), 3.0)

	if owner.estado != "fim":
		return

	var f = FINAIS.get(owner.final_tipo, FINAIS["feliz"])
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.82))
	var cor := Color(f.cor)
	_centro(f.titulo, 230, 52, cor)

	# scores finais dos dois lados
	var r := int(float(owner.dance.score) / float(owner.dance.META) * 100.0)
	var e := int(float(owner.waves.score) / float(owner.waves.META) * 100.0)
	_centro("Racional: %d%%      Emocional: %d%%" % [r, e], 310, 24, Color.WHITE)

	# texto do final (pode ter 2 linhas)
	var linhas: PackedStringArray = String(f.texto).split("\n")
	var y := 370.0
	for ln in linhas:
		_centro(ln, y, 20, Color(0.85, 0.85, 0.95))
		y += 30.0

	_centro("ENTER pra uma nova sessão", 520, 22, Color(0.8, 0.8, 0.9))


func _centro(txt: String, y: float, tam: int, cor: Color) -> void:
	if _font:
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_font, Vector2(W / 2 - w / 2, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
