mods.gof = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_random_point_in_radius(center, radius)
    r = radius * math.sqrt(math.random())
    theta = math.random() * 2 * math.pi
    return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

local function get_ship_crew_room(shipManager, roomId)
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
end

-- written by kokoro
local function convertMousePositionToEnemyShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

local RandomList = {
    New = function(self, table)
        table = table or {}
        self.__index = self
        setmetatable(table, self)
        return table
    end,

    GetItem = function(self)
        local index = Hyperspace.random32() % #self + 1
        return self[index]
    end,
}
--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

mods.gof.chainShots = {}
local chainShots = mods.gof.chainShots
chainShots["GOF_CHAIN_SHOT"] = {1,"gofpulsefire1"}
chainShots["GOF_CHAIN_SHOT_2"] = {2,"gofpulsefire2"}
chainShots["GOF_CHAIN_SHOT_3"] = {3,"gofpulsefire3"}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	--print(weapon.boostLevel)
	local weaponName = nil
	pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local chainShots = chainShots[weaponName]
    if chainShots and weapon.boostLevel > 0 then
    	--local pos = projectile.position
    	userdata_table(weapon, "mods.gof.chainShots").chain = {0.4,weapon.boostLevel,projectile.position.x,projectile.position.y,projectile.currentSpace,projectile.target,projectile.destinationSpace,projectile.heading}    	
		--print(pos.x)
    end
    if chainShots then
    	if weapon.boostLevel < chainShots[1] then
    		--print("AAAAA")
    		weapon.boostLevel = weapon.boostLevel + 1
    	end
    end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local chainTable = userdata_table(weapon, "mods.gof.chainShots")
		if chainTable.chain then
			chainTable.chain[1] = math.max(chainTable.chain[1] - Hyperspace.FPS.SpeedFactor/16, 0)
			if chainTable.chain[1] == 0 then
                --print("FIRERERE")
                local soundName = "gofpulsefire1"
				pcall(function() soundName = chainShots[weapon.blueprint.name][2] end)
				if not soundName then
					soundName = "gofpulsefire1"
				end
        		Hyperspace.Sounds:PlaySoundMix(soundName, -1, true)

				local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
				local laser = spaceManager:CreateLaserBlast(
	                weapon.blueprint,
	                Hyperspace.Pointf(chainTable.chain[3],chainTable.chain[4]),
	                chainTable.chain[5],
	                shipManager.iShipId,
	                chainTable.chain[6],
	                chainTable.chain[7],
	                chainTable.chain[8])
	            --weapon:Fire()
	            --weapon.boostLevel = chainTable.chain[3]
                if chainTable.chain[2] <= 1 then
                	chainTable.chain = nil
                else
                	chainTable.chain[1] = 0.4
                	chainTable.chain[2] = chainTable.chain[2] -1
                end
            end
        end
	end
end)

mods.gof.thermoWeapons = {}
local thermoWeapons = mods.gof.thermoWeapons
thermoWeapons["GOF_THERMO_1"] = true
thermoWeapons["GOF_THERMO_2"] = true
thermoWeapons["GOF_THERMO_3"] = true

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local weaponName = nil
		pcall(function() weaponName = weapon.blueprint.name end)
	    local thermoWeapon = thermoWeapons[weaponName]
	    if thermoWeapon and shipManager.iShipId == 0 then
	    	local weaponTable = userdata_table(weapon, "mods.gof.thermoWeapons")
	    	--print(weapon.targets:size())
	    	--print(weapon.targets[0])
	    	--print("PASS")
	    	weapon.autoFiring = true

	    	if weapon.targets:size() > 0 then
	    		local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
	    		local roomTarget = get_room_at_location(otherShip,weapon.targets[0],true)
	    		if weaponTable.thermoTarget then
	    			--print(weapon.targets[0].x)
	    			--print(weapon.targets[0].y)
	    			if weaponTable.thermoTarget ~= roomTarget then
	    				--print("Target Moved")
		    			weapon.cooldown.first = 0
		    			weapon.boostLevel = 0
		    		end
		    		weaponTable.thermoTarget = roomTarget
		    	else
		    		--print("No Target")
		    		weaponTable.thermoTarget = roomTarget
	    		end
	    	elseif weapon.powered then
	    		--print("No target selected")
	    		weapon.cooldown.first = math.min(weapon.cooldown.first, weapon.cooldown.second-0.1)
	    	end 
	    end
    end
