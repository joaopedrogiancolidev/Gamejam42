extends Node2D

# ============================================================
#  TEMPLATE LORE — molde reaproveitável das telinhas de história
#  (Lore1 / Tutorial1 / PlotTwist / Tutorial2 / Lore2 ...)
#
#  É só o MOLDE: define o visual (moldura de monitor neon) e o
#  comportamento (mostra o texto + ENTER -> próxima cena).
#  Cada tela de verdade HERDA este molde e preenche no Inspector:
#    - header          : a barrinha de status no topo da telinha
#    - texto           : o texto da tela
#    - imagem          : a arte (Texture2D). Se vazio, mostra o
#                        placeholder "graphic design is my passion".
#    - arte_placeholder: o que descreve a arte que vai ali
#    - proxima_cena    : a cena que abre no ENTER (.tscn)
#
#  Criar tela nova: botão direito em TemplateLore.tscn ->
#  "New Inherited Scene", preenche os campos, salva.
# ============================================================

@export var header: String = "●  CyberTerapia™"
@export_multiline var texto: String = "João respirou. Disse 'não' pro deploy de sexta 18h, fechou o notebook e foi viver. O unicórnio que espere, ele escolheu ser uma pessoa inteira em vez de um recurso."
@export var imagem: Texture2D
@export var arte_placeholder: String = "[ ARTE AQUI ]"
@export_file("*.tscn") var proxima_cena: String = ""

var _header: Label
var _texto: Label
var _imagem: TextureRect
var _placeholder: ColorRect
var _placeholder_desc: Label
var _continuar: Label

var _t: float = 0.0


func _ready() -> void:
	# suporta tanto a estrutura nova (nós dentro de Software)
	# quanto a estrutura antiga (nós direto na raiz)
	var sw := "Software/" if has_node("Software") else ""
	_header          = get_node_or_null(sw + "Header")
	_texto           = get_node_or_null(sw + "Conteudo/Texto")
	_imagem          = get_node_or_null(sw + "Imagem")
	_placeholder     = get_node_or_null(sw + "Placeholder")
	_placeholder_desc = get_node_or_null(sw + "Placeholder/Desc")
	_continuar       = get_node_or_null(sw + "Conteudo/Continuar")

	if _header:
		_header.text = header
	if _texto:
		_texto.text = texto
	# moldura do "pc" (arte do monitor). Se assets/monitor.png existir,
	# usa a imagem e esconde a borda desenhada (que é só fallback).
	if ResourceLoader.exists("res://assets/monitor.png"):
		$MonitorFrame.texture = load("res://assets/monitor.png")
		$MonitorFrame.visible = true
		$Monitor.visible = false
	else:
		$MonitorFrame.visible = false
	if imagem and _imagem:
		_imagem.texture = imagem
		_imagem.visible = true
		if _placeholder:
			_placeholder.visible = false
	elif _placeholder:
		if _imagem:
			_imagem.visible = false
		_placeholder.visible = true
		if _placeholder_desc:
			_placeholder_desc.text = arte_placeholder
	# fade-in suave do conjunto
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4)


func _process(delta: float) -> void:
	if not _continuar:
		return
	_t += delta
	var col: Color = _continuar.modulate
	col.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.0))
	_continuar.modulate = col


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_avancar()


func _avancar() -> void:
	if proxima_cena != "":
		get_tree().change_scene_to_file(proxima_cena)
