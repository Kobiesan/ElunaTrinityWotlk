-- QualityCraft.lua (WoW 3.3.5a client-side addon)
--
-- Adds a quality-tier dropdown to the crafted-item icon in the TradeSkill
-- window.  The player picks the desired output quality and all reagents
-- are automatically set to that tier.

-- Upvalue hot-path globals
local pairs, tonumber, tostring = pairs, tonumber, tostring
local floor, huge = math.floor, math.huge
local tinsert, tsort, tconcat, wipe = table.insert, table.sort, table.concat, wipe
local GetItemCount             = GetItemCount
local GetItemInfo              = GetItemInfo
local GetSpellInfo             = GetSpellInfo
local GetNumTradeSkills        = GetNumTradeSkills
local GetTradeSkillInfo        = GetTradeSkillInfo
local GetTradeSkillNumReagents = GetTradeSkillNumReagents
local GetTradeSkillReagentInfo = GetTradeSkillReagentInfo
local GetTradeSkillRecipeLink  = GetTradeSkillRecipeLink
local GetTradeSkillReagentItemLink  = GetTradeSkillReagentItemLink
local GetTradeSkillSelectionIndex   = GetTradeSkillSelectionIndex
local SendAddonMessage         = SendAddonMessage
local UnitName                 = UnitName

local ADDON_PREFIX = "QCRAFT"
local MAX_REAGENTS = 8

-- -----------------------------------------------------------------------
-- Quality display
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
-- Data tables  (server -> client)
-- -----------------------------------------------------------------------
local itemFamilyId    = {}   -- itemId -> familyId
local familyByQuality = {}   -- familyId -> { [quality] = itemId }
local spellOutput     = {}   -- spellId  -> { [quality] = outputItemId }

-- -----------------------------------------------------------------------
-- UI state
-- -----------------------------------------------------------------------
local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("CHAT_MSG_ADDON")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("TRADE_SKILL_SHOW")
mainFrame:RegisterEvent("TRADE_SKILL_UPDATE")
mainFrame:RegisterEvent("TRADE_SKILL_CLOSE")
mainFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
mainFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
mainFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

local dropdownFrame, outputPickerButton
local pendingCraftSpellId, pendingCraftCount = nil, 0
local activeReagentOverride = {}   -- [reagentSlot] = itemId
local synced = false

-- Cached frame references (populated by TryHookBlizzardUI)
local reagentFrames, reagentNames, reagentCounts = {}, {}, {}
local skillBtns, skillTexts, skillCounts, skillHighlights = {}, {}, {}, {}

-- Forward declaration
local UpdateQualityUI

-- -----------------------------------------------------------------------
-- Item cache  (force the client to fetch item data from the server)
-- -----------------------------------------------------------------------
local cacheTooltip = CreateFrame("GameTooltip", "QCCacheTooltip",
                                 nil, "GameTooltipTemplate")
cacheTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function PreCacheItem(id)
    if id and id > 0 then cacheTooltip:SetHyperlink("item:" .. id) end
end

-- -----------------------------------------------------------------------
-- SavedVariables   QualityCraftDB.selections[spellId] = quality (0-5)
-- -----------------------------------------------------------------------
local function GetSelectedQuality(spellId)
    local sel = QualityCraftDB and QualityCraftDB.selections
    return sel and sel[spellId]
end

local function SaveSelectedQuality(spellId, quality)
    QualityCraftDB = QualityCraftDB or {}
    QualityCraftDB.selections = QualityCraftDB.selections or {}
    QualityCraftDB.selections[spellId] = quality
end

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------
local function GetCurrentSpellId()
    local idx = GetTradeSkillSelectionIndex()
    if not idx or idx == 0 then return nil end
    local link = GetTradeSkillRecipeLink(idx)
    return link and tonumber(link:match("|Henchant:(%d+)|h"))
end

