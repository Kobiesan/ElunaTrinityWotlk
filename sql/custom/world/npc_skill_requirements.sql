-- ============================================================
-- NPC Skill Requirements – Populate rows for a given skill/faction
-- ============================================================
-- Configuration: Change these values to target a different
-- skill or faction
-- ============================================================
SET @skill_id   = 111;    -- Skill ID (e.g. 98 = Common, 109 = Orcish)
SET @skill_name = 'Dwarvish'; -- Used in error messages
SET @faction_id = 57;    -- Creature template faction

START TRANSACTION;

INSERT IGNORE INTO npc_skill_requirements (entry, npc_flag, skill_id, skill_level, error_message)
SELECT entry, npc_flag, @skill_id, skill_level, error_message
FROM (
    -- Gossip (flag 1) - skill 1, exclude Flight Masters and NPCs where gossip
    -- is decorative (gossip + one logical service that skips the gossip menu)
    SELECT entry, 1 AS npc_flag, 1 AS skill_level,
           CONCAT('You must know beginner ', @skill_name, ' to interact with this character') AS error_message
    FROM creature_template
    WHERE (npcflag & 0x00000001) <> 0 AND (npcflag & 0x00002000) = 0
      AND faction = @faction_id
      AND (subname IS NULL OR subname NOT LIKE '%Instructor%')
      -- Count functional flags that skip the gossip menu.
      -- Excludes Quest Giver (shows gossip when no quests available).
      -- Vendor+Repairer counted as one logical service.
      -- Guild Master and Tabard Designer also skip gossip.
      AND (BIT_COUNT(npcflag & (0x00000010 | 0x00000080 | 0x00001000 |
                                0x00010000 | 0x00020000 |
                                0x00100000 | 0x00200000 | 0x00400000 | 0x00800000))
           + CASE WHEN (npcflag & 0x00040000) <> 0 THEN 1 ELSE 0 END
           + CASE WHEN (npcflag & 0x00080000) <> 0 THEN 1 ELSE 0 END
           + CASE WHEN (npcflag & 0x00000002) <> 0 AND (npcflag & 0x00000010) <> 0 THEN 1 ELSE 0 END) <> 1

    UNION ALL
    -- Quest Giver (flag 2) - skill 75
    SELECT entry, 2, 75,
           CONCAT('You must have 75 ', @skill_name, ' to interact with this quest giver')
    FROM creature_template WHERE (npcflag & 0x00000002) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Trainer (flag 16) - skill 100
    SELECT entry, 16, 100,
           CONCAT('You must have 100 ', @skill_name, ' to interact with this trainer')
    FROM creature_template WHERE (npcflag & 0x00000010) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Vendor (flag 128) - skill 1
    -- Repairers that are also vendors get gated here; the server-side
    -- HandleRepairItemOpcode check uses the vendor requirement.
    SELECT entry, 128, 1,
           CONCAT('You must know beginner ', @skill_name, ' to interact with this vendor')
    FROM creature_template WHERE (npcflag & 0x00000080) <> 0
    AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Repairer-only (flag 4096, no vendor flag) - skill 25
    SELECT entry, 4096, 25,
           CONCAT('You must have 25 ', @skill_name, ' to interact with this repairer')
    FROM creature_template WHERE (npcflag & 0x00001000) <> 0
    AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Innkeeper (flag 65536) - skill 1
    SELECT entry, 65536, 1,
           CONCAT('You must know beginner ', @skill_name, ' to interact with this innkeeper')
    FROM creature_template WHERE (npcflag & 0x00010000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Banker (flag 131072) - skill 75
    SELECT entry, 131072, 75,
           CONCAT('You must have 75 ', @skill_name, ' to interact with this banker')
    FROM creature_template WHERE (npcflag & 0x00020000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Guild Master / Petitioner (flag 262144) - skill 75
    SELECT entry, 262144, 75,
           CONCAT('You must have 75 ', @skill_name, ' to interact with this guild master')
    FROM creature_template WHERE (npcflag & 0x00040000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Tabard Designer (flag 524288) - skill 75
    SELECT entry, 524288, 75,
           CONCAT('You must have 75 ', @skill_name, ' to interact with this tabard designer')
    FROM creature_template WHERE (npcflag & 0x00080000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Stable Master (flag 4194304) - skill 1
    SELECT entry, 4194304, 1,
           CONCAT('You must know beginner ', @skill_name, ' to interact with this stable master')
    FROM creature_template WHERE (npcflag & 0x00400000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')

    UNION ALL
    -- Auctioneer (flag 2097152) - skill 150
    SELECT entry, 2097152, 150,
           CONCAT('You must have 150 ', @skill_name, ' to interact with this auctioneer')
    FROM creature_template WHERE (npcflag & 0x00200000) <> 0 AND faction = @faction_id
    AND (subname IS NULL OR subname NOT LIKE '%Instructor%')
    ) AS requirements;




-- 1. Show all npc_skill_requirements rows for this faction's creatures
SELECT
    ct.entry,
    ct.name,
    ct.subname,
    ct.npcflag,
    ct.ScriptName,
    nsr.npc_flag,
    nsr.skill_id,
    nsr.skill_level,
    nsr.error_message
FROM creature_template ct
JOIN npc_skill_requirements nsr ON nsr.entry = ct.entry
WHERE ct.faction = @faction_id
  AND nsr.skill_id = @skill_id
ORDER BY ct.entry, nsr.npc_flag;

-- 2. Find creatures that SHOULD have rows but are missing some flags
SELECT
    ct.entry,
    ct.name,
    ct.subname,
    ct.npcflag,
    ct.ScriptName,
    -- Expected flags vs actual flags in npc_skill_requirements
    CASE WHEN (ct.npcflag & 0x00000001) <> 0 AND (ct.npcflag & 0x00002000) = 0 THEN 'Y' ELSE '-' END AS expect_gossip,
    CASE WHEN (ct.npcflag & 0x00000002) <> 0 THEN 'Y' ELSE '-' END AS expect_quest,
    CASE WHEN (ct.npcflag & 0x00000010) <> 0 THEN 'Y' ELSE '-' END AS expect_trainer,
    CASE WHEN (ct.npcflag & 0x00000080) <> 0 THEN 'Y' ELSE '-' END AS expect_vendor,
    CASE WHEN (ct.npcflag & 0x00001000) <> 0 THEN 'Y' ELSE '-' END AS expect_repair,
    CASE WHEN (ct.npcflag & 0x00010000) <> 0 THEN 'Y' ELSE '-' END AS expect_innkeeper,
    CASE WHEN (ct.npcflag & 0x00020000) <> 0 THEN 'Y' ELSE '-' END AS expect_banker,
    CASE WHEN (ct.npcflag & 0x00040000) <> 0 THEN 'Y' ELSE '-' END AS expect_guild,
    CASE WHEN (ct.npcflag & 0x00080000) <> 0 THEN 'Y' ELSE '-' END AS expect_tabard,
    CASE WHEN (ct.npcflag & 0x00200000) <> 0 THEN 'Y' ELSE '-' END AS expect_auctioneer,
    CASE WHEN (ct.npcflag & 0x00400000) <> 0 THEN 'Y' ELSE '-' END AS expect_stable,
    GROUP_CONCAT(nsr.npc_flag ORDER BY nsr.npc_flag) AS actual_flags
FROM creature_template ct
LEFT JOIN npc_skill_requirements nsr ON nsr.entry = ct.entry AND nsr.skill_id = @skill_id
WHERE ct.faction = @faction_id
  AND (ct.subname IS NULL OR ct.subname NOT LIKE '%Instructor%')
  AND (ct.npcflag & (0x00000001 | 0x00000002 | 0x00000010 | 0x00000080 | 0x00001000 |
                     0x00010000 | 0x00020000 | 0x00040000 | 0x00080000 | 0x00200000 | 0x00400000)) <> 0
GROUP BY ct.entry
ORDER BY ct.entry;

-- 3. Find creatures missing ScriptName that should have it
SELECT entry, name, npcflag, ScriptName
FROM creature_template
WHERE faction = @faction_id
  AND ScriptName = ''
  AND (subname IS NULL OR subname NOT LIKE '%Instructor%')
  AND (npcflag & 0x00002000) = 0
  AND (npcflag & (0x00000001 | 0x00000002 | 0x00000010 | 0x00000080 | 0x00001000 |
                  0x00010000 | 0x00020000 | 0x00040000 | 0x00080000 | 0x00200000)) <> 0
ORDER BY entry;
COMMIT;
