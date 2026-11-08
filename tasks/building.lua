return function(utils, pp, dbug, netherBedrock, deletesWater, brick)
function buildGableRoof()
	--[[
	stairs placement:
	   _|   up

	   T L  forward
	   _
	    |   down

	]]
	local lib = {}

	function lib.placeRoof(outward)
		for i = 1, R.length + 2 do
			if R.useBlockType:find("stairs") ~= nil then
				T:place("stairs", "up")
			else
				T:go("C0", false, 0, false, R.useBlockType)
			end
			if i < R.length + 2 then
				if outward then
					T:go("L1F1R1")
				else
					T:go("R1F1L1")
				end
			end
		end
	end

	function lib.placeGable(outward)
		local width = R.width
		for h = 1, R.height do
			for w = 1, width do
				T:go("C1")
				if w < width then
					if outward then
						T:go("L1F1R1")
					else
						T:go("R1F1L1")
					end
				end
			end
			if h < R.height then
				if outward then
					T:go("R1F1L1U1")
				else
					T:go("L1F1R1U1")
				end
			end
			width = width - 2
			outward = not outward
		end
		return outward
	end

	local outward = true
	-- go to centre of end wall if odd no, or half width if even
	R.height = math.floor(R.width / 2)
	local isOdd = R.width % 2 == 1
	R.useBlockType = T:getMostItem()
	T:go("B1R1F"..R.height - 1 .."U"..R.height - 1)	-- top of roof, under top layer
	for h = 1, R.height + 1 do						-- place tiles on left side of roof
		lib.placeRoof(outward)
		if h < R.height + 1 then
			T:go("B1D1")
			outward = not outward
		end
	end
	if isOdd then
		T:go("F"..R.height + 2 .."R2U"..R.height)
	else
		T:go("F"..R.height + 1 .."R2U"..R.height)
	end
	for h = 1, R.height + 1 do						-- place tiles on right side of roof
		lib.placeRoof(outward)
		if h < R.height + 1 then
			T:go("B1D1")
			outward = not outward
		end
	end
	-- gable ends
	if outward then
		T:go("F1R1U1")
	else
		T:go("F1L1U1")
	end
	outward = lib.placeGable(outward)
	T:go("F2R2 C1R2F"..R.length - 1 .."D"..R.height - 1)
	if outward then
		T:go("R1F"..R.height - 1 .."R1")
	else
		T:go("L1F"..R.height - 1 .."L1")
	end
	outward = not outward
	outward = lib.placeGable(outward)
	if isOdd then
		if outward then
			T:go("L1F1 R1U2 F1")
		else
			T:go("R1F1 L1U2 F1")
		end
		for i = 1, R.length do
			T:go("C2F1", false, 0, false)
		end
		for i = 1, R.length + 2 do
			utils.goBack(1)
			T:place("slab", "forward")
		end
	end
	while turtle.down() do end

	return {}
end

function buildPitchedRoof()
	--[[
	stairs placement:
	   _|   up

	   T L  forward
	   _
	    |   down

	]]
	local lib = {}

	function lib.placeRoofSection(length)
		-- starts facing centre of building
		for i = 1, length do
			if i < length then
				if R.useBlockType:find("stairs") ~= nil then
					T:place("stairs", "up")
				else
					T:go("C0", false, 0, false, R.useBlockType)
				end
				T:go("L1F1R1")
			end
		end
		-- ends facing centre of building
	end

	function lib.placeRoof(width, length)
		lib.placeRoofSection(length)
		T:go("R1")
		lib.placeRoofSection(width)
		T:go("R1")
		lib.placeRoofSection(length)
		T:go("R1")
		lib.placeRoofSection(width)
	end

	function lib.placeSlabs(length)
		-- add slabs at top
		T:go("U2F1L1")
		if length > 1 then
			T:forward(length - 3)
			for i = 1, length - 3 do
				T:place("slab", "forward")
				utils.goBack(1)
			end
			T:place("slab", "forward")
		else
			T:place("slab", "forward")
		end
		T:go("D2R1")
		utils.goBack(1)
	end
	--[[
	Turtle MUST be placed on left corner of shortest dimension

	****   or T******
	****      *******
	****      *******
	****
	T***
	shortest dimension is R.width
	if width is odd, ignore top layer as is only 1 block wide
	]]
	local isWidthOdd, isLengthOdd, width, length = false, false, 0, 0
	isWidthOdd, isLengthOdd, width, length = utils.getRoofStats()
	T:go("F"..R.height - 1 .."R1F"..R.height - 1 .."U"..R.height - 1)		-- top of roof, under top layer
	if isWidthOdd then
		lib.placeSlabs(length)
	end
	for h = 1, R.height + 1 do						-- place tiles on left side of roof
		lib.placeRoof(width, length)
		length = length + 2							-- increase dimensions
		width = width + 2
		if h < R.height + 1 then
			utils.goBack(1)
			T:go("D1R1")
			utils.goBack(1)
		end
	end
	while turtle.down() do end

	return {}
