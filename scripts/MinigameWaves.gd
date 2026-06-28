extends Node2D

# ============================================================
#  MINIGAME WAVES  -  VERSÃO PRECISION SPRINT 20S
# ============================================================

# refs de áudio
@onready var chord_player: ChordPlayer = $ChordPlayer
var _som_ruido: AudioStreamPlayer2D

@export_dir var great_frames_dir: String = "res://assets/great_red"
@export var great_frames_prefix: String = "great_red"
@export var great_frames_max: int = 16

@export_dir var perfect_frames_dir: String = "res://assets/perfect_red"
@export var perfect_frames_prefix: String = "perfect_red"
@export var perfect_frames_max: int = 16

# desenho das ondas
@export var largura_onda: float = 640.0
const NIVEL_PX: float = 56.0
const AGIT_PX: float = 52.0

# === DRIVERS DE DIFICULDADE EXTREMA ===
@export var PULL_NIVEL: float = 2.4    
@export var PULL_AGIT: float = 2.2
@export var DRAIN: float = 15.68       # gasto de foco -20% (era 35.0 -> 28.0 -> 19.6 -> 15.68)
@export var RECUP_FOCO: float = 18.0   
@export var RED_THRESH: float = 0.50  
@export var RATE_SCORE: float = 2000.0 / 60.0  # enche a barra por TEMPO: 2000 em 60s (objetivo = aguentar 60s)

const DIFICULDADE_MULT: float = 0.5616 # PUNIÇÃO (dreno/colapso/limiar). -10% de dificuldade (era 0.624)
const ONDA_FORCA: float = 0.6696 # índice/força das ondas -10% (era 0.744)
const FREQ_MULT: float = 1.2    # frequência das perturbações (+20% mais frequentes)

# --- contrato com o Hub ---
@export var META: int = 2000
# tempo de partida do emocional. Quando rodando dentro do Hub, sincroniza
# com o DURACAO da partida no _ready. 30s por enquanto pra testes.
@export var TEMPO_LIMITE: float = 30.0
var score: int = 0
var ativo: bool = true
var falhou: bool = false
# travado por glitch do tipo "segurar": BLOQUEIA o input deste lado (o
# jogador não consegue segurar as teclas pra estabilizar) até o OUTRO
# jogador consertar. A simulação NÃO para: as ondas seguem perturbando e
# o colapso pode subir enquanto está travado. Separado de `ativo`.
var travado: bool = false:
	set(v):
		travado = v
		if v:
			for c in CANAIS:
				c.held = false
				c.held_stable_time = 0.0

var CANAIS := [
	{"nome": "CanalJ", "code": KEY_J, "label": "J", "emo": "ANSIEDADE", "cor": Color("ff7bbf"), "nivel": 0.0, "agit": 0.0, "fase": 0.0, "held": false, "held_stable_time": 0.0, "was_unstable": false, "neon_t": 0.0},
	{"nome": "CanalK", "code": KEY_K, "label": "K", "emo": "TRISTEZA",  "cor": Color("c850ff"), "nivel": 0.0, "agit": 0.0, "fase": 1.0, "held": false, "held_stable_time": 0.0, "was_unstable": false, "neon_t": 0.0},
	{"nome": "CanalL", "code": KEY_L, "label": "L", "emo": "RAIVA",     "cor": Color("ff6a3d"), "nivel": 0.0, "agit": 0.0, "fase": 2.0, "held": false, "held_stable_time": 0.0, "was_unstable": false, "neon_t": 0.0},
]

const FALAS := [
	"...não consigo desligar a cabeça.",
	"...sinto que decepciono todos.",
	"...tem dias que nada importa.",
	"...por que sempre comigo?",
	"...eu devia estar melhor.",
	"...não sei se isso adianta.",
]

var tempo: float = 0.0
var foco: float = 100.0
var colapso: float = 0.0
var dist_timer: float = 1.5            
var _score_f: float = 0.0
var _fala_t: float = 0.0

