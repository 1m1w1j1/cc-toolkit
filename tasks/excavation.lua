return function(utils, pp, dbug, netherBedrock, deletesWater, brick)
function clearArea()
	local evenWidth = false
	local evenHeight = false
	local loopWidth
	-- go(path, useTorch, torchInterval, leaveExisting)
	if R.width % 2 == 0 then
		evenWidth = true
		loopWidth = R.width / 2
	else
		loopWidth = math.ceil(R.width / 2)
	end
	if R.length % 2 == 0 then
		evenHeight = true
	end
	turtle.select(1)
	-- clear an area between 2 x 4 and 32 x 32
	-- if R.width is even no, then complete the up/down run
	-- if R.width odd no then finish at top of up run and reverse
	-- should be on flat ground, check voids below, harvest trees
	for x = 1, loopWidth do
		-- Clear first column (up)
		for y = 1, R.length do
			if R.useBlockType == "dirt" then
				if not turtle.detectDown() then
					T:place("minecraft:dirt", "down", true)
				else --if not water, dirt, grass , stone then replace with dirt
					blockType = T:getBlockType("down")
					if blockType ~= "" then
						if blockType ~= "minecraft:dirt" and blockType ~= "minecraft:grass_block" then
							turtle.digDown()
							T:place("minecraft:dirt", "down", true)
						end
					end
				end
			end
			if y < R.length then
				T:go("F1+1", false,0,false)
			end
		end
		-- clear second column (down)
		if x < loopWidth or (x == loopWidth and evenWidth) then -- go down if on R.width 2,4,6,8 etc
			T:go("R1F1+1R1", false,0,false)
			for y = 1, R.length do
				if R.useBlockType == "dirt" then
					if not turtle.detectDown() then
						T:place("minecraft:dirt", "down", true)
					else
						blockType = T:getBlockType("down")
						if blockType ~= "" then
							if blockType ~= "minecraft:dirt" and blockType ~= "minecraft:grass_block" then
								turtle.digDown()
								T:place("minecraft:dirt", "down", true)
							end
						end
					end
				end
				if y < R.length then
					T:go("F1+1", false, 0, false)
				end
			end
			if x < loopWidth then
				T:go("L1F1+1L1", false,0,false)
			else
				T:turnRight(1)
				T:forward(R.width - 1)
				T:turnRight(1)
			end
		else -- equals R.width but is 1,3,5,7 etc
			T:turnLeft(2) --turn round 180
			T:forward(R.length - 1)
			T:turnRight(1)
			T:forward(R.width - 1)
			T:turnRight(1)
		end
	end
	return {}
end

function clearMineshaft()
	local length = 0
	local torch = 0
	local lib = {}

	function lib.clearCentre(axeSide, swordSide)
		local moves = {}
		local torchCount = 0
		local blockTypeU = ""
		local blockTypeF = ""
		local blockTypeD = ""
		turtle.digUp()										-- in case block already above
		repeat
			blockTypeU = T:getBlockType("up")
			local goUp = false
			local goDown = false
			if blockTypeU ~= "" then						-- block above
				if T:isStone(blockTypeU, true) then				-- stone detected up
					blockTypeD = T:getBlockType("down")
					if blockTypeD:find("torch") ~= nil or blockTypeD:find("rail") ~= nil then	-- torch or rail below
						turtle.digUp(axeSide)				-- remove it
					else
						T:down(1)
						blockTypeD = T:getBlockType("down")
						if blockTypeD ~= "" then			-- block below
							T:go("U1x0")
						else	-- no block below
							table.insert(moves, "D") 		-- add D to moves
						end
					end
				else										-- known block above, not stone, eg planks
					turtle.digUp(axeSide)					-- remove it
				end
			end

			blockTypeD = T:getBlockType("down")
			if blockTypeD ~= "" then						-- block below
				if T:isStone(blockTypeD, true) then				-- stone detected down in centre of mineshaft = level change
					T:up(1)
					table.insert(moves, "U")
				elseif blockTypeD:find("torch") == nil then	-- no torch below
					turtle.digDown(axeSide)
				end
			end
			blockTypeF = T:getBlockType("forward")
			if not T:isStone(blockTypeF, true) then			-- true = include deepslate as stone
				T:forward(1)
				table.insert(moves, "F")					-- Normal move so insert F
				torchCount = torchCount + 1
				if torchCount == R.torchInterval then
					torchCount = 0
					T:place("torch", "down")
				end
			end
		until T:isStone(blockTypeF, true)
		return moves
	end

	function lib.clearSide(directions, axeSide, swordSide)
		if type(directions) ~= "table" then
			directions = {directions}
		end
		for _, direction in ipairs(directions) do
			local blockType = T:getBlockType(direction)
			if blockType:find("cobweb") ~= nil then
				-- T:dig(direction, bypass=true, slot=1, side="")
				T:dig(direction, true, 1, swordSide)
			elseif blockType ~= "" then
				T:dig(direction, true, 1, axeSide)
			end
		end
	end

	function lib.clearSideToEnd(moves, axeSide, swordSide)
		for i = 1, #moves, 1 do	-- reverse the Up/ down markers
			if moves[i] == "U" then
				T:up(1)
			elseif moves[i] == "D" then
				T:down(1)
			elseif moves[i] == "F" then
				lib.clearSide({"up", "down", "forward"}, axeSide, swordSide) -- dig cobweb or any other block up/down/forward
				T:forward(1)
			end
		end
	end

	function lib.clearSideToStart(moves, axeSide, swordSide)
		-- index needs to be manipulted so moves up or down are preceeded by a forward
		local index = #moves								-- start same as loop counter
		for i = #moves, 1, -1 do							-- iterate moves backwards
			if moves[index] == "U" then
				T:go("F1D1")
				index = index - 1
			elseif moves[index] == "D" then
				T:go("F1U1")
				index = index - 1
			elseif moves[index] == "F" then
				lib.clearSide({"up", "down", "forward"}, axeSide, swordSide) -- dig cobweb or any other block up/down/forward
				T:forward(1)
			end
			index = index - 1
			if index == 0 then break end
		end
	end

	function lib.checkEquipment()
		menu.colourPrint("Checking Equipment", colors.red)
		local axeSide, swordSide = "", ""
		local itemLeft, itemRight = T:getEquipped("both")
		if itemLeft == "minecraft:diamond_pickaxe" then
			axeSide = "left"
		elseif itemRight == "minecraft:diamond_pickaxe" then
			axeSide = "right"
		end
		if itemLeft == "minecraft:diamond_sword" then
			swordSide = "left"
		elseif itemRight == "minecraft:diamond_sword" then
			swordSide = "right"
		end
		--place sword on right, pickaxe on left
		if swordSide == "" then
			-- sword not equipped
			if T:getItemSlot("minecraft:diamond_sword") > 0 then	-- sword in inventory
				if axeSide == "left" then
					T:equip("right", "minecraft:diamond_sword")
					swordSide = "right"
				else
					T:equip("left", "minecraft:diamond_sword")
					swordSide = "left"
				end
			end
		end
		if swordSide == "" then		-- no sword
			swordSide = axeSide		-- use axe instead
		end
		return axeSide, swordSide
	end

	function lib.checkPosition()
		menu.colourPrint("Checking position", colors.orange)
		-- check position by rotating until facing away from wall
		local turns = 0
		while not turtle.detect() do
			T:turnRight(1)
			turns = turns + 1
			if turns > 4 then
				return {"I am not facing a wall. Unable to continue"}
			end
		end
		T:turnRight(2)	-- face coridoor
		return nil
	end

	function lib.turnAtEnd(axeSide, swordSide)
		-- turn right, forward, right, return to start with up/down dig
		T:go("R1")
		lib.clearSide({"up","down"}, axeSide, swordSide) 	-- dig cobweb or any other block up/down
		T:go("F1R1")										-- ready for return journey
	end

	function lib.turnAtStart(axeSide, swordSide)
		-- move to other wall and repeat.
		T:go("R1")
		lib.clearSide({"up","down"}, axeSide, swordSide) -- dig cobweb or any other block up/down
		T:go("F1")
		lib.clearSide({"up","down"}, axeSide, swordSide) -- dig cobweb or any other block up/down
		T:go("F1R1")
		--lib.clearSide({"up","down"}, swordSide) -- dig cobweb or any other block up/down
	end

	local axeSide, swordSide = lib.checkEquipment()
	local position = lib.checkPosition()
	if position ~= nil then
		return position
	end
	menu.colourPrint("Clearing Mineshaft", colors.yellow)
	local moves = lib.clearCentre(axeSide, swordSide)

	lib.turnAtEnd(axeSide, swordSide)

	lib.clearSideToStart(moves, axeSide, swordSide)

	lib.turnAtStart(axeSide, swordSide)

	lib.clearSideToEnd(moves, axeSide, swordSide)

	lib.clearSide({"up", "down"}, axeSide, swordSide) -- dig cobweb or any other block up/down/forward

	return {"Mineshaft cleared"}
