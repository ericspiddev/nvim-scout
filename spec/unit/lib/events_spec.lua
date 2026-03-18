local events = require('nvim-scout.lib.events')
local stub = require('luassert.stub')
local utils = require('spec.spec_utils')
local log_levels = require('nvim-scout.lib.scout_logger').LOG_LEVELS
utils:register_global_logger()
utils:register_global_consts()

function create_event(valid_events)
    return events:new(valid_events)
end

function create_event_for_buf_attach(valid_events, buf_is_valid, add_events, attach_succeeds)
    stub(vim.api, "nvim_buf_is_valid").returns(buf_is_valid)
    stub(vim.api, "nvim_buf_attach").returns(attach_succeeds)
    local test_events = create_event(valid_events)
    local tab = {
        event_handler = function() return true end
    }
    if add_events then
        test_events:add_event("valid_event", tab, "event_handler")
    end
    return test_events
end
describe('events', function()

    before_each(function()
        utils:mock_logger_prints()
    end)

    after_each(function()
        utils:revert_logger_prints()
    end)

    it('add constructor events to valid table on creation', function ()
        local fake_valid_events = {"event1", "event2", "event3"}
        local test_events = create_event(fake_valid_events)

        assert(utils:table_contains(test_events.valid_events, "event1"))
        assert(utils:table_contains(test_events.valid_events, "event2"))
        assert(utils:table_contains(test_events.valid_events, "event3"))
        assert(not utils:table_contains(test_events.valid_events, "event4"))
        assert(not utils:table_contains(test_events.valid_events, "e2"))
    end)

    it('identifies valid and invalid events', function()

        local test_events = create_event() -- nil valid_events table
        assert(not test_events:is_valid_event("on_lines"))
        utils:scout_print_was_called(log_levels.ERROR, "Nil valid events table no events will be allowed")
        assert(not test_events:is_valid_event("test"))
        utils:scout_print_was_called(log_levels.ERROR, "Nil valid events table no events will be allowed")
        assert(not test_events:is_valid_event("nonreal_event"))
        utils:scout_print_was_called(log_levels.ERROR, "Nil valid events table no events will be allowed")

        test_events = create_event({}) -- empty valid events table
        assert(not test_events:is_valid_event("on_lines"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "on_lines")
        assert(not test_events:is_valid_event(""))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "")
        assert(not test_events:is_valid_event())

        local fake_valid_events = {"on_lines", "test", "nonreal_event", "some_change_occurred"}
        test_events = create_event(fake_valid_events)

        assert(test_events:is_valid_event("on_lines"))
        assert(test_events:is_valid_event("test"))
        assert(test_events:is_valid_event("nonreal_event"))
        assert(test_events:is_valid_event("some_change_occurred"))

        assert(not test_events:is_valid_event("s0me_change_occurred"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "s0me_change_occurred")
        assert(not test_events:is_valid_event("te3st"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "te3st")
        assert(not test_events:is_valid_event("idk"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "idk")
        assert(not test_events:is_valid_event(""))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", "")
        assert(not test_events:is_valid_event(nil))
        assert(not test_events:is_valid_event(20))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event ", 20)
        assert(not test_events:is_valid_event())

    end)

    it('registers handlers for valid events and blocks it for invalid ones', function()

        local fake_valid_events = {"some_event", "another_event", "event"}
        local test_events = create_event(fake_valid_events)
        local tab = {
            event_handler = function () end,
        }
        assert(not test_events:add_event("not_event", tab, "event_handler"))
        assert(test_events.event_table['not_event'] == nil)
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event supported events are ", fake_valid_events)
        assert(not test_events:add_event("fake_event", tab, "event_handler"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event supported events are ", fake_valid_events)
        assert(test_events.event_table['fake_event'] == nil)
        assert(not test_events:add_event("no_event", tab, "event_handler"))
        utils:scout_print_was_called(log_levels.ERROR, "Unsupported event supported events are ", fake_valid_events)
        assert(not test_events:add_event("fake_event", tab, "event_handler"))
        assert(test_events.event_table['no_event'] == nil)
        assert(not test_events:add_event("ano0ther_event", tab, "event_handler"))
        assert(test_events.event_table['ano0ther_event'] == nil)

        assert(test_events:add_event("some_event", tab, "event_handler"))
        assert(test_events.event_table['some_event'] ~= nil)

        assert(test_events:add_event("another_event", tab, "event_handler"))
        assert(test_events.event_table['another_event'] ~= nil)

        assert(test_events:add_event("event", tab, "event_handler"))
        assert(test_events.event_table['event'] ~= nil)
    end)

    it('does not register nil handlers', function()
        local fake_valid_events = {"valid_event"}
        local test_events = create_event(fake_valid_events)
        local tab = {}
        assert(not test_events:add_event("valid_event", tab, nil))
        assert(test_events.event_table['valid_event'] == nil)
        utils:scout_print_was_called(log_levels.ERROR, "Nil event handler for event ", "valid_event")
    end)

    it('does not register on a nil instance', function()
        local fake_valid_events = {"valid_event"}
        local test_events = create_event(fake_valid_events)
        local tab = nil

        assert(not test_events:add_event("valid_event", tab, "event_handler"))
        assert(test_events.event_table['valid_event'] == nil)
        utils:scout_print_was_called(log_levels.ERROR, "Nil object instance")
    end)

    it('handles an invalid buffer when attaching events', function()
        local fake_valid_events = {"valid_event"}
        local fake_buffer = 10
        local INVALID_BUF = false
        local ADD_EVENTS = true
        local ATTACHES = true
        local test_events = create_event_for_buf_attach(fake_valid_events, INVALID_BUF, ADD_EVENTS, ATTACHES)
        assert(not test_events:attach_buffer_events(fake_buffer))
        utils:scout_print_was_called(log_levels.ERROR, "Cannot attach to invalid nvim buffer ", fake_buffer)
    end)

    it('handles an empty event_table when attaching events', function()
        local fake_valid_events = {"valid_event"}
        local fake_buffer = 10
        local VALID_BUF = true
        local NO_EVENTS = false
        local ATTACHES = true
        local test_events = create_event_for_buf_attach(fake_valid_events, VALID_BUF, NO_EVENTS, ATTACHES)

        assert(not test_events:attach_buffer_events(fake_buffer))
        utils:scout_print_was_called(log_levels.ERROR, "Failed to attach buffer events empty or nil event table!")

        fake_valid_events = {}
        local EVENTS = true
        test_events = create_event_for_buf_attach(fake_valid_events, VALID_BUF, EVENTS, ATTACHES)
        assert(not test_events:attach_buffer_events(fake_buffer))
        utils:scout_print_was_called(log_levels.ERROR, "Failed to attach buffer events empty or nil event table!")

    end)

    it('handles a failed event attach on a buffer', function()
        local fake_valid_events = {"valid_event"}
        local fake_buffer = 10
        local VALID_BUF = true
        local EVENTS = true
        local DOES_ATTACH = false
        local test_events = create_event_for_buf_attach(fake_valid_events, VALID_BUF, EVENTS, DOES_ATTACH)

        assert(not test_events:attach_buffer_events(fake_buffer))
        utils:scout_print_was_called(log_levels.ERROR, "Failed to attach events to buffer ", fake_buffer)
    end)

    it('can attach events to a buffer', function()
        local fake_valid_events = {"valid_event"}
        local fake_buffer = 10
        local VALID_BUF = true
        local EVENTS = true
        local ATTACHES = true
        local test_events = create_event_for_buf_attach(fake_valid_events, VALID_BUF, EVENTS, ATTACHES)

        assert(test_events:attach_buffer_events(fake_buffer))
        utils:scout_print_was_called(log_levels.INFO, "Successfully attached buffer events")
    end)

end)
