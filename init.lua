-- Mission_SORWaxwork
-- Version 1.0
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
local delay_before_zoning = 30000  -- 30s
local section = 0
local timeDelay = 1500
local holdLastKill = ''

Settings = {
    general = {
        GroupMessage = 'dannet',        -- or "bc" - not yet implemented
        Automation = 'CWTN',            -- Automation method, 'CWTN' for the CWTN plugins, 'rgmercs' for the rgmercs lua automation, 'KA' for KissAssist.  KissAssist and RGMercs lua are not supported currently, but should get added later on        
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
Logger.info('\awAutomation: \ay%s', Settings.general.Automation)
--if (Settings.general.Automation ~= 'CWTN' and Settings.general.Automation ~= 'rgmercs' and Settings.general.Automation ~= 'KA')  then
if (Settings.general.Automation ~= 'CWTN'  then
--    Logger.info("Unknown or invalid automation system. Must be either 'CWTN', 'rgmercs', or 'KA'. Ending script. \ar")
    Logger.info("Unknown or invalid automation system. Must be 'CWTN' currently, until I add the other automation systems'. Ending script. \ar")
    os.exit()
end

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
    mq.cmd('/dgga /boxr unpause')
    mq.cmd('/dge /boxr chase')
	if mq.TLO.Spawn(request_npc).Distance() > 40 then 
		Logger.info('You are in %s, but too far away from %s to start the mission! We will attempt to invis and run to the mission npc', request_zone, request_npc)
        GroupInvis(1)
        -- MoveToAndSay(request_npc, request_phrase)
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
    Logger.info('If you do not want to wait like this, change the PreManaCheck flag...')
	mq.delay(15000)
    ZoneCheck(quest_zone)
    TaskCheck(Task_Name)
end

mq.cmd('/dgga /squelch /boxr unpause')
-- in case you are starting the script after you are in the mission zone - need to determine what area you are close to
if Get_dist_to(-2363, -1296, -125) > 50 then
    Logger.debug('Not at Mob, so by zone in: X:%s Y:%s', mq.TLO.Me.X(), mq.TLO.Me.Y())
    Logger.info('Doing some setup. Invising and moving to camp spot.')

    GroupInvis(1)

    mq.delay(2000)

    mq.cmd('/squelch /dgga /nav locyx -2363 -1296 log=off')
    WaitForNav()
end

while Get_dist_to(-2363, -1296, -125) > 50 do
    GroupInvis(1)
    mq.cmd('/squelch /dgga /nav locyx -2363 -1296 log=off')
    WaitForNav()
    mq.delay(5000) -- make sure everyone gets to the proper camp spot
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


local event_zoned = function(line)
    -- zoned so quit
    Command = 1
end

local event_failed = function(line)
    -- failed so quit
    Command = 1
end

local function getHighestHPXTarget()
    local pickSpawn = nil
    local hpCompare = 0

    for i = 1, mq.TLO.Me.XTargetSlots() do
        local xt = mq.TLO.Me.XTarget(i)
        if xt() and xt.ID() > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() then
                local hp = spawn.PctHPs() or 0
                if hp > hpCompare then
                    hpCompare = hp
                    pickSpawn = spawn
                end
                if hp ~= 0 and hp <= 40 and timeDelay > 500 then 
                    timeDelay = 100 
                    Logger.info('Switching addcheck to faster mode')
                end
            end
        end
    end

    return pickSpawn
end

local function getLowestHPXTarget()
    local pickSpawn = nil
    local hpCompare = 0

    for i = 1, mq.TLO.Me.XTargetSlots() do
        local xt = mq.TLO.Me.XTarget(i)
        if xt() and xt.ID() > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() then
                local hp = spawn.PctHPs() or 0
                if hp < hpCompare then
                    hpCompare = hp
                    pickSpawn = spawn
                end
                -- if 
                --     hp ~= 0 and hp <= 30 then timeDelay = 500 
                --     Logger.info('Switching to Lowest')
                -- end
            end
        end
    end

    return pickSpawn
end


local addFlag = 0
local addCount = 0

mq.event('Zoned','LOADING, PLEASE WAIT...#*#',event_zoned)

mq.event('Failed','#*#The Waxwork Abolishion groans and turns its attention to more interesting enemies#*#',event_failed)

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
            addFlag  = 0 
            holdLastKill = ''
            Logger.info('Waxwork Abolishion Attack...')
        end
        Logger.debug('Waxwork Abolishion Attack branch ...')
        MoveToTargetAndAttack('Waxwork Abolishion')
	
	end

    --Adds Section - balance kill the adds
    while mq.TLO.SpawnCount("Waxwork Abolishion")() < 1 do
        if mq.TLO.Me.XTarget() > 0 and addFlag == 0 then
            addCount =  mq.TLO.Me.XTarget()
            addFlag = 1
            section = 2
            Logger.debug('Target Count: %s',addCount)
            Logger.info('Attacking Split Mobs, until they are dead or despawn...')
        end

        local spawnToKill = getHighestHPXTarget()
        
        -- if timeDelay < 1000 and mq.TLO.Me.XTarget() < addCount then 
        --     spawnToKill = getLowestHPXTarget() 
        --     Logger.debug('Switch to Lowest')
        -- end

        if spawnToKill then
            local attackName = spawnToKill.CleanName()

            if attackName ~= holdLastKill then
                Logger.debug('Attacking: %s',attackName)
                holdLastKill = attackName
            end
            
            MoveToTargetAndAttack(attackName)
        end
    

        mq.delay(timeDelay)
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