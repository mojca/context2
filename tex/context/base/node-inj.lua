if not modules then modules = { } end modules ['node-inj'] = {
    version   = 1.001,
    comment   = "companion to node-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- tricky ... fonts.ids is not yet defined .. to be solved (maybe general tex ini)

-- This is very experimental (this will change when we have luatex > .50 and
-- a few pending thingies are available. Also, Idris needs to make a few more
-- test fonts.

local next = next

local trace_injections = false  trackers.register("nodes.injections", function(v) trace_injections = v end)

fonts     = fonts      or { }
fonts.tfm = fonts.tfm  or { }
fonts.ids = fonts.ids  or { }

local fontdata = fonts.ids

local glyph = node.id('glyph')
local kern  = node.id('kern')

local traverse_id        = node.traverse_id
local has_attribute      = node.has_attribute
local set_attribute      = node.set_attribute
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local newkern = nodes.kern

local markbase = attributes.private('markbase')
local markmark = attributes.private('markmark')
local markdone = attributes.private('markdone')
local cursbase = attributes.private('cursbase')
local curscurs = attributes.private('curscurs')
local cursdone = attributes.private('cursdone')
local kernpair = attributes.private('kernpair')

local cursives = { }
local marks    = { }
local kerns    = { }

-- currently we do gpos/kern in a bit inofficial way but when we
-- have the extra fields in glyphnodes to manipulate ht/dp/wd
-- explicitly i will provide an alternative; also, we can share
-- tables

function nodes.set_cursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext)
    local dx, dy = factor*(exit[1]-entry[1]), factor*(exit[2]-entry[2])
    local ws, wn = tfmstart.width, tfmnext.width
    local bound = #cursives + 1
    set_attribute(start,cursbase,bound)
    set_attribute(nxt,curscurs,bound)
    cursives[bound] = { rlmode, dx, dy, ws, wn }
    return dx, dy, bound
end

function nodes.set_pair(current,factor,rlmode,spec,tfmchr)
    local x, y, w, h = factor*spec[1], factor*spec[2], factor*spec[3], factor*spec[4]
    -- dy = y - h
    if x ~= 0 or w ~= 0 or y ~= 0 or h ~= 0 then
        local bound = has_attribute(current,kernpair)
        if bound then
            local kb = kerns[bound]
            kb[2], kb[3], kb[4], kb[5] = kb[2] + x, kb[3] + y, kb[4] + w, kb[5] + h
        else
            bound = #kerns + 1
            set_attribute(current,kernpair,bound)
            kerns[bound] = { rlmode, x, y, w, h }
        end
        return x, y, w, h, bound
    end
    return x, y, w, h -- no bound
end

function nodes.set_kern(current,factor,rlmode,x,tfmchr)
    local dx = factor*x
    if dx ~= 0 then
        local bound = #kerns + 1
        set_attribute(current,kernpair,bound)
        kerns[bound] = { rlmode, dx }
    end
    return dx, bound
end

function nodes.set_mark(start,base,factor,rlmode,ba,ma,index) --ba=baseanchor, ma=markanchor
    local dx, dy = factor*(ba[1]-ma[1]), factor*(ba[2]-ma[2])
    local bound = has_attribute(base,markbase)
    if bound then
        local mb = marks[bound]
        if mb then
            if not index then index = #mb + 1 end
            mb[index] = { dx, dy }
            set_attribute(start,markmark,bound)
            set_attribute(start,markdone,index)
            return dx, dy, bound
        else
            logs.report("nodes mark", "possible problem, U+%04X is base without data (id: %s)",base.char,bound)
        end
    end
    index = index or 1
    bound = #marks + 1
    set_attribute(base,markbase,bound)
    set_attribute(start,markmark,bound)
    set_attribute(start,markdone,index)
    marks[bound] = { [index] = { dx, dy } }
    return dx, dy, bound
end

function nodes.trace_injection(head)
    local function dir(n)
        return (n<0 and "r-to-l") or (n>0 and "l-to-r") or ("unset")
    end
    local function report(...)
        logs.report("nodes finisher",...)
    end
    report("begin run")
    for n in traverse_id(glyph,head) do
        if n.subtype < 256 then
            local kp = has_attribute(n,kernpair)
            local mb = has_attribute(n,markbase)
            local mm = has_attribute(n,markmark)
            local md = has_attribute(n,markdone)
            local cb = has_attribute(n,cursbase)
            local cc = has_attribute(n,curscurs)
            report("char U+%05X, font=%s",n.char,n.font)
            if kp then
                local k = kerns[kp]
                if k[3] then
                    report("  pairkern: dir=%s, x=%s, y=%s, w=%s, h=%s",dir(k[1]),k[2],k[3],k[4],k[5])
                else
                    report("  kern: dir=%s, dx=%s",dir(k[1]),k[2])
                end
            end
            if mb then
                report("  markbase: bound=%s",mb)
            end
            if mm then
                local m = marks[mm]
                if mb then
                    local m = m[mb]
                    if m then
                        report("  markmark: bound=%s, index=%s, dx=%s, dy=%s",mm,j,m[1],m[2])
                    else
                        report("  markmark: bound=%s, missing index",mm)
                    end
                else
                    m = m[1]
                    report("  markmark: bound=%s, dx=%s, dy=%s",mm,m[1],m[2])
                end
            end
            if cb then
                report("  cursbase: bound=%s",cb)
            end
            if cc then
                local c = cursives[cc]
                report("  curscurs: bound=%s, dir=%s, dx=%s, dy=%s",cc,dir(c[1]),c[2],c[3])
            end
        end
    end
    report("end run")
end

-- todo: reuse tables (i.e. no collection), but will be extra fields anyway

function nodes.inject_kerns(head,tail,keep)
    if trace_injections then
        nodes.trace_injection(head)
    end
    local has_marks, has_cursives, has_kerns = next(marks), next(cursives), next(kerns)
    if has_marks or has_cursives then
        -- in the future variant we will not copy items but refs to tables
        local done, ky, rl, valid, cx, wx = false, { }, { }, { }, { }, { }
        for n in traverse_id(glyph,head) do
            if n.subtype < 256 then
                valid[#valid+1] = n
                if has_kerns then -- move outside loop
                    local k = has_attribute(n,kernpair)
                    if k then
                        local kk = kerns[k]
                        if kk then
                            local x, y, w, h = kk[2], kk[3], kk[4], kk[5]
                            local dy = y - h
                            if dy ~= 0 then
                                ky[n] = dy
                            end
                            if w ~= 0 or x ~= 0 then
                                wx[n] = kk
                            end
                            rl[n] = kk[1] -- could move in test
                        end
                    end
                end
            end
        end
        if #valid > 0 then
            -- we can assume done == true because we have cursives and marks
            local cx = { }
            if has_kerns and next(ky) then
                for n, k in next, ky do
                    n.yoffset = k
                end
            end
            -- todo: reuse t and use maxt
            if has_cursives then
                local n_cursbase, n_curscurs, p_cursbase, n, p, nf, tm = nil, nil, nil, nil, nil, nil, nil
                -- since we need valid[n+1] we can also use a "while true do"
                local t, d, maxt = { }, { }, 0
                for i=1,#valid do -- valid == glyphs
                    n = valid[i]
                    if n.font ~= nf then
                        nf = n.font
                        tm = fontdata[nf].marks
                        -- maybe flush
                        maxt = 0
                    end
                    if not tm[n.char] then
                        n_cursbase = has_attribute(n,cursbase)
                        n_curscurs = has_attribute(n,curscurs)
                        if p_cursbase then
                            if p_cursbase == n_curscurs then
                                local c = cursives[n_curscurs]
                                if c then
                                    local rlmode, dx, dy, ws, wn = c[1], c[2], c[3], c[4], c[5]
                                    if rlmode >= 0 then
                                        dx = dx - ws
                                    else
                                        dx = dx + wn
                                    end
                                    if dx ~= 0 then
                                        cx[n] = dx
                                        rl[n] = rlmode
                                    end
                                --  if rlmode and rlmode < 0 then
                                        dy = -dy
                                --  end
                                    maxt = maxt + 1
                                    t[maxt] = p
                                    d[maxt] = dy
                                else
                                    maxt = 0
                                end
                            end
                        elseif maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                t[i].yoffset = t[i].yoffset + ny
                            end
                            maxt = 0
                        end
                        if not n_cursbase and maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                t[i].yoffset = ny
                            end
                            maxt = 0
                        end
                        p_cursbase, p = n_cursbase, n
                    end
                end
                if maxt > 0 then
                    local ny = n.yoffset
                    for i=maxt,1,-1 do
                        ny = ny + d[i]
                        t[i].yoffset = ny
                    end
                    maxt = 0
                end
                if not keep then
                    cursives = { }
                end
            end
            if has_marks then
                local p_markbase, n_markmark = nil, nil
                for i=1,#valid do
                    local p = valid[i]
                    p_markbase = has_attribute(p,markbase)
                    if p_markbase then
                        local mrks = marks[p_markbase]
                        for n in traverse_id(glyph,p.next) do
                            n_markmark = has_attribute(n,markmark)
                            if p_markbase == n_markmark then
                                local index = has_attribute(n,markdone) or 1
                                local d = mrks[index]
                                if d then
                                --  local rlmode = d[3] -- not used
                                --  if rlmode and rlmode < 0 then
                                --      n.xoffset = p.xoffset + d[1]
                                --  else
                                        n.xoffset = p.xoffset - d[1]
                                --  end
                                    n.yoffset = p.yoffset + d[2]
                                end
                            else
                                break
                            end
                        end
                    end
                end
                if not keep then
                    marks = { }
                end
            end
            -- todo : combine
            if next(wx) then
                for n, k in next, wx do
                 -- only w can be nil, can be sped up when w == nil
                    local rl, x, w = k[1], k[2] or 0, k[4] or 0
                    local wx = w - x
                    if rl < 0 then
                        if wx ~= 0 then
                            insert_node_before(head,n,newkern(wx))
                        end
                        if x ~= 0 then
                            insert_node_after (head,n,newkern(x))
                        end
                    else
                    --  if wx ~= 0 then
                    --      insert_node_after(head,n,newkern(wx))
                    --  end
                        if x ~= 0 then
                            insert_node_before(head,n,newkern(x))
                        end
                    end
                end
            end
            if next(cx) then
                for n, k in next, cx do
                    if k ~= 0 then
                        local rln = rl[n]
                        if rln and rln < 0 then
                            insert_node_before(head,n,newkern(-k))
                        else
                            insert_node_before(head,n,newkern(k))
                        end
                    end
                end
            end
            if not keep then
                kerns = { }
            end
            return head, true
        elseif not keep then
            kerns, cursives, marks = { }, { }, { }
        end
    elseif has_kerns then
        -- we assume done is true because there are kerns
        for n in traverse_id(glyph,head) do
            local k = has_attribute(n,kernpair)
            if k then
                local kk = kerns[k]
                if kk then
                 -- only w can be nil, can be sped up when w == nil
                    local rl, x, y, w = kk[1], kk[2] or 0, kk[3] or 0, kk[4] or 0
                    if y ~= 0 then
                        n.yoffset = y -- todo: h ?
                    end
                    local wx = w - x
                    if rl < 0 then
                        if wx ~= 0 then
                            insert_node_before(head,n,newkern(wx))
                        end
                        if x ~= 0 then
                            insert_node_after (head,n,newkern(x))
                        end
                    else
                    --  if wx ~= 0 then
                    --      insert_node_after(head,n,newkern(wx))
                    --  end
                        if x ~= 0 then
                            insert_node_before(head,n,newkern(x))
                        end
                    end
                end
            end
        end
        if not keep then
            kerns = { }
        end
        return head, true
    end
    return head, false
end

-- -- -- KEEP OLD ONE, THE NEXT IS JUST OPTIMIZED -- -- --

function nodes.XXXXXXXxinject_kerns(head,tail,keep)
    if trace_injections then
        nodes.trace_injection(head)
    end
    local has_marks, has_cursives, has_kerns = next(marks), next(cursives), next(kerns)
    if has_marks or has_cursives then
        -- in the future variant we will not copy items but refs to tables
        local done, ky, valid, cx, wx = false, { }, { }, { }, { }
        for n in traverse_id(glyph,head) do
            if n.subtype < 256 then
                valid[#valid+1] = n
                if has_kerns then -- move outside loop
                    local k = has_attribute(n,kernpair)
                    if k then
                        local kk = kerns[k]
                        if kk then
                            local x, y, w, h = kk[2], kk[3], kk[4], kk[5]
                            local dy = y - h
                            if dy ~= 0 then
                                ky[n] = dy
                            end
                            if w ~= 0 or x ~= 0 then
                                wx[n] = kk
                            end
                        end
                    end
                end
            end
        end
        if #valid > 0 then
            -- we can assume done == true because we have cursives and marks
            local cx = { }
            if has_kerns and next(ky) then
                for n, k in next, ky do
                    n.yoffset = k
                end
            end
            -- todo: reuse t and use maxt
            if has_cursives then
                local n_cursbase, n_curscurs, p_cursbase, n, p, nf, tm = nil, nil, nil, nil, nil, nil, nil
                -- since we need valid[n+1] we can also use a "while true do"
                local t, d, maxt = { }, { }, 0
                for i=1,#valid do -- valid == glyphs
                    n = valid[i]
                    if n.font ~= nf then
                        nf = n.font
                        tm = fontdata[nf].marks
                        -- maybe flush
                        maxt = 0
                    end
                    if not tm[n.char] then
                        n_cursbase = has_attribute(n,cursbase)
                        n_curscurs = has_attribute(n,curscurs)
                        if p_cursbase then
                            if p_cursbase == n_curscurs then
                                local c = cursives[n_curscurs]
                                if c then
                                    local rlmode, dx, dy, ws, wn = c[1], c[2], c[3], c[4], c[5]
                                    if rlmode >= 0 then
                                        dx = dx - ws
                                    else
                                        dx = dx + wn
                                    end
                                    if dx ~= 0 then
if rlmode < 0 then
                                        cx[n] = -dx
else
                                        cx[n] = dx
end
                                    end
                                --  if rlmode and rlmode < 0 then
                                        dy = -dy
                                --  end
                                    maxt = maxt + 1
                                    t[maxt] = p
                                    d[maxt] = dy
                                else
                                    maxt = 0
                                end
                            end
                        elseif maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                t[i].yoffset = t[i].yoffset + ny
                            end
                            maxt = 0
                        end
                        if not n_cursbase and maxt > 0 then
                            local ny = n.yoffset
                            for i=maxt,1,-1 do
                                ny = ny + d[i]
                                t[i].yoffset = ny
                            end
                            maxt = 0
                        end
                        p_cursbase, p = n_cursbase, n
                    end
                end
                if maxt > 0 then
                    local ny = n.yoffset
                    for i=maxt,1,-1 do
                        ny = ny + d[i]
                        t[i].yoffset = ny
                    end
                    maxt = 0
                end
                if not keep then
                    cursives = { }
                end
            end
            if has_marks then
                local p_markbase, n_markmark = nil, nil
                for i=1,#valid do
                    local p = valid[i]
                    p_markbase = has_attribute(p,markbase)
                    if p_markbase then
                        local mrks = marks[p_markbase]
                        for n in traverse_id(glyph,p.next) do
                            n_markmark = has_attribute(n,markmark)
                            if p_markbase == n_markmark then
                                local index = has_attribute(n,markdone) or 1
                                local d = mrks[index]
                                if d then
                                    local d1, d2 = d[1], d[2]
                                    if d1 ~= 0 then
                                        n.xoffset = p.xoffset - d[1]
                                    end
                                    if d2 ~= 0 then
                                        n.yoffset = p.yoffset + d[2]
                                    end
                                end
                            else
                                break
                            end
                        end
                    end
                end
                if not keep then
                    marks = { }
                end
            end
            -- todo : combine
            if next(wx) then
                for n, k in next, wx do
                 -- only w can be nil, can be sped up when w == nil
                    local rl, x, w = k[1], k[2] or 0, k[4] or 0
                    local wx = w - x
                    if rl < 0 then
                        if wx ~= 0 then
                            insert_node_before(head,n,newkern(wx))
                        end
                        if x ~= 0 then
                            insert_node_after (head,n,newkern(x))
                        end
                    else
                    --  if wx ~= 0 then
                    --      insert_node_after(head,n,newkern(wx))
                    --  end
                        if x ~= 0 then
                            insert_node_before(head,n,newkern(x))
                        end
                    end
                end
            end
            if next(cx) then
                for n, k in next, cx do
                    insert_node_before(head,n,newkern(k))
                end
            end
            if not keep then
                kerns = { }
            end
            return head, true
        elseif not keep then
            kerns, cursives, marks = { }, { }, { }
        end
    elseif has_kerns then
        -- we assume done is true because there are kerns
        for n in traverse_id(glyph,head) do
            local k = has_attribute(n,kernpair)
            if k then
                local kk = kerns[k]
                if kk then
                 -- only w can be nil, can be sped up when w == nil
                    local rl, x, y, w = kk[1], kk[2] or 0, kk[3] or 0, kk[4] or 0
                    if y ~= 0 then
                        n.yoffset = y -- todo: h ?
                    end
                    local wx = w - x
                    if rl < 0 then
                        if wx ~= 0 then
                            insert_node_before(head,n,newkern(wx))
                        end
                        if x ~= 0 then
                            insert_node_after (head,n,newkern(x))
                        end
                    else
                    --  if wx ~= 0 then
                    --      insert_node_after(head,n,newkern(wx))
                    --  end
                        if x ~= 0 then
                            insert_node_before(head,n,newkern(x))
                        end
                    end
                end
            end
        end
        if not keep then
            kerns = { }
        end
        return head, true
    end
    return head, false
end
