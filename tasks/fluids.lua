local Fuel = require("lib.runtime.Fuel")
return function(utils, pp, dbug, netherBedrock, deletesWater, brick)
function clearWaterPlants()
	local D = {}
	D.depth = 0
	D.maxDepth = 0
	D.blockType = ""
	D.useBlockType = R.useBlockType -- "" or "prismarine"
	D.length = 0	-- copy of R.length used in lib.clearLength
	D.width = 0		-- increased every iteration
	D.facingForward = true
	D.monumentTopClear = false
	D.monumentArchesClear = false
	D.inWater = false
	D.onWater = false
	D.inWater, D.onWater = utils.getWaterStatus()
	D.floorLength = 0 -- used on monument floor

	local lib = {}

	function lib.getLength()
		local length = 1
		print("Checking water length")
		while utils.clearVegetation("forward") do
			T:forward(1)
			length = length + 1
		end
		for i = 1, length do
			turtle.back()
		end
		return length
	end

	function lib.clearDown()
		while utils.clearVegetation("down") do --clears any grass or sea plants, returns true if air or water, bubble column or ice
			T:down(1)
			D.depth = D.depth + 1
		end
		-- if slab at bottom, replace with solid block
		D.blockType = T:getBlockType("down")
		if D.blockType:find("slab") ~= nil then
			T:go("C2")
		end
		if D.depth > D.maxDepth then
			D.maxDepth = D.depth
		end

		--return D
	end

	function lib.clearLength()
		local moves = 0
		local blockHeight = 1
		D.floorLength = 0 -- reset
		while moves < D.length - 1 do
			if utils.clearVegetation("forward") then
				T:forward(1)
				moves = moves + 1
				if turtle.detectUp() then -- could be on monument going under arch, or faulty monument floor
					if not D.monumentArchesClear then
						lib.checkArches()
					end
				end
				local temp = D.depth
				lib.clearDown() -- go down if in water/air
				if blockHeight == 4 and D.depth - temp == 3 then -- could be just gone over 3 block high column in ocean monument
					if not D.monumentTopClear then
						lib.checkTop()
					end
					blockHeight = 1
				end
				if D.useBlockType == "prismarine" then
					if D.blockType:find("prismarine") == nil then
						-- on monument floor so restrict forward movement to 8 blocks
						D.floorLength = D.floorLength + 1
						if D.floorLength == 8 then
							D.blockType = T:getBlockType("forward")
							while D.blockType:find("prismarine") == nil do
								T:up(1)
								D.blockType = T:getBlockType("forward")
							end
							D.floorLength = 0
						end
					end
				end
				if moves >= D.length - 1 then
					D.width = D.width + 1	-- another length completed so increase width
					return D
				end
			else -- block in front
				blockHeight = 1
				local waterAbove = utils.clearVegetation("up")
				local waterAhead = utils.clearVegetation("forward") -- true if air/water in front
				while not waterAhead do 	-- solid block in front
					if waterAbove then 		-- move up
						T:up(1)
						D.depth = D.depth - 1
						blockHeight = blockHeight + 1
						if D.depth < 1 then
							D.width = D.width + 1	-- another length completed so increase width
							return D
						end
					else 					-- block above so go back
						while not waterAbove do
							utils.goBack()	--  returns true if no object behind, but moves anyway
							waterAbove = utils.clearVegetation("up")
							moves = moves - 1
							if moves == 0 then
								T:up(1)
								D.depth = D.depth - 1
								waterAbove = utils.clearVegetation("up")
								while not waterAbove do
									T:up(1)
									D.depth = D.depth - 1
								end
							end
						end
						-- go up 1 to prevent loop
						T:up(1)
						D.depth = D.depth - 1
					end
					waterAbove = utils.clearVegetation("up")
					waterAhead = utils.clearVegetation("forward")
				end
			end
		end
		D.width = D.width + 1	-- another length completed so increase width
		D.maxDepth = D.maxDepth + 1 -- +1 to allow for starting pos in top layer

		--return D
	end

	function lib.checkArches()
		-- gone under a block so could be monument arch (6)
		if T:getBlockType("up"):find("prismarine") ~= nil then -- confirm on monument, not previously cleared
			local direction = "" 	-- initialise direction
			T:go("B1U2F1R1")
			if T:getBlockType("forward"):find("prismarine") ~= nil then -- correct guess
				direction = "R"
			else	-- wrong direction. turn round and check other side
				T:go("R2")
				if T:getBlockType("forward"):find("prismarine") ~= nil then
					direction = "L"
				end
			end
			local path = "U1F1 U1F3 D1F1 D1R2 U2F5 D2"
			--for i = 1, 6 do
			T:go(path) -- clears arch top 1 and returns
			T:go(direction.."1F6"..direction.."1")
			T:go(path) -- clears arch top 2 and returns
			T:go(direction.."1F6"..direction.."1")
			T:go(path) -- clears arch top 3 and returns
			T:go(direction.."1F9"..direction.."1")
			T:go(path) -- clears arch top 4 and returns
			T:go(direction.."1F6"..direction.."1")
			T:go(path) -- clears arch top 5 and returns
			T:go(direction.."1F6"..direction.."1")
			T:go(path) -- clears arch top 6 and returns

			T:go(direction.."3F34"..direction.."2D2F1")
			D.monumentArchesClear =  true
		end
		--return D
	end

	function lib.checkTop()
		-- gone over 3 block column so could be at the top of ocean monument
		if T:getBlockType("down"):find("prismarine") ~= nil then -- confirm on monument, not previously cleared
			local direction = "" 	-- initialise direction
			T:go("U3R1")			-- up to top of column and try right side
			if T:getBlockType("forward"):find("prismarine") ~= nil then -- correct guess
				direction = "L"
			else	-- wrong direction. turn round and check other side
				T:go("R2")
				if T:getBlockType("forward"):find("prismarine") ~= nil then
					direction = "R"
				end
			end
			if direction ~= "" then -- facing single block on layer 2
				T:go("U1F6"..direction.."1F5".. direction.."1F5"..direction.."1F5"..direction.."1") -- clear 4 single blocks
				T:go("F1U1"..direction.."1F1"..direction.."3") -- on top of monument
				T:go("F3".. direction.."1F3"..direction.."1F3"..direction.."1F3"..direction.."3") -- clear top, face return
				T:go("F2D5"..direction.."3B1")
			end
			D.monumentTopClear = true
		end
		--return D
	end

	function lib.findBlockTypeEnd()
		D.blockType = "" -- reset
		repeat
			if utils.clearVegetation("forward") then
				T:forward(1)
				lib.clearDown() -- go down if in water/air, D.blockType is updated with floor type
			else -- block in front
				local waterAbove = utils.clearVegetation("up")
				local waterAhead = utils.clearVegetation("forward") -- true if air/water in front
				while not waterAhead do 	-- solid block in front
					if waterAbove then 		-- move up
						T:up(1)
					else 					-- block above so go back
						while not waterAbove do
							utils.goBack()	--  returns true if no object behind, but moves anyway
							waterAbove = utils.clearVegetation("up")
						end
					end
					waterAbove = utils.clearVegetation("up")
					waterAhead = utils.clearVegetation("forward")
				end
			end
		until D.blockType:find(D.useBlockType) == nil
		-- now above a non-prismarine block, facing away from monument
		T:turnRight(2) -- facing monument
		D.blockType = T:getBlockType("forward")
		while D.blockType:find(D.useBlockType) ~= nil do
			T:up(1)
			D.blockType = T:getBlockType("forward")
		end
		T:go("F1L1")
		D.blockType = T:getBlockType("down")
		while D.blockType:find(D.useBlockType) ~= nil do
			T:forward(1)
			D.blockType = T:getBlockType("down")
		end
		turtle.back()
		-- should now be at end of monument base
	end

	function lib.turn()
		local direction = "R"
		if not D.facingForward then
			direction = "L"
		end
		T:go(direction.. 1)
		if utils.clearVegetation("forward") then
			T:forward(1)
			--D.depth = D.depth + lib.clearDown(depth)
			lib.clearDown()
		else
			while not utils.clearVegetation("forward") do
				T:up(1)
				D.depth = D.depth - 1
			end
			T:forward(1)
		end
		T:go(direction.. 1)
		D.facingForward = not D.facingForward

		--return D
	end

	if R.data == "clearWaterPlants" or R.data == "maxDepth" then -- NOT monument corner discovery
		D.inWater, D.onWater = utils.startWaterFunction(D.onWater, D.inWater, 2, true) -- move into water
		if R.length == 0 then
			R.length = lib.getLength()
		end
		if R.width == 0 then
			T:turnRight(1)
			R.width = lib.getLength()
			T:turnLeft(1)
		end
	end
	D.length = R.length
	lib.clearDown() -- go down to floor, set depth, maxDepth, blockType
	if R.data == "clearWaterPlants" or R.data == "maxDepth" then -- NOT monument corner discovery
		if R.width == 1 then
			print("Single row clearing")
			lib.clearLength() --D.width also increased
		else
			while D.width < R.width do -- D.width starts at 0
				-- now on floor, move along sea/river bed following contour
				lib.clearLength() --D.width also increased
				-- now turn and repeat
				if D.width < R.width then
					lib.turn()
					if D.depth <= 0 then
						break
					end
				end
			end
		end
		-- finished so return to surface
		if R.data == "clearWaterPlants" then
			T:up(1) -- up 1 to check for water below
			while T:getBlockType("down"):find("water") ~= nil do
				T:up(1)
			end
			T:down(2) -- return to surface
			--[[while utils.clearVegetation("forward") do
				T:forward(1)
			end]]
		else
			T:go("U"..(D.maxDepth + 1).."R2F"..R.length.."R2")
		end
	elseif R.data == "clearMonumentArches" then -- clear under monument arches
		D.length = 8
		D.monumentTopClear = true
		D.monumentArchesClear = true
		D.useBlockType = ""
		lib.clearLength()
	elseif R.data == "oceanMonumentColumns" then -- monument corner discovery
		-- this function used to find edge of monument base
		if D.blockType:find(D.useBlockType) ~= nil then
			lib.findBlockTypeEnd()
			return {""}
		else
			T:up(D.depth)
			return {"Prismarine not found on ocean floor"}
		end
	end
	if R.silent then
		return {D.maxDepth, R.length}
	else
		return {""}
	end
