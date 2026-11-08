return function(utils, pp, dbug, netherBedrock, deletesWater, brick)
function attack(direction)
	local totalHitsF = 0
	local totalHitsU = 0
	local totalHitsD = 0
	local cycles = 0
	local lib = {}

	function lib.attack(direction)
		local hitF = false
		local hitU = false
		local hitD = false
		if R.up or direction == "up" or direction == nil then
			if turtle.attackUp() then
				hitU = true
				totalHitsU = totalHitsU + 1
			end
		end
		if R.down or direction == "down" or direction == nil then
			if turtle.attackDown() then
				hitD = true
				totalHitsD = totalHitsD + 1
			end
		end
		if R.forward or direction == "forward" or direction == nil then
			if turtle.attack() then
				hitF = true
				totalHitsF = totalHitsF + 1
			end
		end
		-- colourText(row, text, reset)
		if hitF or hitU or hitD then
			menu.colourText(1, "~green~cycle "..cycles.."     ")
			menu.colourText(2, "~red~hits forward:  "..totalHitsF.."          ")
			menu.colourText(3, "~orange~hits up:   "..totalHitsU.."          ")
			menu.colourText(4, "~yellow~hits down: "..totalHitsD.."          ")
		else
			menu.colourText(1, "~green~cycle "..cycles.."               ")
			menu.colourText(2, "~yellow~No hits this time                      ")
			menu.colourText(3, "                            ")
			menu.colourText(4, "                            ")
		end
	end

	menu.clear(true)
	if R.auto then
		while true do
			cycles = cycles + 1
			lib.attack(direction)
		end
	else
		for i = 1, R.length do
			cycles = i
			lib.attack(direction)
			sleep(1)
		end
	end

	return {"Attack for "..R.length.." seconds completed", "hits forward: "..totalHitsF..", up: "..totalHitsU..", down: "..totalHitsD}
end

function composter()
    -- should have composter in inventory, or be placed on top of an existing one
    -- should be double chest above, filled with seeds
    -- barrel in front for bone_meal
    local lib = {}

    function lib.checkSetup()
        local message  = ""
        local composterSlot = T:getItemSlot("composter")
    --Log:saveToLog("checkSetup() composterSlot = "..composterSlot)
        if composterSlot == 0 then
            if T:getBlockType("down"):find("composter") == nil then
                message = message.. "\nNo composter in inventory or below turtle"
            else
                turtle.select(15)
                turtle.dropUp()
                turtle.digDown()
            end
        else
            if composterSlot ~= 15 then
                turtle.select(15)
                turtle.dropUp()
                turtle.select(composterSlot)
                turtle.transferTo(15)
            end
        end
        local blockType = T:getBlockType("forward")
        if blockType:find("barrel") == nil then
            message  = message..  "\nNo barrel in front of turtle"
        end
        blockType = T:getBlockType("up")
        if blockType:find("chest") == nil and blockType:find("barrel") == nil then
            message  = message..  "\nNo chest or barrel above turtle"
        end
    --Log:saveToLog("checkSetup() return message = '"..message.."'")
        return message
    end

    function lib.emptySlot(slot)
		turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
			local item = T:getSlotContains(slot)
            if item:find("composter") == nil then
                while turtle.dropUp() do end
            end
        end
    end

    function lib.emptyBonemeal()
		-- empty bonemeal into barrel in front
		for slot = 1, 16 do
			local item = T:getSlotContains(slot)
            if item:find("bone") ~= nil then
                turtle.select(slot)
                turtle.drop()
            end
        end
    end

    function lib.fillInventory()
        lib.emptyBonemeal()						-- put bonemeal into barrel in front
        lib.emptySlot(15)                       -- select slot 15 and empty it
        turtle.digDown()                        -- dig composter from below
        turtle.select(1)                        -- ready to empty chest into slot 1
        while turtle.suckUp() do end            -- get contents of chest above all slots except 15
        lib.emptyBonemeal()                     -- put any further bonemeal into barrel in front
        lib.emptySlot(16)                       -- empty slot 16 into chest above
    end

    local message = lib.checkSetup()
    if message ~= "" then
       --Log:saveToLog("local message = '"..message.."'")
		return {message}
    end

    lib.fillInventory()

	local hasVeg = true
	while hasVeg do
        for slot = 1, 14 do
            turtle.select(slot)
            while turtle.getItemCount(slot) > 0 do
                while turtle.dropDown() do end
                sleep(2)
                lib.emptySlot(15) -- select slot 15 and empty it
                turtle.digDown() -- dig composter from below
				turtle.select(1)
				while turtle.suckDown() do end
				T:place("composter", "down")
                turtle.select(slot) -- re-select slot
            end
        end
        lib.fillInventory()
        hasVeg = false
		for slot = 1, 14 do
			if turtle.getItemCount(slot) > 0 then
				local item = T:getSlotContains(slot)
				if item:find("composter") == nil and item:find("bone") == nil then
					hasVeg = true
				end
			end
		end
	end
	return {"Bulk composting completed"}
end

function craftItem()
	return {"Not yet implemented"}
end

function createBlazeGrinder()
	-- starts facing cube, embedded in original floor
	T:go("D4F2 L1F4 R1U4")				-- place upper floor and slabs under it
	utils.placeFloor(9, 9, brick) 			-- place brick floor on level 10
	T:down(2)
	T:place(brick, "up")
	T:go("D1R2")
	utils.ceiling(true)						-- true uses slabs

	-- place lava
	T:go("L1F4 L1F4 U4")					-- through hole in ceiling
	T:go("F4 L1F4 R2")
	for i = 1, 4 do
		T:place("lava", "down")
		T:go("F8 R1")
	end
	T:go("F4 R1F4 D2 F1 R2")
	-- place sign and repair above
	T:dig("forward")
	T:place("sign", true, "")
	T:down(1)
	T:place(brick, "up")
	T:forward(1)
	-- place blocks under exit hole
	for i = 1, 4 do
		T:place(brick, "forward")
		T:turnRight(1)
	end
	-- place chest and hopper

	T:go("D2x2")
	if not T:place("chest", "down") then
		T:place("barrel", "down")
	end
	T:up(1)
	T:place("hopper", "down")
	utils.goBack(1)
	T:place("slab", "forward")
	T:go("R2F5U3")-- return to starting point and create entrance
	return {}
end

function createBoatLift()
	-- build stepped lift with fencing gates and soul sand
	local lib = {}

	function lib.getWater(backToWater, downToWater)
		if backToWater > 0 then
			utils.goBack(backToWater)
		end
		if downToWater > 0 then
			T:down(downToWater)
		end
		T:getWater("down") -- take water from source
		sleep(0.2)
		T:getWater("down") -- take water from source
		if downToWater > 0 then
			T:up(downToWater)
		end
		if backToWater > 0 then
			T:forward(backToWater)
		end
	end

	--T:place(blockType, direction, leaveExisting, signText)

	local backToWater = 0
	local downToWater = 0

	T:go("R1F1L1") 										-- over canal facing forward
	for h = 1, R.height do
		lib.getWater(backToWater, downToWater)			-- check water supplies, return to starting position
		T:go("L1C1 R1D1 L1C1 R1", false, 0, false)		-- place towpath, forward, down, place towpath, face forward
		T:place("soul", "down", false) 				-- place soulsand down
		T:place("soul", "forward", false) 			-- place soulsand forward
		T:go("R1F1C1L1", false, 0, false)				-- place right towpath face forward
		T:place("soul", "down", false) 				-- place soulsand down
		T:place("soul", "forward", false) 			-- place soulsand forward
		T:go("U1 R1C1 L1")								-- place towpath, face forward
		T:placeWater("down") 							-- place water down
		utils.goBack(1)
		T:place("gate", "forward", false) 			-- place fence gate
		T:go("R1C1 U1C1 D1 L2F1 C1R1 F1 L1C1R1")		-- over left soul sand
		T:placeWater("down") 							-- place water down
		utils.goBack(1)
		T:place("gate", "forward", false) 			-- place fence gate
		T:go("U1 L1C1 R1F1 L1C1 R1x1")					-- facing forward first unit complete
		T:go("R1F1 L1x1 R1C1")
		utils.goBack(1)
		T:go("L1F1")
		if backToWater == 0 then
			backToWater = 1
		end
		backToWater = backToWater + 1
		downToWater = downToWater + 1
	end

	-- now finish the canal
	lib.getWater(backToWater, downToWater)
	T:go("D1 L1C1 U1C1")					-- build left towpath, facing towpath, above water level
	T:go("R1F1 L1C1 D1C1")					-- move forward, build towpath, facing towpath ground level
	T:go("R1C1 R1F1 L1C1 R1C1 U1C1")		-- build right towpath, facing towpath, above water level
	T:go("R1F1 L1C1 D1C1 U1")				-- build right towpath next to gate, facing towpath, above water level
	T:placeWater("down")
	utils.goBack(1)
	T:go("L1F1")
	T:placeWater("down")

	return {}
end

function createBorehole()
	--[[go down to bedrock and return. Chart all blocks dug/ passed through]]
	local diary = {}
	local lib = {}
	local depth = R.height	-- eg 63 start position
	local moves = 0
	--R.height = current level

	function lib.addBlock(depth, blockType, diary)
		if blockType == "" then
			blockType = "air"
		end
		table.insert(diary, blockType)


		--[[if blockType ~= "" then
			local add = true
			for k,v in pairs(diary) do
				if blockType == v then
					add = false
					break
				end
			end
			if add then
				diary[depth] = blockType
			end
		end]]

		return diary
	end

	function lib.processItem(item)
		if item:find("minecraft") ~= nil then
			return item:sub(11)
		end
		return item
	end

	function lib.writeReport(diary)
		local numLevels = #diary						-- eg 125 levels
		local levelsPerCol = math.ceil(numLevels / 4)	-- eg 31.25 -> 32
		local lines = {}
		for l = 1, levelsPerCol do						-- add 32 empty strings
			table.insert(lines, "")
		end
		local lineNo = 1
		for k, v in ipairs(diary) do
			local level = R.height - k 					-- eg 63 range 63 to -59
			local lev = "      "
			local item = lib.processItem(v)
			if level < -9 then
				lev = tostring(level).."   "			-- "-10   " to "-59   "
			elseif level < 0 then
				lev = "-0"..math.abs(level).."   "		-- "-09   " to "-01   "
			elseif level < 10 then
				lev = " 0"..level.."   "				-- " 01   " to " 09   "
			elseif level < 100 then
				lev = " "..level.."   "					-- " 10   " to " 99   "
			else
				lev = " "..level.."  " 					-- " 100  " to " 319  "
			end
			local output = lev..item					-- eg "-10   grass_block"
			if #output > 20 then						-- eg "-10   some_long_block_name"
				output = output:sub(1, 20)				-- eg "-10   some_long_block_"
			else
				output = menu.padRight(output, 20, " ")	-- eg "-10   grass_block     "
			end
			lines[lineNo] = lines[lineNo]..output		-- add new entry to this line
			lineNo = lineNo + 1							-- increase line no
			if lineNo > levelsPerCol then				-- past last line number
				lineNo = 1								-- reset to 1
			end
		end

		local fileName = "borehole"..os.getComputerID()..".txt"
		local handle = fs.open(fileName, "w") 		--create file eg "borehole0.txt"
		handle.writeLine("Level Block         Level Block         Level Block         Level Block")
		for k,v in ipairs(lines) do
			handle.writeLine(v)
		end

		handle.close()

		return fileName
	end

	local blockType = T:getBlockType("down")
	while T:down(1) do
		depth = depth - 1
		moves = moves + 1
		if depth == R.depth then
			break
		end
		diary = lib.addBlock(depth, blockType, diary)
		blockType = T:getBlockType("down")
	end
	local fileName = lib.writeReport(diary)
	T:up(moves)

	return {"File '"..fileName.."' written"}
