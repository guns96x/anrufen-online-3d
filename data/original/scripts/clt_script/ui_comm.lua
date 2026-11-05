--UI脚本公共功能
UI_EXAMPLE = {}
UI_EXAMPLE.Main = function( m )
		--测试用UI主函数
		m.m_MsgBox = object.New( object.MsgBox )
		m:AddChild( m.m_MsgBox )
		
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
				--[[
				if p1 == Key.AVK_0 then
					m.m_MsgBox:ShowDialog( "Hello lua", MsgBox.MODE_YESNO )	--YesNo
					local r = m.m_MsgBox:GetResult()
					if r == MsgBox.ECODE_YES then	--Yes
						m.m_MsgBox:ShowDialog( "Yes", MsgBox.MODE_OK )	--OkOnly
					else
						m.m_MsgBox:ShowDialog( "No", MsgBox.MODE_OK )	--OkOnly
						m:PostClose()
					end
					bHandle = 1
				end
				]]
			end
			
			if bHandle == 0 then
				m:DispatchEvt( e, p1, p2 )
			end
		end
		
		object.Del( m.m_MsgBox )
	end
