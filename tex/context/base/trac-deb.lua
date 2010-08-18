if not modules then modules = { } end modules ['trac-deb'] = {
    version   = 1.001,
    comment   = "companion to trac-deb.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg = lpeg
local lpegmatch = lpeg.match
local format, concat = string.format, table.concat
local tonumber, tostring = tonumber, tostring
local texdimen, textoks, texcount = tex.dimen, tex.toks, tex.count

-- maybe tracers -> tracers.tex (and tracers.lua for current debugger)

local report_system = logs.new("system")

tracers         = tracers or { }
local tracers   = tracers

tracers.lists   = { }
local lists     = tracers.lists

tracers.strings = { }
local strings   = tracers.strings

strings.undefined = "undefined"

lists.scratch = {
    0, 2, 4, 6, 8
}

lists.internals = {
    'p:hsize', 'p:parindent', 'p:leftskip','p:rightskip',
    'p:vsize', 'p:parskip', 'p:baselineskip', 'p:lineskip', 'p:topskip'
}

lists.context = {
    'd:lineheight',
    'c:realpageno', 'c:userpageno', 'c:pageno', 'c:subpageno'
}

local types = {
    ['d'] = tracers.dimen,
    ['c'] = tracers.count,
    ['t'] = tracers.toks,
    ['p'] = tracers.primitive
}

local splitboth = lpeg.splitat(":")
local splittype = lpeg.firstofsplit(":")
local splitname = lpeg.secondofsplit(":")

function tracers.type(csname)
    return lpegmatch(splittype,csname)
end

function tracers.name(csname)
    return lpegmatch(splitname,csname) or csname
end

function tracers.cs(csname)
    local tag, name = lpegmatch(splitboth,csname)
    if name and types[tag] then
        return types[tag](name)
    else
        return tracers.primitive(csname)
    end
end

function tracers.dimen(name)
    local d = texdimen[name]
    return d and number.topoints(d) or strings.undefined
end

function tracers.count(name)
    return texcount[name] or strings.undefined
end

function tracers.toks(name,limit)
    local t = textoks[name]
    return t and string.limit(t,tonumber(limit) or 40) or strings.undefined
end

function tracers.primitive(name)
    return tex[name] or strings.undefined
end

function tracers.knownlist(name)
    local l = lists[name]
    return l and #l > 0
end

function tracers.showlines(filename,linenumber,offset)
    local data = io.loaddata(filename)
    local lines = data and string.splitlines(data)
    if lines and #lines > 0 then
        offset = tonumber(offset) or 10
        linenumber = tonumber(linenumber) or 10
        local start = math.max(linenumber - offset,1)
        local stop = math.min(linenumber + offset,#lines)
        if stop > #lines then
            return "<linenumber past end of file>"
        else
            local result, fmt = { }, "%" .. #tostring(stop) .. "d %s  %s"
            for n=start,stop do
                result[#result+1] = format(fmt,n,n == linenumber and ">>" or "  ",lines[n])
            end
            return concat(result,"\n")
        end
    else
        return "<empty file>"
    end
end

function tracers.printerror(offset)
    local filename, linenumber = status.filename, tonumber(status.linenumber) or 0
    if not filename then
        report_system("error not related to input file: %s ...",status.lasterrorstring)
    elseif type(filename) == "number" then
        report_system("error on line %s of filehandle %s: %s ...",linenumber,filename,status.lasterrorstring)
    else
        -- currently we still get the error message printed to the log/console so we
        -- add a bit of spacing around our variant
        texio.write_nl("\n")
        report_system("error on line %s in file %s: %s ...\n",linenumber,filename,status.lasterrorstring or "?") -- lua error?
        texio.write_nl(tracers.showlines(filename,linenumber,offset),"\n")
    end
end

directives.register("system.errorcontext", function(v)
    if v then
        callback.register('show_error_hook', function() tracers.printerror(v) end)
    else
        callback.register('show_error_hook', nil)
    end
end)

-- this might move

lmx = lmx or { }

if not lmx.variables then lmx.variables = { } end

lmx.htmfile = function(name) return environment.jobname .. "-status.html" end
lmx.lmxfile = function(name) return resolvers.find_file(name,'tex') end

function lmx.showdebuginfo(lmxname)
    local variables = {
        ['title']                = 'ConTeXt Debug Information',
        ['color-background-one'] = lmx.get('color-background-green'),
        ['color-background-two'] = lmx.get('color-background-blue'),
    }
    if lmxname == false then
        return variables
    else
        lmx.show(lmxname or 'context-debug.lmx',variables)
    end
end

function lmx.showerror(lmxname)
    local filename, linenumber, errorcontext = status.filename, tonumber(status.linenumber) or 0, ""
    if not filename then
        filename, errorcontext = 'unknown', 'error in filename'
    elseif type(filename) == "number" then
        filename, errorcontext = format("<read %s>",filename), 'unknown error'
    else
        errorcontext = tracers.showlines(filename,linenumber,offset)
    end
    local variables = {
        ['title']                = 'ConTeXt Error Information',
        ['errormessage']         = status.lasterrorstring,
        ['linenumber']           = linenumber,
        ['color-background-one'] = lmx.get('color-background-yellow'),
        ['color-background-two'] = lmx.get('color-background-purple'),
        ['filename']             = filename,
        ['errorcontext']         = errorcontext,
    }
    if lmxname == false then
        return variables
    else
        lmx.show(lmxname or 'context-error.lmx',variables)
    end
end

function lmx.overloaderror()
    callback.register('show_error_hook', function() lmx.showerror() end) -- prevents arguments being passed
end

directives.register("system.showerror", lmx.overloaderror)

local debugger = utilities.debugger

local function trace_calls(n)
    debugger.enable()
    luatex.register_stop_actions(function()
        debugger.disable()
        debugger.savestats(tex.jobname .. "-luacalls.log",tonumber(n))
    end)
    trace_calls = function() end
end

directives.register("system.tracecalls", function(n) trace_calls(n) end) -- indirect is needed for nilling
