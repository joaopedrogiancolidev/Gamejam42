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
@export_multiline var texto: String = "Texto da história aqui..."
@export var imagem: Texture2D
@export var arte_placeholder: String = "[ ARTE AQUI ]"
@export_file("*.tscn") var proxima_cena: String = ""

@onready var _header: Label = $Header
@onready var _texto: Label = $Conteudo/Texto
@onready var _imagem: TextureRect = $Imagem
@onready var _placeholder: ColorRect = $Placeholder
@onready var _placeholder_desc: Label = $Placeholder/Desc
@onready var _continuar: Label = $Conteudo/Continuar

var _t: float = 0.0


func _ready() -> void:
	_header.text = header
	_texto.text = texto
	# moldura do "pc" (arte do monitor). Se assets/monitor.png existir,
	# usa a imagem e esconde a borda desenhada (que é só fallback).
	if ResourceLoader.exists("res://assets/monitor.png"):
		$MonitorFrame.texture = load("res://assets/monitor.png")
		$MonitorFrame.visible = true
		$Monitor.visible = false
	else:
		$MonitorFrame.visible = false
	if imagem:
		_imagem.texture = imagem
		_imagem.visible = true
		_placeholder.visible = false
	else:
		_imagem.visible = false
		_placeholder.visible = true
		_placeholder_desc.text = arte_placeholder
	# fade-in suave do conjunto
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4)


func _process(delta: float) -> void:
	# pulso no "ENTER pra continuar"
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
