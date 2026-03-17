-- Add explicit quality column to item_quality_family.
-- This makes each row self-describing: no need to join item_template.Quality
-- to know what crafting-tier an item represents within its family.
-- quality: 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic (mirrors item_template.Quality)
ALTER TABLE `item_quality_family`
    ADD COLUMN `quality` TINYINT UNSIGNED NOT NULL DEFAULT 0
        COMMENT '0=Poor 1=Common 2=Uncommon 3=Rare 4=Epic'
        AFTER `item_id`;

-- Example data – update after altering the table if you had existing rows:
-- UPDATE `item_quality_family` iqf
--   JOIN `item_template` it ON it.entry = iqf.item_id
--   SET iqf.quality = it.Quality;
