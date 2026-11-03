class_name GuanlinTown
extends Node3D

@onready var hud = $HUD
@onready var local_player = $Player
@onready var elder_npc = $NPC_Elder

func _ready() -> void:
	# Add HUD to group so floating damage numbers and quest kills can access it
	hud.add_to_group("hud")
	
	# Wire HUD controls to player
	hud.joystick.joystick_updated.connect(local_player.set_move_vector)
	hud.attack_pressed.connect(local_player.perform_attack)
	hud.skill_1_pressed.connect(local_player.perform_skill_1)
	hud.skill_2_pressed.connect(local_player.perform_skill_2)
	hud.interact_pressed.connect(_on_interact)
	
	# Initial stats update
	_update_hud_stats()
	print("[GuanlinTown] 3D World initialized. Ready for player!")

func _unhandled_input(event: InputEvent) -> void:
	# PC Keyboard shortcuts for testing
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_on_interact()
		elif event.keycode == KEY_SPACE:
			local_player.perform_attack()
		elif event.keycode == KEY_1:
			local_player.perform_skill_1()
		elif event.keycode == KEY_SHIFT:
			local_player.perform_skill_2()

func _on_interact() -> void:
	if local_player.nearby_npc:
		local_player.nearby_npc.interact(hud)
	else:
		# If close to elder anyway, talk
		var dist = local_player.global_position.distance_to(elder_npc.global_position)
		if dist < 4.0:
			elder_npc.interact(hud)

func _process(_delta: float) -> void:
	_update_hud_stats()

func _update_hud_stats() -> void:
	if local_player and hud:
		var st = local_player.stats
		hud.update_player_stats(
			st.get("hp", 100),
			st.get("max_hp", 100),
			st.get("mp", 50),
			st.get("max_mp", 50),
			st.get("name", "Hero"),
			st.get("class_name", "见习战士")
		)