# Arrays de texturas para animação de notas
var _textures_great: Array[Texture2D] = []
var _textures_perfect: Array[Texture2D] = []

# Controle de animação por canal (J/K/L)
var _rating_popups := {}
var _rating_states := {}

# refs de nós
var _score_label: Label
var _fala_label: Label
var _fill_score: ColorRect
var _fill_foco: ColorRect
var _fill_colapso: ColorRect
var _bg_rect: ColorRect


func _ready() -> void:
	randomize()
	_carregar_assets_precisao()
	
	for c in CANAIS:
		var node := $Canais.get_node(c.nome)
		c["onda"] = node.get_node("Onda")
		c["zona"] = node.get_node("Zona")
		c["tecla"] = node.get_node("Tecla")
		c["status"] = node.get_node("Status")
		c["botao"] = _buscar_sprite_botao(node)
		c.tecla.text = c.label
		var emo: Label = node.get_node("Emo")
		emo.text = c.emo
		emo.modulate = Color(c.cor.r, c.cor.g, c.cor.b, 0.7)
		c.onda.default_color = c.cor
		
	_score_label = $HUD/ScoreLabel
	_fala_label = $HUD/FalaLabel
	_fill_score = $HUD/BarraScoreFill
	_fill_foco = $HUD/BarraFocoFill
	_fill_colapso = $HUD/BarraColapsoFill
	
	# Busca nós novos (se não existirem na árvore, o código ignora sem quebrar)
	_bg_rect = get_node_or_null("Background") if get_node_or_null("Background") else get_node_or_null("HUD/Background")
	_garantir_rating_popups()
	
	if has_node("SomRuido"): _som_ruido = $SomRuido
	
	if _som_ruido:
		if not _som_ruido.playing:
			_som_ruido.play()


func _carregar_assets_precisao() -> void:
	_textures_great = _carregar_frames(great_frames_dir, great_frames_prefix, great_frames_max)
	_textures_perfect = _carregar_frames(perfect_frames_dir, perfect_frames_prefix, perfect_frames_max)

	if _textures_great.is_empty():
		push_warning("Nenhum frame GREAT encontrado em: %s" % great_frames_dir)
	if _textures_perfect.is_empty():
		push_warning("Nenhum frame PERFECT encontrado em: %s" % perfect_frames_dir)


func _garantir_rating_popups() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return

	var pos_top := {"J": 130.0, "K": 288.0, "L": 447.0}
	for label in ["J", "K", "L"]:
		var node_name: String = "RatingPopup%s" % label
		var popup: TextureRect = get_node_or_null("HUD/%s" % node_name)
		if popup == null:
			popup = TextureRect.new()
			popup.name = node_name
			popup.offset_left = 72.0
			popup.offset_top = pos_top[label]
			popup.offset_right = 120.0
			popup.offset_bottom = pos_top[label] + 48.0
			popup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			popup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
			popup.z_index = 30
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			popup.material = mat
			hud.add_child(popup)

		popup.visible = false
		_rating_popups[label] = popup
		_rating_states[label] = {"active": false, "type": "", "frame": 0, "timer": 0.0}