end

function buildStructure()
	local lib = {}

	function lib.goDown()
		--T:go("L1F1 R1F1 L1")	-- now on ground floor
		if R.height > 1 then
			T:down(1)
		end
	end
	local buildHeight = R.height
	local height = R.height
	local width = R.width
	local length = R.length

	if R.direction == "F" then
		T:forward(1)			-- face forward, move over first block
		R.direction = ""		-- do not move forward when building walls
	end
	if R.height > 3 then
		R.height = 3
	end
	T:turnRight(2)
	R.data = "house"
	R.silent = true	-- prevent return to ground after buildWall()
	R.subChoice = 2	-- do not move forward when building walls
	R.useBlockType = T:getMostItem("", false)
	while height > 0 do
		buildWall()

		lib.goDown()
		R.length = width - 1
		buildWall()
		lib.goDown()

		R.length = length - 1
		buildWall()
		lib.goDown()

		R.length = width - 2
		buildWall()
		height = height - R.height	-- 1, 2 or 3
		if height > 0 then
			T:go("U2 R1F1 L1F1")
			R.height = height
			if height > 3 then
				R.height = 3
			end
			R.length = length
		end
	end
	if not R.silent then	-- NOT called from another function
		T:go("U2F2")
		while turtle.down() do end
		T:go("R1F1R1")
	end

	return {}
end

function buildWall()
	-- T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	local lib = {}

	function lib.singleLayer()
		for l = 1, R.length do
			if l == R.length and R.data == "house" then
				T:turnRight(1)
			end
			utils.goBack(1)
			T:go("C1", false, 0, false, R.useBlockType)
		end
	end

	function lib.doubleLayer()
		for l = 1, R.length do
			T:go("C2", false, 0, false, R.useBlockType)
			if l == R.length and R.data == "house" then
				T:turnRight(1)
			end
			utils.goBack(1)
			T:go("C1", false, 0, false, R.useBlockType)
		end
	end

	function lib.tripleLayer()
		for l = 1, R.length do
			T:go("C2C0", false, 0, false, R.useBlockType)
			if l == R.length and R.data == "house" then
				T:turnRight(1)
			end
			utils.goBack(1)
			T:go("C1", false, 0, false, R.useBlockType)
		end
	end

	-- R.width preset to 1
	R.useBlockType = T:getMostItem("", false) -- no excluded blocks, any block type
	menu.colourPrint("Creating "..R.width.." x "..R.length.." walled enclosure", colors.yellow)
	menu.colourPrint("Using: "..R.useBlockType, colors.orange)
	local remaining = R.height

	if R.direction == "F" then
		T:forward(1)			-- face forward, move over first block
	end
	if R.height > 1 then
		T:up(1)					-- go up 1 block
	end
	if R.data ~= "house" then
		T:turnRight(2)				-- rotate 180
	end
	if R.height == 1 then		-- single block: place in front
		lib.singleLayer()
	elseif R.height == 2 then	-- 2 blocks, go backwards, place below and ahead
		lib.doubleLayer()
	else
		while remaining >= 3 do
			lib.tripleLayer()
			remaining = remaining - 3
			if remaining == 1 then
				T:go("U2F1R2")
			elseif remaining > 1 then
				T:go("U3F1R2")
			end
		end
		if remaining == 1 then
			lib.singleLayer()
		elseif remaining == 2 then
			lib.doubleLayer()
		end
	end
	if not R.silent then
		while turtle.down() do end
	end

	return {}
end

