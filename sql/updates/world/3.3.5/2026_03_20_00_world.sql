-- Overrides the reagent count for a specific reagent slot when crafting at a given quality tier.
-- spell_id:     the crafting spell ID
-- quality:      0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
-- reagent_slot: 0-based reagent slot index (0-7)
-- count:        the number of reagents required at this quality tier
CREATE TABLE IF NOT EXISTS `spell_quality_reagent_count` (
    `spell_id`     INT UNSIGNED NOT NULL,
    `quality`      TINYINT UNSIGNED NOT NULL COMMENT '0=Poor 1=Common 2=Uncommon 3=Rare 4=Epic 5=Legendary',
    `reagent_slot` TINYINT UNSIGNED NOT NULL COMMENT '0-based reagent slot index',
    `count`        INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`spell_id`, `quality`, `reagent_slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example: Copper Gloves recipe (spell 99002) uses a Rune in slot 1.
-- Common quality requires 1 Rune, Legendary quality requires 5 Runes.
-- INSERT INTO `spell_quality_reagent_count` VALUES
-- (99002, 1, 1, 1),  -- Common   -> 1x Rune
-- (99002, 2, 1, 2),  -- Uncommon -> 2x Rune
-- (99002, 3, 1, 3),  -- Rare     -> 3x Rune
-- (99002, 4, 1, 4),  -- Epic     -> 4x Rune
-- (99002, 5, 1, 5);  -- Legendary -> 5x Rune