end

function convertWater()
	--[[
	if dry need enough buckets to place along (width + length - 1) / 2
	use 12 buckets
	start on floor + 1
	place slab down and water up along 2 edges. stay on this level
	return round same 2 edges removing slabs and and placing them 1 above
	placeUp water onto slabs on both edges
	repeat recover slabs, place 1 above , placeUp water

	for sloping water, place full area with slabs
	place sloping water on top of slabs
	remove slabs

	]]
	local lib = {}

	function lib.checkStartPosition()
		--[[
		0 T             -- T=turtle, W=wall, S=source, F=flowing
		1 W|S|F|F|F|F|F -- sloping flowing water
		2 W|F|F|F|F|F|F -- blocks removed after placing flowing water above
		3 W|S|S|S|S|S|S -- original sources
		4 W|?|?|?|?|?|? -- may be sources
		]]
		-- need to be on floor or R.height if specified
		local depth = 0
		local blockType = T:getBlockType("down")
		local isWaterUp, isSourceUp = T:isWater("up")
		local isWaterForward, isSourceForward = T:isWater("forward")
		local isWaterDown, isSourceDown = T:isWater("down")
		print("Block below is "..blockType)
		print("Water above is "..tostring(isWaterUp))
		print("Water forward is "..tostring(isWaterForward))
		print("Water below is "..tostring(isWaterDown))
		if blockType:find("water") == nil then -- on at least level 0
			print("Moving forward in 2 seconds...")
			sleep(2)
			T:forward(1)
			blockType = T:getBlockType("down")
			if blockType:find("water") ~= nil then
				print("Water found. Going down to floor")
				depth = -1
			else
				T:down(1)
				blockType = T:getBlockType("down")
				if blockType:find("water") ~= nil then
					depth = -2
				else
					return 0, "Not close to water. Aborting..."
				end
			end
		end
		while turtle.down() do
			depth = depth + 1
		end
		local emptyBuckets = utils.getEmptyBucketCount()
		for i = depth, 0, -1 do
			if emptyBuckets > 0 then
				lib.fillBuckets()
				emptyBuckets = utils.getEmptyBucketCount()
			end
			turtle.up()
		end

		return depth, ""
	end

	function lib.fillBuckets()
		local emptyBuckets = utils.getEmptyBucketCount()
		local direction = "forward"-- start with forward
		local isWater, isSource, isIce = T:isWater(direction)
		if emptyBuckets > 0 then
			if not isSource then
				direction = "down"
				isWater, isSource, isIce = T:isWater(direction)
				if not isSource then
					direction = "up"
					isWater, isSource, isIce = T:isWater(direction)
					if not isSource then
						direction = ""
					end
				end
			end
			if direction == "" then
				print("Unable to locate water source")
			else
				for i = 1, emptyBuckets do
					if utils.fillBucket(direction) then
						print("Bucket filled "..direction)
						sleep(0.3)
					else
						print("Unable to fill bucket ".. i .." / "..emptyBuckets)
					end
				end
			end
		end
		return utils.getWaterBucketCount()
	end

	function lib.placeSlabs(length)
		for i = 1, length do
			T:place("slab", "down", false)
			if i < length then
				T:forward(1)
			end
		end
	end

	function lib.placeSources(length, place)
		local moves = 1
		local waterBuckets = utils.getWaterBucketCount()
		-- place sources alternate positions + start and finish
		while moves < length do
			if place then
				if T:placeWater("up") then
					print("Placed source up")
					waterBuckets = waterBuckets - 1
				end
			end
			place = not place
			if moves < length then
				T:forward(1)
				moves = moves + 1
			end
			if waterBuckets == 0 then
				T:down(1) -- break the slab below
				waterBuckets = lib.fillBuckets()
				T:up(1)
				T:place("slab", "down", false)
			end
		end
		if T:placeWater("up") then -- end of length
			print("Placed final source up")
		end
		return place
	end

	function lib.moveSlabs(length)
		for i = 1, length do
			T:dig("down")
			T:up(1)
			T:place("slab", "down", true)
			if i < length then
				T:forward(1)
				T:down(1)
			end
		end
	end

	function lib.recoverSlabs(length)
		for i = 1, length do
			T:dig("down")
			if i < length then
				T:forward(1)
			end
		end
	end

	local depth, message = lib.checkStartPosition()
	if message ~= "" then
		return {message}
	end
	local maxDepth = R.height
	local buckets = utils.getWaterBucketCount()
	utils.calculateDimensions() -- if R.width or R.length == 0
	T:down(depth)
	lib.placeSlabs(R.length)
	T:go("R1")
	lib.placeSlabs(R.width)
	T:go("R2")

	while depth > 0 do
		local place = true
		lib.fillBuckets()
		place = lib.placeSources(R.width, place)
		T:go("L1")
		place = lib.placeSources(R.length, place)
		lib.fillBuckets()
		T:go("R2")
		lib.moveSlabs(R.length) -- dig slab from below, move up and replace below
		T:go("R1F1D1")
		lib.moveSlabs(R.width - 1)
		T:go("R2") -- now moved up 1 layer
		depth = depth - 1
		if depth == 0 then
			place = lib.placeSources(R.width, true)
			T:go("L1")
			place = lib.placeSources(R.length, place)
			T:go("R2")
			lib.recoverSlabs(R.length)
			T:go("R1")
			lib.recoverSlabs(R.width)
		end
	end

	return {}