function clearBuilding()
	--[[
	menu item: Clear hollow structure
	Clear the outer shell of a building, leaving inside untouched. Optional floor/ceiling removal
	R.goUp = move upwards
	R.goDown = move downwards
	R.forward = move forward first
	R.ceiling = remove ceiling
	R.floor = remove floor
	R.down = go down first (above structure)
	R.width, R.length, R.height
	examples use a 5 x 5 x 7 cube
	]]
utils.logRvalues()
	local height = 1								-- current level of turtle
	local cleared = false							-- flag for cleared floor/ceiling
	R.silent = true
	if R.forward then
		T:forward(1)
		R.forward = false							-- reset so clearPerimeter() does not use it
	end
	if R.down then
		T:down(1)
	end
	R.up = false
	R.down = false								-- reset so clearRectangle() does not use it
	-- check if floor/ceiling is to be cleared
	if (R.goUp and R.floor) or (R.goDown and R.ceiling) then
		clearRectangle()	-- R.up and R.down
		cleared = true
	end

	if (R.height == 1 and not cleared) or (R.height == 2 and not cleared) then			-- only 1 layer, perimeter only eg R.height = 7
		if R.goUp then
			R.up = true
		else
			R.down = true
		end
		clearPerimeter()
	elseif R.height >= 3 then 						-- 3 or more levels, floor/ceiling already assessed eg R.height = 7
		height = height + utils.move(1)			-- move up/down 1 block for first layer eg height: 1 + 1 = 2
		-- height h + 3 R.height   loop
		--	2		5		5		end
		--	2		5		7		+
		--	5		8		7		end
		R.up = true		-- used in clearPerimeter to remove upper and lower blocks
		R.down = true
		repeat
			clearPerimeter()						-- runs at least once, removes 3 layers: 1,2,3
			local move = 3
			if height + 3 >= R.height then			-- range with min 3(0), 4(1), 5(2), 6(3), 7(4), 8(5), 9(6) etc
				move = R.height - height
			end
			height = height + utils.move(move)	-- move up/down 1-2 blocks eg height = 2 + 3 = 5
		until height > R.height - 3				-- min 3 levels eg height = 2, R.height - 3 --> 7 - 3 = 4, 4 - 3 = 1
		if height == R.height then				-- already on top/bottom layer eg height = 5, R.height = 5
			R.up = false
			R.down = false
			clearPerimeter()
		else
			clearPerimeter()
		end
	end

	R.up = false
	R.down = false
--Log:saveToLog("R.goUp = "..tostring(R.goUp)..", R.goDown = "..tostring(R.goDown)..", R.ceiling = "..tostring(R.ceiling)..", R.floor = "..tostring(R.floor))
	if (R.goUp and R.ceiling) or (R.goDown and R.floor) then		-- from bottom to top
		clearRectangle()
	end

	if height > 1 then
		utils.move(height - 1, true) -- reverse direction
	end

	return {}
end

