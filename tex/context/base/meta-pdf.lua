if not modules then modules = { } end modules ['meta-pdf'] = {
    version   = 1.001,
    comment   = "companion to meta-pdf.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Finally we used an optimized version. The test code can be found in
-- meta-pdh.lua but since we no longer want to overload functione we
-- use more locals now.

local concat, format, gsub, find = table.concat, string.format, string.gsub, string.find
local byte = string.byte
local texsprint = tex.sprint

local ctxcatcodes = tex.ctxcatcodes

mptopdf   = { }
mptopdf.n = 0

local m_path, m_stack, m_texts, m_version, m_date, m_shortcuts = { }, { }, { }, 0, 0, false

local m_stack_close, m_stack_path, m_stack_concat = false, { }, nil

local function resetpath()
    m_stack_close   = false
    m_stack_path    = { }
    m_stack_concat  = nil
end

local function resetall()
    m_path, m_stack, m_texts, m_version, m_shortcuts = { }, { }, { }, 0, false
    resetpath()
end

resetall()

-- code injection, todo: collect and flush packed using node injection

local function pdfcode(str) -- not used
    texsprint(ctxcatcodes,"\\MPScode{",str,"}")
end
local function texcode(str)
    texsprint(ctxcatcodes,str)
end

-- auxiliary functions

local function flushconcat()
    if m_stack_concat then
        texsprint(ctxcatcodes,"\\MPScode{",concat(m_stack_concat," ")," cm}")
        m_stack_concat = nil
    end
end

local function flushpath(cmd)
    -- faster: no local function
    if #m_stack_path > 0 then
        local path = { }
        if m_stack_concat then
            local sx, sy = m_stack_concat[1], m_stack_concat[4]
            local rx, ry = m_stack_concat[2], m_stack_concat[3]
            local tx, ty = m_stack_concat[5], m_stack_concat[6]
            local d = (sx*sy) - (rx*ry)
        --  local function mpconcat(px, py) -- move this inline
        --      return (sy*(px-tx)-ry*(py-ty))/d, (sx*(py-ty)-rx*(px-tx))/d
        --  end
            for k=1,#m_stack_path do
                local v = m_stack_path[k]
                local px, py = v[1], v[2] ; v[1], v[2] = (sy*(px-tx)-ry*(py-ty))/d, (sx*(py-ty)-rx*(px-tx))/d -- mpconcat(v[1],v[2])
                if #v == 7 then
                    local px, py = v[3], v[4] ; v[3], v[4] = (sy*(px-tx)-ry*(py-ty))/d, (sx*(py-ty)-rx*(px-tx))/d -- mpconcat(v[3],v[4])
                    local px, py = v[5], v[6] ; v[5], v[6] = (sy*(px-tx)-ry*(py-ty))/d, (sx*(py-ty)-rx*(px-tx))/d -- mpconcat(v[5],v[6])
                end
                path[#path+1] = concat(v," ")
            end
        else
            for k=1,#m_stack_path do
                path[#path+1] = concat(m_stack_path[k]," ")
            end
        end
        flushconcat()
        texcode("\\MPSpath{" .. concat(path," ") .. "}")
        if m_stack_close then
            texcode("\\MPScode{h " .. cmd .. "}")
        else
            texcode("\\MPScode{" .. cmd .."}")
        end
    end
    resetpath()
end

-- mp interface

mps = mps or { }

function mps.creator(a, b, c)
    m_version = tonumber(b)
end

function mps.creationdate(a)
    m_date = a
end

function mps.newpath()
    m_stack_path = { }
end

function mps.boundingbox(llx, lly, urx, ury)
    texcode("\\MPSboundingbox{" .. llx .. "}{" .. lly .. "}{" .. urx .. "}{" .. ury .. "}")
end

function mps.moveto(x,y)
    m_stack_path[#m_stack_path+1] = {x,y,"m"}
end

function mps.curveto(ax, ay, bx, by, cx, cy)
    m_stack_path[#m_stack_path+1] = {ax,ay,bx,by,cx,cy,"c"}
end

function mps.lineto(x,y)
    m_stack_path[#m_stack_path+1] = {x,y,"l"}
end

function mps.rlineto(x,y)
    local dx, dy = 0, 0
    if #m_stack_path > 0 then
        dx, dy = m_stack_path[#m_stack_path][1], m_stack_path[#m_stack_path][2]
    end
    m_stack_path[#m_stack_path+1] = {dx,dy,"l"}
end

function mps.translate(tx,ty)
    texsprint(ctxcatcodes,"\\MPScode{1 0 0 0 1 ",tx," ",ty," cm}")
end

function mps.scale(sx,sy)
    m_stack_concat = {sx,0,0,sy,0,0}
end

function mps.concat(sx, rx, ry, sy, tx, ty)
    m_stack_concat = {sx,rx,ry,sy,tx,ty}
end

function mps.setlinejoin(d)
    texsprint(ctxcatcodes,"\\MPScode{",d," j}")
end

function mps.setlinecap(d)
    texsprint(ctxcatcodes,"\\MPScode{",d," J}")
end

function mps.setmiterlimit(d)
    texsprint(ctxcatcodes,"\\MPScode{",d," M}")
end

function mps.gsave()
    texsprint(ctxcatcodes,"\\MPScode{q}")
end

function mps.grestore()
    texsprint(ctxcatcodes,"\\MPScode{Q}")
end

function mps.setdash(...) -- can be made faster, operate on t = { ... }
    local n = select("#",...)
    texsprint(ctxcatcodes,"\\MPScode{","[",concat({...}," ",1,n-1),"] ",select(n,...)," d}")
end

function mps.resetdash()
    texsprint(ctxcatcodes,"\\MPScode{[ ] 0 d}")
end

function mps.setlinewidth(d)
    texsprint(ctxcatcodes,"\\MPScode{",d," w}")
end

function mps.closepath()
    m_stack_close = true
end

function mps.fill()
    flushpath('f')
end

function mps.stroke()
    flushpath('S')
end

function mps.both()
    flushpath('B')
end

function mps.clip()
    flushpath('W n')
end

function mps.textext(font, scale, str) -- old parser
    local dx, dy = 0, 0
    if #m_stack_path > 0 then
        dx, dy = m_stack_path[1][1], m_stack_path[1][2]
    end
    flushconcat()
    texcode("\\MPStextext{"..font.."}{"..scale.."}{"..str.."}{"..dx.."}{"..dy.."}")
    resetpath()
end

function mps.setrgbcolor(r,g,b) -- extra check
    r, g = tonumber(r), tonumber(g) -- needed when we use lpeg
    if r == 0.0123 and g < 0.1 then
        texcode("\\MPSspecial{" .. g*10000 .. "}{" .. b*10000 .. "}")
    elseif r == 0.123 and g < 0.1 then
        texcode("\\MPSspecial{" .. g* 1000 .. "}{" .. b* 1000 .. "}")
    else
        texcode("\\MPSrgb{" .. r .. "}{" .. g .. "}{" .. b .. "}")
    end
end

function mps.setcmykcolor(c,m,y,k)
    texcode("\\MPScmyk{" .. c .. "}{" .. m .. "}{" .. y .. "}{" .. k .. "}")
end

function mps.setgray(s)
    texcode("\\MPSgray{" .. s .. "}")
end

function mps.specials(version,signal,factor) -- 2.0 123 1000
end

function mps.special(...) -- 7 1 0.5 1 0 0 1 3
    local n = select("#",...)
    texcode("\\MPSbegin\\MPSset{" .. concat({...},"}\\MPSset{",2,n) .. "}\\MPSend")
end

function mps.begindata()
end

function mps.enddata()
end

function mps.showpage()
end

function mps.attribute(id,value)
    texcode("\\attribute " .. id .. "=" .. value .. " ")
end

-- lpeg parser

-- The lpeg based parser is rather optimized for the kind of output
-- that MetaPost produces. It's my first real lpeg code, which may
-- show. Because the parser binds to functions, we define it last.

local lpegP, lpegR, lpegS, lpegC, lpegCc, lpegCs = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs

local digit    = lpegR("09")
local eol      = lpegS('\r\n')^1
local sp       = lpegP(' ')^1
local space    = lpegS(' \r\n')^1
local number   = lpegS('0123456789.-+')^1
local nonspace = lpegP(1-lpegS(' \r\n'))^1

local spec  = digit^2 * lpegP("::::") * digit^2
local text  = lpegCc("{") * (
        lpegP("\\") * ( (digit * digit * digit) / function(n) return "c" .. tonumber(n,8) end) +
                         lpegP(" ")             / function(n) return "\\c32" end + -- never in new mp
                         lpegP(1)               / function(n) return "\\c" .. byte(n) end
    ) * lpegCc("}")
local package = lpegCs(spec + text^0)

function mps.fshow(str,font,scale) -- lpeg parser
    mps.textext(font,scale,package:match(str))
end

local cnumber = lpegC(number)
local cstring = lpegC(nonspace)

local specials           = (lpegP("%%MetaPostSpecials:") * sp * (cstring * sp^0)^0 * eol) / mps.specials
local special            = (lpegP("%%MetaPostSpecial:")  * sp * (cstring * sp^0)^0 * eol) / mps.special
local boundingbox        = (lpegP("%%BoundingBox:")      * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox
local highresboundingbox = (lpegP("%%HiResBoundingBox:") * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox

local setup              = lpegP("%%BeginSetup")  * (1 - lpegP("%%EndSetup") )^1
local prolog             = lpegP("%%BeginProlog") * (1 - lpegP("%%EndProlog"))^1
local comment            = lpegP('%')^1 * (1 - eol)^1

local curveto            = ((cnumber * sp)^6 * lpegP("curveto")            ) / mps.curveto
local lineto             = ((cnumber * sp)^2 * lpegP("lineto")             ) / mps.lineto
local rlineto            = ((cnumber * sp)^2 * lpegP("rlineto")            ) / mps.rlineto
local moveto             = ((cnumber * sp)^2 * lpegP("moveto")             ) / mps.moveto
local setrgbcolor        = ((cnumber * sp)^3 * lpegP("setrgbcolor")        ) / mps.setrgbcolor
local setcmykcolor       = ((cnumber * sp)^4 * lpegP("setcmykcolor")       ) / mps.setcmykcolor
local setgray            = ((cnumber * sp)^1 * lpegP("setgray")            ) / mps.setgray
local newpath            = (                   lpegP("newpath")            ) / mps.newpath
local closepath          = (                   lpegP("closepath")          ) / mps.closepath
local fill               = (                   lpegP("fill")               ) / mps.fill
local stroke             = (                   lpegP("stroke")             ) / mps.stroke
local clip               = (                   lpegP("clip")               ) / mps.clip
local both               = (                   lpegP("gsave fill grestore")) / mps.both
local showpage           = (                   lpegP("showpage")           )
local setlinejoin        = ((cnumber * sp)^1 * lpegP("setlinejoin")        ) / mps.setlinejoin
local setlinecap         = ((cnumber * sp)^1 * lpegP("setlinecap")         ) / mps.setlinecap
local setmiterlimit      = ((cnumber * sp)^1 * lpegP("setmiterlimit")      ) / mps.setmiterlimit
local gsave              = (                   lpegP("gsave")              ) / mps.gsave
local grestore           = (                   lpegP("grestore")           ) / mps.grestore

local setdash            = (lpegP("[") * (cnumber * sp^0)^0 * lpegP("]") * sp * cnumber * sp * lpegP("setdash")) / mps.setdash
local concat             = (lpegP("[") * (cnumber * sp^0)^6 * lpegP("]")                * sp * lpegP("concat") ) / mps.concat
local scale              = (             (cnumber * sp^0)^6                             * sp * lpegP("concat") ) / mps.concat

local fshow              = (lpegP("(") * lpegC((1-lpegP(")"))^1) * lpegP(")") * space * cstring * space * cnumber * space * lpegP("fshow")) / mps.fshow
local fshow              = (lpegP("(") * lpegCs( ( lpegP("\\(")/"\\050" + lpegP("\\)")/"\\051" + (1-lpegP(")")) )^1 )
                            * lpegP(")") * space * cstring * space * cnumber * space * lpegP("fshow")) / mps.fshow

local setlinewidth_x     = (lpegP("0") * sp * cnumber * sp * lpegP("dtransform truncate idtransform setlinewidth pop")) / mps.setlinewidth
local setlinewidth_y     = (cnumber * sp * lpegP("0 dtransform exch truncate exch idtransform pop setlinewidth")  ) / mps.setlinewidth

local c   = ((cnumber * sp)^6 * lpegP("c")  ) / mps.curveto -- ^6 very inefficient, ^1 ok too
local l   = ((cnumber * sp)^2 * lpegP("l")  ) / mps.lineto
local r   = ((cnumber * sp)^2 * lpegP("r")  ) / mps.rlineto
local m   = ((cnumber * sp)^2 * lpegP("m")  ) / mps.moveto
local vlw = ((cnumber * sp)^1 * lpegP("vlw")) / mps.setlinewidth
local hlw = ((cnumber * sp)^1 * lpegP("hlw")) / mps.setlinewidth

local R   = ((cnumber * sp)^3 * lpegP("R")  ) / mps.setrgbcolor
local C   = ((cnumber * sp)^4 * lpegP("C")  ) / mps.setcmykcolor
local G   = ((cnumber * sp)^1 * lpegP("G")  ) / mps.setgray

local lj  = ((cnumber * sp)^1 * lpegP("lj") ) / mps.setlinejoin
local ml  = ((cnumber * sp)^1 * lpegP("ml") ) / mps.setmiterlimit
local lc  = ((cnumber * sp)^1 * lpegP("lc") ) / mps.setlinecap

local n   = lpegP("n") / mps.newpath
local p   = lpegP("p") / mps.closepath
local S   = lpegP("S") / mps.stroke
local F   = lpegP("F") / mps.fill
local B   = lpegP("B") / mps.both
local W   = lpegP("W") / mps.clip
local P   = lpegP("P") / mps.showpage

local q   = lpegP("q") / mps.gsave
local Q   = lpegP("Q") / mps.grestore

local sd  = (lpegP("[") * (cnumber * sp^0)^0 * lpegP("]") * sp * cnumber * sp * lpegP("sd")) / mps.setdash
local rd  = (                                                                   lpegP("rd")) / mps.resetdash

local s   = (             (cnumber * sp^0)^2                   * lpegP("s") ) / mps.scale
local t   = (lpegP("[") * (cnumber * sp^0)^6 * lpegP("]") * sp * lpegP("t") ) / mps.concat

-- experimental

local attribute = ((cnumber * sp)^2 * lpegP("attribute")) / mps.attribute
local A         = ((cnumber * sp)^2 * lpegP("A"))         / mps.attribute

local preamble = (
    prolog + setup +
    boundingbox + highresboundingbox + specials + special +
    comment
)

local procset = (
    lj + ml + lc +
    c + l + m + n + p + r +
    A +
    R + C + G +
    S + F + B + W +
    vlw + hlw +
    Q + q +
    sd + rd +
    t + s +
    fshow +
    P
)

local verbose = (
    curveto + lineto + moveto + newpath + closepath + rlineto +
    setrgbcolor + setcmykcolor + setgray +
    attribute +
    setlinejoin + setmiterlimit + setlinecap +
    stroke + fill + clip + both +
    setlinewidth_x + setlinewidth_y +
    gsave + grestore +
    concat + scale +
    fshow +
    setdash + -- no resetdash
    showpage
)

-- order matters in terms of speed / we could check for procset first

local captures_old = ( space + verbose + preamble           )^0
local captures_new = ( space + procset + preamble + verbose )^0

local function parse(m_data)
    if find(m_data,"%%%%BeginResource: procset mpost") then
        captures_new:match(m_data)
    else
        captures_old:match(m_data)
    end
end

-- main converter

function mptopdf.convertmpstopdf(name)
    resetall()
    local ok, m_data, n = resolvers.loadbinfile(name, 'tex') -- we need a binary load !
    if ok then
        statistics.starttiming(mptopdf)
        mptopdf.n = mptopdf.n + 1
        parse(m_data)
        resetall()
        statistics.stoptiming(mptopdf)
    else
        tex.print("file " .. name .. " not found")
    end
end


-- status info

statistics.register("mps conversion time",function()
    local n = mptopdf.n
    if n > 0 then
        return format("%s seconds, %s conversions", statistics.elapsedtime(mptopdf),n)
    else
        return nil
    end
end)
