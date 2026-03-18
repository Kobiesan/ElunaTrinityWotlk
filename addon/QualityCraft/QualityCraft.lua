-- QualityCraft.lua (WoW 3.3.5a client-side addon)
--
-- Adds a quality-tier dropdown to every reagent icon in the TradeSkill window
-- that belongs to an item_quality_family group.  The player's selection is:
--   * Previewed as "Will craft: <quality> <item>" at the bottom of the window.
--   * Sent to the server so Spell::TakeReagents honours the chosen tier.
--
-- Installation: copy the QualityCraft/ folder to:
--   <WoW>/Interface/AddOns/QualityCraft/

local ADDON_PREFIX = "QCRAFT"
local MAX_REAGENTS = 8  -- mirrors MAX_SPELL_REAGENTS on the server

-- -----------------------------------------------------------------------
-- Quality display helpers
-- -----------------------------------------------------------------------
local QUALITY_COLOR = {
    [0] = "|cff9d9d9d",  -- Poor
    [1] = "|cffffffff",  -- Common
    [2] = "|cff1eff00",  -- Uncommon
    [3] = "|cff0070dd",  -- Rare
    [4] = "|cffa335ee",  -- Epic
    [5] = "|cffff8000",  -- Legendary
}
local QUALITY_NAME = {
    [0] = "Poor", [1] = "Common", [2] = "Uncommon",
    [3] = "Rare",  [4] = "Epic",   [5] = "Legendary",
}

-- -----------------------------------------------------------------------
-- Data tables populated from server messages
-- -----------------------------------------------------------------------
-- itemFamilyId[itemId]           = familyId
-- familyQuality[itemId]          = explicit quality tier (from item_quality_family.quality)
-- familyByQuality[familyId]      = { [quality] = itemId }
-- spellOutput[spellId][quality]  = outputItemId
local itemFamilyId    = {}
local familyQuality   = {}
local familyByQuality = {}
local spellOutput     = {}

-- -----------------------------------------------------------------------
-- Addon message registration
-- -----------------------------------------------------------------------
RegisterAddonMessagePrefix(ADDON_PREFIX)

-- -----------------------------------------------------------------------
-- Frames and UI state
-- -----------------------------------------------------------------------
local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("CHAT_MSG_ADDON")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("TRADE_SKILL_SHOW")
mainFrame:RegisterEvent("TRADE_SKILL_UPDATE")
mainFrame:RegisterEvent("TRADE_SKILL_CLOSE")

local outputLabel                -- FontString at bottom of TradeSkillFrame
local pickerButtons = {}         -- pickerButtons[i] = picker Button for reagent slot i (1-based)
local dropdownFrame              -- UIDropDownMenu frame (shared)
local dropdownSlot               -- 1-based reagent slot the current dropdown is for
local dropdownSpellId            -- spellId the current dropdown belongs to

-- Flag to prevent double-hooking Blizzard_TradeSkillUI (it is LoadOnDemand)
local hooked = false

-- -----------------------------------------------------------------------
-- SavedVariables helpers (QualityCraftDB.selections[spellId][slot] = itemId)
-- -----------------------------------------------------------------------
local function GetSelection(spellId, slot)  -- slot is 0-based
    if not QualityCraftDB or not QualityCraftDB.selections then return 0 end
    local t = QualityCraftDB.selections[spellId]
    return t and (t[slot] or 0) or 0
end

local function SaveSelection(spellId, slot, itemId)  -- slot is 0-based
    QualityCraftDB = QualityCraftDB or {}
    QualityCraftDB.selections = QualityCraftDB.selections or {}
    QualityCraftDB.selections[spellId] = QualityCraftDB.selections[spellId] or {}
    QualityCraftDB.selections[spellId][slot] = itemId
end

-- -----------------------------------------------------------------------
-- Server communication
-- -----------------------------------------------------------------------
local function SendSelectionToServer(spellId)
    local parts = {}
    for i = 0, MAX_REAGENTS - 1 do
        parts[i + 1] = tostring(GetSelection(spellId, i))
    end
    SendAddonMessage(ADDON_PREFIX, "SEL|" .. spellId .. "|" .. table.concat(parts, ","),
                     "WHISPER", UnitName("player"))
end

