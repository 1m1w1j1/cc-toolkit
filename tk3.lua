local version = 20261108.1300
--[[
	**********Toolkit v3**********
	Last edited: see version YYYYMMDD.HHMM
	if NOT online:

Folder PATH listing from Windows cmd: tree /f /a |clip

|   tk3.lua
|
+---lib
|   |   Class.lua
|   |   clsTurtle.lua
|   |   EntityMgr.lua
|   |   Events.lua
|   |   help.lua
|   |   Log.lua
|   |   menu.lua
|   |   Scene.lua
|   |   SceneMgr.lua
|   |   TurtleUtils.lua
|   |   Vector2.lua
|   |
|   +---data
|   |       taskInventory.lua
|   |
|   \---ui
|           Button.lua
|           Checkbox.lua
|           Label.lua
|           MultiButton.lua
|           MultiLabel.lua
|           Textbox.lua
|
\---scenes
        Craft.lua
		GetItems.lua
        Help.lua
        MainMenu.lua
        Quit.lua
        TaskOptions.lua

	else
		lib/scenes folders will be created and files obtained automatically!
	end
]]

args = {...} -- eg "farm", "tree"


--[[
Computercraft started with mc version 1.7.10 and went to 1.8.9
ccTweaked started around mc 1.12.2 and currently at 1.21.1
mc 1.18 onwards has new blocks and bedrock at -64, so needs to be taken into account.
_HOST = The ComputerCraft and Minecraft version of the current computer environment.
For example, ComputerCraft 1.93.0 (Minecraft 1.15.2).
]]
local dbug = true -- debug is reserved word
local netherBedrock = 0
local deletesWater = false
local brick = "minecraft:nether_brick" -- pre 1.16+ name


local Version = require("lib.runtime.Version")
local Task = require("lib.runtime.Task")
_G.U = require("lib.TurtleUtils")
--*********************************LOGGING*********************************************************
_G.Log = require("lib.Log")
Log:setLogFileName("log.txt")
Log:deleteLog()
Log:setUseLog(true)
--*********************************GLOBAL VARIABLES*************************************************
_G.mcMajorVersion = 0	-- Minecraft major version default value 0 eg 1.18, 26.1
_G.mcMinorVersion = 0	-- Minecraft minor version default value 0 eg (1.18).2, (26.1)
_G.ccMajorVersion = 0	-- Computercraft major version default value 0 eg 1.93.0, 1.120.2
_G.ccMinorVersion = 0	-- Computercraft minor version default value 0 eg (1.93).0, (1.120).2

--[[
Netherite level start on 14
Chunk borders F3+G or:
math.floor(x / 16) * 16 add 16 for each border. same for z
]]

local mcParts, ccParts = Version.host(_HOST)
local mcVersion, ccVersion = table.concat(mcParts, "."), table.concat(ccParts, ".")
-- Legacy display fields retained; capability decisions use integer components.
_G.mcMajorVersion = tonumber(mcParts[1].."."..mcParts[2])
_G.mcMinorVersion = mcParts[3] or 0
_G.ccMajorVersion = tonumber((ccParts[1] or 0).."."..(ccParts[2] or 0))
_G.ccMinorVersion = ccParts[3] or 0
if Version.atLeast(mcParts,1,18) then U.bedrock=-64; U.ceiling=319 end
if Version.atLeast(mcParts,1,16) then brick="minecraft:nether_bricks" end
deletesWater = not Version.atLeast(mcParts,1,13)

local Turtle = require("lib.clsTurtle")
-- Global variables _G.mcMajorVersion, _G.mcMinorVersion, _G.ccMajorVersion,_G.ccMinorVersion MUST be declared before requiring turtle class
-- Turtle class (T), menu class (menu) and other libraries made Global
--_G.F is created at end of script: require("lib.data.taskInventory")
_G.T = Turtle(false)
_G.menu = require("lib.menu")
_G.R =
{
	auto = false,
	ceiling = false,
	choice = 0,
	currentLevel = 0,
	data = {},
	depth = 0,
	description = "",
	destinationLevel = 0,
	dimension = "",
	direction = "",
	down = false,
	earlyGame = false,
	floor = false,
	forward = false,
	goDown = false,
	goUp = false,
	height = 0,
	inAir = false,
	inNether = false,
	inventory = {},
	inventoryKey = "",
	left = false,
	legacy = false,
	length = 0,
	logType = "",
	lowerLevel = 0,
	menu = 0,
	message = "",
	misc = false,
	mysticalAgriculture = false,
	networkFarm = false,
	position = 1,
	ready = false,
	right = false,
	side = "",
	size = 0,
	silent = false,
	startLevel = 0,
	subChoice = 0,
	subMenu = 0,
	torchInterval = 0,
	treeSize = "",
	treeFarmVersion = 2,
	turtleCount = 1,
	up = false,
	upperLevel = 0,
	useBlockType = "",
	width = 0,
}



