extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const GREEN := Color("69a94b")
const DARK_GREEN := Color("387343")
const GOLD := Color("f6c84a")

var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var inventory_label: Label
var coins_label: Label
var status_label: Label
var upgrade_panel: PanelContainer
var upgrade_list: VBoxContainer
var input_origin := Vector2.ZERO
var active_touch := -1
var touch_vector := Vector2.ZERO
var current_action := ""
var nearby_station := ""
var carried_wheat := 0
var carried_bread := 0
var deposited_wheat := 0
var ready_bread := 0
var counter_bread := 0
var sale_coins: Array[Dictionary] = []
var timer_harvest := 0.0
var timer_process := 0.0
var timer_buyer := 3.0
var timer_save := 0.0
var wheat_visuals: Array[Node3D] = []
var bread_visuals: Array[Node3D] = []
var coin_visuals: Array[Node3D] = []
var actor_visual: Node3D
var joystick_base: Control
var joystick_knob: Control
var upgrade_pad: StaticBody3D
var area_pad: StaticBody3D
var info_panel: PanelContainer
var action_button: Button

func _ready() -> void:
	carried_wheat = GameState.carried_wheat
	carried_bread = GameState.carried_bread
	deposited_wheat = GameState.deposited_wheat
	ready_bread = GameState.ready_bread
	counter_bread = GameState.counter_bread
	if GameState.pending_coins > 0:
		sale_coins.append({"amount": GameState.pending_coins, "position": Vector3(8, 0.35, 3)})
	_build_world()
	_build_player()
	_build_camera()
	_build_hud()
	GameState.changed.connect(_refresh_hud)
	_refresh_hud()
	_sync_stack_visuals()

func _process(delta: float) -> void:
	_update_production(delta)
	_update_buyer(delta)
	_update_camera(delta)
	_update_station()
	_update_employees(delta)
	_sync_stack_visuals()
	timer_save += delta
	if timer_save >= 15.0:
		timer_save = 0.0
		_persist_world()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_persist_world()

