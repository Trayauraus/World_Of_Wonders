extends Node

# --- UI Nodes ---
@onready var main_menu_ui = $"Multiplayer UI"
@onready var host_panel = $"Multiplayer UI/HostPanel"
@onready var level_list_container = $"Multiplayer UI/HostPanel/LevelScroll/LevelListVBox"
@onready var host_mode_button = $"Multiplayer UI/HostButton"
@onready var join_panel = $"Multiplayer UI/JoinPanel"
@onready var join_mode_button = $"Multiplayer UI/JoinButton"
@onready var scan_button = $"Multiplayer UI/JoinPanel/ScanButton"
@onready var manual_join_button = $"Multiplayer UI/JoinPanel/JoinManualButton"
@onready var ip_input = $"Multiplayer UI/JoinPanel/IPInput"
@onready var server_list_container = $"Multiplayer UI/JoinPanel/ServerListScroll/ServerListVBox"
@onready var status_label = $"Multiplayer UI/JoinPanel/StatusLabel"
@onready var server_name_input = $"Multiplayer UI/HostPanel/ServerNameInput"

@export var back_from_host: Button
@export var back_from_join: Button

@onready var level_container = $LevelContainer 
@onready var players_container = $Players

# --- Configuration ---
const BASE_PORT = 7000
const BROADCAST_PORT = 6999 
const LEVEL_MANIFEST_PATH = "res://Manifest/level_manifest.tres"

@export_group("Settings")
@export var credits_manifest_no: int = 9 
@export var scan_duration: float = 5.0 
@export var scan_retry_delay: float = 2.0 

@export_group("Button Styling")
@export var button_font: FontFile = load("res://Assets/Fonts/Pixel Game.otf")
@export var button_font_size: int = 32
@export var button_size: Vector2 = Vector2(530, 50)

# --- Networking Variables ---
var udp_broadcaster := PacketPeerUDP.new()
var udp_listener := PacketPeerUDP.new()
var broadcast_timer := Timer.new()
var scan_timer := Timer.new()
var retry_timer := Timer.new()
var found_servers: Dictionary = {} 
var actual_hosted_port: int = BASE_PORT 

@onready var level_manifest = load(LEVEL_MANIFEST_PATH)
var level_data: Dictionary = {} 

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	host_mode_button.pressed.connect(_show_host_panel)
	join_mode_button.pressed.connect(_show_join_panel)
	scan_button.pressed.connect(_start_scanning)
	manual_join_button.pressed.connect(_on_manual_join_pressed)
	
	level_container.child_entered_tree.connect(_on_level_added)
	
	if back_from_join: back_from_join.pressed.connect(_stop_scanning)
	if back_from_host: back_from_host.pressed.connect(_hide_panels)
	
	add_child(broadcast_timer); broadcast_timer.wait_time = 1.0; broadcast_timer.timeout.connect(_broadcast_presence)
	add_child(scan_timer); scan_timer.one_shot = true; scan_timer.timeout.connect(_on_scan_timeout)
	add_child(retry_timer); retry_timer.one_shot = true; retry_timer.timeout.connect(_start_scanning)
	
	_parse_level_manifest()
	_hide_panels()

func _process(_delta):
	if join_panel.visible and not scan_timer.is_stopped():
		_listen_for_broadcasts()

## --- LEVEL LOGIC ---

func _parse_level_manifest():
	if not level_manifest: return
	level_data[-1] = {"path": "res://Scenes + Scripts/Levels/-001 Tutorial Grasslands.tscn", "name": "Tutorial Grasslands"}
	for scene in level_manifest.level_scenes:
		var path = scene.get_path()
		var filename = path.get_file().get_basename()
		var level_num = filename.substr(0, 4).to_int() if filename.begins_with("-") else filename.substr(0, 3).to_int()
		if level_num == credits_manifest_no: continue
		var pretty_name = filename.substr(4 if filename.begins_with("-") else 3).replace("_", " ").replace("-", " ").strip_edges()
		level_data[level_num] = { "path": path, "name": pretty_name }

func _populate_level_selection():
	for child in level_list_container.get_children(): child.queue_free()
	var keys = level_data.keys(); keys.sort()
	for num in keys:
		var btn = Button.new()
		if button_font: btn.add_theme_font_override("font", button_font)
		btn.add_theme_font_size_override("font_size", button_font_size)
		btn.custom_minimum_size = button_size
		btn.text = ("Tutorial: " if num <= 0 else "Lv %d: " % num) + level_data[num].name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_host_game.bind(level_data[num].path, level_data[num].name))
		level_list_container.add_child(btn)

func _show_host_panel():
	join_panel.hide(); host_panel.show(); _populate_level_selection()

func _show_join_panel():
	host_panel.hide(); join_panel.show(); _start_scanning()

func _hide_panels():
	host_panel.hide(); join_panel.hide()

## --- HOSTING & JOINING ---

func _host_game(level_path: String, level_name: String):
	var peer = ENetMultiplayerPeer.new()
	var success = false
	var try_port = BASE_PORT
	for i in range(10):
		if peer.create_server(try_port, 8) == OK:
			actual_hosted_port = try_port; success = true; break
		try_port += 1; peer = ENetMultiplayerPeer.new()
	
	if not success: return
	multiplayer.multiplayer_peer = peer
	main_menu_ui.hide(); load_level(level_path)
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_timer.set_meta("level_name", level_name)
	var s_name = server_name_input.text.strip_edges()
	broadcast_timer.set_meta("server_name", s_name if s_name != "" else "Unnamed Room")
	broadcast_timer.start()