end

function createIceCanal()
	--[[
		R.position =
		1: Remove block above and below, place slabs, blocks and torches if > 0
		2: Remove block above, place ice alternating below or 3
		3: Remove block above and below or 2
		4: Remove block above and below, place slabs, blocks and torches if > 0
	]]
	local turn = "L"
	local oTurn = "R"

	R.side = "L"
	if R.position == 3 or R.position == 4 then
		R.side = "R"
		turn = "R"
		oTurn = "L"
	end

	local lib = {}

	function lib.convertTowpath()
		-- tk3 water canal already uses slabs for towpath. Does NOT need converting
		-- only used to convert existing water canal, so assume towpath already present
		-- starting position 1 block above existing towpath
		for i = 1, R.length do
			if turtle.detectDown() then							-- eg existing torch
				T:dig("down")
			end
			local placeSlab = true
			if R.torchInterval > 0 then							-- place torches
				if i == 1 or i % R.torchInterval == 0 then		-- ready to place torch
					--go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
					T:go("C2x0", false, 0, false, R.useBlockType)-- place solid block below
					T:go("F1R2x0")
					T:place("torch", "forward")				-- place torch, move forward
					T:turnRight(2)								-- turn round
					placeSlab = false
				end
			end
			if placeSlab then
				T:dig("up")
				if not T:place("slab", "down") then			-- break if out of slabs
					break
				end
				if i < R.length then
					T:forward(1)								-- move forward
				end
			end
		end
	end

	function lib.icePath()
		-- use only for placing ice to convert a water canal
		-- place ice on alternate blocks until length reached or run out of ice
		local placeIce = true
		--Log:saveToLog("Placing ice")
		for i = 1, R.length do
			if turtle.detectUp() then
				T:go("U2x0D2")
			end
			if T:getBlockType("down"):find("ice") == nil then -- no ice below
				T:dig("down") -- remove any existing block
				if placeIce then
					--Log:saveToLog("Placing ice i = "..i)
					if not T:place("ice", "down", true) then -- out of ice
						break
					end
					if i == R.length - 1 then
						break
					end
				end
			else -- ice already below
				placeIce = true
			end
			--T:go("U1x0 D1F1")
			T:forward(1)
			placeIce = not placeIce -- reverse action
		end
	end

	function lib.airPath()
		-- tk3 water canal alredy at correct height. Does NOT need converting
		-- use only for converting a water canal. start at ground level
		-- dig up/down/forward to clear space
		for i = 1, R.length + 1 do
			if turtle.detectUp() then
				T:go("U2x0D2")
			end
			if turtle.detectDown() then
				turtle.digDown()
			end
			if i < R.length + 1 then
				T:forward(1)
			end
		end
	end

	if R.length == 0 then
		R.length = 512
	end

	R.useBlockType = T:getMostItem("", true)
	--Log:saveToLog("createIceCanal() R.floor = "..tostring(R.floor))
	-- R.floor = true if ice placed by this turtle
	if R.data == "new" or R.data == "" then
		if R.position == 1 or R.position == 4 then	-- towpath
			utils.towpathOnly() -- places torches if R.torchInterval > 0
		elseif R.position == 2 or R.position == 3 then -- ice or air
			if R.floor then	-- place ice
				lib.icePath()
			else 	-- dig 3 blocks
				lib.airPath()
			end
		end
	elseif R.data == "convert" then
		if R.position == 2 or R.position == 3 then			-- over water
			if R.floor then									-- assume placed on existing ice or initial ice position
				lib.icePath()						-- place ice
			else											-- assume placed on empty path
				lib.airPath()							-- clear 3 high area
			end
		elseif R.position == 1 or R.position == 4 then
			if T:getBlockType("down"):find("slab") ~= nil then 	-- slab already present
				T:go("F1")
			else
				T:up(1)
			end
			lib.convertTowpath()
		end
	end

	return {}
