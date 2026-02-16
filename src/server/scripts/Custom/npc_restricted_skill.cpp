#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "WorldSession.h"
#include "ScriptedGossip.h"
#include "ScriptedCreature.h"
#include "DatabaseEnv.h"
#include "Log.h"

struct SkillRequirement
{
    uint32 skillId;
    uint32 skillLevel;
    std::string errorMessage;
};

struct PairHash
{
    std::size_t operator()(std::pair<uint32, uint32> const& p) const noexcept
    {
        return std::hash<uint64>()(static_cast<uint64>(p.first) << 32 | p.second);
    }
};

// Key: { creature entry, npc_flag }
static std::unordered_map<std::pair<uint32, uint32>, SkillRequirement, PairHash> skillRequirements;

static SkillRequirement const* FindRequirement(uint32 entry, uint32 npcFlag)
{
    // First try the specific flag
    auto itr = skillRequirements.find({ entry, npcFlag });
    if (itr != skillRequirements.end())
        return &itr->second;

    // Fall back to the catch-all (npc_flag = 0) if no specific entry exists
    if (npcFlag != 0)
    {
        itr = skillRequirements.find({ entry, 0 });
        if (itr != skillRequirements.end())
            return &itr->second;
    }

    return nullptr;
}

// Returns the lowest skill requirement among all flags this creature has.
// If the player meets this, they qualify for at least one service.
static SkillRequirement const* FindLowestRequirement(Creature* creature)
{
    static constexpr uint32 checkedFlags[] =
    {
        UNIT_NPC_FLAG_GOSSIP,
        UNIT_NPC_FLAG_QUESTGIVER,
        UNIT_NPC_FLAG_TRAINER,
        UNIT_NPC_FLAG_VENDOR,
        UNIT_NPC_FLAG_REPAIR,
        UNIT_NPC_FLAG_INNKEEPER,
        UNIT_NPC_FLAG_BANKER,
        UNIT_NPC_FLAG_PETITIONER,
        UNIT_NPC_FLAG_TABARDDESIGNER,
        UNIT_NPC_FLAG_FLIGHTMASTER,
        UNIT_NPC_FLAG_BATTLEMASTER,
        UNIT_NPC_FLAG_SPIRITHEALER,
        UNIT_NPC_FLAG_AUCTIONEER,
        UNIT_NPC_FLAG_STABLEMASTER,
        UNIT_NPC_FLAG_GUILD_BANKER,
        UNIT_NPC_FLAG_MAILBOX
    };

    bool isTaxi = creature->IsTaxi();
    uint32 entry = creature->GetEntry();
    SkillRequirement const* lowest = nullptr;

    for (uint32 flag : checkedFlags)
    {
        if (!creature->HasNpcFlag(static_cast<NPCFlags>(flag)))
            continue;

        // Flight Masters: the menu must always open so players can fly.
        // Skip all flags except those that don't belong to the flight
        // master's core functionality. Individual services like quest
        // giver are still gated in OnGossipSelect.
        if (isTaxi && (flag == UNIT_NPC_FLAG_FLIGHTMASTER ||
            flag == UNIT_NPC_FLAG_GOSSIP ||
            flag == UNIT_NPC_FLAG_QUESTGIVER))
            continue;

        SkillRequirement const* req = FindRequirement(entry, flag);
        if (req && (!lowest || req->skillLevel < lowest->skillLevel))
            lowest = req;
    }

    return lowest;
}

static bool MeetsRequirement(Player* player, SkillRequirement const* req)
{
    if (!req)
        return true;

    return player->HasSkill(req->skillId) &&
        player->GetSkillValue(req->skillId) >= req->skillLevel;
}

// Public function so other scripts can check skill requirements
bool CheckNpcSkillRequirement(Player* player, Creature* creature, uint32 npcFlag)
{
    if (!player || !creature)
        return true;

    SkillRequirement const* req = FindRequirement(creature->GetEntry(), npcFlag);
    if (!req)
        return true;

    if (!MeetsRequirement(player, req))
    {
        player->GetSession()->SendNotification("%s", req->errorMessage.c_str());
        CloseGossipMenuFor(player);
        return false;
    }

    return true;
}

