class_name PetDevelopment
extends RefCounted

## Source semantics: fixed innate, talent foods, contracts, donor consumption,
## transformation failure -1 and protection. Fees/chances/growth/limits below
## are explicitly modern tuning, not recovered original server formulas.
const CAPACITY_LIMIT: int = 24
const MAX_FORM: int = 7
const TALENT_LIMIT: int = 10000
const TALENTS: Array[String] = ["physical_attack","magic_attack","hp","mp","defense","resistance","accuracy","evasion"]
const TRANSFORM_BOOSTS: Array[int] = [30164,30694,30730,30253]
const TRANSFORM_PROTECTION: Array[int] = [30731,30696]
const TACTICS: Dictionary = {"attack_owner_target":"Атакувати мою ціль","retaliate_owner_attacker":"Захищати мене","support_only":"Лише підтримка","free_attack_visible_enemy":"Самостійно атакувати","standby_follow":"Слідувати без бою"}

static func ensure_pet(pet: Dictionary) -> void:
	if not InventorySystem._integer(pet.get("species_id"),140000,149999): return
	CompanionSystem.ensure_mana(pet)
	var defaults: Dictionary = {"form_rank":0,"innate_skill_id":SourcePetCatalog.innate(int(pet["species_id"])),"talents":{},"tactic":"attack_owner_target","growth_base_hp":pet.get("max_hp",60),"growth_base_mp":pet.get("max_mp",40)}
	for key: String in defaults:
		if not pet.has(key): pet[key] = defaults[key]

static func validate(pet: Dictionary) -> bool:
	if not InventorySystem._integer(pet.get("species_id"),140000,149999) or SourcePetCatalog.species(int(pet["species_id"])).is_empty(): return false
	if not InventorySystem._integer(pet.get("form_rank",0),0,MAX_FORM): return false
	if not InventorySystem._integer(pet.get("innate_skill_id",0),0,999999): return false
	if pet.has("innate_skill_id") and int(pet["innate_skill_id"]) != SourcePetCatalog.innate(int(pet.get("species_id",0))): return false
	if pet.get("tactic","attack_owner_target") not in TACTICS or not pet.get("talents",{}) is Dictionary: return false
	for key: Variant in pet.get("talents",{}):
		if not key is String or key not in TALENTS or not InventorySystem._integer(pet["talents"][key],0,TALENT_LIMIT): return false
	for key: String in ["growth_base_hp","growth_base_mp"]:
		if pet.has(key) and not InventorySystem._integer(pet[key],1,1000000): return false
	return true

static func _find(stats: Dictionary, uid: String) -> Dictionary:
	for pet: Variant in stats.get("companions",[]):
		if pet is Dictionary and pet.get("uid") == uid: return pet
	return {}

static func _owns(stats: Dictionary, id: int) -> bool:
	if not stats.get("inventory") is Dictionary: return false
	return id not in stats.get("locked_items",[]) and id not in stats.get("quest_item_locks",[]) and InventorySystem._integer(stats["inventory"].get(str(id)),1,99999)

static func _consume(stats: Dictionary, id: int) -> void:
	var key: String = str(id)
	stats["inventory"][key] = int(stats["inventory"][key])-1
	if int(stats["inventory"][key]) == 0: stats["inventory"].erase(key)

static func rebuild(pet: Dictionary) -> void:
	ensure_pet(pet)
	var factor: float = 1.0+float(pet["form_rank"])*0.1
	var talents: Dictionary = pet["talents"]
	pet["max_hp"] = clampi(roundi((float(pet["growth_base_hp"])+float(talents.get("hp",0))/10.0)*factor),1,1000000)
	pet["max_mp"] = clampi(roundi((float(pet["growth_base_mp"])+float(talents.get("mp",0))/10.0)*factor),1,1000000)
	pet["hp"] = mini(int(pet["hp"]),int(pet["max_hp"]))
	pet["mp"] = mini(int(pet["mp"]),int(pet["max_mp"]))