end

function createLadderToWater()
	-- go down to water/lava with alternaate solid/open layers
	-- create a working area at the base
	-- Return to surface facing towards player placing ladders
	local inAir = true
	local numBlocks, errorMsg = 0, ""
	local height = 2
	local blockType = T:getBlockType("down")
	if blockType ~= "" then -- not over air
		T:forward(1)
	end
	T:go("R2D1") -- face player, go down 2
	while inAir do --success = false when hits water/lava
		blockType = T:isWaterOrLava("down")
		if blockType:find("water") ~= nil or blockType:find("lava") ~= nil then
			inAir = false
		end
		T:go("C1R1 C1R2 C1R1", false, 0, false)	-- surround front  and sides with cobble
		if inAir then
			T:down(1)
			height = height + 1
		end
		T:place("ladder", "up")
	end
	-- In shaft, facing opposite start direction, on water/lava, ladders above
	T:go("C2", false, 0, false)
	utils.goBack(1)
	T:place("ladder", "forward")
	T:up(3)
	height = height - 3
	for i = 1, height do
		if i < height then
			T:go("C2U1", false, 0, false)
		else
			T:go("C2", false, 0, false)
		end
	end

	return {}
end

function createSlopingWater()
	--[[
	creates a sloping water area above existing lake/river/ocean
	R.width is usually 7 with an existing wall on 8th row
	R.length  is user choice, limited to bucket/slab quantities
	Places slabs into existing surface, places row of sources
	Removes slabs
	]]
	local lib = {}

	function lib.fillBuckets()
		local emptyBuckets = utils.getEmptyBucketCount()
		for i = 1, emptyBuckets do
			if utils.fillBucket("down") then
				print("Bucket filled down")
				sleep(0.3)
			else
				print("Unable to fill bucket ".. i .." / "..emptyBuckets)
			end
		end
		return utils.getWaterBucketCount()
	end

	local outbound = true
	local inWater, onWater = utils.getWaterStatus()
	inWater, onWater = utils.startWaterFunction(onWater, inWater, 2 ,false) -- move above water, max descent 2
	local waterBuckets = lib.fillBuckets()
	for w = 1, R.width do
		for l = 1, R.length do
			T:place("slab", "down", false)
			if l < R.length then
				T:forward(1)
			end
		end
		if w < R.width then
			if outbound then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
			outbound = not outbound
		end
	end
	if outbound then
		T:go("L1F"..R.width - 1 .."L1")
	else
		T:go("R1F"..R.width - 1 .."R1")
	end
	T:placeWater("up")  -- place in corner
	local move = true
	while move do
		move = turtle.forward()
		move = turtle.forward() -- false if at end of run
		T:placeWater("up")  -- alternate positions + end of run
	end
	T:go("R2D1")
	T:sortInventory() -- get all buckets into 1 slot
	for w = 1, R.width do
		for l = 1, R.length do
			if l < R.length then
				T:forward(1)
			end
		end
		if w < R.width then
			if outbound then
				T:go("R1F1R1")
			else
				T:go("L1F1L1")
			end
			outbound = not outbound
		end
	end
	if outbound then
		T:go("L1F"..R.width - 1 .."L1")
	else
		T:go("R1F"..R.width - 1 .."R1")
	end
	T:go("U2")

	return {}