end)

thermoSounds = RandomList:New {"gofthermofire1", "gofthermofire2", "gofthermofire3"}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local weaponName = nil
	pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local thermoWeapon = thermoWeapons[weaponName]
    if thermoWeapon then
    	
    	local random = (math.random()-0.5)
    	--print(random)
    	projectile.position = Hyperspace.Pointf(projectile.position.x, (projectile.position.y + (random * 10)))
    	--projectile.speed_magnitude = projectile.speed_magnitude + (random*20)
    	projectile.speed_magnitude = 0
    	userdata_table(projectile, "mods.gof.thermoProjectiles").delay = math.random() * 0.5
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	for projectile in vter(spaceManager.projectiles) do
		local projTable = userdata_table(projectile, "mods.gof.thermoProjectiles")
		if projTable.delay then
			projTable.delay = math.max(projTable.delay - Hyperspace.FPS.SpeedFactor/16, 0)
			if projTable.delay == 0 then
				projTable.delay = nil
				projectile.speed_magnitude = 50
				local soundName = thermoSounds:GetItem()
        		Hyperspace.Sounds:PlaySoundMix(soundName, -1, true)
        	end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local weaponTable = userdata_table(weapon, "mods.gof.thermoWeapons")
		weaponTable.thermoTarget = nil
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
    if ship.iShipId == 1 then
    	shipManager = Hyperspace.ships.player
    	local slot = 1
    	for weapon in vter(shipManager:GetWeaponList()) do
    		local weaponTable = userdata_table(weapon, "mods.gof.thermoWeapons")

    		if weaponTable.thermoTarget then
    			local roomLoc = ship:GetRoomCenter(weaponTable.thermoTarget)

    			local targetString = "misc/crosshairs_placed_gof_thermo_"..tostring(slot)..".png"
    			local shipTargetImage = Hyperspace.Resources:CreateImagePrimitiveString(
		            targetString,
		            roomLoc.x-19,
		            roomLoc.y-19,
		            0,
		            Graphics.GL_Color(1, 1, 1, 1),
		            1.0,
		            false)
		        Graphics.CSurface.GL_RenderPrimitive(shipTargetImage)
    		end
    		slot = slot + 1
    	end
    end
end)


mods.gof.scatterWeapons = {}
local scatterWeapons = mods.gof.scatterWeapons
scatterWeapons["GOF_SCATTER_1"] = Hyperspace.Blueprints:GetWeaponBlueprint("GOF_SCATTER_1_PROJECTILE")
scatterWeapons["GOF_SCATTER_2"] = Hyperspace.Blueprints:GetWeaponBlueprint("GOF_SCATTER_2_PROJECTILE")
scatterWeapons["GOF_SCATTER_3"] = Hyperspace.Blueprints:GetWeaponBlueprint("GOF_SCATTER_3_PROJECTILE")

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local scatterDamage = scatterWeapons[weaponName]
    if scatterDamage then
        local rooms = {}
        local tblSize = 0
        for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            table.insert(rooms, roomPos)
            tblSize = tblSize + 1
        end

        if tblSize > 0 then
        	
        	local randomNumber = math.random(1, tblSize)
            local randomRoom = rooms[randomNumber]

            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local projectile = spaceManager:CreateLaserBlast(
            	scatterDamage,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                randomRoom,
                projectile.destinationSpace,
                projectile.heading)
            projectile:ComputeHeading()
        end
    end
end)

