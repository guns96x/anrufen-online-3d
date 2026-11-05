
----使用物品类型----
USE_ITEM_TYPE = {
	USE_HP = 1,
	USE_MP = 2,
	USE_PET_HP = 3,
	USE_PET_MP = 4
}
--------------------

-------自动回血血瓶SN------
ITEM_HP_SN = {
	30114,
	30842,
	30174,
	30193
}
-------------------

-------自动回魔魔瓶SN------
ITEM_MP_SN = {
	30162,
	30843,
	30189,
	30194
}
-------------------

-------魔法兽自动回血血瓶SN------
ITEM_PET_HP_SN = {
	30020,
	30021,
	30485,
	31130,
	31131,
	30729
}
-------------------

-------魔法兽自动回魔魔瓶SN------
ITEM_PET_MP_SN = {
	30754,
	30755,
	30756,
	30757,
	30758,
	30778
}
-------------------

--返回玩家身上自动回血血瓶数量
function GetAutoHpItemCount()
	return item.GetItemCount(ITEM_HP_SN[1],ITEM_HP_SN[2],ITEM_HP_SN[3],ITEM_HP_SN[4])
end

--返回玩家身上自动回魔魔瓶数量
function GetAutoMpItemCount()
	return item.GetItemCount(ITEM_MP_SN[1],ITEM_MP_SN[2],ITEM_MP_SN[3],ITEM_MP_SN[4])
end


--返回玩家身上魔法兽自动回血血瓶数量
function GetAutoPetHpItemCount()
	return item.GetItemCount(ITEM_PET_HP_SN[1],ITEM_PET_HP_SN[2],ITEM_PET_HP_SN[3],ITEM_PET_HP_SN[4],ITEM_PET_HP_SN[5],ITEM_PET_HP_SN[6])
end

--返回玩家身上魔法兽自动回魔魔瓶数量
function GetAutoPetMpItemCount()
	return item.GetItemCount(ITEM_PET_MP_SN[1],ITEM_PET_MP_SN[2],ITEM_PET_MP_SN[3],ITEM_PET_MP_SN[4],ITEM_PET_MP_SN[5],ITEM_PET_MP_SN[6])
end

function UseItem( nSN )
	item.UseItem( nSN )
end

function UsePetItem( nSN )
	item.UsePetItem( nSN )
end

function UseItemAuto( nType, tArg )
	
	--自动使用血瓶
	if nType == USE_ITEM_TYPE.USE_HP then
		
		--回血百分比均0
		if tArg[1] < 1 then
			return
		end
					 
		--少于此百分比回血
		local nHp, nHpMax = server.GetPlayerInt( PROP_HPVALUE, HP_MAX )
		--local nHp, nHpMax = server.GetPlayerInt( 1, 30 )
		
		--玩家已死亡
		if nHp < 1 then
			return
		end
		
		local nPer = nHp * 100 / nHpMax
		if nPer < tArg[1] then			
			for i, v in ipairs(ITEM_HP_SN) do
				if item.GetItemCount(v) > 0 then
					local nCD = item.GetMedicCD( v )
					if nCD <= 0 then 
						local bUse = UseItem(v)
						if bUse == 1 then
							server.SetOperaTag( FrameSetting.AUTO_HP, 0 )
						end
						break
					end
				end
			end
		end
		
	end
	
	--自动使用魔瓶
	if nType == USE_ITEM_TYPE.USE_MP then
		
		--回魔百分比为0
		if tArg[1] < 1 then
			return
		end
			
		--少于此百分比回魔
		local nHp, nMp, nMpMax = server.GetPlayerInt( PROP_HPVALUE, PROP_MPVALUE, MP_MAX )
		
		--玩家已死亡
		if nHp < 1 then
			return
		end
		
		local nPer = nMp * 100 / nMpMax
		if nPer < tArg[1] then
			for i, v in ipairs(ITEM_MP_SN) do
				if item.GetItemCount(v) > 0 then
					local nCD = item.GetMedicCD( v )
					if nCD <= 0 then 
						local bUse = UseItem(v)
						if bUse == 1 then
							server.SetOperaTag( FrameSetting.AUTO_MP, 0 )
						end
						break
					end
				end
			end
		end
		
	end
	
	--宠物自动使用血瓶
	if nType == USE_ITEM_TYPE.USE_PET_HP then
		
		--回血百分比均0
		if tArg[1] < 1 then
			return
		end
					 
		--少于此百分比回血
		local nHp, nHpMax = server.GetCallPetInt( PROP_HPVALUE, HP_MAX )
		
		--未召唤宠物或已死亡
		if nHp == nil or nHpMax == nil or nHp < 1 then
			return
		end
		
		local nPer = nHp * 100 / nHpMax
		if nPer < tArg[1] then			
			for i, v in ipairs(ITEM_PET_HP_SN) do
				if item.GetItemCount(v) > 0 then
					local nCD = item.GetMedicCD( v )
					if nCD <= 0 then 
						local bUse = UseItem(v)
						if bUse == 1 then
							server.SetOperaTag( FrameSetting.AUTO_PET_HP, 0 )
						end
						break
					end
				end
			end
		end
		
	end
	
	--宠物自动使用蓝瓶
	if nType == USE_ITEM_TYPE.USE_PET_MP then
		
		--回魔百分比为0
		if tArg[1] < 1 then
			return
		end
			
		--少于此百分比回魔
		local nHp, nMp, nMpMax = server.GetCallPetInt( PROP_HPVALUE, PROP_MPVALUE, MP_MAX )
		
		--未召唤宠物或已死亡
		if nHp == nil or nMp == nil or nMpMax == nil or nHp < 1 then
			return
		end
		
		local nPer = nMp * 100 / nMpMax
		if nPer < tArg[1] then
			for i, v in ipairs(ITEM_PET_MP_SN) do
				if item.GetItemCount(v) > 0 then
					local nCD = item.GetMedicCD( v )
					if nCD <= 0 then 
						local bUse = UseItem(v)
						if bUse == 1 then
							server.SetOperaTag( FrameSetting.AUTO_PET_MP, 0 )
						end
						break
					end
				end
			end
		end
		
	end
	
end