-- Maps a crafting spell to the output item that should be created for each reagent quality level.
-- quality: 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic (matches item_template.Quality)
CREATE TABLE IF NOT EXISTS `spell_quality_output` (
    `spell_id` INT UNSIGNED NOT NULL,
    `quality`  TINYINT UNSIGNED NOT NULL COMMENT '0=Poor 1=Common 2=Uncommon 3=Rare 4=Epic',
    `item_id`  INT UNSIGNED NOT NULL,
    PRIMARY KEY (`spell_id`, `quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example data:
-- Crafting a Bronze Coif (spell 99001) produces a different quality item
-- depending on which quality of Copper Coif the player uses as a reagent.
-- INSERT INTO `spell_quality_output` VALUES
-- (99001, 1, 90010),  -- Common   Copper Coif reagent  -> Common   Bronze Coif
-- (99001, 2, 90011),  -- Uncommon Copper Coif reagent  -> Uncommon Bronze Coif
-- (99001, 3, 90012),  -- Rare     Copper Coif reagent  -> Rare     Bronze Coif
-- (99001, 4, 90013);  -- Epic     Copper Coif reagent  -> Epic     Bronze Coif
