function widget:GetInfo()
	return {
		name      = "Chili Chicken Panel",
		desc      = "Indian cuisine",
		author    = "quantum, KingRaptor, rewrote Helwor",
		date      = "May 04, 2008",
		license   = "GNU GPL, v2 or later",
		layer     = -9,
		enabled   = true  --  loaded by default?
	}
end

-- totally broken: claims it changes the data but doesn't!


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not Spring.GetGameRulesParam("difficulty")) then
	return false
end

local f = Game.modName:match('dev') and  VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
VFS.Include("LuaRules/Utilities/tobool.lua")

local Spring          = Spring
local gl, GL          = gl, GL
local widgetHandler   = widgetHandler
local math            = math
local floor			  = math.floor
local min			  = math.min
local max			  = math.max
local table           = table

local tobool = Spring.Utilities.tobool
local spGetGameRulesParam = Spring.GetGameRulesParam
include('keysym.lua')
local ESCAPE = KEYSYMS.ESCAPE
KEYSYMS = nil

local spGetGameSeconds = Spring.GetGameSeconds
local Echo = Spring.Echo

local panelFont		  = "LuaUI/Fonts/komtxt__.ttf"
local waveFont        = LUAUI_DIRNAME.."Fonts/Skrawl_40"
local panelTexture    = LUAUI_DIRNAME.."Images/panel.tga"

local viewSizeX, viewSizeY = 0,0
local curTime = spGetGameSeconds()
local red             = "\255\255\001\001"
local white           = "\255\255\255\255"
local green			  = "\255\001\255\001"
local blue			  = "\255\100\100\255"
local lightblue		  = "\255\150\200\255"
local yellow		  = "\255\255\255\001"
local fadered		  = "\255\255\100\100"
local purple		  = "\255\215\50\215"
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local modVars, modConsts, modOnce  = {}, {}, {}

local varDescs, varIndex,constIndex
local WritePair, WriteValue
local constSTR =""

local UpdateModVars

local waveMessage
local waveSpacingY    = 7
local waveY           = 800
local waveSpeed       = 0.2
local waveCount       = 0
local waveTime
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- include the unsynced (widget) config data
local file              = LUAUI_DIRNAME .. 'Configs/chickengui_config.lua'
local configs           = VFS.Include(file, nil, VFS.ZIP)
local roostName         = configs.roostName
local chickenColorSet   = configs.colorSet

VFS.Include("LuaRules/Configs/spawn_defs.lua", nil, VFS.ZIP)
local difficulty = difficulties[diff_order[spGetGameRulesParam("difficulty")]]
local chickenTypes = difficulty.chickenTypes

local chickenByTime, coloredChicks = {}, {}


local eggs = tobool(Spring.GetModOptions().eggs)
local speed = tobool(Spring.GetModOptions().speedchicken)
local relentless = tobool(Spring.GetModOptions().relentless)
local hidePanel = tobool(Spring.GetModOptions().chicken_hidepanel)
local noWaveMessages = tobool(Spring.GetModOptions().chicken_nowavemessages)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Chili
local Button
local Label
local Window
local Panel
local TextBox
local Image
local Progressbar
local Control
local Font

-- elements
local controls = {}
local chickenTv, labelStack, background
local global_command_button

local debug_button, win_debug_consts, consts_content

local labelHeight = 22
local fontSize = 16
local chickenTVFont = {font = panelFont, size = fontSize, shadow = false, outline = false, autoOutlineColor = false}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
fontHandler.UseFont(waveFont)
local waveFontSize   = fontHandler.GetFontSize()






--------------------------------------------------------------------------------
-- utility functions
--------------------------------------------------------------------------------

local function GetCount(type)
	local total = 0
	for chickenName,colorInfo in pairs(chickenColorSet) do
		total = total + modVars[chickenName..type]
	end
	return total
end


local function FormatTime(num)
	local h, m, s = num>3599 and num/3600, (num%3600)/60, num%60
	if h then
		return ('%d:%02d:%02d'):format(h, m , s)
	end
	return ('%02d:%02d'):format(m, s)
end

-- explanation for string.char: http://springrts.com/phpbb/viewtopic.php?f=23&t=24952
local function GetColor(percent)
	local midpt = (percent > 50)
	local r, g
	if midpt then
		r = 255
		g = floor(255*(100-percent)/50)
	else
		r = floor(255*percent/50)
		g = 255
	end
	return string.char(255,r,g,0)
end

local function GetColorAggression(value) -- value going from -10 to +10
	local r,g,b
	if (value<=-1) then
		r = 255
		g = max(255 + value*25, 0)
		b = max(255 + value*25, 0)
	elseif (value>=1) then
		r = max(255 - value*25, 0)
		g = 255
		b = max(255 - value*25, 0)
	else
		r=255
		g=255
		b=255
	end
	return string.char(255,r,g,b)
end

local function MakeLiveText(t)
	local strings = {}
	for i,st in ipairs(t) do
		if type(st) == 'function' then
			st = st()
		end
		strings[i] = st
	end
	return table.concat(strings)
end


function string:word(pos) -- detect a word at position in text
	local _,endPos = self:sub(pos):find('^%w+')
	if endPos then
		pos, endPos = self:sub(1,pos-1):find('%w+$') or pos,    pos + endPos - 1
		return self:sub(pos,endPos), pos, endPos
	end
end


for name in pairs(chickenTypes) do
	table.insert(chickenByTime,name)
end
table.sort(chickenByTime,
	function(nameA,nameB)
		return chickenTypes[nameA].time and chickenTypes[nameB].time and chickenTypes[nameA].time < chickenTypes[nameB].time
	end
)
for chickenName, color in pairs(chickenColorSet) do
	coloredChicks[chickenName] = color .. Spring.Utilities.GetHumanName(UnitDefNames[chickenName]) .. "\008"
end

local tooltipWords = {
	burrows = 'BURRO!'
}


local cache,live = {caption={},tooltip={}}, {caption={},tooltip={}}
live.caption.tech = function(self)
	self:SetCaption("Tech progress modifier : "..FormatTime(modVars["totalTechMod"]))
end

live.tooltip.tech = function(self)
	-- calculate future tech mod for the next wave if aggro stay the same
	local waveDuration = (modConsts.chickenSpawnRate)
	local waveDurationMinutes = waveDuration / 60
	local aggro = modVars.humanAggro
	local previTechMod = -aggro * modConsts['humanAggroTechTime'..(aggro>0 and 'Regress' or 'Progress')]
	-- Echo(" is ", (previTechMod + modVars.techMalusMultiplayer), * waveDurationMinutes)
	previTechMod = (previTechMod + modVars.techMalusMultiplayer) * waveDurationMinutes
	--
	self.tooltip = cache.tooltip.tech1
		.."\nChicken tech will gain extra: "..("%.1f"):format(previTechMod) .." seconds at next wave if aggro stay the same."
		..cache.tooltip.tech2