end

function createBubbleLiftOLD()
	menu.clear()
	local message =
[[~red~Additional blocks may be required
~yellow~Observe turtle when collecting water

Right-click if not operating
Add 64 blocks of any stone

~lime~Press Enter to continue
]]
	menu.colourText(1, message)
	read()
	menu.clear()
	local dirt = "minecraft:dirt"
	if T:getItemSlot("minecraft:soul_sand") > 0 then
		dirt = "minecraft:soul_sand"
	end
	local turn, oTurn = "R", "L"								-- build column on right side

	local lib = {}

	function lib.addLayer(closeSide)
		if closeSide == nil then closeSide = true end
		if closeSide then
			T:go("R1C1 R1C1 R1C1 R1F2 L1C1 R1C1 R1C1 L1", false, 0, true) -- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		else
			T:go("R2C1 R2F2C1", false, 0, true)
		end
		turtle.back()
		T:dig("up")	-- clear block above so completed lift can be found
		T:placeWater("forward")
		turtle.back()
		T:go("C1x0")
	end

	function lib.buildLift(toHeight)
		local built = lib.goToWater() 		-- returns lift blocks already placed, total height of drop from starting point
		local toBuild = toHeight - built 	-- no of blocks remaining to increase lift size
		local waterBuckets = 0
		local entryLayer = 0
		while toBuild > 0 do 				-- at least 1 block height remaining
			entryLayer = entryLayer + 1
			if entryLayer == 1 then
				waterBuckets = lib.fillBuckets(true) -- emty trash and arrange buckets
			else
				waterBuckets = lib.fillBuckets(false) -- no of water buckets onboard (could be more than required)
			end
			if waterBuckets > toBuild then			-- more water than required
				waterBuckets = toBuild				-- reduce to correct amount
			end
			T:up(built)						-- climb to top of existing lift
			while waterBuckets > 0 and toBuild > 0 do
				if entryLayer > 2 then
					lib.addLayer(true)
				else
					lib.addLayer(false)
				end
				entryLayer = entryLayer + 1
				waterBuckets = waterBuckets - 1
				T:up(1)
				toBuild = toBuild - 1
			end
			-- may still be some height to complete, but needs refill
			if toBuild > 0 then
				built = lib.goToWater() --return to source
				toBuild = toHeight - built
				--lib.fillBuckets(toBuild)
			end
		end
	end

	function lib.createSource()
		-- place source at ground level, start above soul sand position, facing along source
		--T:go("F2C1"..turn.."1F1C2 L1C1 R2C1 L1F1C2 L1C1 R2C1 L1F1C2 L1C1 R1C1 R1C1 R1U1", false, 0, true)	-- end of source facing Start
		T:go("C2F1 L1C1 R2C1 L1F1C2 L1C1 R2C1 L1F1C2 L1C1 R1C1 R1C1 R1U1", false, 0, true, R.useBlockType)	-- end of source facing Start
		T:placeWater("down") 											-- place back water source
		T:forward(2)
		T:placeWater("down") 											-- place front water source
		T:go("F1R2C2", false, 0, true, R.useBlockType)
		-- |W|W|W|S|C now at position S facing source water: starting point and direction, 1 above ground level
	end

	function lib.fillBuckets(withSort)
		local emptyBuckets = T:getItemCount("minecraft:bucket")
		for i = 1, emptyBuckets do
			if T:getWater("down") then
				sleep(0.5)
			end
		end
		if T:getItemCount("stone") < 16 then
			T:checkInventoryForItem({"stone"}, {64}, true)
		end

		return T:getItemCount("minecraft:water_bucket")
	end

	function lib.goToWater()
		local built = 0 -- measures completed lift height
		while turtle.down() do -- takes turtle to bottom of water source
			if turtle.detect() then
				built = built + 1
			end
		end
		T:up(1) -- above watersource ready to fill buckets
		-- height = height - 1
		-- built = built - 1 not required as next block is water source: not detected
		--lib.fillBuckets(R.height - built, false)
		return built -- , height
	end

	function lib.isLadder()
		for i = 0, 3 do
			local blockType = T:getBlockType("forward")
			if blockType:find("ladder") ~= nil then
				return true, i
			end
			turtle.turnRight()
		end
		return false, 0
	end

	function lib.stackBuckets(withSort)
		if withSort == nil then withSort = false end
		local data = {}
		local noEmpty = false
		if withSort then
			T:emptyInventorySelection("up", {"minecraft:bucket", "minecraft:water_bucket", R.useBlockType}, {12, 12, 192})
		end
		-- iterate all slots
		for i = 1, 16 do
			if turtle.getItemCount(i) > 0 then
				data = turtle.getItemDetail(i)
				if data.name == "minecraft:bucket" then
					if data.count > 1 then
						turtle.select(i)
						while turtle.getItemCount(i) > 1 do
							local empty = T:getFirstEmptySlot()
							if empty > 0 then
								turtle.transferTo(empty)
							else
								noEmpty = true
								break
							end
						end
						if noEmpty then break end
					end
				end
			end
		end
		local emptySlots = T:getEmptySlotCount()
		local waterBuckets = T:getItemCount("minecraft:water_bucket")
		local emptyBuckets = T:getItemCount("minecraft:bucket")
		return emptySlots, waterBuckets, emptyBuckets
	end

	local ladder, turns = lib.isLadder()							-- is ladder next to turtle?, If yes then turns to right is returned
	if ladder then													-- ladder found and facing it
		T:go("L"..turns)											-- face gap next to ladder
		if turns == 1 then
			turn = "L"												-- build column on left side
			oTurn = "R"
		end
	end
	R.height = math.abs(R.upperLevel - R.lowerLevel)
	R.currentLevel = R.startLevel	-- eg 64 going down
	R.useBlockType = T:getMostItem("", false)
	local emptyBuckets = T:getItemCount("minecraft:bucket")
	if emptyBuckets > 10 then
		T:dropItem("minecraft:bucket","up", 10)
	end

	if ladder then
		T:go("F1"..turn.."1")										-- backing ladder column, on floor
		lib.createSource()											-- starting position, but up 1
		if T:getItemCount("sign") >= 4 then
			T:go(oTurn.."1F1"..turn.."1C1 U1C1"..oTurn.."2F1"..oTurn.."2", false, 0, true, R.useBlockType)-- back of ladder column
			T:place("sign", "forward", false, "Lift to\nsurface")		-- top sign
			T:go("D1")													-- down
			T:place("sign", "forward", false, "Travel at\nown risk")	-- lower sign
			T:go("D1F1"..turn.."1F1U1C2"..oTurn.."1", false, 0, true, R.useBlockType)
		end
		T:go(turn.."1F1"..oTurn.."1C1 U1C1"..turn.."2F1"..turn.."2", false, 0, true, R.useBlockType)-- will now have removed ladder 3rd block from ground, facing lift entrance
		T:place("sign", "forward", false, "Lift to\nsurface")		-- top sign
		T:go("D1")													-- down
		T:place("sign", "forward", false, "Travel at\nown risk")	-- lower sign
		T:go(oTurn.."1B1")
		T:place("ladder", "forward")
		T:up(1)
		T:place("ladder", "forward")
		T:up(1)
		T:place("ladder", "forward")
		T:go("D3"..turn.."1F1"..oTurn.."1F2"..turn.."1U1")
		T:place(dirt, "down")										-- soul sand placed at end of source
		T:go("F2R1x1 L2x1 U1x1 R2x1 R1D1")							-- centre of source, facing column
	else
		T:go("F2"..turn.."1")										-- backing ladder column, on floor
		lib.createSource()											-- starting position, but up 1
		T:go(turn.."1F1"..turn.."1C1 U1C1"..turn.."2F1"..turn.."2", false, 0, true, R.useBlockType)	-- return to start, place blocks to support signs
		T:place("sign", "forward", false, "Lift to\nsurface")		-- top sign
		T:go("D1C0", false, 0, true, R.useBlockType)												-- down and block above
		T:place("sign", "forward", false, "Travel at\nown risk")	-- lower sign
		T:go("D1C0 F1R2 C1"..oTurn.."1F1R2C1"..turn.."1U1"..turn.."2", false, 0, true, R.useBlockType)	-- ground level, return to soul sand site, go up
		T:place(dirt, "down")										-- soul sand placed at end of source
		T:go("F2R1x1 L2x1 U1x1 R2x1 R1D1")							-- centre of source, facing column
	end
	--lib.fillBuckets(R.height, true)									-- fill as many buckets as required or until inventory full, sort inventory as well
	-- ready to build lift
	local height = R.height + math.abs(R.currentLevel)
	lib.stackBuckets(true)
	lib.buildLift(height - 1)

	return {"Bubble lift created", "Check correct operation", "Check exit before using" }
end

function createBubbleLift()
	-- Normal start at top- if start from bottom:
	-- move in to column
	-- dig directly up to upperLevel
	local lib = {}

	function lib.addPipe()
		for j = 1, 4 do
			-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
			T:go("C1R1", false, 0, true)
		end
	end

	function lib.placeKelp()
		T:place("minecraft:kelp", "forward")
		T:up(1)
	end

	local drop = 0
	if R.down then
		menu.colourPrint("Wait for my return!", colors.yellow)
	end
	R.height = math.abs(R.upperLevel - R.lowerLevel)
--Log:saveToLog("createBubbleColumn(): R.height = "..R.height, true)
	if R.up then
		T:go("F1U"..R.height)
	end
	local atBedrock = false
	local blockType = T:getBlockType("down")
	for i = 1, R.height do
		if blockType:find("bedrock") == nil then	-- not at bedrock
			T:down(1)
			drop = drop + 1
			lib.addPipe()
			if i == 1 then
				T:placeWater("forward")
			end
			blockType = T:getBlockType("down")
		else 										-- at bedrock
			atBedrock = true
			break
		end
	end
	if atBedrock then
		T:up(1)
		drop = drop - 1
	else
		T:dig("down")
	end
	if not T:place("minecraft:soul_sand", "down") then
		T:place("minecraft:dirt", "down")
	end
	T:go("R2F1R2C2")
	lib.placeKelp()
	T:place("sign", "down", false, "UP!")
	lib.placeKelp()
	T:place("sign", "down", false, "GOING")
	for i = 1, drop - 2 do
		lib.placeKelp()
	end
	while turtle.down() do end	-- on top of signs
	T:go("F1D1x2 U1B1")			-- break kelp and move over it, down 1, break last piece, return to column
	for i = 1, drop - 2 do
		T:go("U1C2")
	end

	return {"Bubble column completed "..drop.. " blocks"}
end