func _carregar_frames(base_dir: String, prefixo: String, max_frames: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in range(max_frames):
		var caminho: String = "%s/%s%d.png" % [base_dir, prefixo, i]
		if ResourceLoader.exists(caminho):
			var tex := load(caminho) as Texture2D
			if tex != null:
				frames.append(tex)
		elif frames.size() > 0:
			break
	return frames


func _buscar_sprite_botao(node: Node) -> Sprite2D:
	for filho in node.get_children():
		if filho is Sprite2D and String(filho.name).findn("botton") >= 0:
			return filho
	return null


func reset() -> void:
	tempo = 0.0
	foco = 100.0
	colapso = 0.0
	dist_timer = 1.5
	score = 0
	_score_f = 0.0
	_fala_t = 0.0
	ativo = true
	falhou = false
	for label in ["J", "K", "L"]:
		if _rating_states.has(label):
			_rating_states[label] = {"active": false, "type": "", "frame": 0, "timer": 0.0}
		if _rating_popups.has(label) and _rating_popups[label] != null:
			_rating_popups[label].visible = false
	for c in CANAIS:
		c.nivel = 0.0
		c.agit = 0.0
		c.held = false
		c.held_stable_time = 0.0
		c.was_unstable = false
		c.neon_t = 0.0
		if c.has("botao") and c.botao != null:
			c.botao.scale = Vector2(0.2, 0.2)
			c.botao.modulate = Color.WHITE


func _process(delta: float) -> void:
	for c in CANAIS:
		c.fase += delta * (2.0 + c.agit * 6.0)
		c.neon_t = maxf(0.0, c.neon_t - delta * 3.6)
	if _fala_t > 0.0:
		_fala_t -= delta

	# Mesmo travado pelo glitch, a simulação continua: as ondas seguem
	# perturbando e o colapso pode subir. O que o `travado` faz é só
	# bloquear o INPUT (no _unhandled_input) — o jogador não consegue
	# segurar as teclas pra estabilizar até o outro lado consertar.
	if ativo:
		_atualizar_logica(delta)
		_processar_animacao_nota(delta)

	_aplicar_visual()


func _atualizar_logica(delta: float) -> void:
	tempo += delta
	var dificuldade: float = 1.0 + tempo / 22.0  # escalada mais suave (≈3.7x no fim, era 5x)

	var segurando: int = 0
	for c in CANAIS:
		if c.held:
			segurando += 1
	
	if segurando > 0:
		foco = clampf(foco - (segurando * DRAIN) * DIFICULDADE_MULT * delta, 0.0, 100.0)
	else:
		foco = clampf(foco + RECUP_FOCO * (1.0 + (1.0 - DIFICULDADE_MULT)) * delta, 0.0, 100.0)
		
	var foco_frac: float = foco / 100.0

	for c in CANAIS:
		c.agit = maxf(0.0, c.agit - 0.10 * delta)
		c.nivel = move_toward(c.nivel, 0.0, 0.10 * delta)
		if c.held and foco > 1.0:
			c.agit = maxf(0.0, c.agit - PULL_AGIT * foco_frac * delta)
			c.nivel = move_toward(c.nivel, 0.0, PULL_NIVEL * foco_frac * delta)
			
			# Monitoramento de desperdício de foco: se já estiver estável e continuar pressionado
			if _instab(c) < 0.16:
				c.held_stable_time += delta
		else:
			c.held_stable_time = 0.0
			
		c.agit = clampf(c.agit, 0.0, 1.4)
		c.nivel = clampf(c.nivel, -1.3, 1.3)

	dist_timer -= delta
	if dist_timer <= 0.0:
		_perturbar(dificuldade)
		# frequência das perturbações é independente da punição: mais interação
		dist_timer = randf_range(0.75, 1.45) / (dificuldade * FREQ_MULT)

	var pior: float = 0.0
	var soma_dano: float = 0.0
	var red_thresh_ajustado: float = clampf(RED_THRESH + (1.0 - DIFICULDADE_MULT) * 0.5, 0.0, 1.3)
	for c in CANAIS:
		var b: float = _instab(c)
		pior = maxf(pior, b)
		
		# Marca que a onda entrou em estado crítico de distorção
		if b > red_thresh_ajustado:
			c.was_unstable = true
			soma_dano += (b - red_thresh_ajustado)
			
	if soma_dano > 0.0:
		colapso = minf(100.0, colapso + soma_dano * 14.0 * DIFICULDADE_MULT * delta)
	elif pior < 0.45:
		colapso = maxf(0.0, colapso - 20.0 * (1.0 + (1.0 - DIFICULDADE_MULT)) * delta)

	# a barra verde enche por TEMPO (objetivo = aguentar 60s): 2000/60 por
	# segundo, independente de estabilidade. Quem joga bem é pra NÃO colapsar.
	_score_f += RATE_SCORE * delta
	score = int(_score_f)

	# Modulação dinâmica do fundo baseado na distorção (Verde Claro -> Verde Escuro/Preto)
	if _bg_rect:
		var tom_verde_claro = Color("d8f3dc") # Fundo limpo e estável
		var tom_verde_escuro = Color("081c15") # Fundo distorcido e em colapso
		_bg_rect.color = tom_verde_claro.lerp(tom_verde_escuro, clampf(pior / 1.1, 0.0, 1.0))

	if score >= META:
		score = META
		ativo = false
	elif tempo >= TEMPO_LIMITE:
		if score < META:
			falhou = true
		ativo = false

	if colapso >= 100.0:
		colapso = 100.0
		falhou = true
		ativo = false

	if _som_ruido and ativo:
		if pior > red_thresh_ajustado:
			var instabilidade_extra: float = (pior - red_thresh_ajustado) / (1.5 - red_thresh_ajustado)
			var energia_audio: float = lerpf(0.05, 1.0, instabilidade_extra)
			_som_ruido.volume_db = linear_to_db(energia_audio)
		else:
			_som_ruido.volume_db = move_toward(_som_ruido.volume_db, -80.0, 100.0 * delta)


func _instab(c) -> float:
	return clampf(absf(c.nivel) * 0.85 + c.agit * 0.90, 0.0, 1.5)


func _perturbar(dif: float) -> void:
	var c = CANAIS[randi() % CANAIS.size()]
	# força fixa (0.8), desacoplada do MULT de punição — perturbar bastante,
	# mas o erro continua pouco punível (colapso baixo + limiar folgado)
	c.agit = clampf(c.agit + randf_range(0.22, 0.42) * dif * ONDA_FORCA, 0.0, 1.4)
	c.nivel = clampf(c.nivel + randf_range(-0.45, 0.45) * dif * ONDA_FORCA, -1.3, 1.3)
	if _fala_label:
		_fala_label.text = "« %s »" % FALAS[randi() % FALAS.size()]
		_fala_label.modulate = Color(c.cor.r, c.cor.g, c.cor.b, 1.0)
		_fala_t = 1.8


func _unhandled_input(event: InputEvent) -> void:
	if not ativo or travado or not (event is InputEventKey) or event.echo:
		return
	for c in CANAIS:
		if event.keycode == c.code:
			# Avaliação de Precisão no momento do RELEASE (Soltou o botão)
			if not event.pressed and c.held:
				c.held = false
				if c.was_unstable:
					var inst = _instab(c)
					# Se soltou bem próximo do equilíbrio perfeito (<0.15) e sem gastar foco extra (<0.15s)
					if inst <= 0.15 and c.held_stable_time < 0.15:
						_engajar_nota_popup("perfect", c.label)  # só feedback visual (score é por tempo)
					elif inst <= 0.38:
						_engajar_nota_popup("great", c.label)
					c.was_unstable = false
				return
				
			if event.pressed:
				c.held = true
				match c.label:
					"J": chord_player.press("C")
					"K": chord_player.press("E")
					"L": chord_player.press("G")
			else:
				match c.label:
					"J": chord_player.release("C")
					"K": chord_player.release("E")
					"L": chord_player.release("G")
			return


func _engajar_nota_popup(tipo: String, label: String) -> void:
	if not _rating_popups.has(label) or _rating_popups[label] == null:
		return
	if not _rating_states.has(label):
		return
	if tipo == "great" and _textures_great.is_empty():
		return
	if tipo == "perfect" and _textures_perfect.is_empty():
		return

	_rating_states[label] = {"active": true, "type": tipo, "frame": 0, "timer": 0.0}
	_rating_popups[label].visible = true
	_aplicar_neon_no_popup(label, tipo)
	_disparar_neon_lane(label, tipo)
	_atualizar_textura_popup(label)


func _aplicar_neon_no_popup(label: String, tipo: String) -> void:
	if not _rating_popups.has(label) or _rating_popups[label] == null:
		return
	var popup: TextureRect = _rating_popups[label]
	var brilho: Color = Color("ff6a3d") if tipo == "great" else Color("ff9cd7")

	popup.scale = Vector2(0.84, 0.84)
	popup.modulate = Color(brilho.r, brilho.g, brilho.b, 0.05)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.10, 1.10), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "modulate", Color(brilho.r, brilho.g, brilho.b, 0.98), 0.08)
	t.set_parallel(false)
	t.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _disparar_neon_lane(label: String, tipo: String) -> void:
	for c in CANAIS:
		if c.label == label:
			c.neon_t = 1.0 if tipo == "perfect" else 0.72
			break


