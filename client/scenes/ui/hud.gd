class_name GameHUD
extends CanvasLayer

signal attack_pressed()
signal skill_1_pressed()
signal skill_2_pressed()
signal interact_pressed()
signal quest_accepted(quest_id: int)

@onready var hp_bar: ProgressBar = $TopLeft/VBox/HPBar
@onready var mp_bar: ProgressBar = $TopLeft/VBox/MPBar
@onready var player_name_lbl: Label = $TopLeft/VBox/NameLabel
@onready var joystick = $BottomLeft/VirtualJoystick
@onready var quest_title_lbl: Label = $TopRight/QuestPanel/VBox/QuestTitle
@onready var quest_obj_lbl: Label = $TopRight/QuestPanel/VBox/QuestObjectives

# Dialogue Window
@onready var dialogue_box: Control = $DialogueBox
@onready var npc_name_lbl: Label = $DialogueBox/Panel/NPCName
@onready var dialogue_text_lbl: Label = $DialogueBox/Panel/DialogueText
@onready var accept_btn: Button = $DialogueBox/Panel/AcceptButton

var active_quest_id: int = 80001
var quest_kills: int = 0
var quest_required_kills: int = 3
var quest_is_completed: bool = false

func _ready() -> void:
	$BottomRight/AttackButton.pressed.connect(func(): attack_pressed.emit())
	$BottomRight/Skill1Button.pressed.connect(func(): skill_1_pressed.emit())
	$BottomRight/Skill2Button.pressed.connect(func(): skill_2_pressed.emit())
	$BottomRight/InteractButton.pressed.connect(func(): interact_pressed.emit())
	accept_btn.pressed.connect(_on_dialogue_accept)
	$DialogueBox/Panel/CloseButton.pressed.connect(func(): dialogue_box.hide())
	dialogue_box.hide()
	update_quest_tracker()

func update_player_stats(hp: int, max_hp: int, mp: int, max_mp: int, pname: String, pclass: String) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	$TopLeft/VBox/HPBar/HPLbl.text = "%d / %d" % [hp, max_hp]
	mp_bar.max_value = max_mp
	mp_bar.value = mp
	$TopLeft/VBox/MPBar/MPLbl.text = "%d / %d" % [mp, max_mp]
	player_name_lbl.text = "Lv.1 %s [%s]" % [pname, pclass]

func show_dialogue(speaker: String, text: String, quest_id: int = 80001) -> void:
	npc_name_lbl.text = speaker
	dialogue_text_lbl.text = text
	active_quest_id = quest_id
	if quest_is_completed:
		accept_btn.text = "Complete Quest (+100 EXP)"
	elif quest_kills > 0:
		accept_btn.text = "Progress (%d/%d)" % [quest_kills, quest_required_kills]
	else:
		accept_btn.text = "Accept Quest"
	dialogue_box.show()

func _on_dialogue_accept() -> void:
	dialogue_box.hide()
	if not quest_is_completed and quest_kills >= quest_required_kills:
		quest_is_completed = true
		quest_title_lbl.text = "✔ Quest Completed!"
		quest_obj_lbl.text = "Return to Village Elder for rewards."
		spawn_floating_text(Vector2(640, 200), "QUEST COMPLETE! +100 EXP", Color.GOLD)
	else:
		quest_accepted.emit(active_quest_id)
		update_quest_tracker()

func add_monster_kill() -> void:
	quest_kills += 1
	update_quest_tracker()
	if quest_kills >= quest_required_kills:
		quest_is_completed = true
		quest_obj_lbl.text = "All beasts defeated! Talk to Elder (3/3)"
		spawn_floating_text(Vector2(640, 200), "Objective Complete! (3/3)", Color.GREEN)

func update_quest_tracker() -> void:
	quest_title_lbl.text = "Quest: Forest Threat"
	if quest_kills < quest_required_kills:
		quest_obj_lbl.text = "Defeat Forest Beasts: %d / %d" % [quest_kills, quest_required_kills]
	else:
		quest_obj_lbl.text = "✔ Ready to turn in! (3/3)"

func spawn_floating_text(screen_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = text
	label.position = screen_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.finished.connect(func(): label.queue_free())