local utils = {}

function utils.calculateDimensions()
	if R.data == "" or R.data == "enclosed" then -- not being called from other functions
		if R.width == 0 then -- user chose auto settings
			R.length = utils.calculateDistance(R.length) -- still facing forward
			print("Calculated Length = "..R.length)
			T:turnRight(1) -- ready to check width
			R.width = utils.calculateDistance(R.width) -- now facing right
			print("Calculated width = "..R.width)
			T:go("R2F"..R.width - 1 .."L1".. "F"..R.length - 1 .."R2") -- back at start. width/length confirmed
		end
	end
	if R.height == 0 then -- use auto settings based on water detection
		R.height = 64
	end
end

function utils.calculateDistance(estDistance)
	--[[
	measure length
	movement stops when either solid block in front or solid below
	called from utils.calculateDimensions
	]]
	local moves = 1
	local nonSolidBelow = utils.clearVegetation("down")
	if estDistance == 0 then
		while nonSolidBelow and turtle.forward() do -- while able to move and air/water below
			moves = moves + 1
			nonSolidBelow = utils.clearVegetation("down")
		end
	else
		while moves < estDistance * 2 do -- loop can only run for max of double estimated distance
			if turtle.forward() then -- able to move forward
				moves = moves + 1
			else
				break
			end
			if not utils.clearVegetation("down") then -- solid below
				turtle.back()
				moves = moves - 1
				break
			end
		end
	end
	return moves
end

function utils.ceiling(blaze)
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	-- all outer walls complete, now for remaining 9x9 ceiling
	blaze = blaze or false
	for i = 1, 9 do
		for j = 1, 9 do
			if blaze then
				T:place("slab", "up", false)
				T:dig("down")
			else
				T:go("C0x2", false, 0, true)
			end
			if j < 9 then
				T:forward(1)
			else	-- end of length
				local place = false
				if i%2 == 1 then -- odd numbers 1,3,5,7,9
					if i < 9 then
						place = true
						T:go("R1F1 R1")
					end
				else
					place = true
					T:go("L1F1 L1")
				end
				if place then
					if blaze then
						T:place("slab", "up", false)
						T:dig("down")
					else
						T:go("C0x2", false, 0, true)
					end
				end
			end
		end
	end
end

function utils.checkFuelNeeded(quantity)
	if turtle.getFuelLevel() == "unlimited" then return end
	local fuelNeeded = quantity - turtle.getFuelLevel() -- eg 600
	if fuelNeeded > 0 then
		if T:checkInventoryForItem({"minecraft:lava_bucket"}, {1}, false) == nil then
			if T:checkInventoryForItem({"coal"}, {math.ceil(fuelNeeded / 60)}, false) == nil then
				T:checkInventoryForItem({"planks"}, {math.ceil(fuelNeeded / 15)})
			end
		end
		T:refuel(quantity, true)
	end
end

function utils.clearVegetation(direction)
	local isAirWaterLava = true	-- default true value air/water/lava presumed
	-- blockType, data
	local blockType = T:getBlockType(direction)
	if blockType ~= "" then --not air
		if T:isVegetation(blockType) then
			T:dig(direction)
		elseif blockType:find("water") == nil
			   and blockType:find("lava") == nil
			   and blockType:find("bubble") == nil
			   and blockType:find("ice") == nil then
			-- NOT water, ice or lava
			isAirWaterLava = false -- solid block
		end
	end

	return isAirWaterLava --clears any grass or sea plants, returns true if air or water, bubble column or ice
end

function utils.craftItem()
	--local message = U.loadStorageLists()	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	local message = U.wrapModem(true)	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	if message ~= "" then return {message} end
	----Log:saveToLog("call U.emptyInventory({'sapling', 'propagule', 'dirt', 'crafting'}, {'all'}, true)")
	U.emptyInventory({"sapling", "propagule", "dirt", "crafting"}, {"all"}, true)	-- 2 lists, one for barrels, one for chests
	----Log:saveToLog("\ncall U.getItemFromNetwork('barrel', 'minecraft:dirt', 169)")
	local turtleSlot, turtleCount = U.getItemFromNetwork("barrel", "minecraft:dirt", 169, nil, false)
	----Log:saveToLog("Get from barrel completed: turtleSlot = "..turtleSlot..", turtleCount = "..turtleCount..", ignoreStock = "..tostring(ignoreStock))
	if turtleCount < 169 then
		----Log:saveToLog("\ncall U.getItemFromNetwork('chest', 'minecraft:dirt', ".. 169 - turtleCount..", ignoreStock = "..tostring(ignoreStock)..")")
		turtleSlot, turtleCount = U.getItemFromNetwork("chest", "minecraft:dirt", 169 - turtleCount, nil, true)
		if turtleCount < 169 then	-- ask player for saplings
			T:checkInventoryForItem({"dirt"}, {169 - turtleCount})
		end
	end
	return {""}
