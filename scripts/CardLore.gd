extends Node2D

# ============================================================
#  CARD DE LORE — template reaproveitável (LORE 1 / plot-twist / LORE 2)
#
#  Mostra: imagem (opcional) + texto + "ENTER pra continuar".
#  Tudo configurável no Inspector, sem mexer no código:
#    - texto         : o que a tela escreve
#    - imagem        : arraste a arte (Texture2D) aqui
#    - proxima_cena  : a cena que abre ao apertar ENTER (.tscn)
#
#  COMO USAR pra criar uma tela nova:
#    1. No FileSystem, botão direito em CardLore.tscn ->
#       "New Inherited Scene" (ou duplique a cena).
#    2. Preencha 'texto', arraste a 'imagem' e escolha a
#       'proxima_cena' no Inspector.
#    3. Salve como Lore1.tscn, PlotTwist.tscn, etc.
#  Encadeie: Menu -> Lore1 -> (tutorial) -> PlotTwist -> ... -> Hub.
#
#  TESTAR: abra a cena e aperte F6.
# ============================================================

@export_multiline var texto: String = "Texto da lore aqui..."
@export var imagem: Texture2D
@export_file("*.tscn") var proxima_cena: String = ""

@onready var _texto: Label = $Conteudo/Texto
@onready var _imagem: TextureRect = $Imagem
@onready var _continuar: Label = $Conteudo/Continuar

var _t: float = 0.0


func _ready() -> void:
	_texto.text = texto
	if imagem:
		_imagem.texture = imagem
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
