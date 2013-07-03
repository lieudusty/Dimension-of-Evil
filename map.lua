--[[

	* * * * * * * * * * * * * * * * * * * *
	*                                     *
	*               Map API               *
	*                                     *
	*            By Imgoodisher           *
	*                                     *
	* * * * * * * * * * * * * * * * * * * *


Functions:

	mapapi.new()
	- Creates a new map object

	mapapi.setRenderer(block, renderer)
	- Sets the renderer for [block].
	- Renderer is a function with the arguments 
	  (map, block, map_x, map_y, map_z, camera_x, camera_y, camera_z, scale)
	- mapapi.defaultRenderer is the default renderer

	mapapi.load(path, progressfunc)
	- loads a map from [path]
	- If [progressfunc] is a function, it is called with the arguments 
	  (completedbytes, totalbytes) while the file is being read

  The following functions can be used either as normal functions in the map api
  or the map argument can be omitted and instead used object-oriented style with
  a map (ex: mapapi.draw(map, ...) -> map:draw(...))

	mapapi.draw(map, camera_x, camera_y, camera_z, scale)
	- Draws the map based on the camera position and scale

	mapapi.save(map, path)
	- Saves the map to [path]

	mapapi.addEntity(map, name, imgname, x, y, z)
	- Adds an entity to the map at (x, y, z)
	- [name] is a unique name for each entity
	- imgname is the name of the image to  use

	mapapi.getEntity(map, name)
	- Gets the entity with the name [name]

	mapapi.moveEntity(map, name, x, y, z)
	- Attempts to move entity [name] to (x, y, z)
	- If it fails, it returns false with the position the entity should be at

	mapapi.setBlock(map, x, y, z, block, ...)
	- Sets the block at (x, y, z) to block with any extra data needed (usually none)

	mapapi.getBlock(map, x, y, z)
	- Gets the block at (x, y, z) (as a table, first value is the block type)

	mapapi.clearBlock(map, x, y, z)
	- Clears the block at (x, y, z)

	mapapi.getBlockBelow(map, x, y, z, depth)
	- Gets the first block below (x, y, z)
	- Depth is how far down to check. Defaults to 20.

	mapapi.getBlockFromPoint(map, m, my, cx, cy)
	- Unimplemented

]]

textutils = require "lib.textutils"

local function coord(x, y, z)
	return "("..x..","..y..","..z..")"
end

local mapapi = {
	drawmode = 1,
	drawmodes = {
		function (x, z)
			return x, z
		end,
		function (x, z)
			return -x, z
		end,
		function (x, z)
			return -x, -z
		end,
		function (x, z)
			return x, -z
		end,
	},
	blocks = {},
	entities = {},
	renderers = {},
	defaultRenderer = function(map, block, x, y, z, cx, cy, sc)

		love.graphics.draw(
			mapapi.blocks[block[1]] or mapapi.blocks["error"],
			(cx + ((z-x) * ((block_w*sc)/2))),
			(cy + ((x+z) * ((block_d*sc)/2)) - ((block_d*sc) * y)),
			nil, sc, sc
		)
	end,
	camera2dpos = function(cx, cy, cz, sc)
		return (love.graphics.getWidth()/2 + ((cx-cz) * ((block_w*sc)/2))),
			   (love.graphics.getHeight()/2 + -(((cz+cx) * ((block_d*sc)/2)) - ((block_d*sc) * cy)))
	end
}

love.graphics.setDefaultImageFilter("nearest", "nearest")
for i,v in pairs(love.filesystem.enumerate("blocks")) do
	if v:find("%.png$") then
		local name = v:match("(.-)%.png")
		name = tonumber(name) or name
		mapapi.blocks[name] = love.graphics.newImage("blocks/"..v)
	end
end
for i,v in pairs(love.filesystem.enumerate("entities")) do
	if v:find("%.png$") then
		local name = v:match("(.-)%.png")
		name = tonumber(name) or name
		mapapi.entities[name] = love.graphics.newImage("entities/"..v)
	end
end

block_w = mapapi.blocks[0]:getWidth()
block_h = mapapi.blocks[0]:getHeight() - 1
block_d = block_h / 2

function mapapi.setDrawMode(n)
	mapapi.drawmode = n
end
function mapapi.getDrawMode()
	return mapapi.drawmode
end

function mapapi.new()
	local map = setmetatable({
		entref = {}
	}, {
		__index = function(tbl, key)
			if key ~= nil and rawget(tbl, key) == nil then
				if type(key) == "string" and mapapi[key] then
					return mapapi[key]
				else

					rawset(tbl, key, setmetatable({}, {
						__index = function(tbl, key)
							if rawget(tbl, key) == nil then
								rawset(tbl, key, {})
							end
							return rawget(tbl, key)
						end,
					}))

					return rawget(tbl, key)
				end
			end
		end,
	})
	return map
