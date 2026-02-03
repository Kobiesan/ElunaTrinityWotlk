-- All Races All Classes (ARAC) SQL Script for TrinityCore 3.3.5a
-- Based on JadaDev's ARAC implementation
-- This script allows players to create characters with any race/class combination
--
-- Races:
--   Human = 1, Orc = 2, Dwarf = 3, Night Elf = 4, Undead = 5
--   Tauren = 6, Gnome = 7, Troll = 8, Blood Elf = 10, Draenei = 11
--
-- Classes:
--   Warrior = 1, Paladin = 2, Hunter = 3, Rogue = 4, Priest = 5
--   Death Knight = 6, Shaman = 7, Mage = 8, Warlock = 9, Druid = 11

SET FOREIGN_KEY_CHECKS=0;

-- ===================================================================
-- PLAYERCREATEINFO - Spawn locations for each race/class combination
-- ===================================================================

-- Human (Race 1) - Adding: Hunter(3), Shaman(7), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(1, 3, 0, 12, -8949.95, -132.493, 83.5312, 0),
(1, 7, 0, 12, -8949.95, -132.493, 83.5312, 0),
(1, 11, 0, 12, -8949.95, -132.493, 83.5312, 0);

-- Orc (Race 2) - Adding: Paladin(2), Priest(5), Mage(8), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(2, 2, 1, 14, -618.518, -4251.67, 38.718, 0),
(2, 5, 1, 14, -618.518, -4251.67, 38.718, 0),
(2, 8, 1, 14, -618.518, -4251.67, 38.718, 0),
(2, 11, 1, 14, -618.518, -4251.67, 38.718, 0);

-- Dwarf (Race 3) - Adding: Shaman(7), Mage(8), Warlock(9), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(3, 7, 0, 1, -6240.32, 331.033, 382.758, 6.17716),
(3, 8, 0, 1, -6240.32, 331.033, 382.758, 6.17716),
(3, 9, 0, 1, -6240.32, 331.033, 382.758, 6.17716),
(3, 11, 0, 1, -6240.32, 331.033, 382.758, 6.17716);

-- Night Elf (Race 4) - Adding: Paladin(2), Shaman(7), Mage(8), Warlock(9)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(4, 2, 1, 141, 10311.3, 832.463, 1326.41, 5.69632),
(4, 7, 1, 141, 10311.3, 832.463, 1326.41, 5.69632),
(4, 8, 1, 141, 10311.3, 832.463, 1326.41, 5.69632),
(4, 9, 1, 141, 10311.3, 832.463, 1326.41, 5.69632);

-- Undead (Race 5) - Adding: Paladin(2), Hunter(3), Shaman(7), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(5, 2, 0, 85, 1676.71, 1678.31, 121.67, 2.70526),
(5, 3, 0, 85, 1676.71, 1678.31, 121.67, 2.70526),
(5, 7, 0, 85, 1676.71, 1678.31, 121.67, 2.70526),
(5, 11, 0, 85, 1676.71, 1678.31, 121.67, 2.70526);

-- Tauren (Race 6) - Adding: Paladin(2), Rogue(4), Priest(5), Mage(8), Warlock(9)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(6, 2, 1, 215, -2917.58, -257.98, 52.9968, 0),
(6, 4, 1, 215, -2917.58, -257.98, 52.9968, 0),
(6, 5, 1, 215, -2917.58, -257.98, 52.9968, 0),
(6, 8, 1, 215, -2917.58, -257.98, 52.9968, 0),
(6, 9, 1, 215, -2917.58, -257.98, 52.9968, 0);

-- Gnome (Race 7) - Adding: Paladin(2), Hunter(3), Priest(5), Shaman(7), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(7, 2, 0, 1, -6240.32, 331.033, 382.758, 0),
(7, 3, 0, 1, -6240.32, 331.033, 382.758, 0),
(7, 5, 0, 1, -6240.32, 331.033, 382.758, 0),
(7, 7, 0, 1, -6240.32, 331.033, 382.758, 0),
(7, 11, 0, 1, -6240.32, 331.033, 382.758, 0);

-- Troll (Race 8) - Adding: Paladin(2), Warlock(9), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(8, 2, 1, 14, -618.518, -4251.67, 38.718, 0),
(8, 9, 1, 14, -618.518, -4251.67, 38.718, 0),
(8, 11, 1, 14, -618.518, -4251.67, 38.718, 0);

