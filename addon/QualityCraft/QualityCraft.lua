-- QualityCraft.lua (WoW 3.3.5 client-side addon)
--
-- Receives quality-family and quality-output data from the server (via the
-- QualityCraft Eluna script) and adds a small label to the TradeSkill frame
-- showing which quality item will actually be created based on the reagents
-- currently in the player's inventory.
--
-- Installation: copy the QualityCraft/ folder to:
--   <WoW>/Interface/AddOns/QualityCraft/

local ADDON_PREFIX = "QCRAFT"

-- Tables populated from server messages
-- qualityFamilies[itemId] = familyId
-- familyItems[familyId]   = { itemId, ... }
-- spellOutput[spellId][quality] = outputItemId
local qualityFamilies = {}
local familyItems     = {}
local spellOutput     = {}

-- Quality metadata (matches item_template.Quality enum values)
local QUALITY_COLOR = {
    [0] = "|cff9d9d9d",  -- Poor
    [1] = "|cffffffff",  -- Common
    [2] = "|cff1eff00",  -- Uncommon
    [3] = "|cff0070dd",  -- Rare
    [4] = "|cffa335ee",  -- Epic
    [5] = "|cffff8000",  -- Legendary
}
local QUALITY_NAME = { [0]="Poor", [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary" }

-- -----------------------------------------------------------------------
-- Addon message handling
-- -----------------------------------------------------------------------
RegisterAddonMessagePrefix(ADDON_PREFIX)

local msgFrame = CreateFrame("Frame")
msgFrame:RegisterEvent("CHAT_MSG_ADDON")
msgFrame:RegisterEvent("TRADE_SKILL_UPDATE")
msgFrame:RegisterEvent("TRADE_SKILL_SHOW")
msgFrame:RegisterEvent("ADDON_LOADED")

local outputLabel  -- FontString added to TradeSkillFrame

local function ParseFamilyMessage(data)
    -- "F|<familyId>|<itemId1>,<itemId2>,..."
    local familyId, itemList = data:match("^(%d+)|(.+)$")
    familyId = tonumber(familyId)
    if not familyId then return end

    familyItems[familyId] = familyItems[familyId] or {}
    for idStr in itemList:gmatch("[^,]+") do
        local itemId = tonumber(idStr)
        if itemId then
            qualityFamilies[itemId] = familyId
            local found = false
            for _, v in ipairs(familyItems[familyId]) do
                if v == itemId then found = true; break end
            end
            if not found then
                table.insert(familyItems[familyId], itemId)
            end
        end
    end
end

local function ParseOutputMessage(data)
    -- "O|<spellId>:<quality>:<itemId>[;<spellId>:...]"
    for entry in data:gmatch("[^;]+") do
        local spellId, quality, itemId = entry:match("^(%d+):(%d+):(%d+)$")
        spellId  = tonumber(spellId)
        quality  = tonumber(quality)
        itemId   = tonumber(itemId)
        if spellId and quality and itemId then
            spellOutput[spellId] = spellOutput[spellId] or {}
            spellOutput[spellId][quality] = itemId
        end
    end
end

-- -----------------------------------------------------------------------
-- Quality preview logic
-- -----------------------------------------------------------------------

-- Returns the spell ID embedded in a recipe link (|Henchant:SPELLID|h).
local function GetSpellIdFromLink(link)
    if not link then return nil end
    return tonumber(link:match("|Henchant:(%d+)|h"))
end

-- Returns the best quality (and matching itemId) of any family member the
-- player currently has in their bags for the given base itemId.
local function GetBestFamilyQuality(baseItemId)
    local fid = qualityFamilies[baseItemId]
    local candidates = fid and familyItems[fid] or { baseItemId }

    local bestQuality = -1
    local bestItemId  = nil
    for _, variantId in ipairs(candidates) do
        local count = GetItemCount(variantId) or 0
        if count > 0 then
            local _, _, quality = GetItemInfo(variantId)
            quality = quality or 1
            if quality > bestQuality then
                bestQuality = quality
                bestItemId  = variantId
            end
        end
    end
    return (bestQuality >= 0) and bestQuality or nil, bestItemId
end

-- Updates the quality-preview label in the TradeSkill frame.
local function UpdateQualityLabel()
    if not outputLabel then return end
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then
        outputLabel:SetText("")
        return
    end

    local index = TradeSkillFrame.selectedSkill
    if not index then
        outputLabel:SetText("")
        return
    end

    local recipeLink = GetTradeSkillRecipeLink(index)
    local spellId    = GetSpellIdFromLink(recipeLink)
    if not spellId or not spellOutput[spellId] then
        outputLabel:SetText("")
        return
    end

    -- Find the highest quality among reagents that belong to a family
    local numReagents   = GetTradeSkillNumReagents(index)
    local detectedQuality = nil

    for i = 1, numReagents do
        local reagentName, _, reagentCount = GetTradeSkillReagentInfo(index, i)
        if reagentName then
            -- Resolve reagent name -> itemId via family tables
            for itemId, _ in pairs(qualityFamilies) do
                local name = GetItemInfo(itemId)
                if name == reagentName then
                    local quality = GetBestFamilyQuality(itemId)
                    if quality and (not detectedQuality or quality > detectedQuality) then
                        detectedQuality = quality
                    end
                    break
                end
            end
        end
    end

    if detectedQuality and spellOutput[spellId][detectedQuality] then
        local outItemId = spellOutput[spellId][detectedQuality]
        local name, _, quality = GetItemInfo(outItemId)
        if name then
            local color = QUALITY_COLOR[quality] or "|cffffffff"
            outputLabel:SetText("Will craft: " .. color .. name .. "|r")
            return
        end
    end

    outputLabel:SetText("")
end

-- -----------------------------------------------------------------------
-- Frame / UI setup
-- -----------------------------------------------------------------------

local function EnsureLabel()
    if outputLabel then return end
    if not TradeSkillFrame then return end

    outputLabel = TradeSkillFrame:CreateFontString(
        "QualityCraftOutputLabel", "OVERLAY", "GameFontNormalSmall")
    outputLabel:SetPoint("BOTTOMLEFT", TradeSkillFrame, "BOTTOMLEFT", 8, 8)
    outputLabel:SetWidth(300)
    outputLabel:SetJustifyH("LEFT")
    outputLabel:SetText("")
end

msgFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix ~= ADDON_PREFIX then return end

        local msgType = message:sub(1, 1)
        local data    = message:sub(3)  -- skip "X|"

        if msgType == "F" then
            ParseFamilyMessage(data)
        elseif msgType == "O" then
            ParseOutputMessage(data)
        end

    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "QualityCraft" then
            -- Hook TradeSkillFrame_Update if it exists already
            if TradeSkillFrame_Update then
                hooksecurefunc("TradeSkillFrame_Update", UpdateQualityLabel)
            end
        end

    elseif event == "TRADE_SKILL_SHOW" then
        EnsureLabel()
        UpdateQualityLabel()

    elseif event == "TRADE_SKILL_UPDATE" then
        UpdateQualityLabel()
    end
end)
