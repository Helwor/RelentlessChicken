local Echo = Spring.Echo
local tobool = Spring.Utilities.tobool
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local modoptions = Spring.GetModOptions() or {}
if modoptions.miniQueenTime then
	if modoptions.miniQueenTime==0 then
		modoptions.miniQueenTime = nil
	end
	modoptions.miniQueenTime = {modoptions.miniQueenTime}
end


--------------------------------------------------------------------------------
-- system

spawnSquare				= 150	   -- size of the chicken spawn square centered on the burrow
spawnSquareIncrement	= 1		 -- square size increase for each unit spawned
burrowName				= "roost"   -- burrow unit name

gameMode				= true

endlessMode				= tobool(modoptions.chicken_endless)

tooltipMessage			= "Kill chickens and collect their eggs to get metal."

mexesUnitDefID = {
	[-UnitDefNames.staticmex.id] = true,
}
mexes = {
	"staticmex",
}
noTarget = {
	terraunit=true,
	wolverine_mine=true,
	roost=true,
}

diff_order = {
	[0] = 0,
	[1] = 'Chicken: Beginner',
	[2] = 'Chicken: Very Easy',
	[3] = 'Chicken: Easy',
	[4] = 'Chicken: Normal',
	[5] = 'Chicken: Hard',
	[6] = 'Chicken: Suicidal',
	[7] = 'Chicken: Custom',
}

defaultDifficulty = diff_order[4]
testBuilding 	= UnitDefNames["energypylon"].id	--testing to place burrow
testBuildingQ 	= UnitDefNames["chicken_dragon"].id	--testing to place queen

--------------------------------------------------------------------------------

base_values = {

	maxBurrows				= 50
	,minBaseDistance		= 1000
	,maxBaseDistance		= 3500
	,maxAge					= 5*60	  -- chicken die at this age, seconds

	,alwaysVisible			= true	 -- chicken are always visible

	,alwaysEggs				= true			--spawn limited-lifespan eggs when not in Eggs mode?
	,eggDecayTime			= 180
	,burrowEggs				= 15	   -- number of eggs each burrow spawns

	,playerMalus			= 1		 -- how much harder it becomes for each additional player, exponential (playercount^playerMalus = malus)	-- used only for burrow spawn rate and queen XP

	,queenName				= "chickenflyerqueen"
	,queenMorphName			= "chickenlandqueen"
	,miniQueenName			= "chicken_dragon"

	,burrowSpawnRate		= 45		-- faster in games with many players, seconds
	,chickenSpawnRate		= 50
	,waveRatio				= 0.6	   -- waves are composed by two types of chicken, waveRatio% of one and (1-waveRatio)% of the other
	,baseWaveSize			= 2.5		 -- multiplied by malus, 1 = 1 squadSize of chickens
	,waveSizeMult			= 1
	--,forceBurrowRespawn	 = false	-- burrows always respawn even if the modoption is set otherwise
	,queenSpawnMult			= 4		 -- how many times bigger is a queen hatch than a normal burrow hatch

	,defensePerMin			= 0.5	-- number of turrets added to defense pool every wave, multiplied by playercount
	,defensePerBurrowKill	= 0.5	-- number of turrets added to defense pool for each burrow killed

	,gracePeriod				= 180	   -- no chicken spawn in this period, seconds
	,gracePenalty			= 15		-- reduced grace per player over one, seconds
	,gracePeriodMin			= 90
	,rampUpTime				= 0	-- if current time < ramp up time, wave size is multiplied by currentTime/rampUpTime; seconds

	,queenTime				= 60*60	-- time at which the queen appears, seconds
	,queenMorphTime			= {60*30, 120*30}	--lower and upper bounds for delay between morphs, gameframes
	,queenHealthMod			= 1
	,miniQueenTime			= {0.6}		-- times at which miniqueens are spawned (multiplier of queentime)
	,endMiniQueenWaves		= 7		-- waves per miniqueen in PvP endgame

	,burrowQueenTime		= 15		-- how much killing a burrow shaves off the queen timer, seconds
	,burrowWaveSize			= 1.2		-- size of contribution each burrow makes to wave size (1 = 1 squadSize of chickens)
	,burrowRespawnChance 	= 0.15
	,burrowRegressTime		= 30		-- direct tech time regress from killing a burrow, divided by playercount ratioed by how easy it is to kill a burrow

	,humanAggroPerBurrow	= 1			-- base aggro gain per burrow killed
	,humanAggroTeamScaling	= 1.2       -- the more it is, the less team loose aggro per player per nest killed
	,humanAggroDecay		= 0.30		-- how much aggro is lost per minute of game time
	,humanAggroMin			= -100
	,humanAggroMax			= 100
	,humanAggroWaveFactor	= 1
	,humanAggroWaveMax		= 5
	,humanAggroDefenseFactor	= 0.6	-- turrets issued per point of aggro per minute, multiplied by playercount
	,humanAggroTechTimeProgress	= 24	-- how much to increase chicken tech progress per positive aggro point, seconds
	,humanAggroTechTimeRegress	= 0	-- how much to reduce chicken tech progress per negative aggro point, seconds
	,humanAggroQueenTimeFactor	= 1	-- burrow queen time is multiplied by this and aggro (after clamping)
	,humanAggroQueenTimeMin	= 0	-- min value of aggro for queen time calc
	,humanAggroQueenTimeMax	= 8

	,techAccelPerPlayer		= 4.8	-- base of tech malus per minute per player, for each player techAccelperPlayer is divided more and then added
	,techAccelTeamScaling   = 1.2   -- oscillate around 1, factor the divisor of techAccelPerPlayer 
	-- techMalusMultiplayer = 0
	-- for i=2,playerCount do
	-- 	techMalusMultiplayer = techMalusMultiplayer + (techAccelPerPlayer/(i*techAccelTeamScaling))
	-- end
	,techTimeFloorFactor	= 0.5	-- tech timer can never be less than this * real time
	,techTimeMax			= 999999
	,techTimeMult			= 1
	,specialChickChance		= 1/25    -- chance of getting next tech chicken per burrow per wave

	,timeSpawnBonus			= .04
	,scoreMult				= 1
}

