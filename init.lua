-- Mission_TOBHazuri
-- Version 1.2
-- TODO: Implement bc support if asked for
-- TODO: Implement RGMercs.lua support if asked for (it has been)
-- Error Reports:
-- 
---------------------------
local mq = require('mq')
LIP = require('lib.LIP')
Logger = require('utils.logger')
C = require('utils/common')

-- #region Variables
Logger.set_log_level(4) -- 4 = Info level, use 5 for debug, and 6 for trace
Zone_name = mq.TLO.Zone.ShortName()
Task_Name = 'Waxwork Abolishion'
Command = 0

local Ready = false
local my_class = mq.TLO.Me.Class.ShortName()
local request_zone = 'candlemakers'
local request_npc = 'Defense Unit CDL'
local request_phrase = 'accept'
local zonein_phrase = 'ready'
local quest_zone = 'candlemakers_mission'
local delay_before_zoning = 27000  -- 27s
local section = 0

Settings = {
    general = {
        GroupMessage = 'dannet',        -- or "bc" - not yet implemented
        Automation = 'CWTN',            -- automation method, 'CWTN' for the CWTN plugins, or 'rgmercs' for the rgmercs lua automation.  KissAssist is not really supported currently, though it might work
        PreManaCheck = false,           -- true to pause until the check for everyone's mana, endurance, hp is full before proceeding, false if it stalls at that point
        Burn = true,                    -- Whether we should burn by default. Some people have a bit of trouble handling the adds when the yburn, so you are able to turn this off if you want
        OpenChest = false,              -- true if you want to open the chest automatically at the end of the mission run. I normally do not do this as you can swap toon's out before opening the chest to get the achievements
        WriteCharacterIni = true,       -- Write/read character specific ini file to be able to run different groups with different parameters.  This must be changed in this section of code to take effect
    }
}
-- #endregion


Logger.info('\awGroup Chat: \ay%s', Settings.general.GroupMessage)
if (Settings.general.GroupMessage ~= 'dannet' and Settings.general.GroupMessage ~= 'bc')  then
   Logger.info("Unknown or invalid group command. Must be either 'dannet' or 'bc'. Ending script. \ar")
   os.exit()
end

Logger.info('\awAutomation: \ay%s', Settings.general.Automation)
Logger.info('\awPreManaCheck: \ay%s', Settings.general.PreManaCheck)
Logger.info('\awBurn: \ay%s', Settings.general.Burn)
Logger.info('\awOpen Chest: \ay%s', Settings.general.OpenChest)
Logger.info('\awWrite Character Ini: \ay%s\aw.', Settings.general.WriteCharacterIni)
if (Settings.general.WriteCharacterIni == true) then
    Load_settings()
elseif (Settings.general.WriteCharacterIni == false) then
else
    Logger.info("\awWrite Character Ini: %s \ar Invalid value. You can only use true or false.  Exiting script until you fix the issue.\ar", Settings.general.WriteCharacterIni)
    os.exit()
end

if my_class ~= 'WAR' and my_class ~= 'SHD' and my_class ~= 'PAL' then 
	Logger.info('You must run the script on a tank class...')
	os.exit()
end
mq.cmdf('/%s pause on', my_class)

if mq.TLO.Me.Combat() == true then 
    Logger.info('You started the script while you are in Combat.  Please kill the mobs first, then restart the script. Exiting script...')
	os.exit()
end

if mq.TLO.Group.AnyoneMissing() then
    Logger.info('You started the script, but not everyone is actually in zone with you. Exiting script...')
    os.exit()
end

if CheckGroupDistance(50) ~= true then 
    Logger.info('You started the script, but not everyone is within 50 feet of you. Exiting script...')
    os.exit()
end

if Zone_name == request_zone then 
	if mq.TLO.Spawn(request_npc).Distance() > 40 then 
		Logger.info('You are in %s, but too far away from %s to start the mission! We will attempt to invis and run to the mission npc', request_zone, request_npc)
        GroupInvis(1)
        MoveToAndSay(request_npc, request_phrase)
    end
    local task = Task(Task_Name, request_zone, request_npc, request_phrase)
    WaitForTask(delay_before_zoning)
    ZoneIn(request_npc, zonein_phrase, quest_zone)
    mq.delay(5000)
    local allinzone = WaitForGroupToZone(600)
    if allinzone == false then
        Logger.info('Timeout while waiting for everyone to zone in.  Please check what is happening and restart the script')
        os.exit()
    end
end

Zone_name = mq.TLO.Zone.ShortName()

if Zone_name ~= quest_zone then 
	Logger.info('You are not in the mission...')
	os.exit()
end

if mq.TLO.Group.AnyoneMissing() then
    Logger.info('You started the script in the mission zone, but not everyone is actually in zone.  Exiting script...')
    os.exit()
end
-- Check group mana / endurance / hp
while Settings.general.PreManaCheck == true and Ready == false do 
	Ready = CheckGroupStats()
	mq.cmd('/noparse /dgga /if (${Me.Standing}) /sit')
    Logger.info('Waiting for full hp / mana/ endurance to proceed...')
	mq.delay(15000)
    ZoneCheck(quest_zone)
    TaskCheck(Task_Name)
