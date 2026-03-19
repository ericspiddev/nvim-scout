local pattern_handler = require('nvim-scout.search.pattern_handler')
local consts = require('nvim-scout.utils.consts')

local escape_chars = consts.modes.escape_chars

describe('pattern_handler', function ()
    it('properly adds as % before escape characters', function ()
        local ph = pattern_handler:new(escape_chars)
        assert.equals(ph:escape_pattern_characters("()"), "%(%)")
        assert.equals(ph:escape_pattern_characters("(Eric)"), "%(Eric%)")
        assert.equals(ph:escape_pattern_characters(")t()string"), "%)t%(%)string")
        assert.equals(ph:escape_pattern_characters("[eric][test]()"), "[eric][test]%(%)")

        assert.equals(ph:escape_pattern_characters("ERIC SPIDLE"), "ERIC SPIDLE")
        assert.equals(ph:escape_pattern_characters("123&*^#$[]{}"), "123&*^#$[]{}")
    end)


    it('does not automatically escape characters when %b modifier is present', function ()
        local ph = pattern_handler:new({"(", ")", "^", "$"})
        assert.equals(ph:escape_pattern_characters("%b()"), "%b()")
        assert.equals(ph:escape_pattern_characters("()"), "%(%)")
        assert.equals(ph:escape_pattern_characters("%b^]"), "%b^]")
        assert.equals(ph:escape_pattern_characters("^test^"), "%^test%^")
        assert.equals(ph:escape_pattern_characters("%b$$"), "%b$$")
        assert.equals(ph:escape_pattern_characters("$$$$$$eric"), "%$%$%$%$%$%$eric")
    end)

    it('can handle multipled escape characters', function ()
        local ph = pattern_handler:new({"(", ")", "^", "$", "#", "{", "}", "*"})
        assert.equals(ph:escape_pattern_characters("123&*^#$[]{}"), "123&%*%^%#%$[]%{%}")
        assert.equals(ph:escape_pattern_characters("{Eric Spidle}"), "%{Eric Spidle%}")
        assert.equals(ph:escape_pattern_characters("Who knows how this goes ^%^"), "Who knows how this goes %^%%^") -- fix me?
    end)
end)
