#ifndef NPC_RESTRICTED_SKILL_H
#define NPC_RESTRICTED_SKILL_H

#include "Define.h"

class Player;
class Creature;

// Returns true if the player meets the skill requirement for this NPC (or if none exists).
// Returns false and sends an error notification if the check fails.
// npcFlag: the specific NPC function to check (e.g. UNIT_NPC_FLAG_VENDOR, UNIT_NPC_FLAG_TRAINER).
//          Use 0 to check the blanket/catch-all requirement.
bool CheckNpcSkillRequirement(Player* player, Creature* creature, uint32 npcFlag = 0);

// Silent version: returns true/false without sending any notification or closing gossip.
bool MeetsNpcSkillRequirement(Player* player, Creature* creature, uint32 npcFlag = 0);

// Checks whether the player can open the gossip dialog with this NPC.
// For multi-function NPCs, uses the lowest skill requirement across all services.
// Returns false and sends an error notification if the check fails.
bool CheckNpcSkillRequirementForGossipHello(Player* player, Creature* creature);

// Maps a Gossip_Option type (GOSSIP_OPTION_VENDOR, etc.) to the corresponding UNIT_NPC_FLAG.
uint32 GossipOptionToNpcFlag(uint32 optionType);

#endif // NPC_RESTRICTED_SKILL_H
