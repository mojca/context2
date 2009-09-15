if not modules then modules = { } end modules ['mtx-context'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts         = scripts         or { }
scripts.context = scripts.context or { }

-- a demo cld file:
--
-- context.starttext()
-- context.chapter("Hello There")
-- context.readfile("tufte","","not found")
-- context.stoptext()

-- l-file / todo

function file.needsupdate(oldfile,newfile)
    return true
end
function file.syncmtimes(oldfile,newfile)
end

-- l-io

function io.copydata(fromfile,tofile)
    io.savedata(tofile,io.loaddata(fromfile) or "")
end

-- ctx

ctxrunner = { }

do

    function ctxrunner.filtered(str,method)
        str = tostring(str)
        if     method == 'name'     then str = file.removesuffix(file.basename(str))
        elseif method == 'path'     then str = file.dirname(str)
        elseif method == 'suffix'   then str = file.extname(str)
        elseif method == 'nosuffix' then str = file.removesuffix(str)
        elseif method == 'nopath'   then str = file.basename(str)
        elseif method == 'base'     then str = file.basename(str)
    --  elseif method == 'full'     then
    --  elseif method == 'complete' then
    --  elseif method == 'expand'   then -- str = file.expand_path(str)
        end
        return str:gsub("\\","/")
    end

    function ctxrunner.substitute(e,str)
        local attributes = e.at
        if str and attributes then
            if attributes['method'] then
                str = ctxrunner.filtered(str,attributes['method'])
            end
            if str == "" and attributes['default'] then
                str = attributes['default']
            end
        end
        return str
    end

    function ctxrunner.reflag(flags)
        local t = { }
        for _, flag in pairs(flags) do
            local key, value = flag:match("^(.-)=(.+)$")
            if key and value then
                t[key] = value
            else
                t[flag] = true
            end
        end
        return t
    end

    function ctxrunner.substitute(str)
        return str
    end

    function ctxrunner.justtext(str)
        str = xml.unescaped(tostring(str))
        str = xml.cleansed(str)
        str = str:gsub("\\+",'/')
        str = str:gsub("%s+",' ')
        return str
    end

    function ctxrunner.new()
        return {
            ctxname      = "",
            jobname      = "",
            xmldata      = nil,
            suffix       = "prep",
            locations    = { '..', '../..' },
            variables    = { },
            messages     = { },
            environments = { },
            modules      = { },
            filters      = { },
            flags        = { },
            modes        = { },
            prepfiles    = { },
            paths        = { },
        }
    end

    function ctxrunner.savelog(ctxdata,ctlname)
        local function yn(b)
            if b then return 'yes' else return 'no' end
        end
        if not ctlname or ctlname == "" or ctlname == ctxdata.jobname then
            if ctxdata.jobname then
                ctlname = file.replacesuffix(ctxdata.jobname,'ctl')
            elseif ctxdata.ctxname then
                ctlname = file.replacesuffix(ctxdata.ctxname,'ctl')
            else
                logs.simple("invalid ctl name: %s",ctlname or "?")
                return
            end
        end
        if table.is_empty(ctxdata.prepfiles) then
            logs.simple("nothing prepared, no ctl file saved")
            os.remove(ctlname)
        else
            logs.simple("saving logdata in: %s",ctlname)
            f = io.open(ctlname,'w')
            if f then
                f:write("<?xml version='1.0' standalone='yes'?>\n\n")
                f:write(string.format("<ctx:preplist local='%s'>\n",yn(ctxdata.runlocal)))
--~                 for name, value in pairs(ctxdata.prepfiles) do
                for _, name in ipairs(table.sortedkeys(ctxdata.prepfiles)) do
                    f:write(string.format("\t<ctx:prepfile done='%s'>%s</ctx:prepfile>\n",yn(ctxdata.prepfiles[name]),name))
                end
                f:write("</ctx:preplist>\n")
                f:close()
            end
        end
    end

    function ctxrunner.register_path(ctxdata,path)
        -- test if exists
        ctxdata.paths[ctxdata.paths+1] = path
    end

    function ctxrunner.trace(ctxdata)
        print(table.serialize(ctxdata.messages))
        print(table.serialize(ctxdata.flags))
        print(table.serialize(ctxdata.environments))
        print(table.serialize(ctxdata.modules))
        print(table.serialize(ctxdata.filters))
        print(table.serialize(ctxdata.modes))
        print(xml.serialize(ctxdata.xmldata))
    end

    function ctxrunner.manipulate(ctxdata,ctxname,defaultname)

        if not ctxdata.jobname or ctxdata.jobname == "" then
            return
        end

        ctxdata.ctxname = ctxname or file.removesuffix(ctxdata.jobname) or ""

        if ctxdata.ctxname == "" then
            return
        end

        ctxdata.jobname = file.addsuffix(ctxdata.jobname,'tex')
        ctxdata.ctxname = file.addsuffix(ctxdata.ctxname,'ctx')

        logs.simple("jobname: %s",ctxdata.jobname)
        logs.simple("ctxname: %s",ctxdata.ctxname)

        -- mtxrun should resolve kpse: and file:

        local usedname = ctxdata.ctxname
        local found    = lfs.isfile(usedname)

        if not found then
            for _, path in pairs(ctxdata.locations) do
                local fullname = file.join(path,ctxdata.ctxname)
                if lfs.isfile(fullname) then
                    usedname, found = fullname, true
                    break
                end
            end
        end

usedname = resolvers.find_file(ctxdata.ctxname,"tex")
found = usedname ~= ""

        if not found and defaultname and defaultname ~= "" and lfs.isfile(defaultname) then
            usedname, found = defaultname, true
        end

        if not found then
            return
        end

        ctxdata.xmldata = xml.load(usedname)

        if not ctxdata.xmldata then
            return
        else
            -- test for valid, can be text file
        end

        xml.include(ctxdata.xmldata,'ctx:include','name', table.append({'.', file.dirname(ctxdata.ctxname)},ctxdata.locations))

        ctxdata.variables['job'] = ctxdata.jobname

        ctxdata.flags        = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:flags/ctx:flag",true)
        ctxdata.environments = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:environment",true)
        ctxdata.modules      = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:module",true)
        ctxdata.filters      = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:filter",true)
        ctxdata.modes        = xml.collect_texts(ctxdata.xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:mode",true)
        ctxdata.messages     = xml.collect_texts(ctxdata.xmldata,"ctx:message",true)

        ctxdata.flags = ctxrunner.reflag(ctxdata.flags)

        for _, message in ipairs(ctxdata.messages) do
            logs.simple("ctx comment: %s", xml.tostring(message))
        end

        xml.each(ctxdata.xmldata,"ctx:value[@name='job']", function(ek,e,k)
            e[k] = ctxdata.variables['job'] or ""
        end)

        local commands = { }
        xml.each(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor", function(r,d,k)
            local ek = d[k]
            commands[ek.at and ek.at['name'] or "unknown"] = ek
        end)

        local suffix   = xml.filter(ctxdata.xmldata,"/ctx:job/ctx:preprocess/attribute(suffix)") or ctxdata.suffix
        local runlocal = xml.filter(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:processors/attribute(local)")

        runlocal = toboolean(runlocal)

        for _, files in ipairs(xml.filters.elements(ctxdata.xmldata,"/ctx:job/ctx:preprocess/ctx:files")) do
            for _, pattern in ipairs(xml.filters.elements(files,"ctx:file")) do

                preprocessor = pattern.at['processor'] or ""

                if preprocessor ~= "" then

                    ctxdata.variables['old'] = ctxdata.jobname
                    xml.each(ctxdata.xmldata,"ctx:value", function(r,d,k)
                        local ek = d[k]
                        local ekat = ek.at['name']
                        if ekat == 'old' then
                            d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                        end
                    end)

                    pattern = ctxrunner.justtext(xml.tostring(pattern))

                    local oldfiles = dir.glob(pattern)

                    local pluspath = false
                    if #oldfiles == 0 then
                        -- message: no files match pattern
                        for _, p in ipairs(ctxdata.paths) do
                            local oldfiles = dir.glob(path.join(p,pattern))
                            if #oldfiles > 0 then
                                pluspath = true
                                break
                            end
                        end
                    end
                    if #oldfiles == 0 then
                        -- message: no old files
                    else
                        for _, oldfile in ipairs(oldfiles) do
                            newfile = oldfile .. "." .. suffix -- addsuffix will add one only
                            if ctxdata.runlocal then
                                newfile = file.basename(newfile)
                            end
                            if oldfile ~= newfile and file.needsupdate(oldfile,newfile) then
                            --  message: oldfile needs preprocessing
                            --  os.remove(newfile)
                                for _, pp in ipairs(preprocessor:split(',')) do
                                    local command = commands[pp]
                                    if command then
                                        command = xml.copy(command)
                                        local suf = (command.at and command.at['suffix']) or ctxdata.suffix
                                        if suf then
                                            newfile = oldfile .. "." .. suf
                                        end
                                        if ctxdata.runlocal then
                                            newfile = file.basename(newfile)
                                        end
                                        xml.each(command,"ctx:old", function(r,d,k)
                                            d[k] = ctxrunner.substitute(oldfile)
                                        end)
                                        xml.each(command,"ctx:new", function(r,d,k)
                                            d[k] = ctxrunner.substitute(newfile)
                                        end)
                                        --  message: preprocessing #{oldfile} into #{newfile} using #{pp}
                                        ctxdata.variables['old'] = oldfile
                                        ctxdata.variables['new'] = newfile
                                        xml.each(command,"ctx:value", function(r,d,k)
                                            local ek = d[k]
                                            local ekat = ek.at and ek.at['name']
                                            if ekat then
                                                d[k] = ctxrunner.substitute(ctxdata.variables[ekat] or "")
                                            end
                                        end)
                                        -- potential optimization: when mtxrun run internal
                                        command = xml.text(command)
                                        command = ctxrunner.justtext(command) -- command is still xml element here
                                        logs.simple("command: %s",command)
                                        local result = os.spawn(command) or 0
                                        if result > 0 then
                                            logs.simple("error, return code: %s",result)
                                        end
                                        if ctxdata.runlocal then
                                            oldfile = file.basename(oldfile)
                                        end
                                    end
                                end
                                if lfs.isfile(newfile) then
                                    file.syncmtimes(oldfile,newfile)
                                    ctxdata.prepfiles[oldfile] = true
                                else
                                    logs.simple("error, check target location of new file: %s", newfile)
                                    ctxdata.prepfiles[oldfile] = false
                                end
                            else
                                logs.simple("old file needs no preprocessing")
                                ctxdata.prepfiles[oldfile] = lfs.isfile(newfile)
                            end
                        end
                    end
                end
            end
        end

        ctxrunner.savelog(ctxdata)

    end

    function ctxrunner.preppedfile(ctxdata,filename)
        if ctxdata.prepfiles[file.basename(filename)] then
            return filename .. ".prep"
        else
            return filename
        end
    end

end

-- rest

scripts.context.multipass = {
--  suffixes = { ".tuo", ".tuc" },
    suffixes = { ".tuc" },
    nofruns = 8,
}

function scripts.context.multipass.hashfiles(jobname)
    local hash = { }
    for _, suffix in ipairs(scripts.context.multipass.suffixes) do
        local full = jobname .. suffix
        hash[full] = md5.hex(io.loaddata(full) or "unknown")
    end
    return hash
end

function scripts.context.multipass.changed(oldhash, newhash)
    for k,v in pairs(oldhash) do
        if v ~= newhash[k] then
            return true
        end
    end
    return false
end

scripts.context.backends = {
    pdftex = 'pdftex',
    luatex = 'pdftex',
    pdf    = 'pdftex',
    dvi    = 'dvipdfmx',
    dvips  = 'dvips'
}

function scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,currentrun,finalrun)
    -- take jobname from ctx
    jobname = file.removesuffix(jobname)
    local f = io.open(jobname..".top","w")
    if f then
        local function someflag(flag)
            return (ctxdata and ctxdata.flags[flag]) or environment.argument(flag)
        end
        local function setvalue(flag,format,hash,default)
            local a = someflag(flag) or default
            if a and a ~= "" then
                if hash then
                    if hash[a] then
                        f:write(format:format(a),"\n")
                    end
                else
                    f:write(format:format(a),"\n")
                end
            end
        end
        local function setvalues(flag,format,plural)
            if type(flag) == "table"  then
                for k, v in pairs(flag) do
                    f:write(format:format(v),"\n")
                end
            else
                local a = someflag(flag) or (plural and someflag(flag.."s"))
                if a and a ~= "" then
                    for v in a:gmatch("%s*([^,]+)") do
                        f:write(format:format(v),"\n")
                    end
                end
            end
        end
        local function setfixed(flag,format,...)
            if someflag(flag) then
                f:write(format:format(...),"\n")
            end
        end
        local function setalways(format,...)
            f:write(format:format(...),"\n")
        end
        --
        setalways("%% runtime options files (command line driven)")
        --
        setalways("\\unprotect")
        --
        setalways("%% special commands, mostly for the ctx development team")
        --
        if environment.argument("dumpdelta") then
            setalways("\\tracersdumpdelta")
        elseif environment.argument("dumphash") then
            setalways("\\tracersdumphash")
        end
        setalways("%% feedback and basic job control")
        if type(environment.argument("track")) == "string" then
            setvalue ("track"    , "\\enabletrackers[%s]")
        end
        setfixed ("timing"       , "\\usemodule[timing]")
        setfixed ("batchmode"    , "\\batchmode")
        setfixed ("nonstopmode"  , "\\nonstopmode")
        setfixed ("tracefiles"   , "\\tracefilestrue")
        setfixed ("nostats"      , "\\nomkivstatistics")
        setfixed ("paranoid"     , "\\def\\maxreadlevel{1}")
        --
        setalways("%% handy for special styles")
        --
        setalways("\\startluacode")
        setalways("document = document or { }")
        setalways(table.serialize(environment.arguments, "document.arguments"))
        setalways(table.serialize(environment.files,     "document.files"))
        setalways("\\stopluacode")
        --
        setalways("%% process info")
        --
        setalways(                 "\\setupsystem[\\c!n=%s,\\c!m=%s]", kindofrun or 0, currentrun or 0)
        setalways(                 "\\setupsystem[\\c!type=%s]",os.platform)
        setvalue ("inputfile"    , "\\setupsystem[inputfile=%s]")
        setvalue ("result"       , "\\setupsystem[file=%s]")
        setvalues("path"         , "\\usepath[%s]")
        setvalue ("setuppath"    , "\\setupsystem[\\c!directory={%s}]")
        setvalue ("randomseed"   , "\\setupsystem[\\c!random=%s]")
        setvalue ("arguments"    , "\\setupenv[%s]")
        setalways("%% modes")
        setvalues("modefile"     , "\\readlocfile{%s}{}{}")
        setvalues("mode"         , "\\enablemode[%s]", true)
        if ctxdata then
            setvalues(ctxdata.modes, "\\enablemode[%s]")
        end
        --
        setalways("%% options (not that important)")
        --
        setalways("\\startsetups *runtime:options")
        setvalue ('output'       , "\\setupoutput[%s]", scripts.context.backends, 'pdftex')
        setfixed ("color"        , "\\setupcolors[\\c!state=\\v!start]")
        setvalue ("separation"   , "\\setupcolors[\\c!split=%s]")
        setfixed ("noarrange"    , "\\setuparranging[\\v!disable]")
        if environment.argument('arrange') and not finalrun then
            setalways(             "\\setuparranging[\\v!disable]")
        end
        setalways("\\stopsetups")
        --
        setalways("%% styles and modules")
        --
        setalways("\\startsetups *runtime:modules")
        setvalues("filter"       , "\\useXMLfilter[%s]", true)
        setvalues("usemodule"    , "\\usemodule[%s]", true)
        setvalues("environment"  , "\\environment %s ", true)
        if ctxdata then
            setvalues(ctxdata.modules,      "\\usemodule[%s]")
            setvalues(ctxdata.environments, "\\environment %s ")
        end
        setalways("\\stopsetups")
        --
        setalways("%% done")
        --
        setalways("\\protect \\endinput")
        f:close()
    end
end

function scripts.context.multipass.copyluafile(jobname)
--  io.savedata(jobname..".tuc",io.loaddata(jobname..".tua") or "")
    local tuaname, tucname = jobname..".tua", jobname..".tuc"
    if lfs.isfile(tuaname) then
        os.remove(tucname)
        os.rename(tuaname,tucname)
    end
end

-- obsolete:
--
-- function scripts.context.multipass.copytuifile(jobname)
--     local tuiname, tuoname = jobname .. ".tui", jobname .. ".tuo"
--     if lfs.isfile(tuiname) then
--         local f, g = io.open(tuiname), io.open(tuoname,'w')
--         if f and g then
--             g:write("% traditional utility file, only commands written by mtxrun/context\n%\n")
--             for line in f:lines() do
--                 if line:find("^c ") then
--                     g:write((line:gsub("^c ","")),"%\n")
--                 end
--             end
--             g:write("\\endinput\n")
--             f:close()
--             g:close()
--         end
--     else
--     --  os.remove(tuoname)
--     end
-- end

scripts.context.cldsuffixes = table.tohash {
    "cld",
}

scripts.context.xmlsuffixes = table.tohash {
    "xml",
}

scripts.context.luasuffixes = table.tohash {
    "lua",
}

scripts.context.beforesuffixes = {
    "tuo", "tuc"
}
scripts.context.aftersuffixes = {
    "pdf", "tuo", "tuc", "log"
}

scripts.context.interfaces = {
    en = "cont-en",
    uk = "cont-uk",
    de = "cont-de",
    fr = "cont-fr",
    nl = "cont-nl",
    cz = "cont-cz",
    it = "cont-it",
    ro = "cont-ro",
    pe = "cont-pe",
    -- for taco and me
 -- xp = "cont-xp",
}

scripts.context.defaultformats  = {
    "cont-en",
    "cont-nl",
--  "cont-xp",
    "mptopdf",
--  "metatex",
    "metafun",
    "plain"
}

local function analyze(filename)
    local f = io.open(file.addsuffix(filename,"tex"))
    if f then
        local t = { }
        local line = f:read("*line") or ""
        local preamble = line:match("[\254\255]*%%%s+(.+)$") -- there can be an utf bomb in front
        if preamble then
            for key, value in preamble:gmatch("(%S+)=(%S+)") do
                t[key] = value
            end
            t.type = "tex"
        elseif line:find("^<?xml ") then
            t.type = "xml"
        end
        if not t.engine then
            t.engine = 'luatex'
        end
        f:close()
        return t
    end
    return nil
end

local function makestub(format,filename,prepname)
    local stubname = file.replacesuffix(file.basename(filename),'run')
    local f = io.open(stubname,'w')
    if f then
        f:write("\\starttext\n")
        f:write(string.format(format,prepname or filename),"\n")
        f:write("\\stoptext\n")
        f:close()
        filename = stubname
    end
    return filename
end

function scripts.context.openpdf(name)
    os.spawn(string.format('pdfopen --file "%s" 2>&1', file.replacesuffix(name,"pdf")))
end
function scripts.context.closepdf(name)
    os.spawn(string.format('pdfclose --file "%s" 2>&1', file.replacesuffix(name,"pdf")))
end

--~ function scripts.context.openpdf(name)
--~     -- somehow two instances start up, one with a funny filename
--~     os.spawn(string.format("\"c:/program files/kde/bin/okular.exe\" --unique %s",file.replacesuffix(name,"pdf")))
--~ end
--~ function scripts.context.closepdf(name)
--~     --
--~ end

function scripts.context.run(ctxdata,filename)
    -- filename overloads environment.files
    local files = (filename and { filename }) or environment.files
    if ctxdata then
        -- todo: interface
        for k,v in pairs(ctxdata.flags) do
            environment.setargument(k,v)
        end
    end
    if #files > 0 then
        --
        local interface = environment.argument("interface")
        -- todo: environment.argument("interface","en")
        interface = (type(interface) == "string" and interface) or "en"
        --
        local formatname = scripts.context.interfaces[interface] or "cont-en"
        local formatfile, scriptfile = resolvers.locate_format(formatname)
        -- this catches the command line
        if not formatfile or not scriptfile then
            logs.simple("warning: no format found, forcing remake (commandline driven)")
            scripts.context.generate()
            scripts.context.make(formatname)
            formatfile, scriptfile = resolvers.locate_format(formatname)
        end
        --
        if formatfile and scriptfile then
            for _, filename in ipairs(files) do
                local basename, pathname = file.basename(filename), file.dirname(filename)
                local jobname = file.removesuffix(basename)
                if pathname == "" then
                    filename = "./" .. filename
                end
                -- look at the first line
                local a = analyze(filename)
                if a and (a.engine == 'pdftex' or a.engine == 'xetex' or environment.argument("pdftex") or environment.argument("xetex")) then
                    local texexec = resolvers.find_file("texexec.rb") or ""
                    if texexec ~= "" then
                        os.setenv("RUBYOPT","")
                        local command = string.format("ruby %s %s",texexec,environment.reconstruct_commandline(environment.arguments_after))
                        os.exec(command)
                    end
                else
                    if a and a.interface and a.interface ~= interface then
                        formatname = scripts.context.interfaces[a.interface] or formatname
                        formatfile, scriptfile = resolvers.locate_format(formatname)
                    end
                    -- this catches the command line
                    if not formatfile or not scriptfile then
                        logs.simple("warning: no format found, forcing remake (source driven)")
                        scripts.context.generate()
                        scripts.context.make(formatname)
                        formatfile, scriptfile = resolvers.locate_format(formatname)
                    end
                    if formatfile and scriptfile then
                        -- we default to mkiv xml !
                        -- the --prep argument might become automatic (and noprep)
                        local suffix = file.extname(filename) or "?"
                        if scripts.context.xmlsuffixes[suffix] or environment.argument("forcexml") then
                            if environment.argument("mkii") then
                                filename = makestub("\\processXMLfilegrouped{%s}",filename)
                            else
                                filename = makestub("\\xmlprocess{\\xmldocument}{%s}{}",filename)
                            end
                        elseif scripts.context.cldsuffixes[suffix] or environment.argument("forcecld") then
                            filename = makestub("\\ctxlua{context.runfile('%s')}",filename)
                        elseif scripts.context.luasuffixes[suffix] or environment.argument("forcelua") then
                            filename = makestub("\\ctxlua{dofile('%s')}",filename)
                        elseif environment.argument("prep") then
                            -- we need to keep the original jobname
                            filename = makestub("\\readfile{%s}{}{}",filename,ctxrunner.preppedfile(ctxdata,filename))
                        end
                        --
                        -- todo: also other stubs
                        --
                        local suffix, resultname = environment.argument("suffix"), environment.argument("result")
                        if type(suffix) == "string" then
                            resultname = file.removesuffix(jobname) .. suffix
                        end
                        local oldbase, newbase = "", ""
                        if type(resultname) == "string" then
                            oldbase = file.removesuffix(jobname)
                            newbase = file.removesuffix(resultname)
                            if oldbase ~= newbase then
                                for _, suffix in pairs(scripts.context.beforesuffixes) do
                                    local oldname = file.addsuffix(oldbase,suffix)
                                    local newname = file.addsuffix(newbase,suffix)
                                    local tmpname = "keep-"..oldname
                                    os.remove(tmpname)
                                    os.rename(oldname,tmpname)
                                    os.remove(oldname)
                                    os.rename(newname,oldname)
                                end
                            else
                                resultname = nil
                            end
                        else
                            resultname = nil
                        end
                        --
                        if environment.argument("autopdf") then
                            scripts.context.closepdf(filename)
                            if resultname then
                                scripts.context.closepdf(resultname)
                            end
                        end
                        --
                        local okay = statistics.check_fmt_status(formatfile)
                        if okay ~= true then
                            logs.simple("warning: %s, forcing remake",tostring(okay))
                            scripts.context.generate()
                            scripts.context.make(formatname)
                        end
                        --
                        local flags = { }
                        if environment.argument("batchmode") then
                            flags[#flags+1] = "--interaction=batchmode"
                        end
                        flags[#flags+1] = "--fmt=" .. string.quote(formatfile)
                        flags[#flags+1] = "--lua=" .. string.quote(scriptfile)
                        flags[#flags+1] = "--backend=pdf"
                        local command = string.format("luatex %s %s", table.concat(flags," "), string.quote(filename))
                        local oldhash, newhash = scripts.context.multipass.hashfiles(jobname), { }
                        local once = environment.argument("once")
                        local maxnofruns = (once and 1) or scripts.context.multipass.nofruns
                        local arrange = environment.argument("arrange")
                        for i=1,maxnofruns do
                            -- 1:first run, 2:successive run, 3:once, 4:last of maxruns
                            local kindofrun = (once and 3) or (i==1 and 1) or (i==maxnofruns and 4) or 2
                            scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,i,false) -- kindofrun, currentrun, final
                            logs.simple("run %s: %s",i,command)
                            local returncode, errorstring = os.spawn(command)
                        --~ if returncode == 3 then
                        --~     scripts.context.generate()
                        --~     scripts.context.make(formatname)
                        --~     returncode, errorstring = os.spawn(command)
                        --~     if returncode == 3 then
                        --~         logs.simple("fatal error, return code 3, message: %s",errorstring or "?")
                        --~         os.exit(1)
                        --~     end
                        --~ end
                            if not returncode then
                                logs.simple("fatal error, no return code, message: %s",errorstring or "?")
                                os.exit(1)
                                break
                            elseif returncode > 0 then
                                logs.simple("fatal error, return code: %s",returncode or "?")
                                os.exit(returncode)
                                break
                            else
                                scripts.context.multipass.copyluafile(jobname)
                            --  scripts.context.multipass.copytuifile(jobname)
                                newhash = scripts.context.multipass.hashfiles(jobname)
                                if scripts.context.multipass.changed(oldhash,newhash) then
                                    oldhash = newhash
                                else
                                    break
                                end
                            end
                        end
                        --
                        if arrange then
                            local kindofrun = 3
                            scripts.context.multipass.makeoptionfile(jobname,ctxdata,kindofrun,i,true) -- kindofrun, currentrun, final
                            logs.simple("arrange run: %s",command)
                            local returncode, errorstring = os.spawn(command)
                            if not returncode then
                                logs.simple("fatal error, no return code, message: %s",errorstring or "?")
                                os.exit(1)
                            elseif returncode > 0 then
                                logs.simple("fatal error, return code: %s",returncode or "?")
                                os.exit(returncode)
                            end
                        end
                        --
                        if environment.argument("purge") then
                            scripts.context.purge_job(jobname)
                        elseif environment.argument("purgeall") then
                            scripts.context.purge_job(jobname,true)
                        end
                        --
                        os.remove(jobname..".top")
                        --
                        if resultname then
                            for _, suffix in pairs(scripts.context.aftersuffixes) do
                                local oldname = file.addsuffix(oldbase,suffix)
                                local newname = file.addsuffix(newbase,suffix)
                                local tmpname = "keep-"..oldname
                                os.remove(newname)
                                os.rename(oldname,newname)
                                os.rename(tmpname,oldname)
                            end
                            logs.simple("result renamed to: %s",newbase)
                        end
                        --
                        if environment.argument("purge") then
                            scripts.context.purge_job(resultname)
                        elseif environment.argument("purgeall") then
                            scripts.context.purge_job(resultname,true)
                        end
                        --
                        if environment.argument("autopdf") then
                            scripts.context.openpdf(resultname or filename)
                        end
                        --
                        if environment.argument("timing") then
                            logs.line()
                            logs.simple("you can process (timing) statistics with:",jobname)
                            logs.line()
                            logs.simple("context --extra=timing '%s'",jobname)
                            logs.simple("mtxrun --script timing --xhtml [--launch --remove] '%s'",jobname)
                            logs.line()
                        end
                    else
                        if formatname then
                            logs.simple("error, no format found with name: %s, skipping",formatname)
                        else
                            logs.simple("error, no format found (provide formatname or interface)")
                        end
                        break
                    end
                end
            end
        else
            if formatname then
                logs.simple("error, no format found with name: %s, aborting",formatname)
            else
                logs.simple("error, no format found (provide formatname or interface)")
            end
        end
    end
end

function scripts.context.pipe()
    -- context --pipe
    -- context --pipe --purge --dummyfile=whatever.tmp
    local interface = environment.argument("interface")
    interface = (type(interface) == "string" and interface) or "en"
    local formatname = scripts.context.interfaces[interface] or "cont-en"
    local formatfile, scriptfile = resolvers.locate_format(formatname)
    if not formatfile or not scriptfile then
        logs.simple("warning: no format found, forcing remake (commandline driven)")
        scripts.context.generate()
        scripts.context.make(formatname)
        formatfile, scriptfile = resolvers.locate_format(formatname)
    end
    if formatfile and scriptfile then
        local okay = statistics.check_fmt_status(formatfile)
        if okay ~= true then
            logs.simple("warning: %s, forcing remake",tostring(okay))
            scripts.context.generate()
            scripts.context.make(formatname)
        end
        local flags = {
            "--interaction=scrollmode",
            "--fmt=" .. string.quote(formatfile),
            "--lua=" .. string.quote(scriptfile),
            "--backend=pdf",
        }
        local filename = environment.argument("dummyfile") or ""
        if filename == "" then
            filename = "\\relax"
            logs.simple("entering scrollmode, end job with \\end")
        else
            filename = file.addsuffix(filename,"tmp")
            io.savedata(filename,"\\relax")
            scripts.context.multipass.makeoptionfile(filename,{ flags = flags },3,1,false) -- kindofrun, currentrun, final
            logs.simple("entering scrollmode using '%s' with optionfile, end job with \\end",filename)
        end
        local command = string.format("luatex %s %s", table.concat(flags," "), string.quote(filename))
        os.spawn(command)
        if environment.argument("purge") then
            scripts.context.purge_job(filename)
        elseif environment.argument("purgeall") then
            scripts.context.purge_job(filename,true)
            os.remove(filename)
        end
    else
        if formatname then
            logs.simple("error, no format found with name: %s, aborting",formatname)
        else
            logs.simple("error, no format found (provide formatname or interface)")
        end
    end
end

function scripts.context.make(name)
    local runners = {
        "luatools --make --compile ",
        (environment.argument("pdftex") and "mtxrun texexec.rb --make --pdftex ") or false,
        (environment.argument("xetex")  and "mtxrun texexec.rb --make --xetex " ) or false,
    }
    local list = (name and { name }) or (environment.files[1] and environment.files) or scripts.context.defaultformats
    for _, name in ipairs(list) do
        name = scripts.context.interfaces[name] or name
        for _, runner in ipairs(runners) do
            if runner then
                local command = runner .. name
                logs.simple("running command: %s",command)
                os.spawn(command)
            end
        end
    end
end

function scripts.context.generate()
    -- hack, should also be a shared function
    local command = "luatools --generate "
    logs.simple("running command: %s",command)
    os.spawn(command)
end

function scripts.context.ctx()
    local ctxdata = ctxrunner.new()
    ctxdata.jobname = environment.files[1]
    ctxrunner.manipulate(ctxdata,environment.argument("ctx"))
    scripts.context.run(ctxdata)
end

function scripts.context.autoctx()
    local ctxdata = nil
    local files = (filename and { filename }) or environment.files
    local firstfile = #files > 0 and files[1]
    if firstfile and file.extname(firstfile) == "xml" then
        local f = io.open(firstfile)
        if f then
            local chunk = f:read(512) or ""
            f:close()
            local ctxname = string.match(chunk,"<%?context%-directive%s+job%s+ctxfile%s+([^ ]-)%s*?>")
            if ctxname then
                ctxdata = ctxrunner.new()
                ctxdata.jobname = firstfile
                ctxrunner.manipulate(ctxdata,ctxname)
            end
        end
    end
    scripts.context.run(ctxdata)
end

-- todo: quite after first image

local template = [[
    \starttext
        \startMPpage %% %s
            input "%s" ;
        \stopMPpage
    \stoptext
]]

local loaded = false

function scripts.context.metapost()
    local filename = environment.files[1] or ""
--~     local tempname = "mtx-context-metapost.tex"
--~     local tempdata = string.format(template,"metafun",filename)
--~     io.savedata(tempname,tempdata)
--~     environment.files[1] = tempname
--~     environment.setargument("result",file.removesuffix(filename))
--~     environment.setargument("once",true)
--~     scripts.context.run()
    if not loaded then
        dofile(resolvers.find_file("mlib-run.lua"))
        loaded = true
        commands = commands or { }
        commands.writestatus = logs.report
    end
    local formatname = environment.arguments("format") or "metafun"
    if formatname == "" or type(format) == "boolean" then
        formatname = "metafun"
    end
    if environment.arguments("svg") then
        metapost.directrun(formatname,filename,"svg")
    else
        metapost.directrun(formatname,filename,"mps")
    end
end

function scripts.context.version()
    local name = resolvers.find_file("context.tex")
    if name ~= "" then
        logs.simple("main context file: %s",name)
        local data = io.loaddata(name)
        if data then
            local version = data:match("\\edef\\contextversion{(.-)}")
            if version then
                logs.simple("current version: %s",version)
            else
                logs.simple("context version: unknown, no timestamp found")
            end
        else
            logs.simple("context version: unknown, load error")
        end
    else
        logs.simple("main context file: unknown, 'context.tex' not found")
    end
end

local generic_files = {
    "texexec.tex", "texexec.tui", "texexec.tuo",
    "texexec.tuc", "texexec.tua",
    "texexec.ps", "texexec.pdf", "texexec.dvi",
    "cont-opt.tex", "cont-opt.bak"
}

local obsolete_results = {
    "dvi",
}

local temporary_runfiles = {
    "tui", "tua", "tup", "ted", "tes", "top",
    "log", "tmp", "run", "bck", "rlg",
    "mpt", "mpx", "mpd", "mpo", "mpb", "ctl",
    "synctex.gz", "pgf"
}

local persistent_runfiles = {
    "tuo", "tub", "top", "tuc"
}

local function purge_file(dfile,cfile)
    if cfile and lfs.isfile(cfile) then
        if os.remove(dfile) then
            return file.basename(dfile)
        end
    elseif dfile then
        if os.remove(dfile) then
            return file.basename(dfile)
        end
    end
end

function scripts.context.purge_job(jobname,all)
    if jobname and jobname ~= "" then
        jobname = file.basename(jobname)
        local filebase = file.removesuffix(jobname)
        local deleted = { }
        for _, suffix in ipairs(obsolete_results) do
            deleted[#deleted+1] = purge_file(filebase.."."..suffix,filebase..".pdf")
        end
        for _, suffix in ipairs(temporary_runfiles) do
            deleted[#deleted+1] = purge_file(filebase.."."..suffix)
        end
        if all then
            for _, suffix in ipairs(persistent_runfiles) do
                deleted[#deleted+1] = purge_file(filebase.."."..suffix)
            end
        end
        if #deleted > 0 then
            logs.simple("purged files: %s", table.join(deleted,", "))
        end
    end
end

function scripts.context.purge(all)
    local all = all or environment.argument("all")
    local pattern = environment.argument("pattern") or "*.*"
    local files = dir.glob(pattern)
    local obsolete = table.tohash(obsolete_results)
    local temporary = table.tohash(temporary_runfiles)
    local persistent = table.tohash(persistent_runfiles)
    local generic = table.tohash(generic_files)
    local deleted = { }
    for _, name in ipairs(files) do
        local suffix = file.extname(name)
        local basename = file.basename(name)
        if obsolete[suffix] or temporary[suffix] or persistent[suffix] or generic[basename] then
            deleted[#deleted+1] = purge_file(name)
        end
    end
    if #deleted > 0 then
        logs.simple("purged files: %s", table.join(deleted,", "))
    end
end

--~ purge_for_files("test",true)
--~ purge_all_files()

local function touch(name,pattern)
    local name = resolvers.find_file(name)
    local olddata = io.loaddata(name)
    if olddata then
        local oldversion, newversion = "", os.date("%Y.%m.%d %H:%M")
        local newdata, ok = olddata:gsub(pattern,function(pre,mid,post)
            oldversion = mid
            return pre .. newversion .. post
        end)
        if ok > 0 then
            local backup = file.replacesuffix(name,"tmp")
            os.remove(backup)
            os.rename(name,backup)
            io.savedata(name,newdata)
            return true, oldversion, newversion, name
        else
            return false
        end
    end
end

function scripts.context.touch()
    if environment.argument("expert") then
        local done, oldversion, newversion, foundname = touch("context.tex", "(\\edef\\contextversion{)(.-)(})")
        if done then
            logs.simple("old version : %s", oldversion)
            logs.simple("new version : %s", newversion)
            logs.simple("touched file: %s", foundname)
            local ok, _, _, foundname = touch("cont-new.tex", "(\\newcontextversion{)(.-)(})")
            if ok then
                logs.simple("touched file: %s", foundname)
            end
            local ok, _, _, foundname = touch("cont-xp.tex", "(\\edef\\contextversion{)(.-)(})")
            if ok then
                logs.simple("touched file: %s", foundname)
            end
        end
    end
end

-- extras

function scripts.context.extras(pattern)
    local found = resolvers.find_file("context.tex")
    if found == "" then
        logs.simple("unknown extra: %s", extra)
    else
        pattern = file.join(dir.expand_name(file.dirname(found)),string.format("mtx-context-%s.tex",pattern or "*"))
        local list = dir.glob(pattern)
        if not extra or extra == "" then
            logs.extendbanner("extras")
        else
            logs.extendbanner(extra)
        end
        for k,v in ipairs(list) do
            local data = io.loaddata(v) or ""
            data = string.match(data,"begin help(.-)end help")
            if data then
                local h = { string.format("extra: %s (%s)",string.gsub(v,"^.*mtx%-context%-(.-)%.tex$","%1"),v) }
                for s in string.gmatch(data,"%% *(.-)[\n\r]") do
                    h[#h+1] = s
                end
                logs.help(table.concat(h,"\n"),"nomoreinfo")
            end
        end
    end
end

function scripts.context.extra()
    local extra = environment.argument("extra")
    if type(extra) == "string" then
        if environment.argument("help") then
            scripts.context.extras(extra)
        else
            local fullextra = extra
            if not string.find(fullextra,"mtx%-context%-") then
                fullextra = "mtx-context-" .. extra
            end
            local foundextra = resolvers.find_file(fullextra)
            if foundextra == "" then
                scripts.context.extras()
                return
            else
                logs.simple("processing extra: %s", foundextra)
            end
            environment.setargument("purgeall",true)
            local result = environment.setargument("result") or ""
            if result == "" then
                environment.setargument("result","context-extra")
            end
            scripts.context.run(nil,foundextra)
        end
    else
        scripts.context.extras()
    end
end

-- todo: we need to do a dummy run

function scripts.context.track()
    environment.files = { "m-track" }
    scripts.context.multipass.nofruns = 1
    scripts.context.run()
    -- maybe filter from log
end

function scripts.context.timed(action)
    statistics.timed(action)
end

local zipname    = "cont-tmf.zip"
local mainzip    = "http://www.pragma-ade.com/context/latest/" .. zipname
local validtrees = { "texmf-local", "texmf-context" }

function zip.loaddata(zipfile,filename) -- should be in zip lib
    local f = zipfile:open(filename)
    if f then
        local data = f:read("*a")
        f:close()
        return data
    end
    return nil
end

function scripts.context.update()
    local force = environment.argument("force")
    local socket = require("socket")
    local http   = require("socket.http")
    local basepath = resolvers.find_file("context.tex") or ""
    if basepath == "" then
        logs.simple("quiting, no 'context.tex' found")
        return
    end
    local basetree = basepath.match(basepath,"^(.-)tex/context/base/context.tex$") or ""
    if basetree == "" then
        logs.simple("quiting, no proper tds structure (%s)",basepath)
        return
    end
    local function is_okay(basetree)
        for _, tree in next, validtrees do
            local pattern = string.gsub(tree,"%-","%%-")
            if basetree:find(pattern) then
                return tree
            end
        end
        return false
    end
    local okay = is_okay(basetree)
    if not okay then
        logs.simple("quiting, tree '%s' is protected",okay)
        return
    else
        logs.simple("updating tree '%s'",okay)
    end
    if not lfs.chdir(basetree) then
        logs.simple("quiting, unable to change to '%s'",okay)
        return
    end
    logs.simple("fetching '%s'",mainzip)
    local latest = http.request(mainzip)
    if not latest then
        logs.simple("context tree '%s' can be updated, use --force",okay)
        return
    end
    io.savedata("cont-tmf.zip",latest)
    if false then
        -- variant 1
        os.execute("mtxrun --script unzip cont-tmf.zip")
    else
        -- variant 2
        local zipfile = zip.open(zipname)
        if not zipfile then
            logs.simple("quiting, unable to open '%s'",zipname)
            return
        end
        local newfile = zip.loaddata(zipfile,"tex/context/base/context.tex")
        if not newfile then
            logs.simple("quiting, unable to open '%s'","context.tex")
            return
        end
        local oldfile = io.loaddata(resolvers.find_file("context.tex")) or ""
        local function versiontonumber(what,str)
            local version = str:match("\\edef\\contextversion{(.-)}") or ""
            local year, month, day, hour, minute = str:match("\\edef\\contextversion{(%d+)%.(%d+)%.(%d+) *(%d+)%:(%d+)}")
            if year and minute then
                local time = os.time { year=year,month=month,day=day,hour=hour,minute=minute}
                logs.simple("%s version: %s (%s)",what,version,time)
                return time
            else
                logs.simple("%s version: %s (unknown)",what,version)
                return nil
            end
        end
        local oldversion = versiontonumber("old",oldfile)
        local newversion = versiontonumber("new",newfile)
        if not oldversion or not newversion then
            logs.simple("quiting, version cannot be determined")
            return
        elseif oldversion == newversion then
            logs.simple("quiting, your current version is up-to-date")
            return
        elseif oldversion > newversion then
            logs.simple("quiting, your current version is newer")
            return
        end
        for k in zipfile:files() do
            local filename = k.filename
            if filename:find("/$") then
                lfs.mkdir(filename)
            else
                local data = zip.loaddata(zipfile,filename)
                if data then
                    if force then
                        io.savedata(filename,data)
                    end
                    logs.simple(filename)
                end
            end
        end
        for _, scriptname in next, { "luatools.lua", "mtxrun.lua" } do
            local oldscript = resolvers.find_file(scriptname) or ""
            if oldscript ~= "" and is_okay(oldscript) then
                local newscript = "./scripts/context/lua/" .. scriptname
                local data = io.loaddata(newscript) or ""
                if data ~= "" then
                    logs.simple("replacing script '%s' by '%s'",oldscript,newscript)
                    if force then
                        io.savedata(oldscript,data)
                    end
                end
            else
                logs.simple("keeping script '%s'",oldscript)
            end
        end
        if force then
            os.execute("context --generate")
            os.execute("context --make")
        end
    end
    if force then
        logs.simple("context tree '%s' has been updated",okay)
    else
        logs.simple("context tree '%s' can been updated (use --force)",okay)
    end
end

logs.extendbanner("ConTeXt Tools 0.51",true)

messages.help = [[
--run                 process (one or more) files (default action)
--make                create context formats
--generate            generate file database etc.
--ctx=name            use ctx file
--version             report installed context version
--forcexml            force xml stub (optional flag: --mkii)
--forcecld            force cld (context lua document) stub
--autopdf             close pdf file in viewer and start pdf viewer afterwards
--once                only one run
--purge(all)          purge files (--pattern=...)
--result=name         rename result to given name
--arrange             run extra arrange pass
--noarrange           ignore arrange commands in the file
--batchmode           run without stopping and don't show messages on the console
--nonstopmode         run without stopping
--usemodule=list      load the given module (or style)
--environment=list    load the given file first
--mode=list           enable given the mode(s)
--path=list           also consult the given paths when files are looked for
--paranoid            don't descend to .. and ../..
--randomseed=number   set the randomseed
--arguments=list      set variables that can be consulted during a run (key/value pairs)
--interface           use specified user interface

--expert              expert options
]]

-- filter=list      is kind of obsolete
-- color            is obsolete for mkiv, always on
-- separation       is obsolete for mkiv, no longer available
-- output           is currently obsolete for mkiv
-- setuppath=list   must check
-- modefile=name    must check
-- inputfile=name   load the given inputfile (must check)

messages.expert = [[
expert options:

--touch               update context version number (remake needed afterwards, also provide --expert)
--nostats             omit runtime statistics at the end of the run
--update              update context from website (not to be confused with contextgarden)
--profile             profile job (use: mtxrun --script profile --analyse)
--track               show/set tracker variables
--timing              generate timing and statistics overview
--extra=name          process extra (mtx-context-<name> in distribution)
--tracefiles          show some extra info when locating files (at the tex end)
--randomseed
]]

messages.private = [[
private options:

--dumphash            dump hash table afterwards
--dumpdelta           dump hash table afterwards (only new entries)
]]

messages.special = [[
special options:

--pdftex              process file with texexec using pdftex
--xetex               process file with texexec using xetex

--pipe                don't check for file and enter scroll mode (--dummyfile=whatever.tmp)
]]

if environment.argument("once") then
    scripts.context.multipass.nofruns = 1
end

if environment.argument("profile") then
    os.setenv("MTX_PROFILE_RUN","YES")
end

if environment.argument("run") then
--  scripts.context.timed(scripts.context.run)
    scripts.context.timed(scripts.context.autoctx)
elseif environment.argument("make") or environment.argument("generate") then
    scripts.context.timed(function()
        if environment.argument("generate") then
            scripts.context.generate()
        end
        if environment.argument("make") then
            scripts.context.make()
        end
    end)
elseif environment.argument("ctx") then
    scripts.context.timed(scripts.context.ctx)
elseif environment.argument("mp") or environment.argument("metapost") then
    scripts.context.timed(scripts.context.metapost)
elseif environment.argument("version") then
    scripts.context.version()
elseif environment.argument("touch") then
    scripts.context.touch()
elseif environment.argument("update") then
    scripts.context.update()
elseif environment.argument("expert") then
    logs.help(table.join({ messages.expert, messages.private, messages.special },"\n"))
elseif environment.argument("extra") then
    scripts.context.extra()
elseif environment.argument("help") then
    logs.help(messages.help)
elseif environment.argument("track") and type(environment.argument("track"))  == "boolean" then
    scripts.context.track()
elseif environment.files[1] then
--  scripts.context.timed(scripts.context.run)
    scripts.context.timed(scripts.context.autoctx)
elseif environment.argument("pipe") then
    scripts.context.timed(scripts.context.pipe)
elseif environment.argument("purge") then
    -- only when no filename given, supports --pattern
    scripts.context.purge()
elseif environment.argument("purgeall") then
    -- only when no filename given, supports --pattern
    scripts.context.purge(true)
else
    logs.help(messages.help)
end

if environment.argument("profile") then
    os.setenv("MTX_PROFILE_RUN","NO")
end
