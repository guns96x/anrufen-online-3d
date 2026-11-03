class_name NPC
extends CharacterBody3D

@export var npc_name: String = "Village Elder (观林镇长)"
@export var dialogue_text: String = "Greetings, brave traveler! Welcome to Guanlin Town. The forest outskirts have been attacked by wild beasts. Slay 3 Forest Beasts to protect our village and prove your worth!"
@export var quest_id: int = 80001

@onready var prompt_label: Label3D = $PromptLabel
@onready var interaction_area: Area3D = $InteractionArea

var player_in_range: Node3D = null

func _ready() -> void:
	$NameLabel.text = npc_name
	prompt_label.hide()
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body.get("is_local_player") == true:
		player_in_range = body
		body.set("nearby_npc", self)
		prompt_label.show()

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		body.set("nearby_npc", null)
		player_in_range = null
		prompt_label.hide()

func interact(hud: Node) -> void:
	if hud and hud.has_method("show_dialogue"):
		hud.show_dialogue(npc_name, dialogue_text, quest_id)