// Maps a Gossip_Option type to the corresponding UNIT_NPC_FLAG
static uint32 GossipOptionToNpcFlag(uint32 optionType)
{
    switch (optionType)
    {
    case GOSSIP_OPTION_GOSSIP:          return UNIT_NPC_FLAG_GOSSIP;
    case GOSSIP_OPTION_VENDOR:          return UNIT_NPC_FLAG_VENDOR;
    case GOSSIP_OPTION_QUESTGIVER:      return UNIT_NPC_FLAG_QUESTGIVER;
    case GOSSIP_OPTION_TRAINER:         return UNIT_NPC_FLAG_TRAINER;
    case GOSSIP_OPTION_TAXIVENDOR:      return UNIT_NPC_FLAG_FLIGHTMASTER;
    case GOSSIP_OPTION_PETITIONER:      return UNIT_NPC_FLAG_PETITIONER;
    case GOSSIP_OPTION_BATTLEFIELD:     return UNIT_NPC_FLAG_BATTLEMASTER;
    case GOSSIP_OPTION_BANKER:          return UNIT_NPC_FLAG_BANKER;
    case GOSSIP_OPTION_INNKEEPER:       return UNIT_NPC_FLAG_INNKEEPER;
    case GOSSIP_OPTION_SPIRITHEALER:    return UNIT_NPC_FLAG_SPIRITHEALER;
    case GOSSIP_OPTION_TABARDDESIGNER:  return UNIT_NPC_FLAG_TABARDDESIGNER;
    case GOSSIP_OPTION_AUCTIONEER:      return UNIT_NPC_FLAG_AUCTIONEER;
    case GOSSIP_OPTION_STABLEPET:       return UNIT_NPC_FLAG_STABLEMASTER;
    case GOSSIP_OPTION_ARMORER:         return UNIT_NPC_FLAG_REPAIR;
    case GOSSIP_OPTION_UNLEARNTALENTS:  return UNIT_NPC_FLAG_TRAINER;
    case GOSSIP_OPTION_UNLEARNPETTALENTS: return UNIT_NPC_FLAG_TRAINER;
    case GOSSIP_OPTION_LEARNDUALSPEC:   return UNIT_NPC_FLAG_TRAINER;
    default:                            return 0;
    }
}

// Counts how many NPC interaction flags this creature has (including gossip)
static int CountServiceFlags(Creature* creature)
{
    int count = 0;
    if (creature->HasNpcFlag(UNIT_NPC_FLAG_GOSSIP))         ++count;
    if (creature->IsQuestGiver())   ++count;
    if (creature->IsVendor())       ++count;
    if (creature->IsTrainer())      ++count;
    if (creature->IsBanker())       ++count;
    if (creature->IsInnkeeper())    ++count;
    if (creature->IsAuctioner())    ++count;
    if (creature->IsTaxi())         ++count;
    if (creature->IsGuildMaster())  ++count;
    if (creature->IsBattleMaster()) ++count;
    if (creature->IsTabardDesigner()) ++count;
    if (creature->IsSpiritHealer()) ++count;
    if (creature->IsArmorer())      ++count;
    if (creature->HasNpcFlag(UNIT_NPC_FLAG_STABLEMASTER))   ++count;
    if (creature->HasNpcFlag(UNIT_NPC_FLAG_GUILD_BANKER))   ++count;
    if (creature->HasNpcFlag(UNIT_NPC_FLAG_MAILBOX))        ++count;
    return count;
}

struct npc_restricted_skill : public ScriptedAI
{
    npc_restricted_skill(Creature* creature) : ScriptedAI(creature) {}