end

-- in case you are starting the script after you are in the mission zone - need to determine what area you are close to
if math.abs(mq.TLO.Me.Y() + 2363) > 200 or math.abs(mq.TLO.Me.X() + 1296) > 200 then
    Logger.debug('Not at Mob, so by zone in: X:%s Y:%s', mq.TLO.Me.X(), mq.TLO.Me.Y())
    Logger.info('Doing some setup. Invising and moving to camp spot.')

    GroupInvis(1)

    mq.delay(2000)

    mq.cmd('/squelch /dgga /nav locyx -2363 -1296 log=off')
    WaitForNav()
end

if math.abs(mq.TLO.Me.Y() + 2363) > 200 or math.abs(mq.TLO.Me.X() + 1296) > 200 then
    mq.cmd('/squelch /dgga /nav locyx -2363 -1296 log=off')
    WaitForNav()
end

Logger.info('Doing some setup...')

DoPrep()

Logger.info('Starting the event in 10 seconds!')

mq.delay(10000)


Logger.info('Starting the event...')
MoveToAndSay('Waxwork Abolishion', 'destroy')

mq.cmdf('/%s gotocamp', my_class)
-- mq.cmd('/squelch /nav locyx -240 50 log=off')
WaitForNav()

-- This section was waiting till all the starting adds were killed to do the rest of the script

-- Logger.info('Killing the 4 initial adds...')
-- while mq.TLO.SpawnCount("Waxwork Abolishion")() > 0 do
--     if (mq.TLO.SpawnCount('Waxwork Abolishion npc radius 60')() > 0) then
--         Logger.debug('Waxwork Abolishion Attack branch...')
--         MoveToTargetAndAttack('Waxwork Abolishion')
--     end
-- 	mq.delay(1000)
--     ZoneCheck(quest_zone)
--     TaskCheck(Task_Name)
-- end

local event_zoned = function(line)
    -- zoned so quit
    Command = 1
end

local event_failed = function(line)
    -- failed so quit
    Command = 1
end

local function getHighestHPXTarget()
    local highestSpawn = nil
    local highestHP = 0

    for i = 1, mq.TLO.Me.XTargetSlots() do
        local xt = mq.TLO.Me.XTarget(i)
        if xt() and xt.ID() > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() then
                local hp = spawn.PctHPs() or 0
                if hp > highestHP then
                    highestHP = hp
                    highestSpawn = spawn
                end
            end
        end
    end

    return highestSpawn
end

mq.event('Zoned','LOADING, PLEASE WAIT...#*#',event_zoned)
mq.event('Failed','#*#summons overwhelming enemies and your mission fails.#*#',event_failed)

while true do
	mq.doevents()

	if Command == 1 then
        break
	end

	if mq.TLO.SpawnCount('_chest')() == 1 then
		Logger.info('I see the chest! You won!')
		break
	end

    if (mq.TLO.SpawnCount('Waxwork Abolishion npc')() > 0 ) then 
        if (section ~= 1) then 
            section = 1
            Logger.info('Waxwork Abolishion Attack...')
        end
        Logger.debug('Waxwork Abolishion Attack branch ...')
        MoveToTargetAndAttack('Waxwork Abolishion')
	
	end

    --Adds Section - balance kill the adds
    while mq.TLO.SpawnCount("Waxwork Abolishion")() < 1 do
        if mq.TLO.Me.XTarget() > 0 then
            -- local target = getHighestHPXTarget()
            -- if target then
            --     print(string.format("Highest HP ETW mob: %s (%d%% HP)", target.Name(), target.PctHPs()))
            -- else
            --     print("No mobs found on ETW.")
            -- end
            local highestHpSpawn = getHighestHPXTarget()
            if highestHpSpawn then
                local attackName = highestHpSpawn.CleanName()
                Logger.debug('Highest HP Name: ',attackName)
                MoveToTargetAndAttack(attackName)
            end
        end

        mq.delay(2000)
        ZoneCheck(quest_zone)
        TaskCheck(Task_Name)
    end

    if mq.TLO.Target() ~= nil then 
        if mq.TLO.Target.Distance() > 20 then
            mq.cmd('/squelch /nav target distance=20 log=off') 
            WaitForNav()
        end
    end
			
	if math.abs(mq.TLO.Me.Y() + 2363) > 25 or math.abs(mq.TLO.Me.X() + 1296) > 25 then
		if math.random(1000) > 800 then
			mq.cmd('/squelch /nav locyx -2363 -1296 log=off')
            WaitForNav()
		end
	end
	mq.delay(1000)
    ZoneCheck(quest_zone)
    TaskCheck(Task_Name)
end

if (Settings.general.OpenChest == true) then Action_OpenChest() end

mq.unevent('Zoned')
mq.unevent('Failed')
ClearStartingSetup()
Logger.info('...Ended')