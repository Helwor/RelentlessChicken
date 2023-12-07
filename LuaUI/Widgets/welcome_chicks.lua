function widget:GetInfo()
	return {
		name      = "Chicken Mod Welcome",
		desc      = "welcome user to play the mod",
		author    = "Helwor",
		date      = "8 October 2022",
		license   = "GPL",
		layer     = 1000000,
		enabled   = true,
	}
end
panelTexture = LUAUI_DIRNAME.."Images/panel.tga"

include('keysym.lua')
local ESCAPE = KEYSYMS.ESCAPE
KEYSYMS = nil
local Echo = Spring.Echo
local spectating = Spring.GetSpectatingState()
local modoptions = Spring.GetModOptions()


local title, subtitle, description

if Spring.Utilities.tobool(modoptions.relentless) then
	title = "Welcome to Relentless Chicken Mod !"
	subtitle = "A continuous waving of chicken awaits for you..."
	description = [[
- Grace Period is only 30 sec,
  so prepare some units already

- aggression rating scale more reasonably
  with many players

- beware, burrows can spawn more closer to your units

- caretakers are buffed

- sometimes wave contains a few higher tech chicken

- and something might surprise you
  in the midgame...

]]
else
	title = "Welcome to Pimp My Chicken !"
	subtitle = "some advanced chickenry going on here"
	description = [[
- this mod allow a full customization of chicken games,
  If you want to create your own rules, you can click the buttons on the chicken TV
  that will give you a thorough explanation.

- what's new:
- aggression is better scaled per player

- custom AI level are now applied correctly
  when custom chicken are used

- chicken are not anymore stuck on unreachable target

- code has been optimized you should experience
  less slowering/lagging

- leapers are reintroduced but you can deactivate them
  with !setoptions noleaper = 1

- each wave can contain a few higher tech chicken
  to spice things up a bit



Helwor
]]
end

function widget:GameFrame()
	widgetHandler:RemoveWidget()
end
function widget:Initialize()
	VFS.Include("LuaRules/Configs/spawn_defs.lua", nil, VFS.ZIP)
	if spectating or Spring.GetGameFrame()>=1 then
		widgetHandler:RemoveWidget()
		return
	end
	local Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end

	local window = Chili.Window:New {
		-- caption = "welcome to the mod",
		parent = Chili.Screen0,
		caption="",
		color = {0,0,0,0},
		x = 0,
		y = 25,
		right = "74%",
		bottom = "50%",
		-- height = "20%",
		classname = "main_window",
		-- dockable = true;
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = false,
		minWidth = 300,
		minHeight = 200,
		padding = {0, 0, 0, 0},
	}
	local background = Chili.Image:New{
		width="100%";
		height="100%";
		y=0;
		x=0;
		color = {0,0,0,0.5},
		keepAspect = false,
		file = panelTexture;
		parent = window;
		disableChildrenHitTest = false,
	}
	Chili.Label:New {
		x = "10%",
		y = 20,
		right = 0,
		parent = background,
		align = "left",
		valign = "left",
		caption = title,
		fontsize = 16,
		textColor = {1,1,1,1},
	}
	Chili.Label:New {
		x = 5,
		y = 60,
		right = 0,
		parent = background,
		align = "left",
		valign = "left",
		caption = subtitle,
		fontsize = 13,
		textColor = {1,1,1,1},
		padding = {5, 0, 0, 0},
	}

	Chili.Label:New {
		x = 5,
		y = 85,
		right = 0,
		parent = background,
		align = "left",
		valign = "left",
		caption = description,
		fontsize = 12,
		textColor = {1,1,1,1},
	}
	Chili.Label:New {
		x = 5,
		-- y = "90%",
		right = 25,
		bottom = "10%",
		parent = background,
		align = "right",
		valign = "right",
		caption = "(press escape to close this window)",
		fontsize = 11,
		textColor = {1,1,1,1},
	}
end

function widget:KeyPress(key)
	if key == ESCAPE then
		widgetHandler:RemoveWidget()
		return true
	end
end