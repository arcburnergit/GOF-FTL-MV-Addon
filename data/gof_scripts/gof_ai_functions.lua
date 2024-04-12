
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
local cloakMaxTimer = 0
local activeProjectileIds = {}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager.iShipId == 1 then
        local playerShip = Hyperspace.ships.player
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local projectileList = spaceManager.projectiles
        if shipManager:HasSystem(0) then
            local weaponRoom = nil
            if shipManager:HasSystem(3) then
                weaponRoom = shipManager.weaponSystem.roomId
            end
            --print(weaponRoom)
            local stillActiveProj = {}
            local shieldTable = userdata_table(shipManager, "mods.ai.shieldSystem")

            local onlyIon = true
            local hasIon = false

            for projectile in vter(projectileList) do
                local roomTarget = get_room_at_location(shipManager, projectile.target, true)
                if roomTarget and projectile.currentSpace == 0 and roomTarget ~= weaponRoom and projectile.position.x > 750 and projectile.destinationSpace == 1 and projectile.ownerId == 0 then
                    if projectile.damage.iIonDamage > 0 and projectile.damage.iDamage <= 0 and projectile.damage.iSystemDamage <= 0 then
                        

                        stillActiveProj[projectile.selfId] = true
                        if not activeProjectileIds[projectile.selfId] then
                            --print(roomTarget)
                            --[[if roomTarget == weaponRoom then
                                print("WEAPONROOM TARGETTED")
                            end]]
                            hasIon = true
                            activeProjectileIds[projectile.selfId] = true
                        end
                    elseif projectile.damage.iDamage > 0 or projectile.damage.iSystemDamage > 0 and (projectile.currentSpace == 1 or (projectile.currentSpace == 0 and projectile.position.x > 600)) then
                        onlyIon = false
                    end
                end
            end

            if onlyIon and hasIon then
                shipManager.shieldSystem:SetPowerCap(0)
                shieldTable.shieldTime = 0.5
                --print("DEPOWER SHIELD")
            end

            if shieldTable.shieldTime then
                shieldTable.shieldTime = math.max(shieldTable.shieldTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if shieldTable.shieldTime == 0 then
                    shieldTable.shieldTime = nil
                    shipManager.shieldSystem:SetPowerCap(100)
                    --print("TURN ON SHIELD")
                end
            end


            for projId in pairs(activeProjectileIds) do
                if not stillActiveProj[projId] then
                    activeProjectileIds[projId] = nil
                end
            end
        end
        if shipManager:HasSystem(10) then
            local cloakSystem = shipManager.cloakSystem
            local cloakTimer = cloakSystem.timer
            local cloakOverride = false
            if cloakSystem.bTurnedOn then
                --print("cloaking")
                cloakMaxTimer = 0
            end
            cloakMaxTimer = math.min(cloakMaxTimer + Hyperspace.FPS.SpeedFactor/16, 20)
            if cloakMaxTimer == 20 then
                cloakMaxTimer = 0
                cloakOverride = true
            end

            local laserCount = 0
            local ionDamage = 0
            local ionClose = false
            local missileDamage = 0
            local missileClose = false
            for projectile in vter(projectileList) do 
                if projectile.damage.iDamage >= 1 and projectile.damage.iDamage + projectile.damage.iSystemDamage >= 1 and projectile.damage.iShieldPiercing <= 4 and projectile.damage.iIonDamage <= 0 then
                    laserCount = 1 + projectile.damage.iShieldPiercing
                elseif projectile.damage.iIonDamage > 0 then
                    ionDamage = ionDamage + projectile.damage.iIonDamage
                    if (projectile.currentSpace == 0 and projectile.position.x > 700) or projectile.currentSpace == 1 then
                        ionClose = true
                    end
                elseif projectile.damage.iShieldPiercing > 4 then
                    missileDamage = missileDamage + projectile.damage.iDamage
                    if (projectile.currentSpace == 0 and projectile.position.x > 700) or projectile.currentSpace == 1 then
                        missileClose = true
                    end
                end
            end

            local shieldHealth = 0
            if shipManager:HasSystem(0) then 
                shieldHealth = shipManager.shieldSystem.shields.power.first
            end

            if laserCount > shieldHealth + 1 or (laserCount + ionDamage > shieldHealth + 1 and ionClose)  then
                cloakMaxTimer = 0
                cloakOverride = true
            elseif missileDamage > (math.max(shieldHealth-1,2)) and missileClose then
                cloakMaxTimer = 0
                cloakOverride = true
            elseif ionDamage > shieldHealth and ionClose and (laserCount > 0 or missileDamage > 0) then
                cloakMaxTimer = 0
                cloakOverride = true
            end

            if cloakOverride then
                cloakMaxTimer = 0
                shipManager.cloakSystem:SetPowerCap(100)
            else
                shipManager.cloakSystem:SetPowerCap(0)
            end
        end
    end
end)