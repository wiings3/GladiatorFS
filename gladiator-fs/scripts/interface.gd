extends CanvasLayer
const CREAM = Color("f4e7cf")
const GOLD = Color("ddb571")
const MUTED = Color("b7b5af")
var game
var root: Control
var menu: PanelContainer
var pause_panel: PanelContainer
var hud: Control
var name_input: LineEdit
var address_input: LineEdit
var mode_select: OptionButton
var status: Label
var heading: Label
var objective: Label
var timer: Label
var health_bar: ProgressBar
var health_text: Label
var stamina_bar: ProgressBar
var stamina_text: Label
var weapon_text: Label
var favor_text: Label
var favor_bar: ProgressBar
var prompt: Label
var announce_text: Label
var announce_sub: Label
var feed: Label
var roster: Label
var hint: Label
var spectator_hint: Label
var damage_flash: ColorRect
var announcement_left = 0.0
var feed_left = 0.0
var previous_health = 100.0

func style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, margin: int = 18) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(margin)
	return s

func label(text: String, size: int, color: Color = CREAM) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func positioned(parent: Control, node: Control, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color("23252a") if primary else CREAM)
	b.add_theme_stylebox_override("normal", style(GOLD if primary else Color("353b40")))
	b.add_theme_stylebox_override("hover", style(Color("e8c990") if primary else Color("4a5155"), GOLD, 1))
	b.add_theme_stylebox_override("pressed", style(Color("bd985b")))
	b.pressed.connect(callback)
	return b

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_menu()
	_build_hud()
	_build_pause()
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	# The scene uses a 1440 x 900 design canvas; scale uniformly for small windows.
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = minf(viewport_size.x / 1440.0, viewport_size.y / 900.0)
	root.scale = Vector2.ONE * scale_factor
	root.size = Vector2(1440, 900)
	root.position = (viewport_size - Vector2(1440, 900) * scale_factor) * 0.5

func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", style(Color(0.075, 0.085, 0.10, 0.94), Color("756047"), 1))
	positioned(root, menu, Rect2(62, 65, 440, 765))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	menu.add_child(box)
	box.add_child(label("BAD IDEAS. GOOD COMPANY.  /  0.3", 15, GOLD))
	box.add_child(label("GLADIATOR\nFRIENDSLOP", 43))
	box.add_child(label("Grab a sword. Make it everyone's problem.", 17, MUTED))
	box.add_child(HSeparator.new())
	box.add_child(label("YOUR GLADIATOR", 14, GOLD))
	name_input = LineEdit.new()
	name_input.text = "Gladiator"
	name_input.max_length = 18
	name_input.custom_minimum_size.y = 40
	box.add_child(name_input)
	mode_select = OptionButton.new()
	for mode in game.MODES:
		mode_select.add_item(mode)
	mode_select.selected = 1
	mode_select.custom_minimum_size.y = 42
	box.add_child(mode_select)
	box.add_child(button("SOLO PRACTICE", func(): game.start_session(false, name_input.text, mode_select.selected), true))
	box.add_child(button("HOST  ·  UP TO 4 PLAYERS", func(): game.start_session(true, name_input.text, mode_select.selected)))
	address_input = LineEdit.new()
	address_input.text = "127.0.0.1"
	address_input.placeholder_text = "Host IP address"
	address_input.custom_minimum_size.y = 40
	box.add_child(address_input)
	box.add_child(button("JOIN FRIEND", func(): game.join_session(address_input.text, name_input.text)))
	status = label("LAN / direct IP  ·  UDP 27840\nSame PC? Open a second instance and join 127.0.0.1.", 14, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	box.add_child(label("Tap LMB to stab · Hold + drag to swing\nHold RMB + aim to block · F kick\nWASD move · C view · Scroll wheel zoom", 16, CREAM))

func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.size = Vector2(1440, 900)
	root.add_child(hud)
	hud.hide()
	for rect in [Rect2(18, 18, 342, 125), Rect2(385, 18, 670, 120), Rect2(1125, 18, 295, 75), Rect2(18, 692, 360, 148), Rect2(0, 844, 1440, 56)]:
		var backing = ColorRect.new()
		backing.color = Color(0.08, 0.10, 0.12, 0.73)
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		positioned(hud, backing, rect)
	heading = label("THE BARRACKS", 27, CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, heading, Rect2(390, 28, 660, 38))
	objective = label("", 18, GOLD)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, objective, Rect2(290, 69, 860, 30))
	timer = label("", 18, MUTED)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, timer, Rect2(420, 102, 600, 30))
	positioned(hud, label("GLADIATOR / FS", 19, GOLD), Rect2(32, 30, 320, 30))
	roster = label("", 16, CREAM)
	positioned(hud, roster, Rect2(33, 79, 345, 160))
	favor_text = label("CROWD FAVOR", 17, GOLD)
	favor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	positioned(hud, favor_text, Rect2(1080, 32, 324, 32))
	favor_bar = ProgressBar.new()
	favor_bar.show_percentage = false
	favor_bar.add_theme_stylebox_override("background", style(Color("36373b"), Color.TRANSPARENT, 0, 0))
	favor_bar.add_theme_stylebox_override("fill", style(GOLD, Color.TRANSPARENT, 0, 0))
	positioned(hud, favor_bar, Rect2(1160, 70, 245, 7))
	health_text = label("GLADIATOR", 21)
	positioned(hud, health_text, Rect2(34, 701, 430, 34))
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", style(Color("343238"), Color.TRANSPARENT, 0, 0))
	health_bar.add_theme_stylebox_override("fill", style(Color("c85c43"), Color.TRANSPARENT, 0, 0))
	positioned(hud, health_bar, Rect2(35, 743, 305, 10))
	stamina_text = label("STAMINA", 13, Color("83d9be"))
	positioned(hud, stamina_text, Rect2(35, 763, 305, 22))
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", style(Color("343238"), Color.TRANSPARENT, 0, 0))
	stamina_bar.add_theme_stylebox_override("fill", style(Color("83d9be"), Color.TRANSPARENT, 0, 0))
	positioned(hud, stamina_bar, Rect2(35, 790, 305, 7))
	weapon_text = label("SWORD  /  SHIELD", 17, GOLD)
	positioned(hud, weapon_text, Rect2(35, 807, 490, 40))
	var reticle = ColorRect.new()
	reticle.color = CREAM
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	positioned(hud, reticle, Rect2(718.5, 448.5, 3, 3))
	prompt = label("", 22, CREAM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, prompt, Rect2(370, 690, 700, 40))
	announce_text = label("", 38)
	announce_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, announce_text, Rect2(80, 238, 1280, 58))
	announce_sub = label("", 19, GOLD)
	announce_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, announce_sub, Rect2(80, 300, 1280, 36))
	feed = label("", 17, GOLD)
	feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	positioned(hud, feed, Rect2(774, 790, 630, 40))
	hint = label("WASD MOVE    SHIFT SPRINT    SPACE JUMP    CTRL DODGE    TAP LMB STAB    HOLD LMB + DRAG SWING    RMB SHIELD", 14, CREAM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, hint, Rect2(12, 850, 1416, 24))
	var second = label("F KICK    E PICK UP    Q DROP    R THROW    V THROW SHIELD    G DRAG BODY    T TAUNT    C VIEW    WHEEL ZOOM    ESC MENU", 13, MUTED)
	second.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, second, Rect2(12, 877, 1416, 21))
	spectator_hint = label("", 19, GOLD)
	spectator_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(hud, spectator_hint, Rect2(375, 753, 690, 52))
	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.7, 0.12, 0.07, 0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	positioned(hud, damage_flash, Rect2(0, 0, 1440, 900))

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", style(Color("20262c"), GOLD, 1))
	positioned(root, pause_panel, Rect2(485, 155, 470, 575))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	pause_panel.add_child(box)
	box.add_child(label("TAKE A BREATH", 31))
	box.add_child(label("The arena keeps moving while this menu is open.", 16, MUTED))
	box.add_child(button("RETURN TO ARENA", func(): game.toggle_menu()))
	box.add_child(label("MOUSE SENSITIVITY", 15, GOLD))
	var sensitivity = HSlider.new()
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = 1
	sensitivity.value_changed.connect(func(value): game.sensitivity = value)
	box.add_child(sensitivity)
	box.add_child(label("SWING SENSITIVITY", 15, GOLD))
	var swing = HSlider.new()
	swing.min_value = 0.5
	swing.max_value = 2.0
	swing.step = 0.05
	swing.value = 1
	swing.value_changed.connect(func(value): game.swing_sensitivity = value)
	box.add_child(swing)
	box.add_child(label("VOLUME", 15, GOLD))
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = 0.65
	volume.value_changed.connect(func(value): AudioServer.set_bus_volume_db(0, linear_to_db(value)))
	box.add_child(volume)
	box.add_child(button("LEAVE SESSION", func(): game.leave_session("Session ended.")))
	pause_panel.hide()

