extends Node

signal changed

const SAVE_PATH := "user://industry_evolution.save"
const SAVE_VERSION := 1

var coins: int = 0
var wheat: int = 0
var flour: int = 0
var bread: int = 0
var carried_wheat: int = 0
var carried_bread: int = 0
var deposited_wheat: int = 0
var ready_bread: int = 0
var counter_bread: int = 0
var pending_coins: int = 0
var capacity: int = 8
var harvest_rate: float = 1.0
var oven_rate: float = 1.0
var unlocked_areas: int = 1
var upgrades: Array[String] = []
var employees: Array[String] = []
var settings := {"master": 1.0, "music": 0.8, "sfx": 1.0, "quality": 1, "joystick_sensitivity": 1.0, "vibration": true, "language": "pt_BR"}

const AREA_NAMES := ["Fazenda", "Moinho", "Padaria industrial", "Pecuária", "Serraria", "Mineração", "Fundição", "Joalheria", "Indústria têxtil", "Fábrica de ferramentas", "Indústria química", "Fábrica de componentes", "Eletrônicos", "Automobilística", "Indústria naval", "Energia", "Robótica", "Aeroespacial", "Tecnologia avançada", "Megacomplexo industrial"]
const UPGRADE_CATALOG := [
	{"id":"scythe", "name":"Foice", "price":30, "description":"Colheita 50% mais rápida."},
	{"id":"capacity_1", "name":"Cesto reforçado", "price":60, "description":"Aumenta a capacidade para 14 itens."},
	{"id":"better_scythe", "name":"Foice aprimorada", "price":120, "description":"Colheita duas vezes mais rápida."},
	{"id":"oven", "name":"Forno aprimorado", "price":180, "description":"Produção de pão mais rápida."},
	{"id":"collector", "name":"Funcionário coletor", "price":350, "description":"Coleta trigo enquanto você trabalha."},
	{"id":"wheat_hauler", "name":"Transportador de trigo", "price":500, "description":"Leva trigo ao processamento."},
	{"id":"bread_hauler", "name":"Transportador de pão", "price":700, "description":"Abastece o caixa automaticamente."},
	{"id":"capacity_2", "name":"Mochila industrial", "price":900, "description":"Aumenta a capacidade para 24 itens."},
	{"id":"seller", "name":"Vendedor automático", "price":1800, "description":"Atende clientes. Moedas ainda são coletadas por você."}
]

func _ready() -> void:
	load_game()

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	changed.emit()
	save_game()

func buy_upgrade(upgrade_id: String) -> bool:
	if upgrades.has(upgrade_id):
		return false
	for item in UPGRADE_CATALOG:
		if item.id == upgrade_id and coins >= int(item.price):
			coins -= int(item.price)
			upgrades.append(upgrade_id)
			_apply_upgrade(upgrade_id)
			changed.emit()
			save_game()
			return true
	return false

func unlock_next_area() -> bool:
	if unlocked_areas >= AREA_NAMES.size():
		return false
	var price := 1000 * int(pow(2.15, unlocked_areas - 1))
	if coins < price:
		return false
	coins -= price
	unlocked_areas += 1
	changed.emit()
	save_game()
	return true

func area_unlock_price() -> int:
	return 1000 * int(pow(2.15, unlocked_areas - 1))

func _apply_upgrade(id: String) -> void:
	match id:
		"scythe": harvest_rate = 1.5
		"better_scythe": harvest_rate = 2.5
		"capacity_1": capacity = 14
		"capacity_2": capacity = 24
		"oven": oven_rate = 1.8
		"collector": employees.append("collector")
		"wheat_hauler": employees.append("wheat_hauler")
		"bread_hauler": employees.append("bread_hauler")
		"seller": employees.append("seller")

func save_game() -> void:
	var data := {"version": SAVE_VERSION, "coins": coins, "wheat": wheat, "flour": flour, "bread": bread, "carried_wheat": carried_wheat, "carried_bread": carried_bread, "deposited_wheat": deposited_wheat, "ready_bread": ready_bread, "counter_bread": counter_bread, "pending_coins": pending_coins, "capacity": capacity, "harvest_rate": harvest_rate, "oven_rate": oven_rate, "unlocked_areas": unlocked_areas, "upgrades": upgrades, "employees": employees, "settings": settings}
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível gravar o salvamento.")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_warning("Não foi possível finalizar o salvamento.")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("Salvamento inválido ou incompatível; uma nova partida será iniciada.")
		return
	coins = maxi(0, int(parsed.get("coins", 0)))
	wheat = maxi(0, int(parsed.get("wheat", 0)))
	flour = maxi(0, int(parsed.get("flour", 0)))
	bread = maxi(0, int(parsed.get("bread", 0)))
	carried_wheat = maxi(0, int(parsed.get("carried_wheat", 0)))
	carried_bread = maxi(0, int(parsed.get("carried_bread", 0)))
	deposited_wheat = maxi(0, int(parsed.get("deposited_wheat", 0)))
	ready_bread = maxi(0, int(parsed.get("ready_bread", 0)))
	counter_bread = clampi(int(parsed.get("counter_bread", 0)), 0, 3)
	pending_coins = maxi(0, int(parsed.get("pending_coins", 0)))
	capacity = maxi(8, int(parsed.get("capacity", 8)))
	harvest_rate = float(parsed.get("harvest_rate", 1.0))
	oven_rate = float(parsed.get("oven_rate", 1.0))
	unlocked_areas = clampi(int(parsed.get("unlocked_areas", 1)), 1, AREA_NAMES.size())
	upgrades.assign(parsed.get("upgrades", []))
	employees.assign(parsed.get("employees", []))
	settings.merge(parsed.get("settings", {}), true)
