--商城脚本功能
UI_CASH_SHOP = {}
UI_CASH_SHOP.Main = function( m )
		--测试用UI主函数
		m.m_MsgBox = object.New( object.MsgBox )
		m.m_Package = object.New( object.Package )
		m:AddChild( m.m_MsgBox )
		m:AddChild( m.m_Package )
		
		while true do
			m:WaitEvt()
			local e, p1, p2 = m:GetEvt()
			local bHandle = 0
			if e == Evt.EVT_NONE then
				--窗体已经不存在了
				bHandle = 1
				break
			elseif e == Evt.EVT_CLOSE then
				--关闭事件
				bHandle = 1
				break
			elseif e == Evt.EVT_DRAW then
				--Draw
				bHandle = 1
			elseif e == Evt.EVT_KEY then
				--Key
				bHandle = 0
			elseif e == Evt.EVT_CMD then
				--执行购买操作时,查看背包中是否有代金券
				if p1 == CMD_CashShop.MENU_BUY then
					local item_count = item.GetItemCountByType(ItemType.ITEMTYPE_PROP, PropType.PROPTYPE_NORMAL, PropMiniType.PROP_MIN_TYPE_TOKEN)
					if item_count > 0 then
						m.m_Package:ShowDialog( Package.MODE_SELECT, ItemType.ITEMTYPE_PROP, PropType.PROPTYPE_NORMAL, PropMiniType.PROP_MIN_TYPE_TOKEN )
						local id, idEx = m.m_Package:GetResult()
						m.id = id
						m.idEx = idEx
						m:Commit()
						m:DispatchEvt( e, p1, p2 )
						bHandle = 1
					end
				end
			end
			
			if bHandle == 0 then
				m:DispatchEvt( e, p1, p2 )
			end
		end
		
		object.Del( m.m_MsgBox )
		object.Del( m.m_Package )
	end