local function GetReagentItemId(skillIndex, reagentIndex)
    local link = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
    return link and tonumber(link:match("|Hitem:(%d+):"))
end

local function GetReagentAtQuality(baseId, quality)
    if not baseId or not quality then return baseId end
    local fid = itemFamilyId[baseId]
    if not fid then return baseId end
    local fam = familyByQuality[fid]
    return (fam and fam[quality]) or baseId
end

local function CalcAvailableAtQuality(tradeIndex, quality)
    local numReagents  = GetTradeSkillNumReagents(tradeIndex)
    local maxCraftable = huge

    for i = 1, numReagents do
        local baseId = GetReagentItemId(tradeIndex, i)
        local _, _, reagentCount, playerReagentCount =
            GetTradeSkillReagentInfo(tradeIndex, i)
        reagentCount = reagentCount or 1

        local playerCount
        if baseId and itemFamilyId[baseId] then
            playerCount = GetItemCount(GetReagentAtQuality(baseId, quality)) or 0
        else
            playerCount = playerReagentCount or 0
        end

        local canMake = floor(playerCount / reagentCount)
        if canMake < maxCraftable then maxCraftable = canMake end
    end

    return maxCraftable == huge and 0 or maxCraftable
end

local function CalcTotalAvailableAllQualities(spellId, tradeIndex)
    local outputs = spellOutput[spellId]
    if not outputs then return nil end

    local numReagents = GetTradeSkillNumReagents(tradeIndex)

    -- Snapshot remaining item counts for all relevant items
    local remaining = {}
    for i = 1, numReagents do
        local baseId = GetReagentItemId(tradeIndex, i)
        if baseId and itemFamilyId[baseId] then
            local fam = familyByQuality[itemFamilyId[baseId]]
            if fam then
                for _, itemId in pairs(fam) do
                    if not remaining[itemId] then
                        remaining[itemId] = GetItemCount(itemId) or 0
                    end
                end
            end
        elseif baseId and not remaining[baseId] then
            remaining[baseId] = GetItemCount(baseId) or 0
        end
    end

    -- Process each quality tier, deducting consumed reagents
    local qualities = {}
    for q in pairs(outputs) do tinsert(qualities, q) end
    tsort(qualities)

    local total = 0
    for _, q in ipairs(qualities) do
        local canMake = huge

        for i = 1, numReagents do
            local baseId = GetReagentItemId(tradeIndex, i)
            local _, _, reagentCount = GetTradeSkillReagentInfo(tradeIndex, i)
            reagentCount = reagentCount or 1

            local useId = GetReagentAtQuality(baseId, q)
            local avail = remaining[useId] or (GetItemCount(useId) or 0)
            local possible = floor(avail / reagentCount)
            if possible < canMake then canMake = possible end
        end

        if canMake > 0 and canMake ~= huge then
            total = total + canMake
            -- Deduct what this tier consumes from the shared pool
            for i = 1, numReagents do
                local baseId = GetReagentItemId(tradeIndex, i)
                local _, _, reagentCount = GetTradeSkillReagentInfo(tradeIndex, i)
                reagentCount = reagentCount or 1
                local useId = GetReagentAtQuality(baseId, q)
                remaining[useId] = (remaining[useId] or 0) - (canMake * reagentCount)
            end
        end
    end

    return total
end

local function GetEffectiveCraftQuality(spellId)
    local outputs = spellOutput[spellId]
    if not outputs then return nil end
    local q = GetSelectedQuality(spellId)
    return (q and outputs[q]) and q or nil
end