end

function mapapi.draw(map, cx, cy, cz, sc)
	sc = sc or 1
	function maxminval(tbl, char)
		local max = -math.huge
		local min = math.huge
		for i,v in pairs(tbl) do
			if type(i) == "number" then
				if i > max then
					max = i
				end
				if i < min then
					min = i
				end
			end
		end
		if max == -math.huge or min == math.huge then
			return 1, 0, 1
		elseif (char == "x" and (mapapi.drawmode == 2 or mapapi.drawmode == 3)) or (char == "z" and (mapapi.drawmode == 3 or mapapi.drawmode == 4)) then
			return max, min, -1
		else
			return min, max, 1
		end
	end

	local i = 0

	local ymin, ymay, yn = maxminval(map, "y")
	for y=ymin, ymay, yn do
		if type(map[y]) == "table" then

			local xmin, xmax, xn = maxminval(map[y], "x")
			for x=xmin, xmax, xn do
				if type(map[y][x]) == "table" then

					local zmin, zmax, zn = maxminval(map[y][x], "z")
					for z=zmin, zmax, zn do
						if type(map[y][x][z]) == "table" then

							i = i + 1
							local x2, z2 = mapapi.drawmodes[mapapi.drawmode](x, z)
							local cx2, cz2 = mapapi.drawmodes[mapapi.drawmode](cx, cz)
							local cx3, cy3 = 
								(love.graphics.getWidth()/2 + ((cx2-cz2) * ((block_w*sc)/2))),
			  					(love.graphics.getHeight()/2 + -(((cz2+cx2) * ((block_d*sc)/2)) - ((block_d*sc) * cy)))
							if mapapi.renderers[map[y][x][z][1]] then
								mapapi.renderers[map[y][x][z][1]](map, map[y][x][z], x2, y, z2, cx3, cy3, sc)
							else
								mapapi.defaultRenderer(map, map[y][x][z], x2, y, z2, cx3, cy3, sc)
							end
						end
					end
				end
			end
		end
	end

	--print("drew "..i)
end

function mapapi.setRenderer(block, func)
	mapapi.renderers[block] = func
end

function mapapi.save(map, path)
	local data = ""

	function addInstr(...)
		local args = {...}
		local str = table.remove(args, 1)
		for i,v in pairs(args) do
			if type(v) == "number" then
				local neg = (v < 0 and true) or false
				v = math.abs(v)
				str = str .. string.char(math.floor(v/256) + ((neg and 128) or 0))
				str = str .. string.char(v%256)
			elseif type(v) == "string" then
				str = str .. "${'" .. v .. "'}$"
			elseif type(v) == "table" then
				str = str .. "${" .. textutils.serialize(v) .. "}$"
			end
		end
		data = data .. str
		return true
	end

	local xpos, zpos = 0, 0 -- y changes every time; combined into block
	for y, xtbl in pairs(map) do
		if type(xtbl) == "table" and y ~= "entref" then
			for x, ztbl in pairs(xtbl) do
				for z, block in pairs(ztbl) do

					ypos = (y ~= ypos and addInstr("y", y) and y) or ypos
					xpos = (x ~= xpos and addInstr("x", x) and x) or xpos

					if type(block) == "table" then
						addInstr("b", z, block[1])
					else
						print("Block at ("..x..","..y..","..z..") is "..block)
					end

				end
			end
		end
	end


	love.filesystem.write(path, data)
	print("Saved map")
end

function mapapi.load(path, progressfunc)
	local data = love.filesystem.read(path)
	local n = 1
	local map = mapapi.new()
	local x, y, z = 0, 0, 0

	local function loadInt(str)
		local a, b = string.byte(str:sub(1, 1)), string.byte(str:sub(2, 2))
		local neg = a/128 >= 1
		if neg then a = a - 128 end
		return ((256 * a) + b) * ((neg and -1) or 1)
	end

	while true do
		local instr = data:sub(n, n)
		if instr == "x" then
			x = loadInt(data:sub(n+1, n+2))
			n = n + 3
		elseif instr == "y" then
			y = loadInt(data:sub(n+1, n+2))
			n = n + 3
		elseif instr == "b" then
			z = loadInt(data:sub(n+1, n+2))
			if data:sub(n+3, n+5) == "${'" then
				local _, e, contents = data:sub(n):find("%${'(.-)'}%$")
				t = contents
				n = n + e
			else
				t = loadInt(data:sub(n+3, n+4))
				n = n + 5
			end
			map:setBlock(x, y, z, t)
		elseif n >= data:len() then
			break
		else
			-- Map is corrupt
			print("Unknown Instruction: "..data:sub(n, n).." at "..n)
			n = n + 1
		end
		if progressfunc then progressfunc(n, data:len()) end
	end

	print("Loaded map")
	return map
end