end

function utils.createBasement(up, down, width, length)
	-- start facing lower left
	T:sortInventory(false)
	T:dropItem("seeds", "forward")
	T:dropItem("flint", "forward")
	R.up = up
	R.down = down
	R.width = width
	R.length = length
	clearRectangle()	-- dig 10 x 10 x 2 area, return to starting position
	-- add network cable, modems and chests
end

function utils.createStorage()
	-- start in centre, above 1st level
	T:place("modem", "down")
	utils.goBack(1)

	T:place("chest", "down")	-- places with handle at back of turtle
	T:go("R1F1L1")
	T:place("chest", "down")	-- 2nd of pair
	for i = 1, 3 do
		T:go("F1L1")
		T:place("chest", "down")
		T:go("R1F1L1")
		T:place("chest", "down")
	end

	T:go("F1L1F1")	-- end at starting position
	U.attachModem()
end

function utils.createWalledSpace(D)
	--[[
	D.width  = #
	D.length = #
	D.height = #
	D.ceiling = false
	D.floor = false
	D.vDirection = "U" or "D"
	D.hDirection = "LR" or "RL"
	D.goHome = true
	T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	]]
	local turn  = "R1"
	local oTurn = "L1"
	if D.hDirection == "RL" then
		turn    = "L1"
		oTurn   = "R1"
	end
	local placeF = "C1"

	local lib = {}

	function lib.getPlace(D, start, finish)
		if start then						-- start of build
			if D.vDirection == "U" then 	-- bottom and going up
				if D.floor then
					return "C2"
				end
			else							-- D.vDirection == "D"
				if D.ceiling then
					return "C0"
				end
			end
		elseif finish then					-- end of build
			if D.vDirection == "U" then 	-- bottom and going up
				if D.ceiling then
					return "C0"
				end
			else
				if D.floor then
					return "C2"
				end
			end
		end

		return ""							-- start and finish both false
	end

	function lib.layer(D, start, finish)
		local outward = true
		local place = lib.getPlace(D, start, finish)
		for width = 1, D.width do
			for length = 1, D.length do
				if start or finish then
					T:go(place, false, 0, true)-- place floor / ceiling
				end
				if width == 1 then
					T:go(oTurn..placeF..turn, false, 0, true)		-- face wall and check if block
				elseif width == D.width then						-- checking opposite wall
					if outward then									-- travelling away from start
						T:go(turn..placeF..oTurn, false, 0, true)	-- face wall and check if block
					else											-- travelling towards start
						T:go(oTurn..placeF..turn, false, 0, true)	-- face wall and check if block
					end
				end
				-- move forward
				if length < D.length then
					T:forward(1)
				end
			end
			if width < D.width then
				-- change direction
				if outward then
					T:go(placeF..turn.."F1"..oTurn..place..placeF..turn..turn, false, 0, true)
				else
					T:go(placeF..oTurn.."F1"..turn..place..placeF..oTurn..oTurn, false, 0, true)
				end
				outward = not outward
			else
				if outward then
					T:go(placeF..oTurn.."F"..D.width -1 ..oTurn.."F"..D.length - 1 .."C1R2", false, 0, true)
				else
					T:go(placeF..turn.."F"..D.width -1 ..oTurn..placeF..turn..turn, false, 0, true)
				end
			end
		end
	end

	T:go("R2C1R2", false, 0, true)						-- place block behind
	for height = 1, D.height do
		if height == 1 then
			lib.layer(D, true, false)					-- first layer, so start = true, finish = false
		elseif height == D.height then
			lib.layer(D, false, true)					-- final layer, so start = false, finish = true
		else
			lib.layer(D, false, false)					-- mid build layer, so start = false, finish = false
		end
		if height < D.height then						-- go up or down unless finished build
			T:go(D.vDirection.."1")
		end
	end
	if D.goHome then-- ends at starting point
		if D.vDirection == "U" then
			T:down(D.height - 1)
		else
			T:up(D.height - 1)
		end
	end