static func level_up(pet: Dictionary) -> void:
	ensure_pet(pet)
	pet["growth_base_hp"] = mini(1000000,int(pet["growth_base_hp"])+10)
	pet["growth_base_mp"] = mini(1000000,int(pet["growth_base_mp"])+4)
	rebuild(pet)
	pet["hp"] = pet["max_hp"]
	pet["mp"] = pet["max_mp"]

static func feed_talent(stats: Dictionary, uid: String, item_id: int) -> bool:
	var pet: Dictionary = _find(stats,uid)
	var addition: Dictionary = SourcePetCatalog.consumable(item_id).get("talent_increment",{})
	if pet.is_empty() or int(pet.get("hp",0)) <= 0 or addition.is_empty() or not _owns(stats,item_id) or not validate(pet): return false
	var key: String = str(addition.get("stat",""))
	var amount: int = int(addition.get("amount",0))
	if key not in TALENTS or amount < 1 or int(pet.get("talents",{}).get(key,0))+amount > TALENT_LIMIT: return false
	var copy: Dictionary = pet.duplicate(true)
	ensure_pet(copy)
	copy["talents"][key] = int(copy["talents"].get(key,0))+amount
	rebuild(copy)
	_consume(stats,item_id)
	pet.merge(copy,true)
	return true

static func change_tactic(stats: Dictionary, uid: String, tactic: String) -> bool:
	var pet: Dictionary = _find(stats,uid)
	if pet.is_empty() or tactic not in TACTICS or pet.get("tactic","attack_owner_target") == tactic: return false
	pet["tactic"] = tactic
	return true

static func transform(stats: Dictionary, primary_uid: String, donor_uid: String, boost: int = 0, protection: int = 0, roll: float = 0.5) -> Dictionary:
	var failure: Dictionary = {"ok":false,"error":"Потрібні два різні здорові звірі у відпочинку, 100 міді та придатні матеріали."}
	var primary: Dictionary = _find(stats,primary_uid)
	var donor: Dictionary = _find(stats,donor_uid)
	if primary_uid == donor_uid or primary.is_empty() or donor.is_empty() or not validate(primary) or not validate(donor): return failure
	if not is_finite(roll) or roll < 0 or roll >= 1 or not InventorySystem._integer(stats.get("copper"),100,1000000000): return failure
	if primary_uid == stats.get("summoned_pet","") or donor_uid == stats.get("summoned_pet","") or int(primary.get("hp",0)) <= 0 or int(donor.get("hp",0)) <= 0: return failure
	var rank: int = int(primary.get("form_rank",0))
	if rank >= MAX_FORM: return {"ok":false,"error":"Досягнуто останньої форми."}
	if (boost != 0 and (boost not in TRANSFORM_BOOSTS or not _owns(stats,boost))) or (protection != 0 and (protection not in TRANSFORM_PROTECTION or not _owns(stats,protection))): return failure
	# Modern choice for source '三以下': guarantee applies at ranks0..2.
	if boost == 30253 and rank >= 3: return {"ok":false,"error":"Цей предмет діє лише до третьої форми."}
	var chance: float = maxf(0.2,0.8-float(rank)*0.08)
	if boost in [30164,30694]: chance = minf(1.0,chance+0.15)
	if boost == 30730: chance = minf(1.0,chance+0.3)
	if boost == 30253: chance = 1.0
	var success: bool = roll < chance
	var updated: Dictionary = primary.duplicate(true)
	ensure_pet(updated)
	updated["form_rank"] = rank+1 if success else rank if protection != 0 else maxi(0,rank-1)
	rebuild(updated)
	# Validation ends here. Secondary disappears on BOTH success and failure.
	if boost != 0: _consume(stats,boost)
	if protection != 0: _consume(stats,protection)
	stats["copper"] = int(stats["copper"])-100
	primary.merge(updated,true)
	stats["companions"].erase(donor)
	return {"ok":true,"success":success,"rank":int(updated["form_rank"]),"message":("Перетворення вдалося! Форма %d." % updated["form_rank"]) if success else "Перетворення не вдалося. Донор використаний; "+("форму збережено." if protection != 0 or rank == 0 else "форма знизилася на один рівень.")}