end

function createWaterCanal()
	--[[
	designed for 4 turtles, but can be done with 2 as well
	R.data = 1 (2 turtles) or 2 (4 turtles)
	R.height = 0 (in water/ on canal floor) or 1 (at ground level)
	R.side = "R" or "L"
	R.subChoice =
		1 = left side, ground level (on towpath)
		2 = left side above canal water (new canal only)
		3 = right side above canal water (new canal only)
		4 = right side, ground level (on towpath)
		5 = left side in canal water (if present)
		6 = right side in canal water (if present)

	if R.height = 0 then already at correct height on canal floor
		check block below, block to left and block above, move forward tunnelling
		if entering water then move up, onto canal wall and continue pathway
		if tunnelling then flood canal
	else R.height = 1 then above water and on path across
		move forward, checking for water below
		if water finishes, move into canal, drop down and continue tunnelling
	]]
	local turn = "L"
	local oTurn = "R"
	local lib = {}

	function lib.fillEmpty(direction)
		direction = direction or "forward"
		local blockType = T:getBlockType(direction)
		if blockType == "" then	-- air
			T:place("stone", direction)
		end
	end

	function lib.newCanalSide()
		T:go("U1x1")
		T:place("slab", "forward")					-- place slab on ground level
		--if turtle.detectUp() then
			--T:go("U1x1 U1x1 U1x1 D4")				-- go up 3 removing blocks ahead and up. back to water level
		--else
			--T:down(1)								-- back to water level
		--end
		local moves = 0
		while turtle.detectUp() and moves <= 3 do
			T:up(1)
			moves = moves + 1
		end
		T:down(moves)
	end

	function lib.newSource()
		-- levels: 0 = water, 1 = path, -1 = canal floor
		-- rows 0 = canal back, 1,2,3, = water source
		--starts facing away from canal at back wall level 0				   |V|V|  0, 1
		T:go("C1D1"..turn.."1") -- facing opposite side under base 		   |>|<| -1, 1										   			-- |>|<| -1, 1
		lib.fillEmpty("forward")

		T:go(turn.."1F1"..oTurn.."1") -- facing opposite side under base 2	   |>|<| -1, 2
		lib.fillEmpty("forward")

		T:go(turn.."1F1"..oTurn.."1") -- facing opposite side under base 3	   |>|<| -1, 3
		lib.fillEmpty("forward")

		T:go(turn.."1U1C1"..turn.."1C1C2 "..turn.."1F1"..oTurn.."1C1C2"..turn.."1F1"..oTurn.."1C1C2"..oTurn.."1F1")
		-- | |C|C| | 0, 4
		-- |C| | |C| 0, 3
		-- |C|^|^|C| 0, 2
		-- |C| | |C| 0, 1
		-- | |C|C| | 0, 0
		T:placeWater("forward") 							-- |C|W|W|C| 0, 3
		T:go(turn.."2")										-- |C|V|V|C| 0, 2
		T:placeWater("forward") 							-- |C|W|W|C| 0, 1
		T:go("F1"..turn.."2")								-- |C|^|^|C| 0, 1
		-- ends at back of canal/water source, facing down canal
	end

	function lib.initialiseCanal()
		--[[ move turtle to correct position. return moves]]
		local newCanal, isWater, isSource = false, false, false
		--if R.subChoice == 1 or R.subChoice == 4 then 	-- left / right side on towpath- move into canal space
		if R.position == 1 or R.position == 4 then 		-- left / right side on towpath- move into canal space
			T:go(oTurn.."1F1D1"..oTurn.."1") 		-- move into canal, face back along any existing canal
			isWater, isSource = T:isWater("forward")
			if isSource then
				T:go(turn.."2") 					-- face forward for new canal
			else
				newCanal = true
			end
		elseif R.position == 2 or R.position == 3 then	-- left / right side above canal finishing pos if deletesWater
			T:go("D1"..R.side.."2")					-- facing existing on canal floor
			isWater, isSource = T:isWater("forward")
			if isSource then						-- water ahead
				T:go(R.side.."2")					-- face forward for new canal
			else
				newCanal = true
			end
		end

		if newCanal then 								-- no water ahead, facing start wall of new canal *|<| | |
			lib.newSource() 							-- start new canal, finish facing new canal 6 block water sources
		end

		--return 1 									-- facing forward ready for new canal *|>| | |
	end

	function lib.waterOnly()
		-- Already in position facing new canal, 2 water buckets
		local sourceCount = 0								-- allow for 1 iteration of placing source blocks when changing from solid to water
		local numBlocks = 0									-- distance travelled
		local _, isSource = nil, false						-- initialise variables

		while numBlocks < R.length do						-- loop from here. Facing forwards to extend canal
			numBlocks = numBlocks + 1						-- inrease block count
			T:forward(1) 								-- move forward to extend canal
			_, isSource = T:isWater("forward")			-- check if source water ahead
			if isSource then							-- ? source ahead
				sourceCount = sourceCount + 1
			else
				sourceCount = 0
				if not turtle.detectDown() then			-- air / water below, but no source in front, so fill it
					T:go(oTurn.."1D1")					-- ready to repair neighbouring canal base
					lib.fillEmpty("forward")			-- repair neighbouring canal base
					T:go(turn.."1U1C2")					-- place block below if not already source
				end
			end
			local moves = 0
			while turtle.detectUp() and moves <= 3 do
				T:up(1)
				moves = moves + 1
				--T:go("U2x0D1")							-- up 1 and excavate blocks above canal. return to canal base
			end
			T:down(moves)

			--T:go(turn.."1C1"..oTurn.."1", false, 0, true) -- face canal wall, replace with stone if empty, face forward
			T:go(turn.."1")
			lib.fillEmpty("forward")
			T:go(oTurn.."1")
			if not isSource	and sourceCount == 0 then	-- not source in front, or first time found, ensures continous canal
				T:go("C1", false, 0, true) 				-- 0| | | |>| face along new canal and block entrance
				utils.goBack(1)							-- 0| | |>| | back 1
				T:placeWater("forward")					-- 0| | |>|W| place water
				T:go(oTurn.."2") 						-- 0| | |<|W| face existing canal
				_, isSource = T:isWater("forward")		-- 0| |?|<|W| check if source water ahead
				if not isSource then
					if not T:placeWater("forward") then	-- place water again 0| |W|<|W|
						while not T:getWater("forward") do -- wait for other turtle
							print("Out of water buckets")
							sleep(1)
						end
						sleep(0.2)
						T:placeWater("forward")
					end
				end
				utils.getWater() 						-- collects 2 water 0| |W|<|W|
				T:go(turn.."2F1") 						-- face along new canal *| |W|>|W| to *| |W|W|>|
			end
		end
	end

	function lib.waterPath()
		-- Already in position facing new canal, 2 water buckets
		local sourceCount = 0								-- allow for 1 iteration of placing source blocks when changing from solid to water
		local _, isSource = nil, false						-- initialise variables

		for i = 1, R.length do								-- loop from here. Facing forwards to extend canal
			T:go(turn.."1")									-- face towpath at water level
			if R.torchInterval > 0 then						-- place torches
				if i == 1 or i % R.torchInterval == 0 then
					T:go("U1x1") 							-- up to towpath level
					T:place("stone", "forward")				-- place block on ground level
					T:go("U1x1 U1x1 U1x0 F1x0 D1")						--
					T:place("torch", "down")				-- place torch	on block
					T:go("B1D3")
					--utils.goBack(1)
					--T:down(3)								-- back to water level
				else
					lib.newCanalSide()
				end
			else
				lib.newCanalSide()
			end
			T:go(oTurn.."1")								-- face front of canal at water level
			-- side of canal has been excavated, slab or torch placed
			-- now continue adding water to canal length
			_, isSource = T:isWater("forward")			-- check if source water ahead
			if isSource then							-- ? source ahead
				sourceCount = sourceCount + 1
			else
				sourceCount = 0
				if not turtle.detectDown() then			-- air / water below, but no source in front, so fill it
					T:go(oTurn.."1D1")					-- ready to repair neighbouring canal base
					lib.fillEmpty("forward")			-- repair neighbouring canal base
					T:go(turn.."1U1C2")					-- place block below if not already source
				end
			end

			T:go(turn.."1")								-- face towpath at water level
			lib.fillEmpty("forward")					-- close gap if air (water left alone)
			T:go(oTurn.."1")
			if not isSource	and sourceCount == 0 then	-- not source in front, or first time found, ensures continous canal
				T:go("C1", false, 0, true) 				-- 0| | | |>| face along new canal and block entrance
				utils.goBack(1)							-- 0| | |>| | back 1
				T:placeWater("forward")					-- 0| | |>|W| place water
				T:go(oTurn.."2") 						-- 0| | |<|W| face existing canal
				_, isSource = T:isWater("forward")		-- 0| |?|<|W| check if source water ahead
				if not isSource then
					if not T:placeWater("forward") then	-- place water again 0| |W|<|W|
						while not T:getWater("forward") do -- wait for other turtle
							print("Out of water buckets")
							sleep(1)
						end
						sleep(0.2)
						T:placeWater("forward")
					end
				end
				utils.getWater() 						-- collects 2 water 0| |W|<|W|
				T:go(turn.."2F1") 						-- face along new canal *| |W|>|W| to *| |W|W|>|
				T:forward(1) 								-- move forward to extend canal
			end
		end
	end

	R.useBlockType = T:getMostItem("", true)
	if R.length == 0 then
		R.length = 512
	end
	R.side = "L"
	if R.position == 3 or R.position == 4 or R.position == 6 then
		R.side = "R"
		turn = "R"
		oTurn = "L"
	end
	menu.clear()
	menu.colourWrite("Building canal "..R.side.." side", colors.yellow, nil, nil, false, true)
	if R.turtleCount == 2 then 		-- 2 turtles
		if R.position < 5 then		-- R.position 5 & 6 already in water canal
			lib.initialiseCanal() 	-- move to correct position and/or start new canal
		end
		lib.waterPath()									-- construct towpath and canal at same time
	else -- 4 turtles (default)
		if R.position == 1 or R.position == 4 then 		-- towpath
			utils.towpathOnly()
		else
			if R.position < 5 then		-- R.position 1, 4 already checked, so 2, 3 only
				lib.initialiseCanal() 	-- move to correct position and/or start new canal
			end
			lib.waterOnly()
		end
	end

	return {}
