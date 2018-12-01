if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- -- how to create a shortcut:
--
-- local function something(...)
--     something = backends.codeinjections.something
--     return something(...)
-- end

local next, type = next, type
local format = string.format

backends                = backends or { }
local backends          = backends

local trace_backend     = false  trackers.register("backend.initializers", function(v) trace_finalizers = v end)
local report_backend    = logs.reporter("backend","initializing")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local setaction         = nodes.tasks.setaction

local function nothing() return nil end

backends.nothing = nothing

local nodeinjections = { }
local codeinjections = { }
local registrations  = { }
local tables         = allocate()

local function donothing(t,k)
    t[k] = nothing
    return nothing
end

setmetatableindex(nodeinjections, donothing)
setmetatableindex(codeinjections, donothing)
setmetatableindex(registrations,  donothing)

local defaults = {
    nodeinjections = nodeinjections,
    codeinjections = codeinjections,
    registrations  = registrations,
    tables         = tables,
}

backends.defaults = defaults

backends.nodeinjections = { }  setmetatableindex(backends.nodeinjections, nodeinjections)
backends.codeinjections = { }  setmetatableindex(backends.codeinjections, codeinjections)
backends.registrations  = { }  setmetatableindex(backends.registrations,  registrations)
backends.tables         = { }  setmetatableindex(backends.tables,         tables)

backends.current = "unknown"

function backends.install(what)
    if type(what) == "string" then
        local backend = backends[what]
        if backend then
            if trace_backend then
                if backend.comment then
                    report_backend("initializing backend %a, %a",what,backend.comment)
                else
                    report_backend("initializing backend %a",what)
                end
            end
            backends.current = what
            for category, default in next, defaults do
                local target = backends[category]
                local plugin = backend [category]
                setmetatableindex(plugin, default)
                setmetatableindex(target, plugin)
            end
        elseif trace_backend then
            report_backend("no backend named %a",what)
        end
    end
end

statistics.register("used backend", function()
    local bc = backends.current
    if bc ~= "unknown" then
        local lmtx = environment.lmtxmode and drivers and drivers.lmtxversion
        local cmnt = backends[bc].comment or "no comment"
        if lmtx then
            return format("lmtx version %0.2f, %s (%s)",lmtx,bc,cmnt)
        else
            return format("%s (%s)",bc,cmnt)
        end
    else
        return nil
    end
end)

local comment = { "comment", "" }

tables.vfspecials = allocate {
    red        = comment,
    green      = comment,
    blue       = comment,
    black      = comment,
    startslant = comment,
    stopslant  = comment,
}

-- can best be here

interfaces.implement {
    name      = "setrealspaces",
    arguments = "string",
    actions   = function(v)
        setaction("shipouts","nodes.handlers.accessibility",v == interfaces.variables.yes)
    end
}

-- moved to here

local included = table.setmetatableindex( {
    context  = true,
    id       = true,
    metadata = true,
    date     = true,
    id       = true,
    pdf      = true,
}, function(t,k)
    return true
end)

backends.included = included

function backends.timestamp()
    return os.date("%Y-%m-%dT%X") .. os.timezone(true)
end