function clearSandWall()
	--dig down while on top of sand/red_sand/soul_sand
	local lib = {}

	function lib.checkAbove(height)
		if turtle.detectUp() then -- moved under a ledge
			T:go("B1U1")
			height = height - 1
		end
		return height
	end

	function lib.moveDown(height)
		blockType = T:getBlockType("down")
		while blockType:find("sand") ~= nil do
			T:down(1)
			height = height + 1
			blockType = T:getBlockType("down")
		end
		return height
	end

	function lib.moveForward(length)
		local unload = false
		lib.digForward()
		T:forward(1)
		local count = T:getItemCount("sand")
		if count > 960 then
			unload = true
		end
		length = length + 1
		local blockType = T:getBlockType("forward")
		return length, blockType, unload
	end

	function lib.digForward()
		while turtle.detect() do
			turtle.dig()
		end
	end

	local moves  = 0
	local height = 0
	local length = 0
	local search = 0
	local unload = false
	local reverse = false
	local blockType = T:getBlockType("down")
	if R.length == 0 then
		R.length = 64
	end

	print("Checking for sand below")
	while blockType:find("sand") == nil do --move forward until sand detected or 3 moves
		T:forward(1)
		search = search + 1
		blockType = T:getBlockType("down")
		if search > 3 then
			T:go("B"..search)
			return {"Unable to locate sand"}
		end
	end
	-- must be sand below
	height = lib.moveDown(height)	-- go down if sand below
	-- repeat until height == 0
	repeat -- starts at bottom of sand wall
		blockType = T:getBlockType("forward")
		if blockType:find("sand") ~= nil then -- sand in front
			length, blockType, unload = lib.moveForward(length) -- move forward 1 and dig sand
			if unload then
				T:up(height)
				menu.clear()
				menu.colourText(1, "Inventory full. Unload and press Enter")
				read()
				T:down(height)
			end
			if blockType == "" or  blockType:find("sand") ~= nil then -- sand or nothing in front
				height = lib.moveDown(height)	-- go down if sand below
			end
		else -- solid block, air or water, not sand so move up
			if turtle.detect() then -- block in front
				blockType = T:getBlockType("down")
				if blockType:find("sand") ~= nil then -- sand below
					T:dig("down")
				end
				T:up(1)
				height = height - 1
			else -- air/water in front so move forward
				if length < 60 then -- in case missing wall and in open ocean
					length, blockType, unload = lib.moveForward(length) -- move forward 1 and dig sand
					if unload then
						T:up(height)
						menu.clear()
						menu.colourText(1, "Inventory full. Unload and press Enter")
						read()
						T:down(height)
					end
					height = lib.checkAbove(height)
				else -- already > monument length of 56
					T:up(1)
					height = height - 1
				end
			end
		end
	until height == 0 or length == R.length
	blockType = T:getBlockType("down")
	if blockType:find("sand") ~= nil then -- sand below
		T:dig("down")
	end
	if height > 0 then -- finished as length ran out
		T:up(height)
	end
	-- stay at end of cleared wall unless user chose to return
	if R.data == "return" then
		T:go("R2F"..length.."R2")
	end

	return {}
end

function clearWall()
	local lib = {}

	function lib.move(direction, blocks, reverse)
		--[[ Move up or down by blocks count ]]
		if reverse == nil then
			reverse = false
		end
		if reverse then
			if direction == "down" then -- reverse direction
				T:up(blocks)
			else
				T:down(blocks)
			end
		else
			if direction == "up" then
				T:up(blocks)
			else
				T:down(blocks)
			end
		end
		return blocks
	end

	function lib.singleLayer(length)
		T:go("F"..length - 1)
	end

	function lib.doubleLayer(modifier, length)
		for i = 1, length do
			if i < length then
				T:go("x"..modifier.."F1")
			else
				T:go("x"..modifier)
			end
		end
	end

	function lib.tripleLayer(direction, length)
		for i = 1, length do
			if i < length then
				T:go("x0x2F1")
			else
				T:go("x0x2")
			end
		end
	end


	-- R.width preset to 1
	-- R.subChoice = 1 up / 2 down
	-- R.down = move down first
	-- R.forward = move forward first

	if R.forward then
		T:forward(1)
	end
	if R.down then
		T:down(1)
	end
	if R.height < 3 then
		R.silent = true
	end
	-- dig along and up/down for specified R.length
	local modifier = "0"
	local direction = "U"
	local outbound = true
	local height = 0
	if R.subChoice == 2 then
		 modifier = "2"
		 direction = "D"
	end
	if R.height == 1 then 				-- single block so dig and return
		lib.singleLayer(R.length)
	elseif R.height == 2 then
		lib.doubleLayer(modifier, R.length)
	else								-- 4 blocks or more. start with bulk 3 blocks
		local remaining = R.height
		T:go(direction.."1")			-- up 1 or down 1
		height = 1
		while remaining >= 3 do
			lib.tripleLayer(direction, R.length)
			remaining = remaining - 3

			if remaining == 0 then		-- no more, return home, already in position

			elseif remaining == 1 or remaining == 2 then
				T:go(direction.."2")
				height = height + 2
			else
				T:go(direction.."3")
				height = height + 3
				if remaining >= 3 then -- another iteration
					T:go("R2")
					outbound = not outbound
				end
			end
		end
		-- 0, 1 or 2 layers left
		if remaining > 0 then
			T:go("R2")
			outbound = not outbound
			if remaining == 1 then
				lib.singleLayer(R.length)
			elseif remaining == 2 then
				lib.doubleLayer(modifier, R.length)
			end
		end
	end
	if outbound then
		T:go("R2F"..R.length - 1)
	else
		T:forward(1)
	end
	direction = "D" -- reverse direction
	if R.subChoice == 2 then
		 direction = "U"
	end
	if height > 0 then
		T:go(direction..height.."R2")
	else
		T:go("R2")
	end
	return {}