    bool OnGossipHello(Player* player) override
    {
        ClearGossipMenuFor(player);

        WorldSession* session = player->GetSession();

        // Multi-function NPC: gate the menu with the lowest requirement so the
        // player can open the menu if they qualify for ANY service.  Each
        // individual action is then gated in OnGossipSelect.
        if (CountServiceFlags(me) > 1)
        {
            // Blanket check (npc_flag = 0) blocks everything
            if (!CheckNpcSkillRequirement(player, me, 0))
                return true;

            // Find the lowest skill requirement across all this NPC's flags.
            // If the player can't even meet the easiest one, block entirely.
            SkillRequirement const* lowest = FindLowestRequirement(me);
            if (lowest && !MeetsRequirement(player, lowest))
            {
                player->GetSession()->SendNotification("%s", lowest->errorMessage.c_str());
                CloseGossipMenuFor(player);
                return true;
            }

            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
            return true;
        }

        // Single-function NPC: check the relevant flag and open the window directly
        if (me->IsQuestGiver())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_QUESTGIVER))
                return true;
            player->PrepareQuestMenu(me->GetGUID());
            player->SendPreparedQuest(me->GetGUID());
        }
        else if (me->IsVendor())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_VENDOR))
                return true;
            session->SendListInventory(me->GetGUID());
        }
        else if (me->IsTrainer())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_TRAINER))
                return true;
            session->SendTrainerList(me);
        }
        else if (me->IsBanker())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_BANKER))
                return true;
            session->SendShowBank(me->GetGUID());
        }
        else if (me->IsInnkeeper())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_INNKEEPER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->IsAuctioner())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_AUCTIONEER))
                return true;
            session->SendAuctionHello(me->GetGUID(), me);
        }
        else if (me->IsTaxi())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_FLIGHTMASTER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->IsGuildMaster())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_PETITIONER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->IsBattleMaster())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_BATTLEMASTER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->IsTabardDesigner())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_TABARDDESIGNER))
                return true;
            session->SendTabardVendorActivate(me->GetGUID());
        }
        else if (me->IsSpiritHealer())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_SPIRITHEALER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->IsArmorer())
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_REPAIR))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->HasNpcFlag(UNIT_NPC_FLAG_STABLEMASTER))
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_STABLEMASTER))
                return true;
            session->SendStablePet(me->GetGUID());
        }
        else if (me->HasNpcFlag(UNIT_NPC_FLAG_GUILD_BANKER))
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_GUILD_BANKER))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else if (me->HasNpcFlag(UNIT_NPC_FLAG_MAILBOX))
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_MAILBOX))
                return true;
            session->SendShowMailBox(me->GetGUID());
        }
        else if (me->HasNpcFlag(UNIT_NPC_FLAG_GOSSIP))
        {
            if (!CheckNpcSkillRequirement(player, me, UNIT_NPC_FLAG_GOSSIP))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }
        else
        {
            // No recognized flags: check the catch-all requirement
            if (!CheckNpcSkillRequirement(player, me, 0))
                return true;
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
        }

        return true;
    }

    bool OnGossipSelect(Player* player, uint32 menuId, uint32 gossipListId) override
    {
        GossipMenuItem const* item = player->PlayerTalkClass->GetGossipMenu().GetItem(gossipListId);
        if (!item)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // OptionType holds the Gossip_Option enum value for DB-defined items
        uint32 npcFlag = GossipOptionToNpcFlag(item->OptionType);
        if (npcFlag != 0)
        {
            // Flight Masters: skip skill checks for gossip and flight options,
            // but still gate other services like quest givers.
            if (me->IsTaxi() && (npcFlag == UNIT_NPC_FLAG_FLIGHTMASTER || npcFlag == UNIT_NPC_FLAG_GOSSIP))
            {
                player->OnGossipSelect(me, gossipListId, menuId);
                return true;
            }

            if (!CheckNpcSkillRequirement(player, me, npcFlag))
            {
                ClearGossipMenuFor(player);
                return true;
            }
        }

        // Let the core handle the action normally
        player->OnGossipSelect(me, gossipListId, menuId);
        return true;
    }
};

class npc_restricted_skill_loader : public WorldScript
{
public:
    npc_restricted_skill_loader() : WorldScript("npc_restricted_skill_loader") {}

    void OnStartup() override
    {
        LoadSkillRequirements();
    }

    static void LoadSkillRequirements()
    {
        skillRequirements.clear();

        QueryResult result = WorldDatabase.Query(
            "SELECT entry, npc_flag, skill_id, skill_level, error_message "
            "FROM npc_skill_requirements");
        if (!result)
            return;

        uint32 count = 0;
        do
        {
            Field* fields = result->Fetch();
            uint32 entry = fields[0].GetUInt32();
            uint32 npcFlag = fields[1].GetUInt32();

            SkillRequirement req;
            req.skillId = fields[2].GetUInt16();
            req.skillLevel = fields[3].GetUInt16();
            req.errorMessage = fields[4].GetString();

            skillRequirements[{ entry, npcFlag }] = req;
            ++count;

        } while (result->NextRow());

        TC_LOG_INFO("server.loading", ">> Loaded {} NPC skill requirements", count);
    }
};

void AddSC_npc_restricted_skill()
{
    RegisterCreatureAI(npc_restricted_skill);
    new npc_restricted_skill_loader();
}
