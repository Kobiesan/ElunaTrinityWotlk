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
 *     - Each comma-separated value is the item ID the player wants to use for
 *       that reagent slot (0-based).  A value of 0 means "no preference".
 *
 *   CLR|<spellId>
 *     - Clears all stored preferences for a specific spell.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "SharedDefines.h"
#include "SpellMgr.h"
#include "Util.h"

namespace
{
constexpr std::string_view QCRAFT_PREFIX = "QCRAFT";
constexpr std::string_view SEL_CMD       = "SEL";
constexpr std::string_view CLR_CMD       = "CLR";
} // anonymous namespace

class QualityCraftScript : public PlayerScript
{
public:
    QualityCraftScript() : PlayerScript("QualityCraftScript") { }

    // Intercept self-whispers with LANG_ADDON that carry the QCRAFT prefix.
    void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Player* receiver) override
    {
        if (lang != LANG_ADDON)
            return;
        if (receiver != player)
            return;
        if (type != CHAT_MSG_WHISPER)
            return;

        // WoW addon messages arrive as "<prefix>\t<message>".
        auto tabPos = msg.find('\t');
        if (tabPos == std::string::npos)
            return;

        std::string_view prefix(msg.data(), tabPos);
        if (prefix != QCRAFT_PREFIX)
            return;

        std::string_view payload(msg.data() + tabPos + 1, msg.size() - tabPos - 1);

        // Split off the command token (SEL or CLR)
        auto pipePos = payload.find('|');
        if (pipePos == std::string::npos)
            return;

        std::string_view cmd  = payload.substr(0, pipePos);
        std::string_view rest = payload.substr(pipePos + 1);
        uint64 playerGuid     = player->GetGUID().GetRawValue();

        if (cmd == SEL_CMD)
            HandleSel(playerGuid, rest);
        else if (cmd == CLR_CMD)
            HandleClr(playerGuid, rest);
    }

    // Clear all stored craft preferences when the player logs out.
    void OnLogout(Player* player) override
    {
        sSpellMgr->ClearCraftPreferences(player->GetGUID().GetRawValue(), SpellMgr::CLEAR_ALL_CRAFT_SPELLS);
    }

private:
    static void HandleSel(uint64 playerGuid, std::string_view payload)
    {
        // payload = "<spellId>|<i0>,<i1>,...,<i7>"
        auto pipePos = payload.find('|');
        if (pipePos == std::string::npos)
            return;

        Optional<uint32> spellId = Trinity::StringTo<uint32>(payload.substr(0, pipePos));
        if (!spellId)
            return;

        std::string_view slotsPart = payload.substr(pipePos + 1);
        uint8 slot = 0;
        for (std::string_view token : Trinity::Tokenize(slotsPart, ',', false))
        {
            if (slot >= MAX_SPELL_REAGENTS)
                break;

            if (Optional<uint32> itemId = Trinity::StringTo<uint32>(token))
                sSpellMgr->SetCraftPreference(playerGuid, *spellId, slot, *itemId);

            ++slot;
        }
    }

    static void HandleClr(uint64 playerGuid, std::string_view payload)
    {
        if (Optional<uint32> spellId = Trinity::StringTo<uint32>(payload))
            sSpellMgr->ClearCraftPreferences(playerGuid, *spellId);
    }
};

void AddQualityCraftScripts()
{
    new QualityCraftScript();
}