end

function createFloorCeiling()
	--[[
	R.up = true for ceiling
	R.down = true for floor
	R.height = 0 for normal
	R.height combined with R.up/R.down used for remote access
	R.data == "random" for random floor placement
	]]

	local lib = {}

	function lib.goToRemote()
		R.silent = true
		local depth = 0
		if R.down or R.floor then -- floor could be under water
			while turtle.down() do
				depth = depth + 1
			end
		elseif R.up or R.ceiling then
			while turtle.up() do
				depth = depth + 1
				if depth > R.height + 3 then
					break
				end
			end
		end
		if not(R.height - depth <= 2 or depth - R.height <= 2) then
			T:up(depth)
			return "Measured depth/height of "..depth.." > setting: "..R.height
		end
		-- not returned so depth acceptable
		return ""
	end

	function lib.checkPosition()
		-- check if block above/below
		if R.subChoice == 2 then -- new floor/ceiling above /below existing
			if R.floor and turtle.detectDown() then
				T:up(1)
			elseif R.ceiling and turtle.detectUp() then
				T:down(1)
			end
		end
	end

	function lib.placeRow(direction, waterPresent)
		for y = 1, R.length do
			local blockType = T:getBlockType("forward")
			if not waterPresent then
				if blockType:find("lava") ~= nil or blockType:find("water") ~= nil then
					waterPresent = true
				end
			end
			lib.getRandomBlock()	-- changes block randomly ONLY if R.data == "random"
			lib.changeCheckered()	-- changes to next block type ONLY if R.data == "checked"
			-- ONLY if R.data == "striped" has already been changed for whole row
			T:place(R.inventory.useBlock, direction, false) -- leaveExisting = false
			if y < R.length then
				T:forward(1)
			end
		end
		return waterPresent
	end

	function lib.getRandomBlock()
		if R.data == "random" then
			local index = math.random(1, #R.inventory.names)	-- random index between 1 and no of block types
			local success = false
			for i = index, R.inventory.blockTypeCount do		-- iterate from index upwards
				if R.inventory.quantities[i] > 0 then			-- at least 1 block left
					R.inventory.useBlock = R.inventory.names[i]
					R.inventory.quantities[i] = R.inventory.quantities[i] - 1
					R.inventory.blockCount = R.inventory.blockCount - 1
					success = true
					break
				end
			end

			if not success then								-- no blocks left in the range of index -> no of block types
				for i = index, 1, -1 do						-- go backwards from index to 1
					if R.inventory.quantities[i] > 0 then		-- at least 1 block left
						R.inventory.useBlock = R.inventory.names[i]
						R.inventory.quantities[i] = R.inventory.quantities[i] - 1
						R.inventory.blockCount = R.inventory.blockCount - 1
						success = true
						break
					end
				end
			end
		end
	end

	function lib.changeStripe()
		if R.data == "striped" then
			R.size = R.size + 1
			if R.size > R.inventory.blockTypeCount then
				R.size = 1
			end
			R.inventory.useBlock = R.inventory.names[R.size]
		end
	end

	function lib.changeCheckered()
		--swap between 2 block types
		if R.data == "checked" then
			if R.inventory.useBlock == R.inventory.names[1] then
				R.inventory.useBlock = R.inventory.names[2]
			else
				R.inventory.useBlock = R.inventory.names[1]
			end
		end
	end

	local waterPresent = false

	R.inventory = T:getInventory()
	--[[
		{
		inventory["minecraft:cobblestone"] = 128
		inventory["minecraft:stone"] = 64
		inventory.names = {minecraft:cobblestone, minecraft:stone}
		inventory.quantities = {128, 64}
		inventory.blockTypeCount = 2,
		inventory.blockCount = 196,
		inventory.useBlock = "minecraft:cobblestone"
		inventory.mostBlock = "minecraft:cobblestone"
		inventory.mostCount = 128
		}
	]]
	--R.useBlockType = T:getMostItem("", false)
	--Log:saveToLog("R.useBlockType = "..R.useBlockType)
	--R.inventory.useBlock = R.useBlockType
	--local inventory = T:getInventory()
	--Log:saveToLog("T:R.inventory = "..textutils.serialise(inventory, {compact = true}))
	--R.inventory.blockCount = T:getInventory()["blockCount"]
	--Log:saveToLog("T:getInventory()['blockCount'] = "..	R.inventory.blockCount)

	if R.data == "random" then
		math.randomseed(R.inventory.blockCount)
		print("Using random blocks")
	elseif R.data == "striped" then
		print("Using striped pattern")
	elseif R.data == "checked" then
		print("Using checkered pattern")
	end
	local direction = "down"
	if R.up or R.ceiling then
		direction = "up"
	end

	if R.height > 0 then -- remote placing. go up/down R.height first
		local message = lib.goToRemote()
		if message ~= "" then	-- error encountered
			return {message}
		end
	end

	lib.checkPosition()
	-- based on clearRectangle code
	if R.width == 1 then 					-- single block ahead only
		waterPresent = lib.placeRow(direction, waterPresent)
		T:turnRight(2)						-- turn at the top of the run
		T:forward(R.length - 1)				-- return to start
		T:turnRight(2)						-- turn round to original position
	else
		local iterations = 0 				-- R.width = 2, 4, 6, 8 etc
		if R.width % 2 == 1 then  			-- R.width = 3, 5, 7, 9 eg R.width 7
			iterations = (R.width - 1) / 2 	-- iterations 1, 2, 3, 4 for widths 3, 5, 7, 9
		else
			iterations = R.width / 2		-- iterations 1, 2, 3, 4 for widths 2, 4, 6, 8
		end
		lib.changeStripe()
		lib.changeCheckered()
		for i = 1, iterations do 			-- eg 3 blocks wide, iterations = 1
			waterPresent = lib.placeRow(direction, waterPresent)
			T:go("R1F1R1")
			lib.changeStripe()
			--lib.changeCheckered()
			waterPresent = lib.placeRow(direction, waterPresent)
			-- if 1 less than end, reposition for next run
			if i < iterations then
				T:go("L1F1L1", false, 0, false)
				lib.changeStripe()
			end
		end
		if R.width % 2 == 1 then  -- additional run and return to base needed
			T:go("L1F1L1", false, 0, false)
			lib.changeStripe()
			waterPresent = lib.placeRow(direction, waterPresent)
			T:turnRight(2)
			T:forward(R.length - 1)
		end
		T:go("R1F"..R.width - 1 .."R1", false, 0, false)
	end

	if waterPresent then
		return {"water or lava found"}
	end

	return {""}
end

function createRailway()
	-- go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
	--[[
		Build steps up or down ready for railtrack
		R.up (default) or R.down
		R.height = no blocks to move (up/down)
		R.depth = headroom, default 2
	]]
	if R.down then									-- move downwards
		if R.height == 0 then						-- stop when reaching existing ground
			local blockType = ""
			while blockType == "" do
				T:go("F1D1", false, 0, true)
				blockType = T:getBlockType("down")
				if blockType == "" then
					T:go("C2", false, 0, true)
				end
			end
		else
			for i = 1, R.height - 1 do
				--T:go("U1x0 D1x1 F1x0x1 D1x1 C2", false, 0, false)
				T:go("U"..math.max(1, R.depth - 1) .."x0 D"..math.max(1, R.depth - 1) .."x1 F1x0x1 D1x1 C2", false, 0, false)
			end
		end
	elseif R.up then
		for i = 1, R.height do
			--T:go("C1U2 x0D1F1", false, 0, false) --put stone in front, up 2 excavate 1, down 1, forward 1
			T:go("C1U"..math.min(1, R.depth).." x0D"..math.min(0, R.depth - 1).."F1", false, 0, false) --put stone in front, up 2 (or headroom) excavate 1, down 1, forward 1
		end
	end
	return {}
end

function createRetainingWall()
	-- facing direction wall will take
	-- will need to rotate 180 to build
	-- if R.height > 0 then build to specified depth
	local lib = {}

	function lib.checkFloor()
		local newDepth = 0
		place = utils.clearVegetation("down") -- in case col in front is deeper
		while place do -- loop will be entered at least once
			T:down(1)
			newDepth = newDepth + 1
			place = utils.clearVegetation("down")
		end
		if newDepth > 0 then
			for j = 1, newDepth do	-- go up until column base is met
				T:go("U1C2")
			end
		end
	end

	function lib.patchMissingBlock()
		if turtle.back() then
			T:go("C1")
		else
			T:go("B1C1")
		end
	end

	function lib.placeSingle(height)
		local y = 0
		if height > 0 then
			T:go("D"..height)
			y = height
		else
			local place = utils.clearVegetation("down")
			while place do -- loop will be entered at least once
				place = utils.clearVegetation("down")
				if place then
					T:down(1)
					y = y + 1
				end
			end
		end
		-- return to surface, placing below
		for i = 1, y do
			T:go("U1C2", false, 0, true)
		end
	end

	function lib.placeDouble(height)
		--T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		local y = 0
		if not turtle.back() then
			T:go("B1")
		end
		if height > 0 then
			for i = 1, height do
				T:go("C1D1", false, 0, true)
			end
			T:go("C1", false, 0, true)
			y = height
		else
			local place = utils.clearVegetation("down")
			-- build back column
			while place do -- loop will be entered at least once
				place = utils.clearVegetation("down")
				if place then
					T:go("C1D1", false, 0, true)
					y = y + 1
				end
			end
			-- reached bottom. floor in front could drop down
			T:go("F1") -- move under first column
			lib.checkFloor()
			turtle.back() -- back at starting point
			T:go("C1", false, 0, true)
		end
		-- return to surface, placing below
		for i = 1, y do
			T:go("U1C2", false, 0, true)
		end
	end

	function lib.placeTriple(height)
		--T:go(path, useTorch, torchInterval, leaveExisting, preferredBlock)
		local y = 0
		utils.goBack(1)
		-- if turtle.back() then
			-- T:go("C1")
		-- else
			-- T:go("B1C1")
		-- end
		T:go("C1")
		if height > 0 then
			for i = 1, height do
				T:go("C1D1", false, 0, true)
			end
			for i = 1, height do
				T:go("C1D1", false, 0, true)
			end
			T:go("C1R2C1", false, 0, true) --fill last block, then turn 180 to build opposite side
			y = height
		else
			local place = utils.clearVegetation("down")
			-- build back column
			while place do -- loop will be entered at least once
				place = utils.clearVegetation("down")
				if place then
					--T:go("C1D1", false, 0, true)
					T:go("C1D1C0", false, 0, true)
					y = y + 1
				end
			end
			-- reached bottom. floor in front could drop down
			T:go("F1") -- move under first column
			lib.checkFloor()
			--T:go("B1C1R2F1", false, 0, true)
			T:go("B1C1B1C1R2F1", false, 0, true)
			lib.checkFloor()
			T:go("B1C1")
			-- return to surface , placing below and to front
		end
		for i = 1, y do
			T:go("C1U1C2", false, 0, true)
		end
		T:go("F1R2C1", false, 0, true)
		-- facing back again inside edge of col 3
		return y -- depth of this run
	end

	local topInPlace = false -- topInPlace = true already a path across the water eg monument rectangle
	if R.data == "withPath" then
		topInPlace = true
	end
	local place = false
	local inWater = false
	local onWater = false
	if not topInPlace then
		if R.length > 1 then
			inWater, onWater = utils.getWaterStatus() -- returns whether above water, or immersed
		end
	end

	local maxDepth = 5 --initial estimated value
	-- start at surface, move back 1 block
	-- each iteration completes 3 columns
	local numBlocks = T:getSolidBlockCount()
	print("Solid blocks in inventory: "..numBlocks)

	if R.length == 1 then -- single column down to water bed
		lib.placeSingle(R.height)
	elseif R.length == 2 then--down then up: 2 cols
		inWater, onWater = utils.startWaterFunction(onWater, inWater, 2, true) -- move into water
		T:go("R2") -- move to face player
		lib.placeDouble(R.height)
		if not inWater then
			T:go("U1C2", false, 0, true)
		end
	else -- R.length 3 or more
		if topInPlace then
			T:down(1) -- break through top
		else
			inWater, onWater = utils.startWaterFunction(onWater, inWater, 2, true) -- move into water
		end
		T:go("R2") -- move to face player
		-- now at water surface
		local remain = R.length
		--while remain >= 3 do
		while remain >= 4 do
			numBlocks = T:getSolidBlockCount()
			print("Inventory blocks: "..numBlocks.." depth: "..maxDepth)
			if numBlocks < maxDepth * 3 then
				--ask player for more
				T:checkInventoryForItem({"stone"}, {maxDepth * remain}, false)
			end
			local y = lib.placeTriple(R.height) -- moves back, places col in front, centre and behind. R.height = 0 for auto depth
			if y > maxDepth then
				maxDepth = y
			end
			--remain = remain - 3
			remain = remain - 4
			if remain > 1 then
				lib.patchMissingBlock()
			end
		end
		if remain == 1 then -- 1 more column
			lib.patchMissingBlock()
			lib.placeSingle(R.height)
		elseif remain == 2 then -- 2 cols
			lib.placeDouble(R.height)
		end
		T:go("U1C2") -- above surface
	end
	return {}
end

function createSandWall()
	local success = true
	local count = 0
	local count17 = 0
	local reg = {0, 0, 0, 0, 0, 0, 0, 0} --{18,17,17,17,17,17,17,18}
	--move above water
	local maxMove = 2
	local lib = {}

	function lib.isArch(count)
		local complete = true
		for i = 1, 7 do
			reg[i] = reg[i + 1]
		end
		reg[8] = count
		--Log:saveToLog("reg = "..textutils.serialise(reg, {compact = true}))
		if  reg[2] == reg[3] and reg[2] == reg[4] and reg[2] == reg[5] and reg[2] == reg[6] and reg[2] == reg[7]  then
			if  reg[1] == reg[2] + 1 and reg[8] == reg[7] + 1 then
				return true
			end
		end
		return false
	end

	function lib.underArch()
		-- need to go down 17, check for prismarine
		T:go("F1")
		local depth = 0
		while turtle.down()	do
			depth = depth + 1
		end
		local blockType = T:getBlockType("down")
		if blockType:find("prismarine") ~= nil then	-- if prismarine, go through, under and place sand below
			T:go("D1R2F1")					-- at col 8 of arch, facing across it
			while turtle.down() do end		-- on floor backing against arch col 9
			utils.followGround(8)			-- clear plants 8 blocks
			while turtle.up() do end		-- climb against col 0 of arch

			utils.dropSand() 				-- col 1 (inner side of arch

			utils.goBack(1)
			T:place("sand", "forward")		-- close col 1
			utils.dropSand() 				-- col 2 of arch

			utils.goBack(1)
			T:place("sand", "forward")		-- close col 2
			turtle.up()						-- ready for col 3. under arch next to lantern
			utils.dropSand() 				-- col 3 of arch

			utils.goBack(1)
			T:place("sand", "forward")		-- close col 3
			utils.dropSand() 				-- col 4 of arch

			utils.goBack(1)
			T:place("sand", "forward")		-- close col 4
			utils.dropSand() 				-- col 5 of arch

			utils.goBack(1)					-- back against lantern
			T:place("sand", "forward")		-- close col 5
			T:down(1)						-- need to go under lantern. use solid block to plug hole
			T:place("minecraft:prismarine_bricks", "up")		-- place prismarine
			utils.dropSand() 				-- col 6 of arch

			utils.goBack(1)					-- back against lantern
			T:place("sand", "forward")		-- close col 6
			utils.dropSand() 				-- col 7 of arch

			utils.goBack(1)					-- under final block
			T:place("sand", "forward")		-- close col 7
			utils.dropSand() 				-- col 8 of arch

			utils.goBack(1)					-- at entry point
			T:place("sand", "forward")		-- close col 8
		end
		T:go("R2U"..tostring(depth + 1))
	end

	while turtle.detectDown() and maxMove > 0 do
		T:forward(1)
		maxMove = maxMove - 1
	end
	if R.length > 0 then
		for i = 1, R.length - 1 do
			success, count = utils.dropSand()
			--Log:saveToLog("Sand dropped = "..count)
			if lib.isArch(count) then
				lib.underArch()
			end
			T:forward(1, false)
		end
		success, count = utils.dropSand()
	else
		while not turtle.detectDown() do 				-- over water
			while not turtle.detectDown() do 			-- nested to allow forward movement
				success, count = utils.dropSand() 		-- drops sand and checks supplies
				--Log:saveToLog("Sand dropped = "..count)
				if lib.isArch(count) then				-- pattern of sand drops matches arch
					lib.underArch()
				end
			end
			if success then
				T:forward(1, false)
			else -- out of sand
				break
			end
		end
	end
	return {}
end


end