end

live.tooltip.anger = function(self)
	-- calculate queen time reduction if burrow is killed now
	local queenAggro = modVars.humanAggro
	queenAggro = min( max(queenAggro, modConsts.humanAggroQueenTimeMin), modConsts.humanAggroQueenTimeMax)
	local queenTimeReduction =  max (modConsts.burrowQueenTime * modConsts.humanAggroQueenTimeFactor * queenAggro, 0)
	queenTimeReduction =  max(queenTimeReduction, 0)
	--

	self.tooltip = "Killing a burrow at current aggro accelerate the arriving of the queen by ".. ("%.1f"):format(queenTimeReduction) .." seconds."
		..cache.tooltip.anger
end
live.tooltip.UpdateToolTipChickens = function(self)
	local breakdown = ""
	for _,name in ipairs(chickenByTime) do
		breakdown = breakdown .. "\n"..coloredChicks[name]..": \255\0\255\0"..modVars[name.."Count"].."\008/\255\255\0\0"..modVars[name.."Kills"]
	end
	self.tooltip = cache.tooltip.chickens .. breakdown
end
live.tooltip.UpdateToolTipBurrows = function(self)
	self.tooltip = "Burrow spawn time (at "..modVars[roostName .. "Count"].." burrows): "
		.. ("%.1f"):format(modVars.burrowSpawnTime) .." seconds\n"
		.. cache.tooltip.burrows
end
for k,v in pairs(live.tooltip) do
	if type(v)=='function' then
		live.tooltip[v]=true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function WriteChiliStatics()

	cache.tooltip.anger = modConsts.miniQueenTime and modConsts.miniQueenTime[1]
		and "\nDragons arrive at ".. FormatTime(floor(modConsts.queenTime * modConsts.miniQueenTime[1])) .. " (".. floor(modConsts.miniQueenTime[1]*100) .."%)"
		or ''

	cache.tooltip.burrows = "When killed, each burrow has a ".. floor(modConsts.burrowRespawnChance*100) .."% chance of respawning"

	cache.tooltip.chickens = "Chickens spawn every ".. modConsts.chickenSpawnRate.." seconds\n"

	cache.tooltip.tech1 = "How much time the chicken tech is ahead/behind from the real time "
		.."(can't be below "..floor(modConsts.techTimeFloorFactor*100) .."% of game time)"
	cache.tooltip.tech2 = '\n'.."Each burrow killed reduces chicken tech time by "..("%.1f"):format(modVars.burrowRegressTime).. " seconds"
	
	chickenTv.aggro.tooltip = "Each burrow killed increases aggression rating by "..("%.1f"):format(modVars.humanAggroPerBurrow)
	.."\n".."Aggression rating decreases by "..("%.2f"):format(modConsts.humanAggroDecay).." per minute of game time"
	..(	modConsts.humanAggroTechTimeRegress>0
		and "\n".."if positive, chicken tech regress per "..("%.1f"):format(modConsts.humanAggroTechTimeRegress).."sec per point at each wave"
		or '')	
	.."\n".."if negative, chicken tech accelerate per "..("%.1f"):format(modConsts.humanAggroTechTimeProgress).."sec per point per minute at each wave"

	cache.caption.mode = {
		antilag = red.."Anti-Lag Enabled\008".."\n"
		,normal = (function()
			local substr = (relentless and 'Relentless' or '')
				..(speed and ', Speed' or '')
				..(eggs and ', Eggs' or '')
			if substr:sub(1,1)==',' then
				substr = substr:sub(2)
			elseif substr:len()>0 then
				substr = '('..substr..')'
			end
			return 'Mode '..configs.difficulties[modVars.difficulty] ..'\n'.. substr
		end)(),
	}


end


-- done every second
local UpdateAnger,UpdateNextTech, UpdateDebugVars
do
	local nextTech, nextTechName, nextTechColor
	UpdateNextTech = function()
		local newNextTech =  modVars.nextTech
		if newNextTech~=nextTech then
			nextTech = newNextTech
			local nextTechDef = UnitDefNames[nextTech]
			nextTechName = nextTechDef and nextTechDef.humanName or 'none'
			nextTechColor = chickenColorSet[nextTech] or ''
		end
		local currTech, grace = modVars.currTech, modVars.gracePeriod
		local remaining = grace>curTime and grace-curTime or modVars.nextTechTime-currTech
		local currTechColor = GetColorAggression((curTime-currTech)/120)
		chickenTv.next_tech:SetCaption(
			"Current tech : "..currTechColor..FormatTime(currTech)
			.."\n"..nextTechColor..nextTechName.."\008 in "..FormatTime(remaining)
		)
	end
	UpdateAnger = function()
		local saveOffset = (modVars.totalSaveGameFrame or 0) / Game.gameSpeed
		local angerPercent = ((curTime + saveOffset) / (modVars.queenTime + saveOffset) * 100)
		local angerString = "Hive Anger : ".. GetColor( min(angerPercent, 100) )..floor(angerPercent).."% \008"
		if (angerPercent < 100) and (not endlessMode) then angerString = angerString .. "("..FormatTime(modVars.queenTime - curTime) .. " left)" end
		chickenTv.anger:SetCaption(angerString)

	end
	UpdateDebugVars = function()
		local all_vars = blue.."Variables modified by the game situation:\008"
		..'\ncurrentTime: '..curTime
		local alinea = '\n\t\t'
		for i, param in ipairs(varIndex) do
			if not (modOnce[param] or param:match('Count') or param:match('Kill')) then
				local desc = varDescs[param]
				local line = '\n'..' - '..param..' = '..WriteValue(modVars[param], blue)
				if desc then
					-- line = line..('\t'):rep(15-floor(line:len()/4))..' => '..desc
					line = line..alinea..' => '..desc
				end
				all_vars = all_vars..line
			end
		end
		vars_content:SetCaption(all_vars)
	end
end
local dynaCaptions = {
	mode = function(self)
		local fps = modVars.fps
		-- Echo("fps is ", fps,spGetGameRulesParam('fps'),spGetGameRulesParam('checkFrequency'))
		if tobool(modVars.lagging) then
			if chickenTv.mode.caption ~= cache.caption.mode.antilag then
				controls.mode:SetCaption(cache.caption.mode.antilag)
				-- Echo("controls.mode.height is ", controls.mode.height)
				controls.mode:Resize(nil,16)
			end
			-- controls.mode:Invalidate()
			-- labelStack:Invalidate()
		elseif chickenTv.mode.caption ~= cache.caption.mode.normal then
			controls.mode:SetCaption(cache.caption.mode.normal)
			controls.mode:Resize(nil,30)

			-- Echo("controls.mode.height is ", controls.mode.height)
			-- controls.mode:Resize(nil,controls.mode.height+labelHeight/3)
			-- controls.mode:Invalidate()
			-- labelStack:Invalidate()
		end
	end
	,chickens = function()
		local chickenCount, chickenKills = GetCount("Count"), GetCount("Kills")
		chickenTv.chickens:SetCaption("Chickens alive/killed : \255\0\255\0"..chickenCount.."\008/\255\255\0\0"..chickenKills)
	end
	,burrows = function()
		chickenTv.burrows:SetCaption("Burrows alive/killed : \255\0\255\0"..modVars[roostName .. "Count"].."\008/\255\255\0\0"..modVars[roostName .. "Kills"])
	end
	,aggro = function()
		chickenTv.aggro:SetCaption("Team Aggression: "..GetColorAggression(modVars["humanAggro"])..("%.3f"):format(modVars["humanAggro"]))
	end

}


