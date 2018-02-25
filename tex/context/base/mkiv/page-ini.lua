if not modules then modules = { } end modules ['page-ini'] = {
    version   = 1.001,
    comment   = "companion to page-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, rawget, type, next = tonumber, rawget, type, next
local match = string.match
local sort, tohash, insert, remove = table.sort, table.tohash, table.insert, table.remove
local settings_to_array, settings_to_hash = utilities.parsers.settings_to_array, utilities.parsers.settings_to_hash

local texgetcount  = tex.getcount

local context      = context
local ctx_testcase = commands.testcase

local data         = table.setmetatableindex("table")
local last         = 0
local pages        = structures.pages
local autolist     = { }
local report       = logs.reporter("pages","mark")

local trace        = false  trackers.register("pages.mark",function(v) trace = v end)

function pages.mark(name,list)
    local realpage = texgetcount("realpageno")
    if not list or list == "" then
        if trace then
            report("marking current page %i as %a",realpage,name)
        end
        data[realpage][name] = true
        return
    end
    if type(list) == "string" then
        list = settings_to_array(list)
    end
    if type(list) == "table" then
        for i=1,#list do
            local page = list[i]
            local sign = false
            if type(page) == "string" then
                sign, page = match(page,"([%+%-])(%d+)")
            end
            page = tonumber(page)
            if page then
                if sign == "+" then
                    page = realpage + page
                end
                if sign == "-" then
                    report("negative page numbers are not supported")
                else
                    if trace then
                        report("marking page %i as %a",page,name)
                    end
                    data[page][name] = true
                end
            end
        end
    else
        if trace then
            report("marking current page %i as %a",realpage,name)
        end
        data[realpage][name] = true
    end
end

function pages.marked(name)
    local realpage = texgetcount("realpageno")
    for i=last,realpage-1 do
        data[i] = nil
    end
    local pagedata = rawget(data,realpage)
    return pagedata and pagedata[name]
end

local function toranges(marked)
    local list = { }
    local size = #marked
    if size > 0 then
        local first = marked[1]
        local last  = first
        for i=2,size do
            local page = marked[i]
            if page > last + 1 then
                list[#list+1] = { first, last }
                first = page
            end
            last = page
        end
        list[#list+1] = { first, last }
    end
    return list
end

pages.toranges = toranges

local function allmarked(list)
    if list then
        local collected = pages.collected
        if collected then
            if type(list) == "string" then
                list = settings_to_hash(list)
            elseif type(list) == "table" and #list > 0 then
                list = tohash(list)
            end
            if type(list) == "table" then
                local found = { }
                for name in next, list do
                    for page, list in next, data do
                        if list[name] and collected[page] then
                            found[#found+1] = page
                        end
                    end
                end
                if #found > 0 then
                    sort(found)
                    if trace then
                        local ranges = toranges(found)
                        for i=1,#ranges do
                            local range = ranges[i]
                            local first = range[1]
                            local last  = range[2]
                            if first == last then
                                report("marked page : %i",first)
                            else
                                report("marked range: %i upto %i",first,last)
                            end
                        end
                    end
                    return found
                end
            end
        end
    end
end

pages.allmarked = allmarked

-- An alternative is to use an attribute and identify the state by parsing the node
-- list but that's a bit overkill for a hardly used feature like this.

luatex.registerpageactions(function()
    local nofauto = #autolist
    if nofauto > 0 then
        local realpage = texgetcount("realpageno")
        for i=1,nofauto do
            local names = autolist[i]
            for j=1,#names do
                local name = names[j]
                data[realpage][name] = true
                if trace then
                    report("automatically marking page %i as %a",realpage,name)
                end
            end
        end
    end
end)

interfaces.implement {
    name      = "markpage",
    arguments = { "string", "string" },
    actions   = pages.mark
}

interfaces.implement {
    name      = "doifelsemarkedpage",
    arguments = "string",
    actions   = { marked, ctx_testcase }
}

interfaces.implement {
    name      = "markedpages",
    arguments = "string",
    actions   = function(name)
        local t = allmarked(name)
        if t then
            context("%,t",t)
        end
    end
}

interfaces.implement {
    name      = "startmarkpages",
    arguments = "string",
    actions   = function(name)
        insert(autolist,settings_to_array(name))
    end
}

interfaces.implement {
    name      = "stopmarkpages",
    arguments = "string",
    actions   = function(name)
        if #autolist > 0 then
            remove(autolist)
        end
    end
}