end

function utils.createWaterSource(level)
	if level == nil then
		level = 0
	end
	if level > 0 then
		T:up(level)
	elseif level < 0 then
		T:down(math.abs(level))
	end
	-- assume on flat surface, but allow for blocks above
	T:go("x0C2F1 x0C2F1 x0C2F1 x0C2R1 F1 x0C2F1 x0C2F1 x0C2R1 F1 x0C2F1 x0C2F1 x0C2R1 F1 x0C2F1 x0C2", false, 0, false)
	T:go("R1F1D1", false, 0, false) --move to corner and drop down
	T:go("C2F1R1 C2F1R1 C2F1R1 C2F1R1", false, 0, false)
	T:go("U1")
	for i = 1, 2 do
		T:placeWater("down")
		T:go("F1R1F1R1", false, 0, false)
	end
	-- refill water buckets
	for i = 1, 2 do
		sleep(0.5)
		T:placeWater("down")
	end
	T:go("R2F1R1F1R1")
	-- end above lower left of pond (starting point)
	return {}
end

function utils.description(text)
	menu.clear()
	print(text)
end

function utils.dropSand()
	local count = 0
	while not turtle.detectDown() do -- over water. will be infinite loop if out of sand
		if not T:place("sand", "down", false) then
			print("Out of sand. Add more to continue...")
			sleep(2)
		end
		count = count + 1
	end
	return true, count --will only get to this point if turtle.detectDown() = true
end

function utils.pause()
	--[[
	allows 2 turtles to co-operate
	When they face each other and move together
	R.side = "R" or "L"
	]]
	local rsIn = rs.getAnalogueInput("front")
	local rsOut = 1
	local present = false
	local confirmed = false
	local timer = 0
	local endTimer = 0
	local finished = false
	T:go(R.side.."1")
	rs.setAnalogueOutput("front", 0) -- switch off output
	local blockType = T:getBlockType("forward")
	while blockType:find("turtle") == nil do
		menu.colourWrite("Waiting for other turtle "..endTimer, colors.orange, nil, nil, false, true)
		blockType = T:getBlockType("forward")
		sleep(0.1)
		timer = timer + 0.1
		if timer >= 1 then
			timer = 0
			endTimer = endTimer + 1
		end
	end
	timer = 0
	endTimer = 0

	while not finished do
		if endTimer == 0 then
			if present then
				if confirmed then
					menu.colourWrite("Turtle confirmed: input = "..rsIn.." output = "..rsOut, colors.orange, nil, nil, false, true)
				else
					menu.colourWrite("Other turtle ok: input = "..rsIn.." output = "..rsOut, colors.orange, nil, nil, false, true)
				end
			else
				menu.colourWrite("Waiting: input = "..rsIn.." output = "..rsOut, colors.orange, nil, nil, false, true)
			end
		end
		sleep(0.1)
		timer = timer + 1
		if endTimer > 0 then
			endTimer = endTimer + 1
		end
		if endTimer >= 10 then -- allows time for other computer to get ready
			finished = true
		end
		rs.setAnalogueOutput("front", 1) -- output 1 as a signal initially
		if present then
			rs.setAnalogueOutput("front", rsOut) -- output 1 as a signal initially
		end
		rsIn = rs.getAnalogueInput("front")
		if rsIn == 1 then
			present = true
			if not confirmed then
				rsOut = 7
			end
		elseif rsIn == 7 then
			present = true
			confirmed = true
			rsOut = 15
		elseif rsIn == 15 or confirmed then
			menu.colourWrite("endTimer active = "..endTimer, colors.orange, nil, nil, false, true)
			endTimer = endTimer + 1 -- start endTimer
		end
	end
	T:go(R.side.."3")

	return rsIn -- 15
end

function utils.startWaterFunction(inWater, onWater, maxDescent, goIn)
	--[[
		Use with utils.getWaterStatus
		could be inWater and not onWater if on single layer of water with floor below
	]]
	maxDescent = maxDescent or 1 -- prevents continuous down due to lack of water
	if goIn == nil then	-- turtle should submerge
		goIn = true
	end
	local descent = 0 -- counter for going down
	if inWater then -- job done
		return inWater, onWater
	end
	if onWater and goIn then --inWater already returned so must be false
		if turtle.down() then
			if T:getBlockType("forward"):find("water") ~= nil or T:getBlockType("forward"):find("bubble") ~= nil then
				inWater = true
				return inWater, onWater
			end
		end
	end
	if not onWater then
		T:forward(1)
	end
	-- should now be above water, but may be further down so onWater still false
	while T:getBlockType("down"):find("water") == nil and T:getBlockType("down"):find("bubble") == nil do-- go down until water below
		if turtle.down() then
			descent = descent + 1
			if descent >= maxDescent then -- limit descent in case no water present
				onWater = false
				return inWater, onWater -- false,false
			end
		else
			onWater = false
			return inWater, onWater -- false,false
		end
	end
	-- now above water
	if goIn then
		turtle.down() -- now inside water block
		inWater = true
	end
	return inWater, onWater