chickenTv ={
	name   = 'chicken_tv'
	,color = {0, 0, 0, 0}
	,width = 270
	,height = 200
	,right = 0
	,top = 100
	,y = 100
	,dockable = true
	,draggable = true
	,resizable = false
	,minWidth = 270
	,minHeight = 200
	,padding = {0, 0, 0, 0}
	-- ,MouseOver = {
	-- 	function(self)
	-- 		Echo("Spring.GetGameSeconds() is ", Spring.GetGameSeconds())
	-- 		return self
	-- 	end
	-- }
	-- user defined
	-- label creation follow this order
	,labels = {'anger', 'chickens', 'burrows', 'aggro', 'tech', 'next_tech', 'mode'}
}


chickenTv.anger = {
	x=15
	,width = 200
	,align="left"
	,valign="left"
	,autosize=false
	,MouseOver = live.tooltip.anger
}

chickenTv.chickens = {
	x=15
	,width = 220
	,autosize=false
	,align="left"
	,valign="left"
	,MouseOver = live.tooltip.UpdateToolTipChickens
}

chickenTv.burrows = {
	autosize=false
	,align="left"
	,valign="left"
	,width = 220
	,x=15
	,MouseOver = live.tooltip.UpdateToolTipBurrows
}

chickenTv.aggro = {
	autosize=false
	,align="left"
	,valign="left"
	-- ,height = labelHeight
	,width = 220
	,x=15
}

chickenTv.tech = {
	autosize=false
	,align="left"
	,valign="left"
	,width = 220
	,OnParentPost = {function(self) self.OnMouseOver = {live.tooltip[self.shortname],live.caption[self.shortname]} self:MouseOver() end}
	,MouseDown = function(self) 
		local modHeight = 0
		if not chickenTv.next_tech.visible then
			modHeight = modHeight + chickenTv.next_tech.height
			chickenTv.next_tech:Show()

		else
			chickenTv.next_tech:Hide()
			modHeight = modHeight - chickenTv.next_tech.height
		end
		chickenTv:Resize(nil,chickenTv.height + modHeight)
	end
	-- user defined
	,shortname = 'tech'

}
chickenTv.next_tech = {
	autosize=true
	,align="left"
	,valign="top"
	,width = "100%"
	,tooltip = 'You spoil !'
	,OnShow = {
		function()
			curTime = spGetGameSeconds()
			UpdateModVars()
			UpdateNextTech()
		end
	}
}
chickenTv.mode = {
	name = 'chickentv_label_mode'
	,autosize=false
	,align="center"
	,valign="center"
	,autosize = true
	-- ,height = labelHeight*5/3
	,x=200
	,width = 100
	,margin = {30,0,0,0}
	-- Note: the real table could be accessed later via getmetatable(self)._obj
	,OnParentPost = {function(self)
		if dynaCaptions[self.shortname] then
			-- Echo("self.name is ", self.name)
			controls[self.shortname]=self
		end
	end}
	,tooltip = ' mode tooltip '
	-- user defined
	,shortname = 'mode'
}






-- done every 2 seconds
local function UpdateAll()
	-- write info

	-- refresh dynamic captions
	for _,updateFunc in pairs(dynaCaptions) do
		updateFunc()
	end
	-- refresh dynamic tooltips
	local hoveredCtrl = screen0.hoveredControl
	local refresh = hoveredCtrl and live.tooltip[hoveredCtrl.MouseOver] and hoveredCtrl:MouseOver()


	-- for k,v in pairs(controls) do
	-- 	Echo('in controls:',k,v)
	-- end

end

--------------------------------------------------------------------------------
-- wave messages
--------------------------------------------------------------------------------
local function WaveRow(n)
	return n*(waveFontSize+waveSpacingY)
end

local function MakeLine(chicken, n)
	local humanName = Spring.Utilities.GetHumanName(UnitDefNames[chicken])
	local color = chickenColorSet[chicken] or ""
	return color..humanName.." x"..n
end

function ChickenEvent(chickenEventArgs)
	if (chickenEventArgs.type == "wave") then
		if noWaveMessages then
			return
		end
		
		local chicken1Name, chicken2Name, chickenSpName, chicken1Number, chicken2Number, chickenSpNumber = unpack(chickenEventArgs)
		if (modVars[roostName .. 'Count'] < 1) then
			return
		end
		waveMessage    = {}
		waveCount      = waveCount + 1
		local n_line = 1
		waveMessage[n_line] = "Wave "..waveCount
		-- Spring.Echo('Wave:'..waveCount,unpack(chickenEventArgs))
		for i=1,3 do
			local name,number = chickenEventArgs[i], chickenEventArgs[i+3]
			if number>0 then
				n_line = n_line + 1
				waveMessage[n_line] = MakeLine(name, number)
			end
		end
	
		waveTime = Spring.GetTimer()
		
	-- table.foreachi(waveMessage, print)
	-- local t = spGetGameSeconds()
	-- print(string.format("time %d:%d", t/60, t%60))
	-- print""
	elseif (chickenEventArgs.type == "burrowSpawn") then
		UpdateModVars()
		UpdateAll()
	elseif (chickenEventArgs.type == "miniQueen") then
		waveMessage    = {}
		waveMessage[1] = "Here be dragons!"
		waveTime = Spring.GetTimer()
	elseif (chickenEventArgs.type == "queen") then
		waveMessage    = {}
		waveMessage[1] = "The Hive is angered!"
		waveTime = Spring.GetTimer()
	elseif (chickenEventArgs.type == "refresh") then
		curTime = spGetGameSeconds()
		UpdateModVars()
		UpdateAll()
		UpdateAnger()
	end
end
do 
	local UseFont,DrawCentered = fontHandler.UseFont, fontHandler.DrawCentered
	local spDiffTimers =  Spring.DiffTimers
	function widget:DrawScreen()
		viewSizeX, viewSizeY = gl.GetViewSizes()
		if (waveMessage)  then
			local t = Spring.GetTimer()
			UseFont(waveFont)
			local waveY = viewSizeY - (relentless and 0 or spDiffTimers(t, waveTime)*waveSpeed*viewSizeY)
			if (waveY > 0) then
				for i=1,#waveMessage do
					DrawCentered(waveMessage[i], viewSizeX/2, waveY-WaveRow(i))
				end
			else
				waveMessage = nil
				waveY = viewSizeY
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:KeyPress(key)
	if key == ESCAPE then 
		if win_debug_consts.visible then
			win_debug_consts:Hide()
			return true
		elseif win_debug_vars.visible then
			win_debug_vars:Hide()
			return true
		else
			widgetHandler:RemoveCallIn("KeyPress",widget)
		end
	end
