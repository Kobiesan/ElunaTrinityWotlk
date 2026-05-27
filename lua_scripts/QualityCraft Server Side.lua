-- QualityCraft.lua (server-side Eluna script)
-- Sends item_quality_family and spell_quality_output data to clients at login
-- so the QualityCraft WoW addon can preview quality-specific crafting output.
--
-- Place this file in your server's lua_scripts/ directory (or wherever
-- LuaScriptDir points in worldserver.conf).

local ADDON_PREFIX = "QCRAFT"

-- Maximum bytes per addon message (WoW client limit is 255 bytes per message).
local MAX_MSG = 240

-- Helper: send a message, discarding any that are still too long.
local function Send(player, msg)
    if #msg > MAX_MSG then
        print("[QualityCraft] Warning: message too long (" .. #msg .. " bytes): " .. msg:sub(1, 60))
        return
    end
    player:SendAddonMessage(ADDON_PREFIX, msg, 7, player)
end

local function OnLogin(event, player)
    -- ---------------------------------------------------------------
    -- 1. Send item quality family data
    --    Protocol: "F|<familyId>|<quality1>:<itemId1>,<quality2>:<itemId2>,..."
    --    Each item is encoded as quality:itemId so the client knows the tier.
    -- ---------------------------------------------------------------
    local familyResult = WorldDBQuery("SELECT family_id, item_id, quality FROM item_quality_family ORDER BY family_id, quality")
    if familyResult then
        local families = {}
        repeat
            local familyId = familyResult:GetUInt32(0)
            local itemId   = familyResult:GetUInt32(1)
            local quality  = familyResult:GetUInt32(2)
            if not families[familyId] then
                families[familyId] = {}
            end
            table.insert(families[familyId], quality .. ":" .. itemId)
        until not familyResult:NextRow()

        for familyId, entries in pairs(families) do
            Send(player, "F|" .. familyId .. "|" .. table.concat(entries, ","))
        end
    end

    -- ---------------------------------------------------------------
    -- 2. Send spell quality output data
    --    Protocol (batched): "O|<spellId>:<quality>:<itemId>[;<spellId>:...]"
    -- ---------------------------------------------------------------
    local outputResult = WorldDBQuery("SELECT spell_id, quality, item_id FROM spell_quality_output ORDER BY spell_id, quality")
    if outputResult then
        local batch    = {}
        local batchLen = 2  -- "O|" prefix

        local function FlushBatch()
            if #batch > 0 then
                Send(player, "O|" .. table.concat(batch, ";"))
                batch    = {}
                batchLen = 2
            end
        end

        repeat
            local spellId = outputResult:GetUInt32(0)
            local quality = outputResult:GetUInt32(1)
            local itemId  = outputResult:GetUInt32(2)
            local entry   = spellId .. ":" .. quality .. ":" .. itemId

            -- +1 for the ";" separator between entries
            if batchLen + #entry + 1 > MAX_MSG then
                FlushBatch()
            end

            table.insert(batch, entry)
            batchLen = batchLen + #entry + 1
        until not outputResult:NextRow()

        FlushBatch()
    end
end

RegisterPlayerEvent(3, OnLogin)  -- PLAYER_EVENT_ON_LOGIN
