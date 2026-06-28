extends Node2D

# ============================================================
#  HUB SCREEN  -  casca do "computador"
#
#  O jogo de verdade (GameWorld.tscn, com o Hub.gd) roda dentro
#  de um SubViewport fixo em 1280x720 e aparece como textura
#  DENTRO da telinha do MonitorUI (nó Software/Conteudo).
#
#  Como o SubViewport não está dentro de um SubViewportContainer,
#  ele não recebe input sozinho: os minigames usam _unhandled_input
#  e o Hub usa _input, então repassamos os eventos na mão com
#  push_input(). (Teclas lidas via Input.is_key_pressed continuam
#  funcionando globalmente, sem precisar de repasse.)
# ============================================================

@onready var _viewport: SubViewport = $GameViewport


func _ready() -> void:
	# garante que o SubViewport sempre renderize o jogo
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _input(event: InputEvent) -> void:
	# repassa teclado/etc. pro jogo lá dentro do monitor
	# (ESC pra sair é tratado globalmente pelo autoload SairGlobal)
	_viewport.push_input(event)
