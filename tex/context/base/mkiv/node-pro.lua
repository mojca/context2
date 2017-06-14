if not modules then modules = { } end modules ['node-pro'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_callbacks  = false  trackers  .register("nodes.callbacks",        function(v) trace_callbacks  = v end)
local force_processors = false  directives.register("nodes.processors.force", function(v) force_processors = v end)

local report_nodes = logs.reporter("nodes","processors")

local nodes        = nodes
local tasks        = nodes.tasks
local nuts         = nodes.nuts

nodes.processors   = nodes.processors or { }
local processors   = nodes.processors

-- vbox: grouptype: vbox vtop output split_off split_keep  | box_type: exactly|aditional
-- hbox: grouptype: hbox adjusted_hbox(=hbox_in_vmode)     | box_type: exactly|aditional

local actions = tasks.actions("processors")

do

    local tonut   = nuts.tonut
    local isglyph = nuts.isglyph
    local getnext = nuts.getnext

    local utfchar = utf.char
    local concat  = table.concat

    local n = 0

    local function reconstruct(head) -- we probably have a better one
        local t, n, h = { }, 0, tonut(head)
        while h do
            n = n + 1
            local char, id = isglyph(h)
            if char then -- todo: disc etc
                t[n] = utfchar(char)
            else
                t[n] = "[]"
            end
            h = getnext(h)
        end
        return concat(t)
    end

    function processors.tracer(what,state,head,groupcode,before,after,show)
        if not groupcode then
            groupcode = "unknown"
        elseif groupcode == "" then
            groupcode = "mvl"
        end
        n = n + 1
        if show then
            report_nodes("%s: location %a, state %a, group %a, # before %a, # after %s, stream: %s",what,n,state,groupcode,before,after,reconstruct(head))
        else
            report_nodes("%s: location %a, state %a, group %a, # before %a, # after %s",what,n,state,groupcode,before,after)
        end
    end

end

local tracer = processors.tracer

processors.enabled = true -- this will become a proper state (like trackers)

do

    local has_glyph   = nodes.has_glyph
    local count_nodes = nodes.countall

    function processors.pre_linebreak_filter(head,groupcode) -- ,size,packtype,direction
        local found = force_processors or has_glyph(head)
        if found then
            if trace_callbacks then
                local before = count_nodes(head,true)
                local head, done = actions(head,groupcode) -- ,size,packtype,direction
                local after = count_nodes(head,true)
                if done then
                    tracer("pre_linebreak","changed",head,groupcode,before,after,true)
                else
                    tracer("pre_linebreak","unchanged",head,groupcode,before,after,true)
                end
                return done and head or true
            else
                local head, done = actions(head,groupcode) -- ,size,packtype,direction
                return done and head or true
            end
        elseif trace_callbacks then
            local n = count_nodes(head,false)
            tracer("pre_linebreak","no chars",head,groupcode,n,n)
        end
        return true
    end

    local function hpack_filter(head,groupcode,size,packtype,direction,attributes)
        local found = force_processors or has_glyph(head)
        if found then
            if trace_callbacks then
                local before = count_nodes(head,true)
                local head, done = actions(head,groupcode,size,packtype,direction,attributes)
                local after = count_nodes(head,true)
                if done then
                    tracer("hpack","changed",head,groupcode,before,after,true)
                else
                    tracer("hpack","unchanged",head,groupcode,before,after,true)
                end
                return done and head or true
            else
                local head, done = actions(head,groupcode,size,packtype,direction,attributes)
                return done and head or true
            end
        elseif trace_callbacks then
            local n = count_nodes(head,false)
            tracer("hpack","no chars",head,groupcode,n,n)
        end
        return true
    end

    processors.hpack_filter = hpack_filter

    do

        local setfield = nodes.setfield
        local hpack    = nodes.hpack

        function nodes.fullhpack(head,...)
            local ok = hpack_filter(head)
            if not done or done == true then
                ok = head
            end
            local hp, b = hpack(ok,...)
            setfield(hp,"prev",nil)
            setfield(hp,"next",nil)
            return hp, b
        end

    end

    do

        local setboth = nuts.setboth
        local hpack   = nuts.hpack

        function nuts.fullhpack(head,...)
            local ok = hpack_filter(tonode(head))
            if not done or done == true then
                ok = head
            else
                ok = tonut(ok)
            end
            local hp, b = hpack(...)
            setboth(hp)
            return hp, b
        end

    end

    callbacks.register('pre_linebreak_filter', processors.pre_linebreak_filter, "all kind of horizontal manipulations (before par break)")
    callbacks.register('hpack_filter'        , processors.hpack_filter,         "all kind of horizontal manipulations (before hbox creation)")

end

do

    local actions     = tasks.actions("finalizers") -- head, where
    local count_nodes = nodes.countall

    -- beware, these are packaged boxes so no first_glyph test
    -- maybe some day a hash with valid groupcodes
    --
    -- beware, much can pass twice, for instance vadjust passes two times
    --
    -- something weird here .. group mvl when making a vbox

    function processors.post_linebreak_filter(head,groupcode)
        if trace_callbacks then
            local before = count_nodes(head,true)
            local head, done = actions(head,groupcode)
            local after = count_nodes(head,true)
            if done then
                tracer("post_linebreak","changed",head,groupcode,before,after,true)
            else
                tracer("post_linebreak","unchanged",head,groupcode,before,after,true)
            end
            return done and head or true
        else
            local head, done = actions(head,groupcode)
            return done and head or true
        end
    end

    callbacks.register('post_linebreak_filter', processors.post_linebreak_filter,"all kind of horizontal manipulations (after par break)")

end

do

    local texnest    = tex.nest

    local getlist    = nodes.getlist
    local setlist    = nodes.setlist
    local getsubtype = nodes.getsubtype

    local line_code  = nodes.listcodes.line

    local actions    = tasks.actions("contributers")

    function processors.contribute_filter(groupcode)
        if groupcode == "box" then -- "pre_box"
            local whatever = texnest[texnest.ptr]
            if whatever then
                local line = whatever.tail
                if line and getsubtype(line) == line_code then
                    local head = getlist(line)
                    if head then
                        local okay, done = actions(head,groupcode,line)
                        if okay and okay ~= head then
                            setlist(line,okay)
                        end
                    end
                end
            end
        end
    end

    callbacks.register('contribute_filter', processors.contribute_filter,"things done with lines")

end

statistics.register("h-node processing time", function()
    return statistics.elapsedseconds(nodes,"including kernel") -- hm, ok here?
end)