end

function clearMonumentLayer() -- Not currently implemented
	R.up = true
	R.down = true
	R.silent = true
	if R.subChoice == 0 then
		R.up = false
		R.down = false
	end
	-- send turtle down until it hits bottom
	-- then clear rectangle of given size
	-- start above water, usually on cobble scaffold above monument
	if T:detect("down") then -- in case not over wall
		T:forward(1)
	end
	local height = 1
	-- go down until solid block detected
	while utils.clearVegetation("down") do
		T:down(1)
		height = height + 1
	end
	T:down(1)
	height = height + 1
	clearRectangle()
	T:up(height - 1)

	return {}
end

function clearMountainSide()
	--[[
	First row              outward  l  s  f  mid    (length, start, finish, midPoint)

	      >|*|*|           true                     lib.clearRow() moves: 7-5=2, midPoint starts at 2
	      +|*|*|
	      +|*|*|
	      ^|*|*|        <  false    7  5  6  2      lib.clearRow() moves: 9-2=7, midPoint starts at -4 -1 = -5
	       |*|*|*|	    +
	     |*|*|*|*|*|    +
	  >  |*|*|*|*|*|    ^  true     9  2  6  -4     lib.getStartingLength(). Ends 1 block after block finish
	  ^|*|*|*|*|*|*|*|*|                            starts here, moves up 1
	    1 2 3 4 5 6 7 8                             block index

	Second row                outward l  s  f  mid
	             <            false
                 +
          |*|*|  +
	   >|*|*|*|*|^            true
	   +|*|*|*|*|
	   +|*|*|*|*|
	   ^|*|*|*|*|          <  false   6  5  6  2
	    |*|*|*|*|*|*|      +
	  |*|*|*|*|*|*|*|*|    +
	  |*|*|*|>|*|*|*|*|    ^  true    7+5   5 -7    lib.getHalf(); goBack(7)
	|*|*|*|*|*|*|*|*|*|*|*|                           starts at midPoint of previous row eg block 4
	 0 1 2 3 4 5 6 7 8 9 10
	]]

	-- variables declared before lib for them to be used within lib as is then in scope
	local turn = "R"
	local oTurn = "L"
	--if R.subChoice == 1 then 	-- remove left side
	if R.left then
		turn = "L"
		oTurn = "R"
	end
	local outward = true		-- direction flag

	local lib = {}

	function lib.isAnyAbove(above)
		--Log:saveToLog("lib.isAnyAbove: "..U.tableConcat(above, ", "), false)
		for k,v in ipairs(above) do
			if v then
				--Log:saveToLog("lib.isAnyAbove Found: "..k , false)
				return true
			end
		end
		return false
	end

	function lib.clearLevel(above)	-- eg 9, 2, 6, -4 from lib.getStartingLength OR 7, 5, 6, 3 from previous
		-- clearLevel always follows either lib.getStartingLength or a previous lib.clearLevel
		-- midPoint should be adjusted as turtle moves to reflect current row length
		if #above == 0 then return above, 1 end
		--local index = 0
		local minMoves = math.floor(#above / 2)
		local up, forward, down = lib.getDetect()
		if outward then										-- follow table indexes
			for x = 1, minMoves do							-- clear first half
				above[x] = up								-- reset this with new value
				T:go("x0x2F1")								-- clear and move forward
				up, forward, down = lib.getDetect()
				--index = index + 1
			end
			for x = minMoves + 1, #above do					-- check remaing half and clear
				T:go("x0x2")								-- clear above / below
				if above[x] then							-- is a block recorded as present?(now below)
					above[x] = up							-- reset this with new value
					T:forward(1)							-- move forward
					up, forward, down = lib.getDetect()
					--index = index + 1
				else
					break
				end
			end
		else												-- iterate table in reverse
			--index = #above
			for x = #above, minMoves, -1 do					-- clear first half
				above[x] = up								-- reset this with new value
				T:go("x0x2F1")								-- clear and move forward
				up, forward, down = lib.getDetect()
				--index = index - 1
			end
			for x = minMoves - 1, 1, -1 do					-- check remaing half and clear
				T:go("x0x2")								-- clear up / down
				if above[x] then							-- is a block recorded as present?(now below)
					above[x] = up							-- reset this with new value
					T:forward(1)							-- move forward
					up, forward, down = lib.getDetect()
					--index = index - 1
				else
					break
				end
			end
		end
		T:go("x0x2 F1R2 x0x2 F1")							-- face opposite direction, delete blocks above and below
		outward = not outward								-- switch direction flag
		return above										-- eg {false, true, true, true, false}
	end

	function lib.getDetect()
		return turtle.detectUp(),  turtle.detect(),  turtle.detectDown()
	end

	function lib.getStartingLength()
		--[[
			length of column by excavating blocks above, ahead or below
			Rotate 180 at end of run ready to return
			already 1 block above ground
		]]
		local above = {}									-- empty table of boolean values
		local length = 0									-- used as counter
		T:forward(1)										-- start check 1 block ahead
		local up, forward, down = lib.getDetect() 			-- check if anything around current block
		if up or forward or down then						-- block found nearby: continue
			while up or forward or down do					-- while blocks ahead / up / down move forward
				table.insert(above, up)
				T:go("x0x2F1")
				up, forward, down = lib.getDetect() 		-- check if anything around current block
				length = length + 1
				if length >= R.length then					-- check if going out of range
					--Log:saveToLog("lib.getStartingLength() : outward = "..tostring(outward).." MaxLength "..maxLength.." reached", false)
					break
				end
			end
			T:go("R2x0x2")									-- Rotate 180 and clear blocks above/below
		else												-- no blocks nearby: exit
			T:go("R2F1")									-- return to start position rotated 180
		end
		outward = not outward

		return above 										-- above = {false, true, true, true, true, false, false}
	end

	function lib.firstRow()
		local height = 1									-- starts at ground level, but forced up 1
		T:up(1)
		local above = lib.getStartingLength()				-- clear the ground level and 1 above eg 9, 2, 5, 4
		if Log:saveToLog("startLength: "..#above, true) then
			--Log:saveToLog(U.tableConcat(above, ", "), false)
			utils.waitForInput()
		end													-- at end of first row as already turned 180, outward set to false in getStartingLength
		while lib.isAnyAbove(above) do
			T:go("U3")	-- go up 3
			height = height + 3
			above = lib.clearLevel(above)	-- returns start and finish of blocks above, rotates 180
			if Log:saveToLog("checking level: "..height, true) then
				--Log:saveToLog(U.tableConcat(above, ", "), false)
				utils.waitForInput()
			end
		end													-- first row all levels completed.
		T:down(height)										-- now on ground + 1, facing last column cleared.

		return above
	end

	function lib.deepCopy(tbl)
		local copy = {}
		for key, value in ipairs(tbl) do
			table.insert(copy, value)
		end
		return copy
	end

	function lib.getHalf(above)
		-- already 1 block above ground
		local maxLength = R.length
		local temp = {}
		local retValue = {}
		if #above > 0 then								-- not empty table, so must be second half
			temp = lib.deepCopy(above)					-- copy existing table
			above = {}									-- initialise above
		end
		local up, forward, down = lib.getDetect()

		while up or forward or down do					-- while blocks ahead / up / down move forward
			T:go("x0x2F1")
			table.insert(above, up)
			up, forward, down = lib.getDetect() 		-- check if anything around current block

			if #above >= math.floor(maxLength / 2) then	-- check if going out of range
				--Log:saveToLog("lib.getHalf() : outward = "..tostring(outward).." MaxLength "..maxLength.." reached", false)
				T:go("x0x2")
				break
			end
		end
		T:turnRight(2)									-- ready for next half or return
		outward = not outward
		if #temp > 0 then								-- completing a second half measurement
			for i = #above, 1, -1 do
				table.insert(retValue, above[i])		-- combine 2 tables into 1
			end
			for i = 1, #temp do
				table.insert(retValue, temp[i])
			end
		else
			retValue = above
		end
		return retValue
	end

	function lib.nextRow()
		local height = 1
		--Log:saveToLog("lib.nextRow()", false)
		T:up(1)
		local pattern = turn.."1F1"..turn.."1"
		if not outward then
			pattern = oTurn.."1F1"..oTurn.."1"
		end
		T:go(pattern)
		--Log:saveToLog("    T:go("..pattern..")", false)
		outward = not outward -- reverse direction flag
		-- now in next vertical row
		local above = lib.getHalf({})
		local index = 0
		if Log:saveToLog("\t  first half Length: "..#above.." Enter", true) then
			--Log:saveToLog(U.tableConcat(above, ", "), false)
			utils.waitForInput()
		end
		lib.returnToMidPoint(#above)					-- return to starting point
		T:forward(1)
		above = lib.getHalf(above)					-- returns length - 1 eg 5, 4
		if Log:saveToLog("\t  total length: "..#above.." Enter", true) then
			--Log:saveToLog(U.tableConcat(above, ", "), false)
			utils.waitForInput()
		end

		while lib.isAnyAbove(above) do
			T:go("U3")				-- go up 3
			height = height + 3		-- increment height
			--Log:saveToLog("\tClear height loop: height = "..height, false)
			above = lib.clearLevel(above)	-- returns start and finish of blocks above
		end
		T:down(height)	-- now on ground + 1
		lib.returnToMidPoint(above)
	end

	function lib.returnToMidPoint(above)
		--[[ value can be integer or table]]
		if type(above) == "table" then
			--Log:saveToLog("lib.returnToMidPoint("..#above..")", false)
			if #above > 0 then
				local midPoint = math.floor(#above / 2)
				if #above % 2 == 1 and  not outward then -- length is odd no
					midPoint = math.ceil(#above / 2)
					--Log:saveToLog("    midPoint adjusted "..midPoint..")", false)
				end
				--Log:saveToLog("    T:forward("..midPoint..")", false)
				T:forward(midPoint)
			end
		else
			--Log:saveToLog("lib.returnToMidPoint("..above..")", false)
			if above > 0 then
				--Log:saveToLog("    T:forward("..above..")", false)
				T:forward(above)
			end
		end
		-- now back at starting point
	end

	-- Start here
	-- if "tk log d.." typed instead of "tk" will start logfile and display comments. read() will be activated for debugging
	--Log:saveToLog("Starting function clearMountainSide", false)
	local above = lib.firstRow() 			-- outward depends on height eg 1-2 = false, 3-5 = true, 6-8 = false
	lib.returnToMidPoint(above)				-- return to mid first row of blocks
	for row = 1, R.width -1 do
		lib.nextRow()
	end

	return {}
end

function clearPerimeter()
	-- set R.up and R.down before calling!
	local lib = {}
	function lib.upDown(length)
		for l = 1, length do
			T:go("x0x2F1x0x2")
		end
	end

	function lib.up(length)
		for l = 1, length do
			T:go("x0F1x0")
		end
	end

	function lib.down(length)
		for l = 1, length do
			T:go("x2F1x2")
		end
	end

	if R.forward then
		T:forward(1)
	end
	if R.up and R.down then	-- rmove blocks above and below
		for i = 1, 2 do
			lib.upDown(R.length - 1)
			T:turnRight(1)
			lib.upDown(R.width - 1)
			T:turnRight(1)
		end
	elseif R.up then	-- remove blocks above only
		for i = 1, 2 do
			lib.up(R.length - 1)
			T:turnRight(1)
			lib.up(R.width - 1)
			T:turnRight(1)
		end
	elseif R.down then	-- remove blocks below only
		for i = 1, 2 do
			lib.down(R.length - 1)
			T:turnRight(1)
			lib.down(R.width - 1)
			T:turnRight(1)
		end
	else	-- remove only blocks in front
		for i = 1, 2 do
			T:forward(R.length - 1)
			T:turnRight(1)
			T:forward(R.width - 1)
			T:turnRight(1)
		end
	end
	return {}
end

function clearRectangle(withData)
	if withData == nil then withData = false end	-- used in treeFarm to count logs
	-- height = 0: one level, 1 = +up, 2 = +down, 3 = +up/down
	local logsDug = 0						-- blocks dug up, forward, down
	local itemCount = 0
	local lib = {}

	function lib.UpDown(length)
		for l = 1, length do
			--T:go("x0x2F1x0x2")
			turtle.digDown()				-- dig below
			itemCount = T:getTotalItemCount()
			while turtle.digUp() do			-- dig up including gravity blocks
				if T:getTotalItemCount() > itemCount then
					logsDug = logsDug + 1
				end
			end
			while not turtle.forward() do	-- if no block in front, moves forward
				turtle.dig()				-- block in front, so dig it
			end
			turtle.digDown()				-- now moved forward so dig down again
			itemCount = T:getTotalItemCount()
			while turtle.digUp() do			-- dig up including gravity blocks
				if T:getTotalItemCount() > itemCount then
					logsDug = logsDug + 1
				end
			end
		end
	end

	function lib.Up(length)
		for l = 1, length do
			itemCount = T:getTotalItemCount()
			while turtle.digUp() do			-- dig up including gravity blocks
				if T:getTotalItemCount() > itemCount then
					logsDug = logsDug + 1
				end
			end
			while not turtle.forward() do	-- if no block in front, moves forward
				turtle.dig()				-- block in front, so dig it
			end
			itemCount = T:getTotalItemCount()
			while turtle.digUp() do			-- dig up including gravity blocks
				if T:getTotalItemCount() > itemCount then
					logsDug = logsDug + 1
				end
			end
		end
	end

	function lib.Down(length)
		for l = 1, length do
			turtle.digDown()				-- dig below
			while not turtle.forward() do	-- if no block in front, moves forward
				turtle.dig()				-- block in front, so dig it
			end
			turtle.digDown()				-- now moved forward so dig down again
		end
	end

	function lib.Forward(length)
		T:forward(length)
	end

	-- could be 1 wide x xx R.length (trench) R.up and return
	-- could be 2+ x 2+
	-- even no of runs return after last run
	-- odd no of runs forward, back, forward, reverse and return
	turtle.select(1)
	if R.direction == "F" then
		T:forward(1)
	end
	if R.width == 1 then 					-- single block trench ahead only
		if R.up and R.down then				-- single block wide trench dig R.up and R.down = 3 blocks deep
			lib.UpDown(R.length - 1)
		elseif R.up then					-- single block wide trench dig R.up = 2 blocks deep
			lib.Up(R.length - 1)
		elseif R.down then					-- single block wide trench dig R.down = 2 blocks deep
			lib.Down(R.length - 1)
		else 								-- single block wide = 1 block deep
			lib.Forward(R.length - 1)
		end
		T:turnRight(2)						-- turn at the top of the run
		T:forward(R.length - 1)				-- return to start
		T:turnRight(2)						-- turn round to original position
	else 									-- R.width 2 or more blocks
		local iterations = 0 				-- R.width = 2, 4, 6, 8 etc
		if R.width % 2 == 1 then  			-- R.width = 3, 5, 7, 9 eg R.width 7
			iterations = (R.width - 1) / 2 	-- iterations 1, 2, 3, 4 for widths 3, 5, 7, 9
		else
			iterations = R.width / 2		-- iterations 1, 2, 3, 4 for widths 2, 4, 6, 8
		end
		for i = 1, iterations do 			-- eg 3 blocks wide, iterations = 1
			if R.up and R.down then							-- dig R.up and R.down
				lib.UpDown(R.length - 1)
				T:go("x0x2R1F1x0x2R1x0x2")				-- turn round
				lib.UpDown(R.length - 1)
			elseif R.up then								-- dig R.up
				lib.Up(R.length - 1)
				T:go("x0R1F1x0R1x0")
				lib.Up(R.length - 1)
			elseif R.down then							-- dig R.down
				lib.Down(R.length - 1)
				T:go("x2R1F1x2R1x2")
				lib.Down(R.length - 1)
			else										-- no digging R.up or R.down
				lib.Forward(R.length - 1)
				T:go("R1F1R1")
				lib.Forward(R.length - 1)
			end
			-- if 1 less than end, reposition for next run
			if i < iterations then
				T:go("L1F1L1", false, 0, false)
			end
		end
		if R.width % 2 == 1 then  -- additional run and return to base needed
			T:go("L1F1L1", false, 0, false)
			if R.up and R.down then
				lib.UpDown(R.length - 1)
			elseif R.up then
				lib.Up(R.length - 1)
			elseif R.down then
				lib.Down(R.length - 1)
			else
				lib.Forward(R.length - 1)
			end
			T:turnRight(2)
			T:forward(R.length - 1)
		end
		T:go("R1F"..R.width - 1 .."R1", false, 0, false)
	end
	if withData then
		return logsDug
	else
		return {}
	end
end

function clearSandCube()
	R.data = ""
	for w = 1, R.width do
		clearSandWall()
		if w < R.width then
			if w % 2 == 1 then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
		end
	end

	return {}
end

function clearSolid()
	-- R.goUp = true if moving up
	-- R.goDown = true if moving down
	local height = 1
	local remaining = R.height
	local lib = {}

	function lib.singleLayer()
		R.up = false
		R.down = false
		clearRectangle()
	end

	function lib.doubleLayer()
		R.up = false
		R.down = false
		if R.goUp then
			R.up = true
		else
			R.down = true
		end
		clearRectangle()
	end

	function lib.tripleLayer()
		-- turtle in centre layer
		R.up = true
		R.down = true
		clearRectangle()
	end

	R.silent = true
	if R.forward then	-- move forward 1
		T:forward(1)
	end
	if R.down then	-- above structure. move down 1
		T:down(1)
	end
	if R.height < 3 then 							--1-3 layers only
		if R.height == 1 then 						--one layer only
			lib.singleLayer()
		elseif R.height == 2 then 					--2 layers only current + dig up/down
			lib.doubleLayer()
		end
	else -- 3 or more levels
		height = height + utils.move(1)				-- move up/down 1 block for first layer
		while remaining >= 3 do 					-- min 3 levels
			lib.tripleLayer()
			remaining = remaining - 3
			if remaining == 0 then					-- all finished
				break
			elseif remaining == 1 then
				height = height + utils.move(2)		-- move up/down 2 blocks
				lib.singleLayer()
			elseif remaining == 2 then
				height = height + utils.move(2)		-- move up/down 2 blocks
				lib.doubleLayer()
			else
				height = height + utils.move(3)		-- move up/down 3 blocks
				if remaining == 3 then
					finish = true
				end
			end
		end
	end

	if height > 1 then
		utils.move(height - 1, true) -- reverse direction
	end

	return {}
end

function createMine()
	-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	-- "M" mine block above and/or fill void
	-- "m" mine block below and/or fill void
	-- "N" mine block above and/or fill void + mine block below if valuable: 1 block high ceiling area
	-- "n" mine block below and/or fill void + check left side
	local lib = {}

	function lib.ceiling(length, useTorch)
		-- excavates a length and places block above
		for i = 1, length do
			if useTorch and (i == 1 or i == 17 or i == length) then
				T:place("torch", "down", true)
			end
			if i < length then
				T:go("C0F1", false, 0, true)
			else
				T:go("C0", false, 0, true)
			end
		end
	end

	function lib.clearArea()
		local outward = true
		for i = 1, 13 do
			T:go("N28", false, 0, true)
			if i < 13 then
				if outward then
					T:go("L1F1L1", false, 0, true)
				else
					T:go("R1F1R1", false, 0, true)
				end
				outward = not outward
			end
		end
	end

	function lib.floor(length, clearUp)
		-- excavates a length and places block below
		-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		for i = 1, length do
			if clearUp then						-- used along floor to make a corridor
				T:go("x0C2", true, 0, true)	-- used along top of wall to place below and clear a passage
			else
				T:go("C2", true, 0, true)
			end
			if i < length then
				T:forward(1)
			end
		end
	end

	function lib.fillWall(length)
		for i = 1, length do
			if i < length then
				T:go("B1C1", false, 0, true)
			end
		end
		T:go("R1")
	end

	function lib.placeStorage()
		T:go("U2D2") 							-- create space for chest
		if not T:place("chest", "up", false) then
			T:place("barrel", "up", false)
		end
	end

	function lib.prepareArea()
		T:go("V14 L1 V14 R1F2R1", false, 0, true)
		T:go("V14 L1 V14 L1 V14 L1", false, 0, true)
		T:go("V14 F2 V14 L1 V14 L1", false, 0, true)
		T:go("F1L1 F1R1", false, 0, true)
	end

	function lib.torch()
		T:go("C2U1", false, 0, true)
		T:place("torch", "down", true)
		T:go("C0F1 C0D1", false, 0, true)
	end

	lib.floor(33, true)						-- mine ground level
	T:go("U1R2") 							-- go up, reverse
	lib.ceiling(17, true)					-- mine ceiling to mid-point
	T:go("D1R1")							-- face side branch on left
	lib.floor(17, true)						-- mine ground level
	T:go("U1R2") 							-- go up, reverse
	lib.ceiling(33, true)					-- mine ceiling
	T:go("R2D1")							-- floor level
	lib.torch()
	lib.floor(16, true)						-- mine ground level
	T:go("L1U1")
	lib.placeStorage()
	T:emptyTrash("up")
	T:place("torch", "down", true)
	T:go("F16R1D1") 						-- return to start, turn right, down to floor

	if R.inNether then
		-- construct solid wall round whole 35 x 35 area first
		lib.floor(17, true)					-- move from centre area to SE corner
		T:go("F1L1 F1R2 U1")				-- ready for outer wall at ceiling level
		for i = 1, 3 do
			lib.floor(35, false)
			T:go("R1")
		end
		lib.floor(16, false)
		T:go("F4")
		lib.floor(16, false)
		T:go("L1C1")						-- face backwards
		for i = 1, 3 do
			lib.fillWall(35)
		end
		lib.fillWall(17)
		T:go("R1F3L2")
		lib.fillWall(15)
		T:go("R2F1 R2C1 R2D1")				-- on floor ready for inner corridor
		for i = 1, 4 do
			lib.floor(33, true)				-- make sure floor is solid
			T:go("R1")
		end
		T:up(1)
		for i = 1, 4 do
			lib.ceiling(33, true)			-- make sure ceiling is solid
			T:go("R1")
		end
		T:go("R1F16L1")
	else
		-- sides not checked for water or lava
		-- start on floor level
		lib.torch()
		lib.floor(16, true)					-- make sure floor is solid
		T:go("R1")
		for i = 1, 3 do
			lib.torch()
			lib.floor(32, true)				-- make sure floor is solid
			T:go("R1")
		end
		lib.torch()
		lib.floor(16, true)					-- back to ladder area
		lib.torch()							-- to left of ladder
		T:go("U1")
		lib.ceiling(16, false)				-- make sure ceiling is solid
		T:go("R1")
		for i = 1, 3 do
			lib.ceiling(33, true)				-- make sure floor is solid
			T:go("R1")
		end
		lib.ceiling(17, true)
		T:go("R1")
	end
	lib.ceiling(16, false)					-- return to centre
	T:go("F1R2")
	T:place("torch", "down", true)
	T:emptyTrash("up")
	T:go("F16 R1F1 R1F1") --return to shaft + 1
	lib.prepareArea()
	lib.clearArea()	-- ends NW corner
	T:go("R1F13 R1F14 L1F1")
	T:emptyTrash("up")
	T:go("B1L1 F15 R1 F2R1")
	lib.prepareArea()
	lib.clearArea()	-- ends SE corner
	T:go("F1R1 F13L1")
	return{"Mining operation complete"}
end

function createStripMine()
	--[[
	R.length should be a multiple of 16
	mine a corridoor repairing floor and ceiling
	check sides, remove valuable items
	plug if lava present
	Every 16 blocks dig a side passage 1 block deep 2 blocks long
	]]
	local lib = {}

	function lib.seal()
		if T:isValuable("forward") then	-- valuable block in front. If debris then refuse already dumped
			T:dig("forward")
		end
		local blockType = T:getBlockType("forward")
		if blockType:find("lava") ~= nil then
			--T:place("stone", "forward", false) -- place does not allow for specific blocktype
			T:go("C1", false, 0, false, R.useBlockType)
			return true
		end

		return false
	end

	function lib.checkSeal()
		local retValue = false
		T:turnRight(1)
		if lib.seal() then
			retValue = true
		end
		T:turnLeft(2)
		if lib.seal() then
			retValue = true
		end
		T:turnRight(1)
		return retValue
	end

	function lib.alcove()
		-- right side, starting at ceiling
		T:go("R1F1 C0", false, 0, false, R.useBlockType)-- stone ceiling, facing alcove wall (upper)
		lib.seal()										-- seal alcove wall (upper)
		T:go("D1C2", false, 0, false, "cobble")			-- cobble floor, facing alcove wall (lower)
		lib.seal()										-- seal alcove wall (lower)
		T:go("L2 F1")									-- down 1, turn round, return to corridoor.
		-- left side
		T:go("F1 C2", false, 0, false, "cobble")		-- cobble floor, facing alcove wall (lower)
		lib.seal()										-- seal alcove wall (lower)
		T:go("U1 C0", false, 0, false, R.useBlockType)	-- stone ceiling, still facing alcove wall
		lib.seal()										-- seal alcove wall (upper)
		T:go("L2F1L1")									-- return to corridoor at ceiling position
		lib.placeTorch()
	end

	function lib.placeTorch()
		if R.torchInterval > 0 then 					-- torches onboard
			if T:getItemSlot("minecraft:torch") > 0 then
				T:place("minecraft:torch", "down")
			end
		end
	end

	R.useBlockType = T:getMostItem("", true) -- exclude none, use stone only/netherrack

	local seal = false
	if T:getItemSlot("minecraft:torch") == 0 then
		R.torchInterval = 0 -- set to default 16 above
	end
	for steps = 1, R.length do
		-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		T:go("C2U1C0", false, 0, true, R.useBlockType)		-- check and repair floor / ceiling
		if steps % 16 == 0 or steps % 16 == 1 then
			lib.alcove() -- enter and exit at ceiling position
		else
			seal = lib.checkSeal()
		end
		T:go("F1D1", false, 0, true)
		seal = lib.checkSeal()
	end
	if seal then -- water or lava found while tunnelling
		T:go("U1C0", false, 0, true, R.useBlockType)
		lib.checkSeal()
		T:go("C1", false, 0, true, R.useBlockType)
		T:down(1)
	end
	return {}
end

function digTrench()
	local blockType
	-- go down R.height, move forward
	if R.length == 0 then
		R.length = 4096 -- will go out of loaded chunks and stop or max 4096 on a server
	end
	for i = 1, R.length do
		local count = 0
		for down = 1, R.height do
			blockType = T:isWaterOrLava("down")
			-- go down only if no water or lava below
			if blockType:find("water") == nil and blockType:find("lava") == nil then
				T:down(1)
				count = count + 1
			end
		end
		T:go("C2", false, 0, true)				-- if empty below fill void
		T:go("U"..count)						-- return to surface, continue if block above
		while turtle.detect() do				-- go up while block in front
			blockType = T:getBlockType("forward")
			if T:isVegetation(blockType) then
				T:dig("forward")
				break
			elseif blockType:find("log") ~= nil then
				T:harvestTree("forward")
			else
				T:up(1)
			end
		end
		T:forward(1)							-- move forward
		while not turtle.detectDown() do		-- go down until block detected
			blockType = T:isWaterOrLava("down")
			if blockType:find("water") == nil and blockType:find("lava") == nil then
				T:down(1)
			else
				break
			end
		end
	end

	return {}
end

function mineBedrockArea()
	--[[
	Assume on level 5 or -59
	for 1, width do
		for 1, length do
			go down until bedrock, digging/replacing all directions
			return to 5 / -59
			move forward 1 blocks
		end
		turn right/ forward 2 turn right
	end
	]]

	local lib = {}

	function lib.clearColumn()
		local level = 0
		--T:go("L1x1R2x1L1")
		local success = T:down(1)
		while success do
			level = level + 1
			if R.data == "leaveExposed" then
				T:go("R1x1R1x1R1x1R1x1", false, 0, true)
			else
				T:go("R1C1R1C1R1C1R1C1", false, 0, true)
			end
			success = T:down(1)
		end
		if R.data == "leaveExposed" then
			T:go("U"..level)
		else
			T:go("U"..level.."C2")
		end
	end

	local goRight = true
	for i = 1, R.width do
		for j = 1, R.length do
			lib.clearColumn()
			T:forward(1)
		end
		if goRight then
			T:go("R1F1R1")
		else
			T:go("L1F1L1")
		end
		goRight = not goRight
	end
	return {"Bedrock area cleared of minerals"}
end

function quickMine()
	--[[
	mine valuable blocks from specified area
	R.subChoice:
	1 At mine area start, on the floor
	2 At mine area start, on the ceiling
	3 On floor, start 1 block ahead
	4 On ceiling, start 1 block ahead
	5 On floor diagonally to left"
	]]
	local lib = {}

	function lib.refuel(direction)
		if T:getWater(direction)  then
			T:refuel(1000, false)
		end
	end

	function lib.mine()
		-- starts on ceiling
		local isValuable, blockType
		for i = 1, R.length do
			local fillUp = R.up
			local fillDown = R.down
			isValuable, blockType = T:isValuable("down")
			if isValuable then
				T:dig("down")
			elseif blockType:find("water") ~= nil then
				fillDown = true
			elseif blockType:find("lava") ~= nil then
				lib.refuel("down")
				fillDown = true
			end
			isValuable, blockType = T:isValuable("up")
			if isValuable then
				T:dig("up")
			elseif blockType:find("water") ~= nil then
				fillUp = true
			elseif blockType:find("lava") ~= nil then
				lib.refuel("up")
				fillUp = true
			end
			--if not turtle.detectUp() and fillUp then
			if fillUp then
				T:fillVoid("up")
			end
			--if not turtle.detectDown() and fillDown then
			if fillDown then
				T:fillVoid("down")
			end
			if i < R.length then
				T:forward(1)
			end
		end
	end

	menu.clear()
	menu.colourPrint("QuickMine rectangle: R.subChoice "..R.width.. " x "..R.length, colors.lightBlue)
	local outbound = true

	if turtle.detectDown() then	--assume on floor
		T:up(1)
	end

	if R.subChoice == 3 or R.subChoice == 4 or R.direction == "F1" then
		T:go("F1")
	elseif R.subChoice == 5 or R.direction == "R1F1L1F1" then
		T:go("R1 F1L1 F1")
	end

	for w = 1, R.width do
		lib.mine()
		if w < R.width then
			if outbound then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
			outbound = not outbound
		end
		if T:getFirstEmptySlot() == 0 then
			T:dumpRefuse("forward", 1)
		end
	end
	if outbound then
		T:go("L1F"..R.width - 1 .."L1F"..R.length - 1)
	else
		T:go("R1F"..R.width - 1 .."R1")
	end

	return {}
end

function quickMineCorridor()
	--[[
	R.subChoice
	1: At corridor start, on the floor
	2: At corridor start, on the ceiling
	3: On floor, start 1 block ahead
	4: On ceiling, start 1 block ahead
	]]

	while turtle.down() do end	-- move to floor level
	if R.subChoice == 3 or R.subChoice == 4 or R.direction == "F1" then
		T:forward(1)
	end

	local width = R.width - 1
	local length = R.length - 1
	R.silent = true
	R.length = length
	createCorridor(true) -- put floor and ceiling for R.length, place torch at start
	T:turnRight(1)
	R.length = width
	createCorridor(true)
	T:turnRight(1)
	R.length = length
	createCorridor(true)
	T:turnRight(1)
	R.length = width
	createCorridor(true)
	T:turnRight(1)

	return {}
end

function undermineDragonTowers()
	--[[
	        -13, -40....12, -40						NNW (4)   	NNE (5)

	    -34, -25............33, -25				NWW	(2)				NEE (9)

	-42, -1....................42, 0		W (1)						E (8)

	     -34, 24............33,24				SWW	(3)				SEE (10)

		      -13,39....12, 39						SSW	(7)		SSE (6)

	North towers centres 25 blocks apart, 40 blocks north of axis
	Mid-North towers 67 blocks apart, 25 blocks north of axis
	W-E centres 84 blocks apart, on 0 axis
	Mid-south towers 67 blocks apart, 24 blocks south of axis
	South towers centres 25 blocks apart, 39 blocks south of axis
	]]

	local lib = {}
	function lib.findNextTower(maxDistance, withMarker)
		local distance = 0
		local blockTypeF = T:getBlockType("forward")
		local blockTypeD = T:getBlockType("down")
		for i = 1, maxDistance do
			if blockTypeF ~= "minecraft:obsidian" and blockTypeD ~= "minecraft:obsidian" then -- not in a tower
				if withMarker and blockTypeD ~= "minecraft:obsidian" then -- used to mark 0 coordinate
					T:place("cobble", "down", false) -- place cobblestone or cobbled deepslate to mark zero coordinate
				end
			else	-- obsidian found, could still be in an earlier tower
				if i > 10 then
					break
				end
			end
			T:go("F1x0")
			distance = distance + 1
			blockTypeF = T:getBlockType("forward")
			blockTypeD = T:getBlockType("down")
		end
		if distance == maxDistance then -- obsidian not found ? wrong place/ direction
			print("Obsidian not found")
			error()
		end
		-- will now be at side of a tower
		lib.findCentre() -- move into tower to find the other side
		return distance
	end

	function lib.findCentre()
		local width = 0
		-- while obsidian in front or below (previously entered tower) measure width and return to centre
		local blockTypeF = T:getBlockType("forward")
		local blockTypeD = T:getBlockType("down")
		while blockTypeF == "minecraft:obsidian" or blockTypeD == "minecraft:obsidian" do
			T:go("F1x0")
			width = width + 1
			blockTypeF = T:getBlockType("forward")
			blockTypeD = T:getBlockType("down")
		end
		-- will always go outside the tower 1 block. width of 5 block tower = 6
		T:go("R2F"..math.ceil(width / 2)) --return to centre of tower
		T:turnLeft(1) -- now find another edge of the tower, dig forward until out of obsidian
		for i = 1, math.ceil(width) do  -- give additional loops if missed centre
			blockTypeF = T:getBlockType("forward")
			blockTypeD = T:getBlockType("down")
			if blockTypeF == "minecraft:obsidian" or blockTypeD == "minecraft:obsidian" then
				T:go("F1x0")
			else
				break
			end
		end
		-- now outside different edge of the tower
		-- reverse and move width/2, dig up + 1 to mark centre, face original direction
		T:go("L2F"..math.ceil(width / 2).."R1U2x1")
		T:place("minecraft:end_stone", "forward", false) -- place endstone to mark facing direction
		T:down(2)
	end

	function lib.findPath(maxLength)
		local blockTypeD = T:getBlockType("down")
		local distance = 0
		while blockTypeD:find("cobble") == nil and distance < maxLength do
			T:go("F1x0")							-- return to 0 axis,
			distance = distance + 1
			blockTypeD = T:getBlockType("down")
		end
		return distance
	end

	-- start at 0,y,0, facing West
	T:dig("up")									-- in case not already done
	local maxLength = 0
	local blockTypeD
	local distance = lib.findNextTower(45, true)-- find W tower (1) and mark trail with cobble
	T:turnRight(2)
	for i = 1, 8 do								-- head back East 8 blocks, turn left (facing north)
		T:go("F1x0")							-- this path may be off-axis, so dig double height
	end
	T:turnLeft(1)
	lib.findNextTower(30)						-- find NWW tower (2)
	T:turnRight(2)
	distance = lib.findPath(30)
	distance = distance + lib.findNextTower(30)	-- find SWW tower (3)
	T:turnRight(2)
	distance = lib.findPath(30)
	T:turnRight(1) 								-- should be on cobble path
	for i = 1, 21 do							-- move East 21 blocks, turn left facing North
		T:go("F1x0")
	end
	T:turnLeft(1)

	distance = lib.findNextTower(45)		-- find NNW tower (4)
	T:turnRight(1)
	distance = lib.findNextTower(30)		-- find NNE tower (5)
	T:turnRight(1)
	distance = lib.findNextTower(85)		-- find SSE tower (6)
	T:turnRight(1)

	distance = lib.findNextTower(30)		-- find SSW tower (7)
	T:turnRight(1)
	distance = lib.findPath(40)				-- head North to 0 axis
	T:go("R1F13") 							-- return to 0,0 facing East
	distance = lib.findNextTower(45, true)	-- find E tower (8)

	T:turnRight(2)
	for i = 1, 9 do
		T:go("F1x0")						-- this path may be off-axis, so dig double height
	end
	T:turnRight(1)

	distance = lib.findNextTower(30)		-- find NEE tower (9)
	T:turnRight(2)
	distance = lib.findPath(30) -- return to 0 axis
	distance = lib.findNextTower(30)		-- find SEE tower (10)
	T:turnRight(2)
	distance = lib.findPath(30) 			-- return to 0 axis
	T:go("L1F33")							-- return to 0, 0

	return {}
end


end