-- -----------------------------------------------------------------------
-- Server communication
-- -----------------------------------------------------------------------
local function SendSelectionToServer(spellId)
    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local selQ = GetSelectedQuality(spellId)
    local numReagents = GetTradeSkillNumReagents(tradeIndex)
    local parts = {}

    for i = 0, MAX_REAGENTS - 1 do
        local vid = 0
        if i < numReagents and selQ then
            local baseId = GetReagentItemId(tradeIndex, i + 1)
            if baseId and itemFamilyId[baseId] then
                local fam = familyByQuality[itemFamilyId[baseId]]
                vid = (fam and fam[selQ]) or 0
            end
        end
        parts[i + 1] = tostring(vid)
    end

    SendAddonMessage(ADDON_PREFIX,
        "SEL|" .. spellId .. "|" .. selQ .. "|" .. tconcat(parts, ","),
        "WHISPER", UnitName("player"))
end

local function RequestSyncFromServer()
    SendAddonMessage(ADDON_PREFIX, "SYNC", "WHISPER", UnitName("player"))
end

-- -----------------------------------------------------------------------
-- Message parsing  (server -> client)
-- -----------------------------------------------------------------------
local function ParseFamilyMessage(data)
    local familyId, entryList = data:match("^(%d+)|(.+)$")
    familyId = tonumber(familyId)
    if not familyId then return end

    familyByQuality[familyId] = familyByQuality[familyId] or {}
    for entry in entryList:gmatch("[^,]+") do
        local q, id = entry:match("^(%d+):(%d+)$")
        q, id = tonumber(q), tonumber(id)
        if q and id then
            itemFamilyId[id] = familyId
            familyByQuality[familyId][q] = id
            PreCacheItem(id)
        end
    end
end

local function ParseOutputMessage(data)
    for entry in data:gmatch("[^;]+") do
        local sid, q, id = entry:match("^(%d+):(%d+):(%d+)$")
        sid, q, id = tonumber(sid), tonumber(q), tonumber(id)
        if sid and q and id then
            spellOutput[sid]    = spellOutput[sid] or {}
            spellOutput[sid][q] = id
            PreCacheItem(id)
        end
    end
end

-- -----------------------------------------------------------------------
-- Output dropdown initialisation
-- -----------------------------------------------------------------------
local function DropdownInit(self, level)
    local spellId = GetCurrentSpellId()
    if not spellId or not spellOutput[spellId] then return end

    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local currentQuality = GetSelectedQuality(spellId)

    -- One entry per quality tier
    local qualities = {}
    for q in pairs(spellOutput[spellId]) do tinsert(qualities, q) end
    tsort(qualities)

    for _, q in ipairs(qualities) do
        local outId     = spellOutput[spellId][q]
        local name      = GetItemInfo(outId)
        local available = CalcAvailableAtQuality(tradeIndex, q)
        local color     = QUALITY_COLOR[q] or "|cffffffff"
        local qname     = QUALITY_NAME[q] or tostring(q)

        local info          = UIDropDownMenu_CreateInfo()
        info.notCheckable   = false
        info.checked        = (currentQuality == q)

        if available > 0 then
            info.text = color .. qname .. "|r  " .. (name or "?")
                        .. "  |cffaaaaaa[" .. available .. "]|r"
        else
            info.text = "|cff666666" .. qname .. "  "
                        .. (name or "?") .. "  [0]|r"
        end

        local capturedQ = q
        info.func = function()
            local prevQ = GetSelectedQuality(spellId)
            SaveSelectedQuality(spellId, capturedQ)
            SendSelectionToServer(spellId)
            if capturedQ ~= prevQ then
                pendingCraftCount   = 0
                pendingCraftSpellId = nil
                if TradeSkillInputBox then TradeSkillInputBox:SetNumber(1) end
            end
            UpdateQualityUI()
        end

        UIDropDownMenu_AddButton(info, level)
    end
end

