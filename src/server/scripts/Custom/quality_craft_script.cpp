/*
 * QualityCraft PlayerScript
 *
 * Handles addon messages from the QualityCraft client addon.
 * Stores per-player reagent quality preferences so that Spell::TakeReagents
 * can honour the quality tier the player selected in the TradeSkill window.
 *
 * Message protocol (prefix "QCRAFT", sent as a self-whisper with LANG_ADDON):
 *
 *   SEL|<spellId>|<slot0ItemId>,<slot1ItemId>,...,<slot7ItemId>
 *     - Stores quality preferences for a specific spell.
 *
 *   CLR|<spellId>
 *     - Clears all stored preferences for a specific spell.
 *
 *   SYNC
 *     - Server responds with F| (family) and O| (output) messages so
 *       the client can populate its quality-tier data tables.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SharedDefines.h"
#include "Spell.h"
#include "SpellMgr.h"
#include "Util.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "ObjectMgr.h"
#include "ItemTemplate.h"
#include "WorldSession.h"
#include "World.h"
#include <unordered_set>

namespace
{
constexpr std::string_view QCRAFT_PREFIX = "QCRAFT";
constexpr std::string_view SEL_CMD       = "SEL";
constexpr std::string_view CLR_CMD       = "CLR";
constexpr std::string_view SYNC_CMD      = "SYNC";
constexpr std::string_view CRAFT_CMD     = "CRAFT";

static Optional<uint32> StringToUInt32(std::string_view str)
{
    if (str.empty())
        return std::nullopt;

    uint32 value = 0;
    auto result = std::from_chars(str.data(), str.data() + str.size(), value);

    if (result.ec == std::errc() && result.ptr == str.data() + str.size())
        return value;

    return std::nullopt;
}

// Send a QCRAFT addon message from server to client.
// The client sees this as a CHAT_MSG_ADDON event with prefix "QCRAFT".
static void SendAddonWhisper(Player* player, std::string const& payload)
{
    // Addon messages are whispers with LANG_ADDON; body = "PREFIX\tPAYLOAD"
    std::string fullMsg = std::string(QCRAFT_PREFIX) + "\t" + payload;

    WorldPacket data;
    ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON,
                                 player->GetGUID(), player->GetGUID(), fullMsg, 0);
    player->SendDirectMessage(&data);
}

} // anonymous namespace

class QualityCraftScript : public PlayerScript
{
public:
    QualityCraftScript() : PlayerScript("QualityCraftScript") { }

    void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Player* receiver) override
    {
        if (lang != LANG_ADDON)
            return;
        if (receiver != player)
            return;
        if (type != CHAT_MSG_WHISPER)
            return;

        auto tabPos = msg.find('\t');
        if (tabPos == std::string::npos)
            return;

        std::string_view prefix(msg.data(), tabPos);
        if (prefix != QCRAFT_PREFIX)
            return;

        std::string_view payload(msg.data() + tabPos + 1, msg.size() - tabPos - 1);

        // SYNC has no pipe ? handle it before splitting on '|'
        if (payload == SYNC_CMD)
        {
            HandleSync(player);
            return;
        }

        auto pipePos = payload.find('|');
        if (pipePos == std::string::npos)
            return;

        std::string_view cmd  = payload.substr(0, pipePos);
        std::string_view rest = payload.substr(pipePos + 1);

        if (cmd == SEL_CMD)
            HandleSel(player->GetGUID().GetRawValue(), rest);
        else if (cmd == CLR_CMD)
            HandleClr(player->GetGUID().GetRawValue(), rest);
        else if (cmd == CRAFT_CMD)
            HandleCraft(player, rest);
    }

    void OnLogout(Player* player) override
    {
        sSpellMgr->ClearCraftPreferences(player->GetGUID().GetRawValue(), SpellMgr::CLEAR_ALL_CRAFT_SPELLS);
    }

private:
    // ---- SEL / CLR (unchanged) ----
    static void HandleSel(uint64 playerGuid, std::string_view payload)
    {
        // payload = "<spellId>|<quality>|<slot0>,<slot1>,..."
        auto pipe1 = payload.find('|');
        if (pipe1 == std::string::npos) return;

        auto pipe2 = payload.find('|', pipe1 + 1);
        if (pipe2 == std::string::npos) return;

        Optional<uint32> spellId = StringToUInt32(payload.substr(0, pipe1));
        Optional<uint32> quality = StringToUInt32(payload.substr(pipe1 + 1, pipe2 - pipe1 - 1));
        if (!spellId || !quality) return;

        sSpellMgr->SetCraftQuality(playerGuid, *spellId, static_cast<uint8>(*quality));

        std::string_view slotsPart = payload.substr(pipe2 + 1);
        uint8 slot = 0;
        for (std::string_view token : Trinity::Tokenize(slotsPart, ',', false))
        {
            if (slot >= MAX_SPELL_REAGENTS) break;
            if (Optional<uint32> itemId = StringToUInt32(token))
                sSpellMgr->SetCraftPreference(playerGuid, *spellId, slot, *itemId);
            ++slot;
        }
    }

    static void HandleClr(uint64 playerGuid, std::string_view payload)
    {
        if (Optional<uint32> spellId = StringToUInt32(payload))
            sSpellMgr->ClearCraftPreferences(playerGuid, *spellId);
    }

    // ---- CRAFT: server-initiated casting ----
    static void HandleCraft(Player* player, std::string_view payload)
    {
        // payload = "<spellId>|<count>" (count is always 1, sent by client)
        auto pipePos = payload.find('|');
        if (pipePos == std::string::npos)
            return;

        Optional<uint32> spellId = StringToUInt32(payload.substr(0, pipePos));
        if (!spellId)
            return;

        // Block if already casting
        if (player->IsNonMeleeSpellCast(false))
            return;

        // Player must actually know the spell
        if (!player->HasSpell(*spellId))
            return;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(*spellId);
        if (!spellInfo)
            return;

        // Must be a tradeskill spell
        if (!spellInfo->HasAttribute(SPELL_ATTR0_TRADESPELL))
            return;

        // Verify reagent availability (including quality variants and count overrides)
        uint8 selectedQuality = sSpellMgr->GetCraftQuality(
            player->GetGUID().GetRawValue(), *spellId);

        for (uint32 i = 0; i < MAX_SPELL_REAGENTS; ++i)
        {
            if (spellInfo->Reagent[i] <= 0)
                continue;

            uint32 itemId = spellInfo->Reagent[i];
            uint32 itemCount = spellInfo->ReagentCount[i];

            // Apply quality-specific reagent count override
            if (selectedQuality > 0)
            {
                uint32 overrideCount = sSpellMgr->GetSpellQualityReagentCount(*spellId, selectedQuality, static_cast<uint8>(i));
                if (overrideCount > 0)
                    itemCount = overrideCount;
            }

            if (!player->HasItemCount(itemId, itemCount))
            {
                uint32 variantId = Spell::FindAvailableReagentVariant(player, itemId, itemCount);
                if (!player->HasItemCount(variantId, itemCount))
                    return;
            }
        }

        player->CastSpell(player, *spellId, false);
    }

    // ---- SYNC: send family + output tables to the client ----
        // ---- SYNC: send family + output tables to the client ----
    static constexpr size_t ADDON_MSG_MAX = 250; // safe margin under 255

    // Push item data to the client so GetItemInfo() works immediately
    static void PushItemDataToClient(Player* player, uint32 itemId)
    {
        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
            return;

        if (sWorld->getBoolConfig(CONFIG_CACHE_DATA_QUERIES))
            player->SendDirectMessage(&itemTemplate->QueryData[static_cast<uint32>(player->GetSession()->GetSessionDbLocaleIndex())]);
        else
        {
            WorldPacket response = itemTemplate->BuildQueryData(player->GetSession()->GetSessionDbLocaleIndex());
            player->SendDirectMessage(&response);
        }
    }

    static void HandleSync(Player* player)
    {
        // Pre-push item data for every quality item so the client's
        // GetItemInfo() returns valid data immediately when the addon
        // processes the F| and O| messages that follow.
        std::unordered_set<uint32> pushedItems;

        for (auto const& [familyId, qualityMap] : sSpellMgr->GetItemQualityFamilyByQuality())
            for (auto const& [quality, itemId] : qualityMap)
                if (pushedItems.insert(itemId).second)
                    PushItemDataToClient(player, itemId);

        for (auto const& [spellId, qualityMap] : sSpellMgr->GetSpellQualityOutputMap())
            for (auto const& [quality, itemId] : qualityMap)
                if (pushedItems.insert(itemId).second)
                    PushItemDataToClient(player, itemId);

        // Send one "F|<familyId>|<q>:<itemId>,..." message per family
        for (auto const& [familyId, qualityMap] : sSpellMgr->GetItemQualityFamilyByQuality())
        {
            std::string payload = "F|" + std::to_string(familyId) + "|";
            bool first = true;
            for (auto const& [quality, itemId] : qualityMap)
            {
                if (!first) payload += ',';
                payload += std::to_string(quality) + ':' + std::to_string(itemId);
                first = false;
            }
            SendAddonWhisper(player, payload);
        }

        // Send spell quality outputs as "O|<spellId>:<q>:<itemId>;..."
        std::string outputPayload = "O|";
        bool first = true;
        for (auto const& [spellId, qualityMap] : sSpellMgr->GetSpellQualityOutputMap())
        {
            for (auto const& [quality, itemId] : qualityMap)
            {
                std::string entry = std::to_string(spellId) + ':' +
                    std::to_string(quality) + ':' +
                    std::to_string(itemId);

                if (!first && outputPayload.size() + 1 + entry.size() > ADDON_MSG_MAX)
                {
                    SendAddonWhisper(player, outputPayload);
                    outputPayload = "O|";
                    first = true;
                }

                if (!first) outputPayload += ';';
                outputPayload += entry;
                first = false;
            }
        }

        if (!first)
            SendAddonWhisper(player, outputPayload);

        // Send spell quality reagent count overrides as "R|<spellId>:<q>:<slot>:<count>;..."
        std::string reagentCountPayload = "R|";
        first = true;
        for (auto const& [spellId, qualityMap] : sSpellMgr->GetSpellQualityReagentCountMap())
        {
            for (auto const& [quality, slotMap] : qualityMap)
            {
                for (auto const& [slot, count] : slotMap)
                {
                    std::string entry = std::to_string(spellId) + ':' +
                        std::to_string(quality) + ':' +
                        std::to_string(slot) + ':' +
                        std::to_string(count);

                    if (!first && reagentCountPayload.size() + 1 + entry.size() > ADDON_MSG_MAX)
                    {
                        SendAddonWhisper(player, reagentCountPayload);
                        reagentCountPayload = "R|";
                        first = true;
                    }

                    if (!first) reagentCountPayload += ';';
                    reagentCountPayload += entry;
                    first = false;
                }
            }
        }

        if (!first)
            SendAddonWhisper(player, reagentCountPayload);
    }
};

void AddQualityCraftScripts()
{
    new QualityCraftScript();
}
