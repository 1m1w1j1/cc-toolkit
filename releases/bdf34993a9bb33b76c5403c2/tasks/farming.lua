local Fuel = require("lib.runtime.Fuel")
return function(utils, pp, dbug, netherBedrock, deletesWater, brick)
function assessFarm(farmType)
    if farmType == nil then farmType = "crop" end
	-- sets R.networkFarm and R.mysticalAgriculture
	menu.clear()
	menu.colourPrint("Assessing farm properties...", colors.yellow)

	if farmType == "bamboo" then					-- check is on ground facing bamboo
		local itemBelow = T:getBlockType("down")
		if itemBelow == "" then						-- air below
			while turtle.down() do end				-- return to ground
			itemBelow = T:getBlockType("down")
		end
		if itemBelow:find("bamboo") ~= nil then 	-- started in wrong place, exit
			return "fail"
		elseif itemBelow:find("modem") ~= nil then
			return "modem"
		end
		-- NOT bamboo below
		return "waiting"
	elseif farmType == "crop" then
		for turns = 1, 4 do
			T:turnRight(1)
			local itemAhead = T:getBlockType("forward")
			if itemAhead:find("modem") ~= nil then
				if not R.networkFarm then	-- prevents repeated text display
					R.networkFarm = true
					menu.colourPrint("Network storage in use.", colors.magenta)
				end
			end
			if itemAhead:find("mysticalagriculture") ~= nil then
				R.mysticalAgriculture = true
				menu.colourPrint("Mystical Agriculture deployed.", colors.lime)
			end
		end
		sleep(1.5)
	end
end

function assessTreeFarm()
	-- R.networkFarm = true
	-- R.subChoice = 1: birch, oak (single dirt)
	-- R.subChoice = 2: jungle, spruce, dark oak, pale oak (4 dirt)
	-- R.subChoice = 3: mangrove (full dirt cover)
	-- R.treeSize  = "single" or "double"
	local lib = {}
	R.message = ""
	function lib.checkPosition()
		-- should be on modem
		T:go("R1F1")
		-- if in correct start, log below
		blockType = T:getBlockType("down")
--Log:saveToLog("T:go(R1F1): blockType = "..blockType)
		if blockType:find("log") ~= nil then
			lib.getSaplingType(blockType)
			T:go("B1L1")
			return true
		end
		T:go("B1L1")
		return false
	end

	function lib.getSaplingType(blockType)
		R.subChoice = 1
		R.treeSize = "single"
		if blockType == "minecraft:mangrove_log" then
			R.logType = blockType
			R.useBlockType ="minecraft:mangrove_propagule"
			R.subChoice = 3
		else
			local parts = T:getNames(blockType)	-- eg {"minecraft", "dark", "oak", "log"}
			local name = ""
			for i = 1, #parts - 1, 1 do				-- eg {"minecraft", "dark", "oak"
				if i == 1 then
					name = parts[1]..":"			-- eg "minecraft:"
				elseif i == 2 then
					name = name..parts[2]			-- eg "minecraft:dark"
				else
					name = name.."_"..parts[i]		-- eg "minecraft:dark_oak"
				end
			end
			name = name.."_sapling"					-- eg "minecraft:dark_oak_sapling"
			R.logType = blockType					-- eg "minecraft:dark_oak_log"
			R.useBlockType = name					-- eg "minecraft:oak_sapling"
			if name:find("spruce") ~= nil or name:find("jungle") ~= nil or name:find("dark_oak") ~= nil or name:find("pale_oak") ~= nil then
				R.subChoice = 2
				R.treeSize = "double"
			end
		end
	end

	--Log:saveToLog("assessTreeFarm() started")
	local blockType = T:getBlockType("down")
	if blockType:find("modem") == nil then
		R.message = "Not on modem. Check position"
		--Log:saveToLog("Not on modem. Check position")
		return
	end
	-- must be network farm so check position
	if not lib.checkPosition() then
		R.message = "Unable to find log for sapling type. Check position"
		--Log:saveToLog("Unable to find log for sapling type. Check position")
	end

	return	-- no values returned as R values are set above
end

function checkFarmPosition()
	local discovered = ""
	local success, storage, detected = false, "", 0
	local blockType = T:getBlockType("down")
	R.networkFarm = true	-- all farms now use network storage
	R.ready = false
--Log:saveToLog("Checking position "..blockType.. " down")
	if blockType:find("water") ~= nil then -- over water, ? facing E (crops)
		-- network: E = _modemmodem__, N = _modemmodem_, W = modemmodem__, S = modem__modem
		-- legacy/earlyGame: E = _chestchest_, N = chestchest__, W = chest__chest, S = __chestchest
		-- Legacy/earlyGame: E = _barrelbarrel_, N = barrelbarrel__, W = barrel__barrel, S = __barrelbarrel
--Log:saveToLog("? over water = true")
		for i = 1, 4 do
			success, storage = utils.isStorage("forward")	-- true/false, chest, barrel, modem,  ""
			local itemAhead = T:getBlockType("forward")
			if success then
				discovered = discovered .. storage
			else
				discovered = discovered .. "_"
			end
			if itemAhead:find("mysticalagriculture") ~= nil then
				R.mysticalAgriculture = true
			end
			T:turnRight(1)
		end
--Log:saveToLog("Storage blocks found:"..discovered)
		if discovered == "modemmodem__" then
		   T:turnLeft(1)
		elseif discovered == "modem__modem" then
		   T:turnLeft(2)
		elseif discovered == "__modemmodem" then
		   T:turnRight(1)
		end
		R.ready = true
	end	-- else not over water
	if R.ready then
		--Log:saveToLog("checkFarmPosition() complete. Ready to go", true)
	else
		Log:saveToLog("checkFarmPosition() NOT ready", true)
	end
	-- now facing crops, R.ready = true/false, R.networkFarm = true/false
end

function clearAndReplantTrees()
	--[[ clear all trees in a rectangle area defined by walls, fences or non-dirt blocks
	replant with same type of sapling. If original tree 2 blocks wide, replant 4 if possible. ]]
	local width = 0
	local length = 0
	local lib = {}

	function lib.harvestTree(blockTypeF)
		--[[ Fell tree, returns true if double size ]]
		-- clsTurtle.harvestTree(extend, craftChest, direction)
		local saplingType = T:getSaplingFromLogType(blockTypeF)
		local double = T:harvestTree("forward")	-- assume single tree, will auto-discover
		T:suckAll()
		if R.auto then
			lib.plantSapling(saplingType, double)
		end
	end

	function lib.plantSapling(sapling, double)
		--[[ plant sapling(s) ]]
		if R.auto then
			if sapling == "" or sapling == nil then sapling = "sapling" end
			T:up(1)
			T:suckAll()
			if double then	-- check if enough saplings
				-- return slotData.lastSlot, total, slotData -- integer, integer, table
				local slot, total, _ = T:getItemSlot(sapling)
				if total >= 4 then
					for i = 1, 4 do
						T:place(sapling, "down")
						T:go("F1R1")
					end
					T:forward(1)		-- above pre-planted sapling
				else
					if not T:place(sapling, "down") then
						T:place("sapling", "down")
					end
				end
			else
				if not T:place(sapling, "down") then
					T:place("sapling", "down")
				end
			end
		end
		turtle.select(1)
	end

	function lib.turn(turn)
		--[[ change direction and return new value for turn direction ]]
		if turn == "r" then
			T:turnRight(1)
			turn = "l"
		else
			T:turnLeft(1)
			turn = "r"
		end
		return turn	-- will only change turn direction variable if return value is used
	end

	function lib.emptyInventory(blockTypeD)
		--[[ Empty all except 32 of each sapling and 1 chest ]]
		if blockTypeD == nil then
			blockTypeD = T:getBlockType("down")
		end
		if blockTypeD:find("chest") ~= nil or blockTypeD:find("barrel") ~= nil then
			-- empty logs, apples, sticks and all but 1 stack of each sapling type
			T:emptyInventorySelection("down", {"chest", "oak_sapling", "birch_sapling", "spruce_sapling", "acacia_sapling", "jungle_sapling","dark_oak_sapling"},{1, 32, 32, 32, 32, 32, 32})
			return true
		else
			return false
		end
	end

	function lib.moveDown(blockTypeD)
		--[[ move down until hit ground. Break leaves and continue ]]
		if blockTypeD == nil then
			blockTypeD = T:getBlockType("down")
		end
		while blockTypeD == "" or blockTypeD:find("leaves") ~= nil do	-- move down, breaking leavse
			T:down(1)
			T:suckAll()
			blockTypeD = T:getBlockType("down")
		end
		return blockTypeD
	end

	function lib.moveForward()
		--[[
			Move forward 1 block only, go down to ground while air or leaves below.
			Use turtle.detect to save time
		]]
		local blockTypeU = ""
		local blockTypeF = ""
		local blockTypeD = ""

		if turtle.detectUp() then
			blockTypeU = T:getBlockType("up")
		end
		if turtle.detect() then
			blockTypeF = T:getBlockType("forward")
		end
		if turtle.detectDown() then
			blockTypeD = T:getBlockType("down")
		end

		if blockTypeU ~= "" and blockTypeU:find("leaves") == nil then	-- block above, not leaves
			if blockTypeU:find("log") ~= nil then
				T:harvestTree("up")
				return false, "", ""
			end
			return false, blockTypeU, "up"								-- report block above, no movement
		end

		if blockTypeD == "" then										-- air below
			return false, blockTypeD, "down"
		end

		if blockTypeF == "" or blockTypeF:find("leaves") ~= nil then	-- air or leaves ahead
			T:forward(1)												-- move forward, breaking leaves
			blockTypeF = T:getBlockType("forward")
			return true, blockTypeF, "forward"							-- moved ok, could be air or block in front
		end
		return false, blockTypeF, ""									-- did not move, obstacle in front NOT leaves or air
	end

	function lib.moveUp(blockTypeF)
		--[[ Move up, dig leaves or harvest tree) ]]
		if blockTypeF == nil then
			blockTypeF = T:getBlockType("forward")
		end
		while turtle.detect() do
			if blockTypeF:find("log") ~= nil then
				lib.harvestTree(blockTypeF)
				return true, ""
			elseif blockTypeF:find("leaves") ~= nil then
				T:go("x0x1")
				return false, ""
			end
			T:up(1)
			blockTypeF = T:getBlockType("forward")
		end
		--return  treeCut, "" / "dirt" etc
		return    false,   blockTypeF	-- should be false, "" (air) or any border block, true = tree cut
	end

	function lib.safeMove()
		--[[ move forward until border reached. loop breaks at that point ]]
		local blockTypeF = ""
		local success = true
		while success do
			success, blockTypeF = lib.moveForward()				-- move forward 1 block, return block type ahead
			if not success then 								-- did not move forwards, block in the way: either log, dirt/grass, border block or vegetation
				if blockTypeF:find("log") then 					-- tree found
					lib.harvestTree(blockTypeF)
					success = true								-- block (log) removed, try again
				else
					success = not lib.isBorder(blockTypeF)		-- Is at border?: if is at border success = false so loop stops
					if success then								-- Not at border. Dirt/grass vegetation in front
						blockTypeF = lib.moveUp(blockTypeF)		-- move up until leaves/log/air
						success = not lib.isBorder(blockTypeF)	-- Is at border?: if is at border success = false so loop stops
						if success then							-- keep moving forward
							if blockTypeF:find("log") then 		-- tree found
								lib.harvestTree(blockTypeF)
							end
																-- else blockTypeF is air/leaves  border has been checked
						end
					end
				end
			end													-- else success = true, 1 block moved so continue
			length = length + 1
		end
	end

	function lib.isBorder(blockType)
		--[[ Is the block log, dirt, grass_block, vegetation: non-border, or other:border]]
		if R.auto then
			if blockType == nil then 					-- not passed as parameter
				blockType = T:getBlockType("forward")
			end
			if blockType == "" then 					-- air ahead: not border
				return false, ""
			else										-- could be border or other
				if blockType:find("dirt") ~= nil or blockType:find("grass_block") ~= nil or blockType:find("log") ~= nil then -- either dirt, grass block or log
					return false, blockType				-- dirt, grass, log: not border
				end
				if T:isVegetation(blockType) then 		-- vegetation found: not border
					return false, blockType
				end
			end
				return true, blockType					-- dirt, grass_block, log and vegetation eliminated:must be border
		else
--Log:saveToLog("length = "..length)
			if length >= R.length then
				return true
			end
			return false
		end
	end

	function lib.inPosition()
		--[[ check if in lower left corner ]]
		local inPosition = true 		-- assume correct
		if not turtle.detectDown() then	-- hanging in mid-air
			return false
		end
		T:turnLeft(1)
		if lib.isBorder() then
			-- so far so good
			T:turnLeft(1)
			if not lib.isBorder() then 	-- not in correct place
				inPosition = false
			end
			T:turnRight(2) 				-- return to original position
		else
			inPosition = false
			T:turnRight(1) 				-- return to original position
		end
		return inPosition
	end

	function lib.findBorder()
		--[[ assume started after reset. if log above harvest tree else return to ground. Find starting corner]]
		local blockType = T:getBlockType("up")					-- dig any logs above, return to ground
		local sapling = "sapling"
		if blockType:find("log") ~= nil then					-- originally felling a tree so complete it
			sapling = T:getSaplingFromLogType(blockType)
			local double = T:harvestTree("up")	-- assume single tree, will auto-discover
			lib.plantSapling(sapling, double)
		else													-- no log above so go downm
			blockType = lib.moveDown()							-- return to ground (or vegetation)
		end
		lib.safeMove()											-- move forward until border reached
		T:turnRight(1)
		lib.safeMove()											-- move forward until second border reached
		T:turnRight(1)											-- should now be in correct position
		lib.emptyInventory()									-- empty inventory if above a chest
	end

	menu.clear()
	menu.colourPrint("Clearing and replanting trees", colors.lime)
	if R.auto then
		menu.colourPrint("Re-planting saplings enabled...", colors.lime)
	end
	menu.colourPrint("Width: "..R.width..", length: "..R.length, colors.lime)
	--Log:saveToLog("clearAndReplantTrees() width: "..R.width..", length: ".. R.length..", re-plant saplings = "..tostring(R.auto))
	local turn = "r"
	local blockTypeF = ""
	local success = false
	for w = 1, R.width do
		local success, blockType, direction, blocksMoved = false, "", "", 0	-- initialise variables
		while blocksMoved < R.length do
			--Log:saveToLog("calling lib.moveForward()")
			success, blockType, direction = lib.moveForward()				-- try to move forward 1 block, return block type ahead
			if success then													-- moved forward
				blocksMoved = blocksMoved + 1								-- increment counter
			else															-- failed to move forwards
				if direction == "up" then									-- block above, no moves
					while turtle.detectUp() do
						blockTypeU = T:getBlockType("up")
						if blockTypeU:find("leaves") == nil and blockTypeU:find("moss") == nil then			-- not leaves or hanging moss above
							T:back(1)
							blocksMoved = blocksMoved - 1					-- decrement counter
						else
							T:up(1)
							break
						end
					end
				else
					if direction == "down" then								-- air below, no moves
						T:down(1)											-- go down 1 as no block below
						success, blockType, direction = lib.moveForward()	-- try again, 1 block lower
						if success then
							blocksMoved = blocksMoved + 1
						end
					end
					if direction == "" then									-- block in front, not air or leaves
						--Log:saveToLog("calling lib.moveUp("..blockType..")")
						success, blockType = lib.moveUp(blockType)			-- true if tree felled
						if not success then									-- moved up, tree not cut
							T:forward(1)									-- move forward
						end
						blocksMoved = blocksMoved + 1
					end
				end
			end
		end
		-- length finished, turn and repeat
		lib.turn(turn)														-- turn r or l. turn direction is not changed
		success, blockType, direction = lib.moveForward()					-- try to move forward 1 block, return block type ahead
		--Log:saveToLog("turn: success = "..tostring(success)..", blockType = '"..blockType.."', direction = "..direction)
		if not success then													-- did not move forward
			if direction == "up" then										-- did not go forward as block above
				while turtle.detectUp() do									-- break blocks above
					T:up(1)
				end
				while turtle.down() do end									-- return to ground
				success, blockType, direction = lib.moveForward()			-- try to move forward 1 block, return block type ahead
			elseif direction == "down" then
				while turtle.down() do end
				success, blockType, direction = lib.moveForward()			-- try to move forward 1 block, return block type ahead
			end
			if not success then													-- following "up" direction
				if direction == "" then										-- block in front, not air or leaves
					while turtle.detect() do								-- while block in front
						blockType = T:getBlockType("forward")				-- what is in front?
						if blockType:find("leaves") ~= nil then				-- leaves found
							T:forward(1)
							break
						elseif blockType:find("log") ~= nil then			-- tree found
							lib.harvestTree(blockType)
							T:back(1)
							break
						else
							T:up(1)											-- move up 1
						end
					end
					T:forward(1)
				end
			end
		end
		turn = lib.turn(turn)												-- turn r or l. turn direction is changed to opposite
	end
	return {}
end