end

function utils.fillBucket(direction, count)
	count = count or 1
	local buckets = 0
	local success = false
	for i = 1, count do
		if T:getWater(direction)  then
			sleep(0.3)
			success = true
			buckets = buckets + 1
		end
	end
	return success, buckets
end

function utils.getEmptyBucketCount()
	-- slotData.lastSlot, total, slotData -- integer, integer, table
	local lastSlot, total, slotData = T:getItemSlot("minecraft:bucket")
	return total
end

function utils.followGround(length)
    for i = 1, length - 1 do
        while not turtle.inspectDown() do -- must be air below
            turtle.down()
        end
		local blockType = T:getBlockType("forward")
		if T:isVegetation(blockType) then
			turtle.dig()
		else
			while turtle.detect() do
				--turtle.digUp() -- in case any blocks above
				if not turtle.up() then
					break
				end
			end
		end
		if i < length then
			turtle.forward()
		end
    end
end

function utils.getItemsForInventory(data)
	for _, v in ipairs(data) do -- eg {{"minecraft:bucket"}, {1}, false}
		-- T:checkInventoryForItem(items, quantities, required, message)
		T:checkInventoryForItem(v[1], v[2], v[3], v[4])
	end
end

function utils.getRoofStats()
	local isWidthOdd = R.width % 2 == 1 			-- is the width odd or even?
	local isLengthOdd = R.length % 2 == 1 			-- is the length odd or even?
	if isWidthOdd then
		R.height = math.floor(R.width / 2)			-- eg 7 x 5 roof, layers = 5 / 2 = 2
	else
		R.height = R.width / 2						-- eg 17 x 8 roof, layers = 8 / 2 = 4
	end

	local width = 2									-- assume even width with  2 block roof ridge
	local length = R.length - R.height - 1			-- assume even width with  2 block roof ridge
	if isWidthOdd then
		width = 3									-- adjust to allow for single width roof ridge
	end
	if isLengthOdd then
		length = R.length - R.height				-- adjust as 1 layer less
	end

	return isWidthOdd, isLengthOdd, width, length
end

function utils.getWater()
	if deletesWater then
		T:getWater("down") -- take water from source
		sleep(0.2)
		T:getWater("down") -- take water from source
	else
		if not turtle.detectDown() then
			T:go("C2", false, 0, false)
		end
		T:getWater("forward") -- take water from source
		sleep(0.2)
		T:getWater("forward") -- take water from source
	end
end

function utils.getWaterBucketCount()
	-- lastSlot, total, slotData  = T:getItemSlot(item)
	local lastSlot, total, slotData = T:getItemSlot("minecraft:water_bucket")
	return total
end

function utils.getWaterStatus()
	--[[ Usage:
	local inWater, onWater = utils.getWaterStatus() -- returns turtle position near water
	utils.startWaterFunction(onWater, inWater, 2, true) -- move INTO water max 2 blocks down
	utils.startWaterFunction(onWater, inWater, 5, false) -- move ABOVE water max 5 blocks down
	]]
	local onWater = false
	local inWater = false
	for i = 1, 4 do
		if T:getBlockType("forward"):find("water") ~= nil  or T:getBlockType("forward"):find("bubble") ~= nil then
			inWater = true
		end
		T:turnRight(1)
	end
	if T:getBlockType("down"):find("water") ~= nil or T:getBlockType("down"):find("bubble") ~= nil then
		onWater = true
	end
	return inWater, onWater
end

function utils.goBack(blocks)
	blocks = blocks or 1
	local success = true
	for i = 1, blocks do
		if not turtle.back() then
			success = false
			T:go("R2F1R2")
		end
	end

	return success
end

function utils.getPrettyPrint(promptColour, menuPromptColour)
	promptColour = promptColour or colors.yellow
	menuPromptColour = menuPromptColour or colors.white

	local pp = {}
	pp.prompt = promptColour
	pp.itemColours = {}
	pp.menuPrompt = menuPromptColour
	pp.allowModifier = true -- can the menu return 'q' or 'h' / 'i'

	return pp
end