mods.gof.artilleryGuns = {}
local artilleryGuns = mods.gof.artilleryGuns
artilleryGuns["GOF_ARTY_1"] = true
artilleryGuns["GOF_ARTY_2"] = true
artilleryGuns["GOF_ARTY_3"] = true

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local weaponName = nil
		pcall(function() weaponName = weapon.blueprint.name end)
	    local artilleryGun = artilleryGuns[weaponName]
	    if artilleryGun then
	    	local weaponTable = userdata_table(weapon, "mods.gof.artilleryGuns")
	    	if weaponTable.target and weapon.targets[0] then
	    		weapon.targets[0] = weaponTable.target
	    	else

	    	end
	    end
	end
end)

mods.gof.manningWeapons = {}
local manningWeapons = mods.gof.manningWeapons
manningWeapons["GOF_HEAVY_0"] = Hyperspace.Damage()
manningWeapons["GOF_HEAVY_0"].iDamage = 1
manningWeapons["GOF_HEAVY_0"].fireChance = 10
manningWeapons["GOF_HEAVY_1"] = Hyperspace.Damage()
manningWeapons["GOF_HEAVY_1"].iDamage = 1
manningWeapons["GOF_HEAVY_1"].iSystemDamage = 1
manningWeapons["GOF_HEAVY_1"].fireChance = 10
manningWeapons["GOF_HEAVY_2"] = Hyperspace.Damage()
manningWeapons["GOF_HEAVY_2"].iDamage = 1
manningWeapons["GOF_HEAVY_2"].iSystemDamage = 1
manningWeapons["GOF_HEAVY_2"].fireChance = 10
manningWeapons["GOF_HEAVY_3"] = Hyperspace.Damage()
manningWeapons["GOF_HEAVY_3"].iDamage = 1
manningWeapons["GOF_HEAVY_3"].iSystemDamage = 1
manningWeapons["GOF_HEAVY_3"].fireChance = 10

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local manningData = manningWeapons[weaponName]
    if manningData and projectile.ownerId == 0 then
    	local shipManager = Hyperspace.ships.player
    	print(shipManager.weaponSystem.iActiveManned)
    	if shipManager.weaponSystem.iActiveManned <= 0 then
    		local roomPos = shipManager:GetRoomCenter(shipManager.weaponSystem.roomId)
    		shipManager:DamageArea(roomPos, manningData, true)
    	end
    end
end)

mods.gof.beamLasers = {}
local beamLasers = mods.gof.beamLasers
beamLasers["GOF_BEAM_1"] = true
beamLasers["GOF_BEAM_2"] = true
beamLasers["GOF_BEAM_3"] = true

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	if shipManager:HasSystem(0) then
	    local shieldPower = shipManager.shieldSystem.shields.power
	    local popData = nil
	    if pcall(function() popData = beamLasers[Hyperspace.Get_Projectile_Extend(projectile).name] end) and popData then
	    	if projectile.damage.iDamage > 1 then
	    		local halfDamage = math.floor(projectile.damage.iDamage/2)
	    		print(halfDamage)
		        if not (shieldPower.super.first > 0) then
		            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
		            shieldPower.first = math.max(0, shieldPower.first - halfDamage)
		            --projectile:Kill()
		        end
		    end
	    end
	end
end)

--[[mods.gof.autoCannons = {}
local autoCannons = mods.gof.autoCannons
autoCannons["GOF_CANNON_1"] = {5,5}
autoCannons["GOF_CANNON_2"] = {3,3}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
	local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local cannonData = autoCannons[weaponName]
    if cannonData then
    	cannonData[1] = cannonData[1] - 1
    	if cannonData[1] <= 0 then
    		local damage = Hyperspace.Damage()
    		damage.iDamage = 1
    		damage.fireChance = 1
    		projectile:SetDamage(damage)
    		cannonData[1] = cannonData[2]
    	end
    end
end)]]

mods.gof.autoCannon = {}
local autoCannon = mods.gof.autoCannon
autoCannon["GOF_CANNON_1"] = 20
autoCannon["GOF_CANNON_2"] = 34
autoCannon["GOF_CANNON_3"] = 50

local function damage_shields(shipManager, projectile)
	local shieldPower = shipManager.shieldSystem.shields.power
	if shieldPower.super.first > 0 then
        if popData.countSuper > 0 then
            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
            shieldPower.super.first = math.max(0, shieldPower.super.first - 1)
        end
    else
        shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
        shieldPower.first = math.max(0, shieldPower.first - 1)
    end
