PLUGIN = nil

function Initialize(Plugin)
	Plugin:SetName("AutoSave")
	Plugin:SetVersion(1)
	
	-- Defaults Values
	ClientsConnected = 0
	TicksChecks = 0
	LastSaveTime = os.time()
	PluginInfo = {["name"] = Plugin:GetName(), ["version"] = Plugin:GetVersion(),}
	LoadMessages()
	LoadParameters()
	
	-- Hooks and Bindings Commands
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_JOINED, OnJoin)
	cPluginManager:AddHook(cPluginManager.HOOK_DISCONNECT, OnQuit)
	cPluginManager:AddHook(cPluginManager.HOOK_TICK, TickServSave)
	cPluginManager:BindCommand("/autosave", "autos", OnCommand, " - Plugin " .. PluginInfo["name"] .. " commands")
	
	-- Get the number of players connected (in the case of loading the plugins after server initialisation)
	cRoot:Get():ForEachPlayer(OnJoin)
	
	LOG("Plugin " .. PluginInfo["name"] .. " by Xenoxis - Version " .. PluginInfo["version"] .. " initialised !")
	return true
end





function LoadMessages()
	Message = {
		["prefix"]				= "[" .. PluginInfo["name"] .. "] ",
		["playerconnected"]		= "At least one player connected, enabling auto saving.",
		["playerdisconnected"]	= "No more players connected - Disabling auto saving.",
		["allworldssaved"]		= "All worlds have been saved.",
		["savecompleted"]		= "Save successfully completed.",
		["uncorrectsyntax"] 	= "Use the correct syntax : /autosave <version | timestamp>",
		["notpermission"]	 	= "You have not the permission to do this.",
		["currenttimestamp"]	= "Current Timestamp : ",
		["timestampchanged"]	= "Timestamp successfully changed.",
		["currentbroadcast"]	= "Current Broadcast : ",
		["broadcastchanged"]	= "Broadcast successfully changed.",
		["notvalidnumber"]		= "is not a valid number.",
		["WriteToIniFileError"] = "Error when writings defaults parameters to \"AutoSaveParameters.ini\", is open elsewhere ?"
	}
end


function LoadParameters()
	local FileParams = cIniFile()
	if (FileParams:ReadFile("AutoSaveParameters.ini")) then
		DefaultSaveTime 			= FileParams:GetValueSetI("General", "Timestamp", 120)
		MinimalBroadcastToPlayer 	= FileParams:GetValueSetI("General", "MinimalBroadcastToPlayer", 1)
	else
		FileParams:AddKeyName("General")
		FileParams:AddValueI("General", "Timestamp", 120)
		FileParams:AddValueI("General", "MinimalBroadcastToPlayer", 1)
		if (not FileParams:WriteFile("AutoSaveParameters.ini")) then
			LOG(Message["prefix"] .. Message["WriteToIniFileError"])
		end
	end
end


function SaveParameters()
	local FileParams = cIniFile()
	
	FileParams:SetValueI("General", "Timestamp", DefaultSaveTime, true)
	FileParams:SetValueI("General", "MinimalBroadcastToPlayer", MinimalBroadcastToPlayer, true)
	
	if (not FileParams:WriteFile("AutoSaveParameters.ini")) then
		LOG(Message["prefix"] .. Message["WriteToIniFileError"])
	end
end



function OnJoin()
	ClientsConnected = ClientsConnected + 1
	if (ClientsConnected == 1) then
		LOG(Message["prefix"] .. Message["playerconnected"])
		LastSaveTime = os.time()
	end
end



function OnQuit(Plugin)
	ClientsConnected = (ClientsConnected > 0) and (ClientsConnected - 1) or 0
	
	if (ClientsConnected == 0) then
		LOG(Message["prefix"] .. Message["playerdisconnected"])
	end
end



function TickServSave(Plugin)
	TicksChecks = TicksChecks + 1
	if (TicksChecks < 20 or ClientsConnected < 1) then
		if (TicksChecks > 20) then TicksChecks = 0 end
		return
	end
	
	TicksChecks = 0
	if (os.difftime(os.time(), LastSaveTime) >= DefaultSaveTime) then
		cRoot:Get():ForEachWorld(function(cWorld)
			cWorld:QueueSaveAllChunks()
			if not(MinimalBroadcastToPlayer) then cRoot:Get():BroadcastChatInfo("[" .. PluginInfo["name"] .. "] \"" .. cWorld:GetName() .. "\" saved !") end
		end)
		cRoot:Get():BroadcastChatSuccess(Message["prefix"] .. Message["allworldssaved"])
		LOG(Message["prefix"] .. Message["savecompleted"])
		LastSaveTime = os.time()
	end
end



function OnCommand(CommandSplit, CurrentPlayer)
	
	local SecondParameter = {
		-- /autosave version
		["version"] = function() CurrentPlayer:SendMessageInfo("Plugin " .. PluginInfo["name"] .. " - Version " .. PluginInfo["version"] .. " by Xenoxis") end,
		
		-- /autosave timestamp <value in seconds>
		["timestamp"] = function()
			if (CommandSplit[3] == nil) then
				CurrentPlayer:SendMessageSuccess(Message["prefix"] .. Message["currenttimestamp"] .. DefaultSaveTime)
				return true
			elseif not(tonumber(CommandSplit[3])) then
				CurrentPlayer:SendMessageFailure(Message["prefix"] .. "\"" .. CommandSplit[3] .. "\"" .. Message["notvalidnumber"])
				return true
			end
			DefaultSaveTime = tonumber(CommandSplit[3])
			if (DefaultSaveTime < -1) then DefaultSaveTime = -1 end
			LastSaveTime = os.time()
			SaveParameters()
			CurrentPlayer:SendMessageSuccess(Message["prefix"] .. Message["timestampchanged"])
			LOG(Message["prefix"] .. "Timestamp changed, new value : " .. DefaultSaveTime)
		end,
		
		-- /autosave broadcast < normal | minimal>
		["broadcast"] = function()
			local success = false
			
			if (CommandSplit[3] == nil) then
				CurrentPlayer:SendMessageSuccess(Message["prefix"] .. Message["currentbroadcast"] .. (MinimalBroadcastToPlayer) and "Minimal" or "Normal")
				return true
			end
			
			if (CommandSplit[3]:lower() == "normal") then
				MinimalBroadcastToPlayer = 0
				success = true
			else if (CommandSplit[3]:lower() == "minimal") then
				MinimalBroadcastToPlayer = 1
				success = true
				end
			end
			
			if (success) then
				CurrentPlayer:SendMessageSuccess(Message["prefix"] .. Message["broadcastchanged"])
				SaveParameters()
				LOG(Message["prefix"] .. "Broadcast changed, new value : " .. (MinimalBroadcastToPlayer) and "Minimal" or "Normal")
			else
				CurrentPlayer:SendMessageFailure(Message["prefix"] .. " Unknown value entered, use /autosave broadcast <normal | minimal>")
			end
		end
	}
	
	for command in pairs(SecondParameter) do
		if (command == CommandSplit[2]:lower()) then
			if (CurrentPlayer:HasPermission("autos." .. command)) then
				SecondParameter[command]()
				return true
			else
				CurrentPlayer:SendMessageFailure(Message["prefix"] .. Message["notpermission"])
			end
		end
	end
	
	CurrentPlayer:SendMessageInfo(Message["prefix"] .. Message["uncorrectsyntax"])
	return true
end