-- -----------------------------------------------------------------------
-- Message parsing
-- -----------------------------------------------------------------------
local function ParseFamilyMessage(data)
    -- Protocol: "F|<familyId>|<q1>:<itemId1>,<q2>:<itemId2>,..."
    local familyId, entryList = data:match("^(%d+)|(.+)$")
    familyId = tonumber(familyId)
    if not familyId then return end

    familyByQuality[familyId] = familyByQuality[familyId] or {}
    for entry in entryList:gmatch("[^,]+") do
        local q, id = entry:match("^(%d+):(%d+)$")
        q  = tonumber(q)
        id = tonumber(id)
        if q and id then
            itemFamilyId[id]              = familyId
            familyQuality[id]             = q
            familyByQuality[familyId][q]  = id
        end
    end
end

local function ParseOutputMessage(data)
    -- Protocol: "O|<spellId>:<quality>:<itemId>[;<spellId>:...]"
    for entry in data:gmatch("[^;]+") do
        local sid, q, id = entry:match("^(%d+):(%d+):(%d+)$")
        sid = tonumber(sid)
        q   = tonumber(q)
        id  = tonumber(id)
        if sid and q and id then
            spellOutput[sid]    = spellOutput[sid] or {}
            spellOutput[sid][q] = id
        end
    end
end

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------
local function GetCurrentSpellId()
    local idx = GetTradeSkillSelectionIndex()
    if not idx or idx == 0 then return nil end
    local link = GetTradeSkillRecipeLink(idx)
    if not link then return nil end
    return tonumber(link:match("|Henchant:(%d+)|h"))
end

local function GetReagentItemId(skillIndex, reagentIndex)
    local link = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
    if not link then return nil end
    return tonumber(link:match("|Hitem:(%d+):"))
end

-- Determine the effective quality that will be used when crafting
-- (the lowest quality among user-selected reagents that have an output mapping)
local function GetEffectiveCraftQuality(spellId, tradeIndex)
    if not spellOutput[spellId] then return nil end
    local numReagents = GetTradeSkillNumReagents(tradeIndex)
    local effectiveQ  = nil

    for i = 1, numReagents do
        local baseId = GetReagentItemId(tradeIndex, i)
        if baseId and itemFamilyId[baseId] then
            local fid    = itemFamilyId[baseId]
            local selId  = GetSelection(spellId, i - 1)
            local usedQ

            if selId and selId ~= 0 and familyQuality[selId] then
                usedQ = familyQuality[selId]
            else
                -- Auto: pick best available in bags
                for q = 5, 0, -1 do
                    local vid = familyByQuality[fid] and familyByQuality[fid][q]
                    if vid and (GetItemCount(vid) or 0) > 0 then
                        usedQ = q
                        break
                    end
                end
            end

            if usedQ then
                if effectiveQ == nil or usedQ < effectiveQ then
                    effectiveQ = usedQ
                end
            end
        end
    end
    return effectiveQ
end

-- -----------------------------------------------------------------------
-- Dropdown initialisation callback (called by UIDropDownMenu_Initialize)
-- -----------------------------------------------------------------------
local function DropdownInit(self, level)
    if not dropdownSlot or not dropdownSpellId then return end

    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local baseItemId = GetReagentItemId(tradeIndex, dropdownSlot)
    if not baseItemId then return end

    local fid = itemFamilyId[baseItemId]
    if not fid or not familyByQuality[fid] then return end

    local currentItemId = GetSelection(dropdownSpellId, dropdownSlot - 1)

    -- "Auto" entry
    local autoInfo = UIDropDownMenu_CreateInfo()
    autoInfo.notCheckable = false
    autoInfo.checked      = (currentItemId == 0)
    autoInfo.text         = "|cffaaaaaa(Auto \226\128\147 use best available)|r"
    autoInfo.func = function()
        SaveSelection(dropdownSpellId, dropdownSlot - 1, 0)
        SendSelectionToServer(dropdownSpellId)
        UpdateQualityUI()
    end
    UIDropDownMenu_AddButton(autoInfo, level)

    -- One entry per quality tier, sorted ascending
    local qualities = {}
    for q in pairs(familyByQuality[fid]) do
        table.insert(qualities, q)
    end
    table.sort(qualities)

    for _, q in ipairs(qualities) do
        local variantId = familyByQuality[fid][q]
        local name, _   = GetItemInfo(variantId)
        local count     = GetItemCount(variantId) or 0
        local color     = QUALITY_COLOR[q] or "|cffffffff"
        local qname     = QUALITY_NAME[q] or tostring(q)

        local info          = UIDropDownMenu_CreateInfo()
        info.notCheckable   = false
        info.checked        = (currentItemId == variantId)
        info.disabled       = (count == 0)
        info.text           = color .. qname .. "|r  " .. (name or "?") .. "  |cffaaaaaa(" .. count .. ")|r"
        local capturedId    = variantId
        info.func = function()
            SaveSelection(dropdownSpellId, dropdownSlot - 1, capturedId)
            SendSelectionToServer(dropdownSpellId)
            UpdateQualityUI()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