-- -----------------------------------------------------------------------
-- Output picker button (anchored to crafted-item icon)
-- -----------------------------------------------------------------------
local function EnsureOutputPicker()
    if outputPickerButton then return outputPickerButton end
    if not TradeSkillSkillIcon then return nil end

    local btn = CreateFrame("Button", "QCOutputPickerBtn", TradeSkillSkillIcon)
    btn:SetWidth(24)
    btn:SetHeight(24)
    btn:SetPoint("TOPRIGHT", TradeSkillSkillIcon, "TOPRIGHT", 4, 4)
    btn:SetFrameLevel(TradeSkillSkillIcon:GetFrameLevel() + 5)

    btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")

    btn:SetScript("OnClick", function(self)
        local spellId = GetCurrentSpellId()
        if not spellId or not spellOutput[spellId] then return end
        UIDropDownMenu_Initialize(dropdownFrame, DropdownInit)
        ToggleDropDownMenu(1, nil, dropdownFrame, self, 0, 0)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Select craft quality")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    outputPickerButton = btn
    return btn
end

-- -----------------------------------------------------------------------
-- Recipe-list count text helper
-- -----------------------------------------------------------------------
local function SetSkillCountText(btnCount, btnText, qty, skillIndex)
    if qty > 0 then
        btnCount:SetText("[" .. qty .. "]")
        local sn = GetTradeSkillInfo(skillIndex)
        if sn then
            TradeSkillFrameDummyString:SetText(" " .. sn)
            local nw = TradeSkillFrameDummyString:GetWidth()
            local cw = btnCount:GetWidth()
            btnText:SetWidth(
                (nw + 2 + cw > TRADE_SKILL_TEXT_WIDTH)
                and (TRADE_SKILL_TEXT_WIDTH - 2 - cw) or 0)
        end
    else
        btnCount:SetText("")
        btnText:SetWidth(TRADE_SKILL_TEXT_WIDTH)
    end
end

-- -----------------------------------------------------------------------
-- UpdateQualityUI
-- -----------------------------------------------------------------------
UpdateQualityUI = function()
    if outputPickerButton then outputPickerButton:Hide() end
    for i = 1, MAX_REAGENTS do activeReagentOverride[i] = nil end

    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end

    local tradeIndex = GetTradeSkillSelectionIndex()
    if not tradeIndex or tradeIndex == 0 then return end

    local spellId = GetCurrentSpellId()
    if not spellId then return end

    local effectiveQ = GetEffectiveCraftQuality(spellId)

    -- Show picker for quality recipes
    if spellOutput[spellId] then
        local btn = EnsureOutputPicker()
        if btn then btn:Show() end
    end

    -- Update reagent displays
    local numReagents  = GetTradeSkillNumReagents(tradeIndex)
    local allSatisfied = true

    for i = 1, numReagents do
        local baseId = GetReagentItemId(tradeIndex, i)
        local _, _, reagentCount, playerReagentCount =
            GetTradeSkillReagentInfo(tradeIndex, i)
        reagentCount = reagentCount or 1

        if baseId and itemFamilyId[baseId] and effectiveQ then
            local useId = GetReagentAtQuality(baseId, effectiveQ)

            if useId ~= baseId then
                activeReagentOverride[i] = useId
            end

            local playerCount = GetItemCount(useId) or 0
            local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(useId)
            local reagent    = reagentFrames[i]
            local nameLabel  = reagentNames[i]
            local countLabel = reagentCounts[i]

            if reagent and nameLabel and countLabel and itemName then
                SetItemButtonTexture(reagent, itemTexture)
                nameLabel:SetText(itemName)
                countLabel:SetText(
                    (playerCount >= 100 and "*" or playerCount)
                    .. " /" .. reagentCount)

                if playerCount >= reagentCount then
                    SetItemButtonTextureVertexColor(reagent, 1.0, 1.0, 1.0)
                    nameLabel:SetTextColor(
                        HIGHLIGHT_FONT_COLOR.r,
                        HIGHLIGHT_FONT_COLOR.g,
                        HIGHLIGHT_FONT_COLOR.b)
                else
                    SetItemButtonTextureVertexColor(reagent, 0.5, 0.5, 0.5)
                    nameLabel:SetTextColor(
                        GRAY_FONT_COLOR.r,
                        GRAY_FONT_COLOR.g,
                        GRAY_FONT_COLOR.b)
                    allSatisfied = false
                end
            else
                if playerCount < reagentCount then allSatisfied = false end
            end
        else
            if (playerReagentCount or 0) < reagentCount then
                allSatisfied = false
            end
        end
    end

    -- Enable/disable Create buttons
    if allSatisfied then
        TradeSkillCreateButton:Enable()
        TradeSkillCreateAllButton:Enable()
    else
        TradeSkillCreateButton:Disable()
        TradeSkillCreateAllButton:Disable()
    end

    -- Override crafted-item icon / name
    if effectiveQ then
        local outId = spellOutput[spellId][effectiveQ]
        local outName, _, _, _, _, _, _, _, _, texture = GetItemInfo(outId)
        if texture then TradeSkillSkillIcon:SetNormalTexture(texture) end
        if outName then TradeSkillSkillName:SetText(outName) end
    end

    -- Override [count] for visible quality recipes
    for j = 1, TRADE_SKILLS_DISPLAYED do
        local skillButton = skillBtns[j]
        if skillButton and skillButton:IsShown() then
            local skillIndex = skillButton:GetID()
            local _, skillType = GetTradeSkillInfo(skillIndex)
            if skillType and skillType ~= "header" then
                local link = GetTradeSkillRecipeLink(skillIndex)
                local sid  = link and tonumber(link:match("|Henchant:(%d+)|h"))
                if sid and spellOutput[sid] then
                    local totalQty = CalcTotalAvailableAllQualities(sid, skillIndex) or 0

                    if tradeIndex == skillIndex then
                        local eq = GetEffectiveCraftQuality(sid)
                        TradeSkillFrame.numAvailable =
                            eq and CalcAvailableAtQuality(skillIndex, eq) or 0
                    end

                    local btnCount = skillCounts[j]
                    local btnText  = skillTexts[j]
                    if btnCount and btnText then
                        SetSkillCountText(btnCount, btnText, totalQty, skillIndex)
                    end
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- Frame helpers
-- -----------------------------------------------------------------------
local function EnsureDropdown()
    if dropdownFrame then return end
    dropdownFrame = CreateFrame("Frame", "QCDropdownFrame", UIParent,
                               "UIDropDownMenuTemplate")
end

-- -----------------------------------------------------------------------
-- Quality-aware "Have Materials" filter
-- -----------------------------------------------------------------------
local qcFilterMakeable = false
local qcFilteredSkills = {}

local function CanCraftWithVariants(skillIndex)
    local _, skillType, numAvailable = GetTradeSkillInfo(skillIndex)
    if skillType == "header" then return true end
    if numAvailable > 0 then return true end

    local link = GetTradeSkillRecipeLink(skillIndex)
    local sid  = link and tonumber(link:match("|Henchant:(%d+)|h"))

    if not sid or not spellOutput[sid] then
        -- Non-quality recipe: standard reagent check
        local numReagents = GetTradeSkillNumReagents(skillIndex)
        for i = 1, numReagents do
            local _, _, reagentCount, playerCount =
                GetTradeSkillReagentInfo(skillIndex, i)
            if (playerCount or 0) < (reagentCount or 1) then return false end
        end
        return true
    end

    -- Quality recipe: craftable at any quality tier?
    for q in pairs(spellOutput[sid]) do
        if CalcAvailableAtQuality(skillIndex, q) > 0 then
            return true
        end
    end
    return false
end

local function BuildFilteredList()
    wipe(qcFilteredSkills)
    if not qcFilterMakeable then return end
    local total = GetNumTradeSkills()
    local lastHeader, headerHasChild = nil, false
    local craftable = {}
    for i = 1, total do
        local _, skillType = GetTradeSkillInfo(i)
        if skillType == "header" then
            if lastHeader and headerHasChild then
                craftable[lastHeader] = true
            end
            lastHeader     = i
            headerHasChild = false
        else
            if CanCraftWithVariants(i) then
                craftable[i]   = true
                headerHasChild = true
            end
        end
    end
    if lastHeader and headerHasChild then craftable[lastHeader] = true end
    for i = 1, total do
        if craftable[i] then tinsert(qcFilteredSkills, i) end
    end
end

-- -----------------------------------------------------------------------
-- TryHookBlizzardUI
-- -----------------------------------------------------------------------
local hooked = false
local function TryHookBlizzardUI()
    if hooked then return end
    if not TradeSkillFrame_SetSelection then return end
    if not TradeSkillFrame_Update       then return end

    -- Cache frame references once
    for i = 1, MAX_REAGENTS do
        reagentFrames[i] = _G["TradeSkillReagent" .. i]
        reagentNames[i]  = _G["TradeSkillReagent" .. i .. "Name"]
        reagentCounts[i] = _G["TradeSkillReagent" .. i .. "Count"]
    end
    for i = 1, TRADE_SKILLS_DISPLAYED do
        skillBtns[i]        = _G["TradeSkillSkill" .. i]
        skillTexts[i]       = _G["TradeSkillSkill" .. i .. "Text"]
        skillCounts[i]      = _G["TradeSkillSkill" .. i .. "Count"]
        skillHighlights[i]  = _G["TradeSkillSkill" .. i .. "Highlight"]
    end

    local origSetSelection = TradeSkillFrame_SetSelection
    TradeSkillFrame_SetSelection = function(id, ...)
        CloseDropDownMenus()
        origSetSelection(id, ...)
        if pendingCraftCount > 0 and pendingCraftSpellId and TradeSkillInputBox then
            TradeSkillInputBox:SetNumber(pendingCraftCount)
        end
        UpdateQualityUI()
    end

    local origUpdate = TradeSkillFrame_Update
    TradeSkillFrame_Update = function(...)
        BuildFilteredList()

        if not qcFilterMakeable then
            origUpdate(...)
            UpdateQualityUI()
            return
        end

        origUpdate(...)

        local numFiltered = #qcFilteredSkills
        FauxScrollFrame_Update(TradeSkillListScrollFrame, numFiltered,
            TRADE_SKILLS_DISPLAYED, TRADE_SKILL_HEIGHT, nil, nil, nil,
            TradeSkillHighlightFrame, 293, 316)

        local skillOffset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
        TradeSkillHighlightFrame:Hide()

        for i = 1, TRADE_SKILLS_DISPLAYED do
            local filteredIdx      = i + skillOffset
            local skillButton      = skillBtns[i]
            local skillButtonText  = skillTexts[i]
            local skillButtonCount = skillCounts[i]

            if filteredIdx <= numFiltered then
                local skillIndex = qcFilteredSkills[filteredIdx]
                local skillName, skillType, numAvailable, isExpanded =
                    GetTradeSkillInfo(skillIndex)

                if TradeSkillListScrollFrame:IsShown() then
                    skillButton:SetWidth(293)
                else
                    skillButton:SetWidth(323)
                end

                local color = TradeSkillTypeColor[skillType]
                if color then
                    skillButton:SetNormalFontObject(color.font)
                    skillButtonCount:SetVertexColor(color.r, color.g, color.b)
                    skillButton.r = color.r
                    skillButton.g = color.g
                    skillButton.b = color.b
                end

                skillButton:SetID(skillIndex)
                skillButton:Show()

                if skillType == "header" then
                    skillButton:SetText(skillName)
                    skillButtonText:SetWidth(TRADE_SKILL_TEXT_WIDTH)
                    skillButtonCount:SetText("")
                    if isExpanded then
                        skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                    else
                        skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                    end
                    skillHighlights[i]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                    skillButton:UnlockHighlight()
                else
                    skillButton:SetNormalTexture("")
                    skillHighlights[i]:SetTexture("")
                    if numAvailable <= 0 then
                        skillButton:SetText(" "..skillName)
                        skillButtonText:SetWidth(TRADE_SKILL_TEXT_WIDTH)
                        skillButtonCount:SetText("")
                    else
                        local sName = " "..skillName
                        skillButtonCount:SetText("["..numAvailable.."]")
                        TradeSkillFrameDummyString:SetText(sName)
                        local nw = TradeSkillFrameDummyString:GetWidth()
                        local cw = skillButtonCount:GetWidth()
                        skillButtonText:SetText(sName)
                        if nw + 2 + cw > TRADE_SKILL_TEXT_WIDTH then
                            skillButtonText:SetWidth(
                                TRADE_SKILL_TEXT_WIDTH - 2 - cw)
                        else
                            skillButtonText:SetWidth(0)
                        end
                    end

                    if GetTradeSkillSelectionIndex() == skillIndex then
                        TradeSkillHighlightFrame:SetPoint("TOPLEFT", skillBtns[i], "TOPLEFT", 0, 0)
                        TradeSkillHighlightFrame:Show()
                        skillButtonCount:SetVertexColor(
                            HIGHLIGHT_FONT_COLOR.r,
                            HIGHLIGHT_FONT_COLOR.g,
                            HIGHLIGHT_FONT_COLOR.b)
                        skillButton:LockHighlight()
                        skillButton.isHighlighted = true
                    else
                        skillButton:UnlockHighlight()
                        skillButton.isHighlighted = false
                    end
                end
            else
                skillButton:Hide()
            end
        end

        UpdateQualityUI()
    end

    -- Reagent tooltips + shift-click
    for i = 1, MAX_REAGENTS do
        local reagent = reagentFrames[i]
        if reagent then
            reagent:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                local oid = activeReagentOverride[i]
                if oid then
                    GameTooltip:SetHyperlink("item:" .. oid)
                else
                    GameTooltip:SetTradeSkillItem(
                        TradeSkillFrame.selectedSkill, self:GetID())
                end
                GameTooltip:Show()
            end)

            reagent:SetScript("OnClick", function(self)
                if not IsModifiedClick("CHATLINK") then return end
                local oid = activeReagentOverride[i]
                if oid then
                    local _, link = GetItemInfo(oid)
                    if link then HandleModifiedItemClick(link); return end
                end
                HandleModifiedItemClick(GetTradeSkillReagentItemLink(
                    TradeSkillFrame.selectedSkill, self:GetID()))
            end)
        end
    end

    -- Crafted-item icon tooltip
    local origItemOnEnter = TradeSkillItem_OnEnter
    TradeSkillItem_OnEnter = function(self)
        if self == TradeSkillSkillIcon then
            local sid = GetCurrentSpellId()
            local ti  = GetTradeSkillSelectionIndex()
            if sid and ti and ti ~= 0 and spellOutput[sid] then
                local eq = GetEffectiveCraftQuality(sid)
                if eq and spellOutput[sid][eq] then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. spellOutput[sid][eq])
                    GameTooltip:Show()
                    CursorUpdate(self)
                    return
                end
            end
        end
        origItemOnEnter(self)
    end

    -- Crafted-item icon shift-click
    if TradeSkillSkillIcon then
        TradeSkillSkillIcon:SetScript("OnClick", function()
            if not IsModifiedClick("CHATLINK") then return end
            local sid = GetCurrentSpellId()
            local ti  = GetTradeSkillSelectionIndex()
            if sid and ti and ti ~= 0 and spellOutput[sid] then
                local eq = GetEffectiveCraftQuality(sid)
                if eq and spellOutput[sid][eq] then
                    local _, link = GetItemInfo(spellOutput[sid][eq])
                    if link then HandleModifiedItemClick(link); return end
                end
            end
            HandleModifiedItemClick(
                GetTradeSkillItemLink(TradeSkillFrame.selectedSkill))
        end)
    end

    -- Create
    TradeSkillCreateButton:SetScript("OnClick", function()
        local sid = GetCurrentSpellId()
        if not sid then return end
        local count = TradeSkillInputBox:GetNumber()
        if count < 1 then count = 1 end
        local max = TradeSkillFrame.numAvailable or count
        if max > 0 and count > max then
            count = max
            TradeSkillInputBox:SetNumber(count)
        end
        pendingCraftSpellId = sid
        pendingCraftCount   = count
        SendAddonMessage(ADDON_PREFIX, "CRAFT|" .. sid .. "|1",
                         "WHISPER", UnitName("player"))
    end)

    -- Create All
    TradeSkillCreateAllButton:SetScript("OnClick", function()
        local sid = GetCurrentSpellId()
        if not sid then return end
        local count = TradeSkillFrame.numAvailable or 1
        if count < 1 then count = 1 end
        pendingCraftSpellId = sid
        pendingCraftCount   = count
        TradeSkillInputBox:SetNumber(count)
        SendAddonMessage(ADDON_PREFIX, "CRAFT|" .. sid .. "|1",
                         "WHISPER", UnitName("player"))
    end)

    -- Have Materials filter
    local origShowMakeable = TradeSkillOnlyShowMakeable
    TradeSkillOnlyShowMakeable = function(flag)
        qcFilterMakeable = flag and true or false
        origShowMakeable(false)
        if TradeSkillFrame and TradeSkillFrame:IsShown() then
            TradeSkillFrame_Update()
        end
    end

    hooked = true