function createCorridor()
	--[[create a corridoor 2 blocks high, with floor and ceiling guaranteed
	T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)]]
	local lib = {}

	function lib.continue(currentSteps, totalSteps)
		if not R.silent then
			if currentSteps >= 64 and R.length == 0 then
				-- request permission to continue if infinite
				T:clear()
				print("Completed "..totalSteps..". Ready for 64 more")
				print("Do you want to continue? (y/n)")
				response = read()
				if response:lower() ~= "y" then
					return true, 0
				else
					return false, currentSteps
				end
			end
		end
		return true, currentSteps
	end

	function lib.seal()
		local blockType = T:getBlockType("forward")
		if blockType:find("water") ~= nil then
			T:place("stone", "forward", false)
			return "water"	-- water found
		elseif blockType:find("lava") ~= nil then
			T:place("stone", "forward", false)
			return "lava"	-- lava found
		end
		return ""	-- no water or lava
	end

	function lib.checkSeal()
		local fluidType = ""
		if R.data == "seal" then 		-- check for lava/water at the sides
			T:turnRight(1)
			fluidType = lib.seal()		-- could be "", "water", "lava"
			T:turnLeft(2)
			local blockType = lib.seal()
			if fluidType == "" then		-- no water / lava so far
				fluidType = blockType	-- could be "", "water", "lava"
			end
			T:turnRight(1)
		end
		return fluidType				-- could be "", "water", "lava"
	end

	function lib.placeTorch(torchSpaces, totalSteps)
		if R.torchInterval > 0 then -- torches onboard
			if torchSpaces == R.torchInterval then -- time to place another torch
				if totalSteps < R.length then -- not at end of run
					if T:getItemSlot("minecraft:torch") > 0 then
						T:place("minecraft:torch", "down")
					end
					torchSpaces = 1
				end
			end
		end
		return torchSpaces -- original value or 1
	end

	if T:getItemSlot("minecraft:torch") == 0 then
		R.torchInterval = 0 -- set to default 9 in getTask()
	end
	local currentSteps = 0					-- counter for infinite length. pause every 64 blocks
	local totalSteps = 0					-- counter for all steps so far
	local torchSpaces = R.torchInterval		-- if torches present, counter to place with 8 blocks between
	local fluidType = ""
	local damLength = 0
	local damStarted = false
	local doContinue = true

	for steps = 1, R.length do
		-- starts on floor of tunnel
		doContinue, currentSteps = lib.continue(currentSteps, totalSteps) -- continue tunnelling?
		if not doContinue then
			break
		end
		T:go("C2U1C0", false, 0, true)		-- place floor, up 1, place ceiling
		fluidType = lib.checkSeal()			-- if R.data == "seal", check for water/lava at ceiling level
		if fluidType == "" then				-- either R.data ~= "seal" or no fluid found
			torchSpaces = lib.placeTorch(torchSpaces, totalSteps) -- original value or 1 if torch placed
			T:go("F1D1")
		elseif fluidType == "water" then
			T:go("F1R2 C1D1 C1L2", false, 0, true)
			damStarted = true
			damLength = damLength + 1
		else	--lava
			T:go("F1D1")
		end
		blockType = lib.checkSeal()
		if blockType ~= "" then
			fluidType = blockType
		end
		currentSteps = currentSteps + 1
		totalSteps = totalSteps + 1
		torchSpaces = torchSpaces + 1
		if damStarted and fluidType == "" then -- was in water, but no more
			T:go("R2 F"..damLength + 1 .."U1L2F"..damLength + 1 .."D1")
			damStarted = false
		end
	end
	if fluidType ~= "" then -- water or lava found while tunnelling
		T:go("U1C0", false, 0, true)
		lib.checkSeal()
		T:go("C1", false, 0, true)
		T:down(1)
	end
	return {}
end

function createDirectedPath()
	-- allow user to control length / width of each path
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	--local pp = utils.getPrettyPrint()
	local lib = {}

	function lib.forward()
		if R.subChoice == 1 then
			for i = 1, R.length do
				T:go("F1x0C2", false, 0, true)
			end
		else
			for i = 1, R.length do
				T:go("F1U1C0D1C2", false, 0, true)
			end
		end
	end

	function lib.back()
		for i = 1, R.length do
			turtle.back()
		end
	end

	function lib.left()
		T:turnLeft(R.length)
	end

	function lib.right()
		T:turnRight(R.length)
	end

	function lib.up()
		if R.subChoice == 1 then
			T:go("U2R2 x1R2 D1C2", false, 0, true)
		else
			T:go("U2R2 x1R2C0 D1C2", false, 0, true)
		end
	end

	function lib.down()
		T:go("D1C2", false, 0, true)
	end

	if R.data == "menu" then
		-- mimics direct commands using f.lua, r.lua etc with space between commands and number
		local width = 0
		local length = 0
		local choices =
		{
			"Forward 1 block",
			"Forward # blocks",
			"Back 1 block",
			"Back # blocks",
			"Turn Right",
			"Turn Left",
			"Up 1 block",
			"Down 1 block",
			"Quit"
		}
		local choice, modifier
		pp.itemColours = {colors.lime, colors.lime, colors.green, colors.green, colors.orange, colors.orange, colors.cyan, colors.cyan, colors.gray}
		while choice ~= 9 do
			choice, modifier = menu.menu("Choose next step", choices, pp, "Type number + Enter ")
			if choice == 1 then
				R.length = 1
				lib.forward()
			elseif choice == 2 then
				-- getInteger(prompt, minValue, maxValue, row, fg, bg, default)
				R.length = menu.getInteger("Move forward how many blocks?", 1, 250, nil, colors.lime)
				lib.forward()
			elseif choice == 3 then
				R.length = 1
				lib.back()
			elseif choice == 4 then
				R.length = menu.getInteger("Move back how many blocks?", 1, 250, nil, colors.green)
				lib.back()
			elseif choice == 5 then
				R.length = 1
				lib.right()
			elseif choice == 6 then
				R.length = 1
				lib.left()
			elseif choice == 7 then
				lib.up()
			elseif choice == 8 then
				lib.down()
			end
		end
	else
		local instructions =
[[~lightGray~Commands:

direction + ~blue~number ~yellow~eg ~white~f2 ~yellow~= forward ~blue~2
~lightGray~direction without number = ~blue~1

~yellow~f = forward  ~orange~b = backward
~lime~l = left     ~red~r = right
~lightGray~u = up       ~cyan~d = down

~red~q = quit

]] -- Direct control
		local cmd = ""
		while cmd ~= "q" do
			local line = menu.clear()
			line = menu.colourText(line, instructions)
			-- menu.getString(prompt, withTitle, minValue, maxValue, row, fg, bg, default)
			input = menu.getString("command ", false, 1, 5, line, colors.yellow, colors.black):lower()
			-- remove spaces
			input = input:gsub( " ", "")
			cmd = input:sub(1,1)
			R.length = 1
			if #input > 1 then
				R.length = tonumber(input:sub(2))
			end
			if cmd == "q" then
				return{"User has quit application"}
			end
			if cmd == "f" then
				lib.forward()
			elseif cmd == "b" then
				lib.back()
			elseif cmd == "l" then
				lib.left()
			elseif cmd == "r" then
				lib.right()
			elseif cmd == "u" then
				lib.up()
			elseif cmd == "d" then
				lib.down()
			end
		end
	end
	return {}
end

function createDiveColumn()
	-- place a series of doors in deep water to make a dive column
	-- go to sea bed
	local block = T:getMostItem("door", false)
	local moves = 0
	local lib = {}

	function lib.placeDoor()
		-- place block, door above, open it, move above.
		T:place(block, "forward")
		T:go("U1")
		T:place("door", "forward")
		rs.setAnalogOutput("front", 15)
		T:up(2)							-- above door
	end

	while turtle.down() do
		moves = moves + 1						-- increment counter
	end

	T:go("F1R2")								-- on sea bed. clear any block in front
	while moves > 0 do							-- head back to surface
		lib.placeDoor()
		T:go("F3R2")
		if moves < 3 then break end
		moves = moves - 3
	end
	return {"Dive column created"}
end

function createDragonTrap()
	-- build up 145 blocks with ladders
	T:clear()
	local text =
[[~yellow~You ~red~MUST ~yellow~have already constructed a
bridge / tunnel into the dragon island
to allow for safe construction of the
dragon trap.

If not use toolkit:
  ~brown~5.~gray~2 Covered path or tunnel~yellow~ length 100

start centre of obsidian platform:
  100,49,0 facing west
~orange~Enter to continue]]
	menu.colourText(1, text)
	read()
	menu.colourPrint("Press Enter to start 1 minute delay\n", colors.red)
	menu.colourPrint("Run to island centre across the bridge\n", colors.orange)
	menu.colourPrint("You have already made the bridge?...", colors.lime)
	read()
	for t = 60, 1, -1 do
		sleep(1)
		T:clear()
		io.write("Starting in "..t.. " seconds ")
	end
	for i = 1, 145 do
		T:go("U1C2")
		turtle.back()
		T:place("minecraft:ladder", "down")
		turtle.forward()
	end
	T:go("R2F1C1 L1C1 L2C1 R1")
	for i = 1, 100 do
		T:go("F1C2U1C0D1")
	end
	T:forward(1)
	T:place("minecraft:obsidian", "down")
	T:go("R2F1x2R2")
	T:placeWater("forward")
	T:go("R2F6R2")
	attack()

	return {}
end

function createEnclosure()
	local lib = {}

	function lib.placeBarrel()
		if R.inventoryKey == "barrel" then
			utils.goBack(1)
			T:go("L1F1")
			T:place("barrel", "down", false)
			utils.goBack(1)
			T:go("R1")
			T:forward(1)
		end
	end

	function lib.placeTorch()
		T:up(1)
		local up = 1
		local blockType = T:getBlockType("forward")
		while blockType:find(R.useBlockType) ~= nil and blockType ~= "" do -- prevent continuous upward travel
			T:up(1)
			up = up + 1
			blockType = T:getBlockType("forward")
		end
		T:place("torch", "forward", true)
		T:down(up)
	end

	function lib.buildWall(length)
		-- T:place(blockType, direction, leaveExisting, signText)
		local blockType = ""
		local blocks = 0
		lib.placeBarrel()
		while blocks < length do
			if turtle.back() then
				T:place(R.useBlockType, "forward", true)
				if R.torchInterval > 0 then
					if blocks == 0 or blocks % R.torchInterval == 0 then
						lib.placeTorch()
					end
				end
				blocks = blocks + 1 -- still facing start position
				while turtle.down() do
					T:place(R.useBlockType, "up", true)
				end
			else -- obstruction
				T:turnRight(2) -- facing away from start
				blockType = T:getBlockType("forward")
				if blockType:find("torch") ~= nil then
					T:go("F1R2")
					T:place(R.useBlockType, "forward")
					blocks = blocks + 1 -- facing start
				elseif blockType:find("log") ~= nil then
					T:harvestTree()
					T:turnRight(2)
					T:place(R.useBlockType, "forward")
					blocks = blocks + 1 -- facing start
				elseif T:isVegetation(blockType) then
					T:go("F1R2")
					T:place(R.useBlockType, "forward")
					blocks = blocks + 1 -- facing start
				else -- cant go forward, go up instead
					while turtle.detect() and blockType:find("torch") == nil and blockType:find("log") == nil and not T:isVegetation(blockType) do -- block ahead, but not torch or tree
						while turtle.detectUp() do -- will only run if block above
							utils.goBack(1)
							blocks = blocks - 1
						end
						turtle.up()
						T:place(R.useBlockType, "down", true)
						blockType = T:getBlockType("forward")
					end
					T:turnRight(2) -- facing start
				end
			end
		end
	end
	R.useBlockType = T:getMostItem("", false)
	T:turnRight(2) --facing start position
	if R.width == 0 then -- single fence
		lib.buildWall(R.length)
	else
		lib.buildWall(R.length - 1)
		T:go("R1") -- facing start so left turn = turnRight
		lib.buildWall(R.width - 1)
		T:go("R1")
		lib.buildWall(R.length - 1)
		T:go("R1")
		lib.buildWall(R.width - 2)
		T:go("U1")
		T:place(R.useBlockType, "down", true)
	end

	return {"Wall or fence completed"}
end