local mustBeRound = {
	endMiniQueenWaves = true
	,gracePeriod = true
	,gracPeriodMin = true
	,queenMorphTime = true
	,gracePenalty = true
	,maxBurrows = true
	,burrowEggs = true
	,maxAge = true
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include("LuaRules/Utilities/tablefunctions.lua")


local function Copy(original)   -- Warning: circular table references lead to
	local copy = {}			   -- an infinite loop.
	for k, v in pairs(original) do
		if (type(v) == "table") then
			copy[k] = Copy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

local floor = math.floor
local round = function (n,dec)
	if dec then 
		local mult = 10^(dec)
		return floor(n*mult + 0.5) / mult
	else
		return floor(n + 0.5)
	end
end



local function TimeModifier(d, mod)
	for chicken, t in pairs(d) do
		t.time = t.time*mod
		if (t.obsolete) then
			t.obsolete = t.obsolete*mod
		end
	end
end


local function ModValue(value,param,base)
	base = base and base[param] or base_values[param]
	if type(value)=='table' then
		for i,v in ipairs(value) do
			value[i]=base[i] * v
			value[i] = round(value[i], not mustBeRound[param] and 3)
		end
	else
		if value<0 then -- "+ something" mod is not implemented (yet?)
			value = base + value	
		else
			value = round(value * base, not mustBeRound[param] and 3)
		end
	end
	if param=='miniQueenTime' and value[1]==0 then
		value[1]=nil
	elseif param=='queenTime' then
		value = round(value/60)*60
	end
	return value
end
local function ModTable(modT,base,dest) -- create or implement a table of modified values
	base = base or base_values
	local t = {}
	for oldParam,value in pairs(modT) do
		local param,isMod = oldParam:gsub('_mod$','')
		if isMod==1 then
			t[param] = ModValue(value,param,base)
		else
			t[oldParam]=value
		end
	end
	if dest then
		for k,v in pairs(t) do
			dest[k]=v
		end
	end
	return t
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- times in minutes

chickenTypes = Spring.Utilities.CustomKeyToUsefulTable(Spring.GetModOptions().campaign_chicken_types_offense) or {
	chicken				=  {time = -60,  squadSize = 3, obsolete = 25},
	chicken_pigeon		=  {time = 6,  squadSize = 1.4, obsolete = 35},
	chickens			=  {time = 12,  squadSize = 1, obsolete = 35},
	chickena			=  {time = 18,  squadSize = 0.5, obsolete = 40},
	chickenr			=  {time = 24,  squadSize = 1.2, obsolete = 45},
	chicken_leaper	    =   not tobool(modoptions.noleaper)
							and {time = 24,  squadSize = 2, obsolete = 45}
							or  nil,
	chickenwurm			=  {time = 28,  squadSize = 0.7},
	chicken_roc			=  {time = 28,  squadSize = 0.4},
	chicken_sporeshooter=  {time = 32,  squadSize = 0.5},
	chickenf			=  {time = 32,  squadSize = 0.5},
	chickenc			=  {time = 40,  squadSize = 0.5},
	chickenblobber		=  {time = 40,  squadSize = 0.3},
	chicken_blimpy		=  {time = 48,  squadSize = 0.2},
	chicken_tiamat		=  {time = 55,  squadSize = 0.2},
}

defenders = Spring.Utilities.CustomKeyToUsefulTable(Spring.GetModOptions().campaign_chicken_types_defense) or {
  chickend = {time = 10, squadSize = 0.6, cost = 1 },
  chicken_dodo = {time = 25,  squadSize = 2, cost = 1},
  chicken_rafflesia =  {time = 25, squadSize = 0.4, cost = 2 },
}

supporters = Spring.Utilities.CustomKeyToUsefulTable(Spring.GetModOptions().campaign_chicken_types_support) or {
  chickenspire =  {time = 50, squadSize = 0.1},
  chicken_shield =  {time = 30, squadSize = 0.4},
  chicken_dodo = {time = 25, squadSize = 2},
  chicken_spidermonkey =  {time = 20, squadSize = 0.6},
}

-- TODO
-- cooldown is in waves
specialPowers = Spring.Utilities.CustomKeyToUsefulTable(Spring.GetModOptions().campaign_chicken_types_special) or {
	{name = "Digger Ambush", maxAggro = -2, time = 15, obsolete = 40, unit = "chicken_digger", burrowRatio = 1.25, minDist = 100, maxDist = 450, cooldown = 3*50, targetHuman = true},
	{name = "Wurmsign", maxAggro = -3, time = 40, unit = "chickenwurm", burrowRatio = 0.2, cooldown = 4*50},
	{name = "Spire Sprout", maxAggro = -4.5, time = 20, unit = "chickenspire", burrowRatio = 0.15, tieToBurrow = true, cooldown = 3*50},
	{name = "Rising Dragon", maxAggro = -8, time = 30, unit = "chicken_dragon", burrowRatio = 1/12, minDist = 250, maxDist = 1200, cooldown = 5*50, targetHuman = true},
	{name = "Dino Killer", maxAggro = -12, time = 40, unit = "chicken_silo", minDist = 1500},
}

local function SetCustomMiniQueenTime()
	if modoptions.miniqueentime then
		if modoptions.miniqueentime == 0 then return nil
		else return modoptions.miniqueentime end
	else
		return base_values.miniQueenTime[1]
	end
end
-- rule : 
-- modes_base are overriding base_values if those modes are set
-- then difficulties param with "_mod" mod the base_values for their difficulty, those without "_mod" simply replace them
-- then custom difficulty get params of set difficulty: normal by default or the AI difficulty set in options (chickenailevel)
-- then those custom params are overridden by specified modoptions params
-- then if mode like relentless or speed chicken are set, params are modified or replaced by those modes params as in previous step when setting difficulties
difficulties = {
	['Chicken: Beginner'] = {
		chickenSpawnRate_mod		 = 3.6,
		burrowSpawnRate_mod			 = 4,
		maxBurrows_mod				 = 0.08,
		gracePeriod_mod				 = 2.5,
		rampUpTime					 = 1200,
		waveSizeMult_mod			 = 0.5,
		timeSpawnBonus_mod			 = 0.25,
		miniQueenName				 = 'chicken_tiamat',
		queenTime_mod				 = 1,
		queenName					 = 'chicken_dragon',
		queenMorphName				 = '',
		techAccelPerPlayer_mod		 = 0.325,
		techTimeFloorFactor_mod	 	 = 0.4,
		specialPowers				 = {},
		specialChickChance_mod		 = 0,
		scoreMult_mod				 = 0.12,

	},
	['Chicken: Very Easy'] = {
		chickenSpawnRate_mod		 = 1.8,
		burrowSpawnRate_mod			 = 2,
		maxBurrows_mod				 = 0.2,
		gracePeriod_mod				 = 5/3,
		rampUpTime					 = 900,
		waveSizeMult_mod			 = 0.6,
		timeSpawnBonus_mod			 = 0.625,
		miniQueenName				 = 'chicken_tiamat',
		queenTime_mod				 = 0.667,
		queenName					 = 'chicken_dragon',
		queenMorphName				 = '',
		techAccelPerPlayer_mod		 = 0.5,
		techTimeFloorFactor_mod		 = 0.8,
		specialPowers				 = {},
		specialChickChance_mod		 = 0.05,
		scoreMult_mod				 = 0.25
	},
	['Chicken: Easy'] = {
		chickenSpawnRate_mod		 = 1.2,
		burrowSpawnRate_mod			 = 10/9,
		gracePeriod_mod				 = 1,
		rampUpTime					 = 480,
		waveSizeMult_mod			 = 0.8,
		timeSpawnBonus_mod			 = 0.75,
		queenHealthMod_mod			 = 0.5,
		techAccelPerPlayer_mod		 = 1,
		specialChickChance_mod		 = 1/3,
		scoreMult_mod				 = 0.66
	},
	['Chicken: Normal'] = {
	},
	['Chicken: Hard'] = {
		chickenSpawnRate_mod		 = 0.9,
		burrowSpawnRate_mod			 = 1,
		burrowWaveSize_mod			 = 7/6,
		waveSizeMult_mod			 = 1.2,
		timeSpawnBonus_mod			 = 1.25,
		miniQueenTime_mod			 = {5/6},
		queenSpawnMult_mod			 = 1.25,
		queenHealthMod_mod			 = 1.5,
		techAccelPerPlayer_mod		 = 1.25,
		techTimeMult_mod			 = 7/8,
		specialChickChance_mod		 = 1.5,
		scoreMult_mod				 = 1.25
	},
	['Chicken: Suicidal'] = {
		chickenSpawnRate_mod		 = 0.9,
		burrowSpawnRate_mod			 = 8/9,
		burrowRespawnChance_mod		 = 5/3,
		gracePeriod_mod				 = 5/6,
		gracePeriodMin_mod			 = 1/3,
		burrowWaveSize_mod			 = 4/3,
		waveSizeMult_mod			 = 1.5,
		timeSpawnBonus_mod			 = 1.5,
		miniQueenTime_mod			 = {0.75},
		endMiniQueenWaves_mod		 = -1,
		queenTime_mod				 = 5/6,
		queenSpawnMult_mod			 = 1.25,
		queenHealthMod_mod			 = 2,
		techAccelPerPlayer_mod		 = 1.5,
		techTimeMult_mod			 = 0.75,
		specialChickChance_mod		 = 2,
		scoreMult_mod				 = 2
	},
	['Chicken: Custom'] = {
	}
}

modes = {
	['Speed Chicken']={
		techTimeMult_mod = 0.5,
		waveSizeMult_mod = 0.85,
		gracePeriod_mod = 0.5,
		gracePenalty_mod = 0.5,
		gracePeriodMin_mod = 0.5,
		timeSpawnBonus_mod = 1.5,
		queenTime_mod = 0.5,
		queenHealthMod_mod = 0.4,
		miniQueenTime = {},
		endMiniQueenWaves_mod = -1,
		burrowQueenTime_mod = 0.5,
		techAccelPerPlayer_mod = 0.5,
		humanAggroTechTimeProgress_mod = 0.5,
		burrowRegressTime_mod = 0.5,
		queenSpawnMult_mod = 0.4,
	},
	['Relentless']={
		maxBurrows_mod = 2,
		burrowSpawnRate_mod = 0.5,
		chickenSpawnRate_mod = 0.1,
		waveSizeMult_mod = 0.01,
		gracePeriod_mod = 1/6,
		minBaseDistance = 400,
		gracePeriodMin = 30,
 		supporters = {
			chickenspire =  {time = 50, squadSize = 0.1},
			chicken_shield =  {time = 25, squadSize = 0.4}, -- changed base time from 30 to 25
			chicken_dodo = {time = 25, squadSize = 2},
			chicken_spidermonkey =  {time = 20, squadSize = 0.6},
		}
	}
}

-- those values replace the starting values before applying mods
local modes_base = {
	['Relentless']={
		specialChickChance = 1/50,
	}
}


if modoptions.chicken_minaggro then
	base_values.humanAggroMin = tonumber(modoptions.chicken_minaggro)
end
if modoptions.chicken_maxaggro then
	base_values.humanAggroMax = tonumber(modoptions.chicken_maxaggro)
end
if modoptions.chicken_maxtech then
	base_values.techTimeMax = tonumber(modoptions.chicken_maxtech)
end


for name,diff in pairs(difficulties) do
	if not name:match('Custom') then
		local new_diff = {}
		-- start a table with the mode base values
		if tobool(modoptions.relentless) and modes_base['Relentless'] then
			new_diff = Copy(modes_base['Relentless'])
		end
		-- apply the difficulty mods and overrides, using that starting table (and also base_values) as base
		ModTable(diff,new_diff, new_diff)

		-- apply the modes mods and overrides
		if tobool(modoptions.speedchicken) then
			ModTable(modes['Speed Chicken'],new_diff,new_diff)
		end
		if tobool(modoptions.relentless) then
			ModTable(modes['Relentless'],new_diff,new_diff)
		end

		if modoptions.chicken_nominiqueen then
			new_diff.miniQueenTime = {}
		end

		difficulties[name] = new_diff
	end
end

-- set the custom params according to the modoptions or the custom AI (if set to a real difficulty, else it will default to normal difficulty)
local customAI = modoptions.chickenailevel
local customBase = difficulties[customAI~='Chicken: Custom' and customAI or 'Chicken: Normal']
local custom = difficulties['Chicken: Custom']
for param, v_base in pairs(base_values) do
	-- verify all the values
	local value = modoptions[param:lower()] or customBase[param]
	if value and type(v_base)=='table' and type(value)~='table' then
		value = {value}
	end
	if  value then
		custom[param] = value
	end
end



-- minutes to seconds
TimeModifier(chickenTypes, 60)
TimeModifier(defenders, 60)
TimeModifier(supporters, 60)
TimeModifier(specialPowers, 60)

--[[
for chicken, t in pairs(chickenTypes) do
	t.timeBase = t.time
end
for chicken, t in pairs(supporters) do
	t.timeBase = t.time
end
for chicken, t in pairs(defenders) do
	t.timeBase = t.time
end
]]--
for name, d in pairs(difficulties) do
	d.timeSpawnBonus = (d.timeSpawnBonus or base_values.timeSpawnBonus)/60
	d.chickenTypes = d.chickenTypes or Copy(chickenTypes)
	d.defenders = d.defenders or Copy(defenders)
	d.supporters = d.supporters or Copy(supporters)
	d.specialPowers = d.specialPowers or Copy(specialPowers)
	-- applying mod/override to difficulties


	TimeModifier(d.chickenTypes, d.techTimeMult or 1)
	TimeModifier(d.defenders, d.techTimeMult or 1)
	TimeModifier(d.supporters, d.techTimeMult or 1)
end

difficulties['Chicken: Very Easy'].chickenTypes.chicken_pigeon.time = 8*60
difficulties['Chicken: Very Easy'].chickenTypes.chicken_tiamat.time = 999999

difficulties['Chicken: Beginner'].chickenTypes.chicken_pigeon.time = 11*60
difficulties['Chicken: Beginner'].chickenTypes.chicken_tiamat.time = 999999



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Below code has been used to rewrite difficulties and make them multipliers

if false then
	-- original difficulties table
	local _difficulties = {
		['Chicken: Beginner'] = {
			chickenSpawnRate = 180,
			burrowSpawnRate  = 180,
			gracePeriod      = 450,
			rampUpTime       = 1200,
			waveSizeMult     = 0.5,
			timeSpawnBonus   = 0.010, -- how much each time level increases spawn size
			queenTime        = 60*60,
			queenName        = "chicken_dragon",
			queenMorphName   = '',
			miniQueenName    = "chicken_tiamat",
			maxBurrows       = 4,
			specialPowers    = {},
			techAccelPerPlayer = 1.3,
			techTimeFloorFactor = 0.2,
			scoreMult        = 0.12,
		},
		
		['Chicken: Very Easy'] = {
			chickenSpawnRate = 90,
			burrowSpawnRate  = 90,
			gracePeriod	  = 300,
			rampUpTime	   = 900,
			waveSizeMult	 = 0.6,
			timeSpawnBonus   = .025,	 -- how much each time level increases spawn size
			queenTime		 = 40*60,
			queenName		= "chicken_dragon",
			queenMorphName	 = '',
			miniQueenName	 = "chicken_tiamat",
			maxBurrows	   = 10,
			specialPowers	 = {},
			techAccelPerPlayer = 2,
			techTimeFloorFactor = 0.4,
			scoreMult		 = 0.25,
		},

		['Chicken: Easy'] = {
			chickenSpawnRate = 60,
			burrowSpawnRate  = 50,
			gracePeriod	  = 180,
			rampUpTime	   = 480,
			waveSizeMult	 = 0.8,
			timeSpawnBonus   = .03,
			queenHealthMod	 = 0.5,
			techAccelPerPlayer = 4,
			scoreMult		 = 0.66,
		},

		['Chicken: Normal'] = {
		},

		['Chicken: Hard'] = {
			chickenSpawnRate = 45,
			burrowSpawnRate  = 45,
			waveSizeMult	 = 1.2,
			timeSpawnBonus   = .05,
			burrowWaveSize	 = 1.4,
			queenHealthMod	 = 1.5,
			queenSpawnMult   = 5,
			miniQueenTime	 = {0.5},
			techAccelPerPlayer	= 5,
			scoreMult		 = 1.25,
			techTimeMult	 = 0.875,
		},
		
		['Chicken: Suicidal'] = {
			chickenSpawnRate = 45,
			burrowSpawnRate  = 40,
			waveSizeMult	 = 1.5,
			timeSpawnBonus   = .06,
			burrowWaveSize	 = 1.6,
			gracePeriod		 = 150,
			gracePeriodMin	 = 30,
			burrowRespawnChance = 0.25,
			--burrowRegressTime	= 25,
			queenSpawnMult   = 5,
			queenTime		 = 50*60,
			queenHealthMod	 = 2,
			miniQueenTime	 = {0.45}, --{0.37, 0.75},
			endMiniQueenWaves	= 6,
			techAccelPerPlayer	= 6,
			techTimeMult	 = 0.75,
			scoreMult		 = 2,
		},

		['Chicken: Custom'] = {
			chickenSpawnRate = modoptions.chickenspawnrate or 50,
			burrowSpawnRate  = modoptions.burrowspawnrate or 45,
			waveSizeMult    = modoptions.wavesizemult or 1,
			timeSpawnBonus   = .04,
		--	chickenTypes	 = Copy(chickenTypes),
		--	defenders		= Copy(defenders),
			queenTime		= (modoptions.queentime or 60)*60,
			miniQueenTime	= { SetCustomMiniQueenTime() },
			gracePeriod		= (modoptions.graceperiod and modoptions.graceperiod * 60) or 180,
			gracePenalty	= 0,
			gracePeriodMin	= 30,
			burrowQueenTime	= (modoptions.burrowqueentime) or 15,
			queenHealthMod	= modoptions.queenhealthmod or 1,
			techTimeMult	= modoptions.techtimemult or 1,
			scoreMult		= 0,
		},
	}


	local param_order = {
		'minBaseDistance',

		'chickenSpawnRate',
		'burrowSpawnRate',

		'maxBurrows',
		'burrowRespawnChance',

		'gracePeriod',
		'gracePenalty',
		'gracePeriodMin',

		'rampUpTime',
		'burrowWaveSize',
		'waveSizeMult',
		'timeSpawnBonus', -- how much each time level increases spawn size

		'miniQueenName',
		'miniQueenTime',
		'endMiniQueenWaves',
		
		'queenTime',
		'queenName',
		'queenMorphName',
		'queenSpawnMult',
		'queenHealthMod',
		'burrowQueenTime',

		'techAccelPerPlayer',
		'techTimeFloorFactor',
		'techTimeMult',

		'specialPowers',
		'scoreMult',
	}
	for i,param in ipairs(param_order) do
		param_order[param]=i
	end

	-- local function TrimComma(str)
	-- 	return (str:gsub(',%s*$',''))
	-- end
	-- local function roundtrim(n,maxdec)
	-- 	return (('%.'..maxdec..'f'):format(n):gsub('%.?0+$',""))
	-- end

	local function TrimComma(str)
		local pos = str:find(',%s*$')
		if pos then
			str = str:sub(1,pos-1)
		end
		return str:gsub(',%s*','')
	end
	local function TrimZeroes(n,maxdec)
		local str = ('%.'..maxdec..'f'):format(n)
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




	local function WriteValue(v,v_base,wantMult)
		return wantMult and TrimZeroes(v/v_base,3) or type(v)=='string' and "'"..v.."'" or v
	end
	local function WritePair(param,v,v_base)
		local v_base = base_values[param]
		local wantMult = v_base and v_base~=0 and not mustBeRound[param] and param~='specialPowers' and type(v)~='string'
		if wantMult then
			param = param..'_mod'
		end
		local value=""
		if type(v)=='table' then
			for i,tv in ipairs(v) do
				value = value..WriteValue(tv,v_base[i],wantMult)..', '
			end
			value = '{'..TrimComma(value)..'}'
		else
			value = WriteValue(v,v_base,wantMult)
		end
		return param..('\t'):rep(7-math.floor(param:len()/4))..' = '..value
	end

	local function WriteModeMultipliers()
		local str = "difficulties = {"
		for i, name in ipairs(diff_order) do
			local difficulty = _difficulties[name]
			if difficulty and not name:find('Custom') then
				str = str.."\n\t['"..name.."'] = {"
				for i, param in ipairs(param_order) do
					if difficulty[param] then
						str = str..'\n\t\t'..WritePair(param,difficulty[param])..','
					end
				end
				for param,v in pairs(difficulty) do
					if not param_order[param] then
						str=str..'\n\t\t'..WritePair(param,v)..','
					end
				end
				str = TrimComma(str)..'\n\t},'
			end
		end
		str = TrimComma(str)..'\n}\n'
		Spring.SetClipboard(str)
	end

	WriteModeMultipliers()
end



