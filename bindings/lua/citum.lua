-- Citum LuaJIT Binding
-- This module provides a high-level Lua interface to the Citum Rust processor.

local ffi = require("ffi")

ffi.cdef[[
    typedef struct Processor Processor;

    Processor* citum_processor_new(const char* style_json, const char* bib_json);
    Processor* citum_processor_new_with_locale(const char* style_json, 
        const char* bib_json, const char* locale_json);
    
    Processor* citum_processor_new_from_yaml(const char* style_yaml_path, 
        const char* bib_yaml_path);
    Processor* citum_processor_new_from_bib(const char* style_yaml_path, 
        const char* bib_path);

    void citum_processor_free(Processor* processor);

    char* citum_render_citation_latex(Processor* processor, const char* cite_json);
    char* citum_render_citation_html(Processor* processor, const char* cite_json);
    char* citum_render_citation_plain(Processor* processor, const char* cite_json);

    char* citum_render_bibliography_latex(Processor* processor);
    char* citum_render_bibliography_html(Processor* processor);
    char* citum_render_bibliography_plain(Processor* processor);

    void citum_string_free(char* s);
]]

local CITUM = {}
CITUM.__index = CITUM

local function get_lib_filename()
    local os_name = "Linux"
    if ffi.os == "OSX" then os_name = "OSX" end
    if ffi.os == "Windows" then os_name = "Windows" end

    if os_name == "OSX"     then return "libcitum_processor.dylib" end
    if os_name == "Windows" then return "citum_engine.dll" end
    return "libcitum_processor.so"
end

local function load_lib()
    local env_path = os.getenv("CITUM_LIB_PATH")
    if env_path and env_path ~= "" then
        return ffi.load(env_path)
    end
    
    local name = get_lib_filename()
    local ok, lib = pcall(ffi.load, name)
    if ok then return lib end
    
    -- Fallback: check current directory or standard paths
    local ok, lib = pcall(ffi.load, "./" .. name)
    if ok then return lib end
    
    error("Could not load Citum shared library (" .. name .. "). "
      .. "Set CITUM_LIB_PATH to the absolute path of the library.")
end

local lib = load_lib()

local function to_lua_string(c_str)
    if c_str == nil then return nil end
    local s = ffi.string(c_str)
    lib.citum_string_free(c_str)
    return s
end

--- Create a new Citum processor from JSON strings.
function CITUM.new(style_json, bib_json)
    local self = setmetatable({}, CITUM)
    self.ptr = lib.citum_processor_new(style_json, bib_json)
    if self.ptr == nil then return nil, "Failed to initialise Citum processor" end
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Create a processor from Citum YAML files on disk (primary format).
function CITUM.from_yaml(style_path, bib_path)
    local self = setmetatable({}, CITUM)
    self.ptr = lib.citum_processor_new_from_yaml(style_path, bib_path)
    if self.ptr == nil then 
        return nil, "Failed to initialise Citum processor from YAML files: " 
          .. style_path .. ", " .. bib_path
    end
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Create a processor from a Citum YAML style and a biblatex .bib file.
function CITUM.from_bib(style_path, bib_path)
    local self = setmetatable({}, CITUM)
    self.ptr = lib.citum_processor_new_from_bib(style_path, bib_path)
    if self.ptr == nil then 
        return nil, "Failed to initialise Citum processor from .bib file: " 
          .. bib_path
    end
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

function CITUM:free()
    if self.ptr then
        local ptr = self.ptr
        self.ptr = nil
        lib.citum_processor_free(ptr)
    end
end

function CITUM:render_citation(opts)
    local cite_json = ""
    if type(opts) == "string" then
        cite_json = '{"items":[{"id":"' .. opts .. '"}]}'
    else
        -- Simple JSON serialisation for common fields
        -- In a real app, use a proper Lua JSON library
        local items = {}
        for _, item in ipairs(opts.items or {}) do
            local parts = {'"id":"' .. item.id .. '"'}
            if item.label then table.insert(parts, '"label":"' .. item.label .. '"') end
            if item.locator then table.insert(parts, '"locator":"' .. item.locator .. '"') end
            if item.prefix then table.insert(parts, '"prefix":"' .. item.prefix .. '"') end
            if item.suffix then table.insert(parts, '"suffix":"' .. item.suffix .. '"') end
            table.insert(items, "{" .. table.concat(parts, ",") .. "}")
        end
        
        local root = {'"items":[' .. table.concat(items, ",") .. ']'}
        if opts.mode then table.insert(root, '"mode":"' .. opts.mode .. '"') end
        if opts.prefix then table.insert(root, '"prefix":"' .. opts.prefix .. '"') end
        if opts.suffix then table.insert(root, '"suffix":"' .. opts.suffix .. '"') end
        
        cite_json = "{" .. table.concat(root, ",") .. "}"
    end

    local c_str = lib.citum_render_citation_latex(self.ptr, cite_json)
    if c_str == nil then
        io.stderr:write("citum: render_citation returned NULL for JSON: " 
          .. cite_json .. "\n")
        return "[citum render error]"
    end
    return to_lua_string(c_str)
