#!/usr/bin/env texlua

if not modules then modules = { } end modules ['mtxrun'] = {
    version   = 1.001,
    comment   = "runner, lua replacement for texmfstart.rb",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


-- one can make a stub:
--
-- #!/bin/sh
-- env LUATEXDIR=/....../texmf/scripts/context/lua luatex --luaonly mtxrun.lua "$@"

-- filename : mtxrun.lua
-- comment  : companion to context.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- This script is based on texmfstart.rb but does not use kpsewhich to
-- locate files. Although kpse is a library it never came to opening up
-- its interface to other programs (esp scripting languages) and so we
-- do it ourselves. The lua variant evolved out of an experimental ruby
-- one. Interesting is that using a scripting language instead of c does
-- not have a speed penalty. Actually the lua variant is more efficient,
-- especially when multiple calls to kpsewhich are involved. The lua
-- library also gives way more control.

-- to be done / considered
--
-- support for --exec or make it default
-- support for jar files (or maybe not, never used, too messy)
-- support for $RUBYINPUTS cum suis (if still needed)
-- remember for subruns: _CTX_K_V_#{original}_
-- remember for subruns: _CTX_K_S_#{original}_
-- remember for subruns: TEXMFSTART.#{original} [tex.rb texmfstart.rb]

texlua = true

-- begin library merge



do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-string'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sub, gsub, find, match, gmatch, format, char, byte, rep = string.sub, string.gsub, string.find, string.match, string.gmatch, string.format, string.char, string.byte, string.rep

if not string.split then

    -- this will be overloaded by a faster lpeg variant

    function string:split(pattern)
        if #self > 0 then
            local t = { }
            for s in gmatch(self..pattern,"(.-)"..pattern) do
                t[#t+1] = s
            end
            return t
        else
            return { }
        end
    end

end

local chr_to_esc = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["^"] = "%^", ["$"] = "%$",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
    ["{"] = "%{", ["}"] = "%}"
}

string.chr_to_esc = chr_to_esc

function string:esc() -- variant 2
    return (gsub(self,"(.)",chr_to_esc))
end

function string:unquote()
    return (gsub(self,"^([\"\'])(.*)%1$","%2"))
end

--~ function string:unquote()
--~     if find(self,"^[\'\"]") then
--~         return self:sub(2,-2)
--~     else
--~         return self
--~     end
--~ end

function string:quote() -- we could use format("%q")
    return '"' .. self:unquote() .. '"'
end

function string:count(pattern) -- variant 3
    local n = 0
    for _ in gmatch(self,pattern) do
        n = n + 1
    end
    return n
end

function string:limit(n,sentinel)
    if #self > n then
        sentinel = sentinel or " ..."
        return sub(self,1,(n-#sentinel)) .. sentinel
    else
        return self
    end
end

function string:strip()
    return (gsub(self,"^%s*(.-)%s*$", "%1"))
end

function string:is_empty()
    return not find(self,"%S")
end

function string:enhance(pattern,action)
    local ok, n = true, 0
    while ok do
        ok = false
        self = gsub(self,pattern, function(...)
            ok, n = true, n + 1
            return action(...)
        end)
    end
    return self, n
end

local chr_to_hex, hex_to_chr = { }, { }

for i=0,255 do
    local c, h = char(i), format("%02X",i)
    chr_to_hex[c], hex_to_chr[h] = h, c
end

function string:to_hex()
    return (gsub(self or "","(.)",chr_to_hex))
end

function string:from_hex()
    return (gsub(self or "","(..)",hex_to_chr))
end

if not string.characters then

    local function nextchar(str, index)
        index = index + 1
        return (index <= #str) and index or nil, str:sub(index,index)
    end
    function string:characters()
        return nextchar, self, 0
    end
    local function nextbyte(str, index)
        index = index + 1
        return (index <= #str) and index or nil, byte(str:sub(index,index))
    end
    function string:bytes()
        return nextbyte, self, 0
    end

end

-- we can use format for this (neg n)

function string:rpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return self .. self.rep(chr or " ",m)
    else
        return self
    end
end

function string:lpadd(n,chr)
    local m = n-#self
    if m > 0 then
        return self.rep(chr or " ",m) .. self
    else
        return self
    end
end

string.padd = string.rpadd

function is_number(str) -- tonumber
    return find(str,"^[%-%+]?[%d]-%.?[%d+]$") == 1
end

--~ print(is_number("1"))
--~ print(is_number("1.1"))
--~ print(is_number(".1"))
--~ print(is_number("-0.1"))
--~ print(is_number("+0.1"))
--~ print(is_number("-.1"))
--~ print(is_number("+.1"))

function string:split_settings() -- no {} handling, see l-aux for lpeg variant
    if find(self,"=") then
        local t = { }
        for k,v in gmatch(self,"(%a+)=([^%,]*)") do
            t[k] = v
        end
        return t
    else
        return nil
    end
end

local patterns_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["+"] = "%+",
    ["*"] = "%*",
    ["%"] = "%%",
    ["("] = "%)",
    [")"] = "%)",
    ["["] = "%[",
    ["]"] = "%]",
}

function string:pattesc()
    return (gsub(self,".",patterns_escapes))
end

function string:tohash()
    local t = { }
    for s in gmatch(self,"([^, ]+)") do -- lpeg
        t[s] = true
    end
    return t
end

local pattern = lpeg.Ct(lpeg.C(1)^0)

function string:totable()
    return pattern:match(self)
end

--~ for _, str in ipairs {
--~     "1234567123456712345671234567",
--~     "a\tb\tc",
--~     "aa\tbb\tcc",
--~     "aaa\tbbb\tccc",
--~     "aaaa\tbbbb\tcccc",
--~     "aaaaa\tbbbbb\tccccc",
--~     "aaaaaa\tbbbbbb\tcccccc",
--~ } do print(string.tabtospace(str)) end

function string.tabtospace(str,tab)
    -- we don't handle embedded newlines
    while true do
        local s = find(str,"\t")
        if s then
            if not tab then tab = 7 end -- only when found
            local d = tab-(s-1)%tab
            if d > 0 then
                str = gsub(str,"\t",rep(" ",d),1)
            else
                str = gsub(str,"\t","",1)
            end
        else
            break
        end
    end
    return str
end

function string:compactlong() -- strips newlines and leading spaces
    self = gsub(self,"[\n\r]+ *","")
    self = gsub(self,"^ *","")
    return self
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-lpeg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, S, Ct, C, Cs, Cc = lpeg.P, lpeg.S, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc

--~ l-lpeg.lua :

--~ lpeg.digit         = lpeg.R('09')^1
--~ lpeg.sign          = lpeg.S('+-')^1
--~ lpeg.cardinal      = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.integer       = lpeg.P(lpeg.sign^0 * lpeg.digit^1)
--~ lpeg.float         = lpeg.P(lpeg.sign^0 * lpeg.digit^0 * lpeg.P('.') * lpeg.digit^1)
--~ lpeg.number        = lpeg.float + lpeg.integer
--~ lpeg.oct           = lpeg.P("0") * lpeg.R('07')^1
--~ lpeg.hex           = lpeg.P("0x") * (lpeg.R('09') + lpeg.R('AF'))^1
--~ lpeg.uppercase     = lpeg.P("AZ")
--~ lpeg.lowercase     = lpeg.P("az")

--~ lpeg.eol           = lpeg.S('\r\n\f')^1 -- includes formfeed
--~ lpeg.space         = lpeg.S(' ')^1
--~ lpeg.nonspace      = lpeg.P(1-lpeg.space)^1
--~ lpeg.whitespace    = lpeg.S(' \r\n\f\t')^1
--~ lpeg.nonwhitespace = lpeg.P(1-lpeg.whitespace)^1

local hash = { }

function lpeg.anywhere(pattern) --slightly adapted from website
    return P { P(pattern) + 1 * lpeg.V(1) }
end

function lpeg.startswith(pattern) --slightly adapted
    return P(pattern)
end

function lpeg.splitter(pattern, action)
    return (((1-P(pattern))^1)/action+1)^0
end

-- variant:

--~ local parser = lpeg.Ct(lpeg.splitat(newline))

local crlf     = P("\r\n")
local cr       = P("\r")
local lf       = P("\n")
local space    = S(" \t\f\v")  -- + string.char(0xc2, 0xa0) if we want utf (cf mail roberto)
local newline  = crlf + cr + lf
local spacing  = space^0 * newline

local empty    = spacing * Cc("")
local nonempty = Cs((1-spacing)^1) * spacing^-1
local content  = (empty + nonempty)^1

local capture = Ct(content^0)

function string:splitlines()
    return capture:match(self)
end

lpeg.linebyline = content -- better make a sublibrary

--~ local p = lpeg.splitat("->",false)  print(p:match("oeps->what->more"))  -- oeps what more
--~ local p = lpeg.splitat("->",true)   print(p:match("oeps->what->more"))  -- oeps what->more
--~ local p = lpeg.splitat("->",false)  print(p:match("oeps"))              -- oeps
--~ local p = lpeg.splitat("->",true)   print(p:match("oeps"))              -- oeps

local splitters_s, splitters_m = { }, { }

local function splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = P(separator)
        if single then
            local other, any = C((1 - separator)^0), P(1)
            splitter = other * (separator * C(any^0) + "")
            splitters_s[separator] = splitter
        else
            local other = C((1 - separator)^0)
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

lpeg.splitat = splitat

local cache = { }

function string:split(separator)
    local c = cache[separator]
    if not c then
        c = Ct(splitat(separator))
        cache[separator] = c
    end
    return c:match(self)
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-table'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

table.join = table.concat

local concat, sort, insert, remove = table.concat, table.sort, table.insert, table.remove
local format, find, gsub, lower, dump = string.format, string.find, string.gsub, string.lower, string.dump
local getmetatable, setmetatable = getmetatable, setmetatable
local type, next, tostring, ipairs = type, next, tostring, ipairs

function table.strip(tab)
    local lst = { }
    for i=1,#tab do
        local s = gsub(tab[i],"^%s*(.-)%s*$","%1")
        if s == "" then
            -- skip this one
        else
            lst[#lst+1] = s
        end
    end
    return lst
end

local function compare(a,b)
    return (tostring(a) < tostring(b))
end

local function sortedkeys(tab)
    local srt, kind = { }, 0 -- 0=unknown 1=string, 2=number 3=mixed
    for key,_ in next, tab do
        srt[#srt+1] = key
        if kind == 3 then
            -- no further check
        else
            local tkey = type(key)
            if tkey == "string" then
            --  if kind == 2 then kind = 3 else kind = 1 end
                kind = (kind == 2 and 3) or 1
            elseif tkey == "number" then
            --  if kind == 1 then kind = 3 else kind = 2 end
                kind = (kind == 1 and 3) or 2
            else
                kind = 3
            end
        end
    end
    if kind == 0 or kind == 3 then
        sort(srt,compare)
    else
        sort(srt)
    end
    return srt
end

local function sortedhashkeys(tab) -- fast one
    local srt = { }
    for key,_ in next, tab do
        srt[#srt+1] = key
    end
    sort(srt)
    return srt
end

table.sortedkeys     = sortedkeys
table.sortedhashkeys = sortedhashkeys

function table.sortedpairs(t)
    local s = sortedhashkeys(t) -- maybe just sortedkeys
    local n = 0
    local function kv(s)
        n = n + 1
        local k = s[n]
        return k, t[k]
    end
    return kv, s
end

function table.append(t, list)
    for _,v in next, list do
        insert(t,v)
    end
end

function table.prepend(t, list)
    for k,v in next, list do
        insert(t,k,v)
    end
end

function table.merge(t, ...) -- first one is target
    t = t or {}
    local lst = {...}
    for i=1,#lst do
        for k, v in next, lst[i] do
            t[k] = v
        end
    end
    return t
end

function table.merged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        for k, v in next, lst[i] do
            tmp[k] = v
        end
    end
    return tmp
end

function table.imerge(t, ...)
    local lst = {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            t[#t+1] = nst[j]
        end
    end
    return t
end

function table.imerged(...)
    local tmp, lst = { }, {...}
    for i=1,#lst do
        local nst = lst[i]
        for j=1,#nst do
            tmp[#tmp+1] = nst[j]
        end
    end
    return tmp
end

local function fastcopy(old) -- fast one
    if old then
        local new = { }
        for k,v in next, old do
            if type(v) == "table" then
                new[k] = fastcopy(v) -- was just table.copy
            else
                new[k] = v
            end
        end
        -- optional second arg
        local mt = getmetatable(old)
        if mt then
            setmetatable(new,mt)
        end
        return new
    else
        return { }
    end
end

local function copy(t, tables) -- taken from lua wiki, slightly adapted
    tables = tables or { }
    local tcopy = {}
    if not tables[t] then
        tables[t] = tcopy
    end
    for i,v in next, t do -- brrr, what happens with sparse indexed
        if type(i) == "table" then
            if tables[i] then
                i = tables[i]
            else
                i = copy(i, tables)
            end
        end
        if type(v) ~= "table" then
            tcopy[i] = v
        elseif tables[v] then
            tcopy[i] = tables[v]
        else
            tcopy[i] = copy(v, tables)
        end
    end
    local mt = getmetatable(t)
    if mt then
        setmetatable(tcopy,mt)
    end
    return tcopy
end

table.fastcopy = fastcopy
table.copy     = copy

-- rougly: copy-loop : unpack : sub == 0.9 : 0.4 : 0.45 (so in critical apps, use unpack)

function table.sub(t,i,j)
    return { unpack(t,i,j) }
end

function table.replace(a,b)
    for k,v in next, b do
        a[k] = v
    end
end

-- slower than #t on indexed tables (#t only returns the size of the numerically indexed slice)

function table.is_empty(t)
    return not t or not next(t)
end

function table.one_entry(t)
    local n = next(t)
    return n and not next(t,n)
end

function table.starts_at(t)
    return ipairs(t,1)(t,0)
end

function table.tohash(t,value)
    local h = { }
    if t then
        if value == nil then value = true end
        for _, v in next, t do -- no ipairs here
            h[v] = value
        end
    end
    return h
end

function table.fromhash(t)
    local h = { }
    for k, v in next, t do -- no ipairs here
        if v then h[#h+1] = k end
    end
    return h
end

--~ print(table.serialize(t), "\n")
--~ print(table.serialize(t,"name"), "\n")
--~ print(table.serialize(t,false), "\n")
--~ print(table.serialize(t,true), "\n")
--~ print(table.serialize(t,"name",true), "\n")
--~ print(table.serialize(t,"name",true,true), "\n")

table.serialize_functions = true
table.serialize_compact   = true
table.serialize_inline    = true

local noquotes, hexify, handle, reduce, compact, inline, functions

local reserved = table.tohash { -- intercept a language flaw, no reserved words as key
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}

local function simple_table(t)
    if #t > 0 then
        local n = 0
        for _,v in next, t do
            n = n + 1
        end
        if n == #t then
            local tt = { }
            for i=1,#t do
                local v = t[i]
                local tv = type(v)
                if tv == "number" then
                    if hexify then
                        tt[#tt+1] = format("0x%04X",v)
                    else
                        tt[#tt+1] = tostring(v) -- tostring not needed
                    end
                elseif tv == "boolean" then
                    tt[#tt+1] = tostring(v)
                elseif tv == "string" then
                    tt[#tt+1] = format("%q",v)
                else
                    tt = nil
                    break
                end
            end
            return tt
        end
    end
    return nil
end

-- Because this is a core function of mkiv I moved some function calls
-- inline.
--
-- twice as fast in a test:
--
-- local propername = lpeg.P(lpeg.R("AZ","az","__") * lpeg.R("09","AZ","az", "__")^0 * lpeg.P(-1) )

local function do_serialize(root,name,depth,level,indexed)
    if level > 0 then
        depth = depth .. " "
        if indexed then
            handle(format("%s{",depth))
        elseif name then
        --~ handle(format("%s%s={",depth,key(name)))
            if type(name) == "number" then -- or find(k,"^%d+$") then
                if hexify then
                    handle(format("%s[0x%04X]={",depth,name))
                else
                    handle(format("%s[%s]={",depth,name))
                end
            elseif noquotes and not reserved[name] and find(name,"^%a[%w%_]*$") then
                handle(format("%s%s={",depth,name))
            else
                handle(format("%s[%q]={",depth,name))
            end
        else
            handle(format("%s{",depth))
        end
    end
    if root and next(root) then
        local first, last = nil, 0 -- #root cannot be trusted here
        if compact then
            -- NOT: for k=1,#root do (we need to quit at nil)
            for k,v in ipairs(root) do -- can we use next?
                if not first then first = k end
                last = last + 1
            end
        end
        local sk = sortedkeys(root)
        for i=1,#sk do
            local k = sk[i]
            local v = root[k]
            --~ if v == root then
                -- circular
            --~ else
            local t = type(v)
            if compact and first and type(k) == "number" and k >= first and k <= last then
                if t == "number" then
                    if hexify then
                        handle(format("%s 0x%04X,",depth,v))
                    else
                        handle(format("%s %s,",depth,v))
                    end
                elseif t == "string" then
                    if reduce and (find(v,"^[%-%+]?[%d]-%.?[%d+]$") == 1) then
                        handle(format("%s %s,",depth,v))
                    else
                        handle(format("%s %q,",depth,v))
                    end
                elseif t == "table" then
                    if not next(v) then
                        handle(format("%s {},",depth))
                    elseif inline then -- and #t > 0
                        local st = simple_table(v)
                        if st then
                            handle(format("%s { %s },",depth,concat(st,", ")))
                        else
                            do_serialize(v,k,depth,level+1,true)
                        end
                    else
                        do_serialize(v,k,depth,level+1,true)
                    end
                elseif t == "boolean" then
                    handle(format("%s %s,",depth,tostring(v)))
                elseif t == "function" then
                    if functions then
                        handle(format('%s loadstring(%q),',depth,dump(v)))
                    else
                        handle(format('%s "function",',depth))
                    end
                else
                    handle(format("%s %q,",depth,tostring(v)))
                end
            elseif k == "__p__" then -- parent
                if false then
                    handle(format("%s __p__=nil,",depth))
                end
            elseif t == "number" then
            --~ if hexify then
            --~     handle(format("%s %s=0x%04X,",depth,key(k),v))
            --~ else
            --~     handle(format("%s %s=%s,",depth,key(k),v))
            --~ end
                if type(k) == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%s]=%s,",depth,k,v))
                    end
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    if hexify then
                        handle(format("%s %s=0x%04X,",depth,k,v))
                    else
                        handle(format("%s %s=%s,",depth,k,v))
                    end
                else
                    if hexify then
                        handle(format("%s [%q]=0x%04X,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v))
                    end
                end
            elseif t == "string" then
                if reduce and (find(v,"^[%-%+]?[%d]-%.?[%d+]$") == 1) then
                --~ handle(format("%s %s=%s,",depth,key(k),v))
                    if type(k) == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%s,",depth,k,v))
                        else
                            handle(format("%s [%s]=%s,",depth,k,v))
                        end
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%s,",depth,k,v))
                    else
                        handle(format("%s [%q]=%s,",depth,k,v))
                    end
                else
                --~ handle(format("%s %s=%q,",depth,key(k),v))
                    if type(k) == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=%q,",depth,k,v))
                        else
                            handle(format("%s [%s]=%q,",depth,k,v))
                        end
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=%q,",depth,k,v))
                    else
                        handle(format("%s [%q]=%q,",depth,k,v))
                    end
                end
            elseif t == "table" then
                if not next(v) then
                    --~ handle(format("%s %s={},",depth,key(k)))
                    if type(k) == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]={},",depth,k))
                        else
                            handle(format("%s [%s]={},",depth,k))
                        end
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s={},",depth,k))
                    else
                        handle(format("%s [%q]={},",depth,k))
                    end
                elseif inline then
                    local st = simple_table(v)
                    if st then
                    --~ handle(format("%s %s={ %s },",depth,key(k),concat(st,", ")))
                        if type(k) == "number" then -- or find(k,"^%d+$") then
                            if hexify then
                                handle(format("%s [0x%04X]={ %s },",depth,k,concat(st,", ")))
                            else
                                handle(format("%s [%s]={ %s },",depth,k,concat(st,", ")))
                            end
                        elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                            handle(format("%s %s={ %s },",depth,k,concat(st,", ")))
                        else
                            handle(format("%s [%q]={ %s },",depth,k,concat(st,", ")))
                        end
                    else
                        do_serialize(v,k,depth,level+1)
                    end
                else
                    do_serialize(v,k,depth,level+1)
                end
            elseif t == "boolean" then
            --~ handle(format("%s %s=%s,",depth,key(k),tostring(v)))
                if type(k) == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%s,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%s,",depth,k,tostring(v)))
                    end
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%s,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%s,",depth,k,tostring(v)))
                end
            elseif t == "function" then
                if functions then
                    --~ handle(format('%s %s=loadstring(%q),',depth,key(k),dump(v)))
                    if type(k) == "number" then -- or find(k,"^%d+$") then
                        if hexify then
                            handle(format("%s [0x%04X]=loadstring(%q),",depth,k,dump(v)))
                        else
                            handle(format("%s [%s]=loadstring(%q),",depth,k,dump(v)))
                        end
                    elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                        handle(format("%s %s=loadstring(%q),",depth,k,dump(v)))
                    else
                        handle(format("%s [%q]=loadstring(%q),",depth,k,dump(v)))
                    end
                end
            else
                --~ handle(format("%s %s=%q,",depth,key(k),tostring(v)))
                if type(k) == "number" then -- or find(k,"^%d+$") then
                    if hexify then
                        handle(format("%s [0x%04X]=%q,",depth,k,tostring(v)))
                    else
                        handle(format("%s [%s]=%q,",depth,k,tostring(v)))
                    end
                elseif noquotes and not reserved[k] and find(k,"^%a[%w%_]*$") then
                    handle(format("%s %s=%q,",depth,k,tostring(v)))
                else
                    handle(format("%s [%q]=%q,",depth,k,tostring(v)))
                end
            end
            --~ end
        end
    end
   if level > 0 then
        handle(format("%s},",depth))
    end
end

-- replacing handle by a direct t[#t+1] = ... (plus test) is not much
-- faster (0.03 on 1.00 for zapfino.tma)

local function serialize(root,name,_handle,_reduce,_noquotes,_hexify)
    noquotes = _noquotes
    hexify = _hexify
    handle = _handle or print
    reduce = _reduce or false
    compact = table.serialize_compact
    inline  = compact and table.serialize_inline
    functions = table.serialize_functions
    local tname = type(name)
    if tname == "string" then
        if name == "return" then
            handle("return {")
        else
            handle(name .. "={")
        end
    elseif tname == "number" then
        if hexify then
            handle(format("[0x%04X]={",name))
        else
            handle("[" .. name .. "]={")
        end
    elseif tname == "boolean" then
        if name then
            handle("return {")
        else
            handle("{")
        end
    else
        handle("t={")
    end
    if root and next(root) then
        do_serialize(root,name,"",0,indexed)
    end
    handle("}")
end

--~ name:
--~
--~ true     : return     { }
--~ false    :            { }
--~ nil      : t        = { }
--~ string   : string   = { }
--~ 'return' : return     { }
--~ number   : [number] = { }

function table.serialize(root,name,reduce,noquotes,hexify)
    local t = { }
    local function flush(s)
        t[#t+1] = s
    end
    serialize(root,name,flush,reduce,noquotes,hexify)
    return concat(t,"\n")
end

function table.tohandle(handle,root,name,reduce,noquotes,hexify)
    serialize(root,name,handle,reduce,noquotes,hexify)
end

-- sometimes tables are real use (zapfino extra pro is some 85M) in which
-- case a stepwise serialization is nice; actually, we could consider:
--
-- for line in table.serializer(root,name,reduce,noquotes) do
--    ...(line)
-- end
--
-- so this is on the todo list

table.tofile_maxtab = 2*1024

function table.tofile(filename,root,name,reduce,noquotes,hexify)
    local f = io.open(filename,'w')
    if f then
        local maxtab = table.tofile_maxtab
        if maxtab > 1 then
            local t = { }
            local function flush(s)
                t[#t+1] = s
                if #t > maxtab then
                    f:write(concat(t,"\n"),"\n") -- hm, write(sometable) should be nice
                    t = { }
                end
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
            f:write(concat(t,"\n"),"\n")
        else
            local function flush(s)
                f:write(s,"\n")
            end
            serialize(root,name,flush,reduce,noquotes,hexify)
        end
        f:close()
    end
end

local function flatten(t,f,complete)
    for i=1,#t do
        local v = t[i]
        if type(v) == "table" then
            if complete or type(v[1]) == "table" then
                flatten(v,f,complete)
            else
                f[#f+1] = v
            end
        else
            f[#f+1] = v
        end
    end
end

function table.flatten(t)
    local f = { }
    flatten(t,f,true)
    return f
end

function table.unnest(t) -- bad name
    local f = { }
    flatten(t,f,false)
    return f
end

table.flatten_one_level = table.unnest

-- the next three may disappear

function table.remove_value(t,value) -- todo: n
    if value then
        for i=1,#t do
            if t[i] == value then
                remove(t,i)
                -- remove all, so no: return
            end
        end
    end
end

function table.insert_before_value(t,value,str)
    if str then
        if value then
            for i=1,#t do
                if t[i] == value then
                    insert(t,i,str)
                    return
                end
            end
        end
        insert(t,1,str)
    elseif value then
        insert(t,1,value)
    end
end

function table.insert_after_value(t,value,str)
    if str then
        if value then
            for i=1,#t do
                if t[i] == value then
                    insert(t,i+1,str)
                    return
                end
            end
        end
        t[#t+1] = str
    elseif value then
        t[#t+1] = value
    end
end

local function are_equal(a,b,n,m) -- indexed
    if a and b and #a == #b then
        n = n or 1
        m = m or #a
        for i=n,m do
            local ai, bi = a[i], b[i]
            if ai==bi then
                -- same
            elseif type(ai)=="table" and type(bi)=="table" then
                if not are_equal(ai,bi) then
                    return false
                end
            else
                return false
            end
        end
        return true
    else
        return false
    end
end

local function identical(a,b) -- assumes same structure
    for ka, va in next, a do
        local vb = b[k]
        if va == vb then
            -- same
        elseif type(va) == "table" and  type(vb) == "table" then
            if not identical(va,vb) then
                return false
            end
        else
            return false
        end
    end
    return true
end

table.are_equal = are_equal
table.identical = identical

-- maybe also make a combined one

function table.compact(t)
    if t then
        for k,v in next, t do
            if not next(v) then
                t[k] = nil
            end
        end
    end
end

function table.contains(t, v)
    if t then
        for i=1, #t do
            if t[i] == v then
                return i
            end
        end
    end
    return false
end

function table.count(t)
    local n, e = 0, next(t)
    while e do
        n, e = n + 1, next(t,e)
    end
    return n
end

function table.swapped(t)
    local s = { }
    for k, v in next, t do
        s[v] = k
    end
    return s
end

--~ function table.are_equal(a,b)
--~     return table.serialize(a) == table.serialize(b)
--~ end

function table.clone(t,p) -- t is optional or nil or table
    if not p then
        t, p = { }, t or { }
    elseif not t then
        t = { }
    end
    setmetatable(t, { __index = function(_,key) return p[key] end })
    return t
end

function table.hexed(t,seperator)
    local tt = { }
    for i=1,#t do tt[i] = format("0x%04X",t[i]) end
    return concat(tt,seperator or " ")
end

function table.reverse_hash(h)
    local r = { }
    for k,v in next, h do
        r[v] = lower(gsub(k," ",""))
    end
    return r
end

function table.reverse(t)
    local tt = { }
    if #t > 0 then
        for i=#t,1,-1 do
            tt[#tt+1] = t[i]
        end
    end
    return tt
end

--~ function table.keys(t)
--~     local k = { }
--~     for k,_ in next, t do
--~         k[#k+1] = k
--~     end
--~     return k
--~ end

--~ function table.keys_as_string(t)
--~     local k = { }
--~     for k,_ in next, t do
--~         k[#k+1] = k
--~     end
--~     return concat(k,"")
--~ end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-io'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte = string.byte

if string.find(os.getenv("PATH"),";") then
    io.fileseparator, io.pathseparator = "\\", ";"
else
    io.fileseparator, io.pathseparator = "/" , ":"
end

function io.loaddata(filename,textmode)
    local f = io.open(filename,(textmode and 'r') or 'rb')
    if f then
    --  collectgarbage("step") -- sometimes makes a big difference in mem consumption
        local data = f:read('*all')
    --  garbagecollector.check(data)
        f:close()
        return data
    else
        return nil
    end
end

function io.savedata(filename,data,joiner)
    local f = io.open(filename,"wb")
    if f then
        if type(data) == "table" then
            f:write(table.join(data,joiner or ""))
        elseif type(data) == "function" then
            data(f)
        else
            f:write(data)
        end
        f:close()
        return true
    else
        return false
    end
end

function io.exists(filename)
    local f = io.open(filename)
    if f == nil then
        return false
    else
        assert(f:close())
        return true
    end
end

function io.size(filename)
    local f = io.open(filename)
    if f == nil then
        return 0
    else
        local s = f:seek("end")
        assert(f:close())
        return s
    end
end

function io.noflines(f)
    local n = 0
    for _ in f:lines() do
        n = n + 1
    end
    f:seek('set',0)
    return n
end

local nextchar = {
    [ 4] = function(f)
        return f:read(1,1,1,1)
    end,
    [ 2] = function(f)
        return f:read(1,1)
    end,
    [ 1] = function(f)
        return f:read(1)
    end,
    [-2] = function(f)
        local a, b = f:read(1,1)
        return b, a
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        return d, c, b, a
    end
}

function io.characters(f,n)
    if f then
        return nextchar[n or 1], f
    else
        return nil, nil
    end
end

local nextbyte = {
    [4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(a), byte(b), byte(c), byte(d)
        else
            return nil, nil, nil, nil
        end
    end,
    [2] = function(f)
        local a, b = f:read(1,1)
        if b then
            return byte(a), byte(b)
        else
            return nil, nil
        end
    end,
    [1] = function (f)
        local a = f:read(1)
        if a then
            return byte(a)
        else
            return nil
        end
    end,
    [-2] = function (f)
        local a, b = f:read(1,1)
        if b then
            return byte(b), byte(a)
        else
            return nil, nil
        end
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(d), byte(c), byte(b), byte(a)
        else
            return nil, nil, nil, nil
        end
    end
}

function io.bytes(f,n)
    if f then
        return nextbyte[n or 1], f
    else
        return nil, nil
    end
end

function io.ask(question,default,options)
    while true do
        io.write(question)
        if options then
            io.write(string.format(" [%s]",table.concat(options,"|")))
        end
        if default then
            io.write(string.format(" [%s]",default))
        end
        io.write(string.format(" "))
        local answer = io.read()
        answer = answer:gsub("^%s*(.*)%s*$","%1")
        if answer == "" and default then
            return default
        elseif not options then
            return answer
        else
            for _,v in pairs(options) do
                if v == answer then
                    return answer
                end
            end
            local pattern = "^" .. answer
            for _,v in pairs(options) do
                if v:find(pattern) then
                    return v
                end
            end
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-number'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

number = number or { }

-- a,b,c,d,e,f = number.toset(100101)

function number.toset(n)
    return (tostring(n)):match("(.?)(.?)(.?)(.?)(.?)(.?)(.?)(.?)")
end

function number.toevenhex(n)
    local s = format("%X",n)
    if #s % 2 == 0 then
        return s
    else
        return "0" .. s
    end
end

-- the lpeg way is slower on 8 digits, but faster on 4 digits, some 7.5%
-- on
--
-- for i=1,1000000 do
--     local a,b,c,d,e,f,g,h = number.toset(12345678)
--     local a,b,c,d         = number.toset(1234)
--     local a,b,c           = number.toset(123)
-- end
--
-- of course dedicated "(.)(.)(.)(.)" matches are even faster

local one = lpeg.C(1-lpeg.S(''))^1

function number.toset(n)
    return one:match(tostring(n))
end




end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-set'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

set = set or { }

local nums   = { }
local tabs   = { }
local concat = table.concat
local next, type = next, type

set.create = table.tohash

function set.tonumber(t)
    if next(t) then
        local s = ""
    --  we could save mem by sorting, but it slows down
        for k, v in next, t do
            if v then
            --  why bother about the leading space
                s = s .. " " .. k
            end
        end
        local n = nums[s]
        if not n then
            n = #tabs + 1
            tabs[n] = t
            nums[s] = n
        end
        return n
    else
        return 0
    end
end

function set.totable(n)
    if n == 0 then
        return { }
    else
        return tabs[n] or { }
    end
end

function set.tolist(n)
    if n == 0 or not tabs[n] then
        return ""
    else
        local t = { }
        for k, v in next, tabs[n] do
            if v then
                t[#t+1] = k
            end
        end
        return concat(t," ")
    end
end

function set.contains(n,s)
    if type(n) == "table" then
        return n[s]
    elseif n == 0 then
        return false
    else
        local t = tabs[n]
        return t and t[s]
    end
end

--~ local c = set.create{'aap','noot','mies'}
--~ local s = set.tonumber(c)
--~ local t = set.totable(s)
--~ print(t['aap'])
--~ local c = set.create{'zus','wim','jet'}
--~ local s = set.tonumber(c)
--~ local t = set.totable(s)
--~ print(t['aap'])
--~ print(t['jet'])
--~ print(set.contains(t,'jet'))
--~ print(set.contains(t,'aap'))



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-os'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find

function os.resultof(command)
    return io.popen(command,"r"):read("*all")
end

if not os.exec  then os.exec  = os.execute end
if not os.spawn then os.spawn = os.execute end

--~ os.type : windows | unix (new, we already guessed os.platform)
--~ os.name : windows | msdos | linux | macosx | solaris | .. | generic (new)

if not io.fileseparator then
    if find(os.getenv("PATH"),";") then
        io.fileseparator, io.pathseparator, os.platform = "\\", ";", os.type or "windows"
    else
        io.fileseparator, io.pathseparator, os.platform = "/" , ":", os.type or "unix"
    end
end

os.platform = os.platform or os.type or (io.pathseparator == ";" and "windows") or "unix"

function os.launch(str)
    if os.platform == "windows" then
        os.execute("start " .. str) -- os.spawn ?
    else
        os.execute(str .. " &")     -- os.spawn ?
    end
end

if not os.setenv then
    function os.setenv() return false end
end

if not os.times then
    -- utime  = user time
    -- stime  = system time
    -- cutime = children user time
    -- cstime = children system time
    function os.times()
        return {
            utime  = os.gettimeofday(), -- user
            stime  = 0,                 -- system
            cutime = 0,                 -- children user
            cstime = 0,                 -- children system
        }
    end
end

os.gettimeofday = os.gettimeofday or os.clock

local startuptime = os.gettimeofday()

function os.runtime()
    return os.gettimeofday() - startuptime
end

--~ print(os.gettimeofday()-os.time())
--~ os.sleep(1.234)
--~ print (">>",os.runtime())
--~ print(os.date("%H:%M:%S",os.gettimeofday()))
--~ print(os.date("%H:%M:%S",os.time()))

os.arch = os.arch or function()
    local a = os.resultof("uname -m") or "linux"
    os.arch = function()
        return a
    end
    return a
end

local platform

function os.currentplatform(name,default)
    if not platform then
        local name = os.name or os.platform or name -- os.name is built in, os.platform is mine
        if not name then
            platform = default or "linux"
        elseif name == "windows" or name == "mswin" or name == "win32" or name == "msdos" then
            if os.getenv("PROCESSOR_ARCHITECTURE") == "AMD64" then
                platform = "mswin-64"
            else
                platform = "mswin"
            end
        else
            local architecture = os.arch()
            if name == "linux" then
                if find(architecture,"x86_64") then
                    platform = "linux-64"
                elseif find(architecture,"ppc") then
                    platform = "linux-ppc"
                else
                    platform = "linux"
                end
            elseif name == "macosx" then
                if find(architecture,"i386") then
                    platform = "osx-intel"
                else
                    platform = "osx-ppc"
                end
            elseif name == "sunos" then
                if find(architecture,"sparc") then
                    platform = "solaris-sparc"
                else -- if architecture == 'i86pc'
                    platform = "solaris-intel"
                end
            elseif name == "freebsd" then
                if find(architecture,"amd64") then
                    platform = "freebsd-amd64"
                else
                    platform = "freebsd"
                end
            else
                platform = default or name
            end
        end
        function os.currentplatform()
            return platform
        end
    end
    return platform
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-file'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup

file = file or { }

local concat = table.concat
local find, gmatch, match, gsub = string.find, string.gmatch, string.match, string.gsub

function file.removesuffix(filename)
    return (gsub(filename,"%.[%a%d]+$",""))
end

function file.addsuffix(filename, suffix)
    if not find(filename,"%.[%a%d]+$") then
        return filename .. "." .. suffix
    else
        return filename
    end
end

function file.replacesuffix(filename, suffix)
    return (gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
end

function file.dirname(name,default)
    return match(name,"^(.+)[/\\].-$") or (default or "")
end

function file.basename(name)
    return match(name,"^.+[/\\](.-)$") or name
end

function file.nameonly(name)
    return (gsub(match(name,"^.+[/\\](.-)$") or name,"%..*$",""))
end

function file.extname(name)
    return match(name,"^.+%.([^/\\]-)$") or  ""
end

file.suffix = file.extname

--~ print(file.join("x/","/y"))
--~ print(file.join("http://","/y"))
--~ print(file.join("http://a","/y"))
--~ print(file.join("http:///a","/y"))
--~ print(file.join("//nas-1","/y"))

function file.join(...)
    local pth = concat({...},"/")
    pth = gsub(pth,"\\","/")
    local a, b = match(pth,"^(.*://)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    a, b = match(pth,"^(//)(.*)$")
    if a and b then
        return a .. gsub(b,"//+","/")
    end
    return (gsub(pth,"//+","/"))
end

function file.iswritable(name)
    local a = lfs.attributes(name) or lfs.attributes(file.dirname(name,"."))
    return a and a.permissions:sub(2,2) == "w"
end

function file.isreadable(name)
    local a = lfs.attributes(name)
    return a and a.permissions:sub(1,1) == "r"
end

file.is_readable = file.isreadable
file.is_writable = file.iswritable

-- todo: lpeg

function file.split_path(str)
    local t = { }
    str = gsub(str,"\\", "/")
    str = gsub(str,"(%a):([;/])", "%1\001%2")
    for name in gmatch(str,"([^;:]+)") do
        if name ~= "" then
            t[#t+1] = gsub(name,"\001",":")
        end
    end
    return t
end

function file.join_path(tab)
    return concat(tab,io.pathseparator) -- can have trailing //
end

function file.collapse_path(str)
    str = gsub(str,"/%./","/")
    local n, m = 1, 1
    while n > 0 or m > 0 do
        str, n = gsub(str,"[^/%.]+/%.%.$","")
        str, m = gsub(str,"[^/%.]+/%.%./","")
    end
    str = gsub(str,"([^/])/$","%1")
    str = gsub(str,"^%./","")
    str = gsub(str,"/%.$","")
    if str == "" then str = "." end
    return str
end

--~ print(file.collapse_path("a/./b/.."))
--~ print(file.collapse_path("a/aa/../b/bb"))
--~ print(file.collapse_path("a/../.."))
--~ print(file.collapse_path("a/.././././b/.."))
--~ print(file.collapse_path("a/./././b/.."))
--~ print(file.collapse_path("a/b/c/../.."))

function file.robustname(str)
    return (gsub(str,"[^%a%d%/%-%.\\]+","-"))
end

file.readdata = io.loaddata
file.savedata = io.savedata

function file.copy(oldname,newname)
    file.savedata(newname,io.loaddata(oldname))
end

-- lpeg variants, slightly faster, not always

--~ local period    = lpeg.P(".")
--~ local slashes   = lpeg.S("\\/")
--~ local noperiod  = 1-period
--~ local noslashes = 1-slashes
--~ local name      = noperiod^1

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.C(noperiod^1) * -1

--~ function file.extname(name)
--~     return pattern:match(name) or ""
--~ end

--~ local pattern = lpeg.Cs(((period * noperiod^1 * -1)/"" + 1)^1)

--~ function file.removesuffix(name)
--~     return pattern:match(name)
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * lpeg.C(noslashes^1) * -1

--~ function file.basename(name)
--~     return pattern:match(name) or name
--~ end

--~ local pattern = (noslashes^0 * slashes)^1 * lpeg.Cp() * noslashes^1 * -1

--~ function file.dirname(name)
--~     local p = pattern:match(name)
--~     if p then
--~         return name:sub(1,p-2)
--~     else
--~         return ""
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.Cp() * noperiod^1 * -1

--~ function file.addsuffix(name, suffix)
--~     local p = pattern:match(name)
--~     if p then
--~         return name
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * (noperiod^1 * period)^1 * lpeg.Cp() * noperiod^1 * -1

--~ function file.replacesuffix(name,suffix)
--~     local p = pattern:match(name)
--~     if p then
--~         return name:sub(1,p-2) .. "." .. suffix
--~     else
--~         return name .. "." .. suffix
--~     end
--~ end

--~ local pattern = (noslashes^0 * slashes)^0 * lpeg.Cp() * ((noperiod^1 * period)^1 * lpeg.Cp() + lpeg.P(true)) * noperiod^1 * -1

--~ function file.nameonly(name)
--~     local a, b = pattern:match(name)
--~     if b then
--~         return name:sub(a,b-2)
--~     elseif a then
--~         return name:sub(a)
--~     else
--~         return name
--~     end
--~ end

--~ local test = file.extname
--~ local test = file.basename
--~ local test = file.dirname
--~ local test = file.addsuffix
--~ local test = file.replacesuffix
--~ local test = file.nameonly

--~ print(1,test("./a/b/c/abd.def.xxx","!!!"))
--~ print(2,test("./../b/c/abd.def.xxx","!!!"))
--~ print(3,test("a/b/c/abd.def.xxx","!!!"))
--~ print(4,test("a/b/c/def.xxx","!!!"))
--~ print(5,test("a/b/c/def","!!!"))
--~ print(6,test("def","!!!"))
--~ print(7,test("def.xxx","!!!"))

--~ local tim = os.clock() for i=1,250000 do local ext = test("abd.def.xxx","!!!") end print(os.clock()-tim)

-- also rewrite previous

local letter    = lpeg.R("az","AZ") + lpeg.S("_-+")
local separator = lpeg.P("://")

local qualified = lpeg.P(".")^0 * lpeg.P("/") + letter*lpeg.P(":") + letter^1*separator + letter^1 * lpeg.P("/")
local rootbased = lpeg.P("/") + letter*lpeg.P(":")

-- ./name ../name  /name c: :// name/name

function file.is_qualified_path(filename)
    return qualified:match(filename)
end

function file.is_rootbased_path(filename)
    return rootbased:match(filename)
end

local slash  = lpeg.S("\\/")
local period = lpeg.P(".")
local drive  = lpeg.C(lpeg.R("az","AZ")) * lpeg.P(":")
local path   = lpeg.C(((1-slash)^0 * slash)^0)
local suffix = period * lpeg.C(lpeg.P(1-period)^0 * lpeg.P(-1))
local base   = lpeg.C((1-suffix)^0)

local pattern = (drive + lpeg.Cc("")) * (path + lpeg.Cc("")) * (base + lpeg.Cc("")) * (suffix + lpeg.Cc(""))

function file.splitname(str) -- returns drive, path, base, suffix
    return pattern:match(str)
end

-- function test(t) for k, v in pairs(t) do print(v, "=>", file.splitname(v)) end end
--
-- test { "c:", "c:/aa", "c:/aa/bb", "c:/aa/bb/cc", "c:/aa/bb/cc.dd", "c:/aa/bb/cc.dd.ee" }
-- test { "c:", "c:aa", "c:aa/bb", "c:aa/bb/cc", "c:aa/bb/cc.dd", "c:aa/bb/cc.dd.ee" }
-- test { "/aa", "/aa/bb", "/aa/bb/cc", "/aa/bb/cc.dd", "/aa/bb/cc.dd.ee" }
-- test { "aa", "aa/bb", "aa/bb/cc", "aa/bb/cc.dd", "aa/bb/cc.dd.ee" }


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-md5'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This also provides file checksums and checkers.

local gsub, format, byte = string.gsub, string.format, string.byte

local function convert(str,fmt)
    return (gsub(md5.sum(str),".",function(chr) return format(fmt,byte(chr)) end))
end

if not md5.HEX then function md5.HEX(str) return convert(str,"%02X") end end
if not md5.hex then function md5.hex(str) return convert(str,"%02x") end end
if not md5.dec then function md5.dec(str) return convert(str,"%03i") end end

--~ if not md5.HEX then
--~     local function remap(chr) return format("%02X",byte(chr)) end
--~     function md5.HEX(str) return (gsub(md5.sum(str),".",remap)) end
--~ end
--~ if not md5.hex then
--~     local function remap(chr) return format("%02x",byte(chr)) end
--~     function md5.hex(str) return (gsub(md5.sum(str),".",remap)) end
--~ end
--~ if not md5.dec then
--~     local function remap(chr) return format("%03i",byte(chr)) end
--~     function md5.dec(str) return (gsub(md5.sum(str),".",remap)) end
--~ end

file.needs_updating_threshold = 1

function file.needs_updating(oldname,newname) -- size modification access change
    local oldtime = lfs.attributes(oldname, modification)
    local newtime = lfs.attributes(newname, modification)
    if newtime >= oldtime then
        return false
    elseif oldtime - newtime < file.needs_updating_threshold then
        return false
    else
        return true
    end
end

function file.checksum(name)
    if md5 then
        local data = io.loaddata(name)
        if data then
            return md5.HEX(data)
        end
    end
    return nil
end

function file.loadchecksum(name)
    if md5 then
        local data = io.loaddata(name .. ".md5")
        return data and data:gsub("%s","")
    end
    return nil
end

function file.savechecksum(name, checksum)
    if not checksum then checksum = file.checksum(name) end
    if checksum then
        io.savedata(name .. ".md5",checksum)
        return checksum
    end
    return nil
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-dir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local find, gmatch = string.find, string.gmatch

dir = dir or { }

-- optimizing for no string.find (*) does not save time

local attributes = lfs.attributes
local walkdir    = lfs.dir

local function glob_pattern(path,patt,recurse,action)
    local ok, scanner
    if path == "/" then
        ok, scanner = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
    else
        ok, scanner = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
    end
    if ok and type(scanner) == "function" then
        if not find(path,"/$") then path = path .. '/' end
        for name in scanner do
            local full = path .. name
            local mode = attributes(full,'mode')
            if mode == 'file' then
                if find(full,patt) then
                    action(full)
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                glob_pattern(full,patt,recurse,action)
            end
        end
    end
end

dir.glob_pattern = glob_pattern

local P, S, R, C, Cc, Cs, Ct, Cv, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cv, lpeg.V

local pattern = Ct {
    [1] = (C(P(".") + P("/")^1) + C(R("az","AZ") * P(":") * P("/")^0) + Cc("./")) * V(2) * V(3),
    [2] = C(((1-S("*?/"))^0 * P("/"))^0),
    [3] = C(P(1)^0)
}

local filter = Cs ( (
    P("**") / ".*" +
    P("*")  / "[^/]*" +
    P("?")  / "[^/]" +
    P(".")  / "%%." +
    P("+")  / "%%+" +
    P("-")  / "%%-" +
    P(1)
)^0 )

local function glob(str,t)
    if type(str) == "table" then
        local t = t or { }
        for s=1,#str do
            glob(str[s],t)
        end
        return t
    elseif lfs.isfile(str) then
        local t = t or { }
        t[#t+1] = str
        return t
    else
        local split = pattern:match(str)
        if split then
            local t = t or { }
            local action = action or function(name) t[#t+1] = name end
            local root, path, base = split[1], split[2], split[3]
            local recurse = find(base,"%*%*")
            local start = root .. path
            local result = filter:match(start .. base)
            glob_pattern(start,result,recurse,action)
            return t
        else
            return { }
        end
    end
end

dir.glob = glob

--~ list = dir.glob("**/*.tif")
--~ list = dir.glob("/**/*.tif")
--~ list = dir.glob("./**/*.tif")
--~ list = dir.glob("oeps/**/*.tif")
--~ list = dir.glob("/oeps/**/*.tif")

local function globfiles(path,recurse,func,files) -- func == pattern or function
    if type(func) == "string" then
        local s = func -- alas, we need this indirect way
        func = function(name) return find(name,s) end
    end
    files = files or { }
    for name in walkdir(path) do
        if find(name,"^%.") then
            --- skip
        else
            local mode = attributes(name,'mode')
            if mode == "directory" then
                if recurse then
                    globfiles(path .. "/" .. name,recurse,func,files)
                end
            elseif mode == "file" then
                if func then
                    if func(name) then
                        files[#files+1] = path .. "/" .. name
                    end
                else
                    files[#files+1] = path .. "/" .. name
                end
            end
        end
    end
    return files
end

dir.globfiles = globfiles

-- t = dir.glob("c:/data/develop/context/sources/**/????-*.tex")
-- t = dir.glob("c:/data/develop/tex/texmf/**/*.tex")
-- t = dir.glob("c:/data/develop/context/texmf/**/*.tex")
-- t = dir.glob("f:/minimal/tex/**/*")
-- print(dir.ls("f:/minimal/tex/**/*"))
-- print(dir.ls("*.tex"))

function dir.ls(pattern)
    return table.concat(glob(pattern),"\n")
end

--~ mkdirs("temp")
--~ mkdirs("a/b/c")
--~ mkdirs(".","/a/b/c")
--~ mkdirs("a","b","c")

local make_indeed = true -- false

if string.find(os.getenv("PATH"),";") then

    function dir.mkdirs(...)
        local str, pth = "", ""
        for _, s in ipairs({...}) do
            if s ~= "" then
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        local first, middle, last
        local drive = false
        first, middle, last = str:match("^(//)(//*)(.*)$")
        if first then
            -- empty network path == local path
        else
            first, last = str:match("^(//)/*(.-)$")
            if first then
                middle, last = str:match("([^/]+)/+(.-)$")
                if middle then
                    pth = "//" .. middle
                else
                    pth = "//" .. last
                    last = ""
                end
            else
                first, middle, last = str:match("^([a-zA-Z]:)(/*)(.-)$")
                if first then
                    pth, drive = first .. middle, true
                else
                    middle, last = str:match("^(/*)(.-)$")
                    if not middle then
                        last = str
                    end
                end
            end
        end
        for s in gmatch(last,"[^/]+") do
            if pth == "" then
                pth = s
            elseif drive then
                pth, drive = pth .. s, false
            else
                pth = pth .. "/" .. s
            end
            if make_indeed and not lfs.isdir(pth) then
                lfs.mkdir(pth)
            end
        end
        return pth, (lfs.isdir(pth) == true)
    end

--~         print(dir.mkdirs("","","a","c"))
--~         print(dir.mkdirs("a"))
--~         print(dir.mkdirs("a:"))
--~         print(dir.mkdirs("a:/b/c"))
--~         print(dir.mkdirs("a:b/c"))
--~         print(dir.mkdirs("a:/bbb/c"))
--~         print(dir.mkdirs("/a/b/c"))
--~         print(dir.mkdirs("/aaa/b/c"))
--~         print(dir.mkdirs("//a/b/c"))
--~         print(dir.mkdirs("///a/b/c"))
--~         print(dir.mkdirs("a/bbb//ccc/"))

    function dir.expand_name(str)
        local first, nothing, last = str:match("^(//)(//*)(.*)$")
        if first then
            first = lfs.currentdir() .. "/"
            first = first:gsub("\\","/")
        end
        if not first then
            first, last = str:match("^(//)/*(.*)$")
        end
        if not first then
            first, last = str:match("^([a-zA-Z]:)(.*)$")
            if first and not find(last,"^/") then
                local d = lfs.currentdir()
                if lfs.chdir(first) then
                    first = lfs.currentdir()
                    first = first:gsub("\\","/")
                end
                lfs.chdir(d)
            end
        end
        if not first then
            first, last = lfs.currentdir(), str
            first = first:gsub("\\","/")
        end
        last = last:gsub("//","/")
        last = last:gsub("/%./","/")
        last = last:gsub("^/*","")
        first = first:gsub("/*$","")
        if last == "" then
            return first
        else
            return first .. "/" .. last
        end
    end

else

    function dir.mkdirs(...)
        local str, pth = "", ""
        for _, s in ipairs({...}) do
            if s ~= "" then
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        str = str:gsub("/+","/")
        if find(str,"^/") then
            pth = "/"
            for s in gmatch(str,"[^/]+") do
                local first = (pth == "/")
                if first then
                    pth = pth .. s
                else
                    pth = pth .. "/" .. s
                end
                if make_indeed and not first and not lfs.isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        else
            pth = "."
            for s in gmatch(str,"[^/]+") do
                pth = pth .. "/" .. s
                if make_indeed and not lfs.isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        end
        return pth, (lfs.isdir(pth) == true)
    end

--~         print(dir.mkdirs("","","a","c"))
--~         print(dir.mkdirs("a"))
--~         print(dir.mkdirs("/a/b/c"))
--~         print(dir.mkdirs("/aaa/b/c"))
--~         print(dir.mkdirs("//a/b/c"))
--~         print(dir.mkdirs("///a/b/c"))
--~         print(dir.mkdirs("a/bbb//ccc/"))

    function dir.expand_name(str)
        if not find(str,"^/") then
            str = lfs.currentdir() .. "/" .. str
        end
        str = str:gsub("//","/")
        str = str:gsub("/%./","/")
        return str
    end

end

dir.makedirs = dir.mkdirs


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-boolean'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

boolean = boolean or { }

local type, tonumber = type, tonumber

function boolean.tonumber(b)
    if b then return 1 else return 0 end
end

function toboolean(str,tolerant)
    if tolerant then
        local tstr = type(str)
        if tstr == "string" then
            return str == "true" or str == "yes" or str == "on" or str == "1" or str == "t"
        elseif tstr == "number" then
            return tonumber(str) ~= 0
        elseif tstr == "nil" then
            return false
        else
            return str
        end
    elseif str == "true" then
        return true
    elseif str == "false" then
        return false
    else
        return str
    end
end

function string.is_boolean(str)
    if type(str) == "string" then
        if str == "true" or str == "yes" or str == "on" or str == "t" then
            return true
        elseif str == "false" or str == "no" or str == "off" or str == "f" then
            return false
        end
    end
    return nil
end

function boolean.alwaystrue()
    return true
end

function boolean.falsetrue()
    return false
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-math'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local floor, sin, cos, tan = math.floor, math.sin, math.cos, math.tan

if not math.round then
    function math.round(x)
        return floor(x + 0.5)
    end
end

if not math.div then
    function math.div(n,m)
        return floor(n/m)
    end
end

if not math.mod then
    function math.mod(n,m)
        return n % m
    end
end

local pipi = 2*math.pi/360

function math.sind(d)
    return sin(d*pipi)
end

function math.cosd(d)
    return cos(d*pipi)
end

function math.tand(d)
    return tan(d*pipi)
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-utils'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- hm, quite unreadable

if not utils        then utils        = { } end
if not utils.merger then utils.merger = { } end
if not utils.lua    then utils.lua    = { } end

utils.merger.m_begin = "begin library merge"
utils.merger.m_end   = "end library merge"
utils.merger.pattern =
    "%c+" ..
    "%-%-%s+" .. utils.merger.m_begin ..
    "%c+(.-)%c+" ..
    "%-%-%s+" .. utils.merger.m_end ..
    "%c+"

function utils.merger._self_fake_()
    return
        "-- " .. "created merged file" .. "\n\n" ..
        "-- " .. utils.merger.m_begin  .. "\n\n" ..
        "-- " .. utils.merger.m_end    .. "\n\n"
end

function utils.report(...)
    print(...)
end

utils.merger.strip_comment = true

function utils.merger._self_load_(name)
    local f, data = io.open(name), ""
    if f then
        utils.report("reading merge from %s",name)
        data = f:read("*all")
        f:close()
    else
        utils.report("unknown file to merge %s",name)
    end
    if data and utils.merger.strip_comment then
        -- saves some 20K
        data = data:gsub("%-%-~[^\n\r]*[\r\n]", "")
    end
    return data or ""
end

function utils.merger._self_save_(name, data)
    if data ~= "" then
        local f = io.open(name,'w')
        if f then
            utils.report("saving merge from %s",name)
            f:write(data)
            f:close()
        end
    end
end

function utils.merger._self_swap_(data,code)
    if data ~= "" then
        return (data:gsub(utils.merger.pattern, function(s)
            return "\n\n" .. "-- "..utils.merger.m_begin .. "\n" .. code .. "\n" .. "-- "..utils.merger.m_end .. "\n\n"
        end, 1))
    else
        return ""
    end
end

--~ stripper:
--~
--~ data = string.gsub(data,"%-%-~[^\n]*\n","")
--~ data = string.gsub(data,"\n\n+","\n")

function utils.merger._self_libs_(libs,list)
    local result, f, frozen = { }, nil, false
    result[#result+1] = "\n"
    if type(libs) == 'string' then libs = { libs } end
    if type(list) == 'string' then list = { list } end
    local foundpath = nil
    for _, lib in ipairs(libs) do
        for _, pth in ipairs(list) do
            pth = string.gsub(pth,"\\","/") -- file.clean_path
            utils.report("checking library path %s",pth)
            local name = pth .. "/" .. lib
            if lfs.isfile(name) then
                foundpath = pth
            end
        end
        if foundpath then break end
    end
    if foundpath then
        utils.report("using library path %s",foundpath)
        local right, wrong = { }, { }
        for _, lib in ipairs(libs) do
            local fullname = foundpath .. "/" .. lib
            if lfs.isfile(fullname) then
            --  right[#right+1] = lib
                utils.report("merging library %s",fullname)
                result[#result+1] = "do -- create closure to overcome 200 locals limit"
                result[#result+1] = io.loaddata(fullname,true)
                result[#result+1] = "end -- of closure"
            else
            --  wrong[#wrong+1] = lib
                utils.report("no library %s",fullname)
            end
        end
        if #right > 0 then
            utils.report("merged libraries: %s",table.concat(right," "))
        end
        if #wrong > 0 then
            utils.report("skipped libraries: %s",table.concat(wrong," "))
        end
    else
        utils.report("no valid library path found")
    end
    return table.concat(result, "\n\n")
end

function utils.merger.selfcreate(libs,list,target)
    if target then
        utils.merger._self_save_(
            target,
            utils.merger._self_swap_(
                utils.merger._self_fake_(),
                utils.merger._self_libs_(libs,list)
            )
        )
    end
end

function utils.merger.selfmerge(name,libs,list,target)
    utils.merger._self_save_(
        target or name,
        utils.merger._self_swap_(
            utils.merger._self_load_(name),
            utils.merger._self_libs_(libs,list)
        )
    )
end

function utils.merger.selfclean(name)
    utils.merger._self_save_(
        name,
        utils.merger._self_swap_(
            utils.merger._self_load_(name),
            ""
        )
    )
end

function utils.lua.compile(luafile, lucfile, cleanup, strip) -- defaults: cleanup=false strip=true
 -- utils.report("compiling",luafile,"into",lucfile)
    os.remove(lucfile)
    local command = "-o " .. string.quote(lucfile) .. " " .. string.quote(luafile)
    if strip ~= false then
        command = "-s " .. command
    end
    local done = (os.spawn("texluac " .. command) == 0) or (os.spawn("luac " .. command) == 0)
    if done and cleanup == true and lfs.isfile(lucfile) and lfs.isfile(luafile) then
     -- utils.report("removing",luafile)
        os.remove(luafile)
    end
    return done
end



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['l-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

aux = aux or { }

local concat, format, gmatch = table.concat, string.format, string.gmatch
local tostring, type = tostring, type

local space     = lpeg.P(' ')
local equal     = lpeg.P("=")
local comma     = lpeg.P(",")
local lbrace    = lpeg.P("{")
local rbrace    = lpeg.P("}")
local nobrace   = 1 - (lbrace+rbrace)
local nested    = lpeg.P{ lbrace * (nobrace + lpeg.V(1))^0 * rbrace }
local spaces    = space^0

local value     = lpeg.P(lbrace * lpeg.C((nobrace + nested)^0) * rbrace) + lpeg.C((nested + (1-comma))^0)

local key       = lpeg.C((1-equal-comma)^1)
local pattern_a = (space+comma)^0 * (key * equal * value + key * lpeg.C(""))
local pattern_c = (space+comma)^0 * (key * equal * value)

local key       = lpeg.C((1-space-equal-comma)^1)
local pattern_b = spaces * comma^0 * spaces * (key * ((spaces * equal * spaces * value) + lpeg.C("")))

-- "a=1, b=2, c=3, d={a{b,c}d}, e=12345, f=xx{a{b,c}d}xx, g={}" : outer {} removes, leading spaces ignored

local hash = { }

local function set(key,value) -- using Carg is slower here
    hash[key] = value
end

local pattern_a_s = (pattern_a/set)^1
local pattern_b_s = (pattern_b/set)^1
local pattern_c_s = (pattern_c/set)^1

aux.settings_to_hash_pattern_a = pattern_a_s
aux.settings_to_hash_pattern_b = pattern_b_s
aux.settings_to_hash_pattern_c = pattern_c_s

function aux.make_settings_to_hash_pattern(set,how)
    if how == "strict" then
        return (pattern_c/set)^1
    elseif how == "tolerant" then
        return (pattern_b/set)^1
    else
        return (pattern_a/set)^1
    end
end

function aux.settings_to_hash(str)
    if str and str ~= "" then
        hash = { }
        if moretolerant then
            pattern_b_s:match(str)
        else
            pattern_a_s:match(str)
        end
        return hash
    else
        return { }
    end
end

function aux.settings_to_hash_tolerant(str)
    if str and str ~= "" then
        hash = { }
        pattern_b_s:match(str)
        return hash
    else
        return { }
    end
end

function aux.settings_to_hash_strict(str)
    if str and str ~= "" then
        hash = { }
        pattern_c_s:match(str)
        return next(hash) and hash
    else
        return nil
    end
end

local seperator = comma * space^0
local value     = lpeg.P(lbrace * lpeg.C((nobrace + nested)^0) * rbrace) + lpeg.C((nested + (1-comma))^0)
local pattern   = lpeg.Ct(value*(seperator*value)^0)

-- "aap, {noot}, mies" : outer {} removes, leading spaces ignored

aux.settings_to_array_pattern = pattern

function aux.settings_to_array(str)
    if not str or str == "" then
        return { }
    else
        return pattern:match(str)
    end
end

local function set(t,v)
    t[#t+1] = v
end

local value   = lpeg.P(lpeg.Carg(1)*value) / set
local pattern = value*(seperator*value)^0 * lpeg.Carg(1)

function aux.add_settings_to_array(t,str)
    return pattern:match(str, nil, t)
end

function aux.hash_to_string(h,separator,yes,no,strict,omit)
    if h then
        local t, s = { }, table.sortedkeys(h)
        omit = omit and table.tohash(omit)
        for i=1,#s do
            local key = s[i]
            if not omit or not omit[key] then
                local value = h[key]
                if type(value) == "boolean" then
                    if yes and no then
                        if value then
                            t[#t+1] = key .. '=' .. yes
                        elseif not strict then
                            t[#t+1] = key .. '=' .. no
                        end
                    elseif value or not strict then
                        t[#t+1] = key .. '=' .. tostring(value)
                    end
                else
                    t[#t+1] = key .. '=' .. value
                end
            end
        end
        return concat(t,separator or ",")
    else
        return ""
    end
end

function aux.array_to_string(a,separator)
    if a then
        return concat(a,separator or ",")
    else
        return ""
    end
end

function aux.settings_to_set(str,t)
    t = t or { }
    for s in gmatch(str,"%s*([^,]+)") do
        t[s] = true
    end
    return t
end

-- temporary here

function aux.getparameters(self,class,parentclass,settings)
    local sc = self[class]
    if not sc then
        sc = table.clone(self[parent])
        self[class] = sc
    end
    aux.add_settings_to_array(sc, settings)
end

-- temporary here

local digit    = lpeg.R("09")
local period   = lpeg.P(".")
local zero     = lpeg.P("0")

--~ local finish   = lpeg.P(-1)
--~ local nodigit  = (1-digit) + finish
--~ local case_1   = (period * zero^1 * #nodigit)/"" -- .000
--~ local case_2   = (period * (1-(zero^0/"") * #nodigit)^1 * (zero^0/"") * nodigit) -- .010 .10 .100100

local trailingzeros = zero^0 * -digit -- suggested by Roberto R
local case_1 = period * trailingzeros / ""
local case_2 = period * (digit - trailingzeros)^1 * (trailingzeros / "")

local number   = digit^1 * (case_1 + case_2)
local stripper = lpeg.Cs((number + 1)^0)

--~ local sample = "bla 11.00 bla 11 bla 0.1100 bla 1.00100 bla 0.00 bla 0.001 bla 1.1100 bla 0.100100100 bla 0.00100100100"
--~ collectgarbage("collect")
--~ str = string.rep(sample,10000)
--~ local ts = os.clock()
--~ stripper:match(str)
--~ print(#str, os.clock()-ts, stripper:match(sample))

function aux.strip_zeros(str)
    return stripper:match(str)
end

function aux.definetable(target) -- defines undefined tables
    local composed, t = nil, { }
    for name in gmatch(target,"([^%.]+)") do
        if composed then
            composed = composed .. "." .. name
        else
            composed = name
        end
        t[#t+1] = format("%s = %s or { }",composed,composed)
    end
    return concat(t,"\n")
end

function aux.accesstable(target)
    local t = _G
    for name in gmatch(target,"([^%.]+)") do
        t = t[name]
    end
    return t
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-tab'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>The parser used here is inspired by the variant discussed in the lua book, but
handles comment and processing instructions, has a different structure, provides
parent access; a first version used different trickery but was less optimized to we
went this route. First we had a find based parser, now we have an <l n='lpeg'/> based one.
The find based parser can be found in l-xml-edu.lua along with other older code.</p>

<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>

<p>Beware, the interface may change. For instance at, ns, tg, dt may get more
verbose names. Once the code is stable we will also remove some tracing and
optimize the code.</p>
--ldx]]--

xml = xml or { }

--~ local xml = xml

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, setmetatable = type, next, setmetatable
local format, lower, find = string.format, string.lower, string.find

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers.</p>
--ldx]]--

local trace_remap = false

if trackers then
    trackers.register("xml.remap", function(v) trace_remap = v end)
end

function xml.settrace(str,value)
    if str == "remap" then
        trace_remap = value or false
    end
end

--[[ldx--
<p>First a hack to enable namespace resolving. A namespace is characterized by
a <l n='url'/>. The following function associates a namespace prefix with a
pattern. We use <l n='lpeg'/>, which in this case is more than twice as fast as a
find based solution where we loop over an array of patterns. Less code and
much cleaner.</p>
--ldx]]--

xml.xmlns = xml.xmlns or { }

local check = lpeg.P(false)
local parse = check

--[[ldx--
<p>The next function associates a namespace prefix with an <l n='url'/>. This
normally happens independent of parsing.</p>

<typing>
xml.registerns("mml","mathml")
</typing>
--ldx]]--

function xml.registerns(namespace, pattern) -- pattern can be an lpeg
    check = check + lpeg.C(lpeg.P(lower(pattern))) / namespace
    parse = lpeg.P { lpeg.P(check) + 1 * lpeg.V(1) }
end

--[[ldx--
<p>The next function also registers a namespace, but this time we map a
given namespace prefix onto a registered one, using the given
<l n='url'/>. This used for attributes like <t>xmlns:m</t>.</p>

<typing>
xml.checkns("m","http://www.w3.org/mathml")
</typing>
--ldx]]--

function xml.checkns(namespace,url)
    local ns = parse:match(lower(url))
    if ns and namespace ~= ns then
        xml.xmlns[namespace] = ns
    end
end

--[[ldx--
<p>Next we provide a way to turn an <l n='url'/> into a registered
namespace. This used for the <t>xmlns</t> attribute.</p>

<typing>
resolvedns = xml.resolvens("http://www.w3.org/mathml")
</typing>

This returns <t>mml</t>.
--ldx]]--

function xml.resolvens(url)
     return parse:match(lower(url)) or ""
end

--[[ldx--
<p>A namespace in an element can be remapped onto the registered
one efficiently by using the <t>xml.xmlns</t> table.</p>
--ldx]]--

--[[ldx--
<p>This version uses <l n='lpeg'/>. We follow the same approach as before, stack and top and
such. This version is about twice as fast which is mostly due to the fact that
we don't have to prepare the stream for cdata, doctype etc etc. This variant is
is dedicated to Luigi Scarso, who challenged me with 40 megabyte <l n='xml'/> files that
took 12.5 seconds to load (1.5 for file io and the rest for tree building). With
the <l n='lpeg'/> implementation we got that down to less 7.3 seconds. Loading the 14
<l n='context'/> interface definition files (2.6 meg) went down from 1.05 seconds to 0.55.</p>

<p>Next comes the parser. The rather messy doctype definition comes in many
disguises so it is no surprice that later on have to dedicate quite some
<l n='lpeg'/> code to it.</p>

<typing>
<!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
<!DOCTYPE Something PUBLIC "... ..." "..." >
<!DOCTYPE Something SYSTEM "... ..." [ ... ] >
<!DOCTYPE Something SYSTEM "... ..." >
<!DOCTYPE Something [ ... ] >
<!DOCTYPE Something >
</typing>

<p>The code may look a bit complex but this is mostly due to the fact that we
resolve namespaces and attach metatables. There is only one public function:</p>

<typing>
local x = xml.convert(somestring)
</typing>

<p>An optional second boolean argument tells this function not to create a root
element.</p>

<p>Valid entities are:</p>

<typing>
<!ENTITY xxxx SYSTEM "yyyy" NDATA zzzz>
<!ENTITY xxxx PUBLIC "yyyy" >
<!ENTITY xxxx "yyyy" >
</typing>
--ldx]]--

xml.strip_cm_and_dt = false -- an extra global flag, in case we have many includes

-- not just one big nested table capture (lpeg overflow)

local nsremap, resolvens = xml.xmlns, xml.resolvens

local stack, top, dt, at, xmlns, errorstr, entities = {}, {}, {}, {}, {}, nil, {}

local mt = { __tostring = xml.text }

function xml.check_error(top,toclose)
    return ""
end

local strip   = false
local cleanup = false

function xml.set_text_cleanup(fnc)
    cleanup = fnc
end

local function add_attribute(namespace,tag,value)
    if cleanup and #value > 0 then
        value = cleanup(value) -- new
    end
    if tag == "xmlns" then
        xmlns[#xmlns+1] = resolvens(value)
        at[tag] = value
    elseif namespace == "xmlns" then
        xml.checkns(tag,value)
        at["xmlns:" .. tag] = value
    else
        at[tag] = value
    end
end

local function add_begin(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = stack[#stack] }
    setmetatable(top, mt)
    dt = top.dt
    stack[#stack+1] = top
    at = { }
end

local function add_end(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local toclose = remove(stack)
    top = stack[#stack]
    if #stack < 1 then
        errorstr = format("nothing to close with %s %s", tag, xml.check_error(top,toclose) or "")
    elseif toclose.tg ~= tag then -- no namespace check
        errorstr = format("unable to close %s with %s %s", toclose.tg, tag, xml.check_error(top,toclose) or "")
    end
    dt = top.dt
    dt[#dt+1] = toclose
    dt[0] = top
    if toclose.at.xmlns then
        remove(xmlns)
    end
end

local function add_empty(spacing, namespace, tag)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    local resolved = (namespace == "" and xmlns[#xmlns]) or nsremap[namespace] or namespace
    top = stack[#stack]
    dt = top.dt
    local t = { ns=namespace or "", rn=resolved, tg=tag, at=at, dt={}, __p__ = top }
    dt[#dt+1] = t
    setmetatable(t, mt)
    if at.xmlns then
        remove(xmlns)
    end
    at = { }
end

local function add_text(text)
    if cleanup and #text > 0 then
        dt[#dt+1] = cleanup(text)
    else
        dt[#dt+1] = text
    end
end

local function add_special(what, spacing, text)
    if #spacing > 0 then
        dt[#dt+1] = spacing
    end
    if strip and (what == "@cm@" or what == "@dt@") then
        -- forget it
    else
        dt[#dt+1] = { special=true, ns="", tg=what, dt={text} }
    end
end

local function set_message(txt)
    errorstr = "garbage at the end of the file: " .. gsub(txt,"([ \n\r\t]*)","")
end

local P, S, R, C, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V

local space            = S(' \r\n\t')
local open             = P('<')
local close            = P('>')
local squote           = S("'")
local dquote           = S('"')
local equal            = P('=')
local slash            = P('/')
local colon            = P(':')
local valid            = R('az', 'AZ', '09') + S('_-.')
local name_yes         = C(valid^1) * colon * C(valid^1)
local name_nop         = C(P(true)) * C(valid^1)
local name             = name_yes + name_nop

local utfbom           = P('\000\000\254\255') + P('\255\254\000\000') +
                         P('\255\254') + P('\254\255') + P('\239\187\191') -- no capture

local spacing          = C(space^0)
local justtext         = C((1-open)^1)
local somespace        = space^1
local optionalspace    = space^0

local value            = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote)
local attribute        = (somespace * name * optionalspace * equal * optionalspace * value) / add_attribute
local attributes       = attribute^0

local text             = justtext / add_text
local balanced         = P { "[" * ((1 - S"[]") + V(1))^0 * "]" } -- taken from lpeg manual, () example

local emptyelement     = (spacing * open         * name * attributes * optionalspace * slash * close) / add_empty
local beginelement     = (spacing * open         * name * attributes * optionalspace         * close) / add_begin
local endelement       = (spacing * open * slash * name              * optionalspace         * close) / add_end

local begincomment     = open * P("!--")
local endcomment       = P("--") * close
local begininstruction = open * P("?")
local endinstruction   = P("?") * close
local begincdata       = open * P("![CDATA[")
local endcdata         = P("]]") * close

local someinstruction  = C((1 - endinstruction)^0)
local somecomment      = C((1 - endcomment    )^0)
local somecdata        = C((1 - endcdata      )^0)

local function normalentity(k,v  ) entities[k] = v end
local function systementity(k,v,n) entities[k] = v end
local function publicentity(k,v,n) entities[k] = v end

local begindoctype     = open * P("!DOCTYPE")
local enddoctype       = close
local beginset         = P("[")
local endset           = P("]")
local doctypename      = C((1-somespace-close)^0)
local elementdoctype   = optionalspace * P("<!ELEMENT") * (1-close)^0 * close

local normalentitytype = (doctypename * somespace * value)/normalentity
local publicentitytype = (doctypename * somespace * P("PUBLIC") * somespace * value)/publicentity
local systementitytype = (doctypename * somespace * P("SYSTEM") * somespace * value * somespace * P("NDATA") * somespace * doctypename)/systementity
local entitydoctype    = optionalspace * P("<!ENTITY") * somespace * (systementitytype + publicentitytype + normalentitytype) * optionalspace * close

local doctypeset       = beginset * optionalspace * P(elementdoctype + entitydoctype + space)^0 * optionalspace * endset
local definitiondoctype= doctypename * somespace * doctypeset
local publicdoctype    = doctypename * somespace * P("PUBLIC") * somespace * value * somespace * value * somespace * doctypeset
local systemdoctype    = doctypename * somespace * P("SYSTEM") * somespace * value * somespace * doctypeset
local simpledoctype    = (1-close)^1 -- * balanced^0
local somedoctype      = C((somespace * (publicdoctype + systemdoctype + definitiondoctype + simpledoctype) * optionalspace)^0)

local instruction      = (spacing * begininstruction * someinstruction * endinstruction) / function(...) add_special("@pi@",...) end
local comment          = (spacing * begincomment     * somecomment     * endcomment    ) / function(...) add_special("@cm@",...) end
local cdata            = (spacing * begincdata       * somecdata       * endcdata      ) / function(...) add_special("@cd@",...) end
local doctype          = (spacing * begindoctype     * somedoctype     * enddoctype    ) / function(...) add_special("@dt@",...) end

--  nicer but slower:
--
--  local instruction = (lpeg.Cc("@pi@") * spacing * begininstruction * someinstruction * endinstruction) / add_special
--  local comment     = (lpeg.Cc("@cm@") * spacing * begincomment     * somecomment     * endcomment    ) / add_special
--  local cdata       = (lpeg.Cc("@cd@") * spacing * begincdata       * somecdata       * endcdata      ) / add_special
--  local doctype     = (lpeg.Cc("@dt@") * spacing * begindoctype     * somedoctype     * enddoctype    ) / add_special

local trailer = space^0 * (justtext/set_message)^0

--  comment + emptyelement + text + cdata + instruction + V("parent"), -- 6.5 seconds on 40 MB database file
--  text + comment + emptyelement + cdata + instruction + V("parent"), -- 5.8
--  text + V("parent") + emptyelement + comment + cdata + instruction, -- 5.5

local grammar = P { "preamble",
    preamble = utfbom^0 * instruction^0 * (doctype + comment + instruction)^0 * V("parent") * trailer,
    parent   = beginelement * V("children")^0 * endelement,
    children = text + V("parent") + emptyelement + comment + cdata + instruction,
}

-- todo: xml.new + properties like entities and strip and such (store in root)

function xml.convert(data, no_root, strip_cm_and_dt, given_entities) -- maybe use table met k/v (given_entities may disapear)
    strip = strip_cm_and_dt or xml.strip_cm_and_dt
    stack, top, at, xmlns, errorstr, result, entities = {}, {}, {}, {}, nil, nil, given_entities or {}
    stack[#stack+1] = top
    top.dt = { }
    dt = top.dt
    if not data or data == "" then
        errorstr = "empty xml file"
    elseif not grammar:match(data) then
        errorstr = "invalid xml file"
    else
        errorstr = ""
    end
    if errorstr and errorstr ~= "" then
        result = { dt = { { ns = "", tg = "error", dt = { errorstr }, at={}, er = true } }, error = true }
        setmetatable(stack, mt)
        if xml.error_handler then xml.error_handler("load",errorstr) end
    else
        result = stack[1]
    end
    if not no_root then
        result = { special = true, ns = "", tg = '@rt@', dt = result.dt, at={}, entities = entities }
        setmetatable(result, mt)
        local rdt = result.dt
        for k=1,#rdt do
            local v = rdt[k]
            if type(v) == "table" and not v.special then -- always table -)
                result.ri = k -- rootindex
                break
            end
        end
    end
    return result
end

--[[ldx--
<p>Packaging data in an xml like table is done with the following
function. Maybe it will go away (when not used).</p>
--ldx]]--

function xml.is_valid(root)
    return root and root.dt and root.dt[1] and type(root.dt[1]) == "table" and not root.dt[1].er
end

function xml.package(tag,attributes,data)
    local ns, tg = tag:match("^(.-):?([^:]+)$")
    local t = { ns = ns, tg = tg, dt = data or "", at = attributes or {} }
    setmetatable(t, mt)
    return t
end

function xml.is_valid(root)
    return root and not root.error
end

xml.error_handler = (logs and logs.report) or (input and logs.report) or print

--[[ldx--
<p>We cannot load an <l n='lpeg'/> from a filehandle so we need to load
the whole file first. The function accepts a string representing
a filename or a file handle.</p>
--ldx]]--

function xml.load(filename)
    if type(filename) == "string" then
        local f = io.open(filename,'r')
        if f then
            local root = xml.convert(f:read("*all"))
            f:close()
            return root
        else
            return xml.convert("")
        end
    elseif filename then -- filehandle
        return xml.convert(filename:read("*all"))
    else
        return xml.convert("")
    end
end

--[[ldx--
<p>When we inject new elements, we need to convert strings to
valid trees, which is what the next function does.</p>
--ldx]]--

function xml.toxml(data)
    if type(data) == "string" then
        local root = { xml.convert(data,true) }
        return (#root > 1 and root) or root[1]
    else
        return data
    end
end

--[[ldx--
<p>For copying a tree we use a dedicated function instead of the
generic table copier. Since we know what we're dealing with we
can speed up things a bit. The second argument is not to be used!</p>
--ldx]]--

local function copy(old,tables)
    if old then
        tables = tables or { }
        local new = { }
        if not tables[old] then
            tables[old] = new
        end
        for k,v in pairs(old) do
            new[k] = (type(v) == "table" and (tables[v] or copy(v, tables))) or v
        end
        local mt = getmetatable(old)
        if mt then
            setmetatable(new,mt)
        end
        return new
    else
        return { }
    end
end

xml.copy = copy

--[[ldx--
<p>In <l n='context'/> serializing the tree or parts of the tree is a major
actitivity which is why the following function is pretty optimized resulting
in a few more lines of code than needed. The variant that uses the formatting
function for all components is about 15% slower than the concatinating
alternative.</p>
--ldx]]--

-- todo: add <?xml version='1.0' standalone='yes'?> when not present

local fallbackhandle = (tex and tex.sprint) or io.write

local function serialize(e, handle, textconverter, attributeconverter, specialconverter, nocommands)
    if not e then
        return
    elseif not nocommands then
        local ec = e.command
        if ec ~= nil then -- we can have all kind of types
            if e.special then
                local etg, edt = e.tg, e.dt
                local spc = specialconverter and specialconverter[etg]
                if spc then
                    local result = spc(edt[1])
                    if result then
                        handle(result)
                        return
                    else
                        -- no need to handle any further
                    end
                end
            end
            local xc = xml.command
            if xc then
                xc(e,ec)
                return
            end
        end
    end
    handle = handle or fallbackhandle
    local etg = e.tg
    if etg then
        if e.special then
            local edt = e.dt
            local spc = specialconverter and specialconverter[etg]
            if spc then
                local result = spc(edt[1])
                if result then
                    handle(result)
                else
                    -- no need to handle any further
                end
            elseif etg == "@pi@" then
            --  handle(format("<?%s?>",edt[1]))
                handle("<?" .. edt[1] .. "?>")
            elseif etg == "@cm@" then
            --  handle(format("<!--%s-->",edt[1]))
                handle("<!--" .. edt[1] .. "-->")
            elseif etg == "@cd@" then
            --  handle(format("<![CDATA[%s]]>",edt[1]))
                handle("<![CDATA[" .. edt[1] .. "]]>")
            elseif etg == "@dt@" then
            --  handle(format("<!DOCTYPE %s>",edt[1]))
                handle("<!DOCTYPE " .. edt[1] .. ">")
            elseif etg == "@rt@" then
                serialize(edt,handle,textconverter,attributeconverter,specialconverter,nocommands)
            end
        else
            local ens, eat, edt, ern = e.ns, e.at, e.dt, e.rn
            local ats = eat and next(eat) and { } -- type test maybe faster
            if ats then
                if attributeconverter then
                    for k,v in next, eat do
                        ats[#ats+1] = format('%s=%q',k,attributeconverter(v))
                    end
                else
                    for k,v in next, eat do
                        ats[#ats+1] = format('%s=%q',k,v)
                    end
                end
            end
            if ern and trace_remap and ern ~= ens then
                ens = ern
            end
            if ens ~= "" then
                if edt and #edt > 0 then
                    if ats then
                    --  handle(format("<%s:%s %s>",ens,etg,concat(ats," ")))
                        handle("<" .. ens .. ":" .. etg .. " " .. concat(ats," ") .. ">")
                    else
                    --  handle(format("<%s:%s>",ens,etg))
                        handle("<" .. ens .. ":" .. etg .. ">")
                    end
                    for i=1,#edt do
                        local e = edt[i]
                        if type(e) == "string" then
                            if textconverter then
                                handle(textconverter(e))
                            else
                                handle(e)
                            end
                        else
                            serialize(e,handle,textconverter,attributeconverter,specialconverter,nocommands)
                        end
                    end
                --  handle(format("</%s:%s>",ens,etg))
                    handle("</" .. ens .. ":" .. etg .. ">")
                else
                    if ats then
                    --  handle(format("<%s:%s %s/>",ens,etg,concat(ats," ")))
                        handle("<" .. ens .. ":" .. etg .. " " .. concat(ats," ") .. "/>")
                    else
                    --  handle(format("<%s:%s/>",ens,etg))
                        handle("<" .. ens .. ":" .. etg .. "/>")
                    end
                end
            else
                if edt and #edt > 0 then
                    if ats then
                    --  handle(format("<%s %s>",etg,concat(ats," ")))
                        handle("<" .. etg .. " " .. concat(ats," ") .. ">")
                    else
                    --  handle(format("<%s>",etg))
                        handle("<" .. etg .. ">")
                    end
                    for i=1,#edt do
                        local ei = edt[i]
                        if type(ei) == "string" then
                            if textconverter then
                                handle(textconverter(ei))
                            else
                                handle(ei)
                            end
                        else
                            serialize(ei,handle,textconverter,attributeconverter,specialconverter,nocommands)
                        end
                    end
                --  handle(format("</%s>",etg))
                    handle("</" .. etg .. ">")
                else
                    if ats then
                    --  handle(format("<%s %s/>",etg,concat(ats," ")))
                        handle("<" .. etg .. " " .. concat(ats," ") .. "/>")
                    else
                    --  handle(format("<%s/>",etg))
                        handle("<" .. etg .. "/>")
                    end
                end
            end
        end
    elseif type(e) == "string" then
        if textconverter then
            handle(textconverter(e))
        else
            handle(e)
        end
    else
        for i=1,#e do
            local ei = e[i]
            if type(ei) == "string" then
                if textconverter then
                    handle(textconverter(ei))
                else
                    handle(ei)
                end
            else
                serialize(ei,handle,textconverter,attributeconverter,specialconverter,nocommands)
            end
        end
    end
end

xml.serialize = serialize

function xml.checkbom(root) -- can be made faster
    if root.ri then
        local dt, found = root.dt, false
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "table" and v.special and v.tg == "@pi" and find(v.dt,"xml.*version=") then
                found = true
                break
            end
        end
        if not found then
            insert(dt, 1, { special=true, ns="", tg="@pi@", dt = { "xml version='1.0' standalone='yes'"} } )
            insert(dt, 2, "\n" )
        end
    end
end

--[[ldx--
<p>At the cost of some 25% runtime overhead you can first convert the tree to a string
and then handle the lot.</p>
--ldx]]--

function xml.tostring(root) -- 25% overhead due to collecting
    if root then
        if type(root) == 'string' then
            return root
        elseif next(root) then -- next is faster than type (and >0 test)
            local result = { }
            serialize(root,function(s) result[#result+1] = s end) -- brrr, slow (direct printing is faster)
            return concat(result,"")
        end
    end
    return ""
end

--[[ldx--
<p>The next function operated on the content only and needs a handle function
that accepts a string.</p>
--ldx]]--

function xml.string(e,handle)
    if not handle or (e.special and e.tg ~= "@rt@") then
        -- nothing
    elseif e.tg then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                xml.string(edt[i],handle)
            end
        end
    else
        handle(e)
    end
end

--[[ldx--
<p>How you deal with saving data depends on your preferences. For a 40 MB database
file the timing on a 2.3 Core Duo are as follows (time in seconds):</p>

<lines>
1.3 : load data from file to string
6.1 : convert string into tree
5.3 : saving in file using xmlsave
6.8 : converting to string using xml.tostring
3.6 : saving converted string in file
</lines>

<p>The save function is given below.</p>
--ldx]]--

function xml.save(root,name)
    local f = io.open(name,"w")
    if f then
        xml.serialize(root,function(s) f:write(s) end)
        f:close()
    end
end

--[[ldx--
<p>A few helpers:</p>
--ldx]]--

function xml.body(root)
    return (root.ri and root.dt[root.ri]) or root
end

function xml.text(root)
    return (root and xml.tostring(root)) or ""
end

function xml.content(root) -- bugged
    return (root and root.dt and xml.tostring(root.dt)) or ""
end

function xml.isempty(root, pattern)
    if pattern == "" or pattern == "*" then
        pattern = nil
    end
    if pattern then
        -- todo
        return false
    else
        return not root or not root.dt or #root.dt == 0 or root.dt == ""
    end
end

--[[ldx--
<p>The next helper erases an element but keeps the table as it is,
and since empty strings are not serialized (effectively) it does
not harm. Copying the table would take more time. Usage:</p>

<typing>
dt[k] = xml.empty() or xml.empty(dt,k)
</typing>
--ldx]]--

function xml.empty(dt,k)
    if dt and k then
        dt[k] = ""
        return dt[k]
    else
        return ""
    end
end

--[[ldx--
<p>The next helper assigns a tree (or string). Usage:</p>

<typing>
dt[k] = xml.assign(root) or xml.assign(dt,k,root)
</typing>
--ldx]]--

function xml.assign(dt,k,root)
    if dt and k then
        dt[k] = (type(root) == "table" and xml.body(root)) or root
        return dt[k]
    else
        return xml.body(root)
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-pth'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, lower, gmatch, gsub, find, rep = string.format, string.lower, string.gmatch, string.gsub, string.find, string.rep

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers. Here we overload a previously defined
function.</p>
--ldx]]--

local trace_lpath = false

if trackers then
    trackers.register("xml.lpath", function(v) trace_lpath = v end)
end

local settrace = xml.settrace -- lxml-tab

function xml.settrace(str,value)
    if str == "lpath" then
        trace_lpath = value or false
    else
        settrace(str,value) -- lxml-tab
    end
end

--[[ldx--
<p>We've now arrived at an intersting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local lpathcalls  = 0 -- statistics
local lpathcached = 0 -- statistics

xml.functions   = xml.functions   or { }
xml.expressions = xml.expressions or { }

local functions   = xml.functions
local expressions = xml.expressions

local actions = {
    [10] = "stay",
    [11] = "parent",
    [12] = "subtree root",
    [13] = "document root",
    [14] = "any",
    [15] = "many",
    [16] = "initial",
    [20] = "match",
    [21] = "match one of",
    [22] = "match and attribute eq",
    [23] = "match and attribute ne",
    [24] = "match one of and attribute eq",
    [25] = "match one of and attribute ne",
    [27] = "has attribute",
    [28] = "has value",
    [29] = "fast match",
    [30] = "select",
    [31] = "expression",
    [40] = "processing instruction",
}

-- a rather dumb lpeg

local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

-- instead of using functions we just parse a few names which saves a call
-- later on

local lp_position  = P("position()") / "ps"
local lp_index     = P("index()")    / "id"
local lp_text      = P("text()")     / "tx"
local lp_name      = P("name()")     / "(ns~='' and ns..':'..tg)" -- "((rt.ns~='' and rt.ns..':'..rt.tg) or '')"
local lp_tag       = P("tag()")      / "tg" -- (rt.tg or '')
local lp_ns        = P("ns()")       / "ns" -- (rt.ns or '')
local lp_noequal   = P("!=")         / "~=" + P("<=") + P(">=") + P("==")
local lp_doequal   = P("=")          / "=="
local lp_attribute = P("@")          / "" * Cc("(at['") * R("az","AZ","--","__")^1 * Cc("'] or '')")

local lp_lua_function  = C(R("az","AZ","--","__")^1 * (P(".") * R("az","AZ","--","__")^1)^1) * P("(") / function(t) -- todo: better . handling
    return t .. "("
end

local lp_function  = C(R("az","AZ","--","__")^1) * P("(") / function(t) -- todo: better . handling
    if expressions[t] then
        return "expressions." .. t .. "("
    else
        return "expressions.error("
    end
end

local lparent  = lpeg.P("(")
local rparent  = lpeg.P(")")
local noparent = 1 - (lparent+rparent)
local nested   = lpeg.P{lparent * (noparent + lpeg.V(1))^0 * rparent}
local value    = lpeg.P(lparent * lpeg.C((noparent + nested)^0) * rparent) -- lpeg.P{"("*C(((1-S("()"))+V(1))^0)*")"}

-- if we use a dedicated namespace then we don't need to pass rt and k

local lp_special = (C(P("name")+P("text")+P("tag"))) * value / function(t,s)
    if expressions[t] then
        if s then
            return "expressions." .. t .. "(r,k," .. s ..")"
        else
            return "expressions." .. t .. "(r,k)"
        end
    else
        return "expressions.error(" .. t .. ")"
    end
end

local converter = lpeg.Cs ( (
    lp_position +
    lp_index +
    lp_text + lp_name + -- fast one
    lp_special +
    lp_noequal + lp_doequal +
    lp_attribute +
    lp_lua_function +
    lp_function +
1 )^1 )

-- expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1

local template = [[
    return function(expressions,r,d,k,e,dt,ns,tg,id,ps)
        local at, tx = e.at or { }, dt[1] or ""
        return %s
    end
]]

local function make_expression(str)
    str = converter:match(str)
    return str, loadstring(format(template,str))()
end

local map = { }

local space                    = S(' \r\n\t')
local squote                   = S("'")
local dquote                   = S('"')
local lparent                  = P('(')
local rparent                  = P(')')
local atsign                   = P('@')
local lbracket                 = P('[')
local rbracket                 = P(']')
local exclam                   = P('!')
local period                   = P('.')
local eq                       = P('==') + P('=')
local ne                       = P('<>') + P('!=')
local star                     = P('*')
local slash                    = P('/')
local colon                    = P(':')
local bar                      = P('|')
local hat                      = P('^')
local valid                    = R('az', 'AZ', '09') + S('_-')
local name_yes                 = C(valid^1 + star) * colon * C(valid^1 + star) -- permits ns:* *:tg *:*
local name_nop                 = Cc("*") * C(valid^1)
local name                     = name_yes + name_nop
local number                   = C((S('+-')^0 * R('09')^1)) / tonumber
local names                    = (bar^0 * name)^1
local morenames                = name * (bar^0 * name)^1
local instructiontag           = P('pi::')
local spacing                  = C(space^0)
local somespace                = space^1
local optionalspace            = space^0
local text                     = C(valid^0)
local value                    = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote)
local empty                    = 1-slash

local is_eq                    = lbracket * atsign * name * eq * value * rbracket
local is_ne                    = lbracket * atsign * name * ne * value * rbracket
local is_attribute             = lbracket * atsign * name              * rbracket
local is_value                 = lbracket *          value             * rbracket
local is_number                = lbracket *          number            * rbracket

local nobracket                = 1-(lbracket+rbracket)  -- must be improved
local is_expression            = lbracket * C(((C(nobracket^1))/make_expression)) * rbracket

local is_expression            = lbracket * (C(nobracket^1))/make_expression * rbracket

local is_one                   =          name
local is_none                  = exclam * name
local is_one_of                =          ((lparent * names * rparent) + morenames)
local is_none_of               = exclam * ((lparent * names * rparent) + morenames)

local stay                     = (period                )
local parent                   = (period * period       ) / function(   ) map[#map+1] = { 11             } end
local subtreeroot              = (slash + hat           ) / function(   ) map[#map+1] = { 12             } end
local documentroot             = (hat * hat             ) / function(   ) map[#map+1] = { 13             } end
local any                      = (star                  ) / function(   ) map[#map+1] = { 14             } end
local many                     = (star * star           ) / function(   ) map[#map+1] = { 15             } end
local initial                  = (hat * hat * hat       ) / function(   ) map[#map+1] = { 16             } end

local match                    = (is_one                ) / function(...) map[#map+1] = { 20, true , ... } end
local match_one_of             = (is_one_of             ) / function(...) map[#map+1] = { 21, true , ... } end
local dont_match               = (is_none               ) / function(...) map[#map+1] = { 20, false, ... } end
local dont_match_one_of        = (is_none_of            ) / function(...) map[#map+1] = { 21, false, ... } end

local match_and_eq             = (is_one     * is_eq    ) / function(...) map[#map+1] = { 22, true , ... } end
local match_and_ne             = (is_one     * is_ne    ) / function(...) map[#map+1] = { 23, true , ... } end
local dont_match_and_eq        = (is_none    * is_eq    ) / function(...) map[#map+1] = { 22, false, ... } end
local dont_match_and_ne        = (is_none    * is_ne    ) / function(...) map[#map+1] = { 23, false, ... } end

local match_one_of_and_eq      = (is_one_of  * is_eq    ) / function(...) map[#map+1] = { 24, true , ... } end
local match_one_of_and_ne      = (is_one_of  * is_ne    ) / function(...) map[#map+1] = { 25, true , ... } end
local dont_match_one_of_and_eq = (is_none_of * is_eq    ) / function(...) map[#map+1] = { 24, false, ... } end
local dont_match_one_of_and_ne = (is_none_of * is_ne    ) / function(...) map[#map+1] = { 25, false, ... } end

local has_attribute            = (is_one  * is_attribute) / function(...) map[#map+1] = { 27, true , ... } end
local has_value                = (is_one  * is_value    ) / function(...) map[#map+1] = { 28, true , ... } end
local dont_has_attribute       = (is_none * is_attribute) / function(...) map[#map+1] = { 27, false, ... } end
local dont_has_value           = (is_none * is_value    ) / function(...) map[#map+1] = { 28, false, ... } end
local position                 = (is_one  * is_number   ) / function(...) map[#map+1] = { 30, true,  ... } end
local dont_position            = (is_none * is_number   ) / function(...) map[#map+1] = { 30, false, ... } end

local expression               = (is_one  * is_expression)/ function(...) map[#map+1] = { 31, true,  ... } end
local dont_expression          = (is_none * is_expression)/ function(...) map[#map+1] = { 31, false, ... } end

local self_expression          = (         is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                          map[#map+1] = { 31, true,  "*", "*", ... } end
local dont_self_expression     = (exclam * is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                          map[#map+1] = { 31, false, "*", "*", ... } end

local instruction              = (instructiontag * text ) / function(...) map[#map+1] = { 40,        ... } end
local nothing                  = (empty                 ) / function(   ) map[#map+1] = { 15             } end -- 15 ?
local crap                     = (1-slash)^1

-- a few ugly goodies:

local docroottag               = P('^^')             / function(   ) map[#map+1] = { 12             } end
local subroottag               = P('^')              / function(   ) map[#map+1] = { 13             } end
local roottag                  = P('root::')         / function(   ) map[#map+1] = { 12             } end
local parenttag                = P('parent::')       / function(   ) map[#map+1] = { 11             } end
local childtag                 = P('child::')
local selftag                  = P('self::')

-- there will be more and order will be optimized

local selector = (
    instruction +
--  many + any + -- brrr, not here !
    parent + stay +
    dont_position + position +
    dont_match_one_of_and_eq + dont_match_one_of_and_ne +
    match_one_of_and_eq + match_one_of_and_ne +
    dont_match_and_eq + dont_match_and_ne +
    match_and_eq + match_and_ne +
    dont_expression + expression +
    dont_self_expression + self_expression +
    has_attribute + has_value +
    dont_match_one_of + match_one_of +
    dont_match + match +
    many + any +
    crap + empty
)

local grammar = P { "startup",
    startup  = (initial + documentroot + subtreeroot + roottag + docroottag + subroottag)^0 * V("followup"),
    followup = ((slash + parenttag + childtag + selftag)^0 * selector)^1,
}

local function compose(str)
    if not str or str == "" then
        -- wildcard
        return true
    elseif str == '/' then
        -- root
        return false
    else
        map = { }
        grammar:match(str)
        if #map == 0 then
            return true
        else
            local m = map[1][1]
            if #map == 1 then
                if m == 14 or m == 15 then
                    -- wildcard
                    return true
                elseif m == 12 then
                    -- root
                    return false
                end
            elseif #map == 2 and m == 12 and map[2][1] == 20 then
            --  return { { 29, map[2][2], map[2][3], map[2][4], map[2][5] } }
                map[2][1] = 29
                return { map[2] }
            end
            if m ~= 11 and m ~= 12 and m ~= 13 and m ~= 14 and m ~= 15 and m ~= 16 then
                insert(map, 1, { 16 })
            end
        --  print(gsub(table.serialize(map),"[ \n]+"," "))
            return map
        end
    end
end

local cache = { }

function xml.lpath(pattern,trace)
    lpathcalls = lpathcalls + 1
    if type(pattern) == "string" then
        local result = cache[pattern]
        if result == nil then -- can be false which is valid -)
            result = compose(pattern)
            cache[pattern] = result
            lpathcached = lpathcached + 1
        end
        if trace or trace_lpath then
            xml.lshow(result)
        end
        return result
    else
        return pattern
    end
end

function xml.cached_patterns()
    return cache
end

--  we run out of locals (limited to 200)
--
--  local fallbackreport = (texio and texio.write) or io.write

function xml.lshow(pattern,report)
--      report = report or fallbackreport
    report = report or (texio and texio.write) or io.write
    local lp = xml.lpath(pattern)
    if lp == false then
        report(" -: root\n")
    elseif lp == true then
        report(" -: wildcard\n")
    else
        if type(pattern) == "string" then
            report(format("pattern: %s\n",pattern))
        end
        for k=1,#lp do
            local v = lp[k]
            if #v > 1 then
                local t = { }
                for i=2,#v do
                    local vv = v[i]
                    if type(vv) == "string" then
                        t[#t+1] = (vv ~= "" and vv) or "#"
                    elseif type(vv) == "boolean" then
                        t[#t+1] = (vv and "==") or "<>"
                    end
                end
                report(format("%2i: %s %s -> %s\n", k,v[1],actions[v[1]],concat(t," ")))
            else
                report(format("%2i: %s %s\n", k,v[1],actions[v[1]]))
            end
        end
    end
end

function xml.xshow(e,...) -- also handy when report is given, use () to isolate first e
    local t = { ... }
--      local report = (type(t[#t]) == "function" and t[#t]) or fallbackreport
    local report = (type(t[#t]) == "function" and t[#t]) or (texio and texio.write) or io.write
    if e == nil then
        report("<!-- no element -->\n")
    elseif type(e) ~= "table" then
        report(tostring(e))
    elseif e.tg then
        report(tostring(e) .. "\n")
    else
        for i=1,#e do
            report(tostring(e[i]) .. "\n")
        end
    end
end

--[[ldx--
<p>An <l n='lpath'/> is converted to a table with instructions for traversing the
tree. Hoever, simple cases are signaled by booleans. Because we don't know in
advance what we want to do with the found element the handle gets three arguments:</p>

<lines>
<t>r</t> : the root element of the data table
<t>d</t> : the data table of the result
<t>t</t> : the index in the data table of the result
</lines>

<p> Access to the root and data table makes it possible to construct insert and delete
functions.</p>
--ldx]]--

local functions   = xml.functions
local expressions = xml.expressions

expressions.contains = string.find
expressions.find     = string.find
expressions.upper    = string.upper
expressions.lower    = string.lower
expressions.number   = tonumber
expressions.boolean  = toboolean

expressions.oneof = function(s,...) -- slow
    local t = {...} for i=1,#t do if s == t[i] then return true end end return false
end

expressions.error = function(str)
    xml.error_handler("unknown function in lpath expression",str or "?")
    return false
end

functions.text = function(root,k,n) -- unchecked, maybe one deeper
    local t = type(t)
    if t == "string" then
        return t
    else -- todo n
        local rdt = root.dt
        return (rdt and rdt[k]) or root[k] or ""
    end
end

functions.name = function(d,k,n) -- ns + tg
    local found = false
    n = n or 0
    if not k then
        -- not found
    elseif n == 0 then
        local dk = d[k]
        found = dk and (type(dk) == "table") and dk
    elseif n < 0 then
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    if found then
        local ns, tg = found.rn or found.ns or "", found.tg
        if ns ~= "" then
            return ns .. ":" .. tg
        else
            return tg
        end
    else
        return ""
    end
end

functions.tag = function(d,k,n) -- only tg
    local found = false
    n = n or 0
    if not k then
        -- not found
    elseif n == 0 then
        local dk = d[k]
        found = dk and (type(dk) == "table") and dk
    elseif n < 0 then
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    return (found and found.tg) or ""
end

expressions.text = functions.text
expressions.name = functions.name
expressions.tag  = functions.tag

local function traverse(root,pattern,handle,reverse,index,parent,wildcard) -- multiple only for tags, not for namespaces
    if not root then -- error
        return false
    elseif pattern == false then -- root
        handle(root,root.dt,root.ri)
        return false
    elseif pattern == true then -- wildcard
        local rootdt = root.dt
        if rootdt then
            local start, stop, step = 1, #rootdt, 1
            if reverse then
                start, stop, step = stop, start, -1
            end
            for k=start,stop,step do
                if handle(root,rootdt,root.ri or k)            then return false end
                if not traverse(rootdt[k],true,handle,reverse) then return false end
            end
        end
        return false
    elseif root.dt then
        index = index or 1
        local action = pattern[index]
        local command = action[1]
        if command == 29 then -- fast case /oeps
            local rootdt = root.dt
            for k=1,#rootdt do
                local e = rootdt[k]
                local tg = e.tg
                if e.tg then
                    local ns = e.rn or e.ns
                    local ns_a, tg_a = action[3], action[4]
                    local matched = (ns_a == "*" or ns == ns_a) and (tg_a == "*" or tg == tg_a)
                    if not action[2] then matched = not matched end
                    if matched then
                        if handle(root,rootdt,k) then return false end
                    end
                end
            end
        elseif command == 11 then -- parent
            local ep = root.__p__ or parent
            if index < #pattern then
                if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
            elseif handle(root,rootdt,k) then
                return false
            end
        else
            if (command == 16 or command == 12) and index == 1 then -- initial
            --  wildcard = true
                wildcard = command == 16 -- ok?
                index = index + 1
                action = pattern[index]
                command = action and action[1] or 0 -- something is wrong
            end
            if command == 11 then -- parent
                local ep = root.__p__ or parent
                if index < #pattern then
                    if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                elseif handle(root,rootdt,k) then
                    return false
                end
            else
                local rootdt = root.dt
                local start, stop, step, n, dn = 1, #rootdt, 1, 0, 1
                if command == 30 then
                    if action[5] < 0 then
                        start, stop, step = stop, start, -1
                        dn = -1
                    end
                elseif reverse and index == #pattern then
                    start, stop, step = stop, start, -1
                end
                local idx = 0
                local hsh = { } -- this will slooow down the lot
                for k=start,stop,step do -- we used to have functions for all but a case is faster
                    local e = rootdt[k]
                    local ns, tg = e.rn or e.ns, e.tg
                    if tg then
                     -- we can optimize this for simple searches, but it probably does not pay off
                        hsh[tg] = (hsh[tg] or 0) + 1
                        idx = idx + 1
                        if command == 30 then
                            local ns_a, tg_a = action[3], action[4]
                            if tg == tg_a then
                                matched = ns_a == "*" or ns == ns_a
                            elseif tg_a == '*' then
                                matched, multiple = ns_a == "*" or ns == ns_a, true
                            else
                                matched = false
                            end
                            if not action[2] then matched = not matched end
                            if matched then
                                n = n + dn
                                if n == action[5] then
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                    else
                                        if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                    end
                                    break
                                end
                            elseif wildcard then
                                if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                            end
                        else
                            local matched, multiple = false, false
                            if command == 20 then -- match
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                            elseif command == 21 then -- match one of
                                multiple = true
                                for i=3,#action,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                            elseif command == 22 then -- eq
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                matched = matched and e.at[action[6]] == action[7]
                            elseif command == 23 then -- ne
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = mached and e.at[action[6]] ~= action[7]
                            elseif command == 24 then -- one of eq
                                multiple = true
                                for i=3,#action-2,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[#action-1]] == action[#action]
                            elseif command == 25 then -- one of ne
                                multiple = true
                                for i=3,#action-2,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[#action-1]] ~= action[#action]
                            elseif command == 27 then -- has attribute
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[5]]
                            elseif command == 28 then -- has value
                                local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and edt and edt[1] == action[5]
                            elseif command == 31 then
                                local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                if matched then
                                    matched = action[6](expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1)
                                end
                            end
                            if matched then -- combine tg test and at test
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                    if wildcard then
                                        if multiple then
                                            if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                                        else
                                         -- maybe or multiple; anyhow, check on (section|title) vs just section and title in example in lxml
                                            if not traverse(e,pattern,handle,reverse,index,root) then return false end
                                        end
                                    end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                end
                            elseif command == 14 then -- any
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                end
                            elseif command == 15 then -- many
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root,true) then return false end
                                end
                            -- not here : 11
                            elseif command == 11 then -- parent
                                local ep = e.__p__ or parent
                                if index < #pattern then
                                    if not traverse(ep,pattern,handle,reverse,root,index+1) then return false end
                                elseif handle(root,rootdt,k) then
                                    return false
                                end
                            elseif command == 40 and e.special and tg == "@pi@" then -- pi
                                local pi = action[2]
                                if pi ~= "" then
                                    local pt = e.dt[1]
                                    if pt and pt:find(pi) then
                                        if handle(root,rootdt,k) then
                                            return false
                                        end
                                    end
                                elseif handle(root,rootdt,k) then
                                    return false
                                end
                            elseif wildcard then
                                if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                            end
                        end
                    else
                        -- not here : 11
                        if command == 11 then -- parent
                            local ep = e.__p__ or parent
                            if index < #pattern then
                                if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                            elseif handle(root,rootdt,k) then
                                return false
                            end
                            break -- else loop
                        end
                    end
                end
            end
        end
    end
    return true
end

xml.traverse = traverse

--[[ldx--
<p>Next come all kind of locators and manipulators. The most generic function here
is <t>xml.filter(root,pattern)</t>. All registers functions in the filters namespace
can be path of a search path, as in:</p>

<typing>
local r, d, k = xml.filter(root,"/a/b/c/position(4)"
</typing>
--ldx]]--

local traverse, lpath, convert = xml.traverse, xml.lpath, xml.convert

xml.filters = { }

function xml.filters.default(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.attributes(root,pattern,arguments)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
    local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
    if ekat then
        if arguments then
            return ekat[arguments] or "", rt, dt, dk
        else
            return ekat, rt, dt, dk
        end
    else
        return { }, rt, dt, dk
    end
end

function xml.filters.reverse(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.count(root,pattern,everything)
    local n = 0
    traverse(root, lpath(pattern), function(r,d,t)
        if everything or type(d[t]) == "table" then
            n = n + 1
        end
    end)
    return n
end

function xml.filters.elements(root, pattern) -- == all
    local t = { }
    traverse(root, lpath(pattern), function(r,d,k)
        local e = d[k]
        if e then
            t[#t+1] = e
        end
    end)
    return t
end

function xml.filters.texts(root, pattern)
    local t = { }
    traverse(root, lpath(pattern), function(r,d,k)
        local e = d[k]
        if e and e.dt then
            t[#t+1] = e.dt
        end
    end)
    return t
end

function xml.filters.first(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.last(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.index(root,pattern,arguments)
    local rt, dt, dk, reverse, i = nil, nil, nil, false, tonumber(arguments or '1') or 1
    if i and i ~= 0 then
        if i < 0 then
            reverse, i = true, -i
        end
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk, i = r, d, k, i-1 return i == 0 end, reverse)
        if i == 0 then
            return dt and dt[dk], rt, dt, dk
        end
    end
    return nil, nil, nil, nil
end

function xml.filters.attribute(root,pattern,arguments)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
    local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
 -- return (ekat and (ekat[arguments] or ekat[gsub(arguments,"^([\"\'])(.*)%1$","%2")])) or ""
    return (ekat and (ekat[arguments] or (find(arguments,"^[\'\"]") and ekat[sub(arguments,2,-2)]))) or ""
end

function xml.filters.text(root,pattern,arguments) -- ?? why index, tostring slow
    local dtk, rt, dt, dk = xml.filters.index(root,pattern,arguments)
    if dtk then -- n
        local dtkdt = dtk.dt
        if not dtkdt then
            return "", rt, dt, dk
        elseif #dtkdt == 1 and type(dtkdt[1]) == "string" then
            return dtkdt[1], rt, dt, dk
        else
            return xml.tostring(dtkdt), rt, dt, dk
        end
    else
        return "", rt, dt, dk
    end
end

function xml.filters.tag(root,pattern,n)
    local tag = ""
    traverse(root, lpath(pattern), function(r,d,k)
        tag = xml.functions.tag(d,k,n and tonumber(n))
        return true
    end)
    return tag
end

function xml.filters.name(root,pattern,n)
    local tag = ""
    traverse(root, lpath(pattern), function(r,d,k)
        tag = xml.functions.name(d,k,n and tonumber(n))
        return true
    end)
    return tag
end

--[[ldx--
<p>For splitting the filter function from the path specification, we can
use string matching or lpeg matching. Here the difference in speed is
neglectable but the lpeg variant is more robust.</p>
--ldx]]--

--  not faster but hipper ... although ... i can't get rid of the trailing / in the path

local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

local slash     = P('/')
local name      = (R("az","AZ","--","__"))^1
local path      = C(((1-slash)^0 * slash)^1)
local argument  = P { "(" * C(((1 - S("()")) + V(1))^0) * ")" }
local action    = Cc(1) * path * C(name) * argument
local attribute = Cc(2) * path * P('@') * C(name)
local direct    = Cc(3) * Cc("../*") * slash^0 * C(name) * argument

local parser    = direct + action + attribute

local filters          = xml.filters
local attribute_filter = xml.filters.attributes
local default_filter   = xml.filters.default

-- todo: also hash, could be gc'd

function xml.filter(root,pattern)
    local kind, a, b, c = parser:match(pattern)
    if kind == 1 or kind == 3 then
        return (filters[b] or default_filter)(root,a,c)
    elseif kind == 2 then
        return attribute_filter(root,a,b)
    else
        return default_filter(root,pattern)
    end
end

--~     slightly faster, but first we need a proper test file
--~
--~     local hash = { }
--~
--~     function xml.filter(root,pattern)
--~         local h = hash[pattern]
--~         if not h then
--~             local kind, a, b, c = parser:match(pattern)
--~             if kind == 1 then
--~                 h = { kind, filters[b] or default_filter, a, b, c }
--~             elseif kind == 2 then
--~                 h = { kind, attribute_filter, a, b, c }
--~             else
--~                 h = { kind, default_filter, a, b, c }
--~             end
--~             hash[pattern] = h
--~         end
--~         local kind = h[1]
--~         if kind == 1 then
--~             return h[2](root,h[2],h[4])
--~         elseif kind == 2 then
--~             return h[2](root,h[2],h[3])
--~         else
--~             return h[2](root,pattern)
--~         end
--~     end

--[[ldx--
<p>The following functions collect elements and texts.</p>
--ldx]]--

-- still somewhat bugged

function xml.collect_elements(root, pattern, ignorespaces)
    local rr, dd = { }, { }
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d and d[k]
        if dk then
            if ignorespaces and type(dk) == "string" and dk:find("[^%S]") then
                -- ignore
            else
                local n = #rr+1
                rr[n], dd[n] = r, dk
            end
        end
    end)
    return dd, rr
end

function xml.collect_texts(root, pattern, flatten)
    local t = { } -- no r collector
    traverse(root, lpath(pattern), function(r,d,k)
        if d then
            local ek = d[k]
            local tx = ek and ek.dt
            if flatten then
                if tx then
                    t[#t+1] = xml.tostring(tx) or ""
                else
                    t[#t+1] = ""
                end
            else
                t[#t+1] = tx or ""
            end
        else
            t[#t+1] = ""
        end
    end)
    return t
end

function xml.collect_tags(root, pattern, nonamespace)
    local t = { }
    xml.traverse(root, xml.lpath(pattern), function(r,d,k)
        local dk = d and d[k]
        if dk and type(dk) == "table" then
            local ns, tg = e.ns, e.tg
            if nonamespace then
                t[#t+1] = tg -- if needed we can return an extra table
            elseif ns == "" then
                t[#t+1] = tg
            else
                t[#t+1] = ns .. ":" .. tg
            end
        end
    end)
    return #t > 0 and {}
end

--[[ldx--
<p>Often using an iterators looks nicer in the code than passing handler
functions. The <l n='lua'/> book describes how to use coroutines for that
purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
code like:</p>

<typing>
for r, d, k in xml.elements(xml.load('text.xml'),"title") do
    print(d[k])
end
</typing>

<p>Which will print all the titles in the document. The iterator variant takes
1.5 times the runtime of the function variant which is due to the overhead in
creating the wrapper. So, instead of:</p>

<typing>
function xml.filters.first(root,pattern)
    for rt,dt,dk in xml.elements(root,pattern)
        return dt and dt[dk], rt, dt, dk
    end
    return nil, nil, nil, nil
end
</typing>

<p>We use the function variants in the filters.</p>
--ldx]]--

local wrap, yield = coroutine.wrap, coroutine.yield

function xml.elements(root,pattern,reverse)
    return wrap(function() traverse(root, lpath(pattern), yield, reverse) end)
end

function xml.elements_only(root,pattern,reverse)
    return wrap(function() traverse(root, lpath(pattern), function(r,d,k) yield(d[k]) end, reverse) end)
end

function xml.each_element(root, pattern, handle, reverse)
    local ok
    traverse(root, lpath(pattern), function(r,d,k) ok = true handle(r,d,k) end, reverse)
    return ok
end

function xml.process_elements(root, pattern, handle)
    traverse(root, lpath(pattern), function(r,d,k)
        local dkdt = d[k].dt
        if dkdt then
            for i=1,#dkdt do
                local v = dkdt[i]
                if v.tg then handle(v) end
            end
        end
    end)
end

function xml.process_attributes(root, pattern, handle)
    traverse(root, lpath(pattern), function(r,d,k)
        local ek = d[k]
        local a = ek.at or { }
        handle(a)
        if next(a) then -- next is faster than type (and >0 test)
            ek.at = a
        else
            ek.at = nil
        end
    end)
end

--[[ldx--
<p>We've now arrives at the functions that manipulate the tree.</p>
--ldx]]--

function xml.inject_element(root, pattern, element, prepend)
    if root and element then
        local matches, collect = { }, nil
        if type(element) == "string" then
            element = convert(element,true)
        end
        if element then
            collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
            traverse(root, lpath(pattern), collect)
            for i=1,#matches do
                local m = matches[i]
                local r, d, k, element, edt = m[1], m[2], m[3], m[4], nil
                if element.ri then
                    element = element.dt[element.ri].dt
                else
                    element = element.dt
                end
                if r.ri then
                    edt = r.dt[r.ri].dt
                else
                    edt = d and d[k] and d[k].dt
                end
                if edt then
                    local be, af
                    if prepend then
                        be, af = xml.copy(element), edt
                    else
                        be, af = edt, xml.copy(element)
                    end
                    for i=1,#af do
                        be[#be+1] = af[i]
                    end
                    if r.ri then
                        r.dt[r.ri].dt = be
                    else
                        d[k].dt = be
                    end
                else
                 -- r.dt = element.dt -- todo
                end
            end
        end
    end
end

-- todo: copy !

function xml.insert_element(root, pattern, element, before) -- todo: element als functie
    if root and element then
        if pattern == "/" then
            xml.inject_element(root, pattern, element, before)
        else
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = convert(element,true)
            end
            if element and element.ri then
                element = element.dt[element.ri]
            end
            if element then
                collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                traverse(root, lpath(pattern), collect)
                for i=#matches,1,-1 do
                    local m = matches[i]
                    local r, d, k, element = m[1], m[2], m[3], m[4]
                    if not before then k = k + 1 end
                    if element.tg then
                        insert(d,k,element) -- untested
--~                         elseif element.dt then
--~                             for _,v in ipairs(element.dt) do -- i added
--~                                 insert(d,k,v)
--~                                 k = k + 1
--~                             end
--~                         end
                    else
                        local edt = element.dt
                        if edt then
                            for i=1,#edt do
                                insert(d,k,edt[i])
                                k = k + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

xml.insert_element_after  =                 xml.insert_element
xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end
xml.inject_element_after  =                 xml.inject_element
xml.inject_element_before = function(r,p,e) xml.inject_element(r,p,e,true) end

function xml.delete_element(root, pattern)
    local matches, deleted = { }, { }
    local collect = function(r,d,k) matches[#matches+1] = { r, d, k } end
    traverse(root, lpath(pattern), collect)
    for i=#matches,1,-1 do
        local m = matches[i]
        deleted[#deleted+1] = remove(m[2],m[3])
    end
    return deleted
end

function xml.replace_element(root, pattern, element)
    if type(element) == "string" then
        element = convert(element,true)
    end
    if element and element.ri then
        element = element.dt[element.ri]
    end
    if element then
        traverse(root, lpath(pattern), function(rm, d, k)
            d[k] = element.dt -- maybe not clever enough
        end)
    end
end

local function load_data(name) -- == io.loaddata
    local f, data = io.open(name), ""
    if f then
        data = f:read("*all",'b') -- 'b' ?
        f:close()
    end
    return data
end

function xml.include(xmldata,pattern,attribute,recursive,loaddata)
    -- parse="text" (default: xml), encoding="" (todo)
    -- attribute = attribute or 'href'
    pattern = pattern or 'include'
    loaddata = loaddata or load_data
    local function include(r,d,k)
        local ek, name = d[k], nil
        if not attribute or attribute == "" then
            local ekdt = ek.dt
            name = (type(ekdt) == "table" and ekdt[1]) or ekdt
        end
        if not name then
            if ek.at then
                for a in gmatch(attribute or "href","([^|]+)") do
                    name = ek.at[a]
                    if name then break end
                end
            end
        end
        local data = (name and name ~= "" and loaddata(name)) or ""
        if data == "" then
            xml.empty(d,k)
        elseif ek.at["parse"] == "text" then -- for the moment hard coded
            d[k] = xml.escaped(data)
        else
            local xi = xml.convert(data)
            if not xi then
                xml.empty(d,k)
            else
                if recursive then
                    xml.include(xi,pattern,attribute,recursive,loaddata)
                end
                xml.assign(d,k,xi)
            end
        end
    end
    xml.each_element(xmldata, pattern, include)
end

function xml.strip_whitespace(root, pattern, nolines) -- strips all leading and trailing space !
    traverse(root, lpath(pattern), function(r,d,k)
        local dkdt = d[k].dt
        if dkdt then -- can be optimized
            local t = { }
            for i=1,#dkdt do
                local str = dkdt[i]
                if type(str) == "string" then
                    if str == "" then
                        -- stripped
                    else
                        if nolines then
                            str = gsub(str,"[ \n\r\t]+"," ")
                        end
                        if str == "" then
                            -- stripped
                        else
                            t[#t+1] = str
                        end
                    end
                else
                    t[#t+1] = str
                end
            end
            d[k].dt = t
        end
    end)
end

local function rename_space(root, oldspace, newspace) -- fast variant
    local ndt = #root.dt
    for i=1,ndt or 0 do
        local e = root[i]
        if type(e) == "table" then
            if e.ns == oldspace then
                e.ns = newspace
                if e.rn then
                    e.rn = newspace
                end
            end
            local edt = e.dt
            if edt then
                rename_space(edt, oldspace, newspace)
            end
        end
    end
end

xml.rename_space = rename_space

function xml.remap_tag(root, pattern, newtg)
    traverse(root, lpath(pattern), function(r,d,k)
        d[k].tg = newtg
    end)
end
function xml.remap_namespace(root, pattern, newns)
    traverse(root, lpath(pattern), function(r,d,k)
        d[k].ns = newns
    end)
end
function xml.check_namespace(root, pattern, newns)
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d[k]
        if (not dk.rn or dk.rn == "") and dk.ns == "" then
            dk.rn = newns
        end
    end)
end
function xml.remap_name(root, pattern, newtg, newns, newrn)
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d[k]
        dk.tg = newtg
        dk.ns = newns
        dk.rn = newrn
    end)
end

function xml.filters.found(root,pattern,check_content)
    local found = false
    traverse(root, lpath(pattern), function(r,d,k)
        if check_content then
            local dk = d and d[k]
            found = dk and dk.dt and next(dk.dt) and true
        else
            found = true
        end
        return true
    end)
    return found
end

--[[ldx--
<p>Here are a few synonyms.</p>
--ldx]]--

xml.filters.position = xml.filters.index

xml.count    = xml.filters.count
xml.index    = xml.filters.index
xml.position = xml.filters.index
xml.first    = xml.filters.first
xml.last     = xml.filters.last
xml.found    = xml.filters.found

xml.each     = xml.each_element
xml.process  = xml.process_element
xml.strip    = xml.strip_whitespace
xml.collect  = xml.collect_elements
xml.all      = xml.collect_elements

xml.insert   = xml.insert_element_after
xml.inject   = xml.inject_element_after
xml.after    = xml.insert_element_after
xml.before   = xml.insert_element_before
xml.delete   = xml.delete_element
xml.replace  = xml.replace_element

--[[ldx--
<p>The following helper functions best belong to the <t>lmxl-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

function xml.gsub(t,old,new)
    local dt = t.dt
    if dt then
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "string" then
                dt[k] = gsub(v,old,new)
            else
                xml.gsub(v,old,new)
            end
        end
    end
end

function xml.strip_leading_spaces(dk,d,k) -- cosmetic, for manual
    if d and k and d[k-1] and type(d[k-1]) == "string" then
        local s = d[k-1]:match("\n(%s+)")
        xml.gsub(dk,"\n"..rep(" ",#s),"\n")
    end
end

function xml.serialize_path(root,lpath,handle)
    local dk, r, d, k = xml.first(root,lpath)
    dk = xml.copy(dk)
    xml.strip_leading_spaces(dk,d,k)
    xml.serialize(dk,handle)
end

--~ xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
--~ xml.unescapes = { } for k,v in pairs(xml.escapes) do xml.unescapes[v] = k end

--~ function xml.escaped  (str) return (gsub(str,"(.)"   , xml.escapes  )) end
--~ function xml.unescaped(str) return (gsub(str,"(&.-;)", xml.unescapes)) end
--~ function xml.cleansed (str) return (gsub(str,"<.->"  , ''           )) end -- "%b<>"

local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

-- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
--
-- 1021:0335:0287:0247

-- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
--
-- 1559:0257:0288:0190 (last one suggested by roberto)

--    escaped = Cs((S("<&>") / xml.escapes + 1)^0)
--    escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
local normal  = (1 - S("<&>"))^0
local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
local escaped = Cs(normal * (special * normal)^0)

-- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

--    unescaped = Cs((S("&lt;")/"<" + S("&gt;")/">" + S("&amp;")/"&" + 1)^0)
--    unescaped = Cs((((P("&")/"") * (P("lt")/"<" + P("gt")/">" + P("amp")/"&") * (P(";")/"")) + 1)^0)
local normal    = (1 - S"&")^0
local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
local unescaped = Cs(normal * (special * normal)^0)

-- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

function xml.escaped  (str) return escaped  :match(str) end
function xml.unescaped(str) return unescaped:match(str) end
function xml.cleansed (str) return cleansed :match(str) end

function xml.join(t,separator,lastseparator)
    if #t > 0 then
        local result = { }
        for k,v in pairs(t) do
            result[k] = xml.tostring(v)
        end
        if lastseparator then
            return concat(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return concat(result,separator)
        end
    else
        return ""
    end
end

function xml.statistics()
    return {
        lpathcalls = lpathcalls,
        lpathcached = lpathcached,
    }
end

--  xml.set_text_cleanup(xml.show_text_entities)
--  xml.set_text_cleanup(xml.resolve_text_entities)

--~ xml.lshow("/../../../a/(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!b[@d!='e']/f")

--~ x = xml.convert([[
--~     <a>
--~         <b n='01'>01</b>
--~         <b n='02'>02</b>
--~         <b n='03'>03</b>
--~         <b n='04'>OK</b>
--~         <b n='05'>05</b>
--~         <b n='06'>06</b>
--~         <b n='07'>ALSO OK</b>
--~     </a>
--~ ]])

--~ xml.settrace("lpath",true)

--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == 'ok']"))
--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == upper('ok')]"))
--~ xml.xshow(xml.first(x,"b[@n=='03' or @n=='08']"))
--~ xml.xshow(xml.all  (x,"b[number(@n)>2 and number(@n)<6]"))
--~ xml.xshow(xml.first(x,"b[find(text(),'ALSO')]"))

--~ str = [[
--~ <?xml version="1.0" encoding="utf-8"?>
--~ <story line='mojca'>
--~     <windows>my secret</mouse>
--~ </story>
--~ ]]

--~ x = xml.convert([[
--~     <a><b n='01'>01</b><b n='02'>02</b><x>xx</x><b n='03'>03</b><b n='04'>OK</b></a>
--~ ]])
--~ xml.xshow(xml.first(x,"b[tag(2) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-2) == 'x']"))

--~ print(xml.filter(x,"b/tag(2)"))
--~ print(xml.filter(x,"b/tag(1)"))


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, gsub, find = string.format, string.gsub, string.find
local utfchar = unicode.utf8.char

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>
--ldx]]--

xml.entities = xml.entities or { } -- xml.entity_handler == function

function xml.entity_handler(e)
    return format("[%s]",e)
end

local function toutf(s)
    return utfchar(tonumber(s,16))
end

local function utfize(root)
    local d = root.dt
    for k=1,#d do
        local dk = d[k]
        if type(dk) == "string" then
        --  test prevents copying if no match
            if find(dk,"&#x.-;") then
                d[k] = gsub(dk,"&#x(.-);",toutf)
            end
        else
            utfize(dk)
        end
    end
end

xml.utfize = utfize

local function resolve(e) -- hex encoded always first, just to avoid mkii fallbacks
    if find(e,"^#x") then
        return utfchar(tonumber(e:sub(3),16))
    elseif find(e,"^#") then
        return utfchar(tonumber(e:sub(2)))
    else
        local ee = xml.entities[e] -- we cannot shortcut this one (is reloaded)
        if ee then
            return ee
        else
            local h = xml.entity_handler
            return (h and h(e)) or "&" .. e .. ";"
        end
    end
end

local function resolve_entities(root)
    if not root.special or root.tg == "@rt@" then
        local d = root.dt
        for k=1,#d do
            local dk = d[k]
            if type(dk) == "string" then
                if find(dk,"&.-;") then
                    d[k] = gsub(dk,"&(.-);",resolve)
                end
            else
                resolve_entities(dk)
            end
        end
    end
end

xml.resolve_entities = resolve_entities

function xml.utfize_text(str)
    if find(str,"&#") then
        return (gsub(str,"&#x(.-);",toutf))
    else
        return str
    end
end

function xml.resolve_text_entities(str) -- maybe an lpeg. maybe resolve inline
    if find(str,"&") then
        return (gsub(str,"&(.-);",resolve))
    else
        return str
    end
end

function xml.show_text_entities(str)
    if find(str,"&") then
        return (gsub(str,"&(.-);","[%1]"))
    else
        return str
    end
end

-- experimental, this will be done differently

function xml.merge_entities(root)
    local documententities = root.entities
    local allentities = xml.entities
    if documententities then
        for k, v in next, documententities do
            allentities[k] = v
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['lxml-mis'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, gsub = string.format, string.gsub

--[[ldx--
<p>The following helper functions best belong to the <t>lmxl-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

function xml.gsub(t,old,new)
    local dt = t.dt
    if dt then
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "string" then
                dt[k] = gsub(v,old,new)
            else
                xml.gsub(v,old,new)
            end
        end
    end
end

function xml.strip_leading_spaces(dk,d,k) -- cosmetic, for manual
    if d and k and d[k-1] and type(d[k-1]) == "string" then
        local s = d[k-1]:match("\n(%s+)")
        xml.gsub(dk,"\n"..string.rep(" ",#s),"\n")
    end
end

function xml.serialize_path(root,lpath,handle)
    local dk, r, d, k = xml.first(root,lpath)
    dk = xml.copy(dk)
    xml.strip_leading_spaces(dk,d,k)
    xml.serialize(dk,handle)
end

--~ xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
--~ xml.unescapes = { } for k,v in pairs(xml.escapes) do xml.unescapes[v] = k end

--~ function xml.escaped  (str) return (gsub(str,"(.)"   , xml.escapes  )) end
--~ function xml.unescaped(str) return (gsub(str,"(&.-;)", xml.unescapes)) end
--~ function xml.cleansed (str) return (gsub(str,"<.->"  , ''           )) end -- "%b<>"

local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

-- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
--
-- 1021:0335:0287:0247

-- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
--
-- 1559:0257:0288:0190 (last one suggested by roberto)

--    escaped = Cs((S("<&>") / xml.escapes + 1)^0)
--    escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
local normal  = (1 - S("<&>"))^0
local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
local escaped = Cs(normal * (special * normal)^0)

-- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

--    unescaped = Cs((S("&lt;")/"<" + S("&gt;")/">" + S("&amp;")/"&" + 1)^0)
--    unescaped = Cs((((P("&")/"") * (P("lt")/"<" + P("gt")/">" + P("amp")/"&") * (P(";")/"")) + 1)^0)
local normal    = (1 - S"&")^0
local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
local unescaped = Cs(normal * (special * normal)^0)

-- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

xml.escaped_pattern   = escaped
xml.unescaped_pattern = unescaped
xml.cleansed_pattern  = cleansed

function xml.escaped  (str) return escaped  :match(str) end
function xml.unescaped(str) return unescaped:match(str) end
function xml.cleansed (str) return cleansed :match(str) end

function xml.join(t,separator,lastseparator)
    if #t > 0 then
        local result = { }
        for k,v in pairs(t) do
            result[k] = xml.tostring(v)
        end
        if lastseparator then
            return concat(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return concat(result,separator)
        end
    else
        return ""
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-tra'] = {
    version   = 1.001,
    comment   = "companion to trac-tra.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- the <anonymous> tag is kind of generic and used for functions that are not
-- bound to a variable, like node.new, node.copy etc (contrary to for instance
-- node.has_attribute which is bound to a has_attribute local variable in mkiv)

debugger = debugger or { }

local counters = { }
local names = { }
local getinfo = debug.getinfo
local format, find, lower, gmatch = string.format, string.find, string.lower, string.gmatch

-- one

local function hook()
    local f = getinfo(2,"f").func
    local n = getinfo(2,"Sn")
--  if n.what == "C" and n.name then print (n.namewhat .. ': ' .. n.name) end
    if f then
        local cf = counters[f]
        if cf == nil then
            counters[f] = 1
            names[f] = n
        else
            counters[f] = cf + 1
        end
    end
end
local function getname(func)
    local n = names[func]
    if n then
        if n.what == "C" then
            return n.name or '<anonymous>'
        else
            -- source short_src linedefined what name namewhat nups func
            local name = n.name or n.namewhat or n.what
            if not name or name == "" then name = "?" end
            return format("%s : %s : %s", n.short_src or "unknown source", n.linedefined or "--", name)
        end
    else
        return "unknown"
    end
end
function debugger.showstats(printer,threshold)
    printer   = printer or texio.write or print
    threshold = threshold or 0
    local total, grandtotal, functions = 0, 0, 0
    printer("\n") -- ugly but ok
 -- table.sort(counters)
    for func, count in pairs(counters) do
        if count > threshold then
            local name = getname(func)
            if not name:find("for generator") then
                printer(format("%8i  %s", count, name))
                total = total + count
            end
        end
        grandtotal = grandtotal + count
        functions = functions + 1
    end
    printer(format("functions: %s, total: %s, grand total: %s, threshold: %s\n", functions, total, grandtotal, threshold))
end

-- two

--~ local function hook()
--~     local n = getinfo(2)
--~     if n.what=="C" and not n.name then
--~         local f = tostring(debug.traceback())
--~         local cf = counters[f]
--~         if cf == nil then
--~             counters[f] = 1
--~             names[f] = n
--~         else
--~             counters[f] = cf + 1
--~         end
--~     end
--~ end
--~ function debugger.showstats(printer,threshold)
--~     printer   = printer or texio.write or print
--~     threshold = threshold or 0
--~     local total, grandtotal, functions = 0, 0, 0
--~     printer("\n") -- ugly but ok
--~  -- table.sort(counters)
--~     for func, count in pairs(counters) do
--~         if count > threshold then
--~             printer(format("%8i  %s", count, func))
--~             total = total + count
--~         end
--~         grandtotal = grandtotal + count
--~         functions = functions + 1
--~     end
--~     printer(format("functions: %s, total: %s, grand total: %s, threshold: %s\n", functions, total, grandtotal, threshold))
--~ end

-- rest

function debugger.savestats(filename,threshold)
    local f = io.open(filename,'w')
    if f then
        debugger.showstats(function(str) f:write(str) end,threshold)
        f:close()
    end
end

function debugger.enable()
    debug.sethook(hook,"c")
end

function debugger.disable()
    debug.sethook()
--~ counters[debug.getinfo(2,"f").func] = nil
end

function debugger.tracing()
    local n = tonumber(os.env['MTX.TRACE.CALLS']) or tonumber(os.env['MTX_TRACE_CALLS']) or 0
    if n > 0 then
        function debugger.tracing() return true  end ; return true
    else
        function debugger.tracing() return false end ; return false
    end
end

--~ debugger.enable()

--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))
--~ print(math.sin(1*.5))

--~ debugger.disable()

--~ print("")
--~ debugger.showstats()
--~ print("")
--~ debugger.showstats(print,3)

trackers = trackers or { }

local data, done = { }, { }

local function set(what,value)
    if type(what) == "string" then
        what = aux.settings_to_array(what)
    end
    for i=1,#what do
        local w = what[i]
        for d, f in next, data do
            if done[d] then
                -- prevent recursion due to wildcards
            elseif find(d,w) then
                done[d] = true
                for i=1,#f do
                    f[i](value)
                end
            end
        end
    end
end

local function reset()
    for d, f in next, data do
        for i=1,#f do
            f[i](false)
        end
    end
end

function trackers.register(what,...)
    what = lower(what)
    local w = data[what]
    if not w then
        w = { }
        data[what] = w
    end
    for _, fnc in next, { ... } do
        local typ = type(fnc)
        if typ == "function" then
            w[#w+1] = fnc
        elseif typ == "string" then
            w[#w+1] = function(value) set(fnc,value,nesting) end
        end
    end
end

function trackers.enable(what)
    done = { }
    set(what,true)
end

function trackers.disable(what)
    done = { }
    if not what or what == "" then
        trackers.reset(what)
    else
        set(what,false)
    end
end

function trackers.reset(what)
    done = { }
    reset()
end

function trackers.list() -- pattern
    local list = table.sortedkeys(data)
    local user, system = { }, { }
    for l=1,#list do
        local what = list[l]
        if find(what,"^%*") then
            system[#system+1] = what
        else
            user[#user+1] = what
        end
    end
    return user, system
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A former version provided functionality for non embeded core
-- scripts i.e. runtime library loading. Given the amount of
-- Lua code we use now, this no longer makes sense. Much of this
-- evolved before bytecode arrays were available and so a lot of
-- code has disappeared already.

local trace_verbose  = false  trackers.register("resolvers.verbose",  function(v) trace_verbose  = v end)
local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v trackers.enable("resolvers.verbose") end)

local format = string.format

-- precautions

os.setlocale(nil,nil) -- useless feature and even dangerous in luatex

function os.setlocale()
    -- no way you can mess with it
end

-- dirty tricks

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

if profiler and os.env["MTX_PROFILE_RUN"] == "YES" then
    profiler.start("luatex-profile.log")
end

-- environment

environment             = environment or { }
environment.arguments   = { }
environment.files       = { }
environment.sortedflags = nil

if not environment.jobname or environment.jobname == "" then if tex then environment.jobname = tex.jobname end end
if not environment.version or environment.version == "" then             environment.version = "unknown"   end
if not environment.jobname                              then             environment.jobname = "unknown"   end

function environment.initialize_arguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index, argument in pairs(arg) do
        if index > 0 then
            local flag, value = argument:match("^%-+(.+)=(.-)$")
            if flag then
                arguments[flag] = string.unquote(value or "")
            else
                flag = argument:match("^%-+(.+)")
                if flag then
                    arguments[flag] = true
                else
                    files[#files+1] = argument
                end
            end
        end
    end
    environment.ownname = environment.ownname or arg[0] or 'unknown.lua'
end

function environment.setargument(name,value)
    environment.arguments[name] = value
end

-- todo: defaults, better checks e.g on type (boolean versus string)
--
-- tricky: too many hits when we support partials unless we add
-- a registration of arguments so from now on we have 'partial'

function environment.argument(name,partial)
    local arguments, sortedflags = environment.arguments, environment.sortedflags
    if arguments[name] then
        return arguments[name]
    elseif partial then
        if not sortedflags then
            sortedflags = { }
            for _,v in pairs(table.sortedkeys(arguments)) do
                sortedflags[#sortedflags+1] = "^" .. v
            end
            environment.sortedflags = sortedflags
        end
        -- example of potential clash: ^mode ^modefile
        for _,v in ipairs(sortedflags) do
            if name:find(v) then
                return arguments[v:sub(2,#v)]
            end
        end
    end
    return nil
end

function environment.split_arguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    for _,v in ipairs(environment.original_arguments) do
        if not done and v == separator then
            done = true
        elseif done then
            after[#after+1] = v
        else
            before[#before+1] = v
        end
    end
    return before, after
end

function environment.reconstruct_commandline(arg,noquote)
    arg = arg or environment.original_arguments
    if noquote and #arg == 1 then
        local a = arg[1]
        a = resolvers.resolve(a)
        a = a:unquote()
        return a
    elseif next(arg) then
        local result = { }
        for _,a in ipairs(arg) do -- ipairs 1 .. #n
            a = resolvers.resolve(a)
            a = a:unquote()
            a = a:gsub('"','\\"') -- tricky
            if a:find(" ") then
                result[#result+1] = a:quote()
            else
                result[#result+1] = a
            end
        end
        return table.join(result," ")
    else
        return ""
    end
end

if arg then

    -- new, reconstruct quoted snippets (maybe better just remnove the " then and add them later)
    local newarg, instring = { }, false

    for index, argument in ipairs(arg) do
        if argument:find("^\"") then
            newarg[#newarg+1] = argument:gsub("^\"","")
            if not argument:find("\"$") then
                instring = true
            end
        elseif argument:find("\"$") then
            newarg[#newarg] = newarg[#newarg] .. " " .. argument:gsub("\"$","")
            instring = false
        elseif instring then
            newarg[#newarg] = newarg[#newarg] .. " " .. argument
        else
            newarg[#newarg+1] = argument
        end
    end
    for i=1,-5,-1 do
        newarg[i] = arg[i]
    end

    environment.initialize_arguments(newarg)
    environment.original_arguments = newarg
    environment.raw_arguments = arg

    arg = { } -- prevent duplicate handling

end

-- weird place ... depends on a not yet loaded module

function environment.texfile(filename)
    return resolvers.find_file(filename,'tex')
end

function environment.luafile(filename)
    local resolved = resolvers.find_file(filename,'tex') or ""
    if resolved ~= "" then
        return resolved
    end
    resolved = resolvers.find_file(filename,'texmfscripts') or ""
    if resolved ~= "" then
        return resolved
    end
    return resolvers.find_file(filename,'luatexlibs') or ""
end

environment.loadedluacode = loadfile -- can be overloaded

--~ function environment.loadedluacode(name)
--~     if os.spawn("texluac -s -o texluac.luc " .. name) == 0 then
--~         local chunk = loadstring(io.loaddata("texluac.luc"))
--~         os.remove("texluac.luc")
--~         return chunk
--~     else
--~         environment.loadedluacode = loadfile -- can be overloaded
--~         return loadfile(name)
--~     end
--~ end

function environment.luafilechunk(filename) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        if trace_verbose then
            logs.report("fileio","loading file %s", fullname)
        end
        return environment.loadedluacode(fullname)
    else
        if trace_verbose then
            logs.report("fileio","unknown file %s", filename)
        end
        return nil
    end
end

-- the next ones can use the previous ones / combine

function environment.loadluafile(filename, version)
    local lucname, luaname, chunk
    local basename = file.removesuffix(filename)
    if basename == filename then
        lucname, luaname = basename .. ".luc",  basename .. ".lua"
    else
        lucname, luaname = nil, basename -- forced suffix
    end
    -- when not overloaded by explicit suffix we look for a luc file first
    local fullname = (lucname and environment.luafile(lucname)) or ""
    if fullname ~= "" then
        if trace_verbose then
            logs.report("fileio","loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
    end
    if chunk then
        assert(chunk)()
        if version then
            -- we check of the version number of this chunk matches
            local v = version -- can be nil
            if modules and modules[filename] then
                v = modules[filename].version -- new method
            elseif versions and versions[filename] then
                v = versions[filename]        -- old method
            end
            if v == version then
                return true
            else
                if trace_verbose then
                    logs.report("fileio","version mismatch for %s: lua=%s, luc=%s", filename, v, version)
                end
                environment.loadluafile(filename)
            end
        else
            return true
        end
    end
    fullname = (luaname and environment.luafile(luaname)) or ""
    if fullname ~= "" then
        if trace_verbose then
            logs.report("fileio","loading %s", fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            if verbose then
                logs.report("fileio","unknown file %s", filename)
            end
        else
            assert(chunk)()
            return true
        end
    end
    return false
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['trac-inf'] = {
    version   = 1.001,
    comment   = "companion to trac-inf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local statusinfo, n, registered = { }, 0, { }

statistics = statistics or { }

statistics.enable    = true
statistics.threshold = 0.05

-- timing functions

local clock = os.gettimeofday or os.clock

local notimer

function statistics.hastimer(instance)
    return instance and instance.starttime
end

function statistics.starttiming(instance)
    if not instance then
        notimer = { }
        instance = notimer
    end
    local it = instance.timing
    if not it then
        it = 0
    end
    if it == 0 then
        instance.starttime = clock()
        if not instance.loadtime then
            instance.loadtime = 0
        end
    end
    instance.timing = it + 1
end

function statistics.stoptiming(instance, report)
    if not instance then
        instance = notimer
    end
    if instance then
        local it = instance.timing
        if it > 1 then
            instance.timing = it - 1
        else
            local starttime = instance.starttime
            if starttime then
                local stoptime = clock()
                local loadtime = stoptime - starttime
                instance.stoptime = stoptime
                instance.loadtime = instance.loadtime + loadtime
                if report then
                    statistics.report("load time %0.3f",loadtime)
                end
                instance.timing = 0
                return loadtime
            end
        end
    end
    return 0
end

function statistics.elapsedtime(instance)
    if not instance then
        instance = notimer
    end
    return format("%0.3f",(instance and instance.loadtime) or 0)
end

function statistics.elapsedindeed(instance)
    if not instance then
        instance = notimer
    end
    local t = (instance and instance.loadtime) or 0
    return t > statistics.threshold
end

-- general function

function statistics.register(tag,fnc)
    if statistics.enable and type(fnc) == "function" then
        local rt = registered[tag] or (#statusinfo + 1)
        statusinfo[rt] = { tag, fnc }
        registered[tag] = rt
        if #tag > n then n = #tag end
    end
end

function statistics.show(reporter)
    if statistics.enable then
        if not reporter then reporter = function(tag,data,n) texio.write_nl(tag .. " " .. data) end end
        -- this code will move
        local register = statistics.register
        register("luatex banner", function()
            return string.lower(status.banner)
        end)
        register("control sequences", function()
            return format("%s of %s", status.cs_count, status.hash_size+status.hash_extra)
        end)
        register("callbacks", function()
            local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
            return format("direct: %s, indirect: %s, total: %s", total-indirect, indirect, total)
        end)
        register("current memory usage", statistics.memused)
        register("runtime",statistics.runtime)
--         --
        for i=1,#statusinfo do
            local s = statusinfo[i]
            local r = s[2]()
            if r then
                reporter(s[1],r,n)
            end
        end
        texio.write_nl("") -- final newline
        statistics.enable = false
    end
end

function statistics.show_job_stat(tag,data,n)
    texio.write_nl(format("%-15s: %s - %s","mkiv lua stats",tag:rpadd(n," "),data))
end

function statistics.memused() -- no math.round yet -)
    local round = math.round or math.floor
    return format("%s MB (ctx: %s MB)",round(collectgarbage("count")/1000), round(status.luastate_bytes/1000000))
end

if statistics.runtime then
    -- already loaded and set
elseif luatex and luatex.starttime then
    statistics.starttime = luatex.starttime
    statistics.loadtime = 0
    statistics.timing = 0
else
    statistics.starttiming(statistics)
end

function statistics.runtime()
    statistics.stoptiming(statistics)
    return statistics.formatruntime(statistics.elapsedtime(statistics))
end

function statistics.formatruntime(runtime)
    return format("%s seconds", statistics.elapsedtime(statistics))
end

function statistics.timed(action,report)
    local timer = { }
    report = report or logs.simple
    statistics.starttiming(timer)
    action()
    statistics.stoptiming(timer)
    report("total runtime: %s",statistics.elapsedtime(timer))
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is old code that needs an overhaul

local write_nl, write, format = texio.write_nl or print, texio.write or io.write, string.format
local texcount = tex and tex.count

if texlua then
    write_nl = print
    write    = io.write
end

--[[ldx--
<p>This is a prelude to a more extensive logging module. For the sake
of parsing log files, in addition to the standard logging we will
provide an <l n='xml'/> structured file. Actually, any logging that
is hooked into callbacks will be \XML\ by default.</p>
--ldx]]--

logs     = logs     or { }
logs.xml = logs.xml or { }
logs.tex = logs.tex or { }

--[[ldx--
<p>This looks pretty ugly but we need to speed things up a bit.</p>
--ldx]]--

logs.moreinfo = [[
more information about ConTeXt and the tools that come with it can be found at:

maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

logs.levels = {
    ['error']   = 1,
    ['warning'] = 2,
    ['info']    = 3,
    ['debug']   = 4,
}

logs.functions = {
    'report', 'start', 'stop', 'push', 'pop', 'line', 'direct',
    'start_run', 'stop_run',
    'start_page_number', 'stop_page_number',
    'report_output_pages', 'report_output_log',
    'report_tex_stat', 'report_job_stat',
    'show_open', 'show_close', 'show_load',
}

logs.tracers = {
}

logs.level = 0
logs.mode  = string.lower((os.getenv("MTX.LOG.MODE") or os.getenv("MTX_LOG_MODE") or "tex"))

function logs.set_level(level)
    logs.level = logs.levels[level] or level
end

function logs.set_method(method)
    for _, v in next, logs.functions do
        logs[v] = logs[method][v] or function() end
    end
end

-- tex logging

function logs.tex.report(category,fmt,...) -- new
    if fmt then
        write_nl(category .. " | " .. format(fmt,...))
    else
        write_nl(category .. " |")
    end
end

function logs.tex.line(fmt,...) -- new
    if fmt then
        write_nl(format(fmt,...))
    else
        write_nl("")
    end
end

function logs.tex.start_page_number()
    local real, user, sub = texcount.realpageno, texcount.userpageno, texcount.subpageno
    if real > 0 then
        if user > 0 then
            if sub > 0 then
                write(format("[%s.%s.%s",real,user,sub))
            else
                write(format("[%s.%s",real,user))
            end
        else
            write(format("[%s",real))
        end
    else
        write("[-")
    end
end

function logs.tex.stop_page_number()
    write("]")
end

logs.tex.report_job_stat = statistics.show_job_stat

-- xml logging

function logs.xml.report(category,fmt,...) -- new
    if fmt then
        write_nl(format("<r category='%s'>%s</r>",category,format(fmt,...)))
    else
        write_nl(format("<r category='%s'/>",category))
    end
end
function logs.xml.line(fmt,...) -- new
    if fmt then
        write_nl(format("<r>%s</r>",format(fmt,...)))
    else
        write_nl("<r/>")
    end
end

function logs.xml.start() if logs.level > 0 then tw("<%s>" ) end end
function logs.xml.stop () if logs.level > 0 then tw("</%s>") end end
function logs.xml.push () if logs.level > 0 then tw("<!-- ") end end
function logs.xml.pop  () if logs.level > 0 then tw(" -->" ) end end

function logs.xml.start_run()
    write_nl("<?xml version='1.0' standalone='yes'?>")
    write_nl("<job>") --  xmlns='www.pragma-ade.com/luatex/schemas/context-job.rng'
    write_nl("")
end

function logs.xml.stop_run()
    write_nl("</job>")
end

function logs.xml.start_page_number()
    write_nl(format("<p real='%s' page='%s' sub='%s'", texcount.realpageno, texcount.userpageno, texcount.subpageno))
end

function logs.xml.stop_page_number()
    write("/>")
    write_nl("")
end

function logs.xml.report_output_pages(p,b)
    write_nl(format("<v k='pages' v='%s'/>", p))
    write_nl(format("<v k='bytes' v='%s'/>", b))
    write_nl("")
end

function logs.xml.report_output_log()
end

function logs.xml.report_tex_stat(k,v)
    texiowrite_nl("log","<v k='"..k.."'>"..tostring(v).."</v>")
end

local level = 0

function logs.xml.show_open(name)
    level = level + 1
    texiowrite_nl(format("<f l='%s' n='%s'>",level,name))
end

function logs.xml.show_close(name)
    texiowrite("</f> ")
    level = level - 1
end

function logs.xml.show_load(name)
    texiowrite_nl(format("<f l='%s' n='%s'/>",level+1,name))
end

--

local name, banner = 'report', 'context'

local function report(category,fmt,...)
    if fmt then
        write_nl(format("%s | %s: %s",name,category,format(fmt,...)))
    elseif category then
        write_nl(format("%s | %s",name,category))
    else
        write_nl(format("%s |",name))
    end
end

local function simple(fmt,...)
    if fmt then
        write_nl(format("%s | %s",name,format(fmt,...)))
    else
        write_nl(format("%s |",name))
    end
end

function logs.setprogram(_name_,_banner_,_verbose_)
    name, banner = _name_, _banner_
    if _verbose_ then
        trackers.enable("resolvers.verbose")
    end
    logs.set_method("tex")
    logs.report = report -- also used in libraries
    logs.simple = simple -- only used in scripts !
    if utils then
        utils.report = simple
    end
    logs.verbose = _verbose_
end

function logs.setverbose(what)
    if what then
        trackers.enable("resolvers.verbose")
    else
        trackers.disable("resolvers.verbose")
    end
    logs.verbose = what or false
end

function logs.extendbanner(_banner_,_verbose_)
    banner = banner .. " | ".. _banner_
    if _verbose_ ~= nil then
        logs.setverbose(what)
    end
end

logs.verbose = false
logs.report  = logs.tex.report
logs.simple  = logs.tex.report

function logs.reportlines(str) -- todo: <lines></lines>
    for line in str:gmatch("(.-)[\n\r]") do
        logs.report(line)
    end
end

function logs.reportline() -- for scripts too
    logs.report()
end

logs.simpleline = logs.reportline

function logs.help(message,option)
    logs.report(banner)
    logs.reportline()
    logs.reportlines(message)
    local moreinfo = logs.moreinfo or ""
    if moreinfo ~= "" and option ~= "nomoreinfo" then
        logs.reportline()
        logs.reportlines(moreinfo)
    end
end

logs.set_level('error')
logs.set_method('tex')

function logs.system(whereto,process,jobname,category,...)
    for i=1,10 do
        local f = io.open(whereto,"a")
        if f then
            f:write(format("%s %s => %s => %s => %s\r",os.date("%d/%m/%y %H:%m:%S"),process,jobname,category,format(...)))
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

--~ local syslogname = "oeps.xxx"
--~
--~ for i=1,10 do
--~     logs.system(syslogname,"context","test","fonts","font %s recached due to newer version (%s)","blabla","123")
--~ end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- After a few years using the code the large luat-inp.lua file
-- has been split up a bit. In the process some functionality was
-- dropped:
--
-- * support for reading lsr files
-- * selective scanning (subtrees)
-- * some public auxiliary functions were made private
--
-- TODO: os.getenv -> os.env[]
-- TODO: instances.[hashes,cnffiles,configurations,522] -> ipairs (alles check, sneller)
-- TODO: check escaping in find etc, too much, too slow

-- This lib is multi-purpose and can be loaded again later on so that
-- additional functionality becomes available. We will split thislogs.report("fileio",
-- module in components once we're done with prototyping. This is the
-- first code I wrote for LuaTeX, so it needs some cleanup. Before changing
-- something in this module one can best check with Taco or Hans first; there
-- is some nasty trickery going on that relates to traditional kpse support.

-- To be considered: hash key lowercase, first entry in table filename
-- (any case), rest paths (so no need for optimization). Or maybe a
-- separate table that matches lowercase names to mixed case when
-- present. In that case the lower() cases can go away. I will do that
-- only when we run into problems with names ... well ... Iwona-Regular.

-- Beware, loading and saving is overloaded in luat-tmp!

local format, gsub, find, lower, upper, match, gmatch = string.format, string.gsub, string.find, string.lower, string.upper, string.match, string.gmatch
local concat, insert, sortedkeys = table.concat, table.insert, table.sortedkeys
local next, type = next, type

local trace_locating, trace_detail, trace_verbose  = false, false, false

trackers.register("resolvers.verbose",  function(v) trace_verbose  = v end)
trackers.register("resolvers.locating", function(v) trace_locating = v trackers.enable("resolvers.verbose") end)
trackers.register("resolvers.detail",   function(v) trace_detail   = v trackers.enable("resolvers.verbose,resolvers.detail") end)

if not resolvers then
    resolvers = {
        suffixes     = { },
        formats      = { },
        dangerous    = { },
        suffixmap    = { },
        alternatives = { },
        locators     = { },  -- locate databases
        hashers      = { },  -- load databases
        generators   = { },  -- generate databases
    }
end

local resolvers = resolvers

resolvers.locators  .notfound = { nil }
resolvers.hashers   .notfound = { nil }
resolvers.generators.notfound = { nil }

resolvers.cacheversion = '1.0.1'
resolvers.cnfname      = 'texmf.cnf'
resolvers.luaname      = 'texmfcnf.lua'
resolvers.homedir      = os.env[os.platform == "windows" and 'USERPROFILE'] or os.env['HOME'] or '~'
resolvers.cnfdefault   = '{$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}'

local dummy_path_expr = "^!*unset/*$"

local formats      = resolvers.formats
local suffixes     = resolvers.suffixes
local dangerous    = resolvers.dangerous
local suffixmap    = resolvers.suffixmap
local alternatives = resolvers.alternatives

formats['afm'] = 'AFMFONTS'       suffixes['afm'] = { 'afm' }
formats['enc'] = 'ENCFONTS'       suffixes['enc'] = { 'enc' }
formats['fmt'] = 'TEXFORMATS'     suffixes['fmt'] = { 'fmt' }
formats['map'] = 'TEXFONTMAPS'    suffixes['map'] = { 'map' }
formats['mp']  = 'MPINPUTS'       suffixes['mp']  = { 'mp' }
formats['ocp'] = 'OCPINPUTS'      suffixes['ocp'] = { 'ocp' }
formats['ofm'] = 'OFMFONTS'       suffixes['ofm'] = { 'ofm', 'tfm' }
formats['otf'] = 'OPENTYPEFONTS'  suffixes['otf'] = { 'otf' } -- 'ttf'
formats['opl'] = 'OPLFONTS'       suffixes['opl'] = { 'opl' }
formats['otp'] = 'OTPINPUTS'      suffixes['otp'] = { 'otp' }
formats['ovf'] = 'OVFFONTS'       suffixes['ovf'] = { 'ovf', 'vf' }
formats['ovp'] = 'OVPFONTS'       suffixes['ovp'] = { 'ovp' }
formats['tex'] = 'TEXINPUTS'      suffixes['tex'] = { 'tex' }
formats['tfm'] = 'TFMFONTS'       suffixes['tfm'] = { 'tfm' }
formats['ttf'] = 'TTFONTS'        suffixes['ttf'] = { 'ttf', 'ttc', 'dfont' }
formats['pfb'] = 'T1FONTS'        suffixes['pfb'] = { 'pfb', 'pfa' }
formats['vf']  = 'VFFONTS'        suffixes['vf']  = { 'vf' }

formats['fea'] = 'FONTFEATURES'   suffixes['fea'] = { 'fea' }
formats['cid'] = 'FONTCIDMAPS'    suffixes['cid'] = { 'cid', 'cidmap' }

formats ['texmfscripts'] = 'TEXMFSCRIPTS' -- new
suffixes['texmfscripts'] = { 'rb', 'pl', 'py' } -- 'lua'

formats ['lua'] = 'LUAINPUTS' -- new
suffixes['lua'] = { 'lua', 'luc', 'tma', 'tmc' }

-- backward compatible ones

alternatives['map files']            = 'map'
alternatives['enc files']            = 'enc'
alternatives['cid files']            = 'cid'
alternatives['fea files']            = 'fea'
alternatives['opentype fonts']       = 'otf'
alternatives['truetype fonts']       = 'ttf'
alternatives['truetype collections'] = 'ttc'
alternatives['truetype dictionary']  = 'dfont'
alternatives['type1 fonts']          = 'pfb'

-- obscure ones

formats ['misc fonts'] = ''
suffixes['misc fonts'] = { }

formats     ['sfd']                      = 'SFDFONTS'
suffixes    ['sfd']                      = { 'sfd' }
alternatives['subfont definition files'] = 'sfd'

-- In practice we will work within one tds tree, but i want to keep
-- the option open to build tools that look at multiple trees, which is
-- why we keep the tree specific data in a table. We used to pass the
-- instance but for practical pusposes we now avoid this and use a
-- instance variable.

-- here we catch a few new thingies (todo: add these paths to context.tmf)
--
-- FONTFEATURES  = .;$TEXMF/fonts/fea//
-- FONTCIDMAPS   = .;$TEXMF/fonts/cid//

-- we always have one instance active

resolvers.instance = resolvers.instance or nil -- the current one (slow access)
local instance = resolvers.instance or nil -- the current one (fast access)

function resolvers.newinstance()

    -- store once, freeze and faster (once reset we can best use
    -- instance.environment) maybe better have a register suffix
    -- function

    for k, v in next, suffixes do
        for i=1,#v do
            local vi = v[i]
            if vi then
                suffixmap[vi] = k
            end
        end
    end

    -- because vf searching is somewhat dangerous, we want to prevent
    -- too liberal searching esp because we do a lookup on the current
    -- path anyway; only tex (or any) is safe

    for k, v in next, formats do
        dangerous[k] = true
    end
    dangerous.tex = nil

    -- the instance

    local newinstance = {
        rootpath        = '',
        treepath        = '',
        progname        = 'context',
        engine          = 'luatex',
        format          = '',
        environment     = { },
        variables       = { },
        expansions      = { },
        files           = { },
        remap           = { },
        configuration   = { },
        setup           = { },
        order           = { },
        found           = { },
        foundintrees    = { },
        kpsevars        = { },
        hashes          = { },
        cnffiles        = { },
        luafiles        = { },
        lists           = { },
        remember        = true,
        diskcache       = true,
        renewcache      = false,
        scandisk        = true,
        cachepath       = nil,
        loaderror       = false,
        sortdata        = false,
        savelists       = true,
        cleanuppaths    = true,
        allresults      = false,
        pattern         = nil, -- lists
        data            = { }, -- only for loading
        force_suffixes  = true,
        fakepaths       = { },
    }

    local ne = newinstance.environment

    for k,v in next, os.env do
        ne[k] = resolvers.bare_variable(v)
    end

    return newinstance

end

function resolvers.setinstance(someinstance)
    instance = someinstance
    resolvers.instance = someinstance
    return someinstance
end

function resolvers.reset()
    return resolvers.setinstance(resolvers.newinstance())
end

local function reset_hashes()
    instance.lists = { }
    instance.found = { }
end

local function check_configuration() -- not yet ok, no time for debugging now
    local ie, iv = instance.environment, instance.variables
    local function fix(varname,default)
        local proname = varname .. "." .. instance.progname or "crap"
        local p, v = ie[proname], ie[varname] or iv[varname]
        if not ((p and p ~= "") or (v and v ~= "")) then
            iv[varname] = default -- or environment?
        end
    end
    local name = os.name
    if name == "windows" then
        fix("OSFONTDIR", "c:/windows/fonts//")
    elseif name == "macosx" then
        fix("OSFONTDIR", "$HOME/Library/Fonts//;/Library/Fonts//;/System/Library/Fonts//")
    else
        -- bad luck
    end
    fix("LUAINPUTS"   , ".;$TEXINPUTS;$TEXMFSCRIPTS") -- no progname, hm
    fix("FONTFEATURES", ".;$TEXMF/fonts/fea//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS")
    fix("FONTCIDMAPS" , ".;$TEXMF/fonts/cid//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS")
    fix("LUATEXLIBS"  , ".;$TEXMF/luatex/lua//")
end

function resolvers.bare_variable(str) -- assumes str is a string
    return (gsub(str,"\s*([\"\']?)(.+)%1\s*", "%2"))
end

function resolvers.settrace(n) -- no longer number but: 'locating' or 'detail'
    if n then
        trackers.disable("resolvers.*")
        trackers.enable("resolvers."..n)
    end
end

resolvers.settrace(os.getenv("MTX.resolvers.TRACE") or os.getenv("MTX_INPUT_TRACE"))

function resolvers.osenv(key)
    local ie = instance.environment
    local value = ie[key]
    if value == nil then
     -- local e = os.getenv(key)
        local e = os.env[key]
        if e == nil then
         -- value = "" -- false
        else
            value = resolvers.bare_variable(e)
        end
        ie[key] = value
    end
    return value or ""
end

function resolvers.env(key)
    return instance.environment[key] or resolvers.osenv(key)
end

--

local function expand_vars(lst) -- simple vars
    local variables, env = instance.variables, resolvers.env
    local function resolve(a)
        return variables[a] or env(a)
    end
    for k=1,#lst do
        lst[k] = gsub(lst[k],"%$([%a%d%_%-]+)",resolve)
    end
end

local function expanded_var(var) -- simple vars
    local function resolve(a)
        return instance.variables[a] or resolvers.env(a)
    end
    return (gsub(var,"%$([%a%d%_%-]+)",resolve))
end

local function entry(entries,name)
    if name and (name ~= "") then
        name = gsub(name,'%$','')
        local result = entries[name..'.'..instance.progname] or entries[name]
        if result then
            return result
        else
            result = resolvers.env(name)
            if result then
                instance.variables[name] = result
                resolvers.expand_variables()
                return instance.expansions[name] or ""
            end
        end
    end
    return ""
end

local function is_entry(entries,name)
    if name and name ~= "" then
        name = gsub(name,'%$','')
        return (entries[name..'.'..instance.progname] or entries[name]) ~= nil
    else
        return false
    end
end

-- {a,b,c,d}
-- a,b,c/{p,q,r},d
-- a,b,c/{p,q,r}/d/{x,y,z}//
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a{b,c}{d,e}f
-- {a,b,c,d}
-- {a,b,c/{p,q,r},d}
-- {a,b,c/{p,q,r}/d/{x,y,z}//}
-- {a,b,c/{p,q/{x,y,z}},d/{p,q,r}}
-- {a,b,c/{p,q/{x,y,z},w}v,d/{p,q,r}}
-- {$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}

-- this one is better and faster, but it took me a while to realize
-- that this kind of replacement is cleaner than messy parsing and
-- fuzzy concatenating we can probably gain a bit with selectively
-- applying lpeg, but experiments with lpeg parsing this proved not to
-- work that well; the parsing is ok, but dealing with the resulting
-- table is a pain because we need to work inside-out recursively

local function splitpathexpr(str, t, validate)
    -- no need for further optimization as it is only called a
    -- few times, we can use lpeg for the sub; we could move
    -- the local functions outside the body
    t = t or { }
    str = gsub(str,",}",",@}")
    str = gsub(str,"{,","{@,")
 -- str = "@" .. str .. "@"
    local ok, done
    local function do_first(a,b)
        local t = { }
        for s in gmatch(b,"[^,]+") do t[#t+1] = a .. s end
        return "{" .. concat(t,",") .. "}"
    end
    local function do_second(a,b)
        local t = { }
        for s in gmatch(a,"[^,]+") do t[#t+1] = s .. b end
        return "{" .. concat(t,",") .. "}"
    end
    local function do_both(a,b)
        local t = { }
        for sa in gmatch(a,"[^,]+") do
            for sb in gmatch(b,"[^,]+") do
                t[#t+1] = sa .. sb
            end
        end
        return "{" .. concat(t,",") .. "}"
    end
    local function do_three(a,b,c)
        return a .. b.. c
    end
    while true do
        done = false
        while true do
            str, ok = gsub(str,"([^{},]+){([^{}]+)}",do_first)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}([^{},]+)",do_second)
            if ok > 0 then done = true else break end
        end
        while true do
            str, ok = gsub(str,"{([^{}]+)}{([^{}]+)}",do_both)
            if ok > 0 then done = true else break end
        end
        str, ok = gsub(str,"({[^{}]*){([^{}]+)}([^{}]*})",do_three)
        if ok > 0 then done = true end
        if not done then break end
    end
    str = gsub(str,"[{}]", "")
    str = gsub(str,"@","")
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then t[#t+1] = s end
        end
    else
        for s in gmatch(str,"[^,]+") do
            t[#t+1] = s
        end
    end
    return t
end

local function expanded_path_from_list(pathlist) -- maybe not a list, just a path
    -- a previous version fed back into pathlist
    local newlist, ok = { }, false
    for k=1,#pathlist do
        if find(pathlist[k],"[{}]") then
            ok = true
            break
        end
    end
    if ok then
        local function validate(s)
            s = file.collapse_path(s)
            return s ~= "" and not find(s,dummy_path_expr) and s
        end
        for k=1,#pathlist do
            splitpathexpr(pathlist[k],newlist,validate)
        end
    else
        for k=1,#pathlist do
            for p in gmatch(pathlist[k],"([^,]+)") do
                p = file.collapse_path(p)
                if p ~= "" then newlist[#newlist+1] = p end
            end
        end
    end
    return newlist
end

-- we follow a rather traditional approach:
--
-- (1) texmf.cnf given in TEXMFCNF
-- (2) texmf.cnf searched in default variable
--
-- also we now follow the stupid route: if not set then just assume *one*
-- cnf file under texmf (i.e. distribution)

resolvers.ownpath     = resolvers.ownpath or nil
resolvers.ownbin      = resolvers.ownbin  or arg[-2] or arg[-1] or arg[0] or "luatex"
resolvers.autoselfdir = true -- false may be handy for debugging

function resolvers.getownpath()
    if not resolvers.ownpath then
        if resolvers.autoselfdir and os.selfdir then
            resolvers.ownpath = os.selfdir
        else
            local binary = resolvers.ownbin
            if os.platform == "windows" then
                binary = file.replacesuffix(binary,"exe")
            end
            for p in gmatch(os.getenv("PATH"),"[^"..io.pathseparator.."]+") do
                local b = file.join(p,binary)
                if lfs.isfile(b) then
                    -- we assume that after changing to the path the currentdir function
                    -- resolves to the real location and use this side effect here; this
                    -- trick is needed because on the mac installations use symlinks in the
                    -- path instead of real locations
                    local olddir = lfs.currentdir()
                    if lfs.chdir(p) then
                        local pp = lfs.currentdir()
                        if trace_verbose and p ~= pp then
                            logs.report("fileio","following symlink %s to %s",p,pp)
                        end
                        resolvers.ownpath = pp
                        lfs.chdir(olddir)
                    else
                        if trace_verbose then
                            logs.report("fileio","unable to check path %s",p)
                        end
                        resolvers.ownpath =  p
                    end
                    break
                end
            end
        end
        if not resolvers.ownpath then resolvers.ownpath = '.' end
    end
    return resolvers.ownpath
end

local own_places = { "SELFAUTOLOC", "SELFAUTODIR", "SELFAUTOPARENT", "TEXMFCNF" }

local function identify_own()
    local ownpath = resolvers.getownpath() or lfs.currentdir()
    local ie = instance.environment
    if ownpath then
        if resolvers.env('SELFAUTOLOC')    == "" then os.env['SELFAUTOLOC']    = file.collapse_path(ownpath) end
        if resolvers.env('SELFAUTODIR')    == "" then os.env['SELFAUTODIR']    = file.collapse_path(ownpath .. "/..") end
        if resolvers.env('SELFAUTOPARENT') == "" then os.env['SELFAUTOPARENT'] = file.collapse_path(ownpath .. "/../..") end
    else
        logs.report("fileio","error: unable to locate ownpath")
        os.exit()
    end
    if resolvers.env('TEXMFCNF') == "" then os.env['TEXMFCNF'] = resolvers.cnfdefault end
    if resolvers.env('TEXOS')    == "" then os.env['TEXOS']    = resolvers.env('SELFAUTODIR') end
    if resolvers.env('TEXROOT')  == "" then os.env['TEXROOT']  = resolvers.env('SELFAUTOPARENT') end
    if trace_verbose then
        for i=1,#own_places do
            local v = own_places[i]
            logs.report("fileio","variable %s set to %s",v,resolvers.env(v) or "unknown")
        end
    end
    identify_own = function() end
end

function resolvers.identify_cnf()
    if #instance.cnffiles == 0 then
        -- fallback
        identify_own()
        -- the real search
        resolvers.expand_variables()
        local t = resolvers.split_path(resolvers.env('TEXMFCNF'))
        t = expanded_path_from_list(t)
        expand_vars(t) -- redundant
        local function locate(filename,list)
            for i=1,#t do
                local ti = t[i]
                local texmfcnf = file.collapse_path(file.join(ti,filename))
                if lfs.isfile(texmfcnf) then
                    list[#list+1] = texmfcnf
                end
            end
        end
        locate(resolvers.luaname,instance.luafiles)
        locate(resolvers.cnfname,instance.cnffiles)
    end
end

local function load_cnf_file(fname)
    fname = resolvers.clean_path(fname)
    local lname = file.replacesuffix(fname,'lua')
    local f = io.open(lname)
    if f then -- this will go
        f:close()
        local dname = file.dirname(fname)
        if not instance.configuration[dname] then
            resolvers.load_data(dname,'configuration',lname and file.basename(lname))
            instance.order[#instance.order+1] = instance.configuration[dname]
        end
    else
        f = io.open(fname)
        if f then
            if trace_verbose then
                logs.report("fileio","loading %s", fname)
            end
            local line, data, n, k, v
            local dname = file.dirname(fname)
            if not instance.configuration[dname] then
                instance.configuration[dname] = { }
                instance.order[#instance.order+1] = instance.configuration[dname]
            end
            local data = instance.configuration[dname]
            while true do
                local line, n = f:read(), 0
                if line then
                    while true do -- join lines
                        line, n = gsub(line,"\\%s*$", "")
                        if n > 0 then
                            line = line .. f:read()
                        else
                            break
                        end
                    end
                    if not find(line,"^[%%#]") then
                        local l = gsub(line,"%s*%%.*$","")
                        local k, v = match(l,"%s*(.-)%s*=%s*(.-)%s*$")
                        if k and v and not data[k] then
                            v = gsub(v,"[%%#].*",'')
                            data[k] = gsub(v,"~","$HOME")
                            instance.kpsevars[k] = true
                        end
                    end
                else
                    break
                end
            end
            f:close()
        elseif trace_verbose then
            logs.report("fileio","skipping %s", fname)
        end
    end
end

local function collapse_cnf_data() -- potential optimization: pass start index (setup and configuration are shared)
    for _,c in ipairs(instance.order) do
        for k,v in next, c do
            if not instance.variables[k] then
                if instance.environment[k] then
                    instance.variables[k] = instance.environment[k]
                else
                    instance.kpsevars[k] = true
                    instance.variables[k] = resolvers.bare_variable(v)
                end
            end
        end
    end
end

function resolvers.load_cnf()
    local function loadoldconfigdata()
        for _, fname in ipairs(instance.cnffiles) do
            load_cnf_file(fname)
        end
    end
    -- instance.cnffiles contain complete names now !
    if #instance.cnffiles == 0 then
        if trace_verbose then
            logs.report("fileio","no cnf files found (TEXMFCNF may not be set/known)")
        end
    else
        instance.rootpath = instance.cnffiles[1]
        for k,fname in ipairs(instance.cnffiles) do
            instance.cnffiles[k] = file.collapse_path(gsub(fname,"\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = file.collapse_path(instance.rootpath)
        if instance.diskcache and not instance.renewcache then
            resolvers.loadoldconfig(instance.cnffiles)
            if instance.loaderror then
                loadoldconfigdata()
                resolvers.saveoldconfig()
            end
        else
            loadoldconfigdata()
            if instance.renewcache then
                resolvers.saveoldconfig()
            end
        end
        collapse_cnf_data()
    end
    check_configuration()
end

function resolvers.load_lua()
    if #instance.luafiles == 0 then
        -- yet harmless
    else
        instance.rootpath = instance.luafiles[1]
        for k,fname in ipairs(instance.luafiles) do
            instance.luafiles[k] = file.collapse_path(gsub(fname,"\\",'/'))
        end
        for i=1,3 do
            instance.rootpath = file.dirname(instance.rootpath)
        end
        instance.rootpath = file.collapse_path(instance.rootpath)
        resolvers.loadnewconfig()
        collapse_cnf_data()
    end
    check_configuration()
end

-- database loading

function resolvers.load_hash()
    resolvers.locatelists()
    if instance.diskcache and not instance.renewcache then
        resolvers.loadfiles()
        if instance.loaderror then
            resolvers.loadlists()
            resolvers.savefiles()
        end
    else
        resolvers.loadlists()
        if instance.renewcache then
            resolvers.savefiles()
        end
    end
end

function resolvers.append_hash(type,tag,name)
    if trace_locating then
        logs.report("fileio","= hash append: %s",tag)
    end
    insert(instance.hashes, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function resolvers.prepend_hash(type,tag,name)
    if trace_locating then
        logs.report("fileio","= hash prepend: %s",tag)
    end
    insert(instance.hashes, 1, { ['type']=type, ['tag']=tag, ['name']=name } )
end

function resolvers.extend_texmf_var(specification) -- crap, we could better prepend the hash
--  local t = resolvers.expanded_path_list('TEXMF') -- full expansion
    local t = resolvers.split_path(resolvers.env('TEXMF'))
    insert(t,1,specification)
    local newspec = concat(t,";")
    if instance.environment["TEXMF"] then
        instance.environment["TEXMF"] = newspec
    elseif instance.variables["TEXMF"] then
        instance.variables["TEXMF"] = newspec
    else
        -- weird
    end
    resolvers.expand_variables()
    reset_hashes()
end

-- locators

function resolvers.locatelists()
    for _, path in ipairs(resolvers.clean_path_list('TEXMF')) do
        if trace_verbose then
            logs.report("fileio","locating list of %s",path)
        end
        resolvers.locatedatabase(file.collapse_path(path))
    end
end

function resolvers.locatedatabase(specification)
    return resolvers.methodhandler('locators', specification)
end

function resolvers.locators.tex(specification)
    if specification and specification ~= '' and lfs.isdir(specification) then
        if trace_locating then
            logs.report("fileio",'! tex locator found: %s',specification)
        end
        resolvers.append_hash('file',specification,filename)
    elseif trace_locating then
        logs.report("fileio",'? tex locator not found: %s',specification)
    end
end

-- hashers

function resolvers.hashdatabase(tag,name)
    return resolvers.methodhandler('hashers',tag,name)
end

function resolvers.loadfiles()
    instance.loaderror = false
    instance.files = { }
    if not instance.renewcache then
        for _, hash in ipairs(instance.hashes) do
            resolvers.hashdatabase(hash.tag,hash.name)
            if instance.loaderror then break end
        end
    end
end

function resolvers.hashers.tex(tag,name)
    resolvers.load_data(tag,'files')
end

-- generators:

function resolvers.loadlists()
    for _, hash in ipairs(instance.hashes) do
        resolvers.generatedatabase(hash.tag)
    end
end

function resolvers.generatedatabase(specification)
    return resolvers.methodhandler('generators', specification)
end

-- starting with . or .. etc or funny char

local weird = lpeg.P(".")^1 + lpeg.anywhere(lpeg.S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))

function resolvers.generators.tex(specification)
    local tag = specification
    if trace_verbose then
        logs.report("fileio","scanning path %s",specification)
    end
    instance.files[tag] = { }
    local files = instance.files[tag]
    local n, m, r = 0, 0, 0
    local spec = specification .. '/'
    local attributes = lfs.attributes
    local directory = lfs.dir
    local function action(path)
        local full
        if path then
            full = spec .. path .. '/'
        else
            full = spec
        end
        for name in directory(full) do
            if not weird:match(name) then
                local mode = attributes(full..name,'mode')
                if mode == 'file' then
                    if path then
                        n = n + 1
                        local f = files[name]
                        if f then
                            if type(f) == 'string' then
                                files[name] = { f, path }
                            else
                                f[#f+1] = path
                            end
                        else -- probably unique anyway
                            files[name] = path
                            local lower = lower(name)
                            if name ~= lower then
                                files["remap:"..lower] = name
                                r = r + 1
                            end
                        end
                    end
                elseif mode == 'directory' then
                    m = m + 1
                    if path then
                        action(path..'/'..name)
                    else
                        action(name)
                    end
                end
            end
        end
    end
    action()
    if trace_verbose then
        logs.report("fileio","%s files found on %s directories with %s uppercase remappings",n,m,r)
    end
end

-- savers, todo

function resolvers.savefiles()
    resolvers.save_data('files')
end

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

function resolvers.splitconfig()
    for i,c in ipairs(instance) do
        for k,v in pairs(c) do
            if type(v) == 'string' then
                local t = file.split_path(v)
                if #t > 1 then
                    c[k] = t
                end
            end
        end
    end
end

function resolvers.joinconfig()
    for i,c in ipairs(instance.order) do
        for k,v in pairs(c) do -- ipairs?
            if type(v) == 'table' then
                c[k] = file.join_path(v)
            end
        end
    end
end
function resolvers.split_path(str)
    if type(str) == 'table' then
        return str
    else
        return file.split_path(str)
    end
end
function resolvers.join_path(str)
    if type(str) == 'table' then
        return file.join_path(str)
    else
        return str
    end
end

function resolvers.splitexpansions()
    local ie = instance.expansions
    for k,v in next, ie do
        local t, h = { }, { }
        for _,vv in ipairs(file.split_path(v)) do
            if vv ~= "" and not h[vv] then
                t[#t+1] = vv
                h[vv] = true
            end
        end
        if #t > 1 then
            ie[k] = t
        else
            ie[k] = t[1]
        end
    end
end

-- end of split/join code

function resolvers.saveoldconfig()
    resolvers.splitconfig()
    resolvers.save_data('configuration')
    resolvers.joinconfig()
end

resolvers.configbanner = [[
-- This is a Luatex configuration file created by 'luatools.lua' or
-- 'luatex.exe' directly. For comment, suggestions and questions you can
-- contact the ConTeXt Development Team. This configuration file is
-- not copyrighted. [HH & TH]
]]

function resolvers.serialize(files)
    -- This version is somewhat optimized for the kind of
    -- tables that we deal with, so it's much faster than
    -- the generic serializer. This makes sense because
    -- luatools and mtxtools are called frequently. Okay,
    -- we pay a small price for properly tabbed tables.
    local t = { }
    local function dump(k,v,m) -- could be moved inline
        if type(v) == 'string' then
            return m .. "['" .. k .. "']='" .. v .. "',"
        elseif #v == 1 then
            return m .. "['" .. k .. "']='" .. v[1] .. "',"
        else
            return m .. "['" .. k .. "']={'" .. concat(v,"','").. "'},"
        end
    end
    t[#t+1] = "return {"
    if instance.sortdata then
        for _, k in pairs(sortedkeys(files)) do -- ipairs
            local fk  = files[k]
            if type(fk) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for _, kk in pairs(sortedkeys(fk)) do -- ipairs
                    t[#t+1] = dump(kk,fk[kk],"\t\t")
                end
                t[#t+1] = "\t},"
            else
                t[#t+1] = dump(k,fk,"\t")
            end
        end
    else
        for k, v in next, files do
            if type(v) == 'table' then
                t[#t+1] = "\t['" .. k .. "']={"
                for kk,vv in next, v do
                    t[#t+1] = dump(kk,vv,"\t\t")
                end
                t[#t+1] = "\t},"
            else
                t[#t+1] = dump(k,v,"\t")
            end
        end
    end
    t[#t+1] = "}"
    return concat(t,"\n")
end

function resolvers.save_data(dataname, makename) -- untested without cache overload
    for cachename, files in next, instance[dataname] do
        local name = (makename or file.join)(cachename,dataname)
        local luaname, lucname = name .. ".lua", name .. ".luc"
        if trace_verbose then
            logs.report("fileio","preparing %s for %s",dataname,cachename)
        end
        for k, v in next, files do
            if type(v) == "table" and #v == 1 then
                files[k] = v[1]
            end
        end
        local data = {
            type    = dataname,
            root    = cachename,
            version = resolvers.cacheversion,
            date    = os.date("%Y-%m-%d"),
            time    = os.date("%H:%M:%S"),
            content = files,
        }
        local ok = io.savedata(luaname,resolvers.serialize(data))
        if ok then
            if trace_verbose then
                logs.report("fileio","%s saved in %s",dataname,luaname)
            end
            if utils.lua.compile(luaname,lucname,false,true) then -- no cleanup but strip
                if trace_verbose then
                    logs.report("fileio","%s compiled to %s",dataname,lucname)
                end
            else
                if trace_verbose then
                    logs.report("fileio","compiling failed for %s, deleting file %s",dataname,lucname)
                end
                os.remove(lucname)
            end
        elseif trace_verbose then
            logs.report("fileio","unable to save %s in %s (access error)",dataname,luaname)
        end
    end
end

function resolvers.load_data(pathname,dataname,filename,makename) -- untested without cache overload
    filename = ((not filename or (filename == "")) and dataname) or filename
    filename = (makename and makename(dataname,filename)) or file.join(pathname,filename)
    local blob = loadfile(filename .. ".luc") or loadfile(filename .. ".lua")
    if blob then
        local data = blob()
        if data and data.content and data.type == dataname and data.version == resolvers.cacheversion then
            if trace_verbose then
                logs.report("fileio","loading %s for %s from %s",dataname,pathname,filename)
            end
            instance[dataname][pathname] = data.content
        else
            if trace_verbose then
                logs.report("fileio","skipping %s for %s from %s",dataname,pathname,filename)
            end
            instance[dataname][pathname] = { }
            instance.loaderror = true
        end
    elseif trace_verbose then
        logs.report("fileio","skipping %s for %s from %s",dataname,pathname,filename)
    end
end

-- some day i'll use the nested approach, but not yet (actually we even drop
-- engine/progname support since we have only luatex now)
--
-- first texmfcnf.lua files are located, next the cached texmf.cnf files
--
-- return {
--     TEXMFBOGUS = 'effe checken of dit werkt',
-- }

function resolvers.resetconfig()
    identify_own()
    instance.configuration, instance.setup, instance.order, instance.loaderror = { }, { }, { }, false
end

function resolvers.loadnewconfig()
    for _, cnf in ipairs(instance.luafiles) do
        local pathname = file.dirname(cnf)
        local filename = file.join(pathname,resolvers.luaname)
        local blob = loadfile(filename)
        if blob then
            local data = blob()
            if data then
                if trace_verbose then
                    logs.report("fileio","loading configuration file %s",filename)
                end
                if true then
                    -- flatten to variable.progname
                    local t = { }
                    for k, v in next, data do -- v = progname
                        if type(v) == "string" then
                            t[k] = v
                        else
                            for kk, vv in next, v do -- vv = variable
                                if type(vv) == "string" then
                                    t[vv.."."..v] = kk
                                end
                            end
                        end
                    end
                    instance['setup'][pathname] = t
                else
                    instance['setup'][pathname] = data
                end
            else
                if trace_verbose then
                    logs.report("fileio","skipping configuration file %s",filename)
                end
                instance['setup'][pathname] = { }
                instance.loaderror = true
            end
        elseif trace_verbose then
            logs.report("fileio","skipping configuration file %s",filename)
        end
        instance.order[#instance.order+1] = instance.setup[pathname]
        if instance.loaderror then break end
    end
end

function resolvers.loadoldconfig()
    if not instance.renewcache then
        for _, cnf in ipairs(instance.cnffiles) do
            local dname = file.dirname(cnf)
            resolvers.load_data(dname,'configuration')
            instance.order[#instance.order+1] = instance.configuration[dname]
            if instance.loaderror then break end
        end
    end
    resolvers.joinconfig()
end

function resolvers.expand_variables()
    local expansions, environment, variables = { }, instance.environment, instance.variables
    local env = resolvers.env
    instance.expansions = expansions
    if instance.engine   ~= "" then environment['engine']   = instance.engine   end
    if instance.progname ~= "" then environment['progname'] = instance.progname end
    for k,v in next, environment do
        local a, b = match(k,"^(%a+)%_(.*)%s*$")
        if a and b then
            expansions[a..'.'..b] = v
        else
            expansions[k] = v
        end
    end
    for k,v in next, environment do -- move environment to expansions
        if not expansions[k] then expansions[k] = v end
    end
    for k,v in next, variables do -- move variables to expansions
        if not expansions[k] then expansions[k] = v end
    end
    local busy = false
    local function resolve(a)
        busy = true
        return expansions[a] or env(a)
    end
    while true do
        busy = false
        for k,v in next, expansions do
            local s, n = gsub(v,"%$([%a%d%_%-]+)",resolve)
            local s, m = gsub(s,"%$%{([%a%d%_%-]+)%}",resolve)
            if n > 0 or m > 0 then
                expansions[k]= s
            end
        end
        if not busy then break end
    end
    for k,v in next, expansions do
        expansions[k] = gsub(v,"\\", '/')
    end
end

function resolvers.variable(name)
    return entry(instance.variables,name)
end

function resolvers.expansion(name)
    return entry(instance.expansions,name)
end

function resolvers.is_variable(name)
    return is_entry(instance.variables,name)
end

function resolvers.is_expansion(name)
    return is_entry(instance.expansions,name)
end

function resolvers.unexpanded_path_list(str)
    local pth = resolvers.variable(str)
    local lst = resolvers.split_path(pth)
    return expanded_path_from_list(lst)
end

function resolvers.unexpanded_path(str)
    return file.join_path(resolvers.unexpanded_path_list(str))
end

do -- no longer needed

    local done = { }

    function resolvers.reset_extra_path()
        local ep = instance.extra_paths
        if not ep then
            ep, done = { }, { }
            instance.extra_paths = ep
        elseif #ep > 0 then
            instance.lists, done = { }, { }
        end
    end

    function resolvers.register_extra_path(paths,subpaths)
        local ep = instance.extra_paths or { }
        local n = #ep
        if paths and paths ~= "" then
            if subpaths and subpaths ~= "" then
                for p in gmatch(paths,"[^,]+") do
                    -- we gmatch each step again, not that fast, but used seldom
                    for s in gmatch(subpaths,"[^,]+") do
                        local ps = p .. "/" .. s
                        if not done[ps] then
                            ep[#ep+1] = resolvers.clean_path(ps)
                            done[ps] = true
                        end
                    end
                end
            else
                for p in gmatch(paths,"[^,]+") do
                    if not done[p] then
                        ep[#ep+1] = resolvers.clean_path(p)
                        done[p] = true
                    end
                end
            end
        elseif subpaths and subpaths ~= "" then
            for i=1,n do
                -- we gmatch each step again, not that fast, but used seldom
                for s in gmatch(subpaths,"[^,]+") do
                    local ps = ep[i] .. "/" .. s
                    if not done[ps] then
                        ep[#ep+1] = resolvers.clean_path(ps)
                        done[ps] = true
                    end
                end
            end
        end
        if #ep > 0 then
            instance.extra_paths = ep -- register paths
        end
        if #ep > n then
            instance.lists = { } -- erase the cache
        end
    end

end

local function made_list(instance,list)
    local ep = instance.extra_paths
    if not ep or #ep == 0 then
        return list
    else
        local done, new = { }, { }
        -- honour . .. ../.. but only when at the start
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                if find(v,"^[%.%/]$") then
                    done[v] = true
                    new[#new+1] = v
                else
                    break
                end
            end
        end
        -- first the extra paths
        for k=1,#ep do
            local v = ep[k]
            if not done[v] then
                done[v] = true
                new[#new+1] = v
            end
        end
        -- next the formal paths
        for k=1,#list do
            local v = list[k]
            if not done[v] then
                done[v] = true
                new[#new+1] = v
            end
        end
        return new
    end
end

function resolvers.clean_path_list(str)
    local t = resolvers.expanded_path_list(str)
    if t then
        for i=1,#t do
            t[i] = file.collapse_path(resolvers.clean_path(t[i]))
        end
    end
    return t
end

function resolvers.expand_path(str)
    return file.join_path(resolvers.expanded_path_list(str))
end

function resolvers.expanded_path_list(str)
    if not str then
        return ep or { }
    elseif instance.savelists then
        -- engine+progname hash
        str = gsub(str,"%$","")
        if not instance.lists[str] then -- cached
            local lst = made_list(instance,resolvers.split_path(resolvers.expansion(str)))
            instance.lists[str] = expanded_path_from_list(lst)
        end
        return instance.lists[str]
    else
        local lst = resolvers.split_path(resolvers.expansion(str))
        return made_list(instance,expanded_path_from_list(lst))
    end
end

function resolvers.expanded_path_list_from_var(str) -- brrr
    local tmp = resolvers.var_of_format_or_suffix(gsub(str,"%$",""))
    if tmp ~= "" then
        return resolvers.expanded_path_list(str)
    else
        return resolvers.expanded_path_list(tmp)
    end
end

function resolvers.expand_path_from_var(str)
    return file.join_path(resolvers.expanded_path_list_from_var(str))
end

function resolvers.format_of_var(str)
    return formats[str] or formats[alternatives[str]] or ''
end
function resolvers.format_of_suffix(str)
    return suffixmap[file.extname(str)] or 'tex'
end

function resolvers.variable_of_format(str)
    return formats[str] or formats[alternatives[str]] or ''
end

function resolvers.var_of_format_or_suffix(str)
    local v = formats[str]
    if v then
        return v
    end
    v = formats[alternatives[str]]
    if v then
        return v
    end
    v = suffixmap[file.extname(str)]
    if v then
        return formats[isf]
    end
    return ''
end

function resolvers.expand_braces(str) -- output variable and brace expansion of STRING
    local ori = resolvers.variable(str)
    local pth = expanded_path_from_list(resolvers.split_path(ori))
    return file.join_path(pth)
end

resolvers.isreadable = { }

function resolvers.isreadable.file(name)
    local readable = lfs.isfile(name) -- brrr
    if trace_detail then
        if readable then
            logs.report("fileio","+ readable: %s",name)
        else
            logs.report("fileio","- readable: %s", name)
        end
    end
    return readable
end

resolvers.isreadable.tex = resolvers.isreadable.file

-- name
-- name/name

local function collect_files(names)
    local filelist = { }
    for k=1,#names do
        local fname = names[k]
        if trace_detail then
            logs.report("fileio","? blobpath asked: %s",fname)
        end
        local bname = file.basename(fname)
        local dname = file.dirname(fname)
        if dname == "" or find(dname,"^%.") then
            dname = false
        else
            dname = "/" .. dname .. "$"
        end
        local hashes = instance.hashes
        for h=1,#hashes do
            local hash = hashes[h]
            local blobpath = hash.tag
            local files = blobpath and instance.files[blobpath]
            if files then
                if trace_detail then
                    logs.report("fileio",'? blobpath do: %s (%s)',blobpath,bname)
                end
                local blobfile = files[bname]
                if not blobfile then
                    local rname = "remap:"..bname
                    blobfile = files[rname]
                    if blobfile then
                        bname = files[rname]
                        blobfile = files[bname]
                    end
                end
                if blobfile then
                    if type(blobfile) == 'string' then
                        if not dname or find(blobfile,dname) then
                            filelist[#filelist+1] = {
                                hash.type,
                                file.join(blobpath,blobfile,bname), -- search
                                resolvers.concatinators[hash.type](blobpath,blobfile,bname) -- result
                            }
                        end
                    else
                        for kk=1,#blobfile do
                            local vv = blobfile[kk]
                            if not dname or find(vv,dname) then
                                filelist[#filelist+1] = {
                                    hash.type,
                                    file.join(blobpath,vv,bname), -- search
                                    resolvers.concatinators[hash.type](blobpath,vv,bname) -- result
                                }
                            end
                        end
                    end
                end
            elseif trace_locating then
                logs.report("fileio",'! blobpath no: %s (%s)',blobpath,bname)
            end
        end
    end
    if #filelist > 0 then
        return filelist
    else
        return nil
    end
end

function resolvers.suffix_of_format(str)
    if suffixes[str] then
        return suffixes[str][1]
    else
        return ""
    end
end

function resolvers.suffixes_of_format(str)
    if suffixes[str] then
        return suffixes[str]
    else
        return {}
    end
end

function resolvers.register_in_trees(name)
    if not find(name,"^%.") then
        instance.foundintrees[name] = (instance.foundintrees[name] or 0) + 1 -- maybe only one
    end
end

-- split the next one up for readability (bu this module needs a cleanup anyway)

local function can_be_dir(name) -- can become local
    local fakepaths = instance.fakepaths
    if not fakepaths[name] then
        if lfs.isdir(name) then
            fakepaths[name] = 1 -- directory
        else
            fakepaths[name] = 2 -- no directory
        end
    end
    return (fakepaths[name] == 1)
end

local function collect_instance_files(filename,collected) -- todo : plugin (scanners, checkers etc)
    local result = collected or { }
    local stamp  = nil
    filename = file.collapse_path(filename)  -- elsewhere
    filename = file.collapse_path(gsub(filename,"\\","/")) -- elsewhere
    -- speed up / beware: format problem
    if instance.remember then
        stamp = filename .. "--" .. instance.engine .. "--" .. instance.progname .. "--" .. instance.format
        if instance.found[stamp] then
            if trace_locating then
                logs.report("fileio",'! remembered: %s',filename)
            end
            return instance.found[stamp]
        end
    end
    if not dangerous[instance.format or "?"] then
        if resolvers.isreadable.file(filename) then
            if trace_detail then
                logs.report("fileio",'= found directly: %s',filename)
            end
            instance.found[stamp] = { filename }
            return { filename }
        end
    end
    if find(filename,'%*') then
        if trace_locating then
            logs.report("fileio",'! wildcard: %s', filename)
        end
        result = resolvers.find_wildcard_files(filename)
    elseif file.is_qualified_path(filename) then
        if resolvers.isreadable.file(filename) then
            if trace_locating then
                logs.report("fileio",'! qualified: %s', filename)
            end
            result = { filename }
        else
            local forcedname, ok, suffix = "", false, file.extname(filename)
            if suffix == "" then -- why
                if instance.format == "" then
                    forcedname = filename .. ".tex"
                    if resolvers.isreadable.file(forcedname) then
                        if trace_locating then
                            logs.report("fileio",'! no suffix, forcing standard filetype: tex')
                        end
                        result, ok = { forcedname }, true
                    end
                else
                    local suffixes = resolvers.suffixes_of_format(instance.format)
                    for _, s in next, suffixes do
                        forcedname = filename .. "." .. s
                        if resolvers.isreadable.file(forcedname) then
                            if trace_locating then
                                logs.report("fileio",'! no suffix, forcing format filetype: %s', s)
                            end
                            result, ok = { forcedname }, true
                            break
                        end
                    end
                end
            end
            if not ok and suffix ~= "" then
                -- try to find in tree (no suffix manipulation), here we search for the
                -- matching last part of the name
                local basename = file.basename(filename)
                local pattern = (filename .. "$"):gsub("([%.%-])","%%%1")
                local savedformat = instance.format
                local format = savedformat or ""
                if format == "" then
                    instance.format = resolvers.format_of_suffix(suffix)
                end
                if not format then
                    instance.format = "othertextfiles" -- kind of everything, maybe texinput is better
                end
                --
                local resolved = collect_instance_files(basename)
                if #result == 0 then
                    local lowered = lower(basename)
                    if filename ~= lowered then
                        resolved = collect_instance_files(lowered)
                    end
                end
                resolvers.format = savedformat
                --
                for r=1,#resolved do
                    local rr = resolved[r]
                    if rr:find(pattern) then
                        result[#result+1], ok = rr, true
                    end
                end
                -- a real wildcard:
                --
                -- if not ok then
                --     local filelist = collect_files({basename})
                --     for f=1,#filelist do
                --         local ff = filelist[f][3] or ""
                --         if ff:find(pattern) then
                --             result[#result+1], ok = ff, true
                --         end
                --     end
                -- end
            end
            if not ok and trace_locating then
                logs.report("fileio",'? qualified: %s', filename)
            end
        end
    else
        -- search spec
        local filetype, extra, done, wantedfiles, ext = '', nil, false, { }, file.extname(filename)
        if ext == "" then
            if not instance.force_suffixes then
                wantedfiles[#wantedfiles+1] = filename
            end
        else
            wantedfiles[#wantedfiles+1] = filename
        end
        if instance.format == "" then
            if ext == "" then
                local forcedname = filename .. '.tex'
                wantedfiles[#wantedfiles+1] = forcedname
                filetype = resolvers.format_of_suffix(forcedname)
                if trace_locating then
                    logs.report("fileio",'! forcing filetype: %s',filetype)
                end
            else
                filetype = resolvers.format_of_suffix(filename)
                if trace_locating then
                    logs.report("fileio",'! using suffix based filetype: %s',filetype)
                end
            end
        else
            if ext == "" then
                local suffixes = resolvers.suffixes_of_format(instance.format)
                for _, s in next, suffixes do
                    wantedfiles[#wantedfiles+1] = filename .. "." .. s
                end
            end
            filetype = instance.format
            if trace_locating then
                logs.report("fileio",'! using given filetype: %s',filetype)
            end
        end
        local typespec = resolvers.variable_of_format(filetype)
        local pathlist = resolvers.expanded_path_list(typespec)
        if not pathlist or #pathlist == 0 then
            -- no pathlist, access check only / todo == wildcard
            if trace_detail then
                logs.report("fileio",'? filename: %s',filename)
                logs.report("fileio",'? filetype: %s',filetype or '?')
                logs.report("fileio",'? wanted files: %s',concat(wantedfiles," | "))
            end
            for k=1,#wantedfiles do
                local fname = wantedfiles[k]
                if fname and resolvers.isreadable.file(fname) then
                    filename, done = fname, true
                    result[#result+1] = file.join('.',fname)
                    break
                end
            end
            -- this is actually 'other text files' or 'any' or 'whatever'
            local filelist = collect_files(wantedfiles)
            local fl = filelist and filelist[1]
            if fl then
                filename = fl[3]
                result[#result+1] = filename
                done = true
            end
        else
            -- list search
            local filelist = collect_files(wantedfiles)
            local doscan, recurse
            if trace_detail then
                logs.report("fileio",'? filename: %s',filename)
            end
            -- a bit messy ... esp the doscan setting here
            for k=1,#pathlist do
                local path = pathlist[k]
                if find(path,"^!!") then doscan  = false else doscan  = true  end
                if find(path,"//$") then recurse = true  else recurse = false end
                local pathname = gsub(path,"^!+", '')
                done = false
                -- using file list
                if filelist and not (done and not instance.allresults) and recurse then
                    -- compare list entries with permitted pattern
                    pathname = gsub(pathname,"([%-%.])","%%%1") -- this also influences
                    pathname = gsub(pathname,"/+$", '/.*')      -- later usage of pathname
                    pathname = gsub(pathname,"//", '/.-/')      -- not ok for /// but harmless
                    local expr = "^" .. pathname
                    for k=1,#filelist do
                        local fl = filelist[k]
                        local f = fl[2]
                        if find(f,expr) then
                            if trace_detail then
                                logs.report("fileio",'= found in hash: %s',f)
                            end
                            --- todo, test for readable
                            result[#result+1] = fl[3]
                            resolvers.register_in_trees(f) -- for tracing used files
                            done = true
                            if not instance.allresults then break end
                        end
                    end
                end
                if not done and doscan then
                    -- check if on disk / unchecked / does not work at all / also zips
                    if resolvers.splitmethod(pathname).scheme == 'file' then -- ?
                        local pname = gsub(pathname,"%.%*$",'')
                        if not find(pname,"%*") then
                            local ppname = gsub(pname,"/+$","")
                            if can_be_dir(ppname) then
                                for k=1,#wantedfiles do
                                    local w = wantedfiles[k]
                                    local fname = file.join(ppname,w)
                                    if resolvers.isreadable.file(fname) then
                                        if trace_detail then
                                            logs.report("fileio",'= found by scanning: %s',fname)
                                        end
                                        result[#result+1] = fname
                                        done = true
                                        if not instance.allresults then break end
                                    end
                                end
                            else
                                -- no access needed for non existing path, speedup (esp in large tree with lots of fake)
                            end
                        end
                    end
                end
                if not done and doscan then
                    -- todo: slow path scanning
                end
                if done and not instance.allresults then break end
            end
        end
    end
    for k=1,#result do
        result[k] = file.collapse_path(result[k])
    end
    if instance.remember then
        instance.found[stamp] = result
    end
    return result
end

if not resolvers.concatinators  then resolvers.concatinators = { } end

resolvers.concatinators.tex  = file.join
resolvers.concatinators.file = resolvers.concatinators.tex

function resolvers.find_files(filename,filetype,mustexist)
    if type(mustexist) == boolean then
        -- all set
    elseif type(filetype) == 'boolean' then
        filetype, mustexist = nil, false
    elseif type(filetype) ~= 'string' then
        filetype, mustexist = nil, false
    end
    instance.format = filetype or ''
    local result = collect_instance_files(filename)
    if #result == 0 then
        local lowered = lower(filename)
        if filename ~= lowered then
            return collect_instance_files(lowered)
        end
    end
    instance.format = ''
    return result
end

function resolvers.find_file(filename,filetype,mustexist)
    return (resolvers.find_files(filename,filetype,mustexist)[1] or "")
end

function resolvers.find_given_files(filename)
    local bname, result = file.basename(filename), { }
    local hashes = instance.hashes
    for k=1,#hashes do
        local hash = hashes[k]
        local files = instance.files[hash.tag]
        local blist = files[bname]
        if not blist then
            local rname = "remap:"..bname
            blist = files[rname]
            if blist then
                bname = files[rname]
                blist = files[bname]
            end
        end
        if blist then
            if type(blist) == 'string' then
                result[#result+1] = resolvers.concatinators[hash.type](hash.tag,blist,bname) or ""
                if not instance.allresults then break end
            else
                for kk=1,#blist do
                    local vv = blist[kk]
                    result[#result+1] = resolvers.concatinators[hash.type](hash.tag,vv,bname) or ""
                    if not instance.allresults then break end
                end
            end
        end
    end
    return result
end

function resolvers.find_given_file(filename)
    return (resolvers.find_given_files(filename)[1] or "")
end

local function doit(path,blist,bname,tag,kind,result,allresults)
    local done = false
    if blist and kind then
        if type(blist) == 'string' then
            -- make function and share code
            if find(lower(blist),path) then
                result[#result+1] = resolvers.concatinators[kind](tag,blist,bname) or ""
                done = true
            end
        else
            for kk=1,#blist do
                local vv = blist[kk]
                if find(lower(vv),path) then
                    result[#result+1] = resolvers.concatinators[kind](tag,vv,bname) or ""
                    done = true
                    if not allresults then break end
                end
            end
        end
    end
    return done
end

function resolvers.find_wildcard_files(filename) -- todo: remap:
    local result = { }
    local bname, dname = file.basename(filename), file.dirname(filename)
    local path = gsub(dname,"^*/","")
    path = gsub(path,"*",".*")
    path = gsub(path,"-","%%-")
    if dname == "" then
        path = ".*"
    end
    local name = bname
    name = gsub(name,"*",".*")
    name = gsub(name,"-","%%-")
    path = lower(path)
    name = lower(name)
    local files, allresults, done = instance.files, instance.allresults, false
    if find(name,"%*") then
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local tag, kind = hash.tag, hash.type
            for kk, hh in next, files[hash.tag] do
                if not find(kk,"^remap:") then
                    if find(lower(kk),name) then
                        if doit(path,hh,kk,tag,kind,result,allresults) then done = true end
                        if done and not allresults then break end
                    end
                end
            end
        end
    else
        local hashes = instance.hashes
        for k=1,#hashes do
            local hash = hashes[k]
            local tag, kind = hash.tag, hash.type
            if doit(path,files[tag][bname],bname,tag,kind,result,allresults) then done = true end
            if done and not allresults then break end
        end
    end
    -- we can consider also searching the paths not in the database, but then
    -- we end up with a messy search (all // in all path specs)
    return result
end

function resolvers.find_wildcard_file(filename)
    return (resolvers.find_wildcard_files(filename)[1] or "")
end

-- main user functions

function resolvers.automount()
    -- implemented later
end

function resolvers.load(option)
    statistics.starttiming(instance)
    resolvers.resetconfig()
    resolvers.identify_cnf()
    resolvers.load_lua()
    resolvers.expand_variables()
    resolvers.load_cnf()
    resolvers.expand_variables()
    if option ~= "nofiles" then
        resolvers.load_hash()
        resolvers.automount()
    end
    statistics.stoptiming(instance)
end

function resolvers.for_files(command, files, filetype, mustexist)
    if files and #files > 0 then
        local function report(str)
            if trace_verbose then
                logs.report("fileio",str) -- has already verbose
            else
                print(str)
            end
        end
        if trace_verbose then
            report('')
        end
        for _, file in ipairs(files) do
            local result = command(file,filetype,mustexist)
            if type(result) == 'string' then
                report(result)
            else
                for _,v in ipairs(result) do
                    report(v)
                end
            end
        end
    end
end

-- strtab

resolvers.var_value  = resolvers.variable   -- output the value of variable $STRING.
resolvers.expand_var = resolvers.expansion  -- output variable expansion of STRING.

function resolvers.show_path(str)     -- output search path for file type NAME
    return file.join_path(resolvers.expanded_path_list(resolvers.format_of_var(str)))
end

-- resolvers.find_file(filename)
-- resolvers.find_file(filename, filetype, mustexist)
-- resolvers.find_file(filename, mustexist)
-- resolvers.find_file(filename, filetype)

function resolvers.register_file(files, name, path)
    if files[name] then
        if type(files[name]) == 'string' then
            files[name] = { files[name], path }
        else
            files[name] = path
        end
    else
        files[name] = path
    end
end

function resolvers.splitmethod(filename)
    if not filename then
        return { } -- safeguard
    elseif type(filename) == "table" then
        return filename -- already split
    elseif not find(filename,"://") then
        return { scheme="file", path = filename, original=filename } -- quick hack
    else
        return url.hashed(filename)
    end
end

function table.sequenced(t,sep) -- temp here
    local s = { }
    for k, v in pairs(t) do -- pairs?
        s[#s+1] = k .. "=" .. v
    end
    return concat(s, sep or " | ")
end

function resolvers.methodhandler(what, filename, filetype) -- ...
    local specification = (type(filename) == "string" and resolvers.splitmethod(filename)) or filename -- no or { }, let it bomb
    local scheme = specification.scheme
    if resolvers[what][scheme] then
        if trace_locating then
            logs.report("fileio",'= handler: %s -> %s -> %s',specification.original,what,table.sequenced(specification))
        end
        return resolvers[what][scheme](filename,filetype) -- todo: specification
    else
        return resolvers[what].tex(filename,filetype) -- todo: specification
    end
end

function resolvers.clean_path(str)
    if str then
        str = gsub(str,"\\","/")
        str = gsub(str,"^!+","")
        str = gsub(str,"^~",resolvers.homedir)
        return str
    else
        return nil
    end
end

function resolvers.do_with_path(name,func)
    for _, v in pairs(resolvers.expanded_path_list(name)) do -- pairs?
        func("^"..resolvers.clean_path(v))
    end
end

function resolvers.do_with_var(name,func)
    func(expanded_var(name))
end

function resolvers.with_files(pattern,handle)
    for _, hash in ipairs(instance.hashes) do
        local blobpath = hash.tag
        local blobtype = hash.type
        if blobpath then
            local files = instance.files[blobpath]
            if files then
                for k,v in next, files do
                    if find(k,"^remap:") then
                        k = files[k]
                        v = files[k] -- chained
                    end
                    if find(k,pattern) then
                        if type(v) == "string" then
                            handle(blobtype,blobpath,v,k)
                        else
                            for _,vv in pairs(v) do -- ipairs?
                                handle(blobtype,blobpath,vv,k)
                            end
                        end
                    end
                end
            end
        end
    end
end

function resolvers.locate_format(name)
    local barename, fmtname = name:gsub("%.%a+$",""), ""
    if resolvers.usecache then
        local path = file.join(caches.setpath("formats")) -- maybe platform
        fmtname = file.join(path,barename..".fmt") or ""
    end
    if fmtname == "" then
        fmtname = resolvers.find_files(barename..".fmt")[1] or ""
    end
    fmtname = resolvers.clean_path(fmtname)
    if fmtname ~= "" then
        local barename = file.removesuffix(fmtname)
        local luaname, lucname, luiname = barename .. ".lua", barename .. ".luc", barename .. ".lui"
        if lfs.isfile(luiname) then
            return barename, luiname
        elseif lfs.isfile(lucname) then
            return barename, lucname
        elseif lfs.isfile(luaname) then
            return barename, luaname
        end
    end
    return nil, nil
end

function resolvers.boolean_variable(str,default)
    local b = resolvers.expansion(str)
    if b == "" then
        return default
    else
        b = toboolean(b)
        return (b == nil and default) or b
    end
end

texconfig.kpse_init = false

kpse = { original = kpse } setmetatable(kpse, { __index = function(k,v) return resolvers[v] end } )

-- for a while

input = resolvers


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module deals with caching data. It sets up the paths and
implements loaders and savers for tables. Best is to set the
following variable. When not set, the usual paths will be
checked. Personally I prefer the (users) temporary path.</p>

</code>
TEXMFCACHE=$TMP;$TEMP;$TMPDIR;$TEMPDIR;$HOME;$TEXMFVAR;$VARTEXMF;.
</code>

<p>Currently we do no locking when we write files. This is no real
problem because most caching involves fonts and the chance of them
being written at the same time is small. We also need to extend
luatools with a recache feature.</p>
--ldx]]--

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache = false  trackers.register("resolvers.cache", function(v) trace_cache = v end)

caches = caches or { }

caches.path     = caches.path or nil
caches.base     = caches.base or "luatex-cache"
caches.more     = caches.more or "context"
caches.direct   = false -- true is faster but may need huge amounts of memory
caches.tree     = false
caches.paths    = caches.paths or nil
caches.force    = false
caches.defaults = { "TEXMFCACHE", "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

function caches.temp()
    local cachepath = nil
    local function check(list,isenv)
        if not cachepath then
            for k=1,#list do
                local v = list[k]
                cachepath = (isenv and (os.env[v] or "")) or v or ""
                if cachepath == "" then
                    -- next
                else
                    cachepath = resolvers.clean_path(cachepath)
                    if lfs.isdir(cachepath) and file.iswritable(cachepath) then -- lfs.attributes(cachepath,"mode") == "directory"
                        break
                    elseif caches.force or io.ask(format("\nShould I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
                        dir.mkdirs(cachepath)
                        if lfs.isdir(cachepath) and file.iswritable(cachepath) then
                            break
                        end
                    end
                end
                cachepath = nil
            end
        end
    end
    check(resolvers.clean_path_list("TEXMFCACHE") or { })
    check(caches.defaults,true)
    if not cachepath then
        print("\nfatal error: there is no valid (writable) cache path defined\n")
        os.exit()
    elseif not lfs.isdir(cachepath) then -- lfs.attributes(cachepath,"mode") ~= "directory"
        print(format("\nfatal error: cache path %s is not a directory\n",cachepath))
        os.exit()
    end
    cachepath = file.collapse_path(cachepath)
    function caches.temp()
        return cachepath
    end
    return cachepath
end

function caches.configpath()
    return table.concat(resolvers.instance.cnffiles,";")
end

function caches.hashed(tree)
    return md5.hex(gsub(lower(tree),"[\\\/]+","/"))
end

function caches.treehash()
    local tree = caches.configpath()
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

function caches.setpath(...)
    if not caches.path then
        if not caches.path then
            caches.path = caches.temp()
        end
        caches.path = resolvers.clean_path(caches.path) -- to be sure
        caches.tree = caches.tree or caches.treehash()
        if caches.tree then
            caches.path = dir.mkdirs(caches.path,caches.base,caches.more,caches.tree)
        else
            caches.path = dir.mkdirs(caches.path,caches.base,caches.more)
        end
    end
    if not caches.path then
        caches.path = '.'
    end
    caches.path = resolvers.clean_path(caches.path)
    if not table.is_empty({...}) then
        local pth = dir.mkdirs(caches.path,...)
        return pth
    end
    caches.path = dir.expand_name(caches.path)
    return caches.path
end

function caches.definepath(category,subcategory)
    return function()
        return caches.setpath(category,subcategory)
    end
end

function caches.setluanames(path,name)
    return path .. "/" .. name .. ".tma", path .. "/" .. name .. ".tmc"
end

function caches.loaddata(path,name)
    local tmaname, tmcname = caches.setluanames(path,name)
    local loader = loadfile(tmcname) or loadfile(tmaname)
    if loader then
        loader = loader()
        collectgarbage("step")
        return loader
    else
        return false
    end
end

--~ function caches.loaddata(path,name)
--~     local tmaname, tmcname = caches.setluanames(path,name)
--~     return dofile(tmcname) or dofile(tmaname)
--~ end

function caches.iswritable(filepath,filename)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    return file.iswritable(tmaname)
end

function caches.savedata(filepath,filename,data,raw)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    local reduce, simplify = true, true
    if raw then
        reduce, simplify = false, false
    end
    if caches.direct then
        file.savedata(tmaname, table.serialize(data,'return',false,true,false)) -- no hex
    else
        table.tofile(tmaname, data,'return',false,true,false) -- maybe not the last true
    end
    local cleanup = resolvers.boolean_variable("PURGECACHE", false)
    local strip = resolvers.boolean_variable("LUACSTRIP", true)
    utils.lua.compile(tmaname, tmcname, cleanup, strip)
end

-- here we use the cache for format loading (texconfig.[formatname|jobname])

--~ if tex and texconfig and texconfig.formatname and texconfig.formatname == "" then
if tex and texconfig and (not texconfig.formatname or texconfig.formatname == "") and input and resolvers.instance then
    if not texconfig.luaname then texconfig.luaname = "cont-en.lua" end -- or luc
    texconfig.formatname = caches.setpath("formats") .. "/" .. gsub(texconfig.luaname,"%.lu.$",".fmt")
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-res'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ print(resolvers.resolve("abc env:tmp file:cont-en.tex path:cont-en.tex full:cont-en.tex rel:zapf/one/p-chars.tex"))

local upper, lower, gsub = string.upper, string.lower, string.gsub

local prefixes = { }

prefixes.environment = function(str)
    return resolvers.clean_path(os.getenv(str) or os.getenv(upper(str)) or os.getenv(lower(str)) or "")
end

prefixes.relative = function(str,n)
    if io.exists(str) then
        -- nothing
    elseif io.exists("./" .. str) then
        str = "./" .. str
    else
        local p = "../"
        for i=1,n or 2 do
            if io.exists(p .. str) then
                str = p .. str
                break
            else
                p = p .. "../"
            end
        end
    end
    return resolvers.clean_path(str)
end

prefixes.locate = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path((fullname ~= "" and fullname) or str)
end

prefixes.filename = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path(file.basename((fullname ~= "" and fullname) or str))
end

prefixes.pathname = function(str)
    local fullname = resolvers.find_given_file(str) or ""
    return resolvers.clean_path(file.dirname((fullname ~= "" and fullname) or str))
end

prefixes.env  = prefixes.environment
prefixes.rel  = prefixes.relative
prefixes.loc  = prefixes.locate
prefixes.kpse = prefixes.locate
prefixes.full = prefixes.locate
prefixes.file = prefixes.filename
prefixes.path = prefixes.pathname

local function _resolve_(method,target)
    if prefixes[method] then
        return prefixes[method](target)
    else
        return method .. ":" .. target
    end
end

local function resolve(str)
    if type(str) == "table" then
        for k, v in pairs(str) do -- ipairs
            str[k] = resolve(v) or v
        end
    elseif str and str ~= "" then
        str = gsub(str,"([a-z]+):([^ \"\']*)",_resolve_)
    end
    return str
end

resolvers.resolve = resolve

if os.uname then

    for k, v in pairs(os.uname()) do
        if not prefixes[k] then
            prefixes[k] = function() return v end
        end
    end

end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

resolvers.finders = resolvers.finders or { }
resolvers.openers = resolvers.openers or { }
resolvers.loaders = resolvers.loaders or { }

resolvers.finders.notfound  = { nil }
resolvers.openers.notfound  = { nil }
resolvers.loaders.notfound  = { false, nil, 0 }


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-out'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

outputs = outputs or { }



end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-con'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache      = false  trackers.register("resolvers.cache",      function(v) trace_cache      = v end)
local trace_containers = false  trackers.register("resolvers.containers", function(v) trace_containers = v end)
local trace_storage    = false  trackers.register("resolvers.storage",    function(v) trace_storage    = v end)
local trace_verbose    = false  trackers.register("resolvers.verbose",    function(v) trace_verbose    = v end)
local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v trackers.enable("resolvers.verbose") end)

--[[ldx--
<p>Once we found ourselves defining similar cache constructs
several times, containers were introduced. Containers are used
to collect tables in memory and reuse them when possible based
on (unique) hashes (to be provided by the calling function).</p>

<p>Caching to disk is disabled by default. Version numbers are
stored in the saved table which makes it possible to change the
table structures without bothering about the disk cache.</p>

<p>Examples of usage can be found in the font related code.</p>
--ldx]]--

containers = containers or { }

containers.usecache = true

local function report(container,tag,name)
    if trace_cache or trace_containers then
        logs.report(format("%s cache",container.subcategory),"%s: %s",tag,name or 'invalid')
    end
end

local allocated = { }

-- tracing

function containers.define(category, subcategory, version, enabled)
    return function()
        if category and subcategory then
            local c = allocated[category]
            if not c then
                c  = { }
                allocated[category] = c
            end
            local s = c[subcategory]
            if not s then
                s = {
                    category = category,
                    subcategory = subcategory,
                    storage = { },
                    enabled = enabled,
                    version = version or 1.000,
                    trace = false,
                    path = caches and caches.setpath and caches.setpath(category,subcategory),
                }
                c[subcategory] = s
            end
            return s
        else
            return nil
        end
    end
end

function containers.is_usable(container, name)
    return container.enabled and caches and caches.iswritable(container.path, name)
end

function containers.is_valid(container, name)
    if name and name ~= "" then
        local storage = container.storage[name]
        return storage and not table.is_empty(storage) and storage.cache_version == container.version
    else
        return false
    end
end

function containers.read(container,name)
    if container.enabled and caches and not container.storage[name] and containers.usecache then
        container.storage[name] = caches.loaddata(container.path,name)
        if containers.is_valid(container,name) then
            report(container,"loaded",name)
        else
            container.storage[name] = nil
        end
    end
    if container.storage[name] then
        report(container,"reusing",name)
    end
    return container.storage[name]
end

function containers.write(container, name, data)
    if data then
        data.cache_version = container.version
        if container.enabled and caches then
            local unique, shared = data.unique, data.shared
            data.unique, data.shared = nil, nil
            caches.savedata(container.path, name, data)
            report(container,"saved",name)
            data.unique, data.shared = unique, shared
        end
        report(container,"stored",name)
        container.storage[name] = data
    end
    return data
end

function containers.content(container,name)
    return container.storage[name]
end

function containers.cleanname(name)
    return (gsub(lower(name),"[^%w%d]+","-"))
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-use'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_verbose    = false  trackers.register("resolvers.verbose",    function(v) trace_verbose    = v end)
local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v trackers.enable("resolvers.verbose") end)

-- since we want to use the cache instead of the tree, we will now
-- reimplement the saver.

local save_data = resolvers.save_data
local load_data = resolvers.load_data

resolvers.cachepath = nil  -- public, for tracing
resolvers.usecache  = true -- public, for tracing

function resolvers.save_data(dataname)
    save_data(dataname, function(cachename,dataname)
        resolvers.usecache = not toboolean(resolvers.expansion("CACHEINTDS") or "false",true)
        if resolvers.usecache then
            resolvers.cachepath = resolvers.cachepath or caches.definepath("trees")
            return file.join(resolvers.cachepath(),caches.hashed(cachename))
        else
            return file.join(cachename,dataname)
        end
    end)
end

function resolvers.load_data(pathname,dataname,filename)
    load_data(pathname,dataname,filename,function(dataname,filename)
        resolvers.usecache = not toboolean(resolvers.expansion("CACHEINTDS") or "false",true)
        if resolvers.usecache then
            resolvers.cachepath = resolvers.cachepath or caches.definepath("trees")
            return file.join(resolvers.cachepath(),caches.hashed(pathname))
        else
            if not filename or (filename == "") then
                filename = dataname
            end
            return file.join(pathname,filename)
        end
    end)
end

-- we will make a better format, maybe something xml or just text or lua

resolvers.automounted = resolvers.automounted or { }

function resolvers.automount(usecache)
    local mountpaths = resolvers.clean_path_list(resolvers.expansion('TEXMFMOUNT'))
    if table.is_empty(mountpaths) and usecache then
        mountpaths = { caches.setpath("mount") }
    end
    if not table.is_empty(mountpaths) then
        statistics.starttiming(resolvers.instance)
        for k, root in pairs(mountpaths) do
            local f = io.open(root.."/url.tmi")
            if f then
                for line in f:lines() do
                    if line then
                        if line:find("^[%%#%-]") then -- or %W
                            -- skip
                        elseif line:find("^zip://") then
                            if trace_locating then
                                logs.report("fileio","mounting %s",line)
                            end
                            table.insert(resolvers.automounted,line)
                            resolvers.usezipfile(line)
                        end
                    end
                end
                f:close()
            end
        end
        statistics.stoptiming(resolvers.instance)
    end
end

-- status info

statistics.register("used config path", function() return caches.configpath()  end)
statistics.register("used cache path",  function() return caches.temp() or "?" end)

-- experiment (code will move)

function statistics.save_fmt_status(texname,formatbanner,sourcefile) -- texname == formatname
    local enginebanner = status.list().banner
    if formatbanner and enginebanner and sourcefile then
        local luvname = file.replacesuffix(texname,"luv")
        local luvdata = {
            enginebanner = enginebanner,
            formatbanner = formatbanner,
            sourcehash   = md5.hex(io.loaddata(resolvers.find_file(sourcefile)) or "unknown"),
            sourcefile   = sourcefile,
        }
        io.savedata(luvname,table.serialize(luvdata,true))
    end
end

function statistics.check_fmt_status(texname)
    local enginebanner = status.list().banner
    if enginebanner and texname then
        local luvname = file.replacesuffix(texname,"luv")
        if lfs.isfile(luvname) then
            local luv = dofile(luvname)
            if luv and luv.sourcefile then
                local sourcehash = md5.hex(io.loaddata(resolvers.find_file(luv.sourcefile)) or "unknown")
                if luv.enginebanner and luv.enginebanner ~= enginebanner then
                    return "engine mismatch"
                end
                if luv.sourcehash and luv.sourcehash ~= sourcehash then
                    return "source mismatch"
                end
            else
                return "invalid status file"
            end
        else
            return "missing status file"
        end
    end
    return true
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-zip'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find = string.format, string.find

local trace_locating, trace_verbose  = false, false

trackers.register("resolvers.verbose",  function(v) trace_verbose  = v end)
trackers.register("resolvers.locating", function(v) trace_locating = v trace_verbose = v end)

zip                 = zip or { }
zip.archives        = zip.archives or { }
zip.registeredfiles = zip.registeredfiles or { }

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders
local locators, hashers, concatinators = resolvers.locators, resolvers.hashers, resolvers.concatinators

local archives = zip.archives

-- zip:///oeps.zip?name=bla/bla.tex
-- zip:///oeps.zip?tree=tex/texmf-local

local function validzip(str) -- todo: use url splitter
    if not find(str,"^zip://") then
        return "zip:///" .. str
    else
        return str
    end
end

function zip.openarchive(name)
    if not name or name == "" then
        return nil
    else
        local arch = archives[name]
        if not arch then
           local full = resolvers.find_file(name) or ""
           arch = (full ~= "" and zip.open(full)) or false
           archives[name] = arch
        end
       return arch
    end
end

function zip.closearchive(name)
    if not name or (name == "" and archives[name]) then
        zip.close(archives[name])
        archives[name] = nil
    end
end

-- zip:///texmf.zip?tree=/tex/texmf
-- zip:///texmf.zip?tree=/tex/texmf-local
-- zip:///texmf-mine.zip?tree=/tex/texmf-projects

function locators.zip(specification) -- where is this used? startup zips (untested)
    specification = resolvers.splitmethod(specification)
    local zipfile = specification.path
    local zfile = zip.openarchive(name) -- tricky, could be in to be initialized tree
    if trace_locating then
        if zfile then
            logs.report("fileio",'! zip locator, found: %s',specification.original)
        else
            logs.report("fileio",'? zip locator, not found: %s',specification.original)
        end
    end
end

function hashers.zip(tag,name)
    if trace_verbose then
        logs.report("fileio","loading zip file %s as %s",name,tag)
    end
    resolvers.usezipfile(format("%s?tree=%s",tag,name))
end

function concatinators.zip(tag,path,name)
    if not path or path == "" then
        return format('%s?name=%s',tag,name)
    else
        return format('%s?name=%s/%s',tag,path,name)
    end
end

function resolvers.isreadable.zip(name)
    return true
end

function finders.zip(specification,filetype)
    specification = resolvers.splitmethod(specification)
    if specification.path then
        local q = url.query(specification.query)
        if q.name then
            local zfile = zip.openarchive(specification.path)
            if zfile then
                if trace_locating then
                    logs.report("fileio",'! zip finder, path: %s',specification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    dfile = zfile:close()
                    if trace_locating then
                        logs.report("fileio",'+ zip finder, name: %s',q.name)
                    end
                    return specification.original
                end
            elseif trace_locating then
                logs.report("fileio",'? zip finder, path %s',specification.path)
            end
        end
    end
    if trace_locating then
        logs.report("fileio",'- zip finder, name: %s',filename)
    end
    return unpack(finders.notfound)
end

function openers.zip(specification)
    local zipspecification = resolvers.splitmethod(specification)
    if zipspecification.path then
        local q = url.query(zipspecification.query)
        if q.name then
            local zfile = zip.openarchive(zipspecification.path)
            if zfile then
                if trace_locating then
                    logs.report("fileio",'+ zip starter, path: %s',zipspecification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    logs.show_open(specification)
                    return openers.text_opener(specification,dfile,'zip')
                end
            elseif trace_locating then
                logs.report("fileio",'- zip starter, path %s',zipspecification.path)
            end
        end
    end
    if trace_locating then
        logs.report("fileio",'- zip opener, name: %s',filename)
    end
    return unpack(openers.notfound)
end

function loaders.zip(specification)
    specification = resolvers.splitmethod(specification)
    if specification.path then
        local q = url.query(specification.query)
        if q.name then
            local zfile = zip.openarchive(specification.path)
            if zfile then
                if trace_locating then
                    logs.report("fileio",'+ zip starter, path: %s',specification.path)
                end
                local dfile = zfile:open(q.name)
                if dfile then
                    logs.show_load(filename)
                    if trace_locating then
                        logs.report("fileio",'+ zip loader, name: %s',filename)
                    end
                    local s = dfile:read("*all")
                    dfile:close()
                    return true, s, #s
                end
            elseif trace_locating then
                logs.report("fileio",'- zip starter, path: %s',specification.path)
            end
        end
    end
    if trace_locating then
        logs.report("fileio",'- zip loader, name: %s',filename)
    end
    return unpack(openers.notfound)
end

-- zip:///somefile.zip
-- zip:///somefile.zip?tree=texmf-local -> mount

function resolvers.usezipfile(zipname)
    zipname = validzip(zipname)
    if trace_locating then
        logs.report("fileio",'! zip use, file: %s',zipname)
    end
    local specification = resolvers.splitmethod(zipname)
    local zipfile = specification.path
    if zipfile and not zip.registeredfiles[zipname] then
        local tree = url.query(specification.query).tree or ""
        if trace_locating then
            logs.report("fileio",'! zip register, file: %s',zipname)
        end
        local z = zip.openarchive(zipfile)
        if z then
            local instance = resolvers.instance
            if trace_locating then
                logs.report("fileio","= zipfile, registering: %s",zipname)
            end
            statistics.starttiming(instance)
            resolvers.prepend_hash('zip',zipname,zipfile)
            resolvers.extend_texmf_var(zipname) -- resets hashes too
            zip.registeredfiles[zipname] = z
            instance.files[zipname] = resolvers.register_zip_file(z,tree or "")
            statistics.stoptiming(instance)
        elseif trace_locating then
            logs.report("fileio","? zipfile, unknown: %s",zipname)
        end
    elseif trace_locating then
        logs.report("fileio",'! zip register, no file: %s',zipname)
    end
end

function resolvers.register_zip_file(z,tree)
    local files, filter = { }, ""
    if tree == "" then
        filter = "^(.+)/(.-)$"
    else
        filter = format("^%s/(.+)/(.-)$",tree)
    end
    if trace_locating then
        logs.report("fileio",'= zip filter: %s',filter)
    end
    local register, n = resolvers.register_file, 0
    for i in z:files() do
        local path, name = i.filename:match(filter)
        if path then
            if name and name ~= '' then
                register(files, name, path)
                n = n + 1
            else
                -- directory
            end
        else
            register(files, i.filename, '')
            n = n + 1
        end
    end
    logs.report("fileio",'= zip entries: %s',n)
    return files
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-crl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

curl = curl or { }

curl.cached    = { }
curl.cachepath = caches.definepath("curl")

local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders

function curl.fetch(protocol, name)
    local cachename = curl.cachepath() .. "/" .. name:gsub("[^%a%d%.]+","-")
--  cachename = cachename:gsub("[\\/]", io.fileseparator)
    cachename = cachename:gsub("[\\]", "/") -- cleanup
    if not curl.cached[name] then
        if not io.exists(cachename) then
            curl.cached[name] = cachename
            local command = "curl --silent --create-dirs --output " .. cachename .. " " .. name -- no protocol .. "://"
            os.spawn(command)
        end
        if io.exists(cachename) then
            curl.cached[name] = cachename
        else
            curl.cached[name] = ""
        end
    end
    return curl.cached[name]
end

function finders.curl(protocol,filename)
    local foundname = curl.fetch(protocol, filename)
    return finders.generic(protocol,foundname,filetype)
end

function openers.curl(protocol,filename)
    return openers.generic(protocol,filename)
end

function loaders.curl(protocol,filename)
    return loaders.generic(protocol,filename)
end

-- todo: metamethod

function curl.install(protocol)
    finders[protocol] = function (filename,filetype) return finders.curl(protocol,filename) end
    openers[protocol] = function (filename)          return openers.curl(protocol,filename) end
    loaders[protocol] = function (filename)          return loaders.curl(protocol,filename) end
end

curl.install('http')
curl.install('https')
curl.install('ftp')


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-kps'] = {
    version   = 1.001,
    comment   = "companion to luatools.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This file is used when we want the input handlers to behave like
<type>kpsewhich</type>. What to do with the following:</p>

<typing>
{$SELFAUTOLOC,$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,}/web2c}
$SELFAUTOLOC    : /usr/tex/bin/platform
$SELFAUTODIR    : /usr/tex/bin
$SELFAUTOPARENT : /usr/tex
</typing>

<p>How about just forgetting about them?</p>
--ldx]]--

local suffixes = resolvers.suffixes
local formats  = resolvers.formats

suffixes['gf']                       = { '<resolution>gf' }
suffixes['pk']                       = { '<resolution>pk' }
suffixes['base']                     = { 'base' }
suffixes['bib']                      = { 'bib' }
suffixes['bst']                      = { 'bst' }
suffixes['cnf']                      = { 'cnf' }
suffixes['mem']                      = { 'mem' }
suffixes['mf']                       = { 'mf' }
suffixes['mfpool']                   = { 'pool' }
suffixes['mft']                      = { 'mft' }
suffixes['mppool']                   = { 'pool' }
suffixes['graphic/figure']           = { 'eps', 'epsi' }
suffixes['texpool']                  = { 'pool' }
suffixes['PostScript header']        = { 'pro' }
suffixes['ist']                      = { 'ist' }
suffixes['web']                      = { 'web', 'ch' }
suffixes['cweb']                     = { 'w', 'web', 'ch' }
suffixes['cmap files']               = { 'cmap' }
suffixes['lig files']                = { 'lig' }
suffixes['bitmap font']              = { }
suffixes['MetaPost support']         = { }
suffixes['TeX system documentation'] = { }
suffixes['TeX system sources']       = { }
suffixes['dvips config']             = { }
suffixes['type42 fonts']             = { }
suffixes['web2c files']              = { }
suffixes['other text files']         = { }
suffixes['other binary files']       = { }
suffixes['opentype fonts']           = { 'otf' }

suffixes['fmt']                      = { 'fmt' }
suffixes['texmfscripts']             = { 'rb','lua','py','pl' }

suffixes['pdftex config']            = { }
suffixes['Troff fonts']              = { }

suffixes['ls-R']                     = { }

--[[ldx--
<p>If you wondered abou tsome of the previous mappings, how about
the next bunch:</p>
--ldx]]--

formats['bib']                      = ''
formats['bst']                      = ''
formats['mft']                      = ''
formats['ist']                      = ''
formats['web']                      = ''
formats['cweb']                     = ''
formats['MetaPost support']         = ''
formats['TeX system documentation'] = ''
formats['TeX system sources']       = ''
formats['Troff fonts']              = ''
formats['dvips config']             = ''
formats['graphic/figure']           = ''
formats['ls-R']                     = ''
formats['other text files']         = ''
formats['other binary files']       = ''

formats['gf']                       = ''
formats['pk']                       = ''
formats['base']                     = 'MFBASES'
formats['cnf']                      = ''
formats['mem']                      = 'MPMEMS'
formats['mf']                       = 'MFINPUTS'
formats['mfpool']                   = 'MFPOOL'
formats['mppool']                   = 'MPPOOL'
formats['texpool']                  = 'TEXPOOL'
formats['PostScript header']        = 'TEXPSHEADERS'
formats['cmap files']               = 'CMAPFONTS'
formats['type42 fonts']             = 'T42FONTS'
formats['web2c files']              = 'WEB2C'
formats['pdftex config']            = 'PDFTEXCONFIG'
formats['texmfscripts']             = 'TEXMFSCRIPTS'
formats['bitmap font']              = ''
formats['lig files']                = 'LIGFONTS'


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find

local trace_verbose = false  trackers.register("resolvers.verbose", function(v) trace_verbose = v end)

function resolvers.update_script(oldname,newname) -- oldname -> own.name, not per se a suffix
    local scriptpath = "scripts/context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = resolvers.clean_path(oldname)
    if trace_verbose then
        logs.report("fileio","to be replaced old script %s", oldscript)
    end
    local newscripts = resolvers.find_files(newname) or { }
    if #newscripts == 0 then
        if trace_verbose then
            logs.report("fileio","unable to locate new script")
        end
    else
        for i=1,#newscripts do
            local newscript = resolvers.clean_path(newscripts[i])
            if trace_verbose then
                logs.report("fileio","checking new script %s", newscript)
            end
            if oldscript == newscript then
                if trace_verbose then
                    logs.report("fileio","old and new script are the same")
                end
            elseif not find(newscript,scriptpath) then
                if trace_verbose then
                    logs.report("fileio","new script should come from %s",scriptpath)
                end
            elseif not (find(oldscript,file.removesuffix(newname).."$") or find(oldscript,newname.."$")) then
                if trace_verbose then
                    logs.report("fileio","invalid new script name")
                end
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    if trace_verbose then
                        logs.report("fileio","old script content replaced by new content")
                    end
                    io.savedata(oldscript,newdata)
                    break
                elseif trace_verbose then
                    logs.report("fileio","unable to load new script")
                end
            end
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['data-tmf'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- loads *.tmf files in minimal tree roots (to be optimized and documented)

function resolvers.check_environment(tree)
    logs.simpleline()
    os.setenv('TMP', os.getenv('TMP') or os.getenv('TEMP') or os.getenv('TMPDIR') or os.getenv('HOME'))
    os.setenv('TEXOS', os.getenv('TEXOS') or ("texmf-" .. os.currentplatform()))
    os.setenv('TEXPATH', (tree or "tex"):gsub("\/+$",''))
    os.setenv('TEXMFOS', os.getenv('TEXPATH') .. "/" .. os.getenv('TEXOS'))
    logs.simpleline()
    logs.simple("preset : TEXPATH => %s", os.getenv('TEXPATH'))
    logs.simple("preset : TEXOS   => %s", os.getenv('TEXOS'))
    logs.simple("preset : TEXMFOS => %s", os.getenv('TEXMFOS'))
    logs.simple("preset : TMP     => %s", os.getenv('TMP'))
    logs.simple('')
end

function resolvers.load_environment(name) -- todo: key=value as well as lua
    local f = io.open(name)
    if f then
        for line in f:lines() do
            if line:find("^[%%%#]") then
                -- skip comment
            else
                local key, how, value = line:match("^(.-)%s*([<=>%?]+)%s*(.*)%s*$")
                if how then
                    value = value:gsub("%%(.-)%%", function(v) return os.getenv(v) or "" end)
                        if how == "=" or how == "<<" then
                            os.setenv(key,value)
                    elseif how == "?" or how == "??" then
                            os.setenv(key,os.getenv(key) or value)
                    elseif how == "<" or how == "+=" then
                        if os.getenv(key) then
                            os.setenv(key,os.getenv(key) .. io.fileseparator .. value)
                        else
                            os.setenv(key,value)
                        end
                    elseif how == ">" or how == "=+" then
                        if os.getenv(key) then
                            os.setenv(key,value .. io.pathseparator .. os.getenv(key))
                        else
                            os.setenv(key,value)
                        end
                    end
                end
            end
        end
        f:close()
    end
end

function resolvers.load_tree(tree)
    if tree and tree ~= "" then
        local setuptex = 'setuptex.tmf'
        if lfs.attributes(tree, "mode") == "directory" then -- check if not nil
            setuptex = tree .. "/" .. setuptex
        else
            setuptex = tree
        end
        if io.exists(setuptex) then
            resolvers.check_environment(tree)
            resolvers.load_environment(setuptex)
        end
    end
end


end -- of closure

do -- create closure to overcome 200 locals limit

if not modules then modules = { } end modules ['luat-sta'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code is used in the updater

states          = states          or { }
states.data     = states.data     or { }
states.hash     = states.hash     or { }
states.tag      = states.tag      or ""
states.filename = states.filename or ""

function states.save(filename,tag)
    tag = tag or states.tag
    filename = file.addsuffix(filename or states.filename,'lus')
    io.savedata(filename,
        "-- generator : luat-sta.lua\n" ..
        "-- state tag : " .. tag .. "\n\n" ..
        table.serialize(states.data[tag or states.tag] or {},true)
    )
end

function states.load(filename,tag)
    states.filename = filename
    states.tag = tag or "whatever"
    states.filename = file.addsuffix(states.filename,'lus')
    states.data[states.tag], states.hash[states.tag] = (io.exists(filename) and dofile(filename)) or { }, { }
end

function states.set_by_tag(tag,key,value,default,persistent)
    local d, h = states.data[tag], states.hash[tag]
    if d then
        if type(d) == "table" then
            local dkey, hkey = key, key
            local pre, post = key:match("(.+)%.([^%.]+)$")
            if pre and post then
                for k in pre:gmatch("[^%.]+") do
                    local dk = d[k]
                    if not dk then
                        dk = { }
                        d[k] = dk
                    end
                    d = dk
                end
                dkey, hkey = post, key
            end
            if type(value) == nil then
                value = value or default
            elseif persistent then
                value = value or d[dkey] or default
            else
                value = value or default
            end
            d[dkey], h[hkey] = value, value
        elseif type(d) == "string" then
            -- weird
            states.data[tag], states.hash[tag] = value, value
        end
    end
end

function states.get_by_tag(tag,key,default)
    local h = states.hash[tag]
    if h and h[key] then
        return h[key]
    else
        local d = states.data[tag]
        if d then
            for k in key:gmatch("[^%.]+") do
                local dk = d[k]
                if dk then
                    d = dk
                else
                    return default
                end
            end
            return d or default
        end
    end
end

function states.set(key,value,default,persistent)
    states.set_by_tag(states.tag,key,value,default,persistent)
end

function states.get(key,default)
    return states.get_by_tag(states.tag,key,default)
end

--~ states.data.update = {
--~ 	["version"] = {
--~ 		["major"] = 0,
--~ 		["minor"] = 1,
--~ 	},
--~ 	["rsync"] = {
--~ 		["server"]     = "contextgarden.net",
--~ 		["module"]     = "minimals",
--~ 		["repository"] = "current",
--~ 		["flags"]      = "-rpztlv --stats",
--~ 	},
--~ 	["tasks"] = {
--~ 		["update"] = true,
--~ 		["make"]   = true,
--~         ["delete"] = false,
--~ 	},
--~ 	["platform"] = {
--~ 		["host"]  = true,
--~ 		["other"] = {
--~ 			["mswin"]     = false,
--~ 			["linux"]     = false,
--~ 			["linux-64"]  = false,
--~ 			["osx-intel"] = false,
--~ 			["osx-ppc"]   = false,
--~ 			["sun"]       = false,
--~ 		},
--~ 	},
--~ 	["context"] = {
--~ 		["available"] = {"current", "beta", "alpha", "experimental"},
--~ 		["selected"]  = "current",
--~ 	},
--~ 	["formats"] = {
--~ 		["cont-en"] = true,
--~ 		["cont-nl"] = true,
--~ 		["cont-de"] = false,
--~ 		["cont-cz"] = false,
--~ 		["cont-fr"] = false,
--~ 		["cont-ro"] = false,
--~ 	},
--~ 	["engine"] = {
--~ 		["pdftex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["pdftex"] = true,
--~ 			},
--~ 		},
--~ 		["luatex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 			},
--~ 		},
--~ 		["xetex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["xetex"] = false,
--~ 			},
--~ 		},
--~ 		["metapost"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["mpost"] = true,
--~ 				["metafun"] = true,
--~ 			},
--~ 		},
--~ 	},
--~ 	["fonts"] = {
--~ 	},
--~ 	["doc"] = {
--~ 	},
--~ 	["modules"] = {
--~ 		["f-urwgaramond"] = false,
--~ 		["f-urwgothic"] = false,
--~ 		["t-bnf"] = false,
--~ 		["t-chromato"] = false,
--~ 		["t-cmscbf"] = false,
--~ 		["t-cmttbf"] = false,
--~ 		["t-construction-plan"] = false,
--~ 		["t-degrade"] = false,
--~ 		["t-french"] = false,
--~ 		["t-lettrine"] = false,
--~ 		["t-lilypond"] = false,
--~ 		["t-mathsets"] = false,
--~ 		["t-tikz"] = false,
--~ 		["t-typearea"] = false,
--~ 		["t-vim"] = false,
--~ 	},
--~ }

--~ states.save("teststate", "update")
--~ states.load("teststate", "update")

--~ print(states.get_by_tag("update","rsync.server","unknown"))
--~ states.set_by_tag("update","rsync.server","oeps")
--~ print(states.get_by_tag("update","rsync.server","unknown"))
--~ states.save("teststate", "update")
--~ states.load("teststate", "update")
--~ print(states.get_by_tag("update","rsync.server","unknown"))


end -- of closure
-- end library merge

own = { } -- not local

own.libs = { -- todo: check which ones are really needed
    'l-string.lua',
    'l-lpeg.lua',
    'l-table.lua',
    'l-io.lua',
    'l-number.lua',
    'l-set.lua',
    'l-os.lua',
    'l-file.lua',
    'l-md5.lua',
    'l-dir.lua',
    'l-boolean.lua',
    'l-math.lua',
--  'l-unicode.lua',
--  'l-tex.lua',
    'l-utils.lua',
    'l-aux.lua',
--  'l-xml.lua',
    'lxml-tab.lua',
    'lxml-pth.lua',
    'lxml-ent.lua',
    'lxml-mis.lua',
    'trac-tra.lua',
    'luat-env.lua',
    'trac-inf.lua',
    'trac-log.lua',
    'data-res.lua',
    'data-tmp.lua',
    'data-pre.lua',
    'data-inp.lua',
    'data-out.lua',
    'data-con.lua',
    'data-use.lua',
--  'data-tex.lua',
--  'data-bin.lua',
    'data-zip.lua',
    'data-crl.lua',
--  'data-lua.lua',
    'data-kps.lua', -- so that we can replace kpsewhich
    'data-aux.lua', -- updater
    'data-tmf.lua', -- tree files
    -- needed ?
    'luat-sta.lua', -- states
}

-- We need this hack till luatex is fixed.
--
-- for k,v in pairs(arg) do print(k,v) end

if arg and (arg[0] == 'luatex' or arg[0] == 'luatex.exe') and arg[1] == "--luaonly" then
    arg[-1]=arg[0] arg[0]=arg[2] for k=3,#arg do arg[k-2]=arg[k] end arg[#arg]=nil arg[#arg]=nil
end

-- End of hack.

own.name = (environment and environment.ownname) or arg[0] or 'luatools.lua'

own.path = string.match(own.name,"^(.+)[\\/].-$") or "."
own.list = { '.' }
if own.path ~= '.' then
    table.insert(own.list,own.path)
end
table.insert(own.list,own.path.."/../../../tex/context/base")
table.insert(own.list,own.path.."/mtx")
table.insert(own.list,own.path.."/../sources")

local function locate_libs()
    for _, lib in pairs(own.libs) do
        for _, pth in pairs(own.list) do
            local filename = string.gsub(pth .. "/" .. lib,"\\","/")
            local codeblob = loadfile(filename)
            if codeblob then
                codeblob()
                own.list = { pth } -- speed up te search
                break
            end
        end
    end
end

if not resolvers then
    locate_libs()
end

if not resolvers then
    print("")
    print("Mtxrun is unable to start up due to lack of libraries. You may")
    print("try to run 'lua mtxrun.lua --selfmerge' in the path where this")
    print("script is located (normally under ..../scripts/context/lua) which")
    print("will make this script library independent.")
    os.exit()
end

logs.setprogram('MTXrun',"TDS Runner Tool 1.22",environment.arguments["verbose"] or false)

local instance = resolvers.reset()

runners  = runners  or { } -- global
messages = messages or { }

messages.help = [[
--script              run an mtx script (--noquotes)
--execute             run a script or program (--noquotes)
--resolve             resolve prefixed arguments
--ctxlua              run internally (using preloaded libs)
--locate              locate given filename

--autotree            use texmf tree cf. env 'texmfstart_tree' or 'texmfstarttree'
--tree=pathtotree     use given texmf tree (default file: 'setuptex.tmf')
--environment=name    use given (tmf) environment file
--path=runpath        go to given path before execution
--ifchanged=filename  only execute when given file has changed (md checksum)
--iftouched=old,new   only execute when given file has changed (time stamp)

--make                create stubs for (context related) scripts
--remove              remove stubs (context related) scripts
--stubpath=binpath    paths where stubs wil be written
--windows             create windows (mswin) stubs
--unix                create unix (linux) stubs

--verbose             give a bit more info
--engine=str          target engine
--progname=str        format or backend

--edit                launch editor with found file
--launch (--all)      launch files like manuals, assumes os support

--intern              run script using built in libraries

--usekpse            use kpse as fallback (when no mkiv and cache installed, often slower)
--forcekpse          force using kpse (handy when no mkiv and cache installed but less functionality)
]]

runners.applications = {
    ["lua"] = "luatex --luaonly",
    ["luc"] = "luatex --luaonly",
    ["pl"] = "perl",
    ["py"] = "python",
    ["rb"] = "ruby",
}

runners.suffixes = {
    'rb', 'lua', 'py', 'pl'
}

runners.registered = {
    texexec      = { 'texexec.rb',      true  },  -- context mkii runner (only tool not to be luafied)
    texutil      = { 'texutil.rb',      true  },  -- old perl based index sorter for mkii (old versions need it)
    texfont      = { 'texfont.pl',      true  },  -- perl script that makes mkii font metric files
    texfind      = { 'texfind.pl',      false },  -- perltk based tex searching tool, mostly used at pragma
    texshow      = { 'texshow.pl',      false },  -- perltk based context help system, will be luafied
 -- texwork      = { \texwork.pl',      false },  -- perltk based editing environment, only used at pragma

    makempy      = { 'makempy.pl',      true  },
    mptopdf      = { 'mptopdf.pl',      true  },
    pstopdf      = { 'pstopdf.rb',      true  },  -- converts ps (and some more) images, does some cleaning (replaced)

--  examplex     = { 'examplex.rb',     false },
    concheck     = { 'concheck.rb',     false },

    runtools     = { 'runtools.rb',     true  },
    textools     = { 'textools.rb',     true  },
    tmftools     = { 'tmftools.rb',     true  },
    ctxtools     = { 'ctxtools.rb',     true  },
    rlxtools     = { 'rlxtools.rb',     true  },
    pdftools     = { 'pdftools.rb',     true  },
    mpstools     = { 'mpstools.rb',     true  },
--  exatools     = { 'exatools.rb',     true  },
    xmltools     = { 'xmltools.rb',     true  },
--  luatools     = { 'luatools.lua',    true  },
    mtxtools     = { 'mtxtools.rb',     true  },

    pdftrimwhite = { 'pdftrimwhite.pl', false }
}

runners.launchers = {
    windows = { },
    unix = { }
}

function runners.prepare()
    local checkname = environment.argument("ifchanged")
    if checkname and checkname ~= "" then
        local oldchecksum = file.loadchecksum(checkname)
        local newchecksum = file.checksum(checkname)
        if oldchecksum == newchecksum then
            logs.simple("file '%s' is unchanged",checkname)
            return "skip"
        else
            logs.simple("file '%s' is changed, processing started",checkname)
        end
        file.savechecksum(checkname)
    end
    local oldname, newname = string.split(environment.argument("iftouched") or "", ",")
    if oldname and newname and oldname ~= "" and newname ~= "" then
        if not file.needs_updating(oldname,newname) then
            logs.simple("file '%s' and '%s' have same age",oldname,newname)
            return "skip"
        else
            logs.simple("file '%s' is older than '%s'",oldname,newname)
        end
    end
    local tree = environment.argument('tree') or ""
    if environment.argument('autotree') then
        tree = os.getenv('TEXMFSTART_TREE') or os.getenv('TEXMFSTARTTREE') or tree
    end
    if tree and tree ~= "" then
        resolvers.load_tree(tree)
    end
    local env = environment.argument('environment') or ""
    if env and env ~= "" then
        for _,e in pairs(string.split(env)) do
            -- maybe force suffix when not given
            resolvers.load_tree(e)
        end
    end
    local runpath = environment.argument("path")
    if runpath and not lfs.chdir(runpath) then
        logs.simple("unable to change to path '%s'",runpath)
        return "error"
    end
    return "run"
end

function runners.execute_script(fullname,internal)
    local noquote = environment.argument("noquotes")
    if fullname and fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            instance.progname = environment.argument("progname") or instance.progname
            instance.format   = environment.argument("format")   or instance.format
            local path, name, suffix, result = file.dirname(fullname), file.basename(fullname), file.extname(fullname), ""
            if path ~= "" then
                result = fullname
            elseif name then
                name = name:gsub("^int[%a]*:",function()
                    internal = true
                    return ""
                end )
                name = name:gsub("^script:","")
                if suffix == "" and runners.registered[name] and runners.registered[name][1] then
                    name = runners.registered[name][1]
                    suffix = file.extname(name)
                end
                if suffix == "" then
                    -- loop over known suffixes
                    for _,s in pairs(runners.suffixes) do
                        result = resolvers.find_file(name .. "." .. s, 'texmfscripts')
                        if result ~= "" then
                            break
                        end
                    end
                elseif runners.applications[suffix] then
                    result = resolvers.find_file(name, 'texmfscripts')
                else
                    -- maybe look on path
                    result = resolvers.find_file(name, 'other text files')
                end
            end
            if result and result ~= "" then
                local before, after = environment.split_arguments(fullname) -- already done
                environment.arguments_before, environment.arguments_after = before, after
                if internal then
                    arg = { } for _,v in pairs(after) do arg[#arg+1] = v end
                    dofile(result)
                else
                    local binary = runners.applications[file.extname(result)]
                    if binary and binary ~= "" then
                        result = binary .. " " .. result
                    end
                    local command = result .. " " .. environment.reconstruct_commandline(after,noquote)
                    if logs.verbose then
                        logs.simpleline()
                        logs.simple("executing: %s",command)
                        logs.simpleline()
                        logs.simpleline()
                        io.flush()
                    end
                    local code = os.exec(command) -- maybe spawn
                    return code == 0
                end
            end
        end
    end
    return false
end

function runners.execute_program(fullname)
    local noquote = environment.argument("noquotes")
    if fullname and fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            local before, after = environment.split_arguments(fullname)
            environment.initialize_arguments(after)
            fullname = fullname:gsub("^bin:","")
            local command = fullname .. " " .. (environment.reconstruct_commandline(after or "",noquote) or "")
            logs.simpleline()
            logs.simple("executing: %s",command)
            logs.simpleline()
            logs.simpleline()
            io.flush()
            local code = os.exec(command) -- (fullname,unpack(after)) does not work / maybe spawn
            return code == 0
        end
    end
    return false
end

-- the --usekpse flag will fallback on kpse

local windows_stub = '@echo off\013\010setlocal\013\010set ownpath=%%~dp0%%\013\010texlua "%%ownpath%%mtxrun.lua" --usekpse --execute %s %%*\013\010endlocal\013\010'
local unix_stub    = '#!/bin/sh\010mtxrun --usekpse --execute %s \"$@\"\010'

function runners.handle_stubs(create)
    local stubpath = environment.argument('stubpath') or '.' -- 'auto' no longer subpathssupported
    local windows  = environment.argument('windows') or environment.argument('mswin') or false
    local unix     = environment.argument('unix') or environment.argument('linux') or false
    if not windows and not unix then
        if os.platform == "unix" then
            unix = true
        else
            windows = true
        end
    end
    for _,v in pairs(runners.registered) do
        local name, doit = v[1], v[2]
        if doit then
            local base = string.gsub(file.basename(name), "%.(.-)$", "")
            if create then
                if windows then
                    io.savedata(file.join(stubpath,base..".bat"),string.format(windows_stub,name))
                    logs.simple("windows stub for '%s' created",base)
                end
                if unix then
                    io.savedata(file.join(stubpath,base),string.format(unix_stub,name))
                    logs.simple("unix stub for '%s' created",base)
                end
            else
                if windows and (os.remove(file.join(stubpath,base..'.bat')) or os.remove(file.join(stubpath,base..'.cmd'))) then
                    logs.simple("windows stub for '%s' removed", base)
                end
                if unix and (os.remove(file.join(stubpath,base)) or os.remove(file.join(stubpath,base..'.sh'))) then
                    logs.simple("unix stub for '%s' removed",base)
                end
            end
        end
    end
end

function runners.resolve_string(filename)
    if filename and filename ~= "" then
        runners.report_location(resolvers.resolve(filename))
    end
end

function runners.locate_file(filename)
    -- differs from texmfstart where locate appends .com .exe .bat ... todo
    if filename and filename ~= "" then
        runners.report_location(resolvers.find_given_file(filename))
    end
end

function runners.locate_platform()
    runners.report_location(os.currentplatform())
end

function runners.report_location(result)
    if logs.verbose then
        logs.simpleline()
        if result and result ~= "" then
            logs.simple(result)
        else
            logs.simple("not found")
        end
    else
        io.write(result)
    end
end

function runners.edit_script(filename) -- we assume that vim is present on most systems
    local editor = os.getenv("MTXRUN_EDITOR") or os.getenv("TEXMFSTART_EDITOR") or os.getenv("EDITOR") or 'vim'
    local rest = resolvers.resolve(filename)
    if rest ~= "" then
        local command = editor .. " " .. rest
        if logs.verbose then
            logs.simpleline()
            logs.simple("starting editor: %s",command)
            logs.simple_line()
            logs.simple_line()
        end
        os.launch(command)
    end
end

function runners.save_script_session(filename, list)
    local t = { }
    for _, key in ipairs(list) do
        t[key] = environment.arguments[key]
    end
    io.savedata(filename,table.serialize(t,true))
end

function runners.load_script_session(filename)
    if lfs.isfile(filename) then
        local t = io.loaddata(filename)
        if t then
            t = loadstring(t)
            if t then t = t() end
            for key, value in pairs(t) do
                environment.arguments[key] = value
            end
        end
    end
end

function resolvers.launch(str)
    -- maybe we also need to test on mtxrun.launcher.suffix environment
    -- variable or on windows consult the assoc and ftype vars and such
    local launchers = runners.launchers[os.platform] if launchers then
        local suffix = file.extname(str) if suffix then
            local runner = launchers[suffix] if runner then
                str = runner .. " " .. str
            end
        end
    end
    os.launch(str)
end

function runners.launch_file(filename)
    instance.allresults = true
    logs.setverbose(true)
    local pattern = environment.arguments["pattern"]
    if not pattern or pattern == "" then
        pattern = filename
    end
    if not pattern or pattern == "" then
        logs.simple("provide name or --pattern=")
    else
        local t = resolvers.find_files(pattern)
        if not t or #t == 0 then
            t = resolvers.find_files("*/" .. pattern)
        end
        if not t or #t == 0 then
            t = resolvers.find_files("*/" .. pattern .. "*")
        end
        if t and #t > 0 then
            if environment.arguments["all"] then
                for _, v in pairs(t) do
                    logs.simple("launching %s", v)
                    resolvers.launch(v)
                end
            else
                logs.simple("launching %s", t[1])
                resolvers.launch(t[1])
            end
        else
            logs.simple("no match for %s", pattern)
        end
    end
end

function runners.find_mtx_script(filename)
    local function found(name)
        local path = file.dirname(name)
        if path and path ~= "" then
            return false
        else
            local fullname = own and own.path and file.join(own.path,name)
            return io.exists(fullname) and fullname
        end
    end
    filename = file.addsuffix(filename,"lua")
    local basename = file.removesuffix(file.basename(filename))
    local suffix = file.extname(filename)
    -- qualified path, raw name
    local fullname = file.is_qualified_path(filename) and io.exists(filename) and filename
    if fullname and fullname ~= "" then
        return fullname
    end
    -- current path, raw name
    fullname = "./" .. filename
    fullname = io.exists(fullname) and fullname
    if fullname and fullname ~= "" then
        return fullname
    end
    -- context namespace, mtx-<filename>
    fullname = "mtx-" .. filename
    fullname = found(fullname) or resolvers.find_file(fullname)
    if fullname and fullname ~= "" then
        return fullname
    end
    -- context namespace, mtx-<filename>s
    fullname = "mtx-" .. basename .. "s" .. "." .. suffix
    fullname = found(fullname) or resolvers.find_file(fullname)
    if fullname and fullname ~= "" then
        return fullname
    end
    -- context namespace, mtx-<filename minus trailing s>
    fullname = "mtx-" .. basename:gsub("s$","") .. "." .. suffix
    fullname = found(fullname) or resolvers.find_file(fullname)
    if fullname and fullname ~= "" then
        return fullname
    end
    -- context namespace, just <filename>
    fullname = resolvers.find_file(filename)
    return fullname
end

function runners.execute_ctx_script(filename,arguments)
    local fullname = runners.find_mtx_script(filename) or ""
    -- retyr after generate but only if --autogenerate
    if fullname == "" and environment.argument("autogenerate") then -- might become the default
        instance.renewcache = true
        logs.setverbose(true)
        resolvers.load()
        --
        fullname = runners.find_mtx_script(filename) or ""
    end
    -- that should do it
    if fullname ~= "" then
        local state = runners.prepare()
        if state == 'error' then
            return false
        elseif state == 'skip' then
            return true
        elseif state == "run" then
            -- load and save ... kind of undocumented
            arg = { } for _,v in pairs(arguments) do arg[#arg+1] = resolvers.resolve(v) end
            environment.initialize_arguments(arg)
            local loadname = environment.arguments['load']
            if loadname then
                if type(loadname) ~= "string" then loadname = file.basename(fullname) end
                loadname = file.replacesuffix(loadname,"cfg")
                runners.load_script_session(loadname)
            end
            filename = environment.files[1]
            if logs.verbose then
                logs.simple("using script: %s\n",fullname)
            end
            dofile(fullname)
            local savename = environment.arguments['save']
            if savename and runners.save_list and not table.is_empty(runners.save_list or { }) then
                if type(savename) ~= "string" then savename = file.basename(fullname) end
                savename = file.replacesuffix(savename,"cfg")
                runners.save_script_session(savename, runners.save_list)
            end
            return true
        end
    else
        logs.setverbose(true)
        if filename == "" then
            logs.simple("unknown script, no name given")
            local context = resolvers.find_file("mtx-context.lua")
            if context ~= "" then
                local result = dir.glob((string.gsub(context,"mtx%-context","mtx-*"))) -- () needed
                local valid = { }
                for _, scriptname in ipairs(result) do
                    scriptname = string.match(scriptname,".*mtx%-([^%-]-)%.lua")
                    if scriptname then
                        valid[#valid+1] = scriptname
                    end
                end
                if #valid > 0 then
                    logs.simple("known scripts: %s",table.concat(valid,", "))
                end
            end
        else
            filename = file.addsuffix(filename,"lua")
            if file.is_qualified_path(filename) then
                logs.simple("unknown script '%s'",filename)
            else
                logs.simple("unknown script '%s' or 'mtx-%s'",filename,filename)
            end
        end
        return false
    end
end

function runners.timedrun(filename) -- just for me
    if filename and filename ~= "" then
        runners.timed(function() os.execute(filename) end)
    end
end

function runners.timed(action)
    statistics.timed(action)
end

-- this is a bit dirty ... first we store the first filename and next we
-- split the arguments so that we only see the ones meant for this script
-- ... later we will use the second half

local filename = environment.files[1] or ""
local ok      = true

local before, after = environment.split_arguments(filename)
environment.arguments_before, environment.arguments_after = before, after
environment.initialize_arguments(before)

instance.engine   = environment.argument("engine")   or 'luatex'
instance.progname = environment.argument("progname") or 'context'
instance.lsrmode  = environment.argument("lsr")      or false

-- maybe the unset has to go to this level

if environment.argument("usekpse") or environment.argument("forcekpse") then

    os.setenv("engine","")
    os.setenv("progname","")

    local remapper = {
        otf = "opentype fonts",
        ttf = "truetype fonts",
        ttc = "truetype fonts",
        pfb = "type1 fonts",
        other = "other text files",
    }

    local function kpse_initialized()
        texconfig.kpse_init = true
        local t = os.clock()
        local k = kpse.original.new("luatex",instance.progname)
        local dummy = k:find_file("mtxrun.lua") -- so that we're initialized
        logs.simple("kpse fallback with progname '%s' initialized in %s seconds",instance.progname,os.clock()-t)
        kpse_initialized = function() return k end
        return k
    end

    local find_file = resolvers.find_file
    local show_path = resolvers.show_path

    if environment.argument("forcekpse") then

        function resolvers.find_file(name,kind)
            return (kpse_initialized():find_file(resolvers.clean_path(name),(kind ~= "" and (remapper[kind] or kind)) or "tex") or "") or ""
        end
        function resolvers.show_path(name)
            return (kpse_initialized():show_path(name)) or ""
        end

    elseif environment.argument("usekpse") then

        resolvers.load()

        function resolvers.find_file(name,kind)
            local found = find_file(name,kind) or ""
            if found ~= "" then
                return found
            else
                return (kpse_initialized():find_file(resolvers.clean_path(name),(kind ~= "" and (remapper[kind] or kind)) or "tex") or "") or ""
            end
        end
        function resolvers.show_path(name)
            local found = show_path(name) or ""
            if found ~= "" then
                return found
            else
                return (kpse_initialized():show_path(name)) or ""
            end
        end

    end

else

    resolvers.load()

end


if environment.argument("selfmerge") then
    -- embed used libraries
    utils.merger.selfmerge(own.name,own.libs,own.list)
elseif environment.argument("selfclean") then
    -- remove embedded libraries
    utils.merger.selfclean(own.name)
elseif environment.argument("selfupdate") then
    logs.setverbose(true)
    resolvers.update_script(own.name,"mtxrun")
elseif environment.argument("ctxlua") or environment.argument("internal") then
    -- run a script by loading it (using libs)
    ok = runners.execute_script(filename,true)
elseif environment.argument("script") or environment.argument("s") then
    -- run a script by loading it (using libs), pass args
    ok = runners.execute_ctx_script(filename,after)
elseif environment.argument("execute") then
    -- execute script
    ok = runners.execute_script(filename)
elseif environment.argument("direct") then
    -- equals bin:
    ok = runners.execute_program(filename)
elseif environment.argument("edit") then
    -- edit file
    runners.edit_script(filename)
elseif environment.argument("launch") then
    runners.launch_file(filename)
elseif environment.argument("make") then
    -- make stubs
    runners.handle_stubs(true)
elseif environment.argument("remove") then
    -- remove stub
    runners.handle_stubs(false)
elseif environment.argument("resolve") then
    -- resolve string
    runners.resolve_string(filename)
elseif environment.argument("locate") then
    -- locate file
    runners.locate_file(filename)
elseif environment.argument("platform")then
    -- locate platform
    runners.locate_platform()
elseif environment.argument("timedrun") then
    -- locate platform
    runners.timedrun(filename)
elseif environment.argument("help") or filename=='help' or filename == "" then
    logs.help(messages.help)
    -- execute script
elseif filename:find("^bin:") then
    ok = runners.execute_program(filename)
else
    ok = runners.execute_script(filename)
end

if os.platform == "unix" then
    io.write("\n")
end

if ok == false then ok = 1 elseif ok == true then ok = 0 end

os.exit(ok)