end

function widget:Initialize()
	local n = #varIndex
	for chickenName,_ in pairs(chickenColorSet) do
		n=n+1
		varIndex[n] = chickenName .. 'Count'
		n=n+1
		varIndex[n] = chickenName .. 'Kills'
	end

	for _,rule in ipairs(varIndex) do
		if not rule:match('comment_') then
			modVars[rule] = spGetGameRulesParam(rule)
		end
	end

	for k,v in pairs(base_values) do
		modConsts[k] = v
	end
	for param,v in pairs(difficulty) do
		if param~='supporters' and param~='defenders' and param~='specialPowers' and param~='chickenTypes' then
			modConsts[param] = v
		end
	end

	local alinea = '\n\t\t'

	constSTR = lightblue..'NON BASE VALUES\008\n'
	..'\n'..lightblue..'lightblue\008:'..' value modified\\initialized at game start for the last time,\n mainly because of player count involved in them.'
	for i,param in ipairs(varIndex)	do
		if modOnce[param] then
			local isComment = not modVars[param]
			local line
			if isComment then
				line = '\n *** '..varDescs[param]
			else
				local desc = varDescs[param]
				line = '\n - '..WritePair(param, v, lightblue)
				if desc then
					-- line = line..('\t'):rep(15-floor(line:len()/4))..' => '..desc
					line = line..alinea..' => '..desc
				end
			end
			if line then
				constSTR = constSTR..line
			end
		end
	end
	constSTR = constSTR..'\n\n'..'<<<<< Values below can be set by Mod Options >>>>>\n'
	constSTR = constSTR..'\n\n'..'All values that have '..yellow..'yellow\008 or '..green..'green\008 values can be changed with ModOptions'.. '\n'
	constSTR = constSTR..'\n'..green..'base values:\008 in '..green..'green '..'\008 modified by mode and difficulty'
	..'\ncompared to their original values in '..yellow..'yellow.\008'
	..'\nin parenthesis are their past history'
	..'\nexcept for QUEENTIME, none of those values will change during game time'
	for i,param in ipairs(constIndex) do
		local line
		local v = difficulty[param]
		local desc = constDescs[param]
		local isComment = not modConsts[param]
		if isComment then
			line = '\n *** '..desc
		elseif param~='supporters' and param~='defenders' and param~='specialPowers' and param~='chickenTypes' then
			local live = not modOnce[param] and (modVars[param] and WritePair(param, modVars[param], blue)..' ('..WriteValue(v, green)..')')
			local once = live or (modOnce[param] and WritePair(param, modVars[param], lightblue)..' ('..WriteValue(v, green)..')')
			line = '\n - '..(once or WritePair(param, v, green))..' ('..WriteValue(base_values[param], yellow)..')'
			if desc then
				-- line = line..('\t'):rep(15-floor(line:len()/4))..' => '..desc
				line = line..alinea..' => '..desc
			end
		end
		if line then
			constSTR = constSTR..line
		end
	end
	constSTR = constSTR..'\n'..yellow..'base values unchanged:\008'
	for i,param in ipairs(constIndex) do
		local line
		local v = modConsts[param]
		local isComment = not modConsts[param]
		if isComment then
			line = '\n *** '..constDescs[param]
		elseif param~='supporters' and param~='defenders' and param~='specialPowers' and param~='chickenTypes' then
			if not difficulty[param] then
				local desc = constDescs[param]
				local live = not modOnce[param] and (modVars[param] and WritePair(param, modVars[param], blue)..' ('..WriteValue(v, green)..')')
				local once = live or (modOnce[param] and WritePair(param, modVars[param], lightblue)..' ('..WriteValue(v, yellow)..')')
				line = '\n - '..(once or WritePair(param, v, yellow))
				if desc then
					-- line = line..('\t'):rep(15-floor(line:len()/4))..' => '..desc
					line = line..alinea..' => '..desc
				end
			end
		end
		if line then
			constSTR = constSTR..line
		end
	end

	curTime = spGetGameSeconds()
	UpdateModVars()
	WriteChiliStatics()

	do -- Chili stuff
		
		Chili = WG.Chili
		Button = Chili.Button
		Label = Chili.Label
		Checkbox = Chili.Checkbox
		Window = Chili.Window
		Panel = Chili.Panel
		StackPanel = Chili.StackPanel
		ScrollPanel = Chili.ScrollPanel
		TextBox = Chili.TextBox
		Image = Chili.Image
		Progressbar = Chili.Progressbar
		Font = Chili.Font
		Control = Chili.Control
		TextBox = Chili.TextBox
		screen0 = Chili.Screen0
		
		--create main Chili elements

		


		labelStack = {
			x = 15
			,y = 20
			,resizeItems = false
			,autosize = true
			,height = 175
			,width =  230
			,itemMargin  = {10, 0, 0, 0}
		}
		background = Image:New{
			x=0
			,y=0
			,width="100%"
			,height="100%"
			,minWidth = 270
			,minHeight = 200
			,autosize = true
			,keepAspect = false
			,file = panelTexture
		}
		-- setup the  chili controls
		local dumfunc = function(self) return self end
		for i,name in ipairs(chickenTv.labels) do
			chickenTv[name].HitTest = dumfunc
			chickenTv[name].font = table.shallowcopy(chickenTVFont)
			chickenTv.labels[i] = chickenTv[name]
			Label:New(chickenTv[name])
		end
		labelStack.children = chickenTv.labels

		StackPanel:New(labelStack)


		chickenTv.children = {labelStack,background}
		chickenTv.font = table.shallowcopy(chickenTVFont)

		chickenTv.parent = screen0
		Window:New(chickenTv)
		-- or after like that
		-- win:AddChild(labelStack,false)
		-- win:AddChild(background,false)


		if Game.modName:match('dev') then

			local button = Button:New{
				caption = 'Close'
				,OnClick = { function(self) self.parent:Hide() end }
				,x=5
				,height=30
				,right=5
				,bottom=5

			}
			local consts_content = TextBox:New{
				x = 5
				,y = 5
				,right = 0
				,align = "left"
				,valign = "left"
				,fontsize = 12
				,multiline = true
				,OnMouseUp = {function(self)
					if self.tooltip then
						-- mouse release unselect, so we redo the processus
						local x,y = self.lastx,self.lasty
						self.tooltip = nil
						self.lastx,self.lasty = -1,-1
						self:HitTest(x,y)
					end 
				end}
				,HitTest = function(self,x,y) -- switch tooltip and create fake selection to highlight some words
					if self.lastx==x and self.lasty==y then
						return self
					end
					self.lastx,self.lasty = x,y
					local infos = self:_GetCursorByMousePos(x, y)
					if infos.outOfBounds then
						self.tooltip = ''
						return self
					end
					local lineID = infos.cursorY
					local logLine = self.lines[lineID]
					local word,pos,endPos = logLine.text:word(infos.cursor)
					local tooltip = tooltipWords[word]
					if tooltip and self.tooltipPos~=pos then
						-- make it selectable only to lure Screen0 and _SetSelection, we want the ability to move the window on drag
						self.selectable = true
						if not self.state.focused then
							-- simulate click for Screen0 to activate the control, or the fake selection won't happen
							local mx,my = Spring.GetMouseState()
							Chili.Screen0:MouseDown(mx,my)
							Chili.Screen0:MouseUp(mx,my)
						end
						self:_SetSelection(pos, lineID, endPos+1, lineID)
						self:Invalidate()
						self.selectable = false
					elseif not tooltip then
						if self.selStart then
							-- clear when mouse go out of the word
							self:ClearSelected()
						end
					end
					self.tooltip = tooltip
					self.tooltipPos = pos
					return self
				end
				,OnParentPost = {function(self) self.font.autoOutlineColor = false end}
				--user defined keys
				,lastx=0,lasty=0

				
			}
			consts_content:SetText(constSTR)
			local consts_scroll = ScrollPanel:New{
				x = 5
				,y = 5
				,right = 0
				,top = 5
				,align = "left"
				,valign = "left"
				,fontsize = 12
				,bottom = 35
				-- workaround to trigger the text updating on scroll, but there's probably a more decent way to do it
				,Update = function(self,...) self.children[1]:Invalidate() self.inherited.Update(self,...)   end
				,children = {consts_content}
			}

			win_debug_consts = Window:New{
				parent = Chili.Screen0
				,width=600
				,height = 600
				-- ,autosize=true
				,children = {consts_scroll,button}
			}


			win_debug_consts:Hide()





			-- hidden button on the chicken panel
			button1 = Window:New{
				parent = chickenTv
				,color = {0, 0, 0, 0.5}
				,minHeight = 17
				,minwidth = 15
				,x = chickenTv.width-21
				,y = "40%"
				,bottom = "90%"
				,MouseDown = function(self) 
					if not self.visible then
						widget:UpdateCallIn("KeyPress")
					end
					win_debug_consts:ToggleVisibility()
				end
			}
			win_debug_vars = Window:New{
				parent = Chili.Screen0,
				x="50%",
				y="5%",
				width=700,
				height = 500,
				-- FIX CHILI: if ToggleVisibility() is used instead of Show() and Hide() OnShow and OnHide are not triggered, 
				-- autosize=true,
			}
			vars_content = Label:New{
				x = 5,
				y = 5,
				right = 0,
				parent = win_debug_vars,
				align = "left",
				valign = "left",
				fontsize = 12,
				caption = blue.."Variables modified by the game situation:\008",
				font = {
					font = "FreeSansBold.otf",
					autoOutlineColor = false,
				},
			}
			win_debug_vars:Hide()

			button2 = Window:New{
				parent = chickenTv,
				color = {0, 0, 0, 0},
				minHeight = 17,
				minwidth = 15,
				x = chickenTv.width-21,
				y = "50%",
				bottom = "90%",
				resizable = false,
				tweakDraggable = false,
				tweakResizable = false,
				padding = {0, 0, 0, 0},
				MouseDown = function(self) 
					if not win_debug_vars.visible then
						UpdateDebugVars()
						widgetHandler:UpdateCallIn("KeyPress",widget)
						win_debug_vars:Show()
					else
						win_debug_vars:Hide()
					end
					-- win_debug_vars:ToggleVisibility()
				end
			}
			UpdateAll()
			UpdateAnger()
			UpdateNextTech()

			chickenTv.next_tech:Hide()
			-- Activate tooltips for labels, they do not have them in default chili
			-- function chickenTv.anger:HitTest(x,y) return self end
			-- function chickenTv.next_tech:HitTest(x,y) return self end
			if hidePanel then
				chickenTv:Hide()
			end

		end

		if WG.GlobalCommandBar and not hidePanel then
			local function ToggleWindow()
				if chickenTv.visible then
					chickenTv:Hide()
				else
					chickenTv:Show()
				end
			end
			if WG.chicken_global_command_button then -- work around since GlobalCommandBar doesn't have a remove function
				WG.chicken_global_command_button.OnClick = {ToggleWindow}
				WG.chicken_global_command_button:Show()
			else
				WG.chicken_global_command_button = WG.GlobalCommandBar.AddCommand("LuaUI/Images/chicken.png", "Chicken info", ToggleWindow)
			end
		end
	end

	widgetHandler:RegisterGlobal("ChickenEvent", ChickenEvent)

