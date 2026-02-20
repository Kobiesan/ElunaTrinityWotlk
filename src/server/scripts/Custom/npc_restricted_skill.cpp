#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "WorldSession.h"
#include "ScriptedGossip.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"

struct SkillRequirement
{
    uint32 skillId;
    uint32 skillLevel;
};

struct PairHash
{
    std::size_t operator()(std::pair<uint32, uint32> const& p) const noexcept
    {
        return std::hash<uint64>()(static_cast<uint64>(p.first) << 32 | p.second);
    }
};

// Key: { creature entry, npc_flag } -> vector of alternatives (OR logic)
static std::unordered_map<std::pair<uint32, uint32>, std::vector<SkillRequirement>, PairHash> skillRequirements;

static std::vector<SkillRequirement> const* FindRequirements(uint32 entry, uint32 npcFlag)
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

static constexpr uint32 NPC_SERVICE_FLAGS[] =
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

// Returns the lowest skill requirement among all flags this creature has.
// If the player meets this, they qualify for at least one service.
// With OR-logic, a group's "effective level" is the minimum among its alternatives.
static uint32 FindLowestRequirementLevel(Creature* creature)
{
    bool isTaxi = creature->IsTaxi();
    uint32 entry = creature->GetEntry();
    uint32 lowestLevel = UINT32_MAX;
    bool found = false;

    for (uint32 flag : NPC_SERVICE_FLAGS)
    {
        if (!creature->HasNpcFlag(static_cast<NPCFlags>(flag)))
            continue;

        if (isTaxi && (flag == UNIT_NPC_FLAG_FLIGHTMASTER ||
            flag == UNIT_NPC_FLAG_GOSSIP ||
            flag == UNIT_NPC_FLAG_QUESTGIVER))
            continue;

        std::vector<SkillRequirement> const* reqs = FindRequirements(entry, flag);
        if (!reqs)
            continue;

        // With OR logic, a group's effective level is the minimum across alternatives
        for (SkillRequirement const& req : *reqs)
        {
            if (req.skillLevel < lowestLevel)
            {
                lowestLevel = req.skillLevel;
                found = true;
            }
        }
    }

    return found ? lowestLevel : 0;
}

static bool MeetsSingleRequirement(Player* player, SkillRequirement const& req)
{
    return player->HasSkill(req.skillId) &&
        player->GetSkillValue(req.skillId) >= req.skillLevel;
}

// OR logic: player must meet at least one requirement in the group
static bool MeetsRequirements(Player* player, std::vector<SkillRequirement> const* reqs)
{
    if (!reqs || reqs->empty())
        return true;

    for (SkillRequirement const& req : *reqs)
    {
        if (MeetsSingleRequirement(player, req))
            return true;
    }

    return false;
}

static char const* NpcFlagToServiceName(uint32 npcFlag)
{
    switch (npcFlag)
    {
    case UNIT_NPC_FLAG_TRAINER:         return "trainer";
    case UNIT_NPC_FLAG_VENDOR:          return "vendor";
    case UNIT_NPC_FLAG_QUESTGIVER:      return "quest giver";
    case UNIT_NPC_FLAG_FLIGHTMASTER:    return "flight master";
    case UNIT_NPC_FLAG_INNKEEPER:       return "innkeeper";
    case UNIT_NPC_FLAG_BANKER:          return "banker";
    case UNIT_NPC_FLAG_AUCTIONEER:      return "auctioneer";
    case UNIT_NPC_FLAG_STABLEMASTER:    return "stable master";
    case UNIT_NPC_FLAG_PETITIONER:      return "guild master";
    case UNIT_NPC_FLAG_TABARDDESIGNER:  return "tabard designer";
    case UNIT_NPC_FLAG_BATTLEMASTER:    return "battlemaster";
    case UNIT_NPC_FLAG_SPIRITHEALER:    return "spirit healer";
    case UNIT_NPC_FLAG_REPAIR:          return "armorer";
    case UNIT_NPC_FLAG_GUILD_BANKER:    return "guild banker";
    case UNIT_NPC_FLAG_MAILBOX:         return "mailbox";
    default:                            return "character";
    }
}

static char const* GetSkillName(uint32 skillId)
{
    SkillLineEntry const* entry = sSkillLineStore.LookupEntry(skillId);
    if (entry && entry->DisplayName[0] && entry->DisplayName[0][0] != '\0')
        return entry->DisplayName[0];
    return "Unknown";
}

// Determines the most meaningful service flag from a creature's NPC flags
static uint32 GetPrimaryServiceFlag(Creature* creature)
{
    if (!creature)
        return 0;

    for (uint32 flag : NPC_SERVICE_FLAGS)
    {
        // Skip GOSSIP and QUESTGIVER as they are too generic for service identification
        if (flag == UNIT_NPC_FLAG_GOSSIP || flag == UNIT_NPC_FLAG_QUESTGIVER)
            continue;
        if (creature->HasNpcFlag(static_cast<NPCFlags>(flag)))
            return flag;
    }
    return 0;
}

