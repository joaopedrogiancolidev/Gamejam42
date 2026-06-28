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
# Esconde a área de arte (imagem + placeholder). Útil quando a telinha
# vai abrigar OUTRA coisa no lugar — ex.: o Tutorial2 roda o minigame
# Dance dentro do monitor. Desligado por padrão: não afeta as demais telas.
@export var esconder_arte: bool = false
# Mostra a moldura de monitor própria desta tela. Desligue quando a tela
# já é exibida DENTRO de outro monitor (ex.: os finais aparecem na TV do
# Hub), pra não duplicar a moldura.
@export var mostrar_monitor: bool = true
# Multiplica o tamanho do conteúdo (nó Software). 1.0 = padrão; ex.: 1.5 nos
# finais, que aparecem dentro da TV do Hub e precisam de mais destaque.
@export var escala_conteudo: float = 1.0
@export_file("*.tscn") var proxima_cena: String = ""

var _header: Label
var _texto: Label
var _imagem: TextureRect
var _placeholder: ColorRect
var _placeholder_desc: Label
var _continuar: Label

var _t: float = 0.0


# procura "Software/<caminho>" e, se não existir, "<caminho>" na raiz
func _achar(caminho: String) -> Node:
	var n: Node = get_node_or_null("Software/" + caminho)
	if n == null:
		n = get_node_or_null(caminho)
	return n


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

	# aumenta/diminui o conteúdo (Software) a partir do centro (pivot já
	# está no meio na cena base), multiplicando a escala existente
	if escala_conteudo != 1.0:
		var _sw := get_node_or_null("Software")
		if _sw:
			_sw.scale *= escala_conteudo

	if _header:
		_header.text = header
	if _texto:
		_texto.text = texto
	# moldura do "pc" (arte do monitor). Se mostrar_monitor estiver off, some
	# com a moldura toda (a tela já está dentro de outro monitor). Senão, usa
	# a arte monitor.png e esconde a borda desenhada (que é só fallback).
	var _frame := get_node_or_null("MonitorFrame")
	var _mon := get_node_or_null("Monitor")
	if not mostrar_monitor:
		if _frame:
			_frame.visible = false
		if _mon:
			_mon.visible = false
	elif ResourceLoader.exists("res://assets/monitor.png"):
		if _frame:
			_frame.texture = load("res://assets/monitor.png")
			_frame.visible = true
		if _mon:
			_mon.visible = false
	elif _frame:
		_frame.visible = false
	if esconder_arte:
		# a telinha vira só moldura + texto; outra coisa ocupa o espaço
		if _imagem:
			_imagem.visible = false
		if _placeholder:
			_placeholder.visible = false
	elif imagem and _imagem:
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