function utils.isStorage(direction)
	local blockType = T:getBlockType(direction)
	if blockType:find("barrel") ~= nil then
		return true, "barrel"
	elseif blockType:find("chest") ~= nil then
		return true, "chest"
	elseif blockType:find("modem") ~= nil then
		return true, "modem"
	end

	return false, blockType
end

function utils.move(blocks, reverse)
	if blocks == 0 then return 0 end
	if reverse == nil then
		reverse = false
	end
	----Log:saveToLog("utils.move R.goDown = "..tostring(R.goDown)..", reverse = "..tostring(reverse)..", R.goUp = "..tostring(R.goUp))
	if reverse then
		if R.goDown then -- reverse direction
			T:up(blocks)
		else
			T:down(blocks)
		end
		return blocks * -1
	else
		if R.goUp  then
			T:up(blocks)
		else
			T:down(blocks)
		end
		return blocks
	end
end

function utils.placeFloor(width, length, blockType)
	-- T:place(blockType, direction, leaveExisting, signText, doNotAttack)
	for i = 1, width do
		for j = 1, length do
			T:place(blockType, "down", true, "", false)
			if j < length then
				T:forward(1)
			else
				if i%2 == 1 then -- odd numbers 1,3,5,7,9
					if i < width then
						T:go("R1F1R1", false, 0, true)
					end
				else
					T:go("L1F1L1", false, 0, true)
				end
			end
		end
	end
end

function utils.printR()
	--[[
		choice = 0,
		subChoice = 0,
		size = 0,
		width = 0,
		length = 0,
		height = 0,
		depth = 0,
		up = false,
		down = false,
		silent = false,
		data = {},
		torchInterval = 0,
		useBlockType = "",
		auto = false,
		side = "",
		direction = "",
		ready = false,
		networkFarm = false,
		mysticalAgriculture = false,
		logType = "",
		treeSize = "",
		message = ""
	]]
	T:clear()
	print("choice= ".. tostring(R.choice)..", subChoice= ".. tostring(R.subChoice))
	print("size= ".. tostring(R.size)..", width= ".. tostring(R.width))
	print("length= ".. tostring(R.length)..", height= ".. tostring(R.height)..", depth= ".. tostring(R.depth))
	print("silent= "..tostring(R.silent)..", up= ".. tostring(R.up)..", down= "..tostring(R.down))
	print("torchInterval= ".. tostring(R.torchInterval))
	print("useBlockType= "..tostring(R.useBlockType))
	print("auto= ".. tostring(R.auto)..", side= "..tostring(R.side)..", direction= "..tostring(R.direction))
	print("ready= ".. tostring(R.ready)..", networkFarm= "..tostring(R.networkFarm)..", mysticalAgriculture= "..tostring(R.mysticalAgriculture))
	print("logType= ".. tostring(R.logType)..", treeSize= "..tostring(R.treeSize)..", message= "..tostring(R.message))
	if type(R.data) == "table" then
		io.write("data= ")
		for k,v in pairs(R.data) do
			print(k ..": "..tostring(v))
		end
	else
		print("data= ".. tostring(R.data))
	end
	io.write("Enter to continue")
	read()
end

function utils.logRvalues()
	Log:saveToLog("R values set = "..textutils.serialise(U.compareR(), {compact = true}))
end

function utils.setStorageOptions()
	-- check inventory for storage type(s) onboard
	local storage = ""
	local storageBackup = ""
	if T:getItemSlot("barrel") > 0 then
		storage = "barrel"
		storageBackup = "barrel"
	end
	if T:getItemSlot("chest") > 0 then
		if storage == "" then
			storage = "chest"
		end
		storageBackup = "chest"
	end
	return storage, storageBackup	-- eg "barrel", "chest"
end

function utils.towpathOnly()
	--[[single turtle on towpath only using 4 turtles. Starts at ground level]]
	T:turnRight(2)										-- face towards completed towpath
	for i = 1, R.length do
		local placeOnly = true							-- no torch placement
		if R.torchInterval > 0 then						-- place torches
			if i == 1 then
				T:go("U1C2 U1x0") 								-- place block on ground level, up 1 and excavate ceiling
				T:place("torch", "down")						-- place torch
				utils.goBack(1)
				T:go("x0D2")
			elseif i % R.torchInterval == 0 then		-- torch interval, already facing towards completed path
				T:go("U1C2 U1x0") 						-- place block on ground level, up 1 and excavate ceiling
				T:place("torch", "down")				-- place torch
				--utils.goBack(1)
				T:go("B1x0 D2")							-- move back, delete block above, down 2
				placeOnly = false						-- no futher action as already moved forward
			end
		end

		if placeOnly then								-- NO torch placed so continue
			if turtle.detectUp() then
				T:go("U2x0D2")							-- up 2 and excavate ceiling, down  to ground
			end
			utils.goBack(1)
			if not T:place("slab", "forward") then	-- place slab
				T:checkInventoryForItem({"slab"}, {R.length - i})
			end
		end
	end