end


function widget:GameFrame(n)
	if (n%60< 1) then
		UpdateAll()
	end
	-- every second for smoother countdown
	if (n%30< 1) then
		UpdateModVars()
		curTime = spGetGameSeconds()
		UpdateAnger()
		UpdateNextTech()
		if win_debug_vars and win_debug_vars.visible then
			UpdateDebugVars()
		end
	end
end

function widget:Shutdown()
	fontHandler.FreeFont(waveFont)
	if WG.chicken_global_command_button then
		WG.chicken_global_command_button:Hide()
	end
	widgetHandler:DeregisterGlobal("ChickenEvent")
end

do -- writing functions
	local function TrimZeroes(n,maxdec)
		local str = tostring(('%.'..maxdec..'f'):format(n))
		if not str:find('.') then
			return n
		end
		while str:sub(-1)=='0' do
			str = str:sub(1,-2)
		end
		if str:sub(-1)=="." then
			str = str:sub(1,-2)
		end
		return str
	end
	local function TrimComma(str)
		local pos = str:find(',%s*$')
		if pos then
			str = str:sub(1,pos-1)
		end
		return str
	end
	WriteValue = function(v,col)
		if type(v)=='table' then
			local value =''
			for i,tv in ipairs(v) do
				value = value..(col or '')..WriteValue(tv)..'\008, '
			end
			value = '{'..TrimComma(value)..'}'
			return value
		end
		return (col or '')..(v==nil and '' or type(v)=='boolean' and tostring(v) or type(v)=='string' and "'"..v.."'" or TrimZeroes(v,3))..'\008'
	end
	WritePair = function(param,v,col)
		local value=""
		if type(v)=='table' then
			for i,tv in ipairs(v) do
				value = value..WriteValue(tv,col)..', '
			end
			value = '{'..TrimComma(value)..'}'
		else
			value = WriteValue(v,col)
		end
		return param..' = '..value
	end
end

