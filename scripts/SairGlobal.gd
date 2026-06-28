extends Node

# ============================================================
#  SAIR GLOBAL  -  autoload
#
#  ESC fecha o jogo em QUALQUER tela (Menu, Lore, Intro, Hub,
#  Finais, etc.). Como é autoload, fica vivo o tempo todo e
#  captura o input independente da cena atual.
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