end

function drainWaterLava()
	-- repeatedly deletes water with row of stone to right
	local lib = {}

	function lib.startCorner()
		-- assume starting mid 3 high column
		T:go("D1C1R1C1 U1C1 L1C1 U1C1 R1C1 L1D1 C2C0", false, 0, true)
		-- finished on same mid 3 high column with wall in front and right completed
	end

	function lib.midWall()
		-- assume starting mid 3 high column
		T:go("D1R1C1 U1C1 U1C1 L1D1 C2C0", false, 0, true)
		-- finished on same mid 3 high column with wall on right completed
	end

	function lib.endCorner()
		-- assume starting mid 3 high column
		T:go("D1R1C1 R1C1 U1C1 L1C1 U1C1 R1C1 L2D1 C2C0", false, 0, true)
		-- finished on same mid 3 high column with wall behind and right completed
	end

	function lib.backTurn(offset)
		-- assume starting mid 3 high column with completed wall behind
		T:go("L1F"..offset.."L2C1 R1D1C1 U1C1 U1C1 D1")
		-- end next row along the width, facing the back, mid point
		-- wall ahead completed
	end

	function lib.frontTurn()
		-- assume starting mid 3 high column facing back
		-- next move is to turn toward previous wall and remove

		T:go("L2D1C1 U1C1 U1C1 D1R1 C2C0 F1R2C1 L1")
		-- end facing back ready to remove wall
	end

	function lib.buildWall(height)
		-- starts 1 block below surface facing across length of water/lava/water
		-- builds 3 high wall ending at starting position
		-- any blocks found along the way are removed
		for i = 1, R.length do
			if i < R.length then
				if height == 3 then
					T:go("C0C2F1")
				else
					T:go("C2F1")
				end
			else
				if height == 3 then
					T:go("C0C2")
				else
					T:go("C2")
				end
			end
		end
		for i = 1, R.length - 1 do
			turtle.back()
			T:place(R.useBlockType, "forward")
		end
	end

	function lib.removeWall(height)
		-- starts centre block of 3 high wall
		-- removes all blocks , ending at perimeter wall
		for i = 1, R.length do
			if i < R.length then
				if height == 3 then
					T:go("x0x2F1")
				else
					T:go("x2F1")
				end
			else
				if height == 3 then
					T:go("x0x2")
				else
					T:go("x2")
				end
			end
		end
	end

	function lib.placeRetainingWall(distance)
		-- assume starting above 3 block high area facing front (player)
		--T:down(1)
		for i = 1, distance do
			if i == 1 then -- start wall
				lib.startCorner()
			else
				if i < distance then -- mid wall
					lib.midWall()
				else -- end of the wall
					lib.endCorner()
				end
			end
			if i < distance then
				if not turtle.back() then
					T:go("R2F1R2")
				end
				T:go("C1", false, 0, true)
			end
		end
		return 1
	end

	function lib.startWall(height)
		lib.buildWall(height)				-- col 1: 1st wall, return to start position
		T:go("R1F1 R2C1 R1")			-- col 2: ready for parallel wall
		lib.buildWall(height)				-- col 2: first 2 walls built. facing far side
		T:go("L1F1 R2C1 L1")			-- col 1: facing far side, retaining wall to right
		lib.removeWall(height)			-- col 1: wall removed, now at far side facing start
		T:go("R2F"..(R.length - 1)) 	-- col 1: start position, facing wall, ready for loop
	end

	function lib.placeDam(distance)
		--T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		local waterPresent = false
		for i = 1, distance do
			if T:isWater("down") then
				waterPresent = true
			end
			T:go("C0C2")
			if i < distance then
				if not turtle.back() then
					T:go("R2F1R2")
				end
				T:go("C1", false, 0, true)
			end
		end
		return waterPresent
	end

	function lib.removeDam(distance)
		-- facing towards back, dig wall up down and ahead
		for i = 1, distance do
			T:go("x0x2")
			if i < distance then
				T:forward(1)
			end
		end
		T:turnRight(2)
		-- end up back to retaining wall, mid point
	end

	R.useBlockType = T:getMostItem("", false)
	if R.data == "" then
		if turtle.detectDown() then -- on solid surface
			turtle.forward()
		end
	end

	if deletesWater then --turtle replaces source so use clearSolid()
		R.silent = true
		R.down = true
		R.up = false
		clearSolid()
	else -- mc 1.12.15+ turtle does NOT replace source blocks
		-- place first stone along the length of water and measure length
		if R.data == "enclosed" then	-- eg ocean monument all walls built

			if R.height == 0 then				-- get max depth
				local tempWidth = R.width
				R.data = "maxDepth"
				R.silent = true
				R.width = 1
				R.length = 0
				local data = clearWaterPlants()		-- {D.maxDepth, R.length} will alreay be at starting position
				R.width = tempWidth
				R.height = data[1]
			else
				if R.length == 0 then				-- get length
					T:forward(1)
					R.length = utils.calculateDistance(0)
					utils.goBack(R.length)
					R.length = R.length - 1
				end
				if R.width == 0 then				-- get width
					T:go("F1R1")
					R.width = utils.calculateDistance(0) - 1
					T:go("R2F"..(R.width).."R1B1")
				end
			end
			local wall = 2							-- wall height
			local depth = 2
			if R.height >= 3 then
				wall = 3
				depth = 3
			end
			if R.height >= 3 then
				T:go("F1D2")						-- col 1: move into water down 2.
			else
				T:go("F1D1")						-- col 1: move into water down 2.
			end
			if R.width == 1 then					-- single width stream
				while depth <= R.height do
					lib.buildWall(wall)				-- build wall, return to start position
					T:go("F1R2 C1F1 R2")			-- remove final water source
					lib.removeWall(wall)
					depth = depth + wall
					wall = 2
					if R.height - depth >= 3 then
						wall = 3
					end
					T:down(wall)
				end
				T:up(R.height)
			else
				local odd = false
				if R.width % 2 == 1 then
					odd = true
				end
				while depth <= R.height do
					lib.startWall(wall)
					local col = 1
					while col < R.width do
						if col == R.width - 1 and not odd then
							T:go("L1F1L1")
							lib.removeWall(wall)	-- ends far side
							T:go("L1F"..(R.width - 1).."L1F"..(R.length - 1).."R2")
							break
						end
						T:go("L1F2 R2C1 R1")		-- col 1, 3, 5  to 3, 5, 7 etc: cut through retaining wall, in water, facing far side
						col = col + 2
						lib.buildWall(wall)			-- col 3, 5, 7 etc: wall to far side, return to start
						T:go("L1F1 R2C1 L1")		-- col 3, 5, 7 to 2, 4, 6 etc: inside retaining wall at start
						col = col - 1
						lib.removeWall(wall)		-- col 2, 4, 6 etc: end at far side
						if col == R.width - 1 and odd then
							T:go("R1F1R1")
							lib.removeWall(wall)	-- ends start side
							T:go("R1F"..(R.width - 1).."R1")
							break
						end
						T:go("R1F2 R2C1 L1")		-- col 2, 4, 6 to 4, 6, 8 etc: cut through retaining wall, in water, facing start
						col = col + 2
						lib.buildWall(wall)			-- col 4, 6, 8 etc: wall to start side, return to far position
						T:go("R1F1 R2C1 R1")		-- col 4, 6, 8  to 3, 5, 7 etc:cut through inner wall, facing start
						col = col - 1
						lib.removeWall(wall)		-- col 3, 5, 7 etc: end at start
					end
					depth = depth + wall
					wall = 2
					if R.height - depth >= 3 then
						wall = 3
					end
					T:down(wall)
				end
			end
		else
			if R.width == 0 or R.length == 0 then
				utils.calculateDimensions()
			end
			local depth = 0
			for h = 1, R.height do
				local waterPresent = false -- resets at each level
				local row = 0
				T:go("R2D2", false, 0, true)	-- at start, level 2, facing towards the front, move backards
				--lib.startCorner()
				row = row + lib.placeRetainingWall(R.length)
				lib.backTurn(1)
				if lib.placeDam(R.length) then
					waterPresent = true
				end
				row = row + 1
				-- left side wall has been built, 2 rows of walls laid. row = 2
				while row < R.width - 1 do -- eg width=2, row=2, this will not run. width=5, row=2
					lib.frontTurn()
					lib.removeDam(R.length)
					lib.backTurn(2)
					if lib.placeDam(R.length) then
						waterPresent = true
					end
					row = row + 1
				end
				-- lay right wall
				lib.frontTurn()
				lib.removeDam(R.length)
				lib.backTurn(2)
				row = row + lib.placeRetainingWall(R.length)
				lib.frontTurn()
				lib.removeDam(R.length) -- faces to front on finish
				T:go("L1F1R1")
				lib.removeDam(R.length) -- faces to front on finish
				depth = depth + 3
				T:go("L1F"..R.width - 1 .."R1D1")
				if depth == R.height or not waterPresent then -- still replacing water
					T:up(depth - 1) -- when h == R.height will go up
					break -- in case water dries up before loop has completed
				end
			end
		end
	end
	return {}
