extends Node2D

# ============================================================
#  MENU INICIAL — CyberTerapia™
#
#  Tela de abertura. START -> Hub (a partida co-op).
#  Toda a arte é carregada por PATH no _ready (load), pra não
#  depender de uid de import:
#   - background_2.png (duas cabeças wireframe) = fundo
#   - botton_w/a/s/d.png (azul/razão) e botton_i/j/k/l.png
#     (vermelho/emoção) = botões do "como jogar" (tecla 1)
#
#  Pra "ligar" o fluxo oficial: aponte o main_scene do projeto
#  (project.godot) pra esta cena Menu.tscn. NÃO mexi nisso de
#  propósito, pra não trocar o F5 de quem está nos minigames.
#
#  TESTAR: abra Menu.tscn e aperte F6.
#    ENTER/ESPAÇO = começar   |   1 = como jogar
# ============================================================

@onready var _start: Label = $Conteudo/Start
@onready var _painel: Control = $ComoJogarPainel

var _t: float = 0.0


func _ready() -> void:
	_set_tex("Heads", "res://assets/background_2.png")
	_set_tex("Cerebro", "res://assets/background.png")
	_set_tex("Conteudo/LogoImg", "res://assets/logo.png")
	# botões neon  (W A S D = razão/azul · I J K L = emoção/vermelho)
	_set_tex("ComoJogarPainel/BtnW", "res://assets/botton_w.png")
	_set_tex("ComoJogarPainel/BtnA", "res://assets/botton_a.png")
	_set_tex("ComoJogarPainel/BtnS", "res://assets/botton_s.png")
	_set_tex("ComoJogarPainel/BtnD", "res://assets/botton_d.png")
	_set_tex("ComoJogarPainel/BtnI", "res://assets/botton_i.png")
	_set_tex("ComoJogarPainel/BtnJ", "res://assets/botton_j.png")
	_set_tex("ComoJogarPainel/BtnK", "res://assets/botton_k.png")
	_set_tex("ComoJogarPainel/BtnL", "res://assets/botton_l.png")
	_set_tex("ComoJogarPainel/BtnVoltar", "res://assets/botton_nb1.png")
	# botão da tecla 1 (abre o "como jogar"). Se o Godot ainda não
	# importou a arte (sem .import), cai pro texto "[1]" como fallback.
	if not _set_tex("Conteudo/Btn1", "res://assets/botton_nb1.png"):
		var b = get_node_or_null("Conteudo/Btn1")
		if b:
			b.visible = false
		var hint = get_node_or_null("Conteudo/ComoJogarHint")
		if hint:
			hint.text = "[1]  Como jogar?"
	_painel.visible = false


func _set_tex(node_path: String, asset_path: String) -> bool:
	var n = get_node_or_null(node_path)
	if n and ResourceLoader.exists(asset_path):
		var t = load(asset_path)
		if t:
			n.texture = t
			return true
	return false


func _process(delta: float) -> void:
	# pulso suave no "ENTER pra começar"
	_t += delta
	var col: Color = _start.modulate
	col.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.0))
	_start.modulate = col


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	# painel "como jogar" aberto -> qualquer tecla fecha
	if _painel.visible:
		_painel.visible = false
		return

	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_comecar()
		KEY_1, KEY_KP_1:
			_painel.visible = true


func _comecar() -> void:
	get_tree().change_scene_to_file("res://scenes/Intro_Cena1.tscn")