end

function utils.waitForInput(message)
	-- Pause script and asks user to continue
	if message ~= nil then
		menu.colourPrint(message, colors.yellow)
		Log:saveToLog("utils.waitForInput("..message..")", false)
	end
	menu.colourPrint("Enter to continue...", colors.lightBlue)
	read()
end

function utils.writeTraceTable(description, tbl)
	local text = ""
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			for k,v in pairs(value) do
				text = text.."k = "..k..", v = "..v.."; "
			end
		else
			text = "key = "..key..", value = "..value
		end
	end
	--Log:saveToLog(description.."\n".. text)
end

local pp = utils.getPrettyPrint()

require("tasks.farming")(utils, pp, dbug, netherBedrock, deletesWater, brick)
require("tasks.utilities")(utils, pp, dbug, netherBedrock, deletesWater, brick)
require("tasks.building")(utils, pp, dbug, netherBedrock, deletesWater, brick)
require("tasks.excavation")(utils, pp, dbug, netherBedrock, deletesWater, brick)
require("tasks.fluids")(utils, pp, dbug, netherBedrock, deletesWater, brick)

local function sceneLoader()
    --Log:saveToLog("sceneLoader() started")
	T:clear()										-- clear terminal, reset cursor to 1,1 and reset colours
	--local message = U.loadStorageLists()			-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	--local message = U.wrapModem()	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	--if message ~= "" then return {message} end
	-- essential libraries:
	local Event 	= require("lib.Events")
	local SM 		= require("lib.SceneMgr")
	_G.events 		= Event(false)					-- global variable: self.handlers = {}
	--Log:saveToLog("Loading all scenes")
	--sm = SM("scenes", {"MainMenu", "Menu", "SetupStorage", "SelectItems", "Craft", "ManageTurtle", "TaskOptions", "GetItems", "Quit", "Help"})
	_G.sm = SM("scenes", {"MainMenu", "TaskOptions", "GetItems", "Quit", "Help"}) -- SM:new(sceneDir, scenes)
	sm:getSceneByName("Quit"):setText("tk3 Toolkit Closing...")
	U.populateAllItems()							-- create a table of displayNames of all items for use in search functions
	--Log:saveToLog("Switching to MainMenu")
	sm:switch("MainMenu")

	while true do	-- gameLoop
		if U.executeTask then
	--Log:saveToLog("sceneLoader exiting with '"..U.currentTask.."'")
	--Log:saveToLog("R settings = "..textutils.serialise(U.compareR(), {compact = true}))
			local description = F[U.currentTask].description
			if description ~= nil then
				-- check for insertion of variables
				if description:find("$") ~= nil then
					local words = U.split(description, "$")
					description = ""
					for _, word in ipairs(words) do
						if word:find("R.") == nil then
							description = description..word
						else
							if word:find("%(") == nil then
								local key = word:sub(3)
								--Log:saveToLog("key = "..key)
								description = description..tostring(R[key])
							else
								local expression = U.parseExpression(word, "tk3.sceneLoader()")
								description = description..tostring(expression)
							end
				--Log:saveToLog("description = "..description)
						end
					end
				end
				menu.clear()
				menu.colourText(description)
			end
			local fuel = F[U.currentTask].fuel
			if fuel ~= nil then
				fuel = U.parseExpression(fuel, "tk3.sceneLoader()")
			--Log:saveToLog("fuel = "..fuel)
				utils.checkFuelNeeded(fuel)
			end
			return {U.currentTask}
		end
		local sceneName = sm:getCurrentSceneName()
		local inputData = nil
		if sceneName == "Quit" then
			-- fade out then quit. No user input required
			for i = 1, 3 do
				sleep(1)
				sm:update()
				sm:draw()
			end
			T:clear()
			return {"GUI toolkit completed"}
		elseif sceneName == "GetItems" then
			-- U.getInput(withTimer, interval, withInventory)
			inputData = U.getInput(false, 3, true) -- get inventory data
			-- inputData = {"turtle_inventory"}
			-- inputData = {"key", keyCode, is_held}
			-- inputData = "mouse_click", button = 1, x = 4, y = 4
			--Log:saveToLog("sceneLoader() inputData = "..textutils.serialise(inputData, {compact = true}))
			sm:update(inputData)
			sm:draw()
		else
			inputData = U.getInput(false)	-- U.getInput(withTimer, interval, withInventory)
			sm:update(inputData)
			sm:draw()
		end
	end
	return {"GUI toolkit exited unexpectedly"}
