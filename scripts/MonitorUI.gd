extends Node2D

# MonitorUI — só a casca visual do monitor (moldura + software UI).
# Não tem lógica de lore, texto ou input — é pra ser instanciado
# onde quiser (Hub, overlays, etc.) e colocar conteúdo no nó Conteudo.

func _ready() -> void:
	if ResourceLoader.exists("res://assets/monitor.png"):
		$MonitorFrame.texture = load("res://assets/monitor.png")
		$MonitorFrame.visible = true
		$Monitor.visible = false
	else:
		$MonitorFrame.visible = false
