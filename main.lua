mapapi = require "map"
socket = require "socket"


local screenw, screenh = love.graphics.getWidth(), love.graphics.getHeight()
local camerax, cameray, cameraz = 0, 11, 0
local scale = 2

local save = true
local network = false

local address, port = "71.80.179.93", 1234

local overlay = love.graphics.newImage("/img/overlay.png")

--[[
completed  compbar
total    = totbar
]]

function love.load()
	if network then	
		love.graphics.print("Connecting to server...", 1, 1)
		client = socket.tcp()
		local ok, err = client:connect(address, port)
		if not ok then
			error(err)
		end
		client:settimeout(0.5)
	end

	--[[local steps = #love.filesystem.enumerate("blocks")
	local completed = 0
	local function drawbar()
		love.graphics.clear()
		local barwid = (screenw-20)*completed/steps

		love.graphics.setColor(120, 120, 120)
		love.graphics.quad(
			"fill",
			10, screenh-20, 
			10, screenh-10, 
			screenw-10, screenh-20, 
			screenw-10, screenh-10
		)
		love.graphics.setColor(40, 200, 40)
		love.graphics.quad(
			"fill",
			10, screenh-20, 
			10, screenh-10, 
			10+barwid, screenh-20, 
			10+barwid, screenh-10
		)
	end--]]

	if save then
		map = mapapi.new()

		for x = 1, 10 do
			for y = 1, 10 do
				for z = 1, 10 do
					if math.random(1,3)==1 then
						map:setBlock(x, y, z, 0)
					else
						map:setBlock(x, y, z, 1)
					end
				end
			end
		end
		--map:setBlock(2, 10, 3, 2)

		mapapi.save(map, "block")
	end

	map = mapapi.load("block")
	map:addEntity("stkm1", "stickman", 0, 11, 0)
	map:addEntity("test", "stickman", 2, 11, 2)
	local ok = map:setVelocity("test", 1, 1, 0.5)
	print(ok)

	--[[mapapi.setRenderer(2, function(bl, x, y, z, cx, cy, cz, sc)
		local bx, by, bz = map:getBlockBelow(x, y, z)
		mapapi.defaultRenderer({"shadow"}, bx, by, bz, cx, cy, cz, sc)

		mapapi.defaultRenderer(bl, x, y, z, cx, cy, cz, sc)
	end)--]]
end

function love.draw()
	mapapi.draw(map, camerax, cameray, cameraz, scale)

	love.graphics.setColor(255, 255, 255)
	love.graphics.setBlendMode("multiplicative")
	love.graphics.draw(overlay, 0, 0)
	love.graphics.setBlendMode("alpha")
	love.graphics.print("c: ("..camerax..", "..cameray..", "..cameraz..")", 1, 1)
	love.graphics.print("s: "..scale, 1, 15)
	love.graphics.print("Current FPS: " ..tostring(love.timer.getFPS()), 1, 30)
end

function love.keypressed(key)
	if key == "left" then
		mapapi.drawmode = (mapapi.drawmode%#mapapi.drawmodes) + 1
	elseif key == "right" then
		
	elseif key == "return" then
		debug.debug()
	end
end

function love.mousepressed(x, y, button)
	if button == "wu" then
		scale = scale + 0.25
	elseif button == "wd" then
		if scale > 0.25 then
			scale = scale - 0.25
		end
	end
end

local movedx, movedz, time = 0, 0, 0
function love.update(dt)
	map:update(dt)
	--map:clearBlock(math.floor(camerax), math.floor(cameray), math.floor(cameraz))
	if love.keyboard.isDown("s") then
		camerax = camerax + (3*dt)
		cameraz = cameraz + (3*dt)
		movedx = movedx + (3*dt)
		movedz = movedz + (3*dt)
	end
	if love.keyboard.isDown("w") then
		camerax = camerax - (3*dt)
		cameraz = cameraz - (3*dt)
		movedx = movedx - (3*dt)
		movedz = movedz - (3*dt)
	end
	if love.keyboard.isDown("a") then
		camerax = camerax + (3*dt)
		cameraz = cameraz - (3*dt)
		movedx = movedx + (3*dt)
		movedz = movedz - (3*dt)
	end
	if love.keyboard.isDown("d") then
		camerax = camerax - (3*dt)
		cameraz = cameraz + (3*dt)
		movedx = movedx - (3*dt)
		movedz = movedz + (3*dt)
	end
	if love.keyboard.isDown(" ") then
		cameray = cameray + (3*dt)
	end
	if love.keyboard.isDown("lshift") then
		cameray = cameray - (3*dt)
	end

	local ok, x2, y2, z2 = map:moveEntity("stkm1", camerax, cameray, cameraz)
	if not ok then
		camerax, cameray, cameraz = x2, y2, z2
	end

	time = time + dt
	while time > 0.1 do
		time = time - 0.1
		if network then
			local packet = ""
			if movedx ~= 0 then
				if movedx < 0 then
					packet = packet .. "move: x - ".. -movedx .. "\n"
				else
					packet = packet .. "move: x + "..movedx .. "\n"
				end
				movedx = 0
			end
			if movedz ~= 0 then
				if movedz < 0 then
					packet = packet .. "move: z - ".. -movedz .. "\n"
				else
					packet = packet .. "move: z + "..movedz .. "\n"
				end
				movedz = 0
			end
			if packet ~= "" then
				print(packet)
				client:send(packet)
			end
		end
	end

	if network then
		local packet = client:receive("*l")
		while packet do
			print(packet)

			packet = client:receive("*l")
		end
	end

	--map:setBlock(math.floor(camerax), math.floor(cameray), math.floor(cameraz), 2)
end