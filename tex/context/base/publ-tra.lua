if not modules then modules = { } end modules ['publ-tra'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

local sortedhash, sortedkeys = table.sortedhash, table.sortedkeys
local settings_to_array = utilities.parsers.settings_to_array
local formatters = string.formatters

local tracers        = publications.tracers or { }
local datasets       = publications.datasets
local specifications = publications.specifications

local context = context

local ctx_NC, ctx_NR, ctx_HL, ctx_FL, ctx_ML, ctx_LL = context.NC, context.NR, context.HL, context.FL, context.ML, context.LL
local ctx_bold, ctx_monobold, ctx_rotate, ctx_llap = context.bold, context.formatted.monobold, context.rotate, context.llap
local ctx_starttabulate, ctx_stoptabulate = context.starttabulate, context.stoptabulate

local privates = publications.tables.privates
local specials = publications.tables.specials

function tracers.showdatasetfields(settings)
    local dataset = settings.dataset
    local current = datasets[dataset]
    local luadata = current.luadata
    if next(luadata) then
        local kind       = settings.kind
        local fielddata  = kind and specifications[kind] or specifications.apa
        local categories = fielddata.categories
        local fieldspecs = fielddata.fields
        ctx_starttabulate { "|lT|lT|pT|" }
            ctx_NC() ctx_bold("tag")
            ctx_NC() ctx_bold("category")
            ctx_NC() ctx_bold("fields")
            ctx_NC() ctx_NR()
            ctx_FL()
            for k, v in sortedhash(luadata) do
                local category = v.category
                local fields   = fieldspecs[category] or { }
                ctx_NC() context(k)
                ctx_NC() context(category)
                ctx_NC() -- grouping around colors needed
                for k, v in sortedhash(v) do
                    if privates[k] then
                        -- skip
                    elseif specials[k] then
                        context("{\\darkblue %s} ",k)
                    else
                        local f = fields[k]
                        if f == "required" then
                            context("{\\darkgreen %s} ",k)
                        elseif f == "optional" then
                            context("{\\darkyellow %s} ",k)
                        else
                            context("%s ",k)
                        end
                    end
                end
                ctx_NC() ctx_NR()
            end
        ctx_stoptabulate()
    end
end

function tracers.showdatasetcompleteness(settings)
    local dataset    = settings.dataset
    local current    = datasets[dataset]
    local luadata    = current.luadata
    local kind       = settings.kind
    local fielddata  = kind and specifications[kind] or specifications.apa
    local categories = fielddata.categories
    local fieldspecs = fielddata.fields
    local lpegmatch  = lpeg.match
    local texescape  = lpeg.patterns.texescape

    local preamble = { "|lTBw(5em)|lBTp(10em)|p|" }

    local function identified(tag,category,crossref)
        ctx_NC()
        ctx_NC() ctx_monobold(category)
        ctx_NC() if crossref then
                ctx_monobold("%s\\hfill\\darkblue => %s",tag,crossref)
             else
                ctx_monobold(tag)
             end
        ctx_NC() ctx_NR()
    end

    local function required(done,foundfields,key,value,indirect)
        ctx_NC() if not done then context("required") end
        ctx_NC() context(key)
        ctx_NC()
            if indirect then
                if value then
                    context("\\darkblue %s",lpegmatch(texescape,value))
                else
                    context("\\darkred\\tttf [missing crossref]")
                end
            elseif value then
                context(lpegmatch(texescape,value))
            else
                context("\\darkred\\tttf [missing value]")
            end
        ctx_NC() ctx_NR()
        foundfields[key] = nil
        return done or true
    end

    local function optional(done,foundfields,key,value,indirect)
        ctx_NC() if not done then context("optional") end
        ctx_NC() context(key)
        ctx_NC()
            if indirect then
                context("\\darkblue %s",lpegmatch(texescape,value))
            elseif value then
                context(lpegmatch(texescape,value))
            end
        ctx_NC() ctx_NR()
        foundfields[key] = nil
        return done or true
    end

    local function special(done,key,value)
        ctx_NC() if not done then context("special") end
        ctx_NC() context(key)
        ctx_NC() context(lpegmatch(texescape,value))
        ctx_NC() ctx_NR()
        return done or true
    end

    local function extra(done,key,value)
        ctx_NC() if not done then context("extra") end
        ctx_NC() context(key)
        ctx_NC() context(lpegmatch(texescape,value))
        ctx_NC() ctx_NR()
        return done or true
    end

    if next(luadata) then
        for tag, entry in sortedhash(luadata) do
            local category    = entry.category
            local fields      = categories[category]
            local foundfields = { }
            for k, v in next, entry do
                foundfields[k] = true
            end
            ctx_starttabulate(preamble)
            identified(tag,category,entry.crossref)
            ctx_FL()
            if fields then
                local requiredfields = fields.required
                local sets = fields.sets or { }
                local done = false
                if requiredfields then
                    for i=1,#requiredfields do
                        local r = requiredfields[i]
                        local r = sets[r] or r
                        if type(r) == "table" then
                            -- this has to be done differently now
                            local okay = false
                            for i=1,#r do
                                local ri = r[i]
                                if rawget(entry,ri) then
                                    done = required(done,foundfields,ri,entry[ri])
                                    okay = true
                                elseif entry[ri] then
                                    done = required(done,foundfields,ri,entry[ri],true)
                                    okay = true
                                end
                            end
                            if not okay then
                                done = required(done,foundfields,table.concat(r," {\\letterbar} "))
                            end
                        elseif rawget(entry,r) then
                            done = required(done,foundfields,r,entry[r])
                        elseif entry[r] then
                            done = required(done,foundfields,r,entry[r],true)
                        else
                            done = required(done,foundfields,r)
                        end
                    end
                end
                local optionalfields = fields.optional
                local done = false
                if optionalfields then
                    for i=1,#optionalfields do
                        local o = optionalfields[i]
                        local o = sets[o] or o
                        if type(o) == "table" then
                            -- this has to be done differently now
                            for i=1,#o do
                                local oi = o[i]
                                if rawget(entry,oi) then
                                    done = optional(done,foundfields,oi,entry[oi])
                                elseif entry[oi] then
                                    done = optional(done,foundfields,oi,entry[oi],true)
                                end
                            end
                        elseif rawget(entry,o) then
                            done = optional(done,foundfields,o,entry[o])
                        elseif entry[o] then
                            done = optional(done,foundfields,o,entry[o],true)
                        end
                    end
                end
            end
            local done = false
            for k, v in sortedhash(foundfields) do
                if privates[k] then
                    -- skip
                elseif specials[k] then
                    done = special(done,k,entry[k])
                end
            end
            local done = false
            for k, v in sortedhash(foundfields) do
                if privates[k] then
                    -- skip
                elseif not specials[k] then
                    done = extra(done,k,entry[k])
                end
            end
            ctx_stoptabulate()
        end
    end

end

function tracers.showfields(settings)
    local rotation    = settings.rotation
    local kind        = settings.kind
    local fielddata   = kind and specifications[kind] or specifications.apa
    local categories  = fielddata.categories
    local fieldspecs  = fielddata.fields
    local validfields = { }
    local function makevalid(list,sets)
        for i=1,#list do
            local li = list[i]
            if sets and sets[li] then
                -- ignore
            elseif type(li) == "table" then
                for i=1,#li do
                    validfields[li[i]] = true
                end
            else
                validfields[li] = true
            end
        end
    end
    for category, fields in next, categories do
        local sets = fields.sets
        for name, list in next, fields do
            if list == sets then
                for k, v in next, list do
                    makevalid(v,sets)
                end
            else
                makevalid(list,sets)
            end
        end
    end
    local s_categories = sortedkeys(categories)
    local s_fields     = sortedkeys(validfields)
    ctx_starttabulate { "|l" .. string.rep("|c",#s_categories) .. "|" }
    ctx_FL()
    ctx_NC()
    if rotation then
        rotation = { rotation = rotation }
    end
    for i=1,#s_categories do
        ctx_NC()
        local txt = formatters["\\bf %s"](s_categories[i])
        if rotation then
            ctx_rotate(rotation,txt)
        else
            context(txt)
        end
    end
    ctx_NC() ctx_NR()
    ctx_FL()
    for i=1,#s_fields do
        local field  = s_fields[i]
        ctx_NC()
        ctx_bold(field)
        for j=1,#s_categories do
            ctx_NC()
            local kind = fieldspecs[s_categories[j]][field]
            if kind == "required" then
                context("\\darkgreen*")
            elseif kind == "optional" then
                context("*")
            end
        end
        ctx_NC() ctx_NR()
    end
    ctx_LL()
    ctx_stoptabulate()
end

commands.showbtxdatasetfields       = tracers.showdatasetfields
commands.showbtxdatasetcompleteness = tracers.showdatasetcompleteness
commands.showbtxfields              = tracers.showfields
