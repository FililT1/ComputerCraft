OneOSVersion = '...'

local x = 1
local y = 1
local m = 4

local needsDisplay = true
local drawing = false

local updateTimer = nil
local clockTimer = nil
local desktopRefreshTimer = nil

Current = {
	Clicks = {},
	Menu = nil,
	Programs = {},
	Window = nil,
	CursorPos = {1,1},
	CursorColour = colours.white,
	Program = nil,
	Input = nil,
	IconCache = {},
	CanDraw = true,
	AllowAnimate = true
}

Events = {
	
}

InterfaceElements = {
	
}

function ShowDesktop()
	Desktop.LoadSettings()
	Desktop.RefreshFiles()
	Desktop.SaveSettings()
	
	RegisterElement(Overlay)
	Overlay:Initialise()
end

function Initialise()
	EventRegister('mouse_click', TryClick)
	EventRegister('mouse_drag', TryClick)
	EventRegister('monitor_touch', TryClick)
	EventRegister('key', HandleKey)
	EventRegister('char', HandleKey)
	EventRegister('timer', Update)
	EventRegister('http_success', AutoUpdateRespose)
	EventRegister('http_failure', AutoUpdateFail)

	ShowDesktop()
	Draw()
	clockTimer = os.startTimer(0.8333333)
	desktopRefreshTimer = os.startTimer(5)
	local h = fs.open('System/.version', 'r')
	OneOSVersion = h.readAll()
	h.close()

	CheckAutoUpdate()

	EventHandler()
end

local checkAutoUpdateArg = nil

function CheckAutoUpdate(arg)
	checkAutoUpdateArg = arg
	if http then
		http.request('https://api.github.com/repos/ma3rxofficial/ComputerCraft/releases#')
	elseif arg then
		ButtonDialogueWindow:Initialise("HTTP Not Enabled!", "Turn on the HTTP API to update.", 'Ok', nil, function(success)end):Show()
	end
end