do -- Descriptions and Update mod Vars
	modOnce = {
		difficulty = true,
		humanAggroPerBurrow = true,
		gracePeriod = true,
		burrowSpawnRate = true, 
		techMalusMultiplayer = true,
		malus = true,
		burrowRegressTime = true,
		easyBurrowKillFactor = true,
		humanAggroDefenseFactor = true,
		defensePerMin = true,
	}
	constDescs = {

		alwaysVisible = 'make chickens and burrows always visible for the players',
		maxAge = 'max time before chicken disappear',
		alwaysEggs = 'Eggs never decay',
		eggDecayTime = 'if alwaysEggs is false, how long eggs last -- TODO: test decay the oldest when a max number is reached for lag sake',
		burrowEggs = 'how many eggs drop a burrow',

		minBaseDistance = 'definitive min base distance for regular chicks',
		maxBaseDistance = 'definitive max base distance for regular chicks',
		maxBurrows = 'definitive max burrows',
		burrowSpawnRate = 'base frequency for burrow spawn',
		specialChickChance = 'base chance of getting higher tech chicken per wave per burrow, if it happen, there is a 1/4 chance of getting even higher tech chicken for this burrow this wave',
		techTimeMult = 'multiply the tech time needed for chicken to appear',

		chickenSpawnRate = 'frequency of waves',
		burrowRespawnChance = 'chance of borrow respawing after one is destroyed',

		-- squad size calculation
		comment_baseWaveSize = "This is an Intro text for baseWaveSize",

		baseWaveSize = 'base size per wave',
		burrowWaveSize = 'additional size per burrow',
		humanAggroWaveFactor = 'multiplier of additional size per positive aggro point per wave',
		humanAggroWaveMax = 'maximum additional size defined by humanAggro and humanAggroWaveFactor (line above)',
		waveSizeMult = 'multiplier of all the above calculation',
		timeSpawnBonus = 'augment waveSizeMult by this value * game time in minutes',
		rampUpTime = 'if this time is not yet reached, reduce the final squad size calculation of the burrow by the proportion of real time vs this time value, until it is reached',
		waveRatio = 'proportion of the squad of first chicken type vs second chicken type ',
		--
		gracePeriod = 'base grace period',
		gracePenalty = 'how much the gracePeriod is reduced per player added',
		gracePeriodMin = 'minimal grace period no matter the number of players',

		queenTime = 'base time remaining before queen appearance',
		miniQueenTime = '{time}',
		queenMorphName = '',
		queenName = '',
		humanAggroTeamScaling = 'factor waighting on the impact of having more players used for modifying burrowRegressTime and humanAggroPerBurrow',
		humanAggroMin = 'minimum aggro possible',
		humanAggroMax = [[

		]],

		techAccelPerPlayer = 'base of tech malus per minute per player, for each player techAccelperPlayer is divided more and then added',
		techAccelTeamScaling = 'oscillate around 1, factor the divisor of techAccelPerPlayer ',
		techTimeFloorFactor = 'the minimum fraction of the real time the tech modifier cannot go below',
		techTimeMax = 'maximum tech possible, chicken that need higher tech time than this value will never be able to appear',

		endMiniQueenWaves = 'in pvp, when queen come, mini queens spawn at this frequency of waves ',
		queenHealthMod = 'multiplier of queen hp',
		queenSpawnMult = 'multiplier of the squad spawned by the queen',

		miniQueenName = '',

		burrowQueenTime = 'base of queen time reduction when killing a burrow',
		humanAggroQueenTimeFactor = 'how much the positive aggro multiply the base reduction of queen time (2 in aggro with 2 in humanAggroQueenTimeFactor will multiply the base reduction by 4)',
		humanAggroQueenTimeMax = 'cap of aggro before beeing used to calculate the humanAggroQueenTimeFactor above',
		humanAggroQueenTimeMin = 'min cap for the same purpose as above',

		humanAggroDecay = 'net loss of aggression rating per minute of game time TODO: implement a more refined system',
		queenMorphTime = '{min,max} min and max frame between which a queen morph occur at random',
		humanAggroPerBurrow = 'aggro gain per burrow killed weighted by easyBurrowKillFactor',
		humanAggroTechTimeRegress = 'net tech time reduction per positive aggro point per minute',
		humanAggroTechTimeProgress = 'net tech time addition per negative aggro point per minute',
		burrowRegressTime = 'base value of net tech time gained when killing a burrow',

		defensePerBurrowKill = 'net defense added to the pool on burrow killed',
		defensePerMin = 'net defense added to the defense pool each minute',
		humanAggroDefenseFactor = 'additional defense for defensePerMin, weighted by aggro and multiplied by player count',

		playerMalus = 'factor the playerCount and only used to diminish the burrowSpawnRate (?!) and factor the xp gained at end of game',
		scoreMult = '',
	}


	varDescs = {
		difficulty = diff_order[spGetGameRulesParam('difficulty')]
		,humanAggro = " the current aggression rating, which, if negative, will up the total tech mod at each new wave occuring"
		,totalTechMod = "the sum of all the time gained and lost (wave passed with negative aggro, burrow killed...)"
		,currTech = "the ,modified= time which unlock higher tech of chicken"
		.."\n\t\t => can't be below time * techTimeFloorFactor (half the time passed by default),"
		.."\n\t\t => and can't be above techTimeMax which is used to cap higher types of chicken so they would never appear))"
		,nextTech = "next chicken type (or one of them)"
		,nextTechTime = "which time is needed for an higher tech chicken to get unlocked "
		,techModByAggro = "how much tech time have been lost at this wave: humanAggroTechTimeProgress * humanAggro * timeSinceLastWaveMinutes"
		,easyBurrowKillFactor = 'how easy to kill a burrow formula: ( (((minBaseDistance + maxBaseDistance)/2)/2250)*3 + (burrowSpawnRate/45) ) / 4'

		,comment_techMalusMultiplayer = "this is Intro text for techMalusMultiplayer"

		,techMalusMultiplayer = "malus added to the techModByAggro and depending on:"
		.."\n\t\t => wave frequency, number of players, proximity and frequency of nest spawning (how easy it is to kill nests)"
		.."\n\t\t => chickenSpawnRate, techAccelPerPlayer,techAccelTeamScaling, minBaseDistance, maxBaseDistance "
		.."\n\t\t => for i=2,playerCount do	techMalusMultiplayer = techMalusMultiplayer + (techAccelPerPlayer/(i*techAccelTeamScaling)) end"
		.."\n\t\t => techMalusMultiplayer = techMalusMultiplayer * easyBurrowKillFactor"
		,humanAggroPerBurrow = "how many point in aggro won per burrow killed"
		,burrowRegressTime = "net time gained by killing a burrow weighted by easyBurrowKillFactor"
		,queenTime = "baseQueenTime reduced by the killing of burrows"
		.."\n\t\t => formula: burrowQueenTime * humanAggroQueenTimeFactor * (humanAggro minmaxed by max(0, humanAggroQueenTimeMin) and humanAggroQueenTimeMax)"
		,queenTimeReduction = "if positive aggro, the resulting reduction of remaining time for queen appearance depending on base burrowQueenTime * current aggro * humanAggroQueenTimeFactor "
		,lagging = "not implemented"
		,gracePeriod = "determined by the gracePenalty * playerCount"

		,squadNumber = "final multiplier of the squad size of chicken type per wave per burrow, ratioed by base waveRatio that give proportion of first and second chicken type"

		,malus = "factor of playerCount, used only for burrowSpawnRate and xp at the end of the game: playerCount^playerMalus "
		,burrowSpawnRate = "base burrowSpawnRate modified by malus and number of AIs: burrowSpawnRate/(malus*0.8 + 0.2)/SetCount(computerTeams)"
		,burrowSpawnTime = "current burrow spawn frequency, depending on existing burrows and base spawn rate : burrowSpawnRate*0.20*(burrowCount+1)"

		,humanAggroDefenseFactor = "base humanAggroDefenseFactor * playerCount"
		,defensePerMin = "defensePerMin * playerCount"
		,defensePoolDelta = "augmentation of the pool this wave: defensePerMin + humanAggroDefenseFactor * aggro"

		,waveSchedule = "game frame for the next wave: last wave frame + 30 * burrowSpawnRate + 1"
		,lastWaveTime = "in seconds"
		,checkFrequency = "frequency in frame for updating counts, spawning burrows, checking for miniqueen and end game"
		.."\n\t\t => 3x this frequency to check age, checking target and giving orders"
		,fps = ""
		,[roostName .. "Count"] = ""
		,[roostName .. "Kills"] = ""

	}
	UpdateModVars = function ()
		for _,param in ipairs(varIndex) do
			if not modOnce[param] and not param:match('comment') then
				modVars[param] = spGetGameRulesParam(param)
			end
		end
	end

