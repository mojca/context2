if not modules then modules = { } end modules ['trac-tim'] = {
    version   = 1.001,
    comment   = "companion to m-timing.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

goodies          = goodies          or { }
goodies.progress = goodies.progress or { }

local progress = goodies.progress

progress = progress or { }

progress.defaultfilename = ((tex and tex.jobname) or "whatever") .. "-luatex-progress"

local params = {
    "cs_count",
    "dyn_used",
    "elapsed_time",
    "luabytecode_bytes",
    "luastate_bytes",
    "max_buf_stack",
    "obj_ptr",
    "pdf_mem_ptr",
    "pdf_mem_size",
    "pdf_os_cntr",
    "pool_ptr",
    "str_ptr",
}

-- storage

local last  = os.clock()
local data  = { }

function progress.save()
    local f = io.open((name or progress.defaultfilename) .. ".lut","w")
    if f then
        f:write(table.serialize(data,true))
        f:close()
        data = { }
    end
end

function progress.store()
    local c = os.clock()
    local t = {
        elapsed_time = c - last,
        node_memory  = nodes.usage(),
    }
    for k, v in pairs(params) do
        if status[v] then t[v] = status[v] end
    end
    data[#data+1] = t
    last = c
end

-- conversion

local processed = { }

function progress.bot(name,tag)
    local d = progress.convert(name)
    return d.bot[tag] or 0
end
function progress.top(name,tag)
    local d = progress.convert(name)
    return d.top[tag] or 0
end
function progress.pages(name,tag)
    local d = progress.convert(name)
    return d.pages or 0
end
function progress.path(name,tag)
    local d = progress.convert(name)
    return d.paths[tag] or "origin"
end
function progress.nodes(name)
    local d = progress.convert(name)
    return d.names or { }
end
function progress.parameters(name)
    local d = progress.convert(name)
    return params -- shared
end

function progress.convert(name)
    name = ((name ~= "") and name) or progress.defaultfilename
    if not processed[name] then
        local names, top, bot, pages, paths, keys = { }, { }, { }, 0, { }, { }
        local data = io.loaddata(name .. ".lut")
        if data then data = loadstring(data) end
        if data then data = data() end
        if data then
            pages = #data
            if pages > 1 then
                local factor = 100
                for k,v in ipairs(data) do
                    for k,v in pairs(v.node_memory) do
                        keys[k] = true
                    end
                end
                for k,v in ipairs(data) do
                    local m = v.node_memory
                    for k, _ in pairs(keys) do
                        if not m[k] then m[k] = 0 end
                    end
                end
                local function path(tag,subtag)
                    local b, t, s = nil, nil, { }
                    for k,v in ipairs(data) do
                        local v = (subtag and v[tag][subtag]) or v[tag]
                        if v then
                            v = tonumber(v)
                            if b then
                                if v > t then t = v end
                                if v < b then b = v end
                            else
                                t = v
                                b = v
                            end
                            s[k] = v
                        else
                            s[k] = 0
                        end
                    end
                    local tagname = subtag or tag
                    top[tagname] = (string.format("%.3f",t)):gsub("%.000$","")
                    bot[tagname] = (string.format("%.3f",b)):gsub("%.000$","")
                    local delta = t-b
                    if delta == 0 then
                        delta = 1
                    else
                        delta = factor/delta
                    end
                    for k, v in ipairs(s) do
                        s[k] = "(" .. k .. "," .. (v-b)*delta .. ")"
                    end
                    paths[tagname] = table.concat(s,"--")
                end
                for _, tag in pairs(params) do
                    path(tag)
                end
                for tag, _ in pairs(keys) do
                    path("node_memory",tag)
                    names[#names+1] = tag
                end
                pages = pages - 1
            end
        end
        table.sort(names)
        processed[name] = {
            names = names,
            top = top,
            bot = bot,
            pages = pages,
            paths = paths,
        }
    end
    return processed[name]
end
