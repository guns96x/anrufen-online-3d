
function Frame()

	--自动加血	
	local tagAutoHp = server.GetOperaTag(FrameSetting.AUTO_HP)
	if tagAutoHp == 1 then
		UseItemAuto( USE_ITEM_TYPE.USE_HP, server.GetSetting( FrameSetting.AUTO_HP ) )
	end

	--自动加魔	
	local tagAutoMp = server.GetOperaTag(FrameSetting.AUTO_MP)
	if tagAutoMp == 1 then
		UseItemAuto( USE_ITEM_TYPE.USE_MP, server.GetSetting( FrameSetting.AUTO_MP ) )
	end
	
	--宠物自动回血
	local tagAutoPetHp = server.GetOperaTag(FrameSetting.AUTO_PET_HP)
	if tagAutoPetHp == 1 then
		UseItemAuto( USE_ITEM_TYPE.USE_PET_HP, server.GetSetting( FrameSetting.AUTO_PET_HP ) )
	end
	
	--宠物自动回蓝
	local tagAutoPetMp = server.GetOperaTag(FrameSetting.AUTO_PET_MP)
	if tagAutoMp == 1 then
		UseItemAuto( USE_ITEM_TYPE.USE_PET_MP, server.GetSetting( FrameSetting.AUTO_PET_MP ) )
	end
	
	return 0
end