end

function CITUM:render_citation_html(opts)
    -- Same JSON logic as above...
    local cite_json = '{"items":[{"id":"' .. (type(opts) == "string" and opts or opts.items[1].id) .. '"}]}'
    return to_lua_string(lib.citum_render_citation_html(self.ptr, cite_json))
end

function CITUM:render_citation_plain(opts)
    local cite_json = '{"items":[{"id":"' .. (type(opts) == "string" and opts or opts.items[1].id) .. '"}]}'
    return to_lua_string(lib.citum_render_citation_plain(self.ptr, cite_json))
end

function CITUM:render_bibliography()
    return to_lua_string(lib.citum_render_bibliography_latex(self.ptr))
end

function CITUM:render_bibliography_html()
    return to_lua_string(lib.citum_render_bibliography_html(self.ptr))
end

function CITUM:render_bibliography_plain()
    return to_lua_string(lib.citum_render_bibliography_plain(self.ptr))
end

--- Map of biblatex optional-argument prefixes to Citum LocatorType strings.
CITUM.locator_labels = {
    ["p."]    = "page",
    ["pp."]   = "page",
    ["ch."]   = "chapter",
    ["vol."]  = "volume",
    ["sect."] = "section",
    ["§"]     = "section",
}

--- Infer a Citum locator label and value from a raw biblatex optional-arg string.
function CITUM.parse_locator(s)
    if not s or s == "" then return nil, nil end
    
    for prefix, label in pairs(CITUM.locator_labels) do
        if s:sub(1, #prefix) == prefix then
            local val = s:sub(#prefix + 1):gsub("^%s+", "")
            return label, val
        end
    end
    
    -- Default to page if it looks like a number
    if s:match("^%d") then
        return "page", s
    end
    
    return nil, s
end

-- Helper for the LaTeX package
function CITUM.do_cite(proc, cite_opts)
    if not proc then 
        tex.sprint("[citum: processor not initialised]")
        return 
    end
    local ok, res = pcall(function() return proc:render_citation(cite_opts) end)
    if ok then
        tex.sprint(res)
    else
        tex.sprint("[citum: render error]")
    end
end

function CITUM.split_keys(s)
    local keys = {}
    for k in s:gmatch("([^,%s]+)") do
        table.insert(keys, k)
    end
    return keys
end

CITUM.cites_items = {}

function CITUM.cites_start()
    CITUM.cites_items = {}
end

function CITUM.cites_add(raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    table.insert(CITUM.cites_items, item)
end

function CITUM.cites_flush(proc)
    CITUM.do_cite(proc, { items = CITUM.cites_items })
end

function CITUM.cites_flush_integral(proc)
    CITUM.do_cite(proc, { mode = "integral", items = CITUM.cites_items })
end

function CITUM.cite_single(proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.do_cite(proc, { items = { item } })
end

function CITUM.textcite_single(proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.do_cite(proc, { mode = "integral", items = { item } })
end

function CITUM.cite_keys(proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.do_cite(proc, { items = items })
end

function CITUM.textcite_keys(proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.do_cite(proc, { mode = "integral", items = items })
end

function CITUM.init_processor(style_opt, bibfile)
    local style_path = style_opt
    local bib_path = bibfile
    
    local proc, err
    if bib_path:match("%.bib$") then
        proc, err = CITUM.from_bib(style_path, bib_path)
    else
        proc, err = CITUM.from_yaml(style_path, bib_path)
    end
    
    if not proc then
        error("citum: failed to init processor. " .. tostring(err))
    end
    return proc
end

function CITUM.print_bibliography(proc)
    if not proc then 
        tex.sprint("[citum: processor not initialised]")
        return 
    end
    local ok, res = pcall(function() return proc:render_bibliography() end)
    if ok then
        tex.sprint(res)
    else
        tex.sprint("[citum: bibliography render error]")
    end
end

return CITUM