end

function lavaRefuel()
	local lib = {}

	function lib.getLavaStrip(y)
		local block, blockType = T:isWaterOrLava("down") -- will automatically fill bucket with lava and refuel
		local length = 0
		local lavaPresent = false
		local full = false
		-- while lava below, just started or moved forward < 3
		while (block == "minecraft:lava" or block == "minecraft:flowing_lava" or length < 3) and not full do --will automatically fill bucket with lava
			if T:forward(1) then
				length = length + 1
				y = y + 1
			end
			block, blockType = T:isWaterOrLava("down")

			print("Block below: "..tostring(block))
			if block == "minecraft:lava" or block == "minecraft:flowing_lava" then
				lavaPresent = true
			end
			if Fuel.level() >= Fuel.limit() then
				full = true
				lavaPresent = false
			end
		end
		T:go("L2F"..length + 1)
		y = y - length - 1
		block, blockType = T:isWaterOrLava("down")
		while block == "minecraft:lava" or block == "minecraft:flowing_lava" do
			T:forward(1)
			y = y - 1
			block, blockType = T:isWaterOrLava("down")
		end
		turtle.back()
		y = y + 1
		T:go("L2")
		return lavaPresent, y
	end

	function lib.goHome(x, y)
		if y > 0 then
			utils.goBack(y)
		elseif y < 0 then
			T:forward(math.abs(y))
		end
		if x > 0 then
			T:go("L1F"..x.."R1")
		elseif x < 0 then
			T:go("R1F"..math.abs(x).."L1")
		end
	end

	print("Current fuel: "..Fuel.level().." / "..Fuel.limit())

	local lavaSlot = T:getItemSlot("minecraft:lava_bucket", -1)
	if lavaSlot > 0 then
		turtle.select(lavaSlot)
		T:refuel(0) -- 0=force refuel
	end
	T:refuel(0) -- 0=force refuel
	local x, y, width = 0, 0, 0
	local lavaPresent, y = lib.getLavaStrip(y)
	if R.side ~= 'C' then -- not a single strip
		while lavaPresent do
			width = width + 1
			if R.side == 'R' then -- do strip on the right
				T:go("R1F1L1")
				x = x + 1
			else
				T:go("L1F1R1")
				x = x - 1
			end
			lavaPresent, y  = lib.getLavaStrip(y)
			if Fuel.level() >= Fuel.limit() then
				lavaPresent = false
				print("Max fuel "..Fuel.limit() .. " achieved")
			end
		end
		if width <= 0 then
			width = 1
		end
		lib.goHome(x, y)
	end

	return {"Refuelled to "..Fuel.level()}
end


end
