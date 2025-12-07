/*
 * This file is part of the TrinityCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "tc_catch2.h"
#include "Player.h"

using namespace std::string_view_literals;

TEST_CASE("MarkUntranslatedWords", "[Player][Language]")
{
    SECTION("Empty text returns empty string")
    {
        REQUIRE(Player::MarkUntranslatedWords("", 0.5f).empty());
    }

    SECTION("Full comprehension returns original text unchanged")
    {
        REQUIRE(Player::MarkUntranslatedWords("Hello friend", 1.0f) == "Hello friend");
        REQUIRE(Player::MarkUntranslatedWords("Testing complete sentences.", 1.0f) == "Testing complete sentences.");
    }

    SECTION("Zero comprehension marks all words with brackets")
    {
        REQUIRE(Player::MarkUntranslatedWords("Hello friend", 0.0f) == "[Hello] [friend]");
        REQUIRE(Player::MarkUntranslatedWords("one", 0.0f) == "[one]");
    }

    SECTION("Punctuation is preserved outside brackets")
    {
        REQUIRE(Player::MarkUntranslatedWords("Hello, world!", 0.0f) == "[Hello], [world]!");
        REQUIRE(Player::MarkUntranslatedWords("What? Yes.", 0.0f) == "[What]? [Yes].");
    }

    SECTION("Multiple spaces are preserved")
    {
        REQUIRE(Player::MarkUntranslatedWords("Hello   world", 0.0f) == "[Hello]   [world]");
    }

    SECTION("Numbers are treated as non-word characters")
    {
        REQUIRE(Player::MarkUntranslatedWords("Hello123world", 0.0f) == "[Hello]123[world]");
        REQUIRE(Player::MarkUntranslatedWords("test42test", 0.0f) == "[test]42[test]");
    }

    SECTION("Partial comprehension creates mixed results")
    {
        // With partial comprehension, some words should be bracketed, others not
        // The exact result depends on the deterministic threshold calculation
        std::string result = Player::MarkUntranslatedWords("Hello friend, how are you today?", 0.3f);
        
        // Result should contain brackets (some words are unintelligible)
        REQUIRE(result.find('[') != std::string::npos);
        REQUIRE(result.find(']') != std::string::npos);
        
        // Punctuation should be preserved
        REQUIRE(result.find(", ") != std::string::npos);
        REQUIRE(result.find("?") != std::string::npos);
    }

    SECTION("Comprehension above 1.0 treated same as 1.0")
    {
        // Comprehension >= 1.0 should return original text
        REQUIRE(Player::MarkUntranslatedWords("Hello friend", 1.5f) == "Hello friend");
        REQUIRE(Player::MarkUntranslatedWords("Hello friend", 2.0f) == "Hello friend");
    }

    SECTION("Negative comprehension marks all words")
    {
        // Negative comprehension should be treated as 0 (all words unintelligible)
        REQUIRE(Player::MarkUntranslatedWords("Hello friend", -0.5f) == "[Hello] [friend]");
    }

    SECTION("Single character words")
    {
        REQUIRE(Player::MarkUntranslatedWords("I", 0.0f) == "[I]");
        REQUIRE(Player::MarkUntranslatedWords("a b c", 0.0f) == "[a] [b] [c]");
    }

    SECTION("Text with only non-word characters")
    {
        REQUIRE(Player::MarkUntranslatedWords("123 456", 0.5f) == "123 456");
        REQUIRE(Player::MarkUntranslatedWords("!@#$%", 0.5f) == "!@#$%");
    }

    SECTION("Words with apostrophes are treated as single words")
    {
        // Contractions should be treated as a single word
        REQUIRE(Player::MarkUntranslatedWords("doesn't", 0.0f) == "[doesn't]");
        REQUIRE(Player::MarkUntranslatedWords("I don't know", 0.0f) == "[I] [don't] [know]");
        REQUIRE(Player::MarkUntranslatedWords("It's working", 0.0f) == "[It's] [working]");
        REQUIRE(Player::MarkUntranslatedWords("can't won't shouldn't", 0.0f) == "[can't] [won't] [shouldn't]");
        
        // Possessives should also be treated as single words
        REQUIRE(Player::MarkUntranslatedWords("John's hat", 0.0f) == "[John's] [hat]");
        
        // Multiple apostrophes in different words
        REQUIRE(Player::MarkUntranslatedWords("I'm sure it's fine", 0.0f) == "[I'm] [sure] [it's] [fine]");
        
        // Apostrophe with punctuation
        REQUIRE(Player::MarkUntranslatedWords("That's great!", 0.0f) == "[That's] [great]!");
    }
}