func _broadcast_presence():
	var info = {"name": broadcast_timer.get_meta("server_name"), "port": actual_hosted_port, "level": broadcast_timer.get_meta("level_name"), "players": players_container.get_child_count()}
	udp_broadcaster.put_packet(JSON.stringify(info).to_utf8_buffer())

func _start_scanning():
	found_servers.clear()
	for child in server_list_container.get_children(): child.queue_free()
	udp_listener.close()
	udp_listener.bind(BROADCAST_PORT)
	scan_timer.start(scan_duration)

func _stop_scanning():
	udp_listener.close(); scan_timer.stop(); _hide_panels()

func _on_scan_timeout():
	if found_servers.is_empty(): retry_timer.start(scan_retry_delay)

func _listen_for_broadcasts():
	while udp_listener.get_available_packet_count() > 0:
		var packet = udp_listener.get_packet(); var ip = udp_listener.get_packet_ip()
		var json = JSON.parse_string(packet.get_string_from_utf8())
		if json and json.has("port"):
			var key = ip + ":" + str(json.port)
			if not found_servers.has(key):
				found_servers[key] = json
				_add_server_button(json.name, ip, json.port, json.level, json.players)

func _add_server_button(host_name, ip, port, level_name, player_count):
	var btn = Button.new()
	btn.text = "%s | %s | Players: %d" % [host_name, level_name, player_count]
	btn.custom_minimum_size = button_size
	btn.pressed.connect(_join_game.bind(ip, port))
	server_list_container.add_child(btn)

func _on_manual_join_pressed():
	_join_game(ip_input.text if ip_input.text != "" else "127.0.0.1", BASE_PORT)

func _join_game(ip, port):
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, int(port)) != OK: return
	_stop_scanning()
	multiplayer.multiplayer_peer = peer
	main_menu_ui.hide()

## --- GAMEPLAY SYNC ---

func _on_level_added(node):
	var player_path = "Universal Scene/UNIVERSAL LV Nodes/Player"
	if node.has_node(player_path): node.get_node(player_path).queue_free()

func load_level(path: String):
	if not multiplayer.is_server(): return
	for child in level_container.get_children(): child.queue_free()
	level_container.add_child(load(path).instantiate())
	if not players_container.has_node("1"): spawn_player(1)

func spawn_player(id):
	if not multiplayer.is_server(): return
	var p = preload("res://Multiplayer/MultiPLAYER_Scene.tscn").instantiate()
	p.name = str(id)
	players_container.add_child(p, true)
	_force_carrots_to_player(p)

func _force_carrots_to_player(player_node: Node2D):
	await get_tree().process_frame 
	for carrot in get_tree().get_nodes_in_group("Carrot"):
		if carrot.force_upgrade_collect_on_start and not carrot.has_meta("is_network_sync"):
			# Sender ID 0 indicates a server-forced event
			sync_carrot_collected.rpc(player_node.name, 0)

func _on_player_connected(id: int):
	if multiplayer.is_server():
		spawn_player(id)
		await get_tree().create_timer(1.0).timeout
		_sync_existing_carrots_to_new_player(id)

func _sync_existing_carrots_to_new_player(new_id: int):
	for p_node in players_container.get_children():
		var count = 0
		for carrot in get_tree().get_nodes_in_group("Carrot"):
			if carrot.target_node == p_node and carrot.is_following: count += 1
		if count > 0: sync_initial_carrots.rpc_id(new_id, p_node.name, count)

@rpc("authority", "call_remote", "reliable")
func sync_initial_carrots(player_name: String, count: int):
	var player_node = players_container.get_node_or_null(player_name)
	if not player_node: return
	for i in range(count): _spawn_network_carrot(player_node)

func _on_player_disconnected(id): if multiplayer.is_server() and players_container.has_node(str(id)): players_container.get_node(str(id)).queue_free()

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null; main_menu_ui.show()
	for child in level_container.get_children(): child.queue_free()
	for child in players_container.get_children(): child.queue_free()

# --- CARROT SYNC FUNCTIONS ---

func request_carrot_collection(player_name: String):
	if multiplayer.multiplayer_peer:
		sync_carrot_collected.rpc(player_name, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func sync_carrot_collected(player_name: String, sender_id: int):
	if sender_id != 0 and sender_id == multiplayer.get_unique_id(): return
	var player_node = players_container.get_node_or_null(player_name)
	if player_node: _spawn_network_carrot(player_node)

func _spawn_network_carrot(player_node: Node2D):
	var carrot_scene = load("res://Scenes + Scripts/General/Collectables/Carrot Upgrade.tscn")
	var new_carrot = carrot_scene.instantiate()
	new_carrot.set_meta("is_network_sync", true)
	new_carrot.target_node = player_node
	get_tree().current_scene.add_child(new_carrot)
	
	var last = player_node.get_meta("last_carrot") if player_node.has_meta("last_carrot") else null
	new_carrot.follow_target = last if is_instance_valid(last) else player_node
	player_node.set_meta("last_carrot", new_carrot)
	new_carrot.is_following = true
	new_carrot.add_dash_counter()

func request_carrot_removal(player_name: String):
	sync_carrot_removed.rpc(player_name)

@rpc("any_peer", "call_local", "reliable")
func sync_carrot_removed(player_name: String):
	var player_node = players_container.get_node_or_null(player_name)
	if player_node and player_node.has_meta("last_carrot"):
		var carrot = player_node.get_meta("last_carrot")
		if is_instance_valid(carrot):
			if multiplayer.get_remote_sender_id() != 0: carrot.set_meta("is_network_sync", true)
			carrot._on_carrot_remover_body_entered(player_node)