func announce(text: String, sub: String = "", duration: float = 3.5) -> void:
	announce_text.text = text
	announce_sub.text = sub
	announcement_left = duration

func toast(text: String) -> void:
	if text.is_empty():
		return
	feed.text = text
	feed_left = 5

func _process(delta: float) -> void:
	announcement_left = maxf(0, announcement_left - delta)
	feed_left = maxf(0, feed_left - delta)
	announce_text.modulate.a = minf(1, announcement_left * 2)
	announce_sub.modulate.a = announce_text.modulate.a
	feed.modulate.a = minf(1, feed_left)
	damage_flash.color.a = maxf(0, damage_flash.color.a - delta * 0.6)
	if not game.running:
		return
	var me = game.actors.get(game.local_id())
	if not is_instance_valid(me):
		return
	heading.text = "THE BARRACKS" if game.phase == "barracks" else game.MODES[game.mode].to_upper()
	objective.text = game.objective_text()
	timer.text = "ROUND %02d  /  %s" % [game.round_number, game.time_text()]
	if game.phase == "barracks" and game.authority:
		timer.text = "ENTER  ·  OPEN THE GATES     |     1–4  ·  CHANGE EVENT"
	health_text.text = me.title.to_upper() + ("  ·  %d" % int(me.health) if me.alive else "  ·  IN THE STANDS")
	health_bar.value = me.health
	stamina_bar.value = me.stamina
	stamina_bar.modulate = Color("ff9568") if me.exhausted or me.guard_broken > 0 else Color.WHITE
	stamina_text.text = "STAMINA  ·  GUARD BROKEN" if me.guard_broken > 0 else ("STAMINA  ·  CATCH YOUR BREATH" if me.exhausted else "STAMINA")
	weapon_text.text = (me.held.to_upper() if me.held != "" else "BARE HANDS") + ("  /  SHIELD" if me.shield else "")
	favor_text.text = "CROWD FAVOR   %d" % me.favor
	favor_bar.value = mini(me.favor, 100)
	if me.health < previous_health:
		damage_flash.color.a = 0.2
	previous_health = me.health
	prompt.text = game.interaction_prompt(me)
	spectator_hint.text = "← / →  SWITCH GLADIATOR     E  CHEER     R  THROW FROM STANDS" if not me.alive else ""
	var entries = []
	for actor in game.actors.values():
		if not actor.bot:
			entries.append(("●  " if actor.alive else "×  ") + actor.title + "   %d favor · %d wins" % [actor.favor, actor.wins])
	roster.text = "\n".join(entries)