func _processar_animacao_nota(delta: float) -> void:
	for label in ["J", "K", "L"]:
		if not _rating_states.has(label):
			continue
		if not _rating_popups.has(label) or _rating_popups[label] == null:
			continue

		var s = _rating_states[label]
		if not s.active:
			continue

		s.timer += delta
		while s.timer >= 0.06: # Levemente mais lento pra ficar visível na gameplay
			s.timer -= 0.06
			s.frame += 1

			var max_frames = _textures_great.size() if s.type == "great" else _textures_perfect.size()
			if s.frame >= max_frames:
				s.active = false
				_rating_popups[label].visible = false
				break
			else:
				_rating_states[label] = s
				_atualizar_textura_popup(label)

		_rating_states[label] = s


func _atualizar_textura_popup(label: String) -> void:
	if not _rating_states.has(label):
		return
	if not _rating_popups.has(label) or _rating_popups[label] == null:
		return

	var s = _rating_states[label]
	if s.type == "great" and s.frame < _textures_great.size():
		_rating_popups[label].texture = _textures_great[s.frame]
	elif s.type == "perfect" and s.frame < _textures_perfect.size():
		_rating_popups[label].texture = _textures_perfect[s.frame]


func _aplicar_visual() -> void:
	for c in CANAIS:
		var pts := PackedVector2Array()
		var amp: float = (0.06 + c.agit) * AGIT_PX
		var off: float = c.nivel * NIVEL_PX
		var x: float = 0.0
		while x <= largura_onda:
			var t: float = x * 0.014 + c.fase
			var y: float = off + sin(t) * amp + sin(t * 2.4 + 1.0) * amp * 0.5 * c.agit
			y += randf_range(-1.0, 1.0) * amp * 0.3 * c.agit
			pts.append(Vector2(x, y))
			x += 6.0
		c.onda.points = pts

		var inst: float = _instab(c)
		var zona_base: Color = Color(0.3, 1.0, 0.5, 0.08).lerp(Color(1.0, 0.3, 0.3, 0.14), clampf(inst, 0.0, 1.0))
		if c.neon_t > 0.0:
			zona_base = zona_base.lerp(Color(c.cor.r, c.cor.g, c.cor.b, 0.34), clampf(c.neon_t, 0.0, 1.0))
		c.zona.color = zona_base

		c.onda.width = 3.0 + c.neon_t * 2.0
		c.tecla.scale = Vector2.ONE * (1.0 + 0.10 * c.neon_t)
		c.tecla.modulate = Color.WHITE if c.held else c.cor.lerp(Color.WHITE, 0.70 * c.neon_t)
		var red_thresh_ajustado: float = clampf(RED_THRESH + (1.0 - DIFICULDADE_MULT) * 0.5, 0.0, 1.3)
		if inst > red_thresh_ajustado:
			c.status.text = "INSTÁVEL"
			c.status.modulate = Color(1.0, 0.4, 0.4)
		elif c.held:
			c.status.text = "PUXANDO"
			c.status.modulate = Color(0.5, 0.85, 1.0)
		else:
			c.status.text = ""

	if _score_label:
		_score_label.text = "SCORE: %d" % score
	if _fill_score:
		_fill_score.scale.x = clampf(float(score) / META, 0.0, 1.0)
	if _fill_foco:
		_fill_foco.scale.x = foco / 100.0
	if _fill_colapso:
		_fill_colapso.scale.x = colapso / 100.0
	if _fala_label:
		_fala_label.modulate.a = clampf(_fala_t / 1.8, 0.0, 1.0)