-- -----------------------------------------------------------------------
-- Picker button per reagent slot
-- -----------------------------------------------------------------------
local function GetOrCreatePickerButton(i)
    if pickerButtons[i] then return pickerButtons[i] end

    local parent = _G["TradeSkillReagent" .. i]
    if not parent then return nil end

    local btn = CreateFrame("Button", "QCPickerBtn" .. i, parent)
    btn:SetWidth(20)
    btn:SetHeight(20)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    btn:SetFrameLevel(parent:GetFrameLevel() + 5)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.85)
    btn.bg = bg

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetJustifyV("MIDDLE")
    lbl:SetText("|cffffffff\226\150\190|r")
    btn.label = lbl

    btn.reagentSlot = i  -- 1-based

    btn:SetScript("OnClick", function(self)
        dropdownSlot    = self.reagentSlot
        dropdownSpellId = GetCurrentSpellId()
        if not dropdownSpellId then return end
        UIDropDownMenu_Initialize(dropdownFrame, DropdownInit, "MENU")
        ToggleDropDownMenu(1, nil, dropdownFrame, self, 0, 0)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to select reagent quality tier", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    pickerButtons[i] = btn
    return btn
end

-- -----------------------------------------------------------------------
-- FixReagentCounts
-- Called after TradeSkillFrame_SetSelection runs.  The Blizzard code only
-- counts the exact base item; this function also counts quality-family
-- variants so family items are shown as available.
-- -----------------------------------------------------------------------
local function FixReagentCounts()
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local numReagents = GetTradeSkillNumReagents(tradeIndex)
    local allSatisfied = true

    for i = 1, numReagents do
        local reagentFrame = _G["TradeSkillReagent" .. i]
        if not reagentFrame then break end

        local nameText  = _G["TradeSkillReagent" .. i .. "Name"]
        local countText = _G["TradeSkillReagent" .. i .. "Count"]

        local _, _, reagentCount, playerCount = GetTradeSkillReagentInfo(tradeIndex, i)
        if not reagentCount then
            allSatisfied = false
        else
            local baseId = GetReagentItemId(tradeIndex, i)
            local fid = baseId and itemFamilyId[baseId]

            if fid and familyByQuality[fid] then
                -- Sum counts of all quality-family variants
                local totalCount = 0
                for _, vid in pairs(familyByQuality[fid]) do
                    totalCount = totalCount + (GetItemCount(vid) or 0)
                end

                if totalCount >= reagentCount then
                    -- Un-gray the reagent icon and name
                    SetItemButtonTextureVertexColor(reagentFrame, 1.0, 1.0, 1.0)
                    if nameText then
                        nameText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    end
                    if countText then
                        countText:SetText(totalCount .. " /" .. reagentCount)
                    end
                else
                    allSatisfied = false
                end
            else
                -- Not a family item; rely on the Blizzard check
                if (playerCount or 0) < reagentCount then
                    allSatisfied = false
                end
            end
        end
    end

    -- Re-enable Create buttons if all reagents are satisfied (including via variants)
    if allSatisfied then
        if TradeSkillCreateButton then
            TradeSkillCreateButton:Enable()
        end
        if TradeSkillCreateAllButton then
            TradeSkillCreateAllButton:Enable()
        end
    end
end

-- -----------------------------------------------------------------------
-- UpdateQualityUI  (also called by TradeSkillFrame_Update hook)
-- -----------------------------------------------------------------------
function UpdateQualityUI()
    -- Hide all pickers initially
    for _, b in pairs(pickerButtons) do b:Hide() end
    if outputLabel then outputLabel:SetText("") end

    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local spellId = GetCurrentSpellId()
    if not spellId then return end

    local numReagents = GetTradeSkillNumReagents(tradeIndex)

    for i = 1, numReagents do
        local baseId = GetReagentItemId(tradeIndex, i)
        if baseId and itemFamilyId[baseId] then
            local fid = itemFamilyId[baseId]
            local btn = GetOrCreatePickerButton(i)
            if btn then
                -- Colour the picker button based on the selected quality
                local selId = GetSelection(spellId, i - 1)
                local selQ
                if selId and selId ~= 0 then
                    selQ = familyQuality[selId]
                else
                    for q = 5, 0, -1 do
                        local vid = familyByQuality[fid] and familyByQuality[fid][q]
                        if vid and (GetItemCount(vid) or 0) > 0 then
                            selQ = q; break
                        end
                    end
                end
                local c = selQ and (QUALITY_COLOR[selQ] or "|cffffffff") or "|cffaaaaaa"
                btn.label:SetText(c .. "\226\150\190|r")
                btn:Show()
            end
        end
    end

    -- Output preview
    if outputLabel and spellOutput[spellId] then
        local effectiveQ = GetEffectiveCraftQuality(spellId, tradeIndex)
        if effectiveQ and spellOutput[spellId][effectiveQ] then
            local outId       = spellOutput[spellId][effectiveQ]
            local name, _, iq = GetItemInfo(outId)
            if name then
                local c = QUALITY_COLOR[iq] or "|cffffffff"
                outputLabel:SetText("Will craft: " .. c .. name .. "|r")
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- TryHookBlizzardUI
-- Hooks TradeSkillFrame_Update and TradeSkillFrame_SetSelection once
-- Blizzard_TradeSkillUI has loaded.  Safe to call multiple times.
-- -----------------------------------------------------------------------
local function TryHookBlizzardUI()
    if hooked then return end
    if not TradeSkillFrame_Update then return end

    hooksecurefunc("TradeSkillFrame_Update", UpdateQualityUI)
    hooksecurefunc("TradeSkillFrame_SetSelection", function()
        UpdateQualityUI()
        FixReagentCounts()
    end)
    hooked = true
end

-- -----------------------------------------------------------------------
-- Frame helpers
-- -----------------------------------------------------------------------
local function EnsureOutputLabel()
    if outputLabel then return end
    if not TradeSkillFrame then return end
    outputLabel = TradeSkillFrame:CreateFontString("QCOutputLabel", "OVERLAY", "GameFontNormalSmall")
    outputLabel:SetPoint("BOTTOMLEFT", TradeSkillFrame, "BOTTOMLEFT", 8, 8)
    outputLabel:SetWidth(320)
    outputLabel:SetJustifyH("LEFT")
    outputLabel:SetText("")
end

local function EnsureDropdown()
    if dropdownFrame then return end
    dropdownFrame = CreateFrame("Frame", "QCDropdownFrame", UIParent, "UIDropDownMenuTemplate")
end

-- -----------------------------------------------------------------------
-- OnEvent dispatcher
-- -----------------------------------------------------------------------
mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local pfx, msg = ...
        if pfx ~= ADDON_PREFIX then return end
        local t    = msg:sub(1, 1)
        local data = msg:sub(3)
        if t == "F" then
            ParseFamilyMessage(data)
        elseif t == "O" then
            ParseOutputMessage(data)
        end

    elseif event == "ADDON_LOADED" then
        local name = ...
        if name == "QualityCraft" then
            -- Initialise saved variables and shared frames
            if not QualityCraftDB then QualityCraftDB = {} end
            if not QualityCraftDB.selections then QualityCraftDB.selections = {} end
            EnsureDropdown()
            -- Attempt hook now in case Blizzard_TradeSkillUI was somehow loaded first
            TryHookBlizzardUI()
        elseif name == "Blizzard_TradeSkillUI" then
            -- Blizzard_TradeSkillUI is LoadOnDemand; it fires this event the
            -- first time the player opens a trade skill window.  Hook here.
            TryHookBlizzardUI()
        end

    elseif event == "TRADE_SKILL_SHOW" then
        EnsureOutputLabel()
        EnsureDropdown()
        UpdateQualityUI()
        FixReagentCounts()

    elseif event == "TRADE_SKILL_UPDATE" then
        UpdateQualityUI()
        FixReagentCounts()

    elseif event == "TRADE_SKILL_CLOSE" then
        for _, b in pairs(pickerButtons) do b:Hide() end
        if outputLabel then outputLabel:SetText("") end
    end
end)
