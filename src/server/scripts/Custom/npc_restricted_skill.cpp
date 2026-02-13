#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "WorldSession.h"
#include "ScriptedGossip.h"
#include "ScriptedCreature.h"
#include "DatabaseEnv.h"

struct SkillRequirement
{
    uint32 skillId;
    uint32 skillLevel;
    std::string errorMessage;
};

static std::unordered_map<uint32, SkillRequirement> skillRequirements;

struct npc_restricted_skill : public ScriptedAI
{
    npc_restricted_skill(Creature* creature) : ScriptedAI(creature) {}

    bool OnGossipHello(Player* player) override
    {
        auto itr = skillRequirements.find(me->GetEntry());
        if (itr != skillRequirements.end())
        {
            SkillRequirement const& req = itr->second;

            if (!player->HasSkill(req.skillId) ||
                player->GetSkillValue(req.skillId) < req.skillLevel)
            {
                player->GetSession()->SendNotification("%s", req.errorMessage.c_str());
                CloseGossipMenuFor(player);
                return true;
            }
        }

        // Skill check passed - open the appropriate NPC window based on flags
        WorldSession* session = player->GetSession();

        if (me->IsAuctioner())
            session->SendAuctionHello(me->GetGUID(), me);
        else if (me->IsBanker())
            session->SendShowBank(me->GetGUID());
        else if (me->IsVendor())
            session->SendListInventory(me->GetGUID());
        else if (me->IsTrainer())
            session->SendTrainerList(me);
        else if (me->IsArmorer())
        {
            // Repair - show gossip with repair option
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
            return true;
        }
        else if (me->IsInnkeeper())
            session->SendBindPoint(me);
        else if (me->IsTabardDesigner())
            session->SendTabardVendorActivate(me->GetGUID());
        else if (me->HasNpcFlag(UNIT_NPC_FLAG_STABLEMASTER))
            session->SendStablePet(me->GetGUID());
        else
        {
            // Fallback: show normal gossip menu
            player->PrepareGossipMenu(me, me->GetCreatureTemplate()->GossipMenuId, true);
            player->SendPreparedGossip(me);
            return true;
        }

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

        QueryResult result = WorldDatabase.Query("SELECT entry, skill_id, skill_level, error_message FROM npc_skill_requirements");
        if (!result)
            return;

        do
        {
            Field* fields = result->Fetch();
            uint32 entry = fields[0].GetUInt32();

            SkillRequirement req;
            req.skillId = fields[1].GetUInt16();
            req.skillLevel = fields[2].GetUInt16();
            req.errorMessage = fields[3].GetString();

            skillRequirements[entry] = req;

        } while (result->NextRow());
    }
};

void AddSC_npc_restricted_skill()
{
    RegisterCreatureAI(npc_restricted_skill);
    new npc_restricted_skill_loader();
}