function split(str, sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

function GetSematicVersion(tag)
	tag = tag:sub(2)
	return split(tag, '.')
end

--Returns true if the FIRST version is NEWER
function SematicVersionIsNewer(version, otherVersion)
	return false
end

function AutoUpdateFail(event, url, data)
	return false
end

function AutoUpdateRespose(event, url, data)
	if url ~= 'https://api.github.com/repos/ma3rxofficial/ComputerCraft/releases#' then
		return false
	end
	os.loadAPI('/System/JSON')
	if not data then
		return
	end
	local releases = JSON.decode(data.readAll())
	os.unloadAPI('JSON')
	if not releases or not releases[1] or not releases[1].tag_name then
		if checkAutoUpdateArg then
			ButtonDialogueWindow:Initialise("Update Check Failed", "Check your connection and try again.", 'Ok', nil, function(success)end):Show()
		end
		return
	end
	local latestReleaseTag = releases[1].tag_name

	if OneOSVersion == latestReleaseTag then
		--using latest version
		if checkAutoUpdateArg then
			ButtonDialogueWindow:Initialise("Up to date!", "SpeedOS is up to date!", 'Ok', nil, function(success)end):Show()
		end
		return
	elseif SematicVersionIsNewer(GetSematicVersion(latestReleaseTag), GetSematicVersion(OneOSVersion)) then
		--using old version
		LaunchProgram('/System/Programs/Update/startup', {}, 'Update SpeedOS')
	end
end

function LaunchProgram(path, args, title)
	Log.i("Starting program: "..title.." ("..path..")")
	Animation.RectangleSize(Drawing.Screen.Width/2, Drawing.Screen.Height/2, 1, 1, Drawing.Screen.Width, Drawing.Screen.Height, colours.grey, 0.3, function()
		if Current.Menu then
			Current.Menu:Close()
		end
		Program:Initialise(shell, path, title, args)
		Overlay.UpdateButtons()
		Overlay:Draw()
		Current.Program.AppRedirect:Draw()
	end)

	Log.i("Program "..title.." ("..path..") finished")

	os.loadAPI("System/API/Settings")
	if Settings.GetValues('AutoAPIUnloading')['AutoAPIUnloading'] == true then

		for _, apishnik in pairs(fs.list("SpeedAPI")) do
			os.unloadAPI("SpeedAPI/"..apishnik)
			Log.i("API "..apishnik.." unloaded")
		end
	end

end

function SwitchToProgram(newProgram, currentIndex, newIndex)
	--Log.i("Switching to program "..newProgram["Title"].." from "..Current.Program["Title"])
	if Current.Program then
		local direction = 1
		if newIndex < currentIndex then
			direction = -1
		end
		Animation.SwipeProgram(Current.Program, newProgram, direction)
	else
		Animation.RectangleSize(Drawing.Screen.Width/2, Drawing.Screen.Height/2, 1, 1, Drawing.Screen.Width, Drawing.Screen.Height, colours.grey, 0.3, function()
			Current.Program = newProgram
			Overlay.UpdateButtons()
			Current.Program.AppRedirect:Draw()
			Draw()
		end)
	end
end

function Update(event, timer)
	if timer == updateTimer then
		if needsDisplay then
			Draw()
		end
	elseif timer == clockTimer then
		clockTimer = os.startTimer(0.8333333)
		Draw()
	elseif timer == desktopRefreshTimer then
		Desktop:RefreshFiles()
		desktopRefreshTimer = os.startTimer(3)
	elseif timer == Desktop.desktopDragOverTimer then
		Desktop.DragOverUpdate()
	else
		Animation.HandleTimer(timer)
		for i, program in ipairs(Current.Programs) do
			for i2, _timer in ipairs(program.Timers) do
				if _timer == timer then
					program:QueueEvent('timer', timer)
				end
			end
		end
	end
end


function Draw()
	if not Current.CanDraw then
		return
	end

	drawing = true
	Current.Clicks = {}

	if Current.Program then
		--Current.Program.AppRedirect:Draw()
	else
		Desktop:Draw()
		term.setCursorBlink(false)
	end

	for i, elem in ipairs(InterfaceElements) do
		if elem.Draw then
			elem:Draw()
		end
	end

	if Current.Window then
		Current.Window:Draw()
	end

	Drawing.DrawBuffer()
	term.setCursorPos(Current.CursorPos[1], Current.CursorPos[2])
	term.setTextColour(Current.CursorColour)
	drawing = false
	needsDisplay = false
	if not Current.Program then
		updateTimer = os.startTimer(0.05)
	end
end

MainDraw = Draw

function RegisterElement(elem)
	table.insert(InterfaceElements, elem)
end

function UnregisterElement(elem)
	for i, e in ipairs(InterfaceElements) do
		if elem == e then
			InterfaceElements[i] = nil
		end
	end
end

function RegisterClick(elem)
	table.insert(Current.Clicks, elem)
end

function CheckClick(object, x, y)
	local pos = GetAbsolutePosition(object)
	if pos.X <= x and pos.Y <= y and  pos.X + object.Width > x and pos.Y + object.Height > y then
		return true
	end
end

function DoClick(event, object, side, x, y)
	if object and CheckClick(object, x, y) then
		return object:Click(side, x - object.X + 1, y - object.Y + 1)
	end	
end

function TryClick(event, side, x, y)
	if Current.Menu and DoClick(event, Current.Menu, side, x, y) then
		Draw()
		return
	elseif Current.Window then
		if DoClick(event, Current.Window, side, x, y) then
			Draw()
			return
		else
			Current.Window:Flash()
		end
	else
		if Current.Menu and not (x < 6 and y == 1) then
			Current.Menu:Close()
			NeedsDisplay()
		end
		if Current.Program and y >= 2 then
			Current.Program:Click(event, side, x, y-1)
		elseif y >= 2 then
			Desktop.Click(event, side, x, y)
		end

		for i, object in ipairs(Current.Clicks) do
			if DoClick(event, object, side, x, y) then
				Draw()
				return
			end		
		end
	end
end

function HandleKey(...)
	local args = {...}
	local event = args[1]
	local keychar = args[2]
	
	--REMOVE THIS AT RELEASE!
	if keychar == '\\' then
		--os.reboot()
	end

	if Current.Input then
		if event == 'char' then
			Current.Input:Char(keychar)
		elseif event == 'key' then
			Current.Input:Key(keychar)
		end
	elseif Current.Program then 
		Current.Program:QueueEvent(...)
	elseif Current.Window then
		if event == 'key' then
			if keychar == keys.enter then
				if Current.Window.OkButton then
					Current.Window.OkButton:Click(1,1,1)
					NeedsDisplay()
				end
			elseif keychar == keys.delete or keychar == keys.backspace then
				if Current.Window.CancelButton then
					Current.Window.CancelButton:Click(1,1,1)
					NeedsDisplay()
				end
			end
		end
	else
		if event == 'key' then
			if keychar == keys.enter then
				Desktop.OpenSelected()
			elseif keychar == keys.delete or keychar == keys.backspace then
				Desktop.DeleteSelected()
			end
		end
	end
end

function GetAbsolutePosition(obj)
	if not obj.Parent then
		return {X = obj.X, Y = obj.Y}
	else
		local pos = GetAbsolutePosition(obj.Parent)
		local x = pos.X + obj.X - 1
		local y = pos.Y + obj.Y - 1
		return {X = x, Y = y}
	end
end

function NeedsDisplay()
	needsDisplay = true
end

--I'll try to impliment this sometime later. The main issue is that it doesn't resume the program, especially if it relies on sleep()

function Sleep()
	Drawing.Clear(colours.black)
	Drawing.DrawCharactersCenter(1, -1, nil, nil, 'Your computer is sleeping to reduce server load.', colours.cyan, colours.black)
	Drawing.DrawCharactersCenter(1, 1, nil, nil, 'Click anywhere to wake it up.', colours.lightGrey, colours.black)
	Drawing.DrawBuffer()
	os.pullEvent('mouse_click')

		--ProgramEventHandle()

--	for i, v in ipairs(Current.Programs) do
--		v:Resume()
--	end

	Draw()
	updateTimer = os.startTimer(0.05)
	clockTimer = os.startTimer(0.8333333)
end


function Shutdown(restart)
	local success = true
	for i, program in ipairs(Current.Programs) do
		if not program:Close() then
			success = false
		end
	end

	if success and not restart then
		Log.i("Shutting down...")
		os.loadAPI("SpeedAPI/windows")
		windows.tv(0)
		os.shutdown()
	elseif success then
		Log.i("Rebooting...")
		windows.tv(0)
		os.reboot()
	else
		Current.Program = nil
		Overlay.UpdateButtons()
		local shutdownLabel = 'shutdown'
		local shutdownLabelCaptital = 'Shutdown'
		if restart then
			shutdownLabel = 'restart'
			shutdownLabelCaptital = 'Restart'
		end

		ButtonDialogueWindow:Initialise("Programs Still Open", "Some programs stopped themselves from being closed, preventing "..shutdownLabel..". Save your work and close them or click 'Force "..shutdownLabelCaptital.."'.", 'Force '..shutdownLabelCaptital, 'Cancel', function(btnsuccess)
			if btsuccess and not restart then
				os.shutdown()
			elseif btnsuccess then
				os.reboot()
			end
		end):Show()
	end
end

function Restart()
	Shutdown(true)
end

function EventRegister(event, func)
	if not Events[event] then
		Events[event] = {}
	end

	table.insert(Events[event], func)
end

function ProgramEventHandle()
	for i, program in ipairs(Current.Programs) do
		for i, event in ipairs(program.EventQueue) do
			program:Resume(unpack(event))
		end
		program.EventQueue = {}
	end
end

function EventHandler()
	while true do
		ProgramEventHandle()
		local event = { coroutine.yield() }
		local hasFound = false

		if Events[event[1]] then
			for i, e in ipairs(Events[event[1]]) do
				if e(event[1], event[2], event[3], event[4], event[5]) == false then
					hasFound = false
				else
					hasFound = true
				end
			end
		end

		if not hasFound and Current.Program then
			Current.Program:QueueEvent(unpack(event))
		end
	end
end
