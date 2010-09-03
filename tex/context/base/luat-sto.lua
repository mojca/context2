if not modules then modules = { } end modules ['luat-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, setmetatable, getmetatable = type, next, setmetatable, getmetatable
local gmatch, format, write_nl = string.gmatch, string.format, texio.write_nl

local report_storage = logs.new("storage")

storage            = storage or { }
local storage      = storage

local data         = { }
storage.data       = data

local evaluators   = { }
storage.evaluators = evaluators

storage.min        = 0 -- 500
storage.max        = storage.min - 1
storage.noftables  = storage.noftables or 0
storage.nofmodules = storage.nofmodules or 0

storage.mark       = utilities.storage.mark
storage.allocate   = utilities.storage.allocate
storage.marked     = utilities.storage.marked

function storage.register(...)
    local t = { ... }
    local d = t[2]
    if d then
        storage.mark(d)
    else
        report_storage("fatal error: invalid storage '%s'",t[1])
        os.exit()
    end
    data[#data+1] = t
    return t
end

-- evaluators .. messy .. to be redone

function storage.evaluate(name)
    evaluators[#evaluators+1] = name
end

local function finalize() -- we can prepend the string with "evaluate:"
    for i=1,#evaluators do
        local t = evaluators[i]
        for i, v in next, t do
            local tv = type(v)
            if tv == "string" then
                t[i] = loadstring(v)()
            elseif tv == "table" then
                for _, vv in next, v do
                    if type(vv) == "string" then
                        t[i] = loadstring(vv)()
                    end
                end
            elseif tv == "function" then
                t[i] = v()
            end
        end
    end
end

lua.registerfinalizer(finalize,"evaluate storage")

local function dump()
    for i=1,#data do
        local d = data[i]
        local message, original, target, evaluate = d[1], d[2] ,d[3] ,d[4]
        local name, initialize, finalize, code = nil, "", "", ""
        for str in gmatch(target,"([^%.]+)") do
            if name then
                name = name .. "." .. str
            else
                name = str
            end
            initialize = format("%s %s = %s or {} ", initialize, name, name)
        end
        if evaluate then
            finalize = "storage.evaluate(" .. name .. ")"
        end
        storage.max = storage.max + 1
        if trace_storage then
            report_storage('saving %s in slot %s',message,storage.max)
            code =
                initialize ..
                format("report_storage('restoring %s from slot %s') ",message,storage.max) ..
                table.serialize(original,name) ..
                finalize
        else
            code = initialize .. table.serialize(original,name) .. finalize
        end
        lua.bytecode[storage.max] = loadstring(code)
        collectgarbage("step")
    end
end

lua.registerfinalizer(dump,"dump storage")

-- we also need to count at generation time (nicer for message)

--~ if lua.bytecode then -- from 0 upwards
--~     local i, b = storage.min, lua.bytecode
--~     while b[i] do
--~         storage.noftables = i
--~         b[i]()
--~         b[i] = nil
--~         i = i + 1
--~     end
--~ end

statistics.register("stored bytecode data", function()
    local modules = (storage.nofmodules > 0 and storage.nofmodules) or (status.luabytecodes - lua.firstbytecode - 1)
    local dumps = (storage.noftables > 0 and storage.noftables) or storage.max-storage.min + 1
    return format("%s modules, %s tables, %s chunks",modules,dumps,modules+dumps)
end)

if lua.bytedata then
    storage.register("lua/bytedata",lua.bytedata,"lua.bytedata")
end

function statistics.reportstorage(whereto)
    whereto = whereto or "term and log"
    write_nl(whereto," ","stored tables:"," ")
    for k,v in table.sortedhash(storage.data) do
        write_nl(whereto,format("%03i %s",k,v[1]))
    end
    write_nl(whereto," ","stored modules:"," ")
    for k,v in table.sortedhash(lua.bytedata) do
        write_nl(whereto,format("%03i %s %s",k,v[2],v[1]))
    end
    write_nl(whereto," ","stored attributes:"," ")
    for k,v in table.sortedhash(attributes.names) do
        write_nl(whereto,format("%03i %s",k,v))
    end
    write_nl(whereto," ","stored catcodetables:"," ")
    for k,v in table.sortedhash(catcodes.names) do
        write_nl(whereto,format("%03i %s",k,table.concat(v," ")))
    end
    write_nl(whereto," ")
end

storage.shared = storage.shared or { }

-- Because the storage mechanism assumes tables, we define a table for storing
-- (non table) values.

storage.register("storage/shared", storage.shared, "storage.shared")

local mark  = storage.mark

if string.patterns     then                               mark(string.patterns)     end
if lpeg.patterns       then                               mark(lpeg.patterns)       end
if os.env              then                               mark(os.env)              end
if number.dimenfactors then                               mark(number.dimenfactors) end
if libraries           then for k,v in next, libraries do mark(v)                   end end
