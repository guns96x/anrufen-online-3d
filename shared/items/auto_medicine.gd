class_name AutoMedicine
extends RefCounted

## Ordered IDs and strict comparison are from clt_script/item.lua UseItemAuto.
const PRIORITIES: Dictionary = {
	"player_hp":[30114,30842,30174,30193],"player_mp":[30162,30843,30189,30194],
	"pet_hp":[30020,30021,30485,31130,31131,30729],"pet_mp":[30754,30755,30756,30757,30758,30778],
}
const OPTIONS: Dictionary = {
	"player_hp":["auto_potion","potion_threshold"],"player_mp":["auto_mp","mp_potion_threshold"],
	"pet_hp":["auto_pet_hp","pet_hp_potion_threshold"],"pet_mp":["auto_pet_mp","pet_mp_potion_threshold"],
}

static func intents(stats: Dictionary, options: Dictionary, now: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not InventorySystem._integer(stats.get("hp"),1,1000000000) or not stats.get("inventory") is Dictionary: return result
	for key: String in PRIORITIES:
		var names: Array = OPTIONS[key]
		var threshold: Variant = options.get(names[1],0)
		if options.get(names[0],false) != true or (not threshold is int and not threshold is float): continue
		if not is_finite(float(threshold)) or float(threshold) <= 0 or float(threshold) > 1 or not MedicineState.available(stats,key,now): continue
		var target: Dictionary = stats
		var uid: String = ""
		if key.begins_with("pet_"):
			if not stats.get("summoned_pet") is String or stats["summoned_pet"].is_empty() or not stats.get("companions") is Array: continue
			uid = stats["summoned_pet"]
			target = {}
			for pet: Variant in stats["companions"]:
				if pet is Dictionary and pet.get("uid") == uid: target = pet; break
			if not InventorySystem._integer(target.get("hp"),1,1000000): continue
		var field: String = "hp" if key.ends_with("hp") else "mp"
		if not InventorySystem._integer(target.get(field),0,1000000000) or not InventorySystem._integer(target.get("max_"+field),1,1000000000): continue
		if float(target[field])/float(target["max_"+field]) >= float(threshold): continue
		for id: int in PRIORITIES[key]:
			if id in stats.get("locked_items",[]) or id in stats.get("quest_item_locks",[]): continue
			if int(stats["inventory"].get(str(id),0)) < 1: continue
			if MedicineState.group(ItemCatalog.get_item(id).get("effect",{})) != key: continue
			result.append({"action":"use" if uid.is_empty() else "pet_medicate","payload":{"id":id} if uid.is_empty() else {"id":id,"uid":uid},"group":key})
			break
	return result
