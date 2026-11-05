class_name NPC
extends CharacterBody3D

@export var npc_name: String = "Mayor of Guanlin (观林镇镇长)"
@export var dialogue_text: String = "Ласкаво просимо до Ґуаньліня! Допоможи містечку та торговцям налагодити порядок. (欢迎来到观林镇！)"
@export var quest_id: int = 80001
@export var citizen_id: int = 50164
@export var tint: Color = Color(1, 1, 1, 1)

@onready var prompt_label: Label3D = $PromptLabel
@onready var interaction_area: Area3D = $InteractionArea
@onready var visual_root: Node3D = $Visual

var player_in_range: Node3D = null
var quest_marker: Label3D
var _idle_time: float = 0.0

func _ready() -> void:
	$NameLabel.text = npc_name
	prompt_label.text = "[ Talk / Розмова ]"
	prompt_label.hide()
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	_idle_time = randf() * TAU

	quest_marker = Label3D.new()
	quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quest_marker.font_size = 64
	quest_marker.pixel_size = 0.012
	quest_marker.outline_size = 12
	quest_marker.position = Vector3(0, 2.9, 0)
	quest_marker.modulate = Color(1, 0.85, 0.15)
	quest_marker.no_depth_test = true
	add_child(quest_marker)

func _process(delta: float) -> void:
	_idle_time += delta
	# Gentle idle breathing so the town feels alive
	visual_root.scale = Vector3(1.0, 1.0 + sin(_idle_time * 2.0) * 0.015, 1.0)
	quest_marker.position.y = 2.9 + sin(_idle_time * 3.0) * 0.08

	var hud: Node = get_tree().get_first_node_in_group("hud")
	var marker: String = ""
	if hud:
		if hud.has_method("get_npc_marker"):
			marker = hud.get_npc_marker(self)
		elif hud.has_method("get_quest_state") and GameHUD.QUESTS.has(quest_id):
			match hud.get_quest_state(quest_id):
				GameHUD.QuestState.NONE:
					marker = "!"
				GameHUD.QuestState.READY:
					marker = "?"
	quest_marker.text = marker

	# Face the player while they are close
	if player_in_range and is_instance_valid(player_in_range):
		var to_p: Vector3 = player_in_range.global_position - global_position
		to_p.y = 0.0
		if to_p.length() > 0.1:
			var target_yaw: float = atan2(-to_p.x, -to_p.z) - rotation.y
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 4.0 * delta)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body.get("is_local_player") == true:
		player_in_range = body
		body.set("nearby_npc", self)
		prompt_label.show()

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		if body.get("nearby_npc") == self:
			body.set("nearby_npc", null)
		player_in_range = null
		prompt_label.hide()

func interact(hud: Node) -> void:
	if hud:
		if hud.has_method("show_dialogue_npc"):
			hud.show_dialogue_npc(self)
		elif hud.has_method("show_dialogue"):
			hud.show_dialogue(npc_name, dialogue_text, quest_id)

## Configuration API for Codex world or procedural spawners to set authentic Anrufen NPC data.
func configure_npc(p_name: String, p_dialogue: String, p_quest_id: int = 0, p_citizen_id: int = 0) -> void:
	npc_name = p_name
	dialogue_text = p_dialogue
	quest_id = p_quest_id
	if p_citizen_id > 0:
		citizen_id = p_citizen_id
	if is_inside_tree() and has_node("NameLabel"):
		$NameLabel.text = npc_name
