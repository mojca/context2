if not modules then modules = { } end modules ['mtx-install'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: initial install from zip

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-install</entry>
  <entry name="detail">ConTeXt Installer</entry>
  <entry name="version">2.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="platform" value="string"><short>platform (windows, linux, linux-64, osx-intel, osx-ppc, linux-ppc)</short></flag>
    <flag name="server" value="string"><short>repository url (rsync://contextgarden.net)</short></flag>
    <flag name="modules" value="string"><short>extra modules (can be list or 'all')</short></flag>
    <flag name="fonts" value="string"><short>additional fonts (can be list or 'all')</short></flag>
    <flag name="goodies" value="string"><short>extra binaries (like scite and texworks)</short></flag>
    <flag name="install"><short>install context</short></flag>
    <flag name="update"><short>update context</short></flag>
    <flag name="identify"><short>create list of files</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local gsub, find, escapedpattern = string.gsub, string.find, string.escapedpattern
local round = math.round
local savetable, loadtable, sortedhash = table.save, table.load, table.sortedhash
local joinfile, filesize, dirname, addsuffix = file.join, file.size, file.dirname, file.addsuffix
local isdir, isfile, walkdir = lfs.isdir, lfs.isfile, lfs.dir
local mkdirs, globdir = dir.mkdirs, dir.glob
local osremove, osexecute, ostype = os.remove, os.execute, os.type
local savedata = io.savedata
local formatters = string.formatters

local fetch = socket.http.request

local application = logs.application {
    name     = "mtx-install",
    banner   = "ConTeXt Installer 2.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.install = scripts.install or { }
local install   = scripts.install

local texformats = {
    "cont-en",
    "cont-nl",
    "cont-cz",
    "cont-de",
    "cont-fa",
    "cont-it",
    "cont-ro",
    "cont-uk",
    "cont-pe",
}

local platforms = {
    ["mswin"]          = "mswin",
    ["windows"]        = "mswin",
    ["win32"]          = "mswin",
    ["win"]            = "mswin",
    --
    ["mswin-64"]       = "win64",
    ["windows-64"]     = "win64",
    ["win64"]          = "win64",
    --
    ["linux"]          = "linux",
    ["linux-32"]       = "linux",
    ["linux32"]        = "linux",
    --
    ["linux-64"]       = "linux-64",
    ["linux64"]        = "linux-64",
    --
    ["linuxmusl-64"]   = "linuxmusl-64",
    --
    ["linux-armhf"]    = "linux-armhf",
    --
    ["freebsd"]        = "freebsd",
    --
    ["freebsd-amd64"]  = "freebsd-amd64",
    --
    ["kfreebsd"]       = "kfreebsd-i386",
    ["kfreebsd-i386"]  = "kfreebsd-i386",
    --
    ["kfreebsd-amd64"] = "kfreebsd-amd64",
    --
    ["linux-ppc"]      = "linux-ppc",
    ["ppc"]            = "linux-ppc",
    --
    ["osx"]            = "osx-intel",
    ["macosx"]         = "osx-intel",
    ["osx-intel"]      = "osx-intel",
    ["osxintel"]       = "osx-intel",
    --
    ["osx-ppc"]        = "osx-ppc",
    ["osx-powerpc"]    = "osx-ppc",
    ["osxppc"]         = "osx-ppc",
    ["osxpowerpc"]     = "osx-ppc",
    --
    ["osx-64"]         = "osx-64",
    --
    ["solaris-intel"]  = "solaris-intel",
    --
    ["solaris-sparc"]  = "solaris-sparc",
    ["solaris"]        = "solaris-sparc",
    --
    ["unknown"]        = "unknown",
}

function install.identify()

    -- We have to be in "...../tex" where subdirectories are prefixed with
    -- "texmf". We strip the "tex/texm*/" from the name in the list.

    local function collect(root,tree)

        local path = root .. "/" .. tree

        if isdir(path) then

            local prefix  = path .. "/"
            local files   = globdir(prefix .. "**")
            local pattern = escapedpattern("^" .. prefix)

            local details = { }
            local total   = 0

            for i=1,#files do
                local name = files[i]
                local size = filesize(name)
                local base = gsub(name,pattern,"")
                local stamp = md5.hex(io.loaddata(name))
                details[i] = { base, size, stamp }
                total = total + size
            end
            report("%-20s : %4i files, %3.0f MB",tree,#files,total/(1000*1000))

            savetable(path .. ".tma",details)

        end

    end

    local sourceroot = file.join(dir.current(),"tex")

    for d in walkdir("./tex") do
        if find(d,"%texmf") then
            collect(sourceroot,d)
        end
    end

end

function install.update()

    local function validdir(d)
        local ok = isdir(d)
        if not ok then
            mkdirs(d)
            ok = isdir(d)
        end
        return ok
    end

    local function download(what,url,target,total,done)
        local data = fetch(url .. "/" .. target)
        if data then
            if total and done then
                report("%-8s : %3i %% : %8i : %s",what,round(100*done/total),#data,target)
            else
                report("%-8s : %8i : %s",what,#data,target)
            end
            if validdir(dirname(target)) then
                savedata(target,data)
            else
                -- message
            end
        end
    end

    local function remove(what,target)
        report("%-8s : %8i : %s",what,filesize(target),target)
        osremove(target)
    end

    local function ispresent(target)
        return isfile(target)
    end

    local function hashed(list)
        local hash = { }
        for i=1,#list do
            local l = list[i]
            hash[l[1]] = l
        end
        return hash
    end

    local function run(fmt,...)
        local command = formatters[fmt](...)
     -- command = gsub(command,"/","\\")
        report("running: %s",command)
        osexecute(command)
    end

    local function prepare(tree)
        tree = joinfile("tex",tree)
        mkdirs(tree)
    end

    local function update(url,tree)

        tree = joinfile("tex",tree)

        local ok = validdir(tree)
        if not validdir(tree) then
            report("invalid directory %a",tree)
            return
        end

        local lua = tree .. ".tma"
        local all = url .. "/" .. lua
        local old = loadtable(lua)
        local new = fetch(all)

        if new then
            new = loadstring(new)
            if new then
                new = new()
            end
        end

        if not new then
            report("invalid database %a",all)
            return
        end

        local total = 0
        local done  = 0

        if not old then

            report("installing %s, %i files",tree,#new)

            for i=1,#new do
                total = total + new[i][2]
            end

            for i=1,#new do
                local entry  = new[i]
                local name   = entry[1]
                local size   = entry[2]
                local target = joinfile(tree,name)
                done = done + size
                download("new",url,target,total,done)
            end

        else

            report("updating %s, %i files",tree,#new)

            local hold = hashed(old)
            local hnew = hashed(new)
            local todo = { }

            for newname, newhash in sortedhash(hnew) do
                local target  = joinfile(tree,newname)
                local oldhash = hold[newname]
                local action  = nil
                if not oldhash then
                    action = "added"
                elseif oldhash[3] ~= newhash[3] then
                    action = "changed"
                elseif not ispresent(joinfile(tree,newname)) then
                    action = "missing"
                end
                if action then
                    local size = newhash[2]
                    total = total + size
                    todo[#todo+1] = { action, target, size }
                end
            end

            for i=1,#todo do
                local entry = todo[i]
                download(entry[1],url,entry[2],total,done)
                done = done + entry[3]
            end

            for oldname, oldhash in sortedhash(hold) do
                local newhash = hnew[oldname]
                local target  = joinfile(tree,oldname)
                if not newhash and ispresent(target) then
                    remove("removed",target)
                end
            end

        end

        savetable(lua,new)

    end

    local targetroot = dir.current()

    local server   = environment.arguments.server   or ""
    local port     = environment.arguments.port     or ""
    local instance = environment.arguments.instance or ""

    if server == "" then
        report("provide server")
        return
    end

    local url = "http://" .. server

    if port ~= "" then
        url = url .. ":" .. port
    end

    url = url .. "/"

    if instance ~= "" then
        url = url .. instance .. "/"
    end

    local osplatform = os.platform
    local platform   = platforms[osplatform]

    if not platform then
        report("unknown platform")
        return
    end

    local texmfplatform = "texmf-" .. platform

    report("server   : %s",server)
    report("port     : %s",port == "" and 80 or "80")
    report("instance : %s",instance)
    report("platform : %s",osplatform)
    report("system   : %s",ostype)

    update(url,"texmf")
    update(url,"texmf-context")
    update(url,texmfplatform)

    prepare("texmf-cache")
    prepare("texmf-project")
    prepare("texmf-fonts")
    prepare("texmf-local")
    prepare("texmf-modules")

    local binpath = joinfile(targetroot,"tex",texmfplatform,"bin")

    if ostype == "unix" then
        osexecute(formatters["chmod +x %s/*"](binpath))
    end

    local mtxrun  = joinfile(binpath,"mtxrun")
    local context = joinfile(binpath,"context")

    if ostype == "windows" then
        addsuffix(mtxrun,"exe")
        addsuffix(context,"exe")
    end

    run("%s --generate",mtxrun)
    run("%s --make en", context)
    run("%s --make nl", context)

 -- local mtxrun  = joinfile(binpath,"mtxrunjit")
 -- local context = joinfile(binpath,"contextjit")
 --
 -- if ostype == "windows" then
 --     addsuffix(mtxrun,"exe")
 --     addsuffix(context,"exe")
 -- end
 --
 -- run("%s --generate",mtxrun)
 -- run("%s --make en", context)
 -- run("%s --make nl", context)

    -- in calling script: update mtxrun.exe and mtxrun.lua

    report("update, done")
end

if environment.argument("identify") then
    install.identify()
elseif environment.argument("install") then
    install.update()
elseif environment.argument("update") then
    install.update()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
