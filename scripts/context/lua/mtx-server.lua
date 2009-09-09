if not modules then modules = { } end modules ['mtx-server'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen & Taco Hoekwater",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

scripts           = scripts           or { }
scripts.webserver = scripts.webserver or { }

dofile(resolvers.find_file("l-url.lua","tex"))
dofile(resolvers.find_file("luat-soc.lua","tex"))

local socket = socket or require("socket") -- redundant in future version
local format = string.format

-- The following two lists are taken from webrick (ruby) and
-- extended with a few extra suffixes.

local mimetypes = {
    ai    = 'application/postscript',
    asc   = 'text/plain',
    avi   = 'video/x-msvideo',
    bin   = 'application/octet-stream',
    bmp   = 'image/bmp',
    bz2   = 'application/x-bzip2',
    cer   = 'application/pkix-cert',
    class = 'application/octet-stream',
    crl   = 'application/pkix-crl',
    crt   = 'application/x-x509-ca-cert',
    css   = 'text/css',
    dms   = 'application/octet-stream',
    doc   = 'application/msword',
    dvi   = 'application/x-dvi',
    eps   = 'application/postscript',
    etx   = 'text/x-setext',
    exe   = 'application/octet-stream',
    gif   = 'image/gif',
    gz    = 'application/x-tar',
    hqx   = 'application/mac-binhex40',
    htm   = 'text/html',
    html  = 'text/html',
    jpe   = 'image/jpeg',
    jpeg  = 'image/jpeg',
    jpg   = 'image/jpeg',
    lha   = 'application/octet-stream',
    lzh   = 'application/octet-stream',
    mov   = 'video/quicktime',
    mpe   = 'video/mpeg',
    mpeg  = 'video/mpeg',
    mpg   = 'video/mpeg',
    pbm   = 'image/x-portable-bitmap',
    pdf   = 'application/pdf',
    pgm   = 'image/x-portable-graymap',
    png   = 'image/png',
    pnm   = 'image/x-portable-anymap',
    ppm   = 'image/x-portable-pixmap',
    ppt   = 'application/vnd.ms-powerpoint',
    ps    = 'application/postscript',
    qt    = 'video/quicktime',
    ras   = 'image/x-cmu-raster',
    rb    = 'text/plain',
    rd    = 'text/plain',
    rgb   = 'image/x-rgb',
    rtf   = 'application/rtf',
    sgm   = 'text/sgml',
    sgml  = 'text/sgml',
    snd   = 'audio/basic',
    tar   = 'application/x-tar',
    tgz   = 'application/x-tar',
    tif   = 'image/tiff',
    tiff  = 'image/tiff',
    txt   = 'text/plain',
    xbm   = 'image/x-xbitmap',
    xls   = 'application/vnd.ms-excel',
    xml   = 'text/xml',
    xpm   = 'image/x-xpixmap',
    xwd   = 'image/x-xwindowdump',
    zip   = 'application/zip',
}

local messages = {
    [100] = 'Continue',
    [101] = 'Switching Protocols',
    [200] = 'OK',
    [201] = 'Created',
    [202] = 'Accepted',
    [203] = 'Non-Authoritative Information',
    [204] = 'No Content',
    [205] = 'Reset Content',
    [206] = 'Partial Content',
    [300] = 'Multiple Choices',
    [301] = 'Moved Permanently',
    [302] = 'Found',
    [303] = 'See Other',
    [304] = 'Not Modified',
    [305] = 'Use Proxy',
    [307] = 'Temporary Redirect',
    [400] = 'Bad Request',
    [401] = 'Unauthorized',
    [402] = 'Payment Required',
    [403] = 'Forbidden',
    [404] = 'Not Found',
    [405] = 'Method Not Allowed',
    [406] = 'Not Acceptable',
    [407] = 'Proxy Authentication Required',
    [408] = 'Request Timeout',
    [409] = 'Conflict',
    [410] = 'Gone',
    [411] = 'Length Required',
    [412] = 'Precondition Failed',
    [413] = 'Request Entity Too Large',
    [414] = 'Request-URI Too Large',
    [415] = 'Unsupported Media Type',
    [416] = 'Request Range Not Satisfiable',
    [417] = 'Expectation Failed',
    [500] = 'Internal Server Error',
    [501] = 'Not Implemented',
    [502] = 'Bad Gateway',
    [503] = 'Service Unavailable',
    [504] = 'Gateway Timeout',
    [505] = 'HTTP Version Not Supported',
}

local handlers = { }

local function errormessage(client,configuration,n)
    local data = format("<head><title>%s %s</title></head><html><h2>%s %s</h2></html>",n,messages[n],n,messages[n])
    logs.simple("handling error %s: %s",n,messages[n])
    handlers.generic(client,configuration,data,nil,true)
end

local validpaths, registered = { }, { }

function scripts.webserver.registerpath(name)
    if not registered[name] then
        local cleanname = string.gsub(name,"%.%.","deleted-parent")
        logs.simple("registering path '%s'",cleanname)
        validpaths[#validpaths+1] = cleanname
        registered[name] = true
    end
end

function handlers.generic(client,configuration,data,suffix,iscontent)
    if not iscontent then
        local name = data
        logs.simple("requested file '%s'",name)
        local fullname = file.join(configuration.root,name)
        data = io.loaddata(fullname) or ""
        if data == "" then
            for n=1,#validpaths do
                local fullname = file.join(validpaths[n],name)
                data = io.loaddata(fullname) or ""
                if data ~= "" then
                    logs.simple("sending generic file '%s'",fullname)
                    break
                end
            end
        else
            logs.simple("sending generic file '%s'",fullname)
        end
    end
    if data and data ~= "" then
        client:send("HTTP/1.1 200 OK\r\n")
        client:send("Connection: close\r\n")
        client:send(format("Content-Length: %s\r\n",#data))
        client:send(format("Content-Type: %s\r\n",(suffix and mimetypes[suffix]) or "text/html"))
        client:send("\r\n")
        client:send(data)
        client:send("\r\n")
    else
        errormessage(client,configuration,404)
    end
end

--~ return os.date()

--~ return { content = "crap" }

--~ return function(configuration,filename)
--~     return { content = filename }
--~ end

local loaded = { }

function handlers.lua(client,configuration,filename,suffix,iscontent,hashed) -- filename will disappear, and become hashed.filename
    local filename = file.join(configuration.scripts,filename)
    if not file.is_qualified_path(filename) then
        filename = file.join(configuration.root,filename)
    end
    -- todo: split url in components, see l-url; rather trivial
    local result, keep = loaded[filename], false
    if result then
        logs.simple("reusing script: %s",filename)
    else
        logs.simple("locating script: %s",filename)
        if lfs.isfile(filename) then
            logs.simple("loading script: %s",filename)
            result = loadfile(filename)
            logs.simple("return type: %s",type(result))
            if result and type(result) == "function" then
             -- result() should return a table { [type=,] [length=,] content= }, function or string
                result, keep = result()
                if keep then
                    logs.simple("saving script: %s",type(result))
                    loaded[filename] = result
                end
            end
        else
            errormessage(client,configuration,404)
        end
    end
    if result then
        if type(result) == "function" then
            result = result(configuration,filename,hashed) -- second argument will become query
        end
        if result and type(result) == "string" then
            result = { content = result }
        end
        if result and type(result) == "table" then
            if result.content then
                local suffix = result.type or "text/html"
                local action = handlers[suffix] or handlers.generic
                action(client,configuration,result.content,suffix,true) -- content
            elseif result.filename then
                local suffix = file.extname(result.filename) or "text/html"
                local action = handlers[suffix] or handlers.generic
                action(client,configuration,result.filename,suffix,false) -- filename
            else
                errormessage(client,configuration,404)
            end
        else
            errormessage(client,configuration,500)
        end
    else
        errormessage(client,configuration,404)
    end
end

handlers.luc  = handlers.lua
handlers.html = handlers.htm

local indices    = { "index.htm", "index.html" }
local portnumber = 31415 -- pi suits tex

function scripts.webserver.run(configuration)
    -- check configuration
    configuration.port = tonumber(configuration.port or os.getenv("MTX_SERVER_PORT") or portnumber) or portnumber
    if not configuration.root or not lfs.isdir(configuration.root) then
        configuration.root = os.getenv("MTX_SERVER_ROOT") or "."
    end
    -- locate root and index file in tex tree
    if not lfs.isdir(configuration.root) then
        for _, name in ipairs(indices) do
            local root = resolvers.resolve("path:" .. name) or ""
            if root ~= "" then
                configuration.root = root
                configuration.index = configuration.index or name
                break
            end
        end
    end
    configuration.root = dir.expand_name(configuration.root)
    if not configuration.index then
        for _, name in ipairs(indices) do
            if lfs.isfile(file.join(configuration.root,name)) then
                configuration.index = name -- we will prepend the rootpath later
                break
            end
        end
        configuration.index = configuration.index or "unknown"
    end
    if not configuration.scripts or configuration.scripts == "" then
        configuration.scripts = dir.expand_name(file.join(configuration.root or ".",configuration.scripts or "."))
    end
    -- so far for checks
    logs.simple("running at port: %s",configuration.port)
    logs.simple("document root: %s",configuration.root or resolvers.ownpath)
    logs.simple("main index file: %s",configuration.index)
    logs.simple("scripts subpath: %s",configuration.scripts)
    logs.simple("context services: http://localhost:%s/mtx-server-ctx-startup.lua",configuration.port)
    local server = assert(socket.bind("*", configuration.port))
--~ local reading = { server }
    while true do -- no multiple clients
        local start = os.clock()
--~ local input = socket.select(reading)
--~ local client = input:accept()
        local client = server:accept()
        client:settimeout(configuration.timeout or 60)
        local request, e = client:receive()
        if e then
            errormessage(client,configuration,404)
        else
            local from = client:getpeername()
            logs.simple("request from: %s",tostring(from))
            local fullurl = request:match("GET (.+) HTTP/.*$") -- todo: more clever
            fullurl = socket.url.unescape(fullurl)
            local hashed = url.hashed(fullurl)
            local query = url.query(hashed.query)
            local filename = hashed.path
            if filename then
                filename = socket.url.unescape(filename)
                logs.simple("requested action: %s",filename)
                if filename:find("%.%.") then
                    filename = nil -- invalid path
                end
                if filename == nil or filename == "" or filename == "/" then
                    filename = configuration.index
                    logs.simple("invalid filename, forcing: %s",filename)
                end
                local suffix = file.extname(filename)
                local action = handlers[suffix] or handlers.generic
                if action then
                    logs.simple("performing action: %s",filename)
                    action(client,configuration,filename,suffix,false,hashed) -- filename and no content
                else
                    errormessage(client,configuration,404)
                end
            else
                errormessage(client,configuration,404)
            end
        end
        client:close()
        logs.simple("time spent with client: %0.03f seconds",os.clock()-start)
    end
end

logs.extendbanner("Simple Webserver 0.10")

messages.help = [[
--start               start server
--port                port to listen to
--root                server root
--scripts             scripts sub path
--index               index file
--auto                start on own path
]]

if environment.argument("auto") then
    local path = resolvers.find_file("mtx-server.lua") or "."
    scripts.webserver.run {
        port    = environment.argument("port"),
        root    = environment.argument("root") or file.dirname(path) or ".",
        scripts = environment.argument("scripts") or file.dirname(path) or ".",
    }
elseif environment.argument("start") then
    scripts.webserver.run {
        port    = environment.argument("port"),
        root    = environment.argument("root") or ".",           -- "e:/websites/www.pragma-ade.com",
        index   = environment.argument("index"),
        scripts = environment.argument("scripts"),
    }
else
    logs.help(messages.help)
end


-- mtxrun --script server --start => http://localhost:8080/mtx-server-ctx-help.lua