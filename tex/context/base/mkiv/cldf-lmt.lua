if not modules then modules = { } end modules ['cldf-lmt'] = {
    version   = 1.001,
    comment   = "companion to toks-scn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local random       = math.random
local randomseed   = math.randomseed
local round        = math.round
local abs          = math.abs

local scanners     = tokens.scanners
local scanword     = scanners.word
local scanstring   = scanners.string
local scanboolean  = scanners.boolean
local scandimen    = scanners.dimen
local scanfloat    = scanners.float
local scancount    = scanners.integer
local scaninteger  = scanners.luainteger
local scancardinal = scanners.luacardinal
local scannumber   = scanners.luanumber
local scanargument = scanners.argument
local scantoken    = scanners.token
local getindex     = token.get_index
local texsetdimen  = tex.setdimen

local values         = tokens.values
local none_code      = values.none
local integer_code   = values.integer
local cardinal_code  = values.cardinal
local dimension_code = values.dimension
local skip_code      = values.skip
local boolean_code   = values.boolean
local float_code     = values.float

local context      = context

local floats    = { }
local integers  = { }
local cardinals = { }
local numbers   = { }

-- variables --

interfaces.implement {
    name      = "luafloat",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            context("%.99g",floats[n] or 0)
        else
            floats[n] = scannumber(true)
         -- floats[n] = scanfloat(true)
        end
    end,
}

interfaces.implement {
    name      = "luainteger",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            context("%i",integers[n] or 0)
        else
            integers[n] = scaninteger(true)
        end
    end,
}

interfaces.implement {
    name      = "luacount",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            return integer_code, integers[n] or 0
        else
            integers[n] = scancount(true)
        end
    end,
}

interfaces.implement {
    name      = "luadimen",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            return dimension_code, integers[n] or 0
        else
            integers[n] = scandimen(false,false,true)
        end
    end,
}

interfaces.implement {
    name      = "luacardinal",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            context("%d",cardinals[n] or 0)
        else
            cardinals[n] = scancardinal(true)
        end
    end,
}

interfaces.implement {
    name      = "luanumber",
    public    = true,
    value     = true,
    actions   = function(b)
        local n = scanword()
        if b then
            context("%d",floats[n] or integers[n] or cardinals[n] or 0)
        else
         -- floats[n] = scanfloat(true)
            floats[n] = scannumber(true)
        end
    end,
}

interfaces.implement {
    name      = "luarandom",
    public    = true,
    value     = true,
    actions   = function(b)
        if b then
            return integer_code, random(scaninteger(),scaninteger())
        else
            randomseed(scaninteger(true))
        end
    end,
}

interfaces.floats    = floats
interfaces.integers  = integers
interfaces.cardinals = cardinals

interfaces.numbers   = table.setmetatableindex(function(t,k)
    return floats[k] or integers[k] or cardinals[k]
end)

-- arrays --

local arrays = { }

interfaces.arrays = arrays

local newindex = lua.newindex

interfaces.implement {
    name      = "newarray",
    public    = true,
    protected = true,
    arguments = { {
        { "name", "string"  },
        { "nx",   "integer" },
        { "ny",   "integer" },
        { "type", "string"  },
    } },
    actions   = function(t)
        local name = t.name
        if t.name then
            local nx = t.nx
            local ny = t.ny
            local ty = t.type or "integer"
            local df = nil
            if ty == "integer" or ty == "float" or ty == "dimension" then
                df = 0
            elseif ty == "boolean" then
                df = false
            else
                ty = nil
            end
            if nx and ty ~= nil then
                local data
                if ny then
                    data = newindex(t.ny)
                    for i=1,ny do
                        data[i] = newindex(nx,df)
                    end
                else
                    data = newindex(nx,df)
                end
                arrays[name] = data
                data.nx      = nx
                data.ny      = ny
                data.type    = ty
                if ty == "integer" then
                    data.scanner = scancount
                elseif ty == "boolean" then
                    data.scanner = scanboolean
                elseif ty == "dimension" then
                    data.scanner = scandimen
                elseif ty == "float" then
                    data.scanner = scanfloat
                end
                if ty == "integer" then
                    data.code = integer_code
                elseif ty == "boolean" then
                    data.code = boolean_code
                elseif ty == "dimension" then
                    data.code = dimension_code
                elseif ty == "float" then
                    data.code = float_code
                end
            end
        end
    end,
}

interfaces.implement {
    name      = "arrayvalue",
    public    = true,
    value     = true,
    actions   = function(b)
        local name = scanstring()
        if name then
            local a = arrays[name]
            if a then
                local nx = a.nx
                local ny = a.ny
                local d  = a
                if ny then
                    d = d[scaninteger()]
                end
                local x = scaninteger()
                if b then
                    local code = a.code
                    if code == float_code then
                        context("%.99g",d[x])
                    else
                        return code, d[x]
                    end
                else
                    d[x] = a.scanner()
                end
            end
        end
    end,
}


interfaces.implement {
    name      = "arrayequals",
    public    = true,
    value     = true,
    actions   = function(b)
        local name = scanstring()
        if name then
            local a = arrays[name]
            if a then
                local nx = a.nx
                local ny = a.ny
                local d  = a
                if ny then
                    d = d[scaninteger()]
                end
                local x = scaninteger()
                if b then
                    return boolean_code, a.scanner() == d[x]
                end
            end
        end
    end,
}

interfaces.implement {
    name      = "arraycompare",
    public    = true,
    value     = true,
    actions   = function(b)
        local name = scanstring()
        if name then
            local a = arrays[name]
            if a then
                local nx = a.nx
                local ny = a.ny
                local d  = a
                if ny then
                    d = d[scaninteger()]
                end
                local x = scaninteger()
                if b then
                    local v = a.scanner()
                    local d = d[x]
                    if d < v then
                        return integer_code, 0
                    elseif d == v then
                        return integer_code, 1
                    else
                        return integer_code, 2
                    end
                end
            end
        end
    end,
}

interfaces.implement {
    name      = "showarray",
    public    = true,
    protected = true,
    actions   = function()
        local name = scanstring()
        if name then
            inspect(arrays[name])
        end
    end,
}

-- expressions --

local cache = table.setmetatableindex(function(t,k)
    local code = "return function() local n = interfaces.numbers local a = interfaces.arrays return " .. k .. " end"
    code = loadstring(code)
    if code then
        code = code()
    end
    t[k] = code or false
    return code
end)

table.makeweak(cache)

interfaces.implement {
    name    = "luaexpression",
    public  = true,
    actions = function()
        local how  = scanword()
        local code = cache[scanargument()]
        if code then
            local result = code()
            if result then
                if not how then
                    context(tostring(code()))
                elseif how == "float" then
                    context("%.99g",result)
                elseif how == "integer" then
                    context("%i",round(result))
                elseif how == "cardinal" then
                    context("%d",abs(round(result)))
                elseif how == "dimen" then
                    context("%p",result)
                elseif how == "boolean" then
                    context("%d",result and 1 or 0)
                elseif how == "lua" then
                    context("%q",result)
                else
                    context(tostring(code()))
                end
            end
        end
    end
}

local dimenfactors = number.dimenfactors

interfaces.implement {
    name      = "nodimen",
    public    = true,
    value     = true,
    actions   = function(b)
        if b then
            local how  = scanword()
            local what = scandimen()
            if how then
                local factor = dimenfactors[how]
                if factor then
                    context("%.6N%s",factor*what,how)
                else
                    return dimension_code, what
                end
            else
                return dimension_code, what
            end
        else
            local t = scantoken()
            if t then
                local i = getindex(t)
                if i then
                    local d = scandimen(false,false,true)
                    texsetdimen(i,d)
                end
            end
        end
    end,
}