end

local function main()
	local result = {}
	T:clear()
    local doContinue = false
    local skip = false
	if args[1] ~= nil then
		if args[1]:sub(1,1) == "h" then
			local help =
[[... = any following characters

tk3 v...     = mc/ccTweaked versions
tk3 log      = enable logging
tk3 log d... = enable logging + debug
tk3 find     = writes locate.txt
tk3 test     = runs test()
tk3 farm     = runs manageFarm()



Enter to exit]]
			menu.colourPrint(help, colours.yellow)
			read()
		elseif args[1] == "attack" then
			R.auto = true
			if args[2] == nil then
				attack()
			else
				if args[2]:find("u") ~= nil then
					attack("up")
				elseif args[2]:find("f") ~= nil then
					attack("forward")
				elseif args[2]:find("d") ~= nil then
					attack("down")
				end
			end
		elseif args[1] == "log" then
			if args[2] ~= nil then
				if args[2]:sub(1,1) == "d" then
					dbug = true	-- set dbug flag
					menu.colourPrint("Logging and debugging enabled", colors.lime)
				end
			else
				menu.colourPrint("Logging enabled", colors.lime)
			end
			if Log:getLogExists() then
				if menu.getBoolean("Delete existing log file? (y/n)", 3, colors.orange) then
					Log:deleteLog()
					menu.colourPrint("Log file deleted", colors.yellow)
				end
			end
			Log:setUseLog(true)
			doContinue = true
            utils.waitForInput()
        elseif args[1] == "bamboo" then
			Log:setUseLog(false)
			R.silent = true
			R.auto = true
			manageBambooFarm()
		elseif args[1] == "farm" then
			R.silent = true
			R.data = "farm"
			R.auto = true
			manageFarm()
		elseif args[1] == "composter" then
			R.silent = true
			composter() -- use file to read status
		elseif args[1] == "find" then
			-- missing turtle: player used 'tk3 find'
			Log:setUseLog(true)
			Log:setLogFileName("locate.txt")
			Log:appendLine("Booting succeeded")
			Log:appendLine("Block ahead: "..T:getBlockType("forward"))
			Log:appendLine("Block above: "..T:getBlockType("up"))
			Log:appendLine("Block below: "..T:getBlockType("down"))
		elseif args[1] == "test" then
            test()
			skip = true
		elseif args[1] == "test2" then
			test2()
		elseif args[1]:find("v") ~= nil then
			print("_HOST:")
			print()
			print(_HOST)
			print()
			print("Minecraft version:       "..mcVersion)
			print("Minecraft major version: "..mcMajor)	-- variables from lines
			print("Minecraft minor version: "..mcMinorVersion)
			print("ccTweaked version:       "..ccVersion)
			print("tk3 version:             "..version)
			print("\nEnter to exit")
			read()
		end
	else
		doContinue = true
	end
    if doContinue then
        print("Minecraft major version: " .. mcMajorVersion)
        print("Bedrock level: " .. U.bedrock)
        if Log:getUseLog() then
            if Log:saveToLog("Started with logging enabled", true) then
                --menu.colourPrint("\nEnter to continue...", colors.lightBlue)
                --sleep(2)
                --read()
            end
        else
            print("Logging disabled")
        end
        sleep(1)
        --T:setEquipment()    -- forces equipped items into inventory and back again (bug in fabric version)

        U.currentTask = ""
        U.copyR()        -- copy current values of R
        result = sceneLoader() -- eg {"createMine"}
        --if fList[result[1]] ~= nil then
        if F[result[1]] ~= nil then
            local task = result[1] -- eg {"createMine"}
            --Log:saveToLog("tk3.main() task = " .. task .. "()")
            utils.logRvalues()
            result = Task.run(task, F[task].call) -- eg createMine()
        end
    end
	if not skip then
    	T:clear()
    	table.insert(result, "Thank you for using 'survival toolkit'")
    	local clr = {colors.yellow, colors.orange, colors.green, colors.lightBlue}
    	local count = 1
    	for _, value in ipairs(result) do
    		menu.colourPrint(tostring(value), clr[count])
    		count = count + 1
    		if count > #clr then
    			count = 1
    		end
    	end
	end
end

_G.F = require("lib.data.taskInventory")	-- has to be placed after all function definitions
-- Note checkFileSystem() runs BEFORE main()
main()
