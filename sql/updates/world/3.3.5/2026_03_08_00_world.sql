CREATE TABLE IF NOT EXISTS `item_quality_family` (
    `family_id` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `quality`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Poor 1=Common 2=Uncommon 3=Rare 4=Epic',
    PRIMARY KEY (`family_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
