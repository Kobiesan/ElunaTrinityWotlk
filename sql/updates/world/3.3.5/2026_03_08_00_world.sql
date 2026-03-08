CREATE TABLE IF NOT EXISTS `item_quality_family` (
    `family_id` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`family_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