function createLadder()
	-- go(path, useTorch, torchInterval, leaveExisting)
	-- place(blockType, damageNo, direction, leaveExisting)
	local lib = {}

	function lib.isFluid(side)
		-- check if water or lava present
		side = side or "forward"
		local blockType = ""
		if side == "left" then
			T:turnLeft(1)
		elseif side == "right" then
			T:turnRight(1)
		end
		blockType = T:getBlockType("forward")
		--Log:saveToLog("lib.isFluid() blockType (forward) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then	-- fluid found, return to correct position
			if side == "left" then
				T:turnRight(1)
			elseif side == "right" then
				T:turnLeft(1)
			end
			return true
		end
		blockType = T:getBlockType("up")
		--Log:saveToLog("lib.isFluid() blockType (up) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then
			return true
		end

		blockType = T:getBlockType("down")
		--Log:saveToLog("lib.isFluid() blockType (down) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then
			return true
		end

		return false
	end

	function lib.buildDam()
		--T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		if lib.isFluid("forward") then
			--[[ surround 2 block shaft with blocks ]]
			T:go("R1C1 R1C1 R1C1 R1F1 L1C1 R1C1 R1C1 R1C1F1 R2C1 x1")
		else
			--[[ no water/lava so prepare ladder site]]
			T:go("F1 L1C1 R1C1 R1C1 L1B1", false, 0, true)
		end
	end

	function lib.placeLadder(direction, ledge, i)
		if not T:place("ladder", "forward", false) then
			T:checkInventoryForItem({"ladder"}, {height - i}, false)
		end
		-- 3 check if ledge, torch
		if ledge == 0 and i > 1 then -- place block above unless new ladder
			T:place("common", direction, false) -- any common block
		elseif ledge == 1 then
			T:place("minecraft:torch", direction, false)
		elseif ledge == 2 then
			ledge = -1
		end

		return ledge
	end

	menu.clear()

	-- R.startLevel and R.destinationLevel set in taskInventory.lua
	-- R.auto = stop at stronghold/trial chamber
	-- R.startLevel eg 64 at top (R.goDown = true) or 5 at bedrock, R.goUp = true
	-- R.lowerLevel = bottom of ladder
	-- R.upperLevel = top of ladder
--Log:saveToLog("tk3.createLadder() starting; R.up = "..tostring(R.up).."R.down = "..tostring(R.down)
--			   .."R.startLevel = "..R.startLevel.."R.destinationLevel = "..R.destinationLevel)

	R.height = math.abs(R.upperLevel - R.lowerLevel)
	R.currentLevel = R.startLevel	-- eg 64 going down
	local retValue = {}
	local ledge = 0
	--local height = math.abs(R.currentLevel - R.height) --height of ladder
	local blockType = T:getBlockType("forward")
	--if R.goUp then -- create ladder from current level to height specified
	if R.up then -- create ladder from current level to height specified
		print("Creating ladder going up "..R.height.." blocks")
		for i = 1, R.height do -- go up, place ladder as you go
			lib.buildDam()
			ledge = lib.placeLadder("down", ledge, i, R.currentLevel) -- ladder placed forward, stone ledge for torch placed down
			if i < R.height then
				T:up(1)
				R.currentLevel = R.currentLevel + 1
				ledge = ledge + 1
			end
		end
	else -- R.goDown = true: ladder towards bedrock
		print("Creating ladder going down "..R.height.." blocks")
		local success = true
		local numBlocks, errorMsg = 0, ""
		T:down(1)
		R.currentLevel = R.currentLevel - 1
		for i = 1, R.height do -- go down, place ladder as you go
			lib.buildDam()
			ledge = lib.placeLadder("up", ledge, i) -- ladder placed forward, stone torch placed up
			--success, blocksMoved, errorMsg, blockType = clsTurtle.down(self, steps, getBlockType)
			if i < R.height then
				success, numBlocks, errorMsg, blockType = T:down(1, true) -- true = return blockType
				ledge = ledge + 1
			end
			-- if looking for stronghold then check for stone_bricks
			if R.auto then
				if blockType:find("stone_bricks") ~= nil then
					table.insert(retValue, "Stronghold discovered")
					break -- stop descent at stronghold
				end
				if blockType:find("polished_tuff") ~= nil then
					table.insert(retValue, "Trial chamber discovered")
					break -- stop descent at trial chamber
				end
			end
		end
		-- if user requested shelter create chamber at this level
		if R.data == "chamber" then -- user has chosen to build a chamber
			table.insert(retValue, "Shelter constructed at level".. R.depth)
			if blockType:find("bedrock") ~= nil then
				T:findBedrockTop(0) -- test to check if on safe level immediately above tallest bedrock
			end
			-- In shaft, facing start direction, on lowest safe level
			-- create a square space round shaft base, end facing original shaft, 1 space back
			T:go("C2 L1n1 R1n3 R1n2 R1n3 R1n1", false, 0, true)
			T:go("U1Q1 R1Q3 R1Q2 R1Q3 R1Q1 R1D1", false, 0, true)
		end
	end

	return retValue
end

function createMobBubbleLift()
	-- Part 3 / 3 Mob Spawner Farm
	-- R.subChoice = 1 or 2 (left/right)
	local lib = {}

	function lib.initialise()
		local blockType = T:getBlockType("down")
		if blockType ~= "minecraft:soul_sand" then
			T:dig("down")
			if not T:place("minecraft:soul_sand", "down", false) then
				return {"Unable to find or place soul sand."}
			end
		end
		-- check facing sign, rotate if not
		blockType = T:getBlockType("forward")
		local turns = 0
		while blockType:find("sign") == nil do
			T:turnRight(1)
			turns = turns + 1
			if turns == 4 then
				return {"Unable to find sign."}
			end
			blockType = T:getBlockType("forward")
		end
		return {""}
	end

	function lib.createWaterSource()
		T:go("F2R2 F1D1")
		for i = 1, 3 do
			T:go("C2 L1C1 R2C1 L1")
			if i < 3 then
				T:go("F1")
			end
		end
		T:go("R2F1") 				-- face column move to middle
		T:placeWater("forward")
		T:go("R2")					-- face away
		T:placeWater("forward")
		T:go("R2U1")				-- facing column, above surface, centre of source
	end

	function lib.goToWater(moves)
		T:down(moves)
		T:getWater("down")
		sleep(0.1)
		T:getWater("down")
	end

	function lib.placeCollector(turn, oTurn)
		local hopperSlot = T:getItemSlot("hopper")
		local chestSlot = T:getItemSlot("chest")
		if hopperSlot > 0 and chestSlot > 0 then
			T:dig("down")
			T:place("chest", "down")
			T:go(turn.."1F1"..oTurn.."1")
			T:dig("down")
			T:place("chest", "down")
			T:go(turn.."1")
			utils.goBack(3)
			T:go("D1x1")
			T:place("hopper", "forward")
			T:go("U1C2F2"..oTurn.."1")
		end
	end

	function lib.up()
		local moves = 0
		while turtle.detect() do
			turtle.up()
			moves = moves + 1
		end

		return moves
	end

	function lib.createChamber()
		local D =
		{
			width  = 4,
			length = 7,
			height = 4,
			ceiling = true,
			floor = true,
			vDirection = "D",
			hDirection = "RL",
			goHome = true
		}
		if R.subChoice == 1 then
			D.hDirection = "LR"
		end
		utils.createWalledSpace(D)
	end

	function lib.mobTransporter()
		for i = 1, 9 do -- fill in a solid block bar from bubble column for 8 spaces
			T:go("F1C0C2 R1C1 R1C1 R1C1 R1C1")
		end
		T:go("D1C2C1 R1C1 R2C1 L1 C0x0") -- move down column
		for i = 1, 8 do -- go under solid block bar
			T:go("F1C2 R1C1 L2C1 R1x0")
		end
	end

	menu.clear()

	local turn = "R"
	local oTurn = "L"
	if R.subChoice == 1 then
		turn = "L"
		oTurn = "R"
	end

	local data = lib.initialise()			-- check if in the right position
	if data[1] ~= "" then
		return data 						-- eg {"Unable to find sign."}
	end
	--lib.createWaterSource(oTurn)			-- everything in place, build a water source, facing spawner
	for i = 1, 3 do		-- fill in back and one side, go up
		T:go(turn.."1C1"..turn.."1C1"..turn.."1x1"..turn.."1U1", false, 0, true)
	end
	-- dungeon wall, above mob exit, facing spawner
	local colHeight = 19
	for i = 1, colHeight do		-- tunnel up, filling 3 sides
		T:go(turn.."1C1"..turn.."1C1"..turn.."1x1"..turn.."1C1 U1", false, 0, true)
	end
	-- facing spawner 20 blocks up. move either left/right 8 blocks, repairing ceiling and sides
	T:go("C0"..turn.."2C1"..turn.."1F1 C0C1"..turn.."1C1"..turn.."2C1"..oTurn.."1", false, 0, true) -- fill top of column
	lib.mobTransporter()
	T:go("x2x0 F1x2x0 F1x2x0 R2") -- over water source
	T:down(colHeight + 2)
	-- now create bubble column
	lib.createWaterSource(oTurn)			-- everything in place, build a water source, facing spawner
	local moves = 0
	repeat
		lib.goToWater(moves)	-- get water
		moves = lib.up()
		T:go("F1")
		T:placeWater("forward")
		T:go("U1C2")
		T:placeWater("forward")
		utils.goBack(1)
		T:go("C1")
		moves = moves + 1
	until moves >= colHeight + 1
	lib.goToWater(moves)	-- get water for last time
	lib.up()				-- finishes above lower part of the transport bar
	T:go("F2R2C1D1")		-- seal off bubble column
	utils.goBack(1)
	T:placeWater("forward")	-- place source on top of bubble column
	utils.goBack(7)			-- over down shaft
	T:down(1)				-- start shaft, facing bubble column
	for i = 1, 17 do
		-- tunnel down, filling all 4 sides
		T:go("R1C1 R1C1 R1C1 R1C1 D1", false, 0, true)
	end
	-- facing column
	lib.createChamber()
	T:go("x0")
	T:go(oTurn.."1C1".. turn.."1D1C2"..oTurn.."1C1"..turn.."1F1".. oTurn.."1F1"..oTurn.."1") -- facing end wall ready to place slabs
	for i = 1, 6 do
		T:place("slab", "down")
		if i == 6 then
			T:go(oTurn.."1")
		end
		utils.goBack(1)
		T:go("C1")
	end

	T:go("D2F2"..turn.."1F5")
	T:placeWater("forward")
	T:go(turn.."1F1"..oTurn.."1") -- facing down mob channel floor
	for i = 1, 5 do
		T:go("C1")
		utils.goBack(1)
	end
	T:go("C1"..turn.."1F1"..turn.."1F1")
	for i = 1, 7 do
		T:go("C2x0")
		if i < 7 then
			T:forward(1)
		end
	end
	T:go("U3R2")
	for i = 1, 7 do
		T:go("F1x2")
	end
	T:go("D3")

	lib.placeCollector(turn, oTurn) -- if hopper / chests present

	return {}
end

function createPath()
	--[[places a path in air/lava/water.]]
	local length = R.length
	local torchInterval = R.torchInterval
	local numBlocks = 0
    local preferredBlock = {}
	local _, total, slotData = T:getItemSlot("slab")
	if total > 0 then
		preferredBlock = {slotData.name}
	end
	_, total, slotData = T:getItemSlot("minecraft:dirt")
	if total > 0 then
		preferredBlock = {"minecraft:dirt"}
	end
	if  R.data == "reduce" then
		T:forward(1)
		local blockType = T:getBlockType("down")
		local useBlock = blockType
		while blockType == useBlock do
			T:go("x2F1")
			numBlocks = numBlocks + 1
			blockType = T:getBlockType("down")
		end
        utils.goBack(numBlocks + 1)
	else
		--for i = 1, 2 do
		--	T:fillVoid("down", preferredBlock, false, true)
		--	T:forward(1)
		--	numBlocks = numBlocks + 1
        --end
		local start = true
		local place = utils.clearVegetation("down")
		while place or start do -- while air, water, normal ice, bubble column or lava below
			-- T:fillVoid(direction, tblPreferredBlock, leaveExisting, allowSlab)
			if T:fillVoid("down", preferredBlock, false, true) or start then -- false if out of blocks
			    start = false
				if R.data == "left" then
                    T:go("L1F1 C2 R1F1")
                elseif R.data == "right" then
					T:go("R1F1 C2 L1F1")
				else
				    T:go("F1")
				end
				numBlocks = numBlocks + 1
				if numBlocks % torchInterval == 1 or numBlocks == 0 then
					if T:getItemSlot("minecraft:torch", -1) > 0 then
						T:turnRight(2)
						T:place("minecraft:torch", "forward", false)
						T:turnRight(2)
					end
				end
			else
				break
			end
			if length > 0 and numBlocks >= length then -- not infinite path (length = 0)
				break
			end
			place = utils.clearVegetation("down")
		end
	end
	return {numBlocks} -- returned as a table in case called as task 51 back to main()
end

function createPlatform()
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	local forward = true
	R.useBlockType = T:getMostItem("", true)
	for w = 1, R.width do
		for l = 1, R.length do
			T:go("x2C2", false, 0, false, R.useBlockType)
			if R.up then
				T:dig("up")
			end
			if l < R.length then
				T:forward(1)
			end
		end
		if w < R.width then
			if forward then
				if R.up then
					T:go("R1F1 x0R1")
				else
					T:go("R1F1 R1")
				end
			else
				if R.up then
					T:go("L1F1 x0L1")
				else
					T:go("L1F1 L1")
				end
			end
		end
		forward = not forward
	end
	return {}
end

function createPortal()
	--[[
	R.length = length of portal NOT width default 4
	R.height = height of portal default 5
	R.width = thickness of portal default 1
	R.data = "bury" to embed bottom into ground
	R.side = "F" (facing) "E" at edge
	]]

	local lib = {}

	function lib.buildBase()
		--T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		T:go("C2", false, 0, false, R.useBlockType)
		T:forward(1)
		for i = 1, R.length - 2 do -- R.length = 4: place when i=1,2
			T:place("minecraft:obsidian", "down", false)
			T:forward(1)
		end
		T:go("C2", false, 0, false, R.useBlockType)
	end

	function lib.buildLayer()
		T:place("minecraft:obsidian", "down", false)
		for i = 1, R.length - 1 do -- R.length = 4: forward when i=1,2,3
			T:forward(1)
		end
		T:place("minecraft:obsidian", "down", false)
	end

	R.useBlockType = T:getMostItem("obsidian", true) -- exclude obsidian from count
	if R.data ~= "bury" then
		T:up(1)
	end
	if R.side == "F" then
		T:go("F1R1")
	end
	local out = true
	for width = 1, R.width do
		lib.buildBase()
		for i = 1, R.height - 2 do
			T:go("R2U1")
			out = not out
			lib.buildLayer()
		end
		T:go("R2U1")
		out = not out
		lib.buildBase()
		if out then
			T:go("R2F"..R.length - 1)
		end
		if width < R.width then
			T:go("R1F1D"..R.height.."R1")
			out = true
		else
			T:go("L1F"..R.width.."D"..R.height - 1 .."R2")
			if R.data ~= "bury" then
				T:down(1)
			end
		end
	end

	return {}
end

function createPortalPlatform()
	--[[ Used in End World to use a trapdoor to push player through portal ]]
	local lib ={}

	-- function lib.findPortal()
		-- local found = false
		-- local onSide = false
		-- for i = 1, 64 do
			-- if not turtle.up() then -- hit block above
				-- found = true
				-- break
			-- end
		-- end
		-- if found then
			-- -- are we under the centre block, or one of the sides?
			-- if turtle.detect() then -- under a side
				-- onSide = true
			-- else	-- nothing in front, probably under centre, or facing wrong direction so check
				-- for i = 1, 4 do
					-- turtle.turnRight()
					-- if turtle.detect() then
						-- onSide = true
						-- break
					-- end
				-- end
			-- end
			-- if onSide then-- move to centre
				-- T:go("D1F1")
			-- end
		-- end
		-- local height = 3 -- allows for 2 bedrock + starting space
		-- while turtle.down() do
			-- height = height + 1
		-- end
		-- return found, height
	-- end

	function lib.addFloor(length)
		for i = 1, length do
			if i < length then
				T:go("C2F1", false, 0, true)
			else
				T:go("C2", false, 0, true)
			end
		end
	end

	function lib.buildLadder(height)
		for i = 1, height do
			--T:go("F1C1 R1C1 L2C1 L1F1L2", false, 0, true)
			T:go("F1C1 R1C1 L2C1 R1", false, 0, true)
			utils.goBack(1)
			if i > 3 then
				T:go("C2")
			end
			T:place("minecraft:ladder", "forward", true)
			T:up(1)
		end
	end

	--local found, height = lib.findPortal()
	--if found then	-- position under centre of beacon
		-- build ladder up and create platform
		T:go("L1F1L1F2L2")
		--T:checkInventoryForItem({"minecraft:ladder"},{height})
		--T:checkInventoryForItem({"stone"},{height * 4 + 18})
		--T:checkInventoryForItem({"trapdoor"},{1})
		lib.buildLadder(R.height) -- ends facing ladder, 1 block above

		T:go("R1")
		utils.goBack(1)
		T:go("C2F1 C2F1 C2F1 C2")
		T:go("R1F1R1")
		T:go("C2F1 C2F1 C2F1 C2")
		utils.goBack(2)
		T:go("R1F1")			-- facing portal entrance
		T:place("trapdoor", "up", false)
	--else
		--return {"Portal not found. Move me under","the centre if possible.", "wait for purple beacon."}
	--end
	return {}
end

function createSafeDrop()
	-- dig down R.height blocks, checking for blocks on all sides
	local drop = 0
	menu.colourPrint("Wait for my return!", colors.yellow)
	R.height = math.abs(R.upperLevel - R.lowerLevel)	-- eg 64 - -59 = 123
--Log:saveToLog("createSafeDrop(): R.height = "..R.height, true)
	for i = 1, R.height do				-- assume turtle is at foot level
		if i > 2 then					-- start placing blocks when below ground level
			for j = 1, 4 do
				-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
				T:go("C1R1", false, 0, true)
			end
		end
		--if i < R.height then
			if T:down(1) then
				 drop = drop + 1
			else
				break
			end
		--end
		if T:isWaterOrLava("up") ~= "" then
			T:go("C0x0", false, 0, false) -- delete water/ lava block
		end
	end
	local blockType = T:getBlockType("down")
	if blockType:find("bedrock") ~= nil then	-- at bedrock
		T:go("C1R1 C1R1 C1R1 C1R1 U1", false, 0, true )
	else
--Log:saveToLog("createSafeDrop(): drop = "..drop.." blocks")
		T:go("D1 C1R1 C1R1 C1R1 C1R1 U1")
		drop = drop + 1
	end
	T:placeWater("down")
	T:go("R2 x1U1 x1 R2")
	drop = drop - 2
	T:up(drop)

	return {"Safe drop completed "..drop + 2 .. " blocks"}
end

function createSinkingPlatform()
	local lib = {}

	function lib.stage1a()							-- build side wall left side
		for l = 1, R.length do 						--            | |*| |
			T:go("L1C1 R1C2", false, 0, false)		-- |*|>| | to |*|>| | place left wall
			if l == 1 then							-- first iteration
				T:go("U1C2 D1 F1C2", false, 0, false)-- |*|>| | to |*|*|>| up/down block to delete source at corner
			elseif l < R.length then				-- mid run
				T:go("F1C2", false, 0, false)		-- |*|>| | to |*|*|>| move forward
			else									-- end of run
				T:go("C1U1 C2D1", false, 0, false)	-- |*|>| | to |*|>|*| place end wall
			end
		end
	end

	function lib.stage1b()							-- same as stage1a on right side
		for l = 1, R.length do
			T:go("R1C1 L1C2", false, 0, false)
			if l == 1 then
				T:go("U1C2 D1 F1C2", false, 0, false)
			elseif l < R.length then
				T:go("F1C2", false, 0, false)
			else
				T:go("C1U1 C2D1", false, 0, false)
			end
		end
	end

	function lib.stage2(forward)
		if forward then
			T:go("C1R1 F1L1 C1R2", false, 0, false)
		else
			T:go("C1L1 F1R1 C1L2", false, 0, false)
		end
	end

	local forward = true
	local goingRight = true
	local blockType = T:getBlockType("down")
	if blockType:find("water") ~= nil or blockType:find("lava") ~= nil then
		T:up(1)
	end
	for h = 1, R.height do						-- repeatedly create a platform, move down and repeat
		T:down(1) 								-- move down into existing platform
		if goingRight then 						-- first side
			if forward then						-- complete left side
				T:go("R2C1 L2", false, 0, false) -- | |>| | to |*|<| | to |*|>| |
				lib.stage1a()					-- build left wall
				T:go("R1F1 L1C1 R2C2", false, 0, false)			-- turn ready for next side
			else
				T:go("L2C1 R2", false, 0, false) -- block 1, 1
				lib.stage1b(R)					-- turn ready for next side
				T:go("L1F1 R1C1 L2C2", false, 0, false)
			end
		else 									-- on right side so different approach
			if forward then
				T:go("L2C1 R2", false, 0, false) -- | |<| | to | |>|* | to | |<|*|
				lib.stage1b()
				T:go("C1L1 F1R1 C1L2 C2", false, 0, false)		-- turn ready for next side
			else								-- complete left side
				T:go("R2C1 L2", false, 0, false) -- block 1, 1
				lib.stage1a()					-- turn ready for next side
				T:go("C1R1 F1L1 C1R2 C2", false, 0, false)
			end
		end
		forward = not forward					-- continue strips across until at far edge
		for w = 1, R.width - 2 do
			for l = 1, R.length do
				if l < R.length then
					T:go("C2F1", false, 0, false)
				else
					T:go("C2", false, 0, false)
				end
			end
			if goingRight then
				lib.stage2(forward)
			else
				lib.stage2(not forward)
			end
			forward = not forward
		end										-- far side
		if goingRight then
			if forward then
				lib.stage1b()
			else
				lib.stage1a()
			end
		else
			if forward then
				lib.stage1a()
			else
				lib.stage1b()
			end
		end
		goingRight = not goingRight
		T:turnRight(2)
		forward = not forward
	end
	return {}
end

function createStaircase()
	-- using slabs NOT stairs
	-- start in centre column of staircase
	-- go down from current level to requested level, then build outer wall upwards if in water or lava
	-- or go up from current level
	-- at top build slabs downwards, deleting water/lava if required
	-- turtle.place() slab stays at ground level, whether block present or not
	-- turtle.placeDown() if block below, places on top of block, else directly below turtle
	-- starting position
	--  |S|S|S| in air / solid ground
	--  |S|T|S|
	--  |S|S|S|


	--	| |*|*|*| | in water or lava
	--  |*|S|S|S|*|
	--  |*|S|T|S|*|
	--  |*|S|S|S|*|
	--	| |*|*|*| |

	local lib = {}

	function lib.isFluid()
		-- check if water or lava present
		local blockType = T:getBlockType("forward")
	--Log:saveToLog("lib.isFluid() blockType (forward) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then	-- liquid found, return position
			return true
		end
		blockType = T:getBlockType("up")
	--Log:saveToLog("lib.isFluid() blockType (up) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then
			return true
		end

		blockType = T:getBlockType("down")
	--Log:saveToLog("lib.isFluid() blockType (down) = "..blockType)
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then
			return true
		end

		T:turnLeft(1)
		blockType = T:getBlockType("forward")
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then	-- liquid found, return position
			T:turnRight(1)
			return true
		end

		T:turnRight(1)
		blockType = T:getBlockType("forward")
		if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then	-- liquid found, return position
			T:turnLeft(1)
			return true
		end

		return false
	end

	function lib.addSlabs()
		-- starting position in corner facing pevious steps on left side
		T:go("U1R1")
		T:place("slab", "down")			-- place corner step
		--T:go("B1L1 C1R1 B1")
		T:go("B2")
		T:place("slab", "forward")		-- place centre step, wall 1
	end

	function lib.cutDrain(height)
		if height == 3 then
			-- remove all blocks in this area
			T:go("x0x2 F1 x0x2 F1 x0x2 R1")	-- ends NE corner face S: |*|*|v| 3
			T:go("x0x2 F1 x0x2 F1 x0x2 R1")	-- ends SE corner face W: |W|W|<| 1
			T:go("x0x2 F1 x0x2 F1 x0x2 R1")	-- ends SW corner face N: |^|*|*| 1
			T:go("x0x2 F1 x0x2 F1R1")			-- ends NW corner face E: |>|*|*| 3
		elseif height == 2 then
			T:go("x0F1 x0F1 x0R1")			-- ends NE corner face S: |*|*|v| 3
			T:go("x0F1 x0F1 x0R1")			-- ends SE corner face W: |W|W|<| 1
			T:go("x0F1 x0F1 x0R1")			-- ends SW corner face N: |^|*|*| 1
			T:go("x0F1 x0F1 R1")				-- ends NW corner face E: |>|*|*| 3
		elseif height == 1 then
			T:go("F2R1 F2R1 F2R1 F2R1")
		end
	end

	function lib.buildRectangle(width, length, height)
		-- used to build outer wall in water / lava with width/length  = 5 * 5
		-- also inner wall 3 * 3
		width = width -1
		length = length -1
		if height == 3 then
			for w = 1, width do
				T:go("C0C2F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for l = 1, length do
				T:go("C0C2F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for w = 1, width do
				T:go("C0C2F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for l = 1, length do
				T:go("C0C2F1")
			end
			T:turnLeft(1)	-- ends NW corner face W: |<|*|...  has blocks above and below
		elseif height == 2 then
			for w = 1, width do
				T:go("C0F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for l = 1, length do
				T:go("C0F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for w = 1, width do
				T:go("C0F1")
			end
			T:go("R1")	-- ends NE corner face S: |*|*|v| 3
			for l = 1, length do
				T:go("C0F1")
			end
			T:turnLeft(1)	-- ends NW corner face W: |<|*|...  has blocks above and below
		elseif height == 1 then
			T:go("F"..width.."R1 F"..length.."R1 F"..width.."R1 F"..length + 1 .."L1")	-- ends NE corner face S: |*|*|v| 3
		end
		for w = 1, width do
			T:go("B1C1")
		end
		T:turnRight(1)
		for l = 1, length do
			T:go("B1C1")
		end
		T:turnRight(1)
		for w = 1, width do
			T:go("B1C1")
		end
		T:turnRight(1)
		for l = 1, length do
			T:go("B1C1")
		end
		--T:turnLeft(1)
		--T:go("R2F1R1")
		-- ends NE corner face E: |>|*|... with block above and below
	end

	function lib.buildWaterBlock(drainHeight)
		T:go("L1F1 L1F1R2")					--	|>| | | | | row 5 in water or lava
		lib.buildRectangle(5, 5, drainHeight)
		T:go("L1F1 R1F1 L2C1 R1")			--      |*|>|*|... row 4 in water or lava
		lib.buildRectangle(3, 3, drainHeight)
		T:go("L1")
		lib.cutDrain(drainHeight)
	end

	function lib.clearCore()
		-- start at top and work down to remove all blocks in 3x3x3 area
		-- delete water/lava as you go
		-- clearance includes layer above and below turtle current level
		-- starting position:
		--  |>|S|S| in air / solid ground
		--  |S|S|S|
		--  |S|S|S|
--Log:saveToLog("lib.clearCore() starting")

		local remaining = R.height - 2					-- -2 as already 2 blocks below top
		local drainHeight = math.min(3, remaining)		-- 3 unless very shallow
		while remaining > 0 do
			if lib.isFluid() then						-- water or lava present
				lib.buildWaterBlock(drainHeight)
			else
				lib.cutDrain(drainHeight)
			end
--Log:saveToLog("lib.clearCore() remaining = "..remaining)
			if remaining > 3 then
				T:down(3)
				drainHeight = 3
				remaining = remaining - 3
			elseif remaining == 3 then					-- 3 blocks from base, turtle at 4 blocks above
				T:down(3)								-- turtle 1 block above base. fixes layer above and below
				if lib.isFluid() then					-- water or lava present
					lib.buildWaterBlock(3)
				else
					lib.cutDrain(3)
				end
				break									-- turtle ends at ground level
			elseif remaining == 2 then					-- 2 blocks from base, turtle at 3 blocks above
				T:down(2)								-- turtle at ground level, fixes layer above only
				if lib.isFluid() then					-- water or lava present
					lib.buildWaterBlock(2)
				else
					lib.cutDrain(2)
				end
				break									-- turtle ends at ground level
			elseif remaining == 1 then					-- 1 blocks from base, turtle at 3 blocks above
				T:down(1)								-- at base level
				if lib.isFluid() then					-- turtle already at ground level, fixes this layer only
					lib.buildWaterBlock(1)
				else
					lib.cutDrain(1)
				end
				break
			end
		end
	end

	-- R.startLevel and R.destinationLevel set in taskInventory.lua
	-- R.auto = stop at stronghold/trial chamber
	-- R.startLevel eg 64 at top (R.goDown = true) or 5 at bedrock, R.goUp = true
	-- R.lowerLevel = bottom of ladder
	-- R.upperLevel = top of ladder

	R.height = math.abs(R.upperLevel - R.lowerLevel)
	R.currentLevel = R.startLevel	-- eg 64 going down
	R.useBlockType = T:getMostItem("slab", true) -- exclude slab, use stone only/netherrack
--Log:saveToLog("Creating staircase "..R.height.." blocks", true)
--Log:saveToLog("tk3.createStaircase() starting; R.up = "..tostring(R.up).."R.down = "..tostring(R.down)
			   --.."R.startLevel = "..R.startLevel.."R.destinationLevel = "..R.destinationLevel..", R.height = "..R.height)

	local success, numBlocks, errorMsg, blockType = true, 0, "", ""
	if R.down then -- go down towards bedrock
		local atBedrock = false
		for i = 1, R.height do
			success, numBlocks, errorMsg, blockType = T:down(1, true) -- true = return blockType
			if success then
				R.currentLevel = R.currentLevel - 1
				if R.auto then
					if blockType:find("stone_bricks") ~= nil then
						table.insert(retValue, "Stronghold discovered")
						break -- stop descent at stronghold
					end
					if blockType:find("polished_tuff") ~= nil or blockType:find("tuff_bricks") ~= nil then
						table.insert(retValue, "Trial chamber discovered")
						break -- stop descent at trial chamber
					end
				end
			else
				atBedrock = true
				break
			end
		end
		if atBedrock then -- hit bedrock so get to level 5 / -59
			R.currentLevel = T:findBedrockTop(R.currentLevel)
			T:go("R1F1R1", false, 0, true)
		end
		-- re-calculate start and destination levels
		R.destinationLevel = R.startLevel
		R.startLevel = R.currentLevel
		R.height = math.abs(R.upperLevel - R.lowerLevel)
	end
	-- start from lowerLevel
	for i = 1, R.height do
		T:up(1)
		if not T:place(R.useBlockType, "down") then
			T:place("stone", "down")
		end
	end
	-- moved to top, placing blocks below for central column
	local isFluid = lib.isFluid()
	while isFluid do		-- continue upwards until out of water/lava
		T:up(1)
		if not T:place(R.useBlockType, "down") then
			T:place("stone", "down")
		end
		R.height = R.height + 1
		isFluid = lib.isFluid()
	end
	-- now at top in air or solid blocks
	-- cut a square pipe round central column
	T:go("F1L1 F1R2 D2")		--  |>| | |  > = turtle facing E
								--  | |X| |  X = core
								--  | | | |
	lib.clearCore()
	T:go("R1x2 F2D1 x2L1")		--  | | | |
								--  | |X| |  X = core
								--  |>| | |  > = turtle facing E top at ground level
	while R.currentLevel < R.destinationLevel do
		lib.addSlabs()
		R.currentLevel = R.currentLevel + 1
	end

	return{"Staircase completed"}
end

function createTrialCover()
	local lib = {}

	function lib.isSpawner()
		local blockType = T:getBlockType("down")
		if blockType:find("spawner") ~= nil then
			return true, "top", ""
		end
		blockType = T:getBlockType("up")
		if blockType:find("spawner") ~= nil then
			return true, "bottom", ""
		end
		blockType = T:getBlockType("forward")
		if blockType:find("spawner") ~= nil then
			return true, "forward", blockType
		end
		return false, "", blockType	-- block ahead always returned. Allows mushroom checking
	end

	function lib.findSpawner()
		local moves  = 0
		local wallCleared = false
		local quit = false
		-- assume turtle placed facing trial spawner
		print("Checking if next to spawner")
		local found, position, blockType = lib.isSpawner() -- true/false, top/bottom/nil
		while not found and not quit do -- move forward towards spawner
			print("Not close to spawner")

			if blockType:find("mushroom") ~= nil then
				turtle.dig()
				blockType = ""
			elseif blockType ~= "" then
				if wallCleared then
					quit = true
					break
				else	-- could be behind a wall
					print("Assuming spawner behind a wall")
					turtle.dig()
					blockType = ""
					wallCleared = true
				end
			end
			turtle.forward()
			moves = moves + 1
			if moves > 32 then
				quit = true
			end
			found, position, blockType = lib.isSpawner() -- true/false, top/bottom/nil
		end
		if not found or quit then
			T:go("R2F"..moves + 2 .."R2")
		end

		return found, position
	end


	function lib.front()
		-- in mid right side facing left | | |<|
		T:go("C0C2 F1 C0C2 F1 C0C2")
		T:go("B1C1 B1C1 B1C1")
		-- ends outside mid right side facing left | | | |<
	end

	function lib.sides()
		-- on mid left side of a 3 x 3 square, facing right
		T:go("C0C2 F1 C0C2 F1 C0C2 F1L1 F1")
		T:go("C0C2 F1 C0C2 F1 C0C2 F1L1 F1")
		T:go("C0C2 F1 C0C2 F1 C0C2")
		T:go("B1C1 B1C1 B1C1")
		T:go("R1B1")
		T:go("B1C1 B1C1 B1C1")
		T:go("R1B1")
		T:go("B1C1 B1C1 B1C1")
		-- ends on mid right of front facing back
	end

	function lib.floor()
		-- start in floor left corner 3 x 3 facing back
		T:go("C2F1 C2F1 C2R1")	-- floor round spawner lowered by 1 block, facing player
		T:go("F1 C2F1 C2R1")
		T:go("F1 C2F1 C2R1")
		T:go("F1C2 B1R1 F1R1")
	end

	R.useBlockType = T:getMostItem("", false) -- use whatever block type available
	local found, position = lib.findSpawner() -- move forwards until meet Spawner, go through wall if present
	if not found then --outside dungeon
		return {"Trial spawner not found"}
	end
	-- move to face spawner, 1 block gap
	if position == "top" then
		T:go("B2D1")
	elseif position == "forward" then
		T:go("B1")
	else
		T:go("B2U1")
	end
	T:go("R1F1R2")				-- ends in right side of 3 x 3 face, looking left | | |<|
								-- starts with wall across spawner
	lib.front()					-- ends in right side of 3 x 3 face, looking left | | | |<
	T:go("R1F1")				-- in position to start sides
	lib.sides()					-- end right of mid front panel, facing rear
	T:go("U1F1 L1F1 R2C1 L1")	-- end top right corner under ceiling, facing rear
	T:go("C0F1 C0F1 C0L1 F1L1 C0F1 C0F1 C0R1 F1R1 C0F1 C0F1 C0") -- ceiling placed. end outside top right corner, facing left
	T:go("R1D2")				-- on top of new floor level
	lib.floor()					-- end facing player, on new floor, block ahead
	T:go("F1C2 F1D1 C2U1 R2")	-- break through, fix player block
	T:place("slab","down")		-- slab for player
	T:go("F1x0")				-- return to entrance, break block above
	T:place("slab","up")		-- reduce exit height
	R.auto = true				-- ready for continuous attack
	attack("forward")
	return {}
end

function createFence()
	R.width = 0
	return createEnclosure()
end

function deactivateDragonTower()
	-- go up centre of tower to bedrock
	local height = 0
	--numBlocksMoved, errorMsg = clsTurtle.doMoves(self, numBlocksRequested, direction)
	local numBlocks, message = T:doMoves(1, "up")
	while message == nil do
		numBlocks, message = T:doMoves(1, "up")
		height = height + 1
		if height > 100 then	 -- climbed too high
			T:down(height)
			return{"Tower top not found"}
		end
	end
	-- go round bedrock and destroy crystal
	--T:go("F1R2U2x1U1x1")
	T:go("F2R2U2")
	turtle.attack() -- mc 1.20+ crystals can be attacked, not dig
	turtle.dig()
	turtle.up()
	turtle.attack() -- mc 1.20+ crystals can be attacked, not dig
	turtle.dig()
	turtle.forward()
	turtle.attack() -- mc 1.20+ crystals can be attacked, not dig
	turtle.dig()
	-- return to start
	T:down(height + 5)
	return {}
end

function demolishPortal()
	--[[
	R.length = length of portal NOT width default 4
	R.height = height of portal default 5
	R.width = thickness of portal default 1
	R.data = "bury" if embedded base in ground
	R.side = "F" facing portal, "E" = aligned with side
	]]
	local data = R.data
	if R.side == "F" then -- facing portal
		T:go("F"..R.width.."R1")
	else
		T:forward(1)
	end
	if R.data == "bury" then
		T:down(1)
	end

	R.data = "up"
	R.silent = true
	if R.width == 1 then
		clearWall()
	else
		clearBuilding(true, true)
	end
	if data == "bury" then
		T:up(1)
	end
	if R.side == "F" then -- facing portal
		T:go("R1F1L1F1L1")
	end

	return {}
end

function earlyExit(message)
	return {message}
end

function findPortal()
	-- Called from TaskOptions:executeCall(key, value) key = "findPortal", value = "inventory"
	local found = false
	local onSide = false
	sm:getSceneByName("TaskOptions"):setInfo("Checking height. Please wait...")
	for i = 1, 64 do
		if not turtle.up() then -- hit block above
			found = true
			break
		end
	end
	if found then
		-- are we under the centre block, or one of the sides?
		if turtle.detect() then -- under a side
			onSide = true
		else	-- nothing in front, probably under centre, or facing wrong direction so check
			for i = 1, 4 do
				turtle.turnRight()
				if turtle.detect() then
					onSide = true
					break
				end
			end
		end
		if onSide then-- move to centre
			T:go("D1F1")
		end
	end
	R.height = 3 -- allows for 2 bedrock + starting space
	while turtle.down() do
		R.height = R.height + 1
	end
	local inventory = nil
	if found then
		inventory =
		{
			{"minecraft:ladder", R.height, true, ""},
			{"stone", R.height * 4 + 18, true, ""},
			{"trapdoor", 1, true, ""}
		}
	end
	F["createPortalPlatform"].inventory = inventory
	sm:getSceneByName("TaskOptions"):setInfo("Height = "..R.height..", Click 'Next' or type 'n'")
	return inventory
end

function findSeabed()
	-- Called from TaskOptions:executeCall(key, value) key = "findSeabed", value = "inventory"
	sm:getSceneByName("TaskOptions"):setInfo("Checking water depth. Please wait...")
	R.depth = 0
	while utils.clearVegetation("down") do		-- go down to sea bed
		T:go("x1D1")							-- make sure area in front is clear, go down
		R.depth = R.depth + 1						-- increment counter
	end
	T:up(R.depth)
	local inventory =
	{
		{"door", math.floor(R.depth / 3) , true, ""},
		{"dirt", math.floor(R.depth / 3), true, ""},
	}
	F["createDiveColumn"].inventory = inventory
	sm:getSceneByName("TaskOptions"):setInfo("Depth = "..R.depth..", Click 'Next' or type 'n'")
	return inventory
end

function floodArea()
	-- flood a rectangular area R.width * R.length * R.depth
	-- use 3 water buckets repeatedly along 2 edges, starting at the bottom
	local lib = {}

	function lib.checkStartPosition()
		-- need to be on floor or R.height if specified
		local depth = 0
		local blockType = T:getBlockType("down")

		if blockType:find("water") == nil then -- on at least level 0
			T:forward(1)
		end
		while turtle.down() do
			depth = depth + 1
		end

		return depth
	end

	function lib.fillBuckets(count)
		T:forward(2)
		utils.fillBucket("forward", count)
	end

	function lib.placeSources()
		local continue = true
		for i = 1, 4 do
			if turtle.back() then
				T:place("water", "forward")
			else
				continue = false
				break
			end
		end
		return continue
	end

	if R.forward then
		T:forward(1)
	end

	depth = lib.checkStartPosition()	-- go to bottom of pool area
	if R.depth == 0 then				-- if not already specified use full depth of travel
		R.depth = depth
	end

	T:turnRight(2)						-- facing start
	for d = 1, R.depth do
		lib.placeSources()				-- 4 source blocks placed
		lib.fillBuckets(4)
		while lib.placeSources() do
			lib.fillBuckets(4)
		end
		lib.fillBuckets(count)			-- recharge before turning
		while turtle.back() do end
		T:turnRight(1)
		while lib.placeSources() do
			lib.fillBuckets(4)
		end
		T:go("F1R2")					-- ready to place final source
		T:place("water", "forward")
		T:turnRight(2)					-- turn to sources
		lib.fillBuckets(4)				-- ready to move to next level
		T:go("R2U1 F1L1")				-- up to next level, facing wall
	end

	return {"Area "..R.width.." * "..R.length.." * "..R.depth.." flooded"}
	-- ready for next layer
end

function makeMud()
	--[[
	1 empty bottle
	up to 14 stacks of dirt
	water source below
	]]
	local bottleSlot = T:getItemSlot("bottle")					-- is empty bottle in inventory
	local dirtSlot = T:getItemSlot("minecraft:dirt")			-- get first dirt slot

	local lib = {}
	function lib.convertDirt()
		turtle.select(dirtSlot)									-- select slot
		turtle.place()											-- place forward
		turtle.select(bottleSlot)								-- select water bottle
		turtle.place()											-- turn dirt into mud
		turtle.placeDown()										-- refill bottle
		turtle.dig()											-- dig mud block
	end

	if R.misc then
		if bottleSlot > 0 then										-- found empty bottle
			turtle.select(bottleSlot)								-- select empty bottle
			turtle.placeDown()										-- fill from water source below
		else
			bottleSlot = T:getItemSlot("potion")					-- bottle may already contain water
			if bottleSlot == 0 then									-- no bottle or potion present
				return {"Unable to locate bottle or water bottle"}
			end
		end
	end

	local mudCount = 0
	local mudRequired = 0
	if R.misc then												-- make mud
		if R.size == 0 then
			mudRequired = 896										-- 14 full slots
		else
			mudRequired = R.size
		end
		while dirtSlot > 0 do
			while turtle.getItemCount(dirtSlot) > 1 do				-- use all but 1 dirt in the slot
				lib.convertDirt()
				mudCount = mudCount + 1
				if mudCount >= mudRequired then
					break
				end
			end
			lib.convertDirt()										-- place and convert last one. It may then contain mud
			mudCount = mudCount + 1
			if mudCount >= mudRequired then
				break
			end
			dirtSlot = T:getItemSlot("minecraft:dirt")				-- any more dirt?
		end
	end
	if R.auto then													-- manage clay
		-- 1. mud/clay already present
		-- 2. no mud/clay present
		-- collect existing clay and place new mud
		T:forward(2)
		local forward = true
		for w = 1, 10 do
			for l = 1, 10 do
				local blockBelow = T:getBlockType("down")
				if blockBelow:find("clay") ~= nil then
					turtle.select(1)
					turtle.digDown()
					blockBelow = ""
				end
				if blockBelow == "" then
					T:place("mud", "down")
				end
				if l < 10 then
					turtle.forward()
				end
			end
			if w < 10 then
				if forward then
					T:go("R1F1R1")
				else
					T:go("L1F1L1")
				end
				forward = not forward
			end
		end
		T:go("R1F9 L1F2 R2")
	end
	return {"Mud and clay management completed"}
end

function measure()
	-- measure height/ depth / length
	-- R.dimension = "height", "depth", "length", "deepest"
	local doContinue = true
	local message = ""
	local blocks = 1
	local method = ""
	local measure = ""

	local lib = {}

	function lib.checkBlocks(blocks)
		blocks = blocks + 1
		doContinue = true
		if blocks > R.size then
			message = "Max "..R.dimension.." of "..R.size.." stopped measurement"
			measure = ""
			doContinue = false
		else
			measure = R.dimension.." measured: "..blocks.." blocks"
		end
		return doContinue, blocks, measure, message
	end

	if R.dimension == "height" then				-- height
		R.size = 64								-- catch-all to prevent going to the top of the world
		if R.subChoice == 1 then				-- obstruction above
			method = "Method: Until obstruction above"
			while turtle.up() and doContinue do
				doContinue, blocks, measure, message = lib.checkBlocks(blocks)
			end
		elseif R.subChoice == 2 then			-- end of blocks in front of turtle eg cliff, wall
			method = "Method: Until no block detected in front"
			while turtle.detect() do
				if turtle.up() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
				else
					message = "Obstruction above stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		elseif R.subChoice == 3 then	-- search for specific block min 3 characters
			method = "Method:Until search: '"..R.data.."' met"
			while turtle.detect() and doContinue do
				if turtle.up() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
					if doContinue then
						local blockType = T:getBlockType("forward")
						if blockType:find(R.data) ~= nil then
							measure = "Height measured: "..blocks.." blocks"
							message = "Found "..blockType
							doContinue = false
						end
					end
				else
					message = "Obstruction above stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		elseif R.subChoice == 4 then	-- When block above changes eg dragon tower height
			local blockType = T:getBlockType("up")
			local compare = blockType
			method = "Method: Until "..blockType.." changes"
			while blockType == compare and doContinue do
				T:up(1)
				doContinue, blocks, measure, message = lib.checkBlocks(blocks)
				if doContinue then
					blockType = T:getBlockType("up")
				end
			end
			measure = "Height measured: "..blocks.." blocks"
			message = "Found "..blockType
		end

		for i = 1, blocks do
			turtle.down()
		end
	elseif R.dimension == "depth" then	-- depth
		-- check if already over air
		local moved = false
		if turtle.detectDown() then
			T:forward(1)
			moved = true
		end
		T:go("R2D1") -- go off the edge and face cliff/pit wall
		blocks = blocks + 1
		if R.subChoice == 1 then		-- obstruction water / lava below
			local move = true
			while move do
				local blockType = T:getBlockType("down")
				if blockType:find("water") ~= nil or blockType:find("lava") ~= nil then
					message1 = blockType.." found at "..blocks
					move = false
				else
					move = turtle.down()
					if move then
						blocks = blocks + 1
					else
						measure = "Depth measured: "..blocks.." blocks"
					end
				end
			end
			method = "Method: Until obstruction below"
		elseif R.subChoice == 2 then	-- end of wall in front`
			while turtle.detect() do
				if turtle.down() then
					blocks = blocks + 1
					measure = "Depth measured: "..blocks.." blocks"
				else
					message1 = "Obstruction below stopped measurement"
					break
				end
			end
			method = "Method: Until no block detected ahead"
		elseif R.subChoice == 3 then	-- specific block detected ahead
			method = "Method:Until search: '"..R.data.."' met"
			while turtle.detect() do
				if turtle.down() then
					blocks = blocks + 1
					local blockType = T:getBlockType("forward")
					if blockType:find(R.data) ~= nil then
						measure = "Depth measured: "..blocks.." blocks"
						message = "Found "..blockType
						break
					end
				else
					message = "Obstruction below stopped measurement"
					break
				end
			end
		end
		for i = 1, blocks - 1 do
			turtle.up()
		end
		if moved then
			T:go("F1")
		end
		T:go("R2")
	elseif R.dimension == "length" then	-- length
	--Log:saveToLog("R.dimension == "..R.dimension..", R.subChoice  = "..R.subChoice)
		if R.subChoice == 1 then		-- obstruction ahead
			method = "Method: Until obstruction ahead"
			while turtle.forward() and doContinue  do
				doContinue, blocks, measure, message = lib.checkBlocks(blocks)
			end
		elseif R.subChoice == 2 then	-- end of ceiling above
			method = "Method: Until no block detected above"
			while turtle.detectUp() and doContinue do
				if turtle.forward() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
				else
					message = "Obstruction ahead stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		elseif R.subChoice == 3 then	-- end of floor below
			method = "Method: Until no block detected below"
			while turtle.detectDown() and doContinue do
				if turtle.forward() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
				else
					message = "Obstruction ahead stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		elseif R.subChoice == 4 then	-- search for specific block up min 3 characters
			method = "Method:Until search: '"..R.data.."' above met"
			while turtle.detectUp() and doContinue do
				if turtle.forward() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
					if doContinue then
						local blockType = T:getBlockType("up")
						if blockType:find(R.data) ~= nil then
							message = "Found "..blockType
							measure = "Length measured: "..blocks.." blocks"
							doContinue = false
						end
					end
				else
					message = "Obstruction ahead stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		elseif R.subChoice == 5 then	-- search for specific block down min 3 characters
			method = "Method:Until search: '"..R.data.."' below met"
			--while turtle.detectDown() and doContinue do
			while doContinue do
				if turtle.forward() then
					doContinue, blocks, measure, message = lib.checkBlocks(blocks)
					if doContinue then
						local blockType = T:getBlockType("down")
						if blockType:find(R.data) ~= nil then
							message = "Found "..blockType
							measure = "Length measured: "..blocks.." blocks"
							doContinue = false
						end
					end
				else
					message = "Obstruction ahead stopped measurement"
					measure = ""
					doContinue = false
				end
			end
		end
		T:turnRight(2)	-- head home
		for i = 1, blocks do
			turtle.forward()
		end
		T:turnRight(2)
	elseif R.dimension == "deepest" then	-- depth of stretch of water
		--R.length = 0 to auto calculate
		R.width = 1
		R.silent = true
		R.useBlockType = ""
		R.data = "clearWaterPlants"
		local data = clearWaterPlants()
		R.height = data[1]
		local length = data[2]
		T:go ("R2F"..length - 1 .."R2U1")
		return {R.height, "Greatest depth measured: ".. R.height, "Width of water: "..R.length}
	end
	return{blocks, method, measure, message}
end

function measureDeepest()
	return measure()
end

function measureDepth()
	return measure()
end

function measureHeight()
	return measure()
end

function measureLength()
	--Log:saveToLog("measureLength() called")
	return measure()
end

function oceanMonumentColumns()
	-- utility to find corners and build columns to surface
	local lib = {}

	function lib.buildColumn()
		local depth = 0
		while T:isWater("forward") do
			T:go("U1C2")
			depth = depth + 1
		end
		return depth
	end

	function lib.buildTower()
		T:go("F1C2 F1C2 F1C2")
		T:go("L1F1 L1C2 F1C2 F1C2 F1C2")
		T:go("R1F1 R1C2 F1C2 F1C2 F1C2")
		T:go("L1F1 L1C2 F1C2 F1C2 F1C2")

		T:go("R2")
		for i = 1, 4 do
			T:go("U1C2")
			for j = 1, 4 do
				T:go("F1C2 F1C2 F1C2 R1")
			end
		end
	end

	R.silent = true
	local blockType = T:getBlockType("down")
	while blockType:find("water") == nil do
		T:down(1) -- if on a platform will break through
		blockType = T:getBlockType("down")
	end
	--R.useBlockType = "prismarine", R.data = "oceanMonumentColumns" from getTask
	--local tempData = R.data
	--R.data = "clearWaterPlants"
	local result = clearWaterPlants()[1]	-- should be {""} -> ""
	if result ~= "" then
		return {result}
	else
		--on corner of monument, facing out to ocean
		local depth = lib.buildColumn()
		-- now above surface, block below at surface level
		for i = 1, 4 do
			T:turnRight(1)
			R.length = 57
			createPath() -- roughly at next corner
			if i < 4 then
				T:down(depth-2) -- roughly at correct depth
				local waterBelow = utils.clearVegetation("down")
				while waterBelow do
					T:down(1)
					waterBelow = utils.clearVegetation("down")
				end
				blockType = T:getBlockType("down")
				while blockType:find("prismarine") ~= nil do
					T:forward(1)
					blockType = T:getBlockType("down")
				end
				turtle.back()
				depth = lib.buildColumn()
			end
		end
		-- completed retaining paths. Build small tower for easy access
		lib.buildTower()
	end

	return {}
end

function placeRedstoneTorch()
	local moves = 2
	local blockType = T:getBlockType("down")
	if R.data == "level" then
		T:turnLeft(1)
		utils.goBack(1)
		if blockType:find("rail") ~= nil then
			 moves = 3
		end
		T:down(moves)
		T:go("F1R1")
		--clsTurtle.place(self, blockType, damageNo, direction, leaveExisting)
		T:place(R.useBlockType, "forward", false)
		utils.goBack(1)
		T:place("minecraft:redstone_torch", "forward", true)
		T:turnLeft(1)
		utils.goBack(1)
		T:up(moves)
		T:go("F1R1F1")
	elseif R.data == "up" then -- sloping rail up/down is relative to direction facing
		moves = 3
		T:turnLeft(1)
		utils.goBack(1)
		if blockType:find("rail") ~= nil then
			 moves = 4
		end
		T:down(moves)
		T:go("F1L1")
		T:place("minecraft:redstone_torch", "up", false)

		T:turnRight(1)
		utils.goBack(1)
		T:up(moves)
		T:go("F1R1")
	end
	return {}
end

function sandFillArea()
	-- clearRectangle with sand drop
	-- could be 1 wide x xx length (trench) up and return
	-- could be 2+ x 2+
	-- even no of runs return after last run
	-- odd no of runs forward, back, forward, reverse and return
	local success = false
	local maxMove = 2
	local directReturn = true
	if R.width % 2 == 1 then
		directReturn = false
	end
	while turtle.detectDown() and maxMove > 0 do
		T:forward(1)
		maxMove = maxMove - 1
	end
	if R.width == 1 then -- trench ahead, so fill then return
		for i = 1, R.length - 1 do
			success = utils.dropSand()
			T:forward(1, false)
		end
		success = utils.dropSand()
		T:go("R2F"..(R.length - 1).."R2", false, 0, false)
	else --2 or more columns
		if directReturn then -- R.width = 2,4,6,8 etc
			for i = 1, R.width, 2 do -- i = 1,3,5,7 etc
				-- move along R.length, dropping sand
				for j = 1, R.length - 1 do
					success = utils.dropSand()
					T:forward(1, false)
				end
				success = utils.dropSand()
				T:go("R1F1R1") --turn right and return on next column
				for j = 1, R.length - 1 do
					success = utils.dropSand()
					T:forward(1, false)
				end
				success = utils.dropSand()
				if i < R.width - 2 then -- eg R.width = 8, i compares with 6: 1, 3, 5, 7
					T:go("L1F1L1")
				end
			end
			T:go("R1F"..R.width - 1 .."R1") --return home
		else
			for i = 1, R.width, 2 do -- i = 1,3,5,7 etc
				-- move along R.length, dropping sand
				for j = 1, R.length - 1 do
					success = utils.dropSand()
					T:forward(1, false)
				end
				success = utils.dropSand()
				T:go("R1F1R1") --turn right and return on next column
				for j = 1, R.length - 1 do
					success = utils.dropSand()
					T:forward(1, false)
				end
				success = utils.dropSand()
				T:go("L1F1L1")
			end
			-- one more run then return
			for j = 1, R.length - 1 do
				success = utils.dropSand()
				T:forward(1, false)
			end
			success = utils.dropSand()
			T:go("R2F"..R.length.."R1F"..R.width - 1 .."R1")
		end
	end
	return {}
end

function test()
	-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	-- allows testing any new functions.
	-- use tk3 test
	Log:saveToLog("test() started", true)
	menu.clear()
    -- insert code below
    if T:place("chest", "down", false) then
        -- drop 2 x water if present
        -- T:dropItem(item, direction, keepAmount, except)
        T:dropItem("minecraft:water_bucket", "down") -- puts water buckets in first 2 slots
        T:dropItem("minecraft:water_bucket", "down")
        T:dropItem("slab", "down")
        T:emptyInventory("down") -- empty all supplied stone
    end
	--return {"function 'test' executed successfully"}
end

function test2()
	R.upperLevel = 106
	R.lowerLevel = 63

	local lib = {}

	function lib.addPipe()
		for j = 1, 4 do
			-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
			T:go("C1R1", false, 0, true)
		end
	end

	function lib.placeKelp()
		T:place("minecraft:kelp", "forward")
		T:up(1)
	end

	local drop = 0
	menu.colourPrint("Wait for my return!", colors.yellow)
	R.height = math.abs(R.upperLevel - R.lowerLevel)
	--Log:saveToLog("createBubbleColumn(): R.height = "..R.height, true)

	local atBedrock = false
	local blockType = T:getBlockType("down")
	for i = 1, R.height do
		if blockType:find("bedrock") == nil then	-- not at bedrock
			T:down(1)
			drop = drop + 1
			lib.addPipe()
			if i == 1 then
				T:placeWater("forward")
			end
			blockType = T:getBlockType("down")
		else 										-- at bedrock
			atBedrock = true
			break
		end
	end
	if atBedrock then
		T:up(1)
		drop = drop - 1
	else
		T:dig("down")
	end
	if not T:place("minecraft:soul_sand", "down") then
		T:place("minecraft:dirt", "down")
	end
	T:go("R2F1R2C2")
	lib.placeKelp()
	T:place("sign", "down", false, "UP!")
	lib.placeKelp()
	T:place("sign", "down", false, "GOING")
	for i = 1, drop - 2 do
		lib.placeKelp()
	end
	while turtle.down() do end	-- on top of signs
	T:go("F1D1x2 U1B1")			-- break kelp and move over it, down 1, break last piece, return to column
	for i = 1, drop - 2 do
		T:go("U1C2")
	end

	return {"Bubble column completed "..drop.. " blocks"}
end

function updateLists()
	U.updateList("barrel")
	U.updateList("chest")
	return {"lists: U.chestItems / U.barrelItems updated"}
end


end