end




do -- retrieve table keys order from written code

    function string:codeescape() -- code string that is escaped character into decimal representation and vice versa
      	return (self:gsub("\\(.)", function (x)
        	return ("\\%03d"):format(x:byte())
        end))
    end
    function string:decodeescape()
      	return (self:gsub("\\(%d%d%d)", function (d)
      	                return "\\" .. d:char()
      	end))
    end

	local function GetLocal(level,search)
		local getlocal = debug.getlocal
		local name,i,value = true,1
		while name do
			name, value = getlocal(level, i)
			if name==search then
				return value
			end
			i = i + 1
		end
	end
	local function GetWidgetCode()
		local getinfo = debug.getinfo
		for i=1,18 do
			local info = getinfo(i)
			if info and info.func and info.what=="main" and getinfo(i+2).name=="LoadWidget" then
				return GetLocal(i+3,"text")
			end
		end
	end

	local function CheckIfValid(pos,line,sym,endPos) -- -- NOTE: CheckIfValid is used to Uncomment in a particular order, it doesn't ensure the validity of a sym in any circumstance
		local tries = 0
		local inString, str_end, quote = line:find("([\"']).-"..sym..".-%1")
		-- check if the found sym is not actually before this, or if the number of quotes are actually even
		if inString and ( pos<inString or select(2, line:sub(1,str_end):gsub(quote,''))%2==1 ) then
			inString=false
		end
		while inString do -- try a next one in the line, if any
			tries = tries + 1 if tries>1000 then Echo('TOO MANY TRIES 2') return end
			pos, endPos = line:find(sym, str_end+1)
			if not pos then
				return
			end
			inString, str_end, quote = line:find("([\"']).-"..sym..".-%1",str_end+1)
			if inString and ( pos<inString or select(2, line:sub(1,str_end):gsub(quote,''))%2==1 ) then
				inString=false
			end
		end
		return pos, endPos
	end

	local function GetSym(sym,curPos,code,tries) -- NOTE: GetSym is used to Uncomment in a particular order, it doesn't ensure the validity of a sym in any circumstance
		local pos, endPos = code:find(sym, curPos)
		if not pos then
			return
		end
		local line,sol = code:line(pos)
		pos, endPos = CheckIfValid(pos - sol + 1, line, sym, endPos - sol + 1)-- convert to pos of the line
		if not pos then
			tries = (tries or 0) + 1 if tries>500 then Echo('TOO MANY TRIES 3') return end
			return GetSym(sym,sol+line:len(),code,tries)
		end
		return pos and pos + sol - 1, line, sol, endPos and endPos + sol - 1
	end

	local function ReachEndOfFunction(pos,code) -- NOTE: ReachEndOfFunction is used to Uncomment in a particular order, it doesn't ensure it will find the function in any circumstance
		local l,r = '[%s%)}%]]','[%s%(%[{]'
		local openings = {l..'if'..r, l..'else'..r, l..'do'..r, l..'elseif'..r, l..'function'..r}
		local ending = l..'end'..r
		local _
		local o,c
		local nomore_o,nomore_c
		local check = function()
		end
		-- get any openings until we get an even number of 'end'
		local sum = 1 -- it is assumed that the 'function' starting pos has already been found and the given pos is at least one char ahead of this starting pos, so we start at sum = 1
		local tries = 0
		while sum>0 do
			tries = tries+1 if tries>500 then Echo('ERROR, TOO MANY FUNC TRIES') break end
			-- get the next end
			if not (c or nomore_c) then
				_,c = code:find(ending,pos+1)
				nomore_c = not c
			end
			-- get the next opening
			if not (o or nomore_o) then
				for _, opening in ipairs(openings) do
					local _,this_o = code:find(opening,pos+1)
					if this_o and (not o or this_o < o) then
						o = this_o
					end
				end
				nomore_o = not o
			end
			if c and (not o or c < o) then
				pos,c = c, false
				sum = sum - 1 
			elseif o then
				pos,o = o, false
				sum = sum + 1 
			else
				Echo('ERROR, FUNCTION NEVER ENDED')
				break
			end
		end
		return pos
	end
	-- NOTE: GetClosure doesn't ensure finding closure in any circonstances (block and comment preprocess is needed)
	-- GetClosure can work with any string, even same strings, same strings will be considered closing or opening aiming at make it even
	local function GetClosure(code, opening,closing, startpos) -- actually string.match got a method with %b
		local pos, sum = startpos or 1, 0
		local start
		local tries = 0
		while pos do
			tries = tries+1
			if tries>100 then
				Echo('ERROR, too many tries')
				return
			end
			local open,_,_,end_open = GetSym(opening,pos,code)

			local close,_,_,end_close = GetSym(closing,pos,code)

			if not (start or open) then
				-- Echo('ERROR, no opening: '..opening..' found.')
				return
			elseif not start then
				start = open
			elseif not close then
				-- Echo('ERROR, no (more) closing "'..closing..'" found, closure never ended')
				return start
			end
			if open and close then
				-- case both opening and closing are found at same pos, either because they are the same or because they start the same
				if open==close then
					-- same pos, we select the one that make it even 
					if sum%2==1 then 
						open = nil
					else
						close = nil
					end
				elseif close<open then
					open = nil
				else
					close = nil
				end
			end
			sum = sum + (open and 1 or close and -1)
			if sum==0 then
				return start,end_close
			end
			pos = (open and end_open+1 or close and end_close+1)
		end
	end


	local function UncommentCode(code,removeComLine)

		
		code = code:codeescape() -- code the escaped chars so we won't get fooled by them
		local t,n = {}, 0

		local commentSym ='%-%-'
		local blockSym = '%[%['
		local endBlockSym = '%]%]'
		local charSym = '%S'
		local tries = 0

		local curPos,newPos,_ = 0
		local comStart, line, sol
		local block = GetSym(blockSym,curPos,code)

		-- we register the pos of the very next block symbol
		-- we register the pos of the very next comment symbol
		-- if the block is before the comment we verify the validity of the block by jumping to its line and checking if it's just chars in a string
		-- , or if there is another valid block in this line
		while curPos do
			tries = tries +1 if tries>3000 then Echo('TOO MANY TRIES', tries) break end
			curPos = curPos+1
			if not comStart then
				comStart, line, sol = GetSym(commentSym,curPos,code) 
			end
			local part
			if not comStart then
				-- no more comment, we pick the remaining code
				part = code:sub(curPos)
			elseif block and comStart>=block-2 then
				-- the very next block is before the very next comment or it is a block comment
				_,newPos = code:find(endBlockSym,block+2)
				if comStart==block-2 then
					-- this is a block comment, we keep what is behind, we add a space at the end in order to not stick the before and the after
					part = code:sub(curPos,comStart-1)..' '
					comStart = false
				else
					-- block is valid and comment is after the start of block, this is a block string, we can safely pick everything until the end of the block
					part = code:sub(curPos,newPos)
					if not newPos or comStart<newPos then
						-- the comment symbol was inside the block, or the block never ended (latter shouldn't happen if the code is valid)
						comStart = false
					end
				end
				 -- if no newPos, the block never ended
				block = newPos and GetSym(blockSym,newPos+1,code)
			else
				-- this is usual uncommenting
				-- look if no char is left on the (last) line to pick after uncommenting
				local _,chars = code:sub(sol,comStart-1):gsub(charSym,'')
				-- set it to sol-1 instead of sol-2 if you want to keep the empty newline after uncommenting
				-- set it to comStart-1 no matter what if you want to keep also the non characters (tabs or spaces usually)
				local endPart = chars==0 and sol-(removeComLine and 2 or 1) or comStart-1 
				if curPos<endPart then
					part = code:sub(curPos,endPart)..'\n'
				end
				newPos = code:find('\n',comStart)
				comStart = false
			end
			if part then
				n = n + 1
				t[n], part = part:decodeescape(), false
			end
			curPos, newPos = newPos, false
		end

		return table.concat(t)
	end
	local function GetTableOrderFromCode(code,nameVar,occurrence,uncommented,thetable,noMissing)
		-- return array of keys of a table as it appear in the code
		-- occurrence, to select which table to pick as it appear reading the code, by default pick the last
		-- NOTE: case with auto exec function are not (yet?) covered eg: local t = (function() return {} end)()
		-- case with keys defined by variable or string is not covered either, I wouldn't see how it is possible to get the correct values used
		-- therefore, keys must be written litterally or, if the table is given as argument or is accessible by checkings globals and locals, the missings keys will be added at the end
		local t,gotAlready = {}, {}
		if type(nameVar)~='string' then
			Echo('ERROR, ',nameVar, 'is not a string')
			return t
		end
		-- we have to uncomment all the code in case of block comment so we don't fall on a fake table
		if not uncommented then
			code = UncommentCode(code,true)
		end
		-- code the escaped symbol so we don't get fooled
		code = code:codeescape()
		-- we have to remove every string blocks so we don't fall again in a fake table
		code = code:gsub("%[%[.-%]%]","")
		
		local tries = 0
		local pos,_ = 1
		local tcode
		local current = 0
		while tries<(occurrence or 20) do
			_,_,_,pos = GetSym(nameVar..'%s-=%s-{',pos,code)
			tries = tries+1
			if not pos then
				if occurrence then
					Echo('ERROR, no valid initialization of '..nameVar..' found at desired occurrence. Ended at occurrence '..current)
				end
				break
			end
			current=current+1
			if not occurrence or current==occurrence then
				local str_start, str_end = GetClosure(code, '{','}', pos)

				tcode = str_end and code:sub(str_start,str_end)
				if occurrence then
					break
				end
			end
			pos = pos + 1
		end
		if not tcode then
			Echo('ERROR, no valid table of '..nameVar..' has been found.')
			return t
		end

		-- this way works but not with key wrote with variable and string
		-- remove any string so we don't get fooled by non-code
		-- Spring.SetClipboard(tcode)
		tcode = tcode:gsub("([\"\']).-%1","")
		-- remove any double equal
		tcode = tcode:gsub("==","")
		-- remove any subtable so we get only our first level keys with an equal sign
		tcode = '{'..tcode:sub(2):gsub("%b{}","")
		-- remove functions
		local funcpos = tcode:find('function')
		while funcpos do
			local endPos = ReachEndOfFunction(funcpos+1,tcode)
			if funcpos==endPos then Echo('ERROR, never found anything after "function" ') break end
			tcode = tcode:sub(1,funcpos-1)..tcode:sub(endPos+1)
			funcpos = tcode:find('function')
		end
		--
		tcode:decodeescape()
		-- now we can get our keys
		for k in tcode:gmatch('[{,]%s-([%w_]+)%s-%=') do
			if not gotAlready[k] then
				table.insert(t,k)
				gotAlready[k] = true
			end
		end

		-- if the table has already been initialized at this point and is accessible from here, the verif can occur
		local obj = thetable or (function() for i=3,8 do local obj = GetLocal(i,nameVar) if obj then return obj end end end)() or widget[nameVar]

		if obj then
			local k=1
			while  t[k] do
				if obj[t[k]]==nil then 
					-- Echo('BAD KEY: '..t[k])
					table.remove(t,k)
				else
					k=k+1
				end
			end
			for k in pairs(obj) do
				if not gotAlready[k] then
					if noMissing then
						table.insert(t,k) -- putting the missing keys at the end
					end
					-- Echo(k..' IS MISSING')
				end
			end
		end
		return t
	end
	local code = UncommentCode(GetWidgetCode(),true)
	varIndex = GetTableOrderFromCode(code,"varDescs",nil,true,varDescs,true)
	constIndex = GetTableOrderFromCode(code,"constDescs",nil,true,constDescs,true)

end



if f then
	f.DebugWidget(widget)
end
--------------------------------------------------------------------------------
---------------------------------------------------------------------------------

