--客户端与服务器共享的一些计算公式

function GetHorseFinalLv( sn,nLv )
	--通过坐骑亲密度获取坐骑等级
	--nLv坐骑亲密度
	--返回值：坐骑实际等级
	if nLv<HORSE_DATA[2] then                  --200以内
		return 1
	elseif  nLv<HORSE_DATA[3] then		   --200-600以内
		return 2
	elseif  nLv<HORSE_DATA[4] then		   --600－1500以内
		return 3 
	elseif  nLv<HORSE_DATA[5] then		   --1500-3000以内
		return 4
	elseif  nLv<HORSE_DATA[6] then		   --3000-10000以内
		return 5
	else
		return 6
	
	end
	
	return 0
end