func _persist_world() -> void:
	GameState.carried_wheat = carried_wheat
	GameState.carried_bread = carried_bread
	GameState.deposited_wheat = deposited_wheat
	GameState.ready_bread = ready_bread
	GameState.counter_bread = counter_bread
	GameState.pending_coins = 0
	for drop in sale_coins:
		GameState.pending_coins += int(drop.amount)
	GameState.save_game()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1 and event.position.x < get_viewport().get_visible_rect().size.x * 0.55:
			active_touch = event.index
			input_origin = event.position
			joystick_base.position = input_origin - Vector2(65, 65)
			joystick_knob.position = joystick_base.position + Vector2(37, 37)
			joystick_base.visible = true
			joystick_knob.visible = true
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			touch_vector = Vector2.ZERO
			joystick_base.visible = false
			joystick_knob.visible = false
	elif event is InputEventScreenDrag and event.index == active_touch:
		var delta := event.position - input_origin
		touch_vector = (delta / 55.0).limit_length(1.0)
		joystick_knob.position = joystick_base.position + Vector2(37, 37) + touch_vector * 34.0

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 0.97)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	_add_box("Gramado", Vector3(0, -0.25, 0), Vector3(34, 0.5, 30), GREEN, true)
	_add_box("Caminho", Vector3(0, 0.015, 1.6), Vector3(30, 0.04, 2.4), Color("d6bd83"), false)
	_add_box("Campo de trigo", Vector3(-8, 0, -5), Vector3(11, 0.08, 9), Color("9dbe55"), false)
	for x in range(-12, -3):
		for z in range(-8, -2):
			var stalk := _add_box("Trigo", Vector3(x + 0.25, 0.45, z + 0.25), Vector3(0.14, 0.9, 0.14), Color("e7c54e"), false)
			stalk.rotation_degrees.z = randf_range(-7, 7)
	_add_machine(Vector3(-1, 0, -4), "PROCESSAMENTO", Color("6f8790"))
	_add_machine(Vector3(3.2, 0, -4), "FORNO", Color("bd6846"))
	_add_machine(Vector3(7.5, 0, -4), "PÃES PRONTOS", Color("8d6945"))
	_add_machine(Vector3(8, 0, 3), "CAIXA", Color("4d7661"))
	_add_pad(Vector3(-5, 0, 5), "MELHORIAS", "upgrade")
	_add_pad(Vector3(12, 0, 5), "PRÓXIMA ÁREA", "area")
	for x in [-15, 15]:
		_add_box("Árvore", Vector3(x, 1, -7), Vector3(1, 2, 1), Color("75543b"), true)
		_add_box("Copa", Vector3(x, 2.7, -7), Vector3(3, 2.1, 3), Color("478448"), false)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Jogador"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 0.1, 3)
	player.set("game", self)
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.45
	collider.shape = capsule
	collider.position.y = 0.72
	player.add_child(collider)
	actor_visual = Node3D.new()
	player.add_child(actor_visual)
	_add_mesh(actor_visual, "Corpo", Vector3(0, 0.8, 0), Vector3(0.55, 0.8, 0.34), Color("3978b7"))
	_add_mesh(actor_visual, "Cabeça", Vector3(0, 1.45, 0), Vector3(0.48, 0.48, 0.48), Color("f0c39a"))
	_add_mesh(actor_visual, "Chapéu", Vector3(0, 1.73, 0), Vector3(0.7, 0.15, 0.7), Color("d9a840"))

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 13, 13)
	camera.rotation_degrees = Vector3(-48, 0, 0)
	camera.current = true
	add_child(camera)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 18)
	hud.add_child(top)
	coins_label = _label("🪙 0", 25)
	top.add_child(coins_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 30
	top.add_child(spacer)
	var area_label := _label("FAZENDA • ÁREA 1", 20)
	top.add_child(area_label)
	var inventory_panel := _panel(Vector2(24, 68), Vector2(240, 90))
	hud.add_child(inventory_panel)
	var inv_box := VBoxContainer.new()
	inventory_panel.add_child(inv_box)
	inventory_label = _label("Carga: 0/8", 18)
	inv_box.add_child(inventory_label)
	status_label = _label("Colha o trigo e leve ao processamento", 18)
	status_label.position = Vector2(24, 170)
	hud.add_child(status_label)
	var btn := _button("☰", Vector2(0, 18), Vector2(72, 52))
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -94
	btn.offset_right = -22
	btn.pressed.connect(_toggle_info)
	hud.add_child(btn)
	action_button = _button("Interagir", Vector2.ZERO, Vector2(160, 58))
	action_button.anchor_left = 1.0
	action_button.anchor_top = 1.0
	action_button.anchor_right = 1.0
	action_button.anchor_bottom = 1.0
	action_button.offset_left = -190
	action_button.offset_top = -94
	action_button.offset_right = -30
	action_button.offset_bottom = -36
	action_button.visible = false
	action_button.pressed.connect(_do_interaction)
	hud.add_child(action_button)
	upgrade_panel = _panel(Vector2(20, 0), Vector2(320, 420))
	upgrade_panel.anchor_top = 0.5
	upgrade_panel.anchor_bottom = 0.5
	upgrade_panel.visible = false
	hud.add_child(upgrade_panel)
	upgrade_list = VBoxContainer.new()
	upgrade_panel.add_child(upgrade_list)
	_build_upgrade_list()
	info_panel = _panel(Vector2(0, 60), Vector2(320, 410))
	info_panel.anchor_left = 0.5
	info_panel.anchor_right = 0.5
	info_panel.offset_left = -160
	info_panel.offset_right = 160
	info_panel.visible = false
	hud.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_panel.add_child(info_box)
	for title in ["Industry Evolution", "Progresso: Fazenda → Megacomplexo", "Salvamento automático ativo", "Configurações", "Apoie o desenvolvedor", "Privacidade • Termos • Sobre"]:
		info_box.add_child(_label(title, 17))
	var close_btn := _button("Fechar", Vector2.ZERO, Vector2(220, 44))
	close_btn.pressed.connect(func(): info_panel.visible = false)
	info_box.add_child(close_btn)
	joystick_base = Control.new()
	joystick_base.size = Vector2(130, 130)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.visible = false
	hud.add_child(joystick_base)
	var base_draw := ColorRect.new()
	base_draw.position = Vector2.ZERO
	base_draw.size = Vector2(130, 130)
	base_draw.color = Color(0.1, 0.15, 0.18, 0.33)
	base_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(base_draw)
	joystick_knob = Control.new()
	joystick_knob.size = Vector2(56, 56)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.visible = false
	hud.add_child(joystick_knob)
	var knob_draw := ColorRect.new()
	knob_draw.size = Vector2(56, 56)
	knob_draw.color = Color(1, 1, 1, 0.58)
	knob_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.add_child(knob_draw)

func _build_upgrade_list() -> void:
	upgrade_list.add_child(_label("MELHORIAS DA FAZENDA", 18))
	var close_btn := _button("Fechar", Vector2.ZERO, Vector2(260, 38))
	close_btn.pressed.connect(func(): upgrade_panel.visible = false)
	upgrade_list.add_child(close_btn)
	for item in GameState.UPGRADE_CATALOG:
		var id: String = item.id
		var button := _button("%s  •  %d moedas" % [item.name, item.price], Vector2.ZERO, Vector2(280, 44))
		button.tooltip_text = item.description
		button.pressed.connect(func(): _purchase_upgrade(id))
		upgrade_list.add_child(button)
	var do_btn := _button("Apoie o desenvolvedor", Vector2.ZERO, Vector2(280, 40))
	do_btn.pressed.connect(func(): _notify("Doações voluntárias: em breve."))
	upgrade_list.add_child(do_btn)

func _update_station() -> void:
	var p := player.global_position
	var next_action := ""
	if p.distance_to(Vector3(-8, 0, -5)) < 2.4:
		next_action = "wheat"
	elif p.distance_to(Vector3(-1, 0, -4)) < 2.3:
		next_action = "process"
	elif p.distance_to(Vector3(7.5, 0, -4)) < 2.3:
		next_action = "bread"
	elif p.distance_to(Vector3(8, 0, 3)) < 2.2:
		next_action = "sell"
	elif p.distance_to(Vector3(-5, 0, 5)) < 2.4:
		next_action = "upgrade"
	elif p.distance_to(Vector3(12, 0, 5)) < 2.5:
		next_action = "area"
	nearby_station = next_action
	if is_instance_valid(action_button):
		action_button.visible = next_action == "area"
		action_button.text = "Desbloquear • %d" % GameState.area_unlock_price()
	if next_action != current_action:
		current_action = next_action
		match current_action:
			"wheat": _notify("Colhendo trigo automaticamente…")
			"process": _notify("Trigo entregue. O forno trabalha sozinho.")
			"bread": _notify("Pães recolhidos para transportar.")
			"sell": _notify("Entregando pães no caixa. Colete as moedas aqui.")
			"upgrade": _notify("Plataforma de melhorias: caminhe sobre uma oferta.")
			"area": _notify("Área %d: %s • desbloqueio %d moedas" % [GameState.unlocked_areas + 1, GameState.AREA_NAMES[GameState.unlocked_areas] if GameState.unlocked_areas < 20 else "Máximo", GameState.area_unlock_price()])
			"": _notify("Explore a fazenda e automatize sua produção.")
	if nearby_station == "wheat":
		timer_harvest += get_process_delta_time()
		if timer_harvest >= 0.8 / GameState.harvest_rate and _carried_count() < GameState.capacity:
			timer_harvest = 0
			carried_wheat += 1
	elif nearby_station == "process" and carried_wheat > 0:
		var moved := mini(carried_wheat, 4)
		carried_wheat -= moved
		deposited_wheat += moved
	elif nearby_station == "bread" and ready_bread > 0 and _carried_count() < GameState.capacity:
		var picked := mini(ready_bread, GameState.capacity - _carried_count())
		ready_bread -= picked
		carried_bread += picked
	elif nearby_station == "sell" and counter_bread < 3 and carried_bread > 0:
		var count := mini(carried_bread, 3 - counter_bread)
		carried_bread -= count
		counter_bread += count
	if nearby_station == "upgrade":
		upgrade_panel.visible = true
	if nearby_station == "area" and Input.is_action_just_pressed("interact"):
		_do_interaction()

func _do_interaction() -> void:
	if nearby_station == "area":
		if GameState.unlock_next_area(): _notify("Nova área desbloqueada! %s" % GameState.AREA_NAMES[GameState.unlocked_areas - 1])
		else: _notify("Você precisa de %d moedas." % GameState.area_unlock_price())

func _update_production(delta: float) -> void:
	if deposited_wheat > 0:
		timer_process += delta * GameState.oven_rate
		if timer_process >= 3.0:
			timer_process = 0
			deposited_wheat -= 1
			ready_bread += 1
	if counter_bread > 0 and timer_buyer <= 0:
		var order := randi_range(1, 3)
		if counter_bread >= order:
			counter_bread -= order
			var reward := order * 12
			sale_coins.append({"amount": reward, "position": Vector3(8 + randf_range(-1, 1), 0.35, 3 + randf_range(-0.7, 0.7))})
			GameState.pending_coins += reward
			_notify("Cliente comprou %d pão(ães): %d moedas no caixa." % [order, reward])
		timer_buyer = 5.0
	
func _update_buyer(delta: float) -> void:
	timer_buyer -= delta
	if sale_coins.size() > 0 and player.global_position.distance_to(Vector3(8, 0, 3)) < 2.3:
		var total := 0
		for drop in sale_coins: total += int(drop.amount)
		sale_coins.clear()
		GameState.pending_coins = 0
		GameState.add_coins(total)
		_notify("+%d moedas coletadas!" % total)

func _update_employees(delta: float) -> void:
	if GameState.employees.has("collector") and randf() < delta * 1.2 and carried_wheat < GameState.capacity:
		carried_wheat += 1
	if GameState.employees.has("wheat_hauler") and deposited_wheat < 20 and randf() < delta * 0.65 and carried_wheat > 0:
		carried_wheat -= 1
		deposited_wheat += 1
	if GameState.employees.has("bread_hauler") and ready_bread > 0 and counter_bread < 3 and randf() < delta * 0.8:
		ready_bread -= 1
		counter_bread += 1
	if GameState.employees.has("seller"):
		pass # O vendedor só atende clientes; as moedas continuam sendo coletadas pelo jogador.

func _update_camera(delta: float) -> void:
	var target := player.global_position + Vector3(0, 12, 13)
	camera.global_position = camera.global_position.lerp(target, minf(delta * 5.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 0.3, 0), Vector3.UP)

func movement_input() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return keyboard if keyboard.length() > 0.05 else touch_vector

func _carried_count() -> int:
	return carried_wheat + carried_bread

func _sync_stack_visuals() -> void:
	_sync_stack(wheat_visuals, carried_wheat, Color("e8c949"), 0.22)
	_sync_stack(bread_visuals, carried_bread, Color("c78b4b"), 0.25)
	_sync_stack(coin_visuals, sale_coins.size(), GOLD, 0.32, true)
	if is_instance_valid(inventory_label):
		inventory_label.text = "Carga: %d/%d  •  🌾 %d  🍞 %d\nEstoque: 🌾 %d  🍞 %d  |  Caixa: %d" % [_carried_count(), GameState.capacity, carried_wheat, carried_bread, deposited_wheat, ready_bread, counter_bread]

func _sync_stack(list: Array[Node3D], amount: int, color: Color, size: float, is_coin: bool = false) -> void:
	while list.size() < amount:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(size, size * 0.6, size)
		mesh.mesh = box
		mesh.material_override = _material(color)
		if is_coin:
			add_child(mesh)
		else:
			actor_visual.add_child(mesh)
		list.append(mesh)
	while list.size() > amount:
		var mesh: Node3D = list.pop_back()
		mesh.queue_free()
	for i in list.size():
		if is_coin:
			list[i].position = sale_coins[mini(i, sale_coins.size() - 1)].position + Vector3(0, float(i) * 0.17, 0) if sale_coins.size() > 0 else Vector3.ZERO
		else:
			list[i].position = Vector3(-0.2 + float(i % 3) * 0.2, 0.62 + float(i / 3) * 0.17, 0.25)

func _refresh_hud() -> void:
	if is_instance_valid(coins_label): coins_label.text = "🪙 %d" % GameState.coins
	if is_instance_valid(inventory_label): _sync_stack_visuals()

func _purchase_upgrade(id: String) -> void:
	if GameState.buy_upgrade(id):
		_notify("Melhoria adquirida!")
		_build_upgrade_refresh()
	else:
		_notify("Moedas insuficientes ou melhoria já comprada.")

func _build_upgrade_refresh() -> void:
	for child in upgrade_list.get_children():
		if child is Button and child.text != "Fechar":
			for item in GameState.UPGRADE_CATALOG:
				if child.text.begins_with(item.name) and GameState.upgrades.has(item.id):
					child.disabled = true
					child.text = "✓ " + item.name + " • adquirido"

func _notify(message: String) -> void:
	if is_instance_valid(status_label): status_label.text = message

func _toggle_info() -> void:
	info_panel.visible = not info_panel.visible

func _add_machine(pos: Vector3, title: String, color: Color) -> void:
	_add_box(title, pos + Vector3(0, 0.75, 0), Vector3(2.1, 1.5, 1.8), color, true)
	_add_box(title + " placa", pos + Vector3(0, 1.65, -0.93), Vector3(1.6, 0.35, 0.08), Color("f1e5bd"), false)

func _add_pad(pos: Vector3, title: String, type: String) -> void:
	var pad := StaticBody3D.new()
	pad.position = pos
	add_child(pad)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.7, 0.2, 2.2)
	mesh.mesh = box
	mesh.material_override = _material(Color("d6b24e") if type == "upgrade" else Color("68a6cc"))
	pad.add_child(mesh)
	if type == "upgrade": upgrade_pad = pad
	else: area_pad = pad
	_add_box(title, pos + Vector3(0, 0.36, 0), Vector3(2.1, 0.4, 0.12), Color("fff1bd"), false)

func _add_box(title: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
	return mesh

func _add_mesh(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.15, 0.9)
	style.border_color = Color("d7b95f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text_value: String, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff2cf"))
	return label

func _button(text_value: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("fff2cf"))
	return button