-- Blood Elf (Race 10) - Adding: Warrior(1), Shaman(7), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(10, 1, 530, 3431, 10349.6, -6357.29, 33.4026, 5.31605),
(10, 7, 530, 3431, 10349.6, -6357.29, 33.4026, 5.31605),
(10, 11, 530, 3431, 10349.6, -6357.29, 33.4026, 5.31605);

-- Draenei (Race 11) - Adding: Rogue(4), Warlock(9), Druid(11)
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`) VALUES
(11, 4, 530, 3526, -3961.64, -13931.2, 100.615, 2.08364),
(11, 9, 530, 3526, -3961.64, -13931.2, 100.615, 2.08364),
(11, 11, 530, 3526, -3961.64, -13931.2, 100.615, 2.08364);

-- ===================================================================
-- PLAYERCREATEINFO_ACTION - Default action bar for new race/class combos
-- ===================================================================

-- Human Hunter (1, 3)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(1, 3, 0, 6603, 0),
(1, 3, 1, 2973, 0),
(1, 3, 2, 75, 0),
(1, 3, 11, 59752, 0);

-- Human Shaman (1, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(1, 7, 0, 6603, 0),
(1, 7, 1, 403, 0),
(1, 7, 2, 331, 0),
(1, 7, 3, 59752, 0);

-- Human Druid (1, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(1, 11, 0, 5176, 0),
(1, 11, 1, 5185, 0),
(1, 11, 11, 59752, 0);

-- Orc Paladin (2, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(2, 2, 0, 6603, 0),
(2, 2, 1, 21084, 0),
(2, 2, 2, 635, 0),
(2, 2, 11, 20572, 0);

-- Orc Priest (2, 5)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(2, 5, 0, 585, 0),
(2, 5, 1, 2050, 0),
(2, 5, 11, 20572, 0);

-- Orc Mage (2, 8)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(2, 8, 0, 133, 0),
(2, 8, 1, 168, 0),
(2, 8, 11, 20572, 0);

-- Orc Druid (2, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(2, 11, 0, 5176, 0),
(2, 11, 1, 5185, 0),
(2, 11, 2, 20572, 0),
(2, 11, 73, 6603, 0),
(2, 11, 76, 20572, 0),
(2, 11, 85, 6603, 0),
(2, 11, 97, 6603, 0),
(2, 11, 109, 6603, 0);

-- Dwarf Shaman (3, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(3, 7, 0, 6603, 0),
(3, 7, 1, 403, 0),
(3, 7, 2, 331, 0),
(3, 7, 3, 20594, 0),
(3, 7, 4, 2481, 0);

-- Dwarf Mage (3, 8)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(3, 8, 0, 133, 0),
(3, 8, 1, 168, 0),
(3, 8, 10, 2481, 0),
(3, 8, 11, 20594, 0);

-- Dwarf Warlock (3, 9)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(3, 9, 0, 686, 0),
(3, 9, 1, 687, 0),
(3, 9, 10, 2481, 0),
(3, 9, 11, 20594, 0);

-- Dwarf Druid (3, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(3, 11, 0, 5176, 0),
(3, 11, 1, 5185, 0),
(3, 11, 10, 2481, 0),
(3, 11, 11, 20594, 0);

-- Night Elf Paladin (4, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(4, 2, 0, 6603, 0),
(4, 2, 1, 21084, 0),
(4, 2, 2, 635, 0),
(4, 2, 11, 58984, 0);

-- Night Elf Shaman (4, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(4, 7, 0, 6603, 0),
(4, 7, 1, 403, 0),
(4, 7, 2, 331, 0),
(4, 7, 3, 58984, 0);

-- Night Elf Mage (4, 8)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(4, 8, 0, 133, 0),
(4, 8, 1, 168, 0),
(4, 8, 11, 58984, 0);

-- Night Elf Warlock (4, 9)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(4, 9, 0, 686, 0),
(4, 9, 1, 687, 0),
(4, 9, 11, 58984, 0);

-- Undead Paladin (5, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(5, 2, 0, 6603, 0),
(5, 2, 1, 21084, 0),
(5, 2, 2, 635, 0),
(5, 2, 11, 20577, 0);

-- Undead Hunter (5, 3)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(5, 3, 0, 6603, 0),
(5, 3, 1, 2973, 0),
(5, 3, 2, 75, 0),
(5, 3, 11, 20577, 0);

-- Undead Shaman (5, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(5, 7, 0, 6603, 0),
(5, 7, 1, 403, 0),
(5, 7, 2, 331, 0),
(5, 7, 3, 20577, 0);

-- Undead Druid (5, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(5, 11, 0, 5176, 0),
(5, 11, 1, 5185, 0),
(5, 11, 11, 20577, 0);

-- Tauren Paladin (6, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(6, 2, 0, 6603, 0),
(6, 2, 1, 21084, 0),
(6, 2, 2, 635, 0),
(6, 2, 11, 20549, 0);

-- Tauren Rogue (6, 4)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(6, 4, 0, 6603, 0),
(6, 4, 1, 1752, 0),
(6, 4, 2, 2098, 0),
(6, 4, 3, 2764, 0),
(6, 4, 11, 20549, 0);

-- Tauren Priest (6, 5)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(6, 5, 0, 585, 0),
(6, 5, 1, 2050, 0),
(6, 5, 11, 20549, 0);

-- Tauren Mage (6, 8)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(6, 8, 0, 133, 0),
(6, 8, 1, 168, 0),
(6, 8, 11, 20549, 0);

-- Tauren Warlock (6, 9)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(6, 9, 0, 686, 0),
(6, 9, 1, 687, 0),
(6, 9, 11, 20549, 0);

-- Gnome Paladin (7, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(7, 2, 0, 6603, 0),
(7, 2, 1, 21084, 0),
(7, 2, 2, 635, 0),
(7, 2, 11, 20589, 0);

-- Gnome Hunter (7, 3)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(7, 3, 0, 6603, 0),
(7, 3, 1, 2973, 0),
(7, 3, 2, 75, 0),
(7, 3, 11, 20589, 0);

-- Gnome Priest (7, 5)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(7, 5, 0, 585, 0),
(7, 5, 1, 2050, 0),
(7, 5, 11, 20589, 0);

-- Gnome Shaman (7, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(7, 7, 0, 6603, 0),
(7, 7, 1, 403, 0),
(7, 7, 2, 331, 0),
(7, 7, 3, 20589, 0);

-- Gnome Druid (7, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(7, 11, 0, 5176, 0),
(7, 11, 1, 5185, 0),
(7, 11, 11, 20589, 0);

-- Troll Paladin (8, 2)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(8, 2, 0, 6603, 0),
(8, 2, 1, 21084, 0),
(8, 2, 2, 635, 0),
(8, 2, 11, 20554, 0);

-- Troll Warlock (8, 9)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(8, 9, 0, 686, 0),
(8, 9, 1, 687, 0),
(8, 9, 11, 20554, 0);

-- Troll Druid (8, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(8, 11, 0, 5176, 0),
(8, 11, 1, 5185, 0),
(8, 11, 11, 20554, 0);

-- Blood Elf Warrior (10, 1)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(10, 1, 0, 6603, 0),
(10, 1, 72, 6603, 0),
(10, 1, 73, 78, 0),
(10, 1, 82, 28730, 0),
(10, 1, 84, 6603, 0),
(10, 1, 96, 6603, 0),
(10, 1, 108, 6603, 0);

-- Blood Elf Shaman (10, 7)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(10, 7, 0, 6603, 0),
(10, 7, 1, 403, 0),
(10, 7, 2, 331, 0),
(10, 7, 3, 28730, 0);

-- Blood Elf Druid (10, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(10, 11, 0, 5176, 0),
(10, 11, 1, 5185, 0),
(10, 11, 11, 28730, 0);

-- Draenei Rogue (11, 4)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(11, 4, 0, 6603, 0),
(11, 4, 1, 1752, 0),
(11, 4, 2, 2098, 0),
(11, 4, 3, 2764, 0),
(11, 4, 11, 28880, 0);

-- Draenei Warlock (11, 9)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(11, 9, 0, 686, 0),
(11, 9, 1, 687, 0),
(11, 9, 11, 28880, 0);

-- Draenei Druid (11, 11)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(11, 11, 0, 5176, 0),
(11, 11, 1, 5185, 0),
(11, 11, 11, 28880, 0);

-- ===================================================================
-- PLAYERCREATEINFO_ITEM - Starting items for new race/class combos
-- ===================================================================

-- Human Hunter (1, 3)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(1, 3, 129, 1),
(1, 3, 147, 1),
(1, 3, 148, 1),
(1, 3, 2508, 1),
(1, 3, 2102, 1),
(1, 3, 2516, 200),
(1, 3, 12282, 1),
(1, 3, 6948, 1);

-- Human Shaman (1, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(1, 7, 153, 1),
(1, 7, 154, 1),
(1, 7, 36, 1),
(1, 7, 2362, 1),
(1, 7, 6948, 1);

-- Human Druid (1, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(1, 11, 6123, 1),
(1, 11, 6124, 1),
(1, 11, 3661, 1),
(1, 11, 6948, 1);

-- Orc Paladin (2, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(2, 2, 43, 1),
(2, 2, 44, 1),
(2, 2, 45, 1),
(2, 2, 2361, 1),
(2, 2, 6948, 1);

-- Orc Priest (2, 5)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(2, 5, 51, 1),
(2, 5, 52, 1),
(2, 5, 53, 1),
(2, 5, 6144, 1),
(2, 5, 35, 1),
(2, 5, 6948, 1);

-- Orc Mage (2, 8)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(2, 8, 55, 1),
(2, 8, 6096, 1),
(2, 8, 1395, 1),
(2, 8, 6140, 1),
(2, 8, 35, 1),
(2, 8, 6948, 1);

-- Orc Druid (2, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(2, 11, 6139, 1),
(2, 11, 6124, 1),
(2, 11, 35, 1),
(2, 11, 6948, 1);

-- Dwarf Shaman (3, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(3, 7, 153, 1),
(3, 7, 154, 1),
(3, 7, 36, 1),
(3, 7, 2362, 1),
(3, 7, 6948, 1);

-- Dwarf Mage (3, 8)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(3, 8, 55, 1),
(3, 8, 6096, 1),
(3, 8, 1395, 1),
(3, 8, 6140, 1),
(3, 8, 35, 1),
(3, 8, 6948, 1);

-- Dwarf Warlock (3, 9)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(3, 9, 57, 1),
(3, 9, 59, 1),
(3, 9, 1396, 1),
(3, 9, 6097, 1),
(3, 9, 35, 1),
(3, 9, 6948, 1);

-- Dwarf Druid (3, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(3, 11, 6139, 1),
(3, 11, 6124, 1),
(3, 11, 3661, 1),
(3, 11, 6948, 1);

-- Night Elf Paladin (4, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(4, 2, 43, 1),
(4, 2, 44, 1),
(4, 2, 45, 1),
(4, 2, 2361, 1),
(4, 2, 6948, 1);

-- Night Elf Shaman (4, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(4, 7, 153, 1),
(4, 7, 154, 1),
(4, 7, 36, 1),
(4, 7, 2362, 1),
(4, 7, 6948, 1);

-- Night Elf Mage (4, 8)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(4, 8, 55, 1),
(4, 8, 6096, 1),
(4, 8, 1395, 1),
(4, 8, 56, 1),
(4, 8, 35, 1),
(4, 8, 6948, 1);

-- Night Elf Warlock (4, 9)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(4, 9, 57, 1),
(4, 9, 59, 1),
(4, 9, 1396, 1),
(4, 9, 6097, 1),
(4, 9, 35, 1),
(4, 9, 6948, 1);

-- Undead Paladin (5, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(5, 2, 43, 1),
(5, 2, 44, 1),
(5, 2, 45, 1),
(5, 2, 2361, 1),
(5, 2, 6948, 1);

-- Undead Hunter (5, 3)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(5, 3, 129, 1),
(5, 3, 147, 1),
(5, 3, 148, 1),
(5, 3, 2508, 1),
(5, 3, 2102, 1),
(5, 3, 2516, 200),
(5, 3, 12282, 1),
(5, 3, 6948, 1);

-- Undead Shaman (5, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(5, 7, 153, 1),
(5, 7, 154, 1),
(5, 7, 36, 1),
(5, 7, 2362, 1),
(5, 7, 6948, 1);

-- Undead Druid (5, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(5, 11, 6139, 1),
(5, 11, 6124, 1),
(5, 11, 35, 1),
(5, 11, 6948, 1);

-- Tauren Paladin (6, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(6, 2, 43, 1),
(6, 2, 44, 1),
(6, 2, 45, 1),
(6, 2, 23346, 1),
(6, 2, 6948, 1);

-- Tauren Rogue (6, 4)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(6, 4, 120, 1),
(6, 4, 121, 1),
(6, 4, 2105, 1),
(6, 4, 2092, 1),
(6, 4, 50055, 1),
(6, 4, 28979, 1),
(6, 4, 6948, 1);

-- Tauren Priest (6, 5)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(6, 5, 51, 1),
(6, 5, 52, 1),
(6, 5, 53, 1),
(6, 5, 6144, 1),
(6, 5, 35, 1),
(6, 5, 6948, 1);

-- Tauren Mage (6, 8)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(6, 8, 55, 1),
(6, 8, 6096, 1),
(6, 8, 1395, 1),
(6, 8, 6140, 1),
(6, 8, 35, 1),
(6, 8, 6948, 1);

-- Tauren Warlock (6, 9)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(6, 9, 6129, 1),
(6, 9, 59, 1),
(6, 9, 1396, 1),
(6, 9, 6097, 1),
(6, 9, 35, 1),
(6, 9, 6948, 1);

-- Gnome Paladin (7, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(7, 2, 43, 1),
(7, 2, 44, 1),
(7, 2, 45, 1),
(7, 2, 2361, 1),
(7, 2, 6948, 1);

-- Gnome Hunter (7, 3)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(7, 3, 129, 1),
(7, 3, 147, 1),
(7, 3, 148, 1),
(7, 3, 2508, 1),
(7, 3, 2102, 1),
(7, 3, 2516, 200),
(7, 3, 12282, 1),
(7, 3, 6948, 1);

-- Gnome Priest (7, 5)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(7, 5, 51, 1),
(7, 5, 52, 1),
(7, 5, 53, 1),
(7, 5, 6098, 1),
(7, 5, 35, 1),
(7, 5, 6948, 1);

-- Gnome Shaman (7, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(7, 7, 153, 1),
(7, 7, 154, 1),
(7, 7, 36, 1),
(7, 7, 2362, 1),
(7, 7, 6948, 1);

-- Gnome Druid (7, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(7, 11, 6139, 1),
(7, 11, 6124, 1),
(7, 11, 3661, 1),
(7, 11, 6948, 1);

-- Troll Paladin (8, 2)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(8, 2, 43, 1),
(8, 2, 44, 1),
(8, 2, 45, 1),
(8, 2, 2361, 1),
(8, 2, 6948, 1);

-- Troll Warlock (8, 9)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(8, 9, 6129, 1),
(8, 9, 59, 1),
(8, 9, 1396, 1),
(8, 9, 6097, 1),
(8, 9, 35, 1),
(8, 9, 6948, 1);

-- Troll Druid (8, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(8, 11, 6139, 1),
(8, 11, 6124, 1),
(8, 11, 35, 1),
(8, 11, 6948, 1);

-- Blood Elf Warrior (10, 1)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(10, 1, 20915, 1),
(10, 1, 20918, 1),
(10, 1, 20919, 1),
(10, 1, 23346, 1),
(10, 1, 6948, 1);

-- Blood Elf Shaman (10, 7)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(10, 7, 153, 1),
(10, 7, 154, 1),
(10, 7, 36, 1),
(10, 7, 2362, 1),
(10, 7, 6948, 1);

-- Blood Elf Druid (10, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(10, 11, 6123, 1),
(10, 11, 6124, 1),
(10, 11, 3661, 1),
(10, 11, 6948, 1);

-- Draenei Rogue (11, 4)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(11, 4, 120, 1),
(11, 4, 121, 1),
(11, 4, 2105, 1),
(11, 4, 2092, 1),
(11, 4, 50055, 1),
(11, 4, 28979, 1),
(11, 4, 6948, 1);

-- Draenei Warlock (11, 9)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(11, 9, 6129, 1),
(11, 9, 59, 1),
(11, 9, 1396, 1),
(11, 9, 6097, 1),
(11, 9, 35, 1),
(11, 9, 6948, 1);

-- Draenei Druid (11, 11)
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`) VALUES
(11, 11, 6123, 1),
(11, 11, 6124, 1),
(11, 11, 3661, 1),
(11, 11, 6948, 1);

SET FOREIGN_KEY_CHECKS=1;

-- ===================================================================
-- NOTES:
-- ===================================================================
-- This SQL script adds the necessary database entries for ARAC (All Races All Classes).
-- 
-- IMPORTANT: This only enables the SERVER-SIDE functionality.
-- For the CLIENT to display these options in character creation, you need:
-- 1. A modified Patch-A.MPQ file with updated CharBaseInfo.dbc
--    that allows all race/class combinations
-- 2. Players must place this patch in their WoW client Data folder
--
-- Without the client-side patch, players won't see the new class options
-- when creating a character, even though the server would accept them.
-- ===================================================================