end

-- -----------------------------------------------------------------------
-- Event dispatcher
-- -----------------------------------------------------------------------
mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local pfx, msg = ...
        if pfx ~= ADDON_PREFIX then return end
        local tag  = msg:sub(1, 1)
        local data = msg:sub(3)
        if tag == "F" then
            ParseFamilyMessage(data)
        elseif tag == "O" then
            ParseOutputMessage(data)
        end
        UpdateQualityUI()

    elseif event == "ADDON_LOADED" then
        local name = ...
        if name == "QualityCraft" then
            -- Migrate old per-slot selections to new format
            if QualityCraftDB and QualityCraftDB.selections then
                for k, v in pairs(QualityCraftDB.selections) do
                    if type(v) == "table" then
                        QualityCraftDB.selections[k] = nil
                    end
                end
            else
                QualityCraftDB = { selections = {} }
            end
            EnsureDropdown()
            TryHookBlizzardUI()
        elseif name == "Blizzard_TradeSkillUI" then
            TryHookBlizzardUI()
        end

    -- In the event handler for TRADE_SKILL_SHOW:
    elseif event == "TRADE_SKILL_SHOW" then
        TryHookBlizzardUI()
        EnsureDropdown()
        if not synced then
            RequestSyncFromServer()
            synced = true
        end
        UpdateQualityUI()

    elseif event == "TRADE_SKILL_UPDATE" then
        UpdateQualityUI()

    elseif event == "TRADE_SKILL_CLOSE" then
        if outputPickerButton then outputPickerButton:Hide() end
        pendingCraftCount   = 0
        pendingCraftSpellId = nil

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName = ...
        if unit == "player" and pendingCraftCount > 0
           and pendingCraftSpellId then
            if spellName == GetSpellInfo(pendingCraftSpellId) then
                pendingCraftCount = pendingCraftCount - 1
                if TradeSkillInputBox then
                    TradeSkillInputBox:SetNumber(pendingCraftCount)
                end
                if pendingCraftCount > 0 then
                    SendAddonMessage(ADDON_PREFIX,
                        "CRAFT|" .. pendingCraftSpellId .. "|1",
                        "WHISPER", UnitName("player"))
                else
                    pendingCraftSpellId = nil
                end
            end
        end

    elseif event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" and pendingCraftSpellId then
            pendingCraftCount   = 0
            pendingCraftSpellId = nil
        end
    end
end)