function mapapi.addEntity(map, name, imgname, x, y, z)
	local height = math.ceil(mapapi.entities[imgname]:getHeight() / block_d)
	local mx, my, mz = math.floor(x), math.floor(y)+height, math.floor(z)
	local ox, oy, oz = x%1, y%1, z%1
	if (not map:getBlock(mx, my, mz)) or map:getBlock(mx, my, mz)[1] ~= "entpile" then
		map:setBlock(mx, my, mz, "entpile", {})
	end
	map:getBlock(mx, my, mz)[2][name] = {
		img = imgname,
		x = ox,
		y = oy-height,
		z = oz,
	}
	map.entref[name] = {mx,my,mz}
end

function mapapi.getEntity(map, name)
	local ref = map.entref[name]
	if map:getBlock(unpack(ref)) and map:getBlock(unpack(ref))[1] == "entpile" then
		if map:getBlock(unpack(ref))[2][name] then
			return map:getBlock(unpack(ref))[2][name]
		else
			map.entref[name] = nil
			print("Removed entity reference for "..name.." at "..coord(unpack(ref)))
		end
	end
	return false
end

function mapapi.moveEntity(map, name, x, y, z)
	local ent = map:getEntity(name)
	local height = mapapi.entities[ent.img]:getHeight() / block_d
	local ref = map.entref[name]
	if not ent then
		return false, 0, 0, 0
	end

	local mx, my, mz = math.floor(x), math.floor(y)+math.ceil(height), math.floor(z)
	local my2 = math.floor(y)

	for ypos = my2, my do
		if map:getBlock(mx, ypos, mz) and map:getBlock(mx, ypos, mz)[1] ~= "entpile" then
			return false, ref[1]+ent.x, ref[2]+ent.y, ref[3]+ent.z
		end
	end

	if not map:getBlock(mx, my, mz) then
		map:setBlock(mx, my, mz, "entpile", {})
	end

	if map:getBlock(mx, my, mz)[1] == "entpile" then
		map:getBlock(unpack(ref))[2][name] = nil
		if #map:getBlock(unpack(ref))[2] == 0 and not (ref[1] == mx and ref[2] == my and ref[3] == mz) then
			map:clearBlock(unpack(ref))
		end

		ent.x, ent.y, ent.z = x%1, (y%1)-math.ceil(height), z%1
		map:getBlock(mx, my, mz)[2][name] = ent
		map.entref[name] = {mx,my,mz}
		return true
	else
		return false, ref[1]+ent.x, ref[2]+ent.y, ref[3]+ent.z
	end
end

function mapapi.setBlock(map, x, y, z, ...)
	map[y][x][z] = {...}
end

function mapapi.getBlock(map, x, y, z)
	return map[y][x][z]
end

function mapapi.clearBlock(map, x, y, z)
	map[y][x][z] = nil
end

--x = (camerax + ((z-x) * ((block_w*scale)/2))),
--y = (cameray + ((x+z) * ((block_d*scale)/2)) - ((block_d*scale) * y)),

function mapapi.getBlockBelow(map, x, y, z, depth)
	depth = depth or 20
	x, y, z = math.floor(x), math.floor(y)-1, math.floor(z)
	while (map:getBlock(x, y, z) == nil or map:getBlock(x, y, z)[1] == "entpile") and depth > 0 do
		y = y - 1
		depth = depth - 1
	end
	return x, y, z
end

function mapapi.getBlockFromPoint(map, mx, my, cx, cy, cz)
	local angle = math.atan(math.sin(math.rad(45)))
	local x = mx/block_w
	local y = cy + 5
	local z = my/block_w
	for i = 1, 10 do
		local dist = y * math.tan(angle)
		map:setBlock(math.floor(dist-x), math.floor(y), math.floor(dist-z), 2)

		y = y - 1
	end
end



mapapi.setRenderer("entpile", function(map, bl, mx, my, mz, cx, cy, sc)

	if type(bl[2]) ~= "table" then
		print("Added table to entpile at "..coord(mx,my,mz))
		bl[2] = {}
	end

	local x2, y2, z2 = map:getBlockBelow(mx, my, mz)

	for i,v in pairs(bl[2]) do
		local x, y, z = mx+v.x-0.5, my+v.y-0.5, mz+v.z-0.5
		mapapi.defaultRenderer(map, {"shadow"}, x2+v.x-0.5, y2, z2+v.z-0.5, cx, cy, sc)
		love.graphics.draw(
			mapapi.entities[v.img] or mapapi.entities["error"],
			(cx + ((z-x) * ((block_w*sc)/2)) + (((mapapi.entities[v.img]:getWidth()/2)-0.75)*sc)),
			(cy + ((x+z) * ((block_d*sc)/2)) - ((block_d*sc) * y)) + (block_d*sc) - (mapapi.entities[v.img]:getHeight()*sc),
			nil, sc, sc
		)
	end
end)

return mapapi