end

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local cannonDamage = autoCannon[weaponName]
    if cannonDamage and shipManager.iShipId == 1 then
    	Hyperspace.playerVariables.gofEnemyShield = Hyperspace.playerVariables.gofEnemyShield + cannonDamage
    	--print(Hyperspace.playerVariables.gofEnemyShield)
    	if Hyperspace.playerVariables.gofEnemyShield >= 100 then
    		Hyperspace.playerVariables.gofEnemyShield = Hyperspace.playerVariables.gofEnemyShield - (100)
    		damage_shields(shipManager, projectile)
		end
	elseif cannonDamage and shipManager.iShipId == 0 then
		Hyperspace.playerVariables.gofPlayerShield = Hyperspace.playerVariables.gofPlayerShield + cannonDamage
		--print(Hyperspace.playerVariables.gofPlayerShield)
    	if Hyperspace.playerVariables.gofPlayerShield >= 100 then
    		Hyperspace.playerVariables.gofPlayerShield = Hyperspace.playerVariables.gofPlayerShield - (100)
    		damage_shields(shipManager, projectile)
		end
    end
end)

local function damage_hull(shipManager, projectile)
	local damage = Hyperspace.Damage()
	damage.iDamage = 1
	damage.fireChance = 1
	shipManager:DamageArea(projectile.position, damage, true)
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local cannonDamage = autoCannon[weaponName]
    if cannonDamage and shipManager.iShipId == 1 then
    	Hyperspace.playerVariables.gofEnemyHull = Hyperspace.playerVariables.gofEnemyHull + cannonDamage
    	--print(Hyperspace.playerVariables.gofEnemyHull)
    	if Hyperspace.playerVariables.gofEnemyHull >= 100 then
    		Hyperspace.playerVariables.gofEnemyHull = Hyperspace.playerVariables.gofEnemyHull - (100+cannonDamage)
    		damage_hull(shipManager, projectile)
		end


	elseif cannonDamage and shipManager.iShipId == 0 then
		Hyperspace.playerVariables.gofPlayerHull = Hyperspace.playerVariables.gofPlayerHull + cannonDamage
		--print(Hyperspace.playerVariables.gofPlayerHull)
    	if Hyperspace.playerVariables.gofPlayerHull >= 100 then
    		Hyperspace.playerVariables.gofPlayerHull = Hyperspace.playerVariables.gofPlayerHull - (100+cannonDamage)
    		damage_hull(shipManager, projectile)
		end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	Hyperspace.playerVariables.gofEnemyShield = 0
	Hyperspace.playerVariables.gofEnemyHull = 0
	Hyperspace.playerVariables.gofPlayerShield = 0
	Hyperspace.playerVariables.gofPlayerHull = 0
end)

--[[
mods.gof.rocketPods = {}
local rocketPods = mods.gof.rocketPods
rocketPods["GOF_ROCKET_1"] = 5
rocketPods["GOF_ROCKET_2"] = 10
rocketPods["GOF_ROCKET_3"] = 15

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local rocketData = rocketPods[weaponName]
    if rocketData then
    	print(weaponName)
    	local rocketTable = userdata_table(weapon, "mods.gof.rocketPods")
    	if rocketTable.rockets then
    		rocketTable.rockets = rocketTable.rockets - 1
    		print("AMMO")
    		print(rocketTable.rockets)
    		if rocketTable.rockets <= 0 then 
    			weapon:SetCooldownModifier(-1)
    		end
    		--weapon.boostLevel = rocketTable.rockets
    	else
    		print("START AMMO")
    		rocketTable.rockets = rocketData - 1
    		--weapon.boostLevel = rocketTable.rockets
    	end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local rocketData = rocketPods[weapon.blueprint.name]
		if rocketData then
			weapon:SetCooldownModifier(1)
			userdata_table(weapon, "mods.gof.rocketPods").rockets = rocketData
			--weapon.boostLevel = rocketData
		end
	end
end)]]