function convertEssence()
	-- R.subChoice = 1 to 5
	-- R.size = quantity
	-- 1 = inferium to prudentium
	-- 2 = prudentium to tertium
	-- 3 = Tertium to Imperium
	-- 4 = Imperium to Supremium
	-- 5 = Supremium to Insanium
	local lib = {}

	function lib.getCrystal()
		local turtleSlot, turtleCount = 0, 0
		if utils.isStorage("up") then
			turtle.select(2)
			turtle.suckUp()
		end
		turtleSlot = T:getItemSlot("crystal")
		if turtleSlot == 0 then
			turtleSlot, turtleCount = U.getItemFromNetwork("chest", "infusion_crystal", 1)
		end
		if turtleSlot > 0 then
			turtle.select(turtleSlot)
			turtle.transferTo(2)
			return true
		end

		return false
	end

	function lib.loadCrafter(crafterName)
		-- up to 64 essences stored in turtle slots 2, 4, 6, 8
		local slots = {2, 4, 6, 8}
		for _, slot in ipairs(slots) do		-- drop each slot contents into crafter ? slot 1
			turtle.select(slot)
			turtle.drop()
			peripheral.call(crafterName, "pushItems", crafterName, 1, nil, slot)	-- move to correct place
		end
	end

	function lib.loadTurtle(availableStorage, availableStorageKeys, essence, loaded)
		-- collect essence as above and place in minecraft:crafter slots 2, 4, 6, 8
		local crafterData = {{2, loaded}, {4, loaded}, {6, loaded}, {8, loaded}} -- eg 64 items in each of 4 slots in the crafter
		U.transferItemToTurtle(availableStorage, availableStorageKeys, crafterData)
	end

	function lib.runCrafter(crafterName, count)
		-- can only craft once, then crystal + output is returned to turtle
		-- repeat process count times
		-- drop crystal into crafter, move to slot 5
		for i = 1, count do
			local slot = T:getItemSlot("crystal")
			if slot > 0 then
				turtle.select(slot)
				turtle.drop()
				U.moveItem(crafterName, "crystal", 5)
				for i = 1, 3 do
					rs.setAnalogOutput("front",15)
					sleep(0.1)
					rs.setAnalogOutput("front", 0)
				end
			end
		end
		while turtle.suck() do end
	end

	function lib.storeCrystal()
		if utils.isStorage("up") then
			T:dropItem("crystal", "up")
		else
			U.sendItemToNetworkStorage("chest", "crystal", 0)	-- empty turtle to storage chests
		end
	end

	function lib.storeOutput()
		if utils.isStorage("up") then
			T:dropItem("crystal", "up")
		end
		--Log:saveToLog("==> lib.storeOutput() call --> U.sendItemToNetworkStorage('chest', 'all', 0")
		U.sendItemToNetworkStorage("chest", "all", 0)	-- empty turtle to storage chests
	end

	function lib.getStorageData(essence)
		--local message = U.wrapModem(true)
		--if message == "Modem not found" then return 0, nil, nil, "" end
		local availableStorage = {}
		local availableStorageKeys = {}
		local total = 0
		for _, storageName in pairs(storageNames) do
			local storageCount, storageData = U.findItemCountInInventory(storageName, essence)	-- eg 86, {{1, 64},{4, 22}}
			if storageCount > 0 then		-- eg 86: storage has some items
				--Log:saveToLog("storageCount = "..storageCount)
				availableStorage[storageName] = {}
				availableStorage[storageName].count = storageCount
				availableStorage[storageName].data = storageData
				table.insert(availableStorageKeys, storageName)
				total = total + storageCount
			end
		end

		return total, availableStorage, availableStorageKeys
		--[[
			availableStorage.minecraft:chest_114 = {count = 86, data = {{1, 64},{4, 22}},
			availableStorage.minecraft:chest_115 = {count = 1024, data = {{1, 64},{2, 64},{3, 64}, ... }
		]]
	end

	local essences = {"mysticalagriculture:inferium_essence",
					"mysticalagriculture:prudentium_essence",
					"mysticalagriculture:tertium_essence",
					"mysticalagriculture:imperium_essence",
					"mysticalagriculture:supremium_essence",
					"mysticalagriculture:insanium_essence"}

	--local message = U.loadStorageLists()
	local message = U.wrapModem(true)	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	if message ~= nil then return {message} end
	local essence = essences[R.subChoice]
	local missing = ""
	local crafter = peripheral.find("minecraft:crafter")
	local crafterName = ""
	local completed = 0
	if R.size > 0 then
		R.size = math.floor(R.size / 4) * 4
		if R.size == 0 then R.size = 4 end
	end
	if crafter == nil then
		return {"No crafter found"}
	else
		crafterName = peripheral.getName(crafter)
		--Log:saveToLog("utils.convertEssence started using "..essence..", quantity = "..R.size )
		while turtle.suck() do end						-- empty crafter
		lib.storeOutput()	-- empty turtle to storage chests, (except crystal if storage above)
		if not lib.getCrystal() then
			return {"Failed: missing infusion crystal"}
		end
		lib.storeCrystal()
		local totalInStorage, availableStorage, availableStorageKeys = lib.getStorageData(essence)
		if totalInStorage < 4 then
			return {"Only "..totalInStorage.." ".. essence:sub(20).." available"}
		else
			-- can only transfer full amount direct to crafter
			-- if a chest has 32 items in 1 slot and 32 in another Slot
			-- these have to be sent into the turtle first, dropped into crafter slot 1 and moved to correct position
			totalInStorage = math.floor(totalInStorage / 4) * 4
			if R.size == 0 then	-- process all
				--Log:saveToLog("initial call lib.loadTurtle("..U.turtleName..", "..totalInStorage.." essence")
				local processed = 0
				local loaded = 0

				while totalInStorage > 0 do		-- use ALL stored essence
					if totalInStorage - 256 > 0 then
						loaded = 64
					else
						loaded = totalInStorage / 4
					end
					lib.loadTurtle(availableStorage, availableStorageKeys, essence, loaded)
					lib.loadCrafter(crafterName)
					lib.getCrystal()
					processed = processed + loaded
					totalInStorage = totalInStorage - loaded * 4
					lib.runCrafter(crafterName, loaded)
					lib.storeOutput()
				end
			elseif R.size <= 64 then
				local loaded = math.min(R.size, totalInStorage)	-- process requested or available if less
				if loaded > 0 then
					lib.loadTurtle(availableStorage, availableStorageKeys, essence, loaded)
					lib.loadCrafter(crafterName)
					lib.getCrystal()
					lib.runCrafter(crafterName, loaded)
					lib.storeOutput()
				end
			else	-- amount > 64
				local processed = 0
				local loaded = 0
				while totalInStorage > 0 and processed < R.size do	-- stop if run out of essence, or reached target
					if totalInStorage - 256 > 0 and R.size - processed >= 64 then
						loaded = 64
					elseif totalInStorage - 256 > 0 and R.size - processed > 0 then
						loaded = R.size - processed
					end
					lib.loadTurtle(availableStorage, availableStorageKeys, essence, loaded)
					lib.loadCrafter(crafterName)
					lib.getCrystal()
					processed = processed + loaded
					totalInStorage = totalInStorage - loaded * 4
					lib.runCrafter(crafterName, loaded)
					lib.storeOutput()
				end
			end
			lib.storeOutput()
		end
		return {"success"}
	end
end

function convertFarm()
	-- check position
	local blockType = T:getBlockType("down")
	if blockType:find("water") == nil then
		return {"Position not determined.\nMove to lower left corner over water. (Normal start position)"}
	end
	local withStorage = false
	if R.inventoryKey == "convertStorage" then
		withStorage = true
	end
	local response = createFarmNetworkStorage(withStorage, true)
	return {response}
end

function convertTreefarm()
	-- legacy farm had polished block on positions 4 / (10) from left corner
	-- R.data = "convert"
	-- R.down = true if storage is to be included
	if R.data == "convert" then
		R.down = false-- no storage built underneath
	elseif R.data == "convertStorage" then
		R.down = true
	end
	return createTreefarm()
end

function createBambooFarm()
	R.useBlockType = T:getMostItem("minecraft:dirt", true)
	local lib = {}

	function lib.section()
		T:go("F1C2")
		for i = 1, 8 do
			T:go("F1x2")
			T:place("dirt", "down", false)
		end
		T:go("F1C2 F1C2")
	end

	T:go("D2R2 x1U1 x1R2")
	T:place("barrel", "down", false)
	T:up(1)
	T:place("modem", "down", false)
	U.attachModem()
	T:go("F1L1")
	T:place("chest", "down", false)
	T:go("R1F1L1")
	T:place("chest", "down", false)
	T:turnRight(1)
	for i = 1, 9 do
		T:go("F1C2")
	end
	T:go("R1F1 C2R1 F1C2")
	for i = 1, 9 do
		T:go("F1C2")
	end
	T:go("F1")
	T:place("chest", "down", false)
	T:go("L1F1R1")
	T:place("chest", "down", false)
	T:go("R2F1C2")
	for i = 1, 8 do
		T:go("F1x2")
		T:place("dirt", "down", false)
	end
	T:go("F1C2 F1C2 R1F1 R1C2")
	out = false
	for w = 1, 7 do
		lib.section()
		if out then
			T:go("R1F1 C2R1")
		else
			T:go("L1F1 C2L1")
		end
		out = not out
	end
	for i = 1, 11 do
		T:go("F1C2")
	end
	T:go("R1F1 C2R1")
	for i = 1, 11 do
		T:go("F1C2")
	end
	T:go("R1F11R1")
	return {"Bamboo Farm created"}
end

function createClayfarm()

	R.useBlockType = T:getMostItem("minecraft:dirt", true)		-- exclude dirt from choice

	local lib = {}

	function lib.waterSource()
		--make 3 x 1 water source
		T:go("L1F1 R1F1 R1")
		T:go("C2F1 C2F1 C2F1 C2F1 C2")
		T:go("R1F1 C2F1 R1")
		T:go("C2F1 C2F1 C2F1 C2F1 C2")
		T:go("R1F1 C2R1 F1")
		T:go("D2 F1x0 F1x0 U2")
		T:place("slab", "down")
		T:back(2)
		T:place("slab", "down")
		T:go("F1D2 C1R2 C1U1 C2")
		T:placeWater("forward")
		T:turnRight(2)
		T:placeWater("forward")
		T:go("U1B1 L1")
	end

	function lib.buildWall(length)
		for i = 1, length do
			T:go("F1x0 x2C2", false, 0, false, R.useBlockType)
		end
	end

	-- starts behind SW corner
	lib.waterSource()	-- ends at starting position
	for i = 1, 4 do
		lib.buildWall(11)
		T:go("R1")
	end
	T:go("F1R1 F1L1 D2")						-- 2 blocks below surface grass / dirt
	utils.createBasement(true, true, 10, 10)	-- remove 3 layers
	T:down(2)
	utils.createBasement(true, true, 10, 10)
	T:up(1)
	R.up = true
	R.width = 10
	R.length = 10
	R.useBlockType = "slab"
	createFloorCeiling()
	T:down(1)
	R.useBlockType = "minecraft:pointed_dripstone"
	createFloorCeiling()
	T:go("R2D1C2 F1x0C2 F1x0C2 F1x0C2 C1U1C1")
	T:place("ladder","down")
	T:go("U1C1")
	T:place("ladder","down")
	T:go("U1C1")
	T:place("ladder","down")
	T:go("U1C1")
	T:place("ladder","down")
	T:go("B1")
	T:place("water", "forward")
	T:go("U1R2")
end

function createFarmNetworkStorage(withStorage, removeLegacy)
	if removeLegacy == nil then removeLegacy = false end
	-- new or converted farm will have:
	-- 2 modems, 1 barrel per plot
	-- primary plot and storage needs 1 modem, 1 barrel, 8 chests
	local lib = {}

	function lib.placeNetwork(count, pattern)
		for i = 1, count do
			T:place("computercraft:cable", "up", true)
			if i < count then
				T:go(pattern)
			end
		end
	end

	-- called when starting at lower left side of plot, facing crops
	if removeLegacy then
		T:go("L1F1")
		local blockType = T:getBlockType("down")
		if blockType == "minecraft:chest" or blockType == "minecraft:barrel" then
			while turtle.suckDown() do end	-- barrel/chest used to be present
		--T:dig("down", false)	-- do not bypass chests
			turtle.digDown()
			T:place("dirt", "down")
		end
		T:go("R2F1")	-- back over water
		while turtle.suck() do end	-- in case barrel / chest in front
		T:go("F1L1 F1U1 R2")	-- remove barrel/wall or double chest. face tree
		T:place("stone", "down")
		T:forward(1)
		T:place("modem", "down")
		-- could be tree/sapling in front
		T:forward(1)
		if T:getBlockType("down") == "minecraft:dirt" then
			T:place("barrel", "down")
			T:go("U1x0")
			T:place("dirt", "up")
			T:go("B1U2")
			if T:getBlockType("forward"):find("log") ~= nil then
				T:place("sapling", "forward")
			end
			T:go("D3F1 R1F1")
		else
			T:place("barrel", "down")
			T:go("R1F1")
		end
		while turtle.suckDown() do end
		T:place("modem", "down")
		U.attachModem()
		T:clear()
		T:go("F1x2 R2C2 F1L1 F1D1")
	end

	T:go("L1D3") -- move below crop field, face N
	utils.createBasement(true, true, 10, 10)	-- ends facing N 1 block below water source
	-- Close all leaking water sources
	T:go("U1 L1C1 L1C1")
	T:go("B1C1 B8 R1C1 R1C1 L1")				-- move N backwards along W edge, end facing W on N edge
	T:go("B1C1 B8 R1C1 R1C1 L1")
	T:go("B1C1 B8 R1C1 R1C1 L1")
	T:go("B1C1 R2F7 L1F1 R1F1x1 R2C1 B1L1") 	-- move to corner, face W along front edge
	-- 1 block below barrel, facing N. If farm to left, will be cable above

	T:place("computercraft:cable", "up")		-- cable placed under barrel
	T:go("F1R2 C1x0")							-- block placed under cable, block above removed
	T:place("computercraft:cable", "up")		-- cable placed up
	T:go("B1C1 R2")								--
	lib.placeNetwork(9, "F1x0x2")

	for i = 1, 3 do
		T:go("R1C1 L1F1")							-- in NW corner, facing N
		T:place("computercraft:cable", "up")
		T:go("R2C1 L1")								-- 1 block below NW corner, facing E
		T:go("F1x0 F1x0 R2 F1C1")						-- in NW corner, facing E, 2 blocks further E
		T:place("computercraft:cable", "up")
		T:go("B1C1 R2")									-- in NW corner, facing E, 2 blocks further E
		lib.placeNetwork(9, "F1x0x2")
	end

	T:go("R1C1 L1F1")							-- in SE corner, facing S
	T:place("computercraft:cable", "up")
	T:go("R2C1")								-- under network under barrel, facing E side

	if withStorage then
		T:go("F2R2 C1R2 F3L1")					-- under mid network cable run facing in
		lib.placeNetwork(6, "D1")				-- build cable down under floor level
		lib.placeNetwork(6, "F1x0")				-- continue under floor to chest area
		T:go("F1U2")
		T:place("computercraft:cable", "down", true)
		T:go("U1")
		T:place("computercraft:cable", "down", true)
		T:go("U1")
		utils.createStorage()					-- places modem and chests
		-- R.data used for "new" or extension direction: "right" or "back"
		if R.data == "new" then
			T:go("L2F5 R1D1 F5L1 F2L1")			-- ends 4 below south edge, 1 block south S, facing E
		end
	else
		if R.data == "new" then
			T:go("R1F1 R2C1 R1D2")				-- ends 4 below south edge, 1 block south S, facing E
		end
	end
	if R.data == "new" then
		for i = 1, 5 do
			T:go("C1U1")
			T:place("ladder", "down")
		end
	else
		T:go("D1C0 D1")
	end

	return "Farm created with networking"
end

function createFarm()
	-- R.data used for "new" or extension direction: "right" or "back"
	-- R.networkFarm = true. All farms will use network storage
	-- R.goDown = true (build storage)
	-- R.misc = true = pumpkin / melon

	local lib = {}

	function lib.addWaterSource(pattern)
		-- pattern = {"d","c","c","d"} t = place crafting  instead of dirt
		-- place(self, blockType, damageNo, direction, leaveExisting, signText)
		T:go("D1x2C2", false, 0, false, R.useBlockType)
		for i = 1, 4 do
			T:dig("forward")
			if pattern[i] == "d" then
				T:place("dirt", "forward", false)
			-- elseif pattern[i] == "t" then
				-- if T:place(storage, "forward", false) then
					-- if T:dropItem("crafting", "forward", 0) then
						-- print("Crafting table -> buried storage")
					-- end
				-- else
					-- T:place("dirt", "forward", false) -- dirt if no storage available
				-- end
			elseif pattern[i] == "c" then
				T:place(R.useBlockType, "forward", false)
			end
			T:turnRight(1)
		end
		T:up(1)
		T:placeWater("down")	-- ends facing same direction as started, over water source
	end

	function lib.placeDirt(count, atCurrent)
		if atCurrent then
			local blockType = T:getBlockType("down")
			if blockType:find("dirt") == nil and blockType:find("grass_block") == nil then
				T:place("dirt", "down", false)
			end
		end
		for  i = 1, count do
			T:forward(1)
			T:dig("up")
			local blockType = T:getBlockType("down")
			if blockType:find("dirt") == nil and blockType:find("grass_block") == nil then
				T:place("dirt", "down", false)
			end
		end
	end

	function lib.placeStorage(storage, storageBackup)
		T:dig("down")
		if not T:place(storage, "down", false) then-- place barrel/chest below
			T:place(storageBackup, "down", false) -- place chest below
		end
	end

	local blockType = ""

	local numPlots = 0
	local storage, storageBackup = utils.setStorageOptions()	-- storage type(s) onboard eg "barrel", "barrel"
	R.useBlockType = T:getMostItem("minecraft:dirt", true)		-- exclude dirt from choice
	if R.data == "right" then				-- extendFarm called. Position should be facing crops
		T:up(1)
		utils.goBack(1)
		repeat
			T:forward(11)
			numPlots = numPlots + 1
		until not utils.isStorage("down") 	-- on top of chest, barrel or modem
		T:go("R1F1R2")						-- move to front right corner of last plot on right side
	elseif R.data == "back" then			-- extendFarm called. Position should be facing crops
		T:go("L1U1")
		utils.goBack(1)
		repeat
			T:forward(11)
			numPlots = numPlots + 1
		until not utils.isStorage("down") 	-- on top of chest, barrel or modem
		T:go("L1F1 R1x2")					-- could dig tree or sapling + block below
	else 									-- new farm.
		T:up(1) 							-- assume on the ground, go up 1
	end

	-- design change: sapling placed 2 blocks above corner for ease of walking round
	-- barrel on corner
	-- modems on each side N/E
	T:place("barrel", "down", false)

	-- stage 2 place sapling
	T:up(3)
	T:place("dirt", "down")
	T:up(1)
	T:place("sapling", "down") -- plant sapling
	T:go("F1D4")
	T:place("modem", "down", false)
	U.attachModem()
	T:forward(1)
	T:place(R.useBlockType, "down", false)

	if R.data == "right" then -- cobble wall exists so go forward to its end
		T:forward(9)
	else -- new farm or extend forward
		for i = 1, 9 do -- complete left wall to end of farm
			T:go("F1 x0x2 C2", false, 0, false, R.useBlockType)
		end
	end
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	T:go("R1F1 R1x0 x2C2 F1D1", false, 0, false, R.useBlockType)-- turn round ready for first dirt col
	lib.addWaterSource({"d","c","c","d"}) -- water at top of farm
	lib.placeDirt(9, false) 	-- place dirt back to start
	-- water source next to modem
	lib.addWaterSource({"c","c","d","d"})
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock
	T:go("U1F1L1")
	T:place("modem", "down", false)
	T:go("F1C2 L1F1 D1", false, 0, false, R.useBlockType)
	lib.placeDirt(9, true)
	local turn = "R"
	for i = 1, 7 do
		T:go("F1U1x0C2"..turn.."1F1"..turn.."1x0 x2C2 F1D1", false, 0, false, R.useBlockType)
		lib.placeDirt(9, true)
		if turn == "R" then
			turn = "L"
		else
			turn = "R"
		end
	end
	T:go("F1U1x0C2"..turn.."1F1"..turn.."1x0x2C2F1D1", false, 0, false, R.useBlockType)
	lib.addWaterSource({"d","c","c","d"})	-- bottom right
	lib.placeDirt(9, false)
	lib.addWaterSource({"c","c","d","d"})	-- top right, facing away from plot
	T:go("F1U1 R1C2 x0F1 x0x2 C2R1", false, 0, false, R.useBlockType)
	for i = 1, 11 do	-- build right wall from top of plot to bottom
		T:go("F1x0x2C2", false, 0, false, R.useBlockType)
	end
	T:go("R1F10")				-- ends on top of front modem facing tree
	if R.misc then
		-- add solid blocks for melon or pumpkin farm
		T:go("R1F5 R1")
		for i = 1, 10 do
			T:go("C2F1")
		end
		T:go("L1F1 L1F1")
		for i = 1, 10 do
			T:go("C2F1")
		end
		T:go("L1F6 L1F1 L2")
	end
	U.attachModem()
	T:clear()
	T:go("R1F1D1R1")	-- over water source, facing E (crops)
	if R.data == "new" and R.goDown then	-- primary plot, user chose to add storage
		createFarmNetworkStorage(true)		-- add networking and storage
	else
		createFarmNetworkStorage(false)		-- add networking, no storage
	end
	-- if R.data == "right" then
		-- T:up(1)
		-- utils.goBack(numPlots * 11)
		-- T:down(1)
	-- elseif R.data == "back" then
		-- T:go("R1U1F".. numPlots * 11 .."D1L1")
	-- end
	return {"Modular farm completed"}
end

function createFarmExtension()
	-- R.data = "right" or "back"
	-- R.networkFarm = true
	-- R.misc = true or false: true = melon or pumpkin

	checkFarmPosition()

	if not R.ready then
		return {"Unable to determine starting position"}
	end

	createFarm()
	return {"Modular crop farm extended"}
end

function createMobFarmCube()
	--[[
	Part 1 / 3 Mob Spawner Farm
	blaze = true: blaze spawner in nether
		R.subChoice is set to:
		1 = on top of spawner
		2 = line of sight
		3 = room below
	blaze = false: overworld mob spawner
	R.data = "spawner" or "chest" if chests present
	Always place a chest at base of spawner for collecting mob drops
	and storage of 2 water buckets and 2 slabs
	]]
	R.useBlockType = T:getMostItem("", true) -- exclude none, use stone only/netherrack
	-- need external chest to empty internals
	if T:getItemSlot("chest") == 0 then
		T:checkInventoryForItem({"minecraft:chest"}, {1}, true)
	end
	local blaze = false	            -- R.data = "blaze"
	if R.data == "blaze" then
		blaze = true
	end

	menu.clear(true)

	local lib = {}

    function lib.buildBase()
        --[[
            1 |c|c|c|c|c|c|c|c|c|c|c|
            2 |w| | | | | | | | | |w|
            3 |w| | | | | | | | | |w|
            4 |w| | | | | | | | | |w|
            5 |w| | | | | | | | | |w|
            6 | | | | | |S| | | | | | S = spawner
            7 |*| | | | | | | | | |*|
            8 |*|*| | | | | | | |*|*|
            9 |*|*|*| | |O| | |*|*|*| partial floor O = opening. Turtle sits above chest to attack
           10 |*|*|*|*|*|C|*|*|*|*|*| sub floor. C = chest or barrel
        ]]
        T:go("R2F6 D6x1x2")                 -- descend to base of dungeon. level 9 clear blocks forward and down
        T:go("R1F2 U1x1 R2 F3x2 F1x2 F1U1") -- level 8, ending on level 7
        T:go("F1R2 F8 U1F1")                -- level 7 ending on level 6
        T:go("R2F10 U1F1")                  -- level 6 ending on level 5
        T:go("R2F12 B6L1 D4")               -- level 5 ending on level 9
        if T:place("chest", "down", false) then
            -- drop 2 x water if present
            -- T:dropItem(item, direction, keepAmount, except)
            T:dropItem("minecraft:water_bucket", "down") -- puts water buckets in first 2 slots
            T:dropItem("minecraft:water_bucket", "down")
            T:dropItem("slab", "down")
            if R.data == "chest" then    -- if known chests in the area
                T:emptyInventory("down") -- empty all supplied stone
            end
        end

        T:go("U6R2") -- should be level 4, facing spawner, repair block above
    end

    function lib.clearChest()
		local blockType = T:getBlockType("down")
		if blockType:find("chest") ~= nil then
            while turtle.suckDown() do end
			turtle.digDown()
		end
        blockType = T:getBlockType("forward")
		if blockType:find("chest") ~= nil then
            while turtle.suck() do end
			turtle.dig()
		end
	end

	function lib.setLocation()
    	-- clsTurtle.go(self, path, useTorch, torchInterval, leaveExisting, preferredBlock)
        -- determine spawner position level 4, move to top of spawner (level 6)
    	print("Checking if already at spawner")
    	local found, position = lib.isSpawner()               -- already on spawner?
        if blaze then
            if not found then                                 -- away from spawner
                if R.subChoice == 3 then                      -- on floor below
                    T:go("U5")
                end
                found, position = lib.findSpawner(blaze)
                if not found then
                    return false
                end
            end
        else                                                   -- go to bottom of dungeon and empty chests
            if found then                                      -- next to spawner
                lib.placeSlab(position)                        -- now on top of slab facing back of dungeon
            else                                               -- not next to spawner: outside dungeon or close by
                lib.enterDungeon()                             -- go inside and face spawner assuming it is on the floor
                local found, position = lib.findSpawner(blaze) -- is spawner in front / above / below?
                if found then
                    lib.placeSlab(position)
                else
                    return false
                end
            end
        end
        return true
	end

	function lib.floorSection(length)
		for i = 1, length do		-- starts on top left corner
			T:go("C2")
			if i < length then
				T:forward(1)
			else
				T:go("R1F1")
			end
		end
	end

	function lib.wallSection(blaze)
	    -- blaze parameter set top level only in blaze spawner
	    blaze = blaze or false
        for i = 1, 4 do
            for j = 1, 11 do
                if blaze then
                    T:place("slab", "up", false)
                    --T:go("C2", false, 0, false)
                    if not turtle.detectDown() then
                        T:place("stone","down")
                    end
                else
                    --T:go("C0C2", false, 0, false)
                    if not turtle.detectUp() then
                        T:place("stone", "up")
                    end
                    if not turtle.detectDown() then
                        T:place("stone","down")
                    end
                end
                if j < 11 then
                    T:forward(1)
                else
                    T:turnRight(1)
                end
            end
        end
        -- blocks above and below placed, now fill the layer between
        T:go("R2")                             -- turn round
        for i = 1, 4 do
            for j = 1, 10 do
                if j < 10 then
                    T:go("B1C1", false, 0, false)
                    if not turtle.detectUp() then
                        T:place("stone", "up")
                    end
                    if not turtle.detectDown() then
                        T:place("stone","down")
                    end
                else
                    if i < 4 then
                        T:go("B1C1 R1", false, 0, false)
                        if not turtle.detectUp() then
                            T:place("stone", "up")
                        end
                        if not turtle.detectDown() then
                            T:place("stone","down")
                        end
                    else
                        T:go("R1B1 C1R2", false, 0, false)  -- back inside facing front
                    end
                end
            end
        end
        -- turtle will be in top right corner in centre layer of new wall section
	end

	function lib.digWallSection(check)
	    -- dig a block above, below and in front of turtle
		if check == nil then check = false end
        if turtle.detectUp() then
            if check then
                local blockType = T:getBlockType("up")
        		if blockType:find("spawner") == nil then
        			turtle.digUp()
        		end
            else
                turtle.digUp()
            end
        end
        if turtle.detectDown() then
            if check then
                local blockType = T:getBlockType("down")
                if blockType:find("spawner") == nil then
                    turtle.digDown()
                end
            else
                turtle.digDown()
            end
        end
        if turtle.detect() then
            if check then
                local blockType = T:getBlockType("forward")
                if blockType:find("spawner") == nil then
                    turtle.dig()
                else
                    return false -- spawner in front, do not dig!
                end
            else
                turtle.dig()
            end
        end
        -- returns false if spawner in front
        return true
	end

	function lib.clearWall(length, check)
        -- cuts a 3 block high rectangular perimeter
        if check == nil then check = false end
        for i = 1, 4 do
            for j = 1, length do
                if j < length then
                    if lib.digWallSection(check) then
                        turtle.forward()
                    else
                        return false
                    end
                else
                    turtle.turnRight()
                end
            end
        end
        return true
		-- ends at starting position / facing
	end

	function lib.isSpawner()
	    -- recursive call if torch is found below or in front
        local blockType = T:getBlockType("down")
        if blockType:find("spawner") ~= nil then
            return true, "top"
        end
		if blockType:find("torch") ~= nil then
            turtle.digDown()
            turtle.down()
			return lib.isSpawner()
		end
		blockType = T:getBlockType("up")
		if blockType:find("spawner") ~= nil then
			return true, "bottom"
		end
		blockType = T:getBlockType("forward")
        if blockType:find("spawner") ~= nil then
            return true, "forward"
        end
        if blockType:find("torch") ~= nil then
            turtle.dig()
            turtle.forward()
			return lib.isSpawner()
		end
		return false, ""
	end

	function lib.gotoSpawner(maxSteps)
        local blockType = T:getBlockType("down")
        while maxSteps > 0 do
            if blockType:find("spawner") == nil and blockType:find("slab") == nil then
                T:forward(1)
            else
                return true
            end
            maxSteps = maxSteps - 1
            blockType = T:getBlockType("down")
        end
		return false
	end

	function lib.findChests()
        -- start above slab / spawner, spiral round 7x7 blocks with spawner at centre
		local A, B, C = "R1F1", "F1", "F1R1"
        local pattern =
        {
            A,
            A, C,
            B, C,
            B, B, C,
            B, B, C,
            B, B, B, C,
            B, B, B, C, B,
            B, B, B, C,
            B, B, B, B, C,
            B, B, B, B, B, C,
            B, B, B, B, B, C,
            B, B, B, B, B, B
        }
        turtle.back()
        turtle.down()
        local blockType = T:getBlockType("forward")
		if blockType:find("spawner") ~= nil then
            T:up(1)                             -- facing slab placed earlier
        end
        T:turnRight(2)                          -- facing away from spawner
		for _, move in ipairs(pattern) do
		    T:go(move)
            lib.clearChest()
			--utils.waitForInput("Next?")
		end
        T:go("R1F3 L1F3")
        while turtle.down() do end              -- go down to previously placed chest
        while turtle.dig() do end               -- create space for chest in front loop in case of gravel
        if T:place("chest", "forward") then     -- if chest placed
            T:emptyInventory("forward")         -- empty inventory into forward chest
        end
        while turtle.suckDown() do end          -- retrieve stone dumped earlier
        -- return to spawner
        T:go("U6R2")
        if not lib.gotoSpawner(8) then -- should be facing spawner
            return false
        end
        return true
		-- ends with turtle on top of slab
	end

	function lib.floodFloor()
	    -- starts above chest. Water and slabs stored in chest. used for flooding
        turtle.select(16)
        turtle.dropDown()
        turtle.select(15)
        turtle.dropDown()
        turtle.select(14)
        turtle.dropDown()
        turtle.suckDown()                           -- water bucket chest slot 1
        turtle.suckDown()                           -- water bucket chest slot 2
        turtle.suckDown()                           -- slabs chest slot 3
        -- return to back wall and place blocks
        T:go("F10L1 F4L2U1")                                        -- to NW corner
        T:go("C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2 R1F1R1")   -- 9 blocks N wall
        T:go("C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2F1 C2 L1F1L1")   -- 9 blocks N wall - 1
        T:go("C2F1 C2F1 C2F1 C2F2 C2F1 C2F1 C2F1 C2 R1F1R1")        -- 8 blocks N wall - 2
        T:go("C2F1 C2F1 C2F4 C2F1 C2F1 C2 L1F1L1")                  -- 6 blocks N wall - 3
        T:go("C2F1 C2F6 C2F1 C2 R1F1R1")                            -- 4 blocks N wall - 4
        T:go("C2F8 C2 R1F5 R1U1")                                   -- 2 blocks N wall - 5 then return to NW corner
        T:placeWater("down")                                        -- place water NW corner
        T:go("F8R1")                                                -- move to NE corner
        T:placeWater("down")                                        -- place water NE corner
        T:go("F8R1 F3L1 D1")                                        -- back to R side of entrance
        T:dig("forward")
        T:place("slab", "forward")
        T:go("R1F2L1")
        T:dig("forward")
        T:place("slab", "forward")
        T:go("L1F1 D1R1 F2R2")
	end

	function lib.enterDungeon()
		--[[ find and empty any chests, return to dungeon wall ]]
		print("Entering dungeon")
		--local found, position = false, ""						-- initialise variables
		local blockType = T:getBlockType("forward")
		if blockType ~= "" then 								-- attempt entry into dungeon wall
			T:go("U2F2")									    -- go up 2 enter via single block. no mobs can escape
			while turtle.down() do end 							-- either on floor or chest if one at this position
			blockType = T:getBlockType("down")
			if blockType:find("chest") ~= nil then
			    R.data = "chest"                                -- notify chest found
				T:go("F1D1") -- on floor level facing spawner
			end
		end
	end

    function lib.placeSlab(position)
        if position == "forward" then
            T:go("U1F1")
        elseif position == "bottom" then
            T:go("B1U2 F1")
        end
        -- else assume on top
        T:up(1)
        T:place("slab", "down", true)                                       -- place slab on top T:place(blockType, direction, leaveExisting)
    end

    function lib.noSpawner()
        return {"Spawner not found. Place me on top,","immediately below, or facing it.","\nEnter to quit"}
    end

	function lib.findSpawner(blaze)
		local moves  = 0
		-- assume turtle placed on centre of inside spawner wall in front of spawner
		-- or as close as possible in Nether
		print("Checking if next to spawner")
		local found, position = lib.isSpawner() -- true/false, top/bottom/nil
		if not found then -- move forward towards spawner
			print("Not close to spawner")
			if blaze then -- could be behind a wall
				print("Assuming blaze spawner behind a wall")
				T:forward(1)
				moves = moves + 1
				while turtle.forward() and not quit do
					moves = moves + 1
					if moves > 16 then
						quit = true
					end
				end
				found, position = lib.isSpawner() -- true/false, top/bottom/nil
                if not found then
                    T:go("R2F" .. moves + 2 .. "R2")
                end
            else
                while not found do
                    if turtle.forward() then
                        moves = moves + 1
                        if moves > 16 then
                            return found, position
                        end
                        found, position = lib.isSpawner() -- true/false, top/bottom/nil
            			if found then
            			    return found, position
            			end
                    else
                        return found, position            -- not found return false, ""
                    end
                end
			end
		end

		return found, position
	end

    --***************** Start here *******************************************************
            --[[
       1 |c|c|c|c|c|c|c|c|c|c|c|
       2 |w| | | | | | | | | |w|
       3 |w| | | | | | | | | |w|
       4 |w| | | | | | | | | |w|
       5 |w| | | | | | | | | |w|
       6 |w| | | | |s| | | | |w|
       7 |w| | | | | | | | | |w|
       8 |w|S| | | | | | | |S|w|
       9 |w|f| | | |o| | | |f|w| partial floor
      10 |f|f|f|f|f|c|f|f|f|f|f| sub floor
          1 2 3 4 5 6 7 8 9 1 1
                            0 1
    ]]
    local found = lib.setLocation()
	if not found then
		return lib.noSpawner() -- return error message
	end
	lib.buildBase()                                 -- build base, place chest
    if lib.gotoSpawner(8) then                      -- should be facing spawner
        if R.data == "chest" then
            print("Searching for chests")
            if not lib.findChests() then            -- go round emptying chests. Finish with turtle on top of slab
                return lib.noSpawner()
            end
        end
    else
        return lib.noSpawner()
    end
	T:go("U2F5 R1F5 R1") 							-- Level 2: now placed 1 below ceiling inside wall, top right corner of new dungeon
	lib.wallSection(blaze) 							-- fix layers 1, 2, 3 including ceiling margin turtle at Level 2
	utils.ceiling(blaze)							-- fix ceiling, end SW corner
    T:go("R2D3")                                    -- now on level 5 (slab level)
	lib.clearWall(9, false)						    -- clear the 9 x 9 area around the spawner levels 4,5,6
	T:go("F1R1F1L1")                                -- move closer to centre
	lib.clearWall(7)								-- clear the 7 x 7 area around the spawner
	T:go("F1R1F1L1")                                -- move closer to centre
	lib.clearWall(5)                                -- clear the 5 x 5 area around the spawner. Also needed for cave spiders
    T:go("F1R1F1L1")                                -- move closer to centre
	if not lib.clearWall(3, true) then			    -- clear the 3 x 3 area around the spawner. removes torches. level 6
	    return lib.noSpawner()
	end
	T:go("F5R1 F6L1F1R2", false, 0, false)			-- return from ceiling, enter wall below previous section: Level 5
	lib.wallSection(false) 							-- deal with areas from spawner level up (4,5,6). walls only exit level 5
    T:down(3)
	-- set R values for clearRectangle()
	R.width = 9
	R.length = 9
	R.up = true
	R.down = true
	clearRectangle()    -- clear levels 7,8,9
	T:go("L1F1 L1F1L2", false, 0, false) 			-- go inside wall section, ready for next wall section
	lib.wallSection() 								-- deal with walls on levels 7,8,9
	T:down(3)
	clearRectangle()                                -- clear levels 10,11,12
	if blaze then
		T:go("L1F1 L1F1L2", false, 0, false) 		-- ready for next wall section
		lib.wallSection() 							-- wall on layers 10,11,12
		T:down(3)
		clearRectangle()                            -- clear levels 13, 14, 15
	end
	T:go("L1F1L1F1L2", false, 0, false)             -- ready for next wall section
    lib.wallSection()                               -- wall on layers 10,11,12 or 12,13,14 if blaze
    if blaze then
        utils.placeFloor(9, 9, brick)               -- place brick floor on level 14
        T:go("L1F4 R1F2 U4R2")                      -- ends facing in to lower chamber ?below staircase
        -- now needs to build killzone
    else
        T:up(1)
        utils.placeFloor(9, 9, "stone")             -- ends facing wall on entrance side
        T:go("L1F4 R1F2 R2")                        -- return to mid-point front. exit at bottom of dungeon, over chest placed earlier
        lib.floodFloor()
    end

	return {}
end

function createMobFarmCubeBlaze()
	return createMobFarmCube()
end

function createTreefarm()
	local lib = {}
    -- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	-- T:place(blockType, direction, leaveExisting, signText, doNotAttack)
	function lib.buildWallSection(section, useBlockType)
		-- build a layer 1 block high below turtle
		for i = 1, #section do
            local block = section:sub(i, i)
			if block == "l" then
				T:place("log", "down", false)
			elseif block == "m" then
				T:place("modem", "down", false)
			elseif block == "b" then
				T:place("barrel", "down", false)
				T:drop("down", "dirt", 64)	-- T:drop(direction, slot, amount): override number 'slot' with string 'dirt'
			elseif block == "c" then
				T:place("cable", "down", false)
			else
				T:place(useBlockType, "down", false)
			end
			if i < #section then
				T:forward(1)
			end
		end
	end

	function lib.placeFloor(length, useBlockType)
		for i = 1, length do
			while turtle.digUp() do end
			turtle.digDown()
			T:place(useBlockType, "down")
			--T:go("x0C2", false, 0, false, useBlockType)
			if i < length then
				while not turtle.forward() do
					turtle.dig()
				end
				--T:forward(1)
			end
		end
	end

	function lib.placeWater(length)
		T:placeWater("down")
		T:go("F"..length.."R1")
	end

	function lib.placeCorners(length, numBlocks, useBlockType)
		for i = 1, numBlocks do
			T:go("C2F1", false, 0, false, useBlockType)
		end
		-- now at 5th space
		T:forward(length - (numBlocks * 2))
		for i = 1, numBlocks do
			T:go("C2", false, 0, false, useBlockType)
			if i < numBlocks then
				T:forward(1)
			end
		end
	end

	function lib.turn(outward)
		if outward then
			T:go("R1F1R1")
		else
			T:go("L1F1L1")
		end
		return not outward
	end

	function lib.findLegacyStart()
		T:turnRight(1)
		local block = T:getBlockType("down")
		if block:find("polished") ~= nil then
			return ""	-- in correct position, facing centre of front wall
		end
		-- assume on left corner
		T:forward (1)
		local couint = 0
		while (T:getBlockType("down")):find("polished") == nil do
			T:forward(1)
			count = count + 1
			if count > 10 then
				return "Unable to locate polished block"
			end
		end
		return ""
	end

	function lib.floodFarm()
		local outward = true
		T:sortInventory(false)
		for i = 1, R.width - 2 do
			lib.placeFloor(R.length - 2, R.useBlockType)
			if i < R.width - 2 then
				outward = lib.turn(outward)
			end
		end
		T:go("U1R2") -- over 13 x 13 internal area opposite corner
		-- now add corners
		lib.placeCorners(R.length - 2, 4, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 3, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 2, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 1, R.useBlockType)
		if outward then
			T:go("R1F"..R.width - 9 .."R1")
		else
			T:go("L1F"..R.width - 9 .."L1")
		end
		outward = not outward
		lib.placeCorners(R.length - 2, 1, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 2, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 3, R.useBlockType)
		outward = lib.turn(outward)
		lib.placeCorners(R.length - 2, 4, R.useBlockType) -- should be back in starting corner facing front

		T:go("U1R1")
		lib.placeWater(R.length - 3) -- place water down then move forward, turn right
		lib.placeWater(R.width - 3)
		lib.placeWater(R.length - 3)
		lib.placeWater(R.width - 3)
		T:go("F".. math.floor((R.length - 2) / 2).."R1F".. math.floor((R.width - 2) / 2)) -- should be in centre

		--T:go("D6x2 F1x2 F1x2 F1x2 F1x2 F1x2 F1x2 F1x2 F1x2 F1x2 R1F7 R1U1")
		T:go("D6F7 R1F7 R1U1") -- end facing back at left corner, 1 block above floor/1 below ceiling
	end

	function lib.clearBasement()
		-- T:sortInventory(false)
		-- T:dropItem("seeds", "forward")
		-- T:dropItem("flint", "forward")
		-- clearRectangle({width = 15, length = 15, up = true, down = true})
		utils.createBasement(true, true, 15, 15)	-- end facing back at left corner, 1 block above floor/1 below ceiling
		-- area has been cleared. starts facing back, 1 block above ground, 1 block below ceiling
		T:go("R1U1")
		for i = 1, 14 do	-- place cable into gutter beneath front of farm
			T:place("cable", "up", false)
			if i < 14 then
				T:forward(1)
			end
		end
		-- ends right side facing right, just below ceiling
	end

	local blockType
	local blockModifier
	R.useBlockType = T:getMostItem("", true)
	-- R.data = "new", "left", "right" or "back" to extend tree farm
	-- R.data = "convert" or "convertStorage" for legacy farm
	-- R.up = true if clear area
	-- R.goDown to create storage area
	utils.waitForInput("IMPORTANT! follow me underneath\nto activate modems when prompted")

	if R.inventoryKey ~= "" then
		R.data = R.inventoryKey
	end
	if R.up then
		if R.data == "left" then -- clearArea() start position is bottom left
			turtle.turnLeft()
		end
		clearArea()
		if R.data == "left" then -- clearArea() end position is bottom left
			turtle.turnRight()
		end
	end
	-- R.data = "new", "left", "right", "back"
	-- R.up = clear area
	-- R.goDown = add storage: usually on new farm

	if R.data == "new" then -- new treeFarm, Start at current position
		-- build 4 wall sections in 2 passes
		T:down(1)
		lib.buildWallSection("---------------", R.useBlockType)		-- left wall (15 blocks)
		T:go("R1F1")
		for i = 1, 2 do
			lib.buildWallSection("--------------", R.useBlockType)	-- back/ right wall (14 blocks)
			T:go("R1F1")
		end
		lib.buildWallSection("------c------", R.useBlockType)		-- front wall (14 blocks) c = network cable
		T:go("U1F1R1")
		lib.buildWallSection("---------------", R.useBlockType)		-- left wall top (15 blocks)
		T:go("R1F1")
		for i = 1, 2 do
			lib.buildWallSection("--------------", R.useBlockType)	--back/right wall (14 blocks)
			T:go("R1F1")
		end
		--lib.buildWallSection("-----lmb-----", R.useBlockType)	--front wall (14 blocks) log/modem/barrel
		lib.buildWallSection("-----lmb", R.useBlockType)
		utils.goBack(1)
		U.attachModem()
		T:forward(2)
		lib.buildWallSection("-----", R.useBlockType)
		T:go("R1F1 D2") -- over 13 x 13 internal area
	elseif R.data == "left" or R.data == "right" or R.data == "back" then
		-- build 3 wall sections in 2 passes
		if R.data == "left" then										-- should be on left corner of existing
			T:go("L1F1 D1") 											-- move left 1 blocks, down 1: <-
			lib.buildWallSection("------c-------", R.useBlockType)		-- front wall (14 blocks) c = network cable <-
			T:go("R1F1")
			lib.buildWallSection("--------------", R.useBlockType)		-- left wall (14 blocks) ^
			T:go("R1F1")
			lib.buildWallSection("-------------", R.useBlockType)		-- back wall (13 blocks) ->
			T:go("U1R2")												-- turn round ready to add next layer <-
			lib.buildWallSection("--------------", R.useBlockType)		-- back wall top (14 blocks) <-
			T:go("L1F1")
			lib.buildWallSection("--------------", R.useBlockType)		-- left wall top (14 blocks) v
			T:go("L1F1")
			lib.buildWallSection("-----bm", R.useBlockType)			-- front wall (7 blocks) barrel/modem ->
			U.attachModem()
			T:forward(1)
			lib.buildWallSection("l-----", R.useBlockType)				-- front wall (5 blocks) log ->
			T:go("R2F12 R1F1 D2") 										-- over 13 x 13 internal area lower left side
		elseif R.data == "right" then									-- should be on right corner of existing
			T:go("R1F1 D1") 											-- move right, forward, down 1
			lib.buildWallSection("------c-------", R.useBlockType)	-- front wall (14 blocks) c = network cable
			T:go("L1F1")
			lib.buildWallSection("--------------", R.useBlockType)		-- right wall (14 blocks)
			T:go("L1F1")
			lib.buildWallSection("-------------", R.useBlockType)		-- back wall (13 blocks)
			T:go("U1R2")												-- turn round ready to add next layer
			lib.buildWallSection("--------------", R.useBlockType)		-- back wall top (14 blocks)
			T:go("R1F1")
			lib.buildWallSection("--------------", R.useBlockType)		-- left wall top (14 blocks)
			T:go("R1F1")
			lib.buildWallSection("-----lmb", R.useBlockType)
			utils.goBack(1)
			U.attachModem()
			T:forward(2)
			lib.buildWallSection("-----", R.useBlockType)
			T:go("R1F1 D2") 											-- over 13 x 13 internal area
		elseif R.data == "back" then									-- should be on left front corner of existing
			T:go("R2F1 D4R2 F1") 										-- move forward 14 blocks, down 1
			for i = 1, 15 do
				T:place("cable", "up")
				T:forward(1)
			end
			T:up(1)
			if T:getBlockType("up") == R.useBlockType then				-- already a farm on left side
				T:go("U2C2 U1C2 F13R1 F1D1", false, 0, false, R.useBlockType)
				lib.buildWallSection("--------------", R.useBlockType)	-- back wall (14 blocks)
				T:go("R1F1")
			else
				T:up(2)
				lib.buildWallSection("--------------", R.useBlockType)	-- left wall (14 blocks)
				T:go("R1F1")
				lib.buildWallSection("--------------", R.useBlockType)	-- back wall (14 blocks)
				T:go("R1F1")
			end

			lib.buildWallSection("-------------", R.useBlockType)		--right wall (13 blocks) no special blocks
			T:go("U1R2")	-- turn round ready to add next layer
			for i = 1, 2 do
				lib.buildWallSection("--------------", R.useBlockType)	--right wall top (14 blocks) no special blocks
				T:go("L1F1")
			end
			lib.buildWallSection("-------------", R.useBlockType)		-- left wall top (13 blocks) no special blocks
			T:go("F1L1 F7x2")
			T:go("D1x2")
			T:place("cable", "down")
			T:up(1)
			T:place("modem", "down")
			T:go("F1R2x2")
			T:place("log", "down")
			T:go("F2x2")
			T:place("barrel", "down")
			utils.goBack(1)
			U.attachModem()
			T:go("F6R1 F1D2")
		end
	else -- convertStorage or convert
		-- legacy farm had polished block on positions 4 / (10) from left corner
		 local message = lib.findLegacyStart()
		 if message ~= "" then
			return {message}
		 end
		 -- now on top of polished block, 4 from left corner, facing Centre
		 T:forward(2)
		 T:place("barrel", "down", false)
		 T:go("F1D1")
		 T:place("cable", "down", false)
		 T:up(1)
		 T:place("modem", "down", false)
		 U.attachModem()
		 T:forward(1)
		 T:place("log", "down", false)
		 T:go("R1F1 R1F1 D5R1 F1x0L1 F1x0 F1x0 F1x0 F1x0 F1x0 F1x0 F1x0 R1")-- left corner, facing back ready to clear basement
	end
	if (R.data):find("convert") == nil then
		lib.floodFarm()
	end
	lib.clearBasement() 				-- area has been cleared. ends right side facing right, just below ceiling

	if R.data == "back" then			-- do not make exit for player
		R.goDown = false				-- disable storage
		T:go("R2F6 R1D1")
	else
		T:go("R2F6 L1F1 x2U4") 	-- make exit for player. end mid floor/ceiling height, facing back, in centre
		for i = 1, 6 do
			T:down(1)
			T:place("ladder", "up")
		end
		T:back(1)
		T:place("ladder", "forward")
		T:go("U1R2")
	end
	for i = 1, 6 do
		T:place("cable", "up")
		T:forward(1)
	end
	if R.goDown or R.data == "convertStorage" then	-- build storage
		utils.createStorage()	-- creates on ground, 1 below current
		T:place("modem", "up")
		T:go("F1R2")
		T:place("cable", "forward")
		T:go("U2")
	else
		T:place("modem", "up")
		T:go("F1U2R2")
	end
	T:place("barrel", "down")
	T:up(1)
	T:place("hopper", "down")
	T:go("F2D2")
	U.attachModem()
	T:up(1)
	T:place("cable", "down")
	T:go("U1C2 U2F5 R2")

	return {"tree farm created"}
end

function fellTree()
	if T:isLog("forward") then
		--menu.colourPrint("Felling tree", colors.lime)
		os.sleep(2)    -- pause for 2 secs to allow time to press esc
		T:harvestTree("forward")
		while turtle.down() do end
		retValue = {"Tree Harvested"}
	elseif T:isLog("up") then
		os.sleep(2)    -- pause for 2 secs to allow time to press esc
		T:harvestTree("up")
		while turtle.down() do end
		retValue = {"Tree Harvested"}
	else
		retValue =
		{
			"No log in front..",
			"Move me in front of a tree!"
		}
	end
	return retValue
end

function floodMobFarm()
	--[[Part 2 / 3 Mob Spawner Farm turtle on floor, pointing towards water source wall, single hole]]
	local lib ={}

	function lib.setPosition(addWater)
		local width = 0
		while turtle.forward() do end					-- move forward until hit wall
		T:go("U1L1")
		while turtle.forward() do end					-- move forward until hit left wall
		if addWater then
			T:placeWater("down") 			 			-- place water down
		end
		T:turnLeft(2)									-- turn round
		while turtle.forward() do
			width = width + 1
		end			-- go forward 7
		if addWater then								-- back 1
			T:placeWater("down") 						-- place water
		end
		T:go("L2F".. math.floor(width / 2) .."L1")		-- turn round, go forward 3 (centre of wall), turn left
	end

	function lib.digFloor()
		T:go("x2F1 x2")									-- first block, move forward

		T:turnLeft(1)									-- left turn, go back into right side, facing left
		utils.goBack(1)
		T:go("x2 F1x2 F1x2 R1F1")						-- go right to left dig 3 blocks, forward on left side

		T:turnRight(1)									-- right turn, go back into left side, facing right
		utils.goBack(1)
		T:go("x2 F1x2 F1x2 F1x2 F1x2 L1F1")				-- go left to right dig 5 blocks, forward on right side

		T:turnLeft(1)									-- left turn, go back into right side, facing left
		utils.goBack(1)
		T:go("x2 F1x2 F1x2 F1x2 F1x2 F1x2 F1x2 R1F1")	-- go right to left dig 7 blocks, forward on left side

		T:turnRight(1)									-- right turn, go back into left side, facing right
		utils.goBack(1)
		T:go("x2 F1x2 F1x2 F1x2 F1x2 F1x2  F1x2  F1x2  F1x2 L1")	-- go left to right dig 5 blocks, face forward on right side
	end

	lib.setPosition(false)					-- move to back of cube and verify position
	if R.inventoryKey == "lift" then
		T:forward(3)						-- forward 4 (centre of chamber)
	elseif R.inventoryKey == "turtle" then
		T:forward(2)						-- forward 3
	end
	T:down(1)
	lib.digFloor()
	if R.inventoryKey == "lift" then
		T:go("D1F1 L1F8")
		utils.goBack(4)
		T:go("L1U1")
		lib.setPosition(true)				-- place water sources
		T:go("F8D2")
		-- go down 2, check floor, up 1, place fence
		T:go("D2C2U1", false, 0, true)
		T:place("fence", "down", false)
		T:go("F1D1C2U1", false, 0, true)
		T:place("fence", "down", false)
		T:go("F1U1R2", false, 0, true)
		T:go("F1R1U1")
		T:place("sign", "down", false)
		T:go("U1C0D1")
		T:place("slab", "up", false)
		T:go("R2F1R2")
		T:place("sign", "forward", false)
		T:go("R1F1R2C1R1F1D1L1") --sitting on soul sand/dirt facing spawner
		if not T:place("minecraft:soul_sand", "down", false) then
			T:place("minecraft:dirt", "down", false)
		end
	elseif R.inventoryKey == "turtle" then
		T:go("D1F1 L1F8")
		T:go("R1F1 R1F8")
		utils.goBack(4)
		T:go("R1U1")
		lib.setPosition(true)		-- place water sources
		T:go("F8D2 F1C2C0 F1R2")	-- exit leaving single hole in wall, facing spawner
	end

	return {}
end

function harvestBamboo()
	-- site is 12x12 blocks with 10x10 field and 6x6 growing area
	-- lower left corner has barrel with modem above
	-- |C|D|D|B|B		C = buried chest D = Dirt B = Bamboo
	-- |C|D|D|T|D		C = buried chest D = Dirt T = Turtle
	-- |M|C|C|D|D		M = Barrel buried 2 blocks down with modem on top
	-- turtle should start in front of bamboo at ground level
	local lib = {}

	function lib.operate(instruction)
		while turtle.suckDown() do end
		if instruction:find('P') ~= nil then
			-- T:place(blockType, direction, leaveExisting, signText, doNotAttack)
			if not turtle.detectDown() then
				T:place("minecraft:bamboo", "down")
			end
		end
		if instruction:find('R') ~= nil then
			turtle.turnRight()
		end
		if instruction:find('L') ~= nil then
			turtle.turnLeft()
		end
		if instruction:find('F') ~= nil then
			if turtle.detect() then
				T:forward(1)
				sleep(0.5)
				while turtle.suckDown() do end
			else
				turtle.forward()
			end
			while turtle.suck() do end
		end
	end

	function lib.plant(move)
		turtle.suckDown()
        -- T:place(blockType, direction, leaveExisting, signText, doNotAttack)
		if not turtle.detectDown() then
		    T:place("minecraft:bamboo", "down")
		end
		if move then
			turtle.forward()
		end
	end

	function lib.wait()
		local timePassed = 0
		-- check state of crop in front. Harvest if ripe
		while not turtle.detect() do
			print("Waiting for bamboo growth "..timePassed.. " minutes")
			sleep(60)
			timePassed = timePassed + 1
		end
	end

	function lib.waitForCapacity()
		-- must be running on R.auto
		T:clear()
		waitingTime = 0
		local waiting = true
		while waiting do
			local numChests, numPlanks, capacity = lib.getBambooPlanksStock()-- check if chests are full
			if capacity * 64 - numPlanks > 200 then		-- enough capacity
				waiting = false
			else
				sleep(60)
				waitingTime = waitingTime + 1
				menu.clear(true)
				menu.colourText(1, "~green~waiting for available storage "..waitingTime.." minutes  ")
			end
		end
	end

	function lib.refuel()
		turtle.select(1)
		local fuelRequired = Fuel.limit() - Fuel.level()
		--local fuelAvailable = T:getItemcount("minecraft:bamboo_planks") * 15
		local numPlanks = math.min(math.floor(fuelRequired / 15), turtle.getItemCount(1))
		if fuelRequired >= 15 and numPlanks > 0 then
			turtle.refuel(numPlanks)
			if numPlanks == 64 then
				turtle.select(2)
				fuelRequired = Fuel.limit() - Fuel.level()
				numPlanks = math.min(math.floor(fuelRequired / 15), turtle.getItemCount(2))
				turtle.refuel(numPlanks)
			end
		end
		return Fuel.level()
	end

	function lib.getBambooPlanksStock()
		local chestObjects = {peripheral.find("minecraft:chest")}
		local numPlanks = 0
		local capacity = 0
		if chestObjects == nil then								-- no chests found
			return 0, 0, 0
		end

		for _, chest in ipairs(chestObjects) do					-- iterate both chests
			local chestName = peripheral.getName(chest)
			local contents = peripheral.call(chestName, "list")
			local size = peripheral.call(chestName, "size")
			capacity = capacity + size

			for slot, item in pairs(contents) do
				if item.name == "minecraft:bamboo_planks" then
					numPlanks = numPlanks + item.count
				end
			end
	--Log:saveToLog("lib.getBambooPlanksStock() chestName = "..chestName..", size = "..size..", total capacity = "..capacity..", numPlanks = "..numPlanks )
		end
		return #chestObjects, numPlanks, capacity
	end

	function lib.getBambooFromBarrel(amount, toTurtleSlot)
	--Log:saveToLog("lib.getBambooFromBarrel(amount = "..amount..", toTurtleSlot: "..toTurtleSlot)
		-- remove <amount> bamboo from barrel and place in specified turtle slot
		-- barrel contents listed and iterated until turtle slot has received correct amount
		-- if insufficient bamboo available return false
		local contents = peripheral.call(U.barrelNames[1], "list")
		local numBamboo = 0
		local sent = 0
		for slot, item in pairs(contents) do
			if item.name == "minecraft:bamboo" then
				--numBamboo = numBamboo + peripheral.call(U.barrelNames[1], "pushItems", U.turtleName, slot, amount, toTurtleSlot)
				sent = numBamboo + peripheral.call(U.barrelNames[1], "pushItems", U.turtleName, slot, amount, toTurtleSlot)
			--Log:saveToLog("    sent " ..sent.." from slot "..slot)
				if sent == amount then
					return true
				else
					amount = amount - sent
			--Log:saveToLog("    requesting " ..amount - sent.." from next slot")
				end
			end
		end
		return false
	end

	function lib.getAllBambooFromBarrel()
		-- empties entire barrel back into turtle unless turtle inventory is full
		local contents = peripheral.call(U.barrelNames[1], "list")
		local numBamboo = 0
		for slot, item in pairs(contents) do
			if item.name == "minecraft:bamboo" then
				numBamboo = numBamboo + item.count
				-- U.pushItems(fromName, fromSlot, quantity, toName, toSlot)
				-- U.pushItems(U.barrelNames[1], slot, nil, U.turtleName, nil)
				peripheral.call(U.barrelNames[1], "pushItems", U.turtleName, slot, nil, nil)
			end
		end
		return numBamboo
	end

	function lib.emptyTurtleToBarrel()
	--Log:saveToLog("lib.emptyTurtleToBarrel():checking bamboo in inventory. Storing in "..U.barrelNames[1])
		for slot = 1, 16 do		-- iterate slots, drop contents into barrel
			local quantity = turtle.getItemCount(slot)
			if quantity > 0 then
		--Log:saveToLog("    emptying "..quantity.." from slot "..slot)
				local sent = peripheral.call(U.barrelNames[1], "pullItems", U.turtleName, slot, nil, nil)
		--Log:saveToLog("    sent "..sent.." to "..U.barrelNames[1])
			end
		end
	end

	function lib.craftBamboo(count)
		local craftAmount = math.min(math.floor(count / 9), 64)
		local slots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
		for _, slot in ipairs(slots) do
			-- peripheral.call(inventoryName, "pushItems", inventoryName, fromSlot, quantity, toSlot)
			if lib.getBambooFromBarrel(craftAmount, slot) then
		--Log:saveToLog("Slot "..slot.." recieved "..craftAmount.." bamboo from "..U.barrelNames[1].." slot "..slot)
			else
		--Log:saveToLog("Unable to get sufficient bamboo from "..U.barrelNames[1])
			end
		end

		if turtle.craft()then										-- craft bamboo to bamboo_block
			if  turtle.craft() then									-- craft bamboo_block to bamboo_planks
				local fuelLevel = lib.refuel()						-- refuel to the max with bamboo blocks
				local chestIndex = 1								-- 2 chests available
				for slot = 1, 16 do									-- iterate turtle slots
					local slotCount = turtle.getItemCount(slot)		-- count items in selected slot
					if slotCount > 0 then							-- items present
						-- sent is the number of items stored in the selected chest
						local sent = peripheral.call(U.chestNames[chestIndex], "pullItems", U.turtleName, slot, nil, nil)
				--Log:saveToLog("sent "..sent.." items from slot "..slot.." to "..U.chestNames[chestIndex])
						if sent < slotCount then					-- chest could be full
							chestIndex = 2							-- change to chest 2
							sent = sent + peripheral.call(U.chestNames[chestIndex], "pullItems", U.turtleName, slot, nil, nil)
				--Log:saveToLog("Using second chest: sent "..sent.." items from slot "..slot.." to "..U.chestNames[chestIndex])
							if sent < slotCount then				-- second chest could be full
								return {"Storage chests are full"}	-- exit tk3
							end
						end
					end
				end
			end
		end

		count = lib.getAllBambooFromBarrel()			-- check if any more bamboo in storage
		if count > 9 then								-- clear out barrel to max of 64
			lib.emptyTurtleToBarrel()
			lib.craftBamboo(count)						-- recursive call
		else
			return
		end
	end


	local status = assessFarm("bamboo")	-- checks position, returns "fail" if above bamboo, "modem" if above modem
	if status == "fail" then
		return {"Unable to determine position"}
	elseif status == "waiting" then	-- facing bamboo
		T:go("L1 F1R1") -- return to modem
	end
	--elseif status == "modem" then	-- currently over modem
	if T:getBlockType("down"):find("modem") == nil then
		return {"Unable to determine position"}
	end
	U.wrapModem(true)			-- sets U.turtleName and U.BarrelNames, U.chestNames, U.barrelObjects, U.chestObjects
	local bamboo = T:getItemCount("minecraft:bamboo")
	if bamboo > 0 then			-- drop all bamboo into the barrel
		lib.emptyTurtleToBarrel()
	end
	bamboo = lib.getAllBambooFromBarrel()
	if bamboo >= 9 then
		lib.emptyTurtleToBarrel()
		lib.craftBamboo(bamboo)	-- eg craft using 9
	end
	local numChests, numPlanks, capacity = lib.getBambooPlanksStock()-- check if chests are full
	if numChests == 0 then
		return {"Modem inactive or not in position"}
	else
		-- farm can produce 64 * 14 = 896 bamboo -> 100 bamboo_block --> 200 bamboo_planks
		if capacity * 64 - numPlanks <= 200 then		-- almost or full
			if R.auto then -- if auto just stay over modem and check every minute
				lib.waitForCapacity()
			else	-- else report and quit
				return {"Insufficient Bamboo_planks storage ("..capacity - numPlanks..")"}
			end
		end
	end
	T:go("R1F1 L1")	-- move to bamboo
	local blockType = T:getBlockType("forward")
	if blockType:find("bamboo") == nil then
		-- no bamboo in front ? new farm or player harvested
		T:checkInventoryForItem({"minecraft:bamboo"}, {64}, true, "bamboo required 1-64 + Enter")
	end
	local pattern =
	{
		"F", "F","F","F","F","F","F","F","F","RF",
		"RF", "PF","PF","PF","PF","PF","PF","PF","PF","LF",
		"LF", "PF","PF","PF","PF","PF","PF","PF","PF","RF",
		"RF", "PF","PF","PF","PF","PF","PF","PF","PF","LF",
		"LF", "PF","PF","PF","PF","PF","PF","PF","PF","RF",
		"RF", "PF","PF","PF","PF","PF","PF","PF","PF","LF",
		"LF", "PF","PF","PF","PF","PF","PF","PF","PF","RF",
		"RF", "PF","PF","PF","PF","PF","PF","PF","PF","LF",
		"LF", "PF","PF","PF","PF","PF","PF","PF","PF","RF",
		"RF", "F","F","F","F","F","F","F","F","R"
	}
	repeat
		blockType = T:getBlockType("forward")
		if blockType:find("bamboo") ~= nil then
			-- go up 10 blocks and wait
			T:up(10)
			lib.wait()					-- waits until bamboo has grown
            while turtle.down() do end -- return to groud level
			turtle.up()                 -- move up 1 so harvest can be done, leaving 1 bamboo behind
		end
		-- assume placed on lower left corner of 8x8 planting area
		local out = true
		T:forward(1)					-- enter bamboo plot
		for l = 1, 8 do
			T:forward(7)
			if out then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
			out = not out
		end
		while turtle.suckUp() do end
		T:go("B1 L1F9R1")	-- back to start

		for _, instruction in ipairs(pattern) do
			lib.operate(instruction)
		end

		T:go("D1F9R1")								-- now in lower left corner above modem
		bamboo = T:getItemCount("minecraft:bamboo")	-- Count how many bamboo in inventory
		lib.emptyTurtleToBarrel()					-- empty into barrel
		lib.craftBamboo(bamboo)						-- craft bamboo planks based on amount sent
		if R.auto then
			lib.waitForCapacity()
			T:go("R1F1 L1")						-- move to face bamboo
		end
	until R.auto == false
	return {"Bamboo harvested and replanted"}
end

function harvestObsidian()
	local lib = {}

	function lib.forward(move)
		T:isWaterOrLava("forward")	-- automatically use lava ahead to refuel
		T:isWaterOrLava("down") 	-- automatically use lava down to refuel
		T:go("C2", false, 0, false)	-- place / replace block below
		if move then
			T:forward(1)
		end
	end

	function lib.home(outward)
		if outward then
			T:go("L1F"..R.width - 1 .."L1F"..R.length - 1)
		else
			T:go("R1F"..R.width - 1 .."R1")
		end
	end

	function lib.start()
		local lavaSlot = T:getItemSlot("lava")
		if lavaSlot > 0 then
			turtle.select(slot)
			turtle.refuel()
		end
		T:down(1)
	end

	local outward = true

	lib.start()						-- use lava bucket if placed, move down into block below
	for w = 1, R.width do
		for l = 1, R.length do
			if l < R.length then
				lib.forward(true)
			else
				lib.forward(false)
			end
		end
		if w < R.width then
			if outward then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
			outward = not outward
		end
	end

	lib.home(outward)

	return {}
end

function harvestShulkers()
	local lib = {}

	function lib.attackAll()
		return turtle.attack(), turtle.attackUp(), turtle.attackDown()
	end

	function lib.attack()
		local forward, up, down = lib.attackAll()
		while forward or up or down do
			forward, up, down = lib.attackAll()
			sleep(0.2)
		end
	end

	function lib.approach(direction, limit, dig)
		-- move forward until stopped by shulker
		limit = limit or 64
		dig = dig or false
		local count = 0
		local solidDown = false
		move = turtle.forward
		if direction == "up" then
			move = turtle.up
		elseif direction == "down" then
			move = turtle.down
		end
		local forward, up, down = lib.attackAll()
		if forward or up or down then -- attacks suceeded
			return true, 0, solidDown
		else
			while move() do
				count = count + 1
				if turtle.detectDown() then
					solidDown = true
				end
				if count >= limit then
					return false, count, solidDown
				end
				forward, up, down = lib.attackAll()
				if forward or up or down then
					return true, count, solidDown
				else
					if dig then
						T:dig("forward")
					end
				end
			end
			return false, count, solidDown
		end
	end

	function lib.home(direction, moves)
		local move = turtle.back
		if direction == "up" then
			move = turtle.down
		elseif direction == "down" then
			move = turtle.up
		end
		for i = 1, moves do
			move()
		end
	end

	function lib.checkPosition()
		if T:detect("forward") then			-- wall in front
			T:turnRight(1)
			if T:detect("forward") then		-- wall to right
				T:turnLeft(1)
				return true					-- position corrected
			else
				T:turnLeft(2)
				if T:detect("forward") then	-- wall in front. position correct
					return true
				end
			end
		end
		return false
	end

	function lib.getLength()
		local count = 0
		while turtle.detectDown() do
			count = count + 1
			T:forward(1)
		end
		utils.goBack(1)
		return count
	end

	function lib.clearWall()
		local distance = 0
		while distance < 9 do	-- smallest external walls are 8 x 8
			local success, count = lib.approach("forward", 8 - distance)
			if success then
				lib.attack()
			end
			distance = distance + count
		end
		T:turnLeft(1)
		if T:detect("forward") then	-- larger than 8 blocks
			T:turnRight(1)
			while distance < 14 do	-- larger builds are 14 x 14
				local success, count = lib.approach("forward", 13 - distance)
				if success then
					lib.attack()
				end
				distance = distance + count
			end
			T:go("L1x2")
		end
	end

	function lib.roof()
		-- check position
		local doContinue = lib.checkPosition()

		if doContinue then
			T:go("U2F3 R1F3 R1")
			local length = lib.getLength()
			local width = 1
			local outward = lib.turnRound(true)
			local success, count, onRoof = false, 0, true
			while onRoof do
				local distance = 0
				while distance < length - 1 do
					success, count, onRoof = lib.approach("forward", length - 1 - distance)
					if success then
						lib.attack()
					end
					if count == 0 then
						turtle.dig()
					end
					distance = distance + count
				end
				width = width + 1
				outward = lib.turnRound(outward)
			end
			if outward then
				T:go("F".. 3 .."L1F"..width - 3 .."D2L1")
			else
				T:go("F".. length - 3 .."R1F"..width - 3 .."D2L1")
			end
			return {}
		else
			return {"Turtle not in front of a wall"}
		end
	end

	function lib.turnRound(outward)
		if outward then
			T:go("R1F1R1")
		else
			T:go("L1F1L1")
		end
		return not outward
	end

	function lib.upAndOver()
		local start, height, forward = 0, 0, 0
		while turtle.detect() do
			turtle.up()
			start = start + 1
		end
		while turtle.forward() do
			forward = forward + 1
		end
		turtle.turnRight()
		while not turtle.detectUp() do
			local success, count = lib.approach("up", 64, true)
			if success then
				lib.attack()
			end
			height = height + count
		end
		T:turnRight(2)
		while not turtle.detectDown() do
			if lib.approach("down", 64, true) then
				lib.attack()
			end
		end
		T:turnLeft(1)
		for i = 1, forward do
			turtle.forward()
		end
		for i = 1, start do
			turtle.down()
		end
		T:turnRight(2)
	end

	function lib.walls()
		local doContinue = lib.checkPosition()
		if doContinue then
			T:go("F2R1 F2R2 D1x2")		-- on corner outside middle of wall, facing along its length, dig light rod
			for i = 1, 4 do
				lib.clearWall()
			end
			T:go("F2L1 U1F2 R2")
		else
			return {"Turtle not in front of a wall"}
		end
	end

	local direction = "forward"
	local doContinue = false

	if R.subChoice == 1 then		-- Shulker is above
		direction = "up"
		doContinue = true
	elseif R.subChoice == 2 then	-- Shulker is ahead
		doContinue = true
	elseif R.subChoice == 3 then	-- Shulker is below
		direction = "down"
		doContinue = true
	else
		if R.subChoice == 4 then	-- Climb tower wall
			lib.upAndOver()
		elseif R.subChoice == 5 then	-- Clear roof above
			return lib.roof()
		elseif R.subChoice == 6 then	-- Clear outside walls
			lib.walls()
		end

	end
	if doContinue then
		local success, moves = lib.approach(direction, 64)
		if success then
			lib.attack()
		end
		lib.home(direction, moves)
	end

	return {}
end

function harvestTreeFarm()
	local lib = {}

	function lib.getLogCount()
		local count = 0
		for i = 1,16 do
			local item, itemCount = T:getSlotContains(i)
			if item:find("log") ~= nil then
				count = count + itemCount
			end
		end

		return count
	end

	function lib.initialise()
		-- assumes legacy tree farm with turtle on polished block 4 blocks from corner
		local message  = ""
		R.treeSize = "single"
		local blockType = T:getBlockType("forward")
		--local logType = ""
		--local startHeight = 0
		local range = 0
		if blockType == "" then
			while turtle.forward() do
				range = range + 1
				if range == 3 then
					break
				end
			end
		end
		blockType = T:getBlockType("forward")
		if blockType:find("dirt") ~= nil then	-- dirt found
			T:go("R1F1L1")
			blockType = T:getBlockType("forward")
			if blockType:find("dirt") ~= nil then
				R.treeSize = "double"
			end
			T:go("L1F1 R1")
		else	-- dirt NOT found where expected
			message = "Unable to determine position"
		end
		T:up(1)
		blockType = T:getBlockType("forward")	-- 1 block above dirt
		if blockType:find("log") ~= nil or blockType:find("sapling") ~= nil or blockType:find("propagule") ~= nil then
			local parts = T:getNames(blockType)
			local name = ""
			for i = 1, #parts - 1, 1 do				-- eg {"minecraft", "dark", "oak"
				if i == 1 then
					name = parts[1]..":"			-- eg "minecraft:"
				elseif i == 2 then
					name = name..parts[2]			-- eg "minecraft:dark"
				else
					name = name.."_"..parts[i]		-- eg "minecraft:dark_oak"
				end
			end
			name = name.."_sapling"					-- eg "minecraft:dark_oak_sapling"
		end
		T:down(1)	-- facing dirt

		return message
	end

	function lib.waitForGrowth()
		local pattern = R.treeSize	--"single","double"
		local elapsed = 0
		local ready = {}
		ready.left = false
		ready.top = false
		ready.right = false
		ready.bottom = false
		local facings = {"left", "top", "right", "bottom"}
		if R.logType:find("mangrove") ~= nil then
			pattern = "mangrove"
			T:up(1)	-- go up from dirt to sapling level
			while not ready.left or not ready.right or not ready.top or not ready.bottom do
				for i = 1, 4 do
					local blockType = T:getBlockType("forward")
					if blockType:find("propagule") ==  nil then	-- either grown or deleted by roots
						ready[facings[i]] = true
					end
					T:turnRight(1)
				end
				if ready.left and ready.right and ready.top and ready.bottom then
					break
				else
					sleep(15)
					elapsed = elapsed + 15
					if  elapsed / 60 > 15 then	-- max 15 mins real time before farm is harvested
						break
					end
				end
				print("Waiting for mangrove growth "..elapsed / 60 .." minutes")
				print("Left = "..tostring(ready.left)..
					  ", top = "..tostring(ready.top)..
					  ", right = "..tostring(ready.right)..
					  ", bottom = "..tostring(ready.bottom))

			end
			--T:go("L1D1")
			T:turnLeft(1)	-- face front
		else
			while true do
				T:up(1)	-- go up from dirt to sapling level
				if (T:getBlockType("forward")):find("log") ~=  nil then
					T:down(1)	-- drop below sapling to dirt level
					return
				end
				T:clear()
				print("Farm type: "..pattern)
				print("Waiting for tree growth "..elapsed / 60 .." minutes")
				print("Left grown = "..tostring(ready.left)..", right grown = "..tostring(ready.right))
				sleep(15)
				elapsed = elapsed + 15
				if pattern == "single" and elapsed / 60 > 10 then	-- max 10 mins real time before farm is harvested
					break
				elseif pattern == "double" and elapsed / 60 > 15 then	-- max 15 mins real time before farm is harvested
					break
				end
			end
		end
		if pattern == "mangrove" then
			T:go("D2F6 U1F1 R1F6 R1F1 U1")
		end
		-- ends facing dirt at base of first tree
		-- no return needed, function exit so trees are grown
	end

	function lib.harvestSingle(direction, moves)
		-- if direction == "up": starting inside tree on dirt at dirt level
	--Log:saveToLog("lib.harvestSingle('"..direction.."', moves = "..moves)
		if direction == "up" then
			while turtle.detectUp() do
				T:up(1)
				moves = moves + 1
			end
		else	-- direction = "down", but could be mid-tree
			local movesUp = 0
			while turtle.detectUp() do
				T:up(1)
				movesUp = movesUp + 1
			end
			T:down(movesUp)
			T:down(moves)
		end
		return moves
	end

	function lib.harvestSingleRow()
		-- start under dirt of first tree
		local moves = lib.harvestSingle("up", 0)
		T:go("F2")
		lib.harvestSingle("down", moves)
		T:go("F2")
		moves = lib.harvestSingle("up", 0)
		T:go("F2")
		lib.harvestSingle("down", moves)
	end

	function lib.harvestDouble()
		T:forward(1)	-- dig dirt, move into left (S) corner
		local moves = 0
		while turtle.detectUp() do
			turtle.dig()
			turtle.digUp()
			turtle.up()
			moves = moves + 1
		end
		turtle.dig()
		T:go("R1F1L1")	-- move to right corner
		for i = 1, moves do
			turtle.dig()
			turtle.digDown()
			turtle.down()
		end
		turtle.dig()
		T:go("F1L1F1R1") -- move to left corner (N)
	end

	-- R.networkFarm is now default
	menu.clear()
	menu.colourPrint("Harvesting treefarm starting", colors.lime)
	R.silent = true

	--local message = U.loadStorageLists()	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	local message = U.wrapModem(true)	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	if message ~= "" then return {message} end
	U.emptyInventory({"sapling", "propagule", "dirt"}, {"all"}, true)
	if Fuel.level() < Fuel.limit() / 2 then
		local turtleSlot, turtleCount = U.getItemFromNetwork("chest", "log", 16)
		if turtleSlot > 0 then
			if turtle.craft() then
				turtle.refuel()
			end
		end
	end
	if R.logType:find("mangrove") ~= nil then	-- mangrove
		T:go("F1D1")
		T:place("dirt", "up")
		T:go("F6x2U1L1")				-- move under dirt covering, clear roots from hopper, move level with dirt, face left
	else
		T:go("F4L1")					-- either in between 2 trees or in gap between double trees at dirt level
		if turtle.detect() then			-- single trees, move between 1st and 2nd rows
			T:go("L1F1 R1F3 R1")		-- facing first dirt 4x4 grid, facing back
			R.treeSize = "single"
		else							-- using double trees
			T:go("F1")					-- next to dirt on first double tree group
			if turtle.detect() then		-- dirt found
				T:go("L1F1 R1F2 R1")	-- move to lower left corner of 2x2 dirt, facing back
				R.treeSize = "double"
			else
				return {"Unable to determine position"}
			end
		end
	end
	--Log:saveToLog("harvestTreeFarm(): logType = "..R.logType..", treeSize = "..R.treeSize)
	lib.waitForGrowth()
	--Log:saveToLog("harvestTreeFarm(): trees grown. Starting")
	-- different clearing for different trees:
	-- mangrove clear solid cube including dirt placed over whole farm
	-- spruce and jungle: double trees staight up/down
	-- birch single up / down
	-- acacia, cherry, oak,  pale_oak and dark_oak treat as solid cube
	if R.logType:find("mangrove") ~= nil then
		R.width = 13
		R.length = 13
		R.up = true
		R.down = true
		clearRectangle()
		T:go("U2F1 R1F1L1")
		R.width = 11
		R.length = 11
		R.height = 21
		R.goUp = true
		clearSolid()
		T:go("D3R1 F5R1 F2R2")
		U.emptyInventory({"sapling", "propagule", "dirt", "crafting"}, {"all"}, true)
	elseif R.logType:find("birch") ~= nil or R.logType:find("spruce") ~= nil or R.logType:find("jungle") ~= nil then	-- use column harvest
		if R.treeSize == "single" then
			T:forward(1)
			lib.harvestSingleRow() -- do 4 dirt/tree blocks on first col
			T:go("R1F2R1")	-- facing towards start on col 2
			lib.harvestSingleRow()
			T:go("L1F2L1") -- facing towards back on col 3
			lib.harvestSingleRow() -- facing towards start on col 4
			T:go("R1F2R1")
			lib.harvestSingleRow()
			T:go("F1R1 F3L1 F3R2")
			U.emptyInventory({"sapling", "propagule", "dirt", "crafting"}, {"all"}, true)
		else
			lib.harvestDouble()
			T:go("F3")
			lib.harvestDouble()
			T:go("R1F4")
			lib.harvestDouble()
			T:go("R1F4")
			lib.harvestDouble()
			T:go("F1R1 F3L1 F3R2")
			U.emptyInventory({"sapling", "propagule", "dirt", "crafting"}, {"all"}, true)
		end
	else	-- acacia, cherry, oak,  pale_oak, dark_oak
		local size = 11							-- default for oak,  pale_oak and dark_oak
		local start = "L1F1 L1F1 R2"			-- default for oak,  pale_oak and dark_oak
		local finish = "R1F1 R1F3 R2"			-- default for oak,  pale_oak and dark_oak
		if R.logType:find("acacia") ~= nil then
			size = 12
			start = "L1F2 L1F2 R2"
			finish = "R1F2 R1F2 R2"
		elseif R.logType:find("cherry") ~= nil then
			size = 14
			start = "L1F3 L1F3 R2"
			finish = "R1F3 R1F1 R2"
		end
		T:go("U1F1")	-- into first log at base of tree
		R.width = 7
		R.length = 7
		R.up = true
		R.down = true
		local currentLogCount = clearRectangle(true)			-- amount of logs obtained by digUp
	--Log:saveToLog("logs from digUp() first layer = "..currentLogCount, true)
		T:go(start)												-- after clearing soil and first layer, move out
		R.width = size
		R.length = size
		local height = 0
		while currentLogCount > 0 do							-- ony continue if at least 1 logs harvested last round
			T:up(3)
			height = height + 3
			currentLogCount = clearRectangle(true)				-- true = return logs dug from digUp() only
	--Log:saveToLog("logs from digUp() height = "..height..", count = "..currentLogCount, true)
		end
		T:up(3)													-- one additional layer
		height = height + 3
		currentLogCount = clearRectangle(true)					-- true = return logs dug from digUp() only
	--Log:saveToLog("logs from final digUp() height = "..height..", count = "..currentLogCount, true)
		T:down(height + 1)
		T:go(finish)
		T:go("R1F3 L1")			-- on modem
		--storageType, itemRequired, countRequired, toTurtleSlot, ignoreStock
		U.getItemFromNetwork("barrel", "minecraft:stick", 64, nil, false)
		U.getItemFromNetwork("barrel", "minecraft:apple", 64, nil, false)
		U.emptyInventory({"sapling", "propagule", "dirt", "crafting"}, {"all"}, true)
	end

	return {}	-- if player initiated, stops here. If R.auto then returns to plantTreeFarm() code
end

function manageBambooFarm()
	-- called from ui "Manage Bamboo Farm" button
	local lib = {}

	function lib.disableAutostart()
		if fs.exists("start.txt") then
			fs.delete("start.txt")
		end
		if fs.exists("startup.lua") then
			fs.delete("startup.lua")
		end
	end

	function lib.enableAutostart()
		if not fs.exists("startup.lua") then
			local h = fs.open("startup.lua", "w")
			h.writeLine('function main()')
			h.writeLine('	if fs.exists("start.txt") then')
			h.writeLine('		local handle = fs.open("start.txt", "r")')
			h.writeLine('		local cmd = handle.readLine()')
			h.writeLine('		handle.close()')
			h.writeLine('		shell.run("tk3.lua "..cmd)')
			h.writeLine('	end')
			h.writeLine('end')
			h.writeLine('main()')
			h.close()
		end
		local h = fs.open("start.txt", "w")
		h.writeLine('bamboo')
		h.close()
		print("Startup files written")
	end

	local isManaged = fs.exists("start.txt")
	if isManaged then
		R.auto = true
	--Log:saveToLog("R.auto set: manageBambooFarm() harvestBamboo()")
		return harvestBamboo()
	end
	--Log:saveToLog("manageBambooFarm() R.inventoryKey = ".. R.inventoryKey)
	if R.inventoryKey == "create" then	-- create a new bamboo farm
		if T:getBlockType("down"):find("modem") ~= nil then
			return {"Bamboo farm already exists!"}
		end
		return createBambooFarm()
	elseif R.inventoryKey == "harvest" then -- harvest now
		R.silent = false
		R.auto = false
		--Log:saveToLog("manageBambooFarm() harvestBamboo()")
		return harvestBamboo()
	elseif R.inventoryKey == "auto" then -- enable/disable auto farm
		local line = menu.clear()
		if isManaged then
			local message = ( "This turtle has been configured to"..
							  "start automatically and continuously"..
							  "grow and harvest bamboo.\n")
			line = menu.colourText(line, message, true, true)
			if menu.getBoolean("Do you want to disable this? (y/n)", line, colors.yellow, colors.black) then
				lib.disableAutostart()
			end
			return {"Autostart disabled. Reboot to activate"}
		else -- not managed
			local message = ( "~yellow~This turtle can be configured to be\n"..
							  "a dedicated bamboo fuel producer.\n\n"..
							  "~lightGray~It will then start automatically and\n"..
							  "monitor the farm complex:\n\n"..
							  "~green~harvesting~yellow~ and ~lime~replanting ~yellow~continuously.\n")
			line = menu.colourText(line, message, true, true)
			if menu.getBoolean("Do you want to enable this? (y/n)", line + 2, colors.orange, colors.black) then
				lib.enableAutostart()
			else
				return {"Player cancelled operation"}
			end
			return {"Autostart enabled. Reboot to activate"}
		end
	end

	return {}
end

function manageFarm()
	local lib = {}

	function lib.askPlayerForCrops()
		local seed  = ""
		pp.itemColours = {colors.lightGray, colors.red, colors.orange, colors.brown, colors.magenta, colors.yellow}
		crops = {"minecraft:wheat_seeds", "minecraft:beetroot_seeds", "minecraft:carrots", "minecraft:potatoes", "minecraft:pumpkin_seeds", "minecraft:melon_seeds", "mysticalagriculture", "none"}
		choices = {"wheat (seeds)", "beetroot (seeds)", "carrot", "potato", "pumpkin", "melon", "Mystical Agriculture", "Till soil only"}
		choice = menu.menu("Choose preferred crop", choices, pp, "Type number of your choice")
		crop = crops[choice]
		if crop == "none" then
			return "", ""
		elseif crop == "mysticalagriculture" then
			T:checkInventoryForItem({"seeds"}, {95}, true, "Add one type of M. Agriculture seeds")
		else
			if crop == "minecraft:pumpkin_seeds" or crop == "minecraft:melon_seeds" then
				T:checkInventoryForItem({crop}, {36}, true, "Do not mix! Enter when done")
			else
				T:checkInventoryForItem({crop}, {95}, true, "Do not mix! Enter when done")
			end
		end
		crop = T:getMostItem("", false)		-- not searching for any specific item, not checking stone only
		-- crop could be wheat/beetroot seeds, carrots, potatoes or mystical agriculture seeds
		seed, crop = lib.getCropSeed(crop)	-- seed type or "", crop type
		return seed, crop
	end

	function lib.assessPlot()
		local crop = T:getBlockType("forward")	-- convert ma:inferium_crop to ma:inferium_seeds
		local seed = lib.getCropSeed(crop)
		turtle.down()									-- into water source
		local soil = T:getBlockType("forward")
		turtle.up()										-- at crop level
		return crop, seed, soil
	end

	function lib.chartPosition()
		local chart = {"","","",""}
		for turns = 1, 4 do
			T:go("F1")
			local item = T:getBlockType("down")
			if item:find("chest") ~= nil then
				chart[turns] = "c"
			elseif item:find("barrel") ~= nil then
				chart[turns] = "b"
			elseif item:find("modem") ~= nil then
				chart[turns] = "m"
				R.networkFarm = true
			end
			utils.goBack(1)
			T:go("R1")
		end
		return chart
	end

	function lib.crossFarm()
		-- used with goHome to find starting point
		local blockType = ""
		local isReady, cropType, seed, status
		isReady, cropType, seed, status = lib.isCropReady("down")
		-- will go forward until chest, barrel, modem or cobble detected below
		-- if detected within 1 move, this is ignored
		local numMoves = 0
		local endOfPath = false
		while not endOfPath do
			blockType = T:getBlockType("down")
			if blockType == "" or cropType ~= "" then --crops or nothing below
				turtle.forward()
			elseif  blockType:find("barrel") ~= nil or
					blockType:find("chest") ~= nil or
					blockType:find("modem") ~= nil or
					blockType:find("cobble") ~= nil then
				endOfPath = true
			end
			numMoves = numMoves + 1
		end
		return blockType -- either barrel, chest, modem or cobble
	end

	function lib.checkFarmToRight()
		-- check existence of farms to right and front
		local isFarmToRight = false
		T:go("U1F10")						-- go to right side of this farm
		if utils.isStorage("down") then
			isFarmToRight = true
		end
		T:go("B10D1")						-- return to default position
		return isFarmToRight
	end

	function lib.checkFarmLocations()
		-- check existence of farms to right and front
		local isFarmToRight, isFarmToFront = false, false
		T:go("U1F10")						-- right side of this farm
		if utils.isStorage("down") then
			isFarmToRight = true
		end
		T:go("B10 L1F10")					-- front of this farm
		if utils.isStorage("down") then
			isFarmToFront = true
		end
		T:go("B10 D1R1")					-- starting position

		return isFarmToRight, isFarmToFront
	end

	function lib.farmToRight(plotCountR)
		--[[ facing crops on first farm. move to next farm on right side ]]
		if plotCountR then
			T:go("U1F11 D1")													-- on next farm, facing crops
		end
		local isFarmToRight = false
		local isReady, crop, seed, status = lib.isCropReady("forward")		-- eg true, "minecraft:carrots", "7 / 7" or false, "", ""
		--Log:saveToLog("lib.farmToRight(), isReady = "..tostring(isReady)..", crop = "..crop..", seed = "..seed)
		if crop == "" then -- if no crop then ignore this farm
			isFarmToRight, isFarmToFront = lib.checkFarmLocations()
		else
			lib.manageTree() -- refuel if required, else do nothing
			lib.getSeedsOrCrops(seed, crop)
			isFarmToRight, isFarmToFront = lib.harvest(seed, crop)			-- harvest field, store crops
			-- now at starting position of current plot
		end

		return isFarmToRight, isFarmToFront
	end

	function lib.getCropSeed(crop)
		-- change growing crops into equivalent seed names
		-- crop could be seeds, so return equivalent crop
		local start = crop:find("_crop")
		if start ~= nil then	-- only modded seeds have "crop"
			return crop, crop:sub(1, start).."seeds"
		end
		if crop:find("seeds") ~= nil then	-- asked to return crop from seed type
			if crop:find("wheat") ~= nil then
				return  "minecraft:wheat", "minecraft:wheat_seeds"
			end
			if crop:find("beetroot") ~= nil then
				return "minecraft:beetroot", "minecraft:beetroot_seeds"
			end
			if crop:find("tomatoes") ~= nil then
				return "farmersdelight:tomatoes", "farmers_delight:tomato_seeds"
			end
		end
		if crop:find("wheat") ~= nil then
			return  "minecraft:wheat", "minecraft:wheat_seeds"
		end
		if crop:find("beetroot") ~= nil then
			return  "minecraft:beetroot", "minecraft:beetroot_seeds"
		end
		if crop:find("carrot") ~= nil then
			return "minecraft:carrot", ""
		end
		if crop:find("potato") ~= nil then
			return "minecraft:potato", ""
		end
		if crop:find("onion") ~= nil then
			return "farmersdelight:onion", ""
		end
		-- planted crops are plural, harvested singular: carrots / carrot, pototoes/ potato
		return crop, "" -- no seed for carrot / potato
	end

	function lib.getItem(name)
	    --Log:saveToLog("==> lib.getItem("..name..")")
		local slot = U.getItemFromNetwork("barrel", name, 1)
		if slot > 0 then					-- obtained from network
		--Log:saveToLog("    return slot = "..slot..", item = "..name)
			return slot
		end
		-- not found, slot = 0
		slot = T:getItemSlot(name)				-- if item in inventory
		if slot == 0 then						-- item not present
			T:checkInventoryForItem({name}, {1}, true, name.." required to continue")
			slot = T:getItemSlot(name)			-- if item in inventory
			if slot == 0 then
				return {name.." is required. Add to turtle and restart"}
			end
		end
		return slot
	end

	function lib.getSeedsOrCrops(crop, seed)
		-- get seeds or veg based on what is growing
		if seed ~= "" then
			local seedType, seedCount = lib.getSeeds(seed) 	-- table: get 95 of beetroot / wheat / mysticalagriculture seeds
			if seedCount == 0 then
		--Log:saveToLog("No seeds available.", true)
			end
		else	-- seed  = ""
			local veg, vegCount = "", 0
			veg, vegCount = lib.getVeg(crop)	-- gets any carrots / potatoes
			if veg ~= "" then
				crop = veg
			end
		end
	end

	function lib.getSaplings()
		-- get a single sapling from network storage
		U.wrapModem(false)
		local slot, count = U.getItemFromNetwork("barrel", "sapling", 1)

		return slot
	end

	function lib.getSeeds(seed)
		--[[
			seed = name of growing crops seed or ""
			turtle facing crops on networked, else facing storage
			allow for other seeds from mods eg MysticalAgriculture
			get 1 stack of seeds of whatever type is being farmed
		]]
		if seed == "" then
			return "", 0
		end
		local inventorySlot, seedCount = 0, 0
		--Log:saveToLog("Collecting seeds from storage")
		U.wrapModem(false)
		inventorySlot, seedCount = U.getItemFromNetwork("chest", seed, 64)
		if seedCount > 0 then
		--Log:saveToLog("planting " ..seed)
		end
		return seed, seedCount	-- could be: "", 0 or "minecraft:wheat_seeds", 64
	end

	function lib.getVeg(crop)
		-- assume only one type of crop per field
		-- local item, itemName, shortName, slot = "", "","", 0
		local inventorySlot, cropCount = 0, 0
		U.wrapModem(false)
		inventorySlot, cropCount = U.getItemFromNetwork("chest", crop, 64)

		if cropCount > 0 then
			print("planting " ..crop)
		end
		return crop, cropCount -- could be: "", 0 or "minecraft:potato", 64
	end

	function lib.goHome()
		-- after a re-boot go to start
		R.ready = true
		local onTree = false
		-- is tree above or in front
		-- check if log in front
		if T:getBlockType("forward"):find("log") ~= nil then -- about to harvest tree
			lib.harvestTree("forward") 		-- will only harvest if fuel below half of limit
			onTree = true					-- end on dirt
		elseif T:getBlockType("up"):find("log") ~= nil then -- harvesting tree
			lib.harvestTree("up")			-- end on dirt
			onTree = true
		elseif T:getItemSlot("log") > 0 then-- tree just harvested
			onTree = true
			turtle.up()
			if T:getBlockType("up"):find("log") ~= nil then -- harvesting tree
				lib.harvestTree("up")		-- end on dirt
			else
				while turtle.down() do end	-- end on dirt
			end
		elseif T:getBlockType("down"):find("barrel") ~= nil then -- on corner barrel, could be networked or earlyGame
			local chart = lib.chartPosition()
			-- chart = {"","s","s",""} = facing out of left
			-- chart = {"s","s","",""} = facing back of farm
			-- chart = {"s","","","s"} = facing right side of farm
			-- chart = {"","","s","s"} = facing out of front farm
			if U.sameSequence(chart, {"s","s","",""}) then
				T:go("L1")
			elseif U.sameSequence(chart, {"s","","","s"}) then
				T:go("R2")
			elseif U.sameSequence(chart, {"","","s","s"}) then
				T:go("R1")
			end
			T:go("B1D4 R1F1 D1R1")	-- facing crops, over water
		elseif T:getBlockType("down"):find("chest") ~= nil then -- on earlyGame farm on top of chest
			local chart = lib.chartPosition()
			-- |c|w
			-- |b|c|c
			if U.sameSequence(chart, {"b","","c",""}) then -- on front chest, left side facing out of left
				T:go("R1")
			elseif U.sameSequence(chart, {"c","","b",""}) then -- on front chest, facing right side of farm
				T:go("L1")
			elseif U.sameSequence(chart, {"","b","","c"})  then -- on front chest, facing away from farm
				T:go("R2")
			end
			T:go("F1D1R1")
		end

		if onTree then
			local success, storage = false, ""
			-- tree harvested, sitting on dirt, but direction unknown
			T:down(3) 				-- dig dirt, go down to barrel in left corner
			-- if storage type farm chest/barrel will give position
			local chart = lib.chartPosition()
			if U.sameSequence(chart, {"","c","c",""}) or U.sameSequence(chart, {"", "m","m",""}) then
				T:go("L1")
			elseif U.sameSequence(chart, {"c","c","",""}) or U.sameSequence(chart, {"m","m","",""}) then
				T:go("R2")
			elseif U.sameSequence(chart, {"","","c","c"}) or U.sameSequence(chart, {"","","m","m"}) then
				T:go("R1")
			end
			T:up(3)
			T:place("dirt", "down")
			T:up(1)
			T:place("sapling", "down") -- plant sapling
			T:go("B1D4 R1F1 D1R1")	-- facing crops, over water
		else
			while turtle.down() do end -- no tree around, no logs onboard
			R.ready = false
		end
	end

	function lib.goToLeft(plotCountR)
		if plotCountR > 0 then
			T:go("U1B"..plotCountR * 11 .."D1")	-- return home and continue with front
			if R.config ~= nil then
				local coord = R.config.currentPlot
				for i = 1, plotCountR do
					coord = lib.configUpdateCoords(coord, "left")
				end
				R.config.currentPlot = coord
			end
		end
	end

	function lib.goToFront(plotCountF)
		if plotCountF > 0 then
			T:go("U1R1F"..plotCountF * 11 .."D1L1")
			if R.config ~= nil then
				local coord = R.config.currentPlot
				for i = 1, plotCountF do
					coord = lib.configUpdateCoords(coord, "back")
				end
				R.config.currentPlot = coord
			end
		end
	end

	function lib.gotoTree()
	    --Log:saveToLog("==> lib.gotoTree()")
		T:go("R1U1 F1R1 U3")								-- move on top of wall/storage. face tree direction
		--Log:saveToLog("    Finding tree..")
		lib.harvestTree("forward") 				-- fell tree or plant sapling, ends facing tree / dirt / sapling. sticks already used for fuel. excess saplings placed
		T:go("R1F1D1R1")							-- return to base, facing crops
		U.sendItemToNetworkStorage("barrel", "sapling", 64) --move saplings to any attached barrel
		-- ends in field facing crops
	end

	function lib.harvest(seed, crop)
		--[[
		cover the field in a set pattern.
		harvest crop if ripe
		till soil and plant new ones
		place seeds / harvest in chests
		return farm(s) to right / front
		crop is full name. if mixed seeds only one type returned
		]]
		T:go("U1") --ready to farm field
		local isFarmToRight = false
		local isFarmToFront = false
		local width = 9
		local length = 10
		local toRight = true
		--Log:saveToLog("lib.harvest(seed = "..seed..", crop = "..crop..")")
		if crop:find("pumpkin") ~= nil or crop:find("melon") ~= nil or seed:find("pumpkin") ~= nil or seed:find("melon") ~= nil then
		--Log:saveToLog("lib.harvest(seed = "..seed..", crop = "..crop..") found pumpkin or melon")
			for w = 1, width do
				lib.replant(seed, crop)	-- check and replant crop below
				T:forward(1)
			end
			turtle.forward()
			if utils.isStorage("down") then	-- chest, barrel or modem
				isFarmToRight = true
			end
			turtle.back()
			-- end of the row: change direction
			T:go("L1F1L1")												-- over first row of melon/pumpkin
			T:go("x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2")		-- harvest first row
			T:go("R1F1R1")
			T:go("x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2")		-- over second row of melon/pumpkin
			T:go("L1F1L1")												-- over second row of stems
			for w = 1, width do
				lib.replant(seed, crop)									-- check and replant crop below
				T:forward(1)
			end
			lib.replant(seed, crop)
			T:go("R1F3R1")												-- move over solid blocks
			for w = 1, width do
				lib.replant(seed, crop)									-- check and replant crop below
				T:forward(1)
			end
			lib.replant(seed, crop)
			T:go("L1F1L1")												-- over third row of stems
			T:go("x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2")		-- harvest third row
			T:go("R1F1R1")
			T:go("x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2F1 x2")		-- over fouth row of melon/pumpkin
			T:go("L1F1L1")												-- over second row of stems
			for w = 1, width do
				lib.replant(seed, crop)									-- check and replant crop below
				T:forward(1)
			end
		else
			for l = 1, length do
				for w = 1, width do
					lib.replant(seed, crop)	-- check and replant crop below
					T:forward(1)
					if l == 1 and w == width then -- last block of first row at front of farm
						T:forward(1)
						if utils.isStorage("down") then	-- chest, barrel or modem
							isFarmToRight = true
						end
						turtle.back()
					end
				end
				-- end of the row: change direction
				if l < length then -- do not turn at final row
					lib.replant(seed, crop)	-- check and replant crop below
					if toRight then
						T:go("L1F1L1")
					else
						T:go("R1F1R1")
					end
					lib.replant(seed, crop)
				end
				toRight = not toRight
			end
		end
		T:go("R1F1") -- goes over chest/cobble on top wall
		if utils.isStorage("down") then
			isFarmToFront = true
		end
		T:go("R2F"..length.."D1L1") -- go straight across to seed chest 10 blocks, facing crops
		lib.storeCrops() -- rotates from start to deposit seeds and crops, ends facing crops
		return isFarmToRight, isFarmToFront
	end

	function lib.harvestTree(direction)
		--[[
			start in front of / during tree harvest
			Check if sapling present
			Harvest tree if present, replant sapling
			Dispose of apples. Use sticks as fuel
			Return to top of storage
		]]

		direction = direction or "forward"
		local inFront = T:getBlockType("forward")
		print("Checking tree")
		if inFront == "" then -- no tree or sapling
			print("No sapling: planting sapling")
			T:place("sapling", "forward")
		elseif inFront:find("log") ~= nil or direction == "up" then -- tree above or in front
			--print("Harvesting tree")
			T:harvestTree(direction) --do not investigate side branches in case chunk unloaded
			T:back(1) -- face dirt
			-- place(self, blockType, direction, leaveExisting, signText)
			T:place("sapling", "forward")
		end
		print("Disposing of apples")
		T:dropItem("apple", "up", 0) -- drop any apples
		U.useSticksAsFuel()

		while turtle.down() do end	-- ends facing tree, on top of plot storage
	end

	function lib.manageTree()
		-- starting position facing crops
		local logSlot = T:getItemSlot("stick")
		if logSlot > 0 then
			turtle.select(logSlot)
			turtle.refuel()
		end
		if Fuel.level() < 250 then
		--Log:saveToLog("==> lib.manageTree() Fuel required: Extracting saplings from storage")
			-- assume facing crops
			if not lib.refuelFromNetwork() then
				if lib.getItem("sapling") > 0 then					-- gets one sapling only (if present)
				--Log:saveToLog("    calling lib.gotoTree()")
					lib.gotoTree()			-- check for sapling or harvest tree, retuns to facing crops
					lib.refuelWithLogs(T:getItemSlot("log"))
				end
			end
		end
	end

	function lib.isCropReady(direction)
		local isReady = false
		local status = ""
		local success = false
		local crop, seed = "", ""
		local data = {}

		direction = direction or "forward"

		if direction == "down" then
			success, data = turtle.inspectDown()
		else
			success, data = turtle.inspect()
		end
		--Log:saveToLog("lib.isCropReady(".. direction..")")
		if success then			-- inspect() success
			crop = data.name	-- name of growing plant
			if crop:find("flower") ~= nil then
			--Log:saveToLog("Flower "..crop.." found")
				return true, crop, "open"	-- eg torchflower
			else
				if data.name:find("beetroot") ~= nil then
					status = data.state.age.." / 3"
					if data.state.age == 3 then
						isReady = true
					end
				--elseif data.name:find("attached") ~= nil then	-- pumpkin / melon does not have state.age
				elseif data.name:find("stem") ~= nil then	-- pumpkin / melon does not have state.age
					return true, crop, "", 7
				else			-- all other crops inc Mystical Agriculture
					if data.state.age == nil then
						isReady = true
					else
						status = data.state.age.." / 7"
						if data.state.age == 7 then
							isReady = true
						end
					end
				end
			end
			crop, seed = lib.getCropSeed(crop)
		end
		--Log:saveToLog("return isReady = "..tostring(isReady)..", crop = "..crop..", seed = "..seed..", status = "..status)
		-- crop: "", "minecraft:carrots", "minecraft:beetroot", "minecraft:potatoes", "minecraft:wheat", "mysticalagriculture:*_crop"
		return isReady, crop, seed, status	-- eg true, "minecraft:carrots", "7 / 7" or false, "mysticalagriculture:inferium_crop", "1 / 7"
	end

	function lib.locateFarm()
		--Log:saveToLog("? over water = false")
		for i = 1, 4 do
			if turtle.detect() then
				detected = i
			end
			T:turnRight(1)
		end
		--Log:saveToLog("Neighbouring blocks detected at: "..detected)
		-- check if on corner
		if detected > 0 then
			--assume tree / sapling on corner on older farm type
			--Log:saveToLog("Assuming next to tree / sapling. Moving..")
			T:go("R"..detected .."F1D1R1")
		else	-- no surrounding blocks
			for i = 1, 4 do
				T:forward(1)
				success, storage = utils.isStorage("down")
				--Log:saveToLog("i = "..i..",success = "..tostring(success)..". storage = "..storage)
				if success then
					discovered = discovered .. storage
					if storage == "modem" then
						R.networkFarm = true
					end
				else
					if storage == "" then
						discovered = discovered .. "_"
					else
						discovered = discovered .. "wall"
					end
				end
				utils.goBack(1)
				T:turnRight(1)
			end
			--Log:saveToLog("Neighbouring blocks found:"..discovered)
		end
		-- check discovered for patterns eg {_wall_barrel}
		-- |W|*|B| * = turtle on wall
		-- | | |M|
		if R.networkFarm then
			-- E = wall_barrel_, N = _barrel_wall, W = wall_barrel_, S = _wall_barrel
			if discovered == "_wall_barrel" then
				T:go("F1D1R1")
			elseif discovered == "barrel_wall_" then
				T:go("R1F1D1R1")
			elseif discovered == "_barrel_wall" then
				T:go("R2F1D1R1")
			elseif discovered == "wall_barrel_" then
				T:go("L1F1D1R1")
			end
		else	-- normal storage farm
			if discovered == "_chest_chest" then
				T:go("F1D1R1")
			elseif discovered == "chest__chest" then
				T:go("R1F1D1R1")
			elseif discovered == "_chest_chest" then
				T:go("R2F1D1R1")
			elseif discovered == "chest_chest_" then
				T:go("L1F1D1R1")
			end
		end
		blockType = T:getBlockType("down")
		if blockType:find("water") ~= nil then
			for i = 1, 4 do
				success, storage = utils.isStorage("forward")	-- true/false, chest, barrel, modem / ""
				if success and storage == "modem" then
					R.networkFarm = true
				end
				T:turnRight(1)
			end
			R.ready = true
		end
	end

	function lib.plantCrop(seed, crop, direction)
		--turtle.digDown("left") -- harvest existing
		--turtle.digDown("right") -- till soil
		if crop:find("potato") ~= nil then
			T:dropItem("poison", "up", 0)
		end
		--Log:saveToLog("lib.plantCrop(seed = "..seed..", crop = "..crop)
		local success = false
		-- place(blockType, direction, leaveExisting, signText, doNotAttack)
		if seed == "" then			-- must be a crop or bare soil
			if crop == "" then		-- crop planted
				return false
			else
				success = T:place(crop, direction, true, "", true)
			end
			--success = T:place(crop, direction, false, "", true)
			--Log:saveToLog("Seed = "..seed..". Placing "..crop..": success = "..tostring(success))
		else
			success = T:place(seed, direction, true, "", true) 	-- eg "mysticalagriculture:air_seeds"
			--success = T:place(seed, direction, false, "", true) 	-- eg "mysticalagriculture:air_seeds"
			--Log:saveToLog("Placing "..seed..": success = "..tostring(success))
		end
		if not success then
			success = T:place("seed", direction, true, "", true)			-- failsafe
			--success = T:place("seed", direction, false, "", true)			-- failsafe
			--Log:saveToLog("Placing generic 'seeds' : success = "..tostring(success))
		end
		return success
	end

	function lib.replant(seed, crop)
		-- check crop below. If ripe, dig and replant seed
		local isReady, cropType, seedType, status = lib.isCropReady("down")	-- eg true, "minecraft:carrots", "7 / 7" or false, "", ""
		if cropType == "" then					-- no crop below (above water, storage or dirt)
			turtle.digDown("right")				-- use hoe
			if not lib.plantCrop(seed, crop, "down") then	-- plant crop
				turtle.digDown("right")			-- use hoe again required with some mods
				lib.plantCrop(seed, crop, "down")
			end
		elseif crop:find("pumpkin") == nil and crop:find("melon") == nil and isReady then						-- crop below is ready
			turtle.digDown("left")				-- use pickaxe
			if not lib.plantCrop(seedType, cropType, "down") then	-- plant crop
				turtle.digDown("left")
				lib.plantCrop(seedType, cropType, "down")
			end
		elseif cropType == "minecraft:melon" or cropType == "minecraft:pumpkin" then
			turtle.digDown("left")				-- use pickaxe
		end
		turtle.suckDown()
	end

	function lib.refuelFromNetwork()
		local logSlot, logCount = 0, 0
		U.wrapModem(true)
--Log:saveToLog("lib.refuelFromNetwork() calling U.getItemFromNetwork('chest', 'planks', 64)")
		logSlot, logCount = U.getItemFromNetwork("chest", "planks", 64)

		if logCount > 0 then
			print("refuelling with planks")
			turtle.select(logSlot)
			turtle.refuel(turtle.getItemCount(logSlot))
			print ("Refuelled to ".. Fuel.level())
			return true
		end
		return false
	end
	
	function lib.refuelWithLogs(logSlot)
		--[[ called after lib.manageTree and on startup ]]
		--Log:saveToLog("lib.refuelWithLogs(logSlot = "..logSlot..")")
		if logslot == 0 then return end
		local equippedLeft, equippedRight = T:getEquipped("both")				-- "" or "minecraft:..." for each side
		local craftSlot = T:getItemSlot("minecraft:crafting_table")				-- if crafting table in inventory
		--Log:saveToLog("lib.refuelWithLogs("..logSlot..") equippedLeft = "..equippedLeft..", equippedRight = "..equippedRight)
		if equippedLeft ~= "minecraft:crafting_table" and equippedRight ~= "minecraft:crafting_table" then
			if craftSlot == 0 then												-- no crafter present
				craftSlot = lib.getItem("minecraft:crafting_table") 			-- gets item or errors
			end
			T:equip("right", "minecraft:crafting_table")						-- equip with crafting table
			U.sendItemToNetworkStorage("barrel", "minecraft:diamond_hoe", 1)
		end
		turtle.select(logSlot)
		turtle.transferTo(1)
		-- utils.waitForInput("Ready to craft logs slot 1. Proceed?")
		turtle.craft()														-- craft logs to planks
		logSlot = T:getItemSlot("planks")
		while logSlot > 0 and Fuel.level() < Fuel.limit() do
			turtle.select(logSlot)
			turtle.refuel()													-- refuel using planks
			logSlot = T:getItemSlot("planks")
		end

		T:unequip("right")													-- unequip crafting table
		-- return crafting table
		U.sendItemToNetworkStorage("barrel", "minecraft:crafting_table", 1)
		if not T:equip("right", "minecraft:diamond_hoe") then		-- ? equip hoe
			lib.getItem("minecraft:diamond_hoe")				-- get hoe
			T:equip("right", "minecraft:diamond_hoe")				-- equip hoe
		end
	end

	function lib.storeCraftingTable()
		-- turtle facing crops
		U.sendItemToNetworkStorage("barrel", "minecraft:crafting_table", 1)
	end

	function lib.storeCrops()
		-- place crops and seeds into chests. Starts facing crops
		T:dropItem("apple", "up", 0) 									-- drop all apples
		T:dropItem("poison", "up", 0) 									-- drop all poison potatoes
		-- put "sapling", "diamond_hoe", "crafting" into barrels near farm, everything else into chest storage
		-- U.emptyInventory(barrels, chests, sticksAsFuel, relist)
		-- relist forces remappimg of chest and barrel contents to help locate correct storage location
		U.emptyInventory({"sapling", "diamond_hoe", "crafting"}, {"all"}, true, true)
		-- position remains as start of this function
	end

	function lib.watchFarm()
		--[[
		check status of crops in front of turtle.
		call lib.harvest when ripe
		return farm(s) found in front or to the right
		]]
		--    bool,    string, string, integer
		local isReady, crop, seed, status = lib.isCropReady("forward")		-- eg true, "minecraft:carrots", "7 / 7" or false, "", ""
		-- check state of crop in front. Harvest if ripe
		repeat
			if not isReady then
				if crop == "" then
					return {"No crops found in front", "Plant seeds, carrots, potatoes", "pumpkin or melon"}
				else
					print("Waiting for "..crop.." status: "..status)
					if crop:find("mysticalagriculture") ~= nil then
						R.mysticalAgriculture = true
					end
				end
				sleep(60)
				isReady, crop, seed, status = lib.isCropReady("forward")			-- eg true, "minecraft:carrots", "7 / 7" or false, "", ""
			end
		until isReady
		--Log:saveToLog("Local crops ripe calling lib.manageTree()")
		--seed, crop = lib.manageTree() -- "", "" or name of seed, crop
		lib.manageTree() -- refuel if required, else do nothing
		lib.getSeedsOrCrops(crop, seed)
		return crop, seed
	end

	--[[
		ENTRY POINT**********************************************
		called from args on start, or from user choice
		farm already built, needs planting and/or harvesting
		needs both pickaxe and hoe. crafting chest only used if tree is felled for fuel
		may start in any position if chunk unloaded while running
		All farms now use network storage
	]]
	--Log:saveToLog("manageFarm() calling checkFarmPosition()")
	if Fuel.level() < 60 then
	    --Log:saveToLog("manageFarm(): Fuel level is "..Fuel.level())
		if not lib.refuelFromNetwork() then
			if R.auto then
				utils.waitForInput("Unable to proceed. Fuel level is "..Fuel.level())
				return {}
			else		-- not started from startup.lua
				return {"Unable to proceed. Fuel level is "..Fuel.level()}
			end
		end
	end
	checkFarmPosition()											-- should be facing crops, placed above water source. R.ready, R.networkFarm is true
	if not R.ready then											-- not in correct starting place
		lib.goHome()
		if not R.ready then 									-- try to find home
			return
			{
				"Unable to determine my position.\n",
				"Place me in the lower left corner",
				"over water, facing the crops with",
				"barrel / chest /modem to my right",
				"and behind."
			}
		end
	end
	local message = U.wrapModem(true)								-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	if message ~= "" then return {message} end						-- return to main menu
	local empty = T:isEmpty()
	if not empty then												-- items still in turtle inventory
		T:sortInventory(false)										-- sort inventory prior to unloading.
	end
	local equippedLeft, equippedRight = T:getEquipped("both")		-- "" or "minecraft:..." for each side
	local emptySlots = T:getEmptySlotCount()
	if emptySlots < 3 then											-- 3 slots needed for axe, hoe and crafting
		T:clear()
		return {"Too many items in inventory. 3 free slots required"}
	end
	local logSlot = T:getItemSlot("log")							-- if logs in inventory
	if logSlot == 0 and not empty then								-- no logs, so empty inventory
		lib.storeCrops(false)										-- stores crops and seeds
	end
	if equippedLeft ~= "minecraft:diamond_pickaxe" then
		T:unequip("left")											-- remove from left
		if not T:equip("left", "minecraft:diamond_pickaxe") then	-- ? equip pickaxe. should always be present
			lib.getItem("minecraft:diamond_pickaxe")				-- get pickaxe
			T:equip("left", "minecraft:diamond_pickaxe")			-- equip pickaxe
		end
	end
	local craftSlot = T:getItemSlot("minecraft:crafting_table")		-- if crafting table in inventory
	-- turtle has pickaxe equipped. If fuel needed equip crafter, else hoe
	-- if logs present, use as fuel, or fuelLevel < 1000
	if logSlot > 0 then				-- equip axe and crafter		-- logs onboard, need to equip crafting table
		lib.refuelWithLogs(logSlot)
	else
		-- store crafting table as not required
		if craftSlot > 0 then
			lib.storeCraftingTable(false)
		end
		if equippedRight ~= "minecraft:diamond_hoe" then
			if not T:equip("right", "minecraft:diamond_hoe") then		-- ? equip hoe
				lib.getItem("minecraft:diamond_hoe")					-- get hoe
				T:equip("right", "minecraft:diamond_hoe")				-- equip hoe
			end
		end
	end

	local isReady, crop, seed, status = lib.isCropReady("forward")
	--Log:saveToLog("lib.isCropReady('forward'): isReady = "..tostring(isReady)..", crop = "..crop..", seed = "..seed..", status = "..status)
	local watch = true	-- assume watching farm already planted
	local planted = true
	if crop == "" then	-- nothing has been planted
		seed, crop = lib.askPlayerForCrops()
		if crop ~= "" or seed  ~= "" then	-- something has been chosen
		--Log:saveToLog("Initial planting of "..crop, true)
			-- isFarmToRight, isFarmToFront = lib.harvest(seed, crop)	-- harvest plot a1 plots to right / front recorded
			lib.harvest(seed, crop)	-- plant this plot only
			return {"Initial crops planted. Re-start to manage this farm"}
		elseif crop == "" and seed == "" then	-- request till soil only
			watch = false
			planted = false
			lib.harvest(seed, crop)
			return {"soil tilled ready for growing"}
		end
	end

	if watch and planted then -- planted true when farm first planted
		crop, seed = lib.watchFarm() -- waits if required, returns seed / crop
		planted = true
	end
	--first farm is ready to go
	--Log:saveToLog("Beginning "..crop.. " management", true)
	local plotCountF = 0																-- move from front to back of farm plots. This counts no of plots moved from front
	local plotCountR = 0																-- move left to right along farm plots
	local isFarmToRight, isFarmToFront = true, true										-- flags set to true to ensure loop runs at least once
	local flagSet = false
	while true do -- start infinite loop of watching crops, farming all modules
		while isFarmToFront do															-- farm to front confirmed on first plot
			while isFarmToRight do														-- do all plots on the right side
				lib.manageTree()														-- refuel if needed
				local hasFrontFarm = false												-- local flag to imitialise isFarmToFront
				isReady, crop, seed, status = lib.isCropReady("forward")
				isFarmToRight, hasFrontFarm = lib.harvest(seed, crop)					-- harvest this plot
				if not flagSet then
					isFarmToFront = hasFrontFarm										-- external flag now set when first plot is harvested
					flagSet = true
				end
				if isFarmToRight then													-- plot just harvested sets this flag
					T:go("U1F11 D1")													-- now moved to next farm, facing crops
					plotCountR = plotCountR + 1											-- increment plot counter for return to base
					local isReady, crop, seed, status = lib.isCropReady("forward")		-- eg true, "minecraft:carrots", "7 / 7" or false, "", ""
					-- NOT waiting fror crops to be ready any more
			--Log:saveToLog("farming plot no "..plotCountR.." on right, crop = "..crop..", seed = "..seed)
					lib.manageTree() 													-- refuel if required, else do nothing
					if crop == "" then 													-- if no crop then ignore this farm
			--Log:saveToLog("farming plot no "..plotCountR.." no crop found, so checking for further plots")
						isFarmToRight = lib.checkFarmToRight()							-- check right border for further plot
					else
						lib.getSeedsOrCrops(seed, crop)									-- load in crop / seed
					end
				end
			end
			-- no more farms to right, so return to start position
			lib.goToLeft(plotCountR)													-- all plots to right have been checked, return to start position
			plotCountR = 0																-- reset right plot counter
			isFarmToRight = true														-- reset to ensure farm in front is harvested
			flagSet = false																-- reset so next band of farms controls isFarmToFront flag
			if isFarmToFront then														-- farm in front confirmed
				T:go("U1L1 F11D1 R1")													-- on next farm, facing crops
				plotCountF = plotCountF + 1
			end
		end
		-- no more farms in front
		lib.goToFront(plotCountF)
		plotCountR = 0																	-- reset all flags and counters
		plotCountF = 0																	-- reset forward plot counter
		isFarmToRight = true
		isFarmToFront = true
		flagSet = false
		if not R.auto then 																-- not started from startup.lua
			return {"Crop management of all modules completed"}
		end
		crop, seed = lib.watchFarm() -- waits if required, returns seed / crop
	end
end

function manageFarmSetup()
	-- called from ui "Manage Farm" button
	local lib = {}

	function lib.disableAutostart()
		if fs.exists("start.txt") then
			fs.delete("start.txt")
		end
		if fs.exists("startup.lua") then
			fs.delete("startup.lua")
		end
	end

	function lib.enableAutostart()
		if not fs.exists("startup.lua") then
			local h = fs.open("startup.lua", "w")
			h.writeLine('function main()')
			h.writeLine('	if fs.exists("start.txt") then')
			h.writeLine('		local handle = fs.open("start.txt", "r")')
			h.writeLine('		local cmd = handle.readLine()')
			h.writeLine('		handle.close()')
			h.writeLine('		shell.run("tk3.lua "..cmd)')
			h.writeLine('	end')
			h.writeLine('end')
			h.writeLine('main()')
			h.close()
		end
		local h = fs.open("start.txt", "w")
		h.writeLine('farm')
		h.close()
		print("Startup files written")
	end

	--[[
	T:clear()
	--local pp = utils.getPrettyPrint()
	local choices = {"Plant or harvest this farm complex"}	-- 1.
	local isManaged = fs.exists("start.txt")

	if isManaged then
		table.insert(choices, "Disable automatic farm management") -- 2.
	else
		table.insert(choices, "Enable automatic farm management") -- 2.
	end
	pp.itemColours = {colors.lime, colors.lightGray}
	if not R.networkFarm then
		table.insert(choices, "Convert to Network Storage")		-- 3.
		table.insert(pp.itemColours, colors.magenta)
	end
	if R.mysticalAgriculture then
		--table.insert(choices, "Convert to Mystical Agriculture")
		table.insert(choices, "Upgrade Mystical Agriculture soil")	--3/4
		table.insert(pp.itemColours, colors.green)
	end

	local userChoice, modifier = menu.menu("Choose your option", choices, pp) -- 1 to 2
	if modifier == "q" then -- quit chosen
		return {"Player has quit"}
	end
	R.subChoice = userChoice]]
	local isManaged = fs.exists("start.txt")
	--Log:saveToLog("manageFarmSetup() R.inventoryKey = ".. R.inventoryKey)
	if R.inventoryKey == "farm" then -- harvest now
		R.silent = false
		R.auto = false
	--Log:saveToLog("manageFarmSetup() calling manageFarm()")
		return manageFarm()
	elseif R.inventoryKey == "auto" then -- enable/disable auto farm
		local line = menu.clear()
		if isManaged then
			local message = ( "This turtle has been configured to"..
							  "start automatically and run the farm"..
							  "management program.\n")
			line = menu.colourText(line, message, true, true)
			if menu.getBoolean("Do you want to disable this? (y/n)", line, colors.yellow, colors.black) then
				lib.disableAutostart()
			end
			return {"Autostart disabled. Reboot to activate"}
		else -- not managed
			local message = ( "~yellow~This turtle can be configured to be\n"..
							  "a dedicated farm manager.\n\n"..
							  "~lightGray~It will then start automatically and\n"..
							  "monitor the farm complex:\n\n"..
							  "~green~harvesting~yellow~ and ~lime~replanting ~yellow~continuously.\n")
			line = menu.colourText(line, message, true, true)
			if menu.getBoolean("Do you want to enable this? (y/n)", line + 2, colors.orange, colors.black) then
				lib.enableAutostart()
			else
				return {"Player cancelled operation"}
			end
			return {"Autostart enabled. Reboot to activate"}
		end
	--elseif R.subChoice == 3 and #choices == 4 then -- convert normal farm to network storage
	elseif R.inventoryKey == "convert" then -- convert normal farm to network storage
		local isMain = false
		local line = menu.clear()
		local message = ("~yellow~You have chosen to convert this farm "..
						 "to ~magenta~network storage ~yellow~with modems."..
						 "All ~brown~chests and barrels ~red~will be removed.\n")
		line = menu.colourText(line, message, true, true)
		if menu.getBoolean("Is this the main or only plot? (y/n)", line + 3, colors.orange, colors.black) then
			isMain = true
		end
		T:checkInventoryForItem({"stone"}, {16})
		T:checkInventoryForItem({"dirt"}, {2})
		T:checkInventoryForItem({"sapling"}, {1})
		T:checkInventoryForItem({"barrel"}, {1})
		T:checkInventoryForItem({"ladder"}, {5})
		if isMain then
			T:checkInventoryForItem({"chest"}, {8})
			T:checkInventoryForItem({"wired_modem_full"}, {3})
			T:checkInventoryForItem({"computercraft:cable"}, {70})
			return createFarm("convertWithStorage")
		else
			T:checkInventoryForItem({"wired_modem_full"}, {2})
			T:checkInventoryForItem({"computercraft:cable"}, {57})
			return createFarm("convert")
		end
	--elseif R.subChoice == 3 and #choices == 3 then -- upgrade farmland with essence (network opt not present)
	--elseif R.subChoice == 3 and #choices == 3 then -- upgrade farmland with essence (network opt not present)
		--return upgradeFarmland()
	--elseif R.inventoryKey == "upgrade" then -- upgrade farmland with essence
		--return upgradeFarmland()
	end

	return {}
end

function plantTreefarm()
	-- F["assessTreeFarm"].call() already run
	-- R.logType = eg "minecraft:dark_oak_log"
	-- R.useBlockType = eg "minecraft:oak_sapling"
	-- R.subChoice = 1,2,3 single, double, mangrove
	-- R.networkFarm = true
	local lib = {}

	function lib.emptyInventory()
		if not T:isEmpty() then
			U.useSticksAsFuel()
		--Log:saveToLog("==> lib.emptyInventory() call --> U.sendItemToNetworkStorage('barrel', 'sapling, 64")
			U.sendItemToNetworkStorage("barrel", "sapling", 64)
			U.sendItemToNetworkStorage("barrel", "propagule", 64)
			U.sendItemToNetworkStorage("barrel", "apple", 64)
			U.sendItemToNetworkStorage("barrel", "dirt", 64)
			U.sendItemToNetworkStorage("chest", "all", 0)
		end
	end

	function lib.createIsland(sapling, count, exit)
		-- place 4 dirt with saplings on all 4
		-- sapling count/type already checked
		T:forward(2) -- assume starting outside planting area
		for i = 1, 4 do
			T:go("R1F1")
			T:place("dirt", "down", false, "", true)
		end
		T:up(1)
		if count >= 4 then
			for i = 1, 4 do
				T:go("R1F1")
				T:place(sapling, "down", false, "", true)
			end
		end
		if exit == "forward" then
			T:go("F1D1")
		elseif exit == "right" then
			T:go("R1F2D1")
		elseif exit == "left" then
			T:go("L1F1D1")
		elseif exit == "back" then
			T:go("R2F2D1")
		end
	end

	function lib.createSingle(sapling, exit)
		-- place single dirt with sapling on top
		-- sapling count/type already checked
		T:place("dirt", "down", false, "", true)
		T:up(1)
		if not T:place(sapling, "down", false, "", true) then 	-- try specific sapling
			T:place("sapling", "down", false, "", true)			-- any available sapling
		end
		if exit == "forward" then
			T:go("F1D1")
		elseif exit == "right" then
			T:go("R1F1D1")
		elseif exit == "left" then
			T:go("L1F1D1")
		elseif exit == "back" then
			T:go("R2F1D1")
		end
	end

	function lib.getMangroveSupplies()
		-- getItemFromNetwork(storageType, itemRequired, countRequired, toTurtleSlot, ignoreStock)
		local turtleSlot, turtleCount = U.getItemFromNetwork("barrel", "minecraft:dirt", 169, nil, true)
		if turtleCount < 169 then
			turtleSlot, turtleCount = U.getItemFromNetwork("chest", "minecraft:dirt", 169 - turtleCount, nil, true)
			if turtleCount < 169 then	-- ask player for saplings
				T:checkInventoryForItem({"dirt"}, {169 - turtleCount})
			end
		end
		turtleSlot, turtleCount = U.getItemFromNetwork("barrel", "minecraft:mangrove_propagule", 25)
		if turtleCount == 0 then	-- ask player for saplings
			T:checkInventoryForItem({"mangrove_propagule"}, {25}, true, "Mangrove propagules required")
		end
	end

	function lib.getSaplings()
		-- getItemFromNetwork(storageType, itemRequired, countRequired, toTurtleSlot, ignoreStock)
		local turtleSlot, turtleCount = U.getItemFromNetwork("barrel", "minecraft:dirt", 16, nil, true)
		if turtleCount < 16 then
			turtleSlot, turtleCount = U.getItemFromNetwork("chest", "minecraft:dirt", 16 - turtleCount, nil, true)
			if turtleCount < 16 then	-- ask player for dirt
				T:checkInventoryForItem({"dirt"}, {16 - turtleCount})
			end
		end
		turtleSlot, turtleCount = U.getItemFromNetwork("barrel", R.useBlockType, 16)
		if turtleCount == 0 then	-- ask player for saplings
			T:checkInventoryForItem({R.useBlockType}, {16}, true, "saplings required")
		end
	end

	function lib.plantMangrove()
		T:go("L1F6 R1F1 U1")
		createFloorCeiling({width = 13, length = 13, up = false, down = true,
							height = 0, subChoice = 0, useBlockType = "minecraft:dirt",
							inventory = T:getInventory()})

		--T:go("U1F5 R1F5 L1")			-- lower left of planting area, facing Back
		T:go("U1F4 R1F4 L1")			-- lower left of planting area, facing Back
		for x = 1, 5 do
			for i = 1, 5 do
				T:place("propagule", "down")	-- left 1
				if i < 5 then
					T:forward(1)
				end
			end
			if x % 2 == 1 then
				if x < 5 then
					T:go("R1F1R1")
				end
			else
				T:go("L1F1L1")
			end
		end
		T:go("L1F2 L1F2 D2U2 F7R2 D2")
		--[[
		T:place("propagule", "down")	-- left 1
		T:forward(1)
		T:place("propagule", "down")	-- left 2
		T:forward(1)
		T:place("propagule", "down")	-- left 3/top 1

		T:go("R1F1")
		T:place("propagule", "down")	-- top 2
		T:forward(1)
		T:place("propagule", "down")	-- top 3/right 1
		T:go("R1F1")

		T:place("propagule", "down")	-- right 2
		T:forward(1)
		T:place("propagule", "down")	-- right 3/bottom 1
		T:go("R1F1")
		T:place("propagule", "down")	-- bottom 2]]

		--T:go("R1F1R2 D2U2 F7R2 D2")
	end

	function lib.plantSingle()
		--local sapling, count = lib.checkSaplings(firstChoice, secondChoice)
		local saplingSlot, name, count = T:getSaplingSlot(R.useBlockType)
		if count >= 1 then
			T:go("U1L1 F3R1 F4") -- outside first area
			for i = 1, 3 do	-- column 1/4
				lib.createSingle(sapling, "forward")
				T:forward(1)
			end
			for i = 1, 2 do
				lib.createSingle(sapling, "right") -- place 4th dirt/saling and exit to right
				T:forward(1)
			end
			for i = 1, 2 do -- column 2/4
				lib.createSingle(sapling, "forward")
				T:forward(1)
			end
			for i = 1, 2 do
				lib.createSingle(sapling, "left") -- place 4th dirt/saling and exit to right
				T:forward(1)
			end
			for i = 1, 2 do -- column 3/4
				lib.createSingle(sapling, "forward")
				T:forward(1)
			end
			for i = 1, 2 do
				lib.createSingle(sapling, "right") -- place 4th dirt/saling and exit to right
				T:forward(1)
			end
			for i = 1, 3 do -- column 4/4
				lib.createSingle(sapling, "forward")
				T:forward(1)
			end
			T:go("R1F3 R1F2L1") -- in-between 2 trees
			if R.auto then
				harvestTreeFarm()
			else
				T:go("L1F4R2D1")
			end
		else
			return "No saplings to plant"
		end

		return ""
	end

	function lib.plantDouble()
		-- assume placed 4 blocks from start
		--local sapling, count = lib.checkSaplings(saplings, firstChoice, secondChoice)
		local saplingSlot, sapling, count = T:getSaplingSlot(R.useBlockType)
		if count >= 4 then
			T:go("U1L1 F3R1 F3") -- outside first area
			lib.createIsland(sapling, count, "forward")
			saplingSlot, sapling, count = T:getSaplingSlot(R.useBlockType)
			T:go("F2")
			lib.createIsland(sapling, count, "right")
			saplingSlot, sapling, count = T:getSaplingSlot(R.useBlockType)
			T:go("F2")
			lib.createIsland(sapling, count,  "right")
			saplingSlot, sapling, count = T:getSaplingSlot(R.useBlockType)
			T:go("F2")
			lib.createIsland(sapling, count, "forward")
			T:go("R1F4 R1F1 L1") 			-- on left side of double tree
			if R.auto then
				harvestTreeFarm()
			else
				T:go("L1F4 L1F1 L1D1")	-- back to start
			end
		else
			return "Insufficient saplings to plant"
		end
		return ""
	end

	menu.clear()
	menu.colourPrint("plantTreefarm starting: size "..R.subChoice, colors.lime)

	local message = U.wrapModem(true)	-- initialises or creates lists of where an item can be found: GLOBAL LISTS!
	if message ~= "" then return {message} end
	lib.emptyInventory()

	if R.subChoice == 3 then	-- mangrove
		lib.getMangroveSupplies()
		lib.plantMangrove()
	else
		lib.getSaplings()
		-- check type/size of farm
		local message = ""
		if R.subChoice == 1 then 			-- 16 single trees
			message = lib.plantSingle()		-- always ""
		elseif R.subChoice == 2 then 		-- 4 double trees (4 saplings)
			message = lib.plantDouble()		-- "" or error about numbers
		end
	end
	lib.emptyInventory()
	if message == "" then					-- planted successfully
		message = "Planted tree farm with "..R.useBlockType
	end
	return {message}
end

function upgradeFarmland()
	local essences = {":inferium", ":prudentium", ":tertium", ":imperium", ":supremium", ":awakened" , ":insanium"}

	local lib = {}

	function lib.isHigherTeir(essence, farmLand)
		-- eg "ma:prudentium_essence", "mc:farmland"
		local teir = 0
		for index = 1, #essences do
			if farmLand:find(essences[index]) ~= nil then
				teir = index	-- 0 if vanilla, else eg 2 for prudentium
				break
			end
		end
		for index = 1, #essences do
			if essence:find(essences[index]) ~= nil then
				if index > teir then
					return true
				end
			end
		end
		return false
	end

	function lib.upgrade(essence, slot)
		-- essence is the slot no of any essence
		turtle.select(slot)
		local blockType = T:getBlockType("up")
		if blockType:find("farmland") ~= nil then			-- farmland found (vanilla or modded)
			if lib.isHigherTeir(essence, blockType) then	-- eg "ma:inferium", mc:farmland"
				turtle.placeUp()
			end
		end
	end
	-- check if any essence still onboard
	T:checkInventoryForItem({"essence"}, {95}, false)
	-- return slotData.lastSlot, total, slotData -- integer, integer, table
	local name = ""
	local slot, amount, data = T:getItemSlot("essence")
	name = data.mostName or ""
	local empty = T:getFirstEmptySlot()

	if slot > 0 then
		T:go("D2")
		local outward = true
		for w = 1, 10 do
			for i = 1, 9 do
				if turtle.getItemCount(slot) == 0 then
					slot, amount, data = T:getItemSlot("essence")
					name = data.mostName or ""
					if slot == 0 then
						slot = empty
					end
				end
				lib.upgrade(name, slot)
				if w == 1 and i == 1 then
					T:go("F1R2 C1R2")
				elseif w == 10 and i == 1 then

				else
					T:forward(1)
				end
			end
			if outward then
				lib.upgrade(name, slot)
				if w == 1 then
					T:go("L1F1 L2C1 R1")
				elseif w == 9 then
					T:go("L1F1 L1F1 L2C1 L2")
				else
					T:go("L1F1L1")
				end
			else
				if w < 10 then
					lib.upgrade(name, slot)
					T:go("R1F1R1")
				else
					T:go("L1F1 L2C1 R2F8 L1U1 C2U2") -- 1 above normal position
				end
			end
			outward = not outward
		end
		-- sometimes original essence pops out of the ground when upgraded, so rescue it
		for w = 1, 10 do
			for i = 1, 9 do
				turtle.suckDown()
				turtle.suck()
				T:forward(1)
			end
			if outward then
				turtle.suckDown()
				turtle.suck()
				T:go("L1F1L1")
			else
				if w < 10 then
					turtle.suckDown()
					turtle.suck()
					T:go("R1F1R1")
				else
					T:go("L1F9 L1D1") -- normal position
				end
			end
			outward = not outward
		end
	end
	return ({"Farmland Upgraded"})
end


end