// Builds a combined message like:
//   "You need 75 Dwarvish, 75 Gnomish, or 75 Orcish to speak with this trainer."
//   "You need 75 Dwarvish to repair items at this armorer."
static void SendRequirementErrors(Player* player, std::vector<SkillRequirement> const* reqs, uint32 npcFlag = 0, Creature* creature = nullptr)
{
    if (!reqs || reqs->empty())
        return;

    std::string message = "You need ";
    for (size_t i = 0; i < reqs->size(); ++i)
    {
        if (i > 0)
        {
            if (reqs->size() == 2)
                message += " or ";
            else if (i == reqs->size() - 1)
                message += ", or ";
            else
                message += ", ";
        }
        message += std::to_string((*reqs)[i].skillLevel);
        message += " ";
        message += GetSkillName((*reqs)[i].skillId);
    }

    if (npcFlag == UNIT_NPC_FLAG_REPAIR)
    {
        message += " to repair items at this armorer.";
    }
    else
    {
        // When npcFlag is unset (0), try to determine a better name
        uint32 displayFlag = npcFlag;
        if (creature && displayFlag == 0)
            displayFlag = GetPrimaryServiceFlag(creature);

        message += " to speak with this ";
        message += NpcFlagToServiceName(displayFlag);
        message += ".";
    }

    player->GetSession()->SendNotification("%s", message.c_str());
}

// Public function so other scripts can check skill requirements
bool CheckNpcSkillRequirement(Player* player, Creature* creature, uint32 npcFlag)
{
    if (!player || !creature)
        return true;

    std::vector<SkillRequirement> const* reqs = FindRequirements(creature->GetEntry(), npcFlag);
    if (!reqs)
        return true;

    if (!MeetsRequirements(player, reqs))
    {
        SendRequirementErrors(player, reqs, npcFlag, creature);
        CloseGossipMenuFor(player);
        return false;
    }

    return true;
}

bool MeetsNpcSkillRequirement(Player* player, Creature* creature, uint32 npcFlag)
{
    if (!player || !creature)
        return true;

    std::vector<SkillRequirement> const* reqs = FindRequirements(creature->GetEntry(), npcFlag);
    if (!reqs)
        return true;

    return MeetsRequirements(player, reqs);
}

// Maps a Gossip_Option type to the corresponding UNIT_NPC_FLAG
uint32 GossipOptionToNpcFlag(uint32 optionType)
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

bool CheckNpcSkillRequirementForGossipHello(Player* player, Creature* creature)
{
    if (!player || !creature)
        return true;

    // Blanket check (npc_flag = 0) blocks everything
    if (!CheckNpcSkillRequirement(player, creature, 0))
        return false;

    // Find the lowest skill requirement across all this NPC's flags.
    // If the player can't even meet the easiest one, block entirely.
    uint32 lowestLevel = FindLowestRequirementLevel(creature);
    if (lowestLevel > 0)
    {
        // Check if the player meets ANY requirement across all flags
        // by re-checking each flag's requirements with OR logic
        bool isTaxi = creature->IsTaxi();
        bool meetsAny = false;
        std::vector<SkillRequirement> const* firstFailedReqs = nullptr;
        uint32 firstFailedFlag = 0;

        for (uint32 flag : NPC_SERVICE_FLAGS)
        {
            if (!creature->HasNpcFlag(static_cast<NPCFlags>(flag)))
                continue;

            if (isTaxi && (flag == UNIT_NPC_FLAG_FLIGHTMASTER ||
                flag == UNIT_NPC_FLAG_GOSSIP ||
                flag == UNIT_NPC_FLAG_QUESTGIVER))
                continue;

            std::vector<SkillRequirement> const* reqs = FindRequirements(creature->GetEntry(), flag);
            if (!reqs)
                continue;

            if (!firstFailedReqs)
            {
                firstFailedReqs = reqs;
                firstFailedFlag = flag;
            }

            if (MeetsRequirements(player, reqs))
            {
                meetsAny = true;
                break;
            }
        }

        if (!meetsAny)
        {
            std::vector<SkillRequirement> const* displayReqs = firstFailedReqs;
            uint32 displayFlag = firstFailedFlag;

            // Count specific service flags (excluding generic GOSSIP and QUESTGIVER)
            // to determine if the NPC shows a gossip menu as a gateway.
            uint32 specificServiceCount = 0;
            for (uint32 flag : NPC_SERVICE_FLAGS)
            {
                if (flag == UNIT_NPC_FLAG_GOSSIP || flag == UNIT_NPC_FLAG_QUESTGIVER)
                    continue;
                if (creature->HasNpcFlag(static_cast<NPCFlags>(flag)))
                    ++specificServiceCount;
            }

            // When the NPC has a single specific service (no gossip menu),
            // use the primary service's requirements so the skill level
            // matches the service name displayed.
            // When the NPC shows a gossip menu (multiple specific services),
            // keep the gossip-level error since that's the first barrier.
            if (specificServiceCount < 2)
            {
                uint32 primaryFlag = GetPrimaryServiceFlag(creature);
                if (primaryFlag != 0)
                {
                    std::vector<SkillRequirement> const* primaryReqs = FindRequirements(creature->GetEntry(), primaryFlag);
                    if (primaryReqs)
                    {
                        displayReqs = primaryReqs;
                        displayFlag = primaryFlag;
                    }
                }
            }

            SendRequirementErrors(player, displayReqs, displayFlag, creature);
            CloseGossipMenuFor(player);
            return false;
        }
    }

    return true;
}

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
            "SELECT entry, npc_flag, skill_id, skill_level "
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

            skillRequirements[{ entry, npcFlag }].push_back(req);
            ++count;

        } while (result->NextRow());

        TC_LOG_INFO("server.loading", ">> Loaded {} NPC skill requirements", count);
    }
};

void AddSC_npc_restricted_skill()
{
    new npc_restricted_skill_loader();
}
