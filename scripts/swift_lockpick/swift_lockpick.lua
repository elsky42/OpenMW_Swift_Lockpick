local camera = require('openmw.camera')
local I = require('openmw.interfaces')
local input = require('openmw.input')
local nearby = require('openmw.nearby')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local ui = require('openmw.ui')
local util = require('openmw.util')

local Actor = types.Actor
local Lockable = types.Lockable
local Lockpick = types.Lockpick
-- local Probe = types.Probe
local Settings = I.Settings

Settings.registerPage {
    key = 'SwiftLockpickPage',
    l10n = 'SwiftLockpick',
    name = 'Swift Lockpick',
    description = 'Automatically equip a lockpick when a key is pressed close to a locked container',
}
Settings.registerGroup {
    key = 'SwiftLockpickSettings',
    page = 'SwiftLockpickPage',
    l10n = 'SwiftLockpick',
    name = 'Swift Lockpick',
    description = '',
    permanentStorage = false,
    settings = {
        {
            key = 'isEnabled',
            renderer = 'checkbox',
            name = 'Enabled',
            description = 'Enable or disable the mod',
            default = true,
        },
        {
            key = 'keySymbol',
            renderer = 'textLine',
            name = 'Key',
            default = input.getKeyName(input.KEY.Space),
        }
    }
}

local playerSettings = storage.playerSection('SwiftLockpickSettings')

local function lookup_container()
    local origin = camera.getPosition()
    local direction = camera.viewportToWorldVector(util.vector2(0.5, 0.5)) or util.vector3(0, 0, 0)
    local front = origin + direction * 300
    return nearby.castRay(origin, front, {ignore=self})
end

local function looking_at_locked_container()
    local res = lookup_container()
    if res == nil then return false end
    -- print('res ' .. tostring(res.hitObject))
    return Lockable.objectIsInstance(res.hitObject) and
       Lockable.isLocked(res.hitObject)
end

-- local function looking_at_trapped_container()
--     local res = lookup_container()
--     if res == nil then return false end
--     print('res ' .. tostring(res.hitObject))
--     return Lockable.objectIsInstance(res.hitObject) and
--        Lockable.getTrapSpell(res.hitObject) ~= nil
-- end

local function equip(itemOrNil)
    local equipment = Actor.getEquipment(self)
    if itemOrNil then
        equipment[Actor.EQUIPMENT_SLOT.CarriedRight] = itemOrNil
    else
        table.remove(equipment, Actor.EQUIPMENT_SLOT.CarriedRight)
    end
    Actor.setEquipment(self, equipment)
end

local function rotate_carried_lockpick()
    local carried = Actor.getEquipment(self, Actor.EQUIPMENT_SLOT.CarriedRight)
    local quality = -1
    if carried and Lockpick.objectIsInstance(carried) then
        quality = Lockpick.record(carried).quality + 0.1
    end
    print('Searching for lockpick with quality ' .. tostring(quality))
    local found = nil;
    for i, lockpick in ipairs(Actor.inventory(self):getAll(Lockpick)) do
        local record = Lockpick.record(lockpick)
        if (not found or Lockpick.record(found).quality > record.quality) and record.quality >= quality then
            found = lockpick
        end
    end
    if quality ~= -1 or found then
        equip(found)
        Actor.setStance(self, Actor.STANCE.Weapon)
        if found then
            ui.showMessage(Lockpick.record(found).name .. ' equipped')
        end
    end
end

-- local function rotate_carried_probe()
--     local carried = Actor.getEquipment(self, Actor.EQUIPMENT_SLOT.CarriedRight)
--     local quality = -1
--     if carried and Probe.objectIsInstance(carried) then
--         quality = Probe.record(carried).quality + 0.1
--     end
--     print('Searching for probe with quality ' .. tostring(quality))
--     for i, probe in ipairs(Actor.inventory(self):getAll(Probe)) do
--         local record = Probe.record(probe)
--         if record.quality >= quality then
--             equip(probe)
--             Actor.setStance(self, Actor.STANCE.Weapon)
--             ui.showMessage(record.name .. ' equipped')
--             return
--         end
--     end
--     equip(nil)
--     Actor.setStance(self, Actor.STANCE.Weapon)
-- end

local function onKeyPress(key)
    if playerSettings:get('isEnabled') and input.getKeyName(key.code):lower() == playerSettings:get('keySymbol'):lower() then
        if looking_at_locked_container() then
            rotate_carried_lockpick()
        -- elseif looking_at_trapped_container() then
            -- rotate_carried_probe()
            
        end
    end
end

return {
    engineHandlers = {
        onKeyPress = onKeyPress,
    }
}