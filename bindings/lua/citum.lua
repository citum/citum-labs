-- Citum LuaJIT Binding
-- This module provides a high-level Lua interface to the Citum Rust processor.
--
-- Design note: this binding is an experimental project whose primary purpose is
-- testing the citum-core API, its C FFI surface, and the citum-server RPC protocol.
-- It is not intended for production use. Two transport backends are provided:
--
--   FFI  — loads libcitum_engine directly via LuaJIT FFI. Fast for local
--   development, but unsuitable for distribution in environments like TeXLive,
--   which prohibit loading external shared libraries for security and policy
--   reasons. (Zeping Lee's TeXLive inquiry on the TUG list, March 2026, and
--   Karl Berry's reply, prompted the addition of the RPC mode.)
--
--   Pipe/RPC — spawns citum-server as a subprocess communicating over
--   stdin/stdout using JSON-RPC 2.0. This is the only viable path for broad
--   distribution such as TeXLive.
--
-- If this ever develops into a production LaTeX package, the FFI transport should
-- be removed in favour of the pipe/RPC mode.

local CITUM = {}
CITUM.__index = CITUM

-- State for multi-pass LaTeX processing
CITUM.document_citations = {}
CITUM.cached_results = { citations = {}, bibliography = "", bibliography_filtered = {} }
CITUM.citation_index = 0
CITUM.config = { transport = "ffi", server_path = nil, jobname = "texput" }

local json
do
    local ok, res = pcall(require, "utilities.json")
    if ok and res then
        json = res
    else
        ok, res = pcall(require, "citum_json")
        if ok and res then
            json = res
        else
            ok, res = pcall(require, "json")
            if ok and res then
                json = res
            end
        end
    end
end

if not json then
    -- Minimal fallback: encode + decode sufficient for citation data
    local J = {}
    local function enc(v)
        local t = type(v)
        if t == "nil"     then return "null" end
        if t == "boolean" then return tostring(v) end
        if t == "number"  then return tostring(v) end
        if t == "string"  then
            local escapes = { ['\\']='\\\\', ['"']='\\"', ['\n']='\\n',
                              ['\r']='\\r', ['\t']='\\t' }
            return '"' .. v:gsub('[\\"\n\r\t]', escapes) .. '"'
        end
        if t == "table" then
            if #v > 0 then
                local a = {}
                for _, x in ipairs(v) do a[#a+1] = enc(x) end
                return "[" .. table.concat(a, ",") .. "]"
            end
            local o = {}
            for k, x in pairs(v) do o[#o+1] = '"' .. k .. '":' .. enc(x) end
            return "{" .. table.concat(o, ",") .. "}"
        end
        return "null"
    end
    local function dec(s, i)
        i = s:find("[^ \t\n\r]", i or 1)
        if not i then return nil, (#s + 1) end
        local c = s:sub(i, i)
        if c == '"' then
            local j, parts = i + 1, {}
            while j <= #s do
                local ch = s:sub(j, j)
                if ch == '"' then return table.concat(parts), j + 1
                elseif ch == '\\' then
                    local esc_ch = s:sub(j+1,j+1)
                    local m = {['"']='"',['\\']='\\',['/']=  '/',
                               b=string.char(8),f=string.char(12),
                               n='\n',r='\r',t='\t'}
                    parts[#parts+1] = m[esc_ch] or esc_ch
                    j = j + 2
                else parts[#parts+1] = ch ; j = j + 1 end
            end
        elseif c == '[' then
            local arr, ni = {}, i + 1
            ni = s:find("[^ \t\n\r]", ni)
            if s:sub(ni,ni) == ']' then return arr, ni+1 end
            repeat
                local v; v, ni = dec(s, ni) ; arr[#arr+1] = v
                ni = s:find("[^ \t\n\r]", ni)
                if s:sub(ni,ni) == ']' then return arr, ni+1 end
                ni = ni + 1
            until false
        elseif c == '{' then
            local obj, ni = {}, i + 1
            ni = s:find("[^ \t\n\r]", ni)
            if s:sub(ni,ni) == '}' then return obj, ni+1 end
            repeat
                local k; k, ni = dec(s, ni)
                ni = (s:find(":", ni) or ni) + 1
                local v; v, ni = dec(s, ni) ; obj[k] = v
                ni = s:find("[^ \t\n\r]", ni)
                if s:sub(ni,ni) == '}' then return obj, ni+1 end
                ni = ni + 1
            until false
        elseif s:sub(i,i+3) == "true"  then return true,  i+4
        elseif s:sub(i,i+4) == "false" then return false, i+5
        elseif s:sub(i,i+3) == "null"  then return nil,   i+4
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
            if num then return tonumber(num), i + #num end
            error("citum json: unexpected token at " .. i)
        end
    end
    J.tostring = enc ; J.encode = enc
    J.tolua    = function(s) return (dec(s)) end
    J.decode   = function(s) return (dec(s)) end
    json = J
end

local ffi_ok, ffi = pcall(require, "ffi")
local lib = nil

if ffi_ok then
    ffi.cdef[[
        typedef struct Processor Processor;

        Processor* citum_processor_new(const char* style_json, const char* bib_json);
        Processor* citum_processor_new_with_locale(const char* style_json,
            const char* bib_json, const char* locale_json);

        Processor* citum_processor_new_from_yaml(const char* style_yaml,
            const char* bib_yaml);
        Processor* citum_processor_new_with_locale_from_yaml(const char* style_yaml,
            const char* bib_yaml, const char* locale_yaml);

        void citum_processor_free(Processor* processor);

        char* citum_get_last_error();
        char* citum_version();

        char* citum_render_citation_latex(Processor* processor, const char* cite_json);
        char* citum_render_citation_html(Processor* processor, const char* cite_json);
        char* citum_render_citation_plain(Processor* processor, const char* cite_json);
        char* citum_render_citation_djot(Processor* processor, const char* cite_json);
        char* citum_render_citation_typst(Processor* processor, const char* cite_json);

        char* citum_render_bibliography_latex(Processor* processor);
        char* citum_render_bibliography_html(Processor* processor);
        char* citum_render_bibliography_plain(Processor* processor);
        char* citum_render_bibliography_djot(Processor* processor);
        char* citum_render_bibliography_typst(Processor* processor);

        char* citum_render_bibliography_grouped_html(Processor* processor);
        char* citum_render_bibliography_grouped_plain(Processor* processor);

        char* citum_render_citations_json(Processor* processor, const char* citations_json, const char* format);

        void citum_string_free(char* s);
    ]]

    local function get_lib_filename()
        local os_name = "Linux"
        if ffi.os == "OSX" then os_name = "OSX" end
        if ffi.os == "Windows" then os_name = "Windows" end

        if os_name == "OSX"     then return "libcitum_engine.dylib" end
        if os_name == "Windows" then return "citum_engine.dll" end
        return "libcitum_engine.so"
    end

    local function load_lib()
        local env_path = os.getenv("CITUM_LIB_PATH")
        if env_path and env_path ~= "" then
            local ok, l = pcall(ffi.load, env_path)
            if ok then return l end
        end

        local name = get_lib_filename()
        local ok, l = pcall(ffi.load, name)
        if ok then return l end

        local ok2, l2 = pcall(ffi.load, "./" .. name)
        if ok2 then return l2 end

        return nil
    end

    lib = load_lib()
end

local function is_null_ptr(p)
    if p == nil then return true end
    if ffi_ok and ffi then
        return tonumber(ffi.cast("uintptr_t", p)) == 0
    end
    return false
end

local function to_lua_string(c_str)
    if not lib or is_null_ptr(c_str) then return nil end
    local s = ffi.string(c_str)
    lib.citum_string_free(c_str)
    return s
end

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then
        error("citum: cannot open file '" .. path .. "': " .. tostring(err))
    end
    local content = f:read("*a")
    f:close()
    return content
end

--- Get the last error from the Citum engine.
function CITUM.get_last_error()
    return to_lua_string(lib.citum_get_last_error())
end

--- Get the version of the Citum engine.
function CITUM.version()
    return to_lua_string(lib.citum_version())
end

--- Create a new Citum processor from JSON strings.
function CITUM.new(style_json, bib_json)
    local self = setmetatable({}, CITUM)
    self.ptr = lib.citum_processor_new(style_json, bib_json)
    if is_null_ptr(self.ptr) then
        return nil, "Failed to initialise Citum processor: " .. (CITUM.get_last_error() or "unknown error")
    end
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Create a new Citum processor with a specific locale, from JSON strings.
function CITUM.new_with_locale(style_json, bib_json, locale_json)
    local self = setmetatable({}, CITUM)
    self.ptr = lib.citum_processor_new_with_locale(style_json, bib_json, locale_json)
    if is_null_ptr(self.ptr) then
        return nil, "Failed to initialise Citum processor with locale: " .. (CITUM.get_last_error() or "unknown error")
    end
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Create a processor from Citum YAML files on disk (primary format).
-- Reads file contents and passes YAML strings to the FFI.
function CITUM.from_yaml(style_path, bib_path)
    local style_str = read_file(style_path)
    local bib_str   = read_file(bib_path)
    local ptr = lib.citum_processor_new_from_yaml(style_str, bib_str)
    if is_null_ptr(ptr) then
        return nil, "Failed to initialise Citum processor from YAML files: "
          .. style_path .. ", " .. bib_path .. " (" .. (CITUM.get_last_error() or "unknown error") .. ")"
    end
    local self = setmetatable({}, CITUM)
    self.ptr = ptr
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Create a processor from Citum YAML files with a locale.
-- locale may be a .yaml file path, a multi-line YAML string, or a bare locale
-- ID like "en-US" (produces a minimal locale; engine uses built-in term tables).
function CITUM.from_yaml_with_locale(style_path, bib_path, locale)
    if not locale or locale == "" then
        return nil, "citum: locale is required for from_yaml_with_locale"
    end
    local style_str = read_file(style_path)
    local bib_str   = read_file(bib_path)
    local locale_str
    if locale:match("%.ya?ml$") then
        locale_str = read_file(locale)
    elseif locale:match("\n") then
        locale_str = locale
    else
        locale_str = "locale: " .. locale
    end
    local ptr = lib.citum_processor_new_with_locale_from_yaml(style_str, bib_str, locale_str)
    if is_null_ptr(ptr) then
        return nil, "Failed to initialise Citum processor with locale: "
          .. (CITUM.get_last_error() or "unknown error")
    end
    local self = setmetatable({}, CITUM)
    self.ptr = ptr
    ffi.gc(self.ptr, lib.citum_processor_free)
    return self
end

--- Not supported: biblatex .bib input is not available via the C FFI.
-- Convert your bibliography to Citum YAML format and use from_yaml instead.
function CITUM.from_bib(_style_path, bib_path)
    return nil, "citum: biblatex .bib input (" .. bib_path .. ") is not supported "
      .. "via the C FFI. Convert to Citum YAML bib format and use from_yaml."
end

function CITUM:free()
    if self.ptr then
        local ptr = self.ptr
        self.ptr = nil
        lib.citum_processor_free(ptr)
    end
end

local function json_escape(s)
    local esc = { ['\\'] = '\\\\', ['"'] = '\\"', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return s:gsub('[\\"\n\r\t]', esc)
end

local function generate_cite_json(opts)
    if type(opts) == "string" then
        return '{"items":[{"id":"' .. json_escape(opts) .. '"}]}'
    end

    local items = {}
    for _, item in ipairs(opts.items or {}) do
        local parts = {'"id":"' .. json_escape(item.id) .. '"'}
        if item.locator then
            local lbl = json_escape(item.label or "page")
            parts[#parts+1] = '"locator":{"label":"' .. lbl .. '","value":"' .. json_escape(item.locator) .. '"}'
        end
        if item.prefix then parts[#parts+1] = '"prefix":"' .. json_escape(item.prefix) .. '"' end
        if item.suffix then parts[#parts+1] = '"suffix":"' .. json_escape(item.suffix) .. '"' end
        table.insert(items, "{" .. table.concat(parts, ",") .. "}")
    end

    local root = {'"items":[' .. table.concat(items, ",") .. ']'}
    if opts.mode then table.insert(root, '"mode":"' .. json_escape(opts.mode) .. '"') end
    if opts.sentence_start then table.insert(root, '"sentence-start":true') end
    if opts.prefix then table.insert(root, '"prefix":"' .. json_escape(opts.prefix) .. '"') end
    if opts.suffix then table.insert(root, '"suffix":"' .. json_escape(opts.suffix) .. '"') end

    return "{" .. table.concat(root, ",") .. "}"
end

function CITUM:render_citation(opts)
    local cite_json = generate_cite_json(opts)
    local c_str = lib.citum_render_citation_latex(self.ptr, cite_json)
    if c_str == nil then
        return "[citum render error: " .. (CITUM.get_last_error() or "unknown") .. "]"
    end
    return to_lua_string(c_str)
end

function CITUM:render_citation_html(opts)
    local cite_json = generate_cite_json(opts)
    return to_lua_string(lib.citum_render_citation_html(self.ptr, cite_json))
end

function CITUM:render_citation_plain(opts)
    local cite_json = generate_cite_json(opts)
    return to_lua_string(lib.citum_render_citation_plain(self.ptr, cite_json))
end

function CITUM:render_citation_djot(opts)
    local cite_json = generate_cite_json(opts)
    return to_lua_string(lib.citum_render_citation_djot(self.ptr, cite_json))
end

function CITUM:render_citation_typst(opts)
    local cite_json = generate_cite_json(opts)
    return to_lua_string(lib.citum_render_citation_typst(self.ptr, cite_json))
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

function CITUM:render_bibliography_djot()
    return to_lua_string(lib.citum_render_bibliography_djot(self.ptr))
end

function CITUM:render_bibliography_typst()
    return to_lua_string(lib.citum_render_bibliography_typst(self.ptr))
end

function CITUM:render_bibliography_grouped_html()
    return to_lua_string(lib.citum_render_bibliography_grouped_html(self.ptr))
end

function CITUM:render_bibliography_grouped_plain()
    return to_lua_string(lib.citum_render_bibliography_grouped_plain(self.ptr))
end

--- Render multiple citations in batch.
-- citations: table of citation options (as passed to render_citation)
-- format: "latex", "html", "plain", "djot", "typst"
function CITUM:render_citations_batch(citations, format)
    local batch = {}
    for _, c in ipairs(citations) do
        table.insert(batch, generate_cite_json(c))
    end
    local citations_json = "[" .. table.concat(batch, ",") .. "]"
    return to_lua_string(lib.citum_render_citations_json(self.ptr, citations_json, format or "plain"))
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

function CITUM.load_cache(jobname)
    CITUM.config.jobname = jobname
    CITUM.citation_index = 0
    CITUM.document_citations = {}
    local path = jobname .. ".citum.json"
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(json.tolua, content)
        if ok and data then
            CITUM.cached_results = data
        end
    end
end

function CITUM.save_cache(data)
    local path = CITUM.config.jobname .. ".citum.json"
    local f = io.open(path, "w")
    if f then
        f:write(json.tostring(data))
        f:close()
    end
end

-- Pipe/RPC transport helpers.
-- See the design note at the top of this file for background on why this mode
-- exists (TeXLive policy, Zeping Lee's TUG list inquiry, Karl Berry's reply).
-- tug.org/pipermail/tex-live/2026-March/052253.html
local function find_server_binary()
    local explicit = CITUM.config.server_path or os.getenv("CITUM_SERVER_PATH")
    if explicit and explicit ~= "" then return explicit end
    -- os.execute returns boolean true (Lua 5.2+) or integer 0 (Lua 5.1/LuaJIT) on success.
    local ok = os.execute("citum-server --version >/dev/null 2>&1")
    if ok == true or ok == 0 then
        return "citum-server"
    end
    return nil
end

local function pipe_request(server_path, payload)
    -- os.tmpname() returns a /tmp/… path that LuaTeX's openout_any blocks.
    -- Use a job-relative name so the write lands in the current directory.
    local tmpfile = CITUM.config.jobname .. ".citum_pipe_tmp"
    local f = io.open(tmpfile, "w")
    if not f then return nil, "citum: cannot create temp file for pipe transport" end
    f:write(payload)
    f:write("\n")
    f:close()
    -- Quote server_path to guard against spaces/special chars in the path.
    -- Note: 2>/dev/null is POSIX-only; Windows is not supported by this transport.
    local quoted = '"' .. server_path:gsub('"', '\\"') .. '"'
    local cmd = string.format('%s < "%s" 2>/dev/null', quoted, tmpfile)
    local pipe = io.popen(cmd, "r")
    if not pipe then
        os.remove(tmpfile)
        return nil, "citum: failed to spawn citum-server"
    end
    local response = pipe:read("*l")
    pipe:close()
    os.remove(tmpfile)
    if not response or response == "" then
        return nil, "citum: citum-server returned no output"
    end
    return response
end

local function parse_bib_entry_list(bib_str)
    local header_lines, entries = {}, {}
    local current, current_type, in_entries = nil, nil, false
    for line in (bib_str .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^  %- id:") then
            if current then
                entries[#entries+1] = { text = current, type = current_type or "" }
            end
            current, current_type, in_entries = line .. "\n", nil, true
        elseif in_entries then
            local t = line:match("^%s+type:%s*(%S+)")
            if t then current_type = t end
            current = current .. line .. "\n"
        else
            header_lines[#header_lines+1] = line
        end
    end
    if current then entries[#entries+1] = { text = current, type = current_type or "" } end
    return table.concat(header_lines, "\n") .. "\n", entries
end

local function make_filtered_yaml(header, entries, filter_type, exclude)
    local out = {}
    for _, e in ipairs(entries) do
        local match = (e.type == filter_type)
        if (not exclude and match) or (exclude and not match) then
            out[#out+1] = e.text
        end
    end
    if #out == 0 then return nil end
    return header .. table.concat(out)
end

function CITUM.process_document(proc, style_path, bib_path, locale)
    local citations = CITUM.document_citations
    local format = "latex"
    local results = { citations = {}, bibliography = "" }

    if CITUM.config.transport == "pipe" then
        local citation_occs = {}
        for i, c in ipairs(citations) do
            local items = {}
            for _, item in ipairs(c.items) do
                local new_item = { id = item.id }
                if item.locator then
                    -- Server expects locator as {label, value}, not flat fields
                    new_item.locator = { label = item.label or "page", value = item.locator }
                end
                if item.prefix then new_item.prefix = item.prefix end
                if item.suffix then new_item.suffix = item.suffix end
                table.insert(items, new_item)
            end
            local occ = { id = "cite-" .. i, items = items }
            if c.mode then occ.mode = c.mode end
            if c.sentence_start then occ["sentence-start"] = true end
            table.insert(citation_occs, occ)
        end
        local params = {
            style  = { kind = "path", value = style_path },
            refs   = { kind = "path", value = bib_path },
            output_format = format,
            citations = citation_occs,
        }
        if locale and locale ~= "" then params.locale = locale end
        local request = { jsonrpc = "2.0", id = 1, method = "format_document", params = params }
        local encode = json.tostring or json.encode
        local ok, payload = pcall(encode, request)
        if not ok then error("citum: failed to encode pipe request: " .. tostring(payload)) end
        local response, err = pipe_request(CITUM.config.server_path, payload)
        if not response then
            texio.write_nl("Package citum Warning: pipe error: " .. tostring(err))
            return
        end
        local decode = json.tolua or json.decode
        local ok2, data = pcall(decode, response)
        if not ok2 or not data or not data.result then
            error("citum: failed to parse pipe response: " .. tostring(data))
        end
        local fc = data.result.formatted_citations or {}
        for _, c in ipairs(fc) do
            table.insert(results.citations, c.text or "")
        end
        local bib = data.result.bibliography
        results.bibliography = (type(bib) == "table" and bib.content) or bib or ""
    else
        -- FFI Batch processing
        if not proc then return end
        local batch_parts = {}
        for _, c in ipairs(citations) do
            table.insert(batch_parts, generate_cite_json(c))
        end
        local batch_json = "[" .. table.concat(batch_parts, ",") .. "]"
        local c_str = lib.citum_render_citations_json(proc.ptr, batch_json, format)
        local rendered_str = to_lua_string(c_str)
        if rendered_str then
            results.citations = json.tolua(rendered_str) or {}
        end
        results.bibliography = proc:render_bibliography()

        -- Pre-render type-filtered bibliographies (FFI only)
        local ok_bib, bib_file_str = pcall(read_file, bib_path)
        if ok_bib then
            local hdr, entry_list = parse_bib_entry_list(bib_file_str)
            local types_seen = {}
            for _, e in ipairs(entry_list) do
                if e.type ~= "" then types_seen[e.type] = true end
            end
            if next(types_seen) then
                local ok_sty, sty_str = pcall(read_file, style_path)
                if ok_sty then
                    local filtered = {}
                    local function render_filtered(key, yaml_str)
                        local ptr = lib.citum_processor_new_from_yaml(sty_str, yaml_str)
                        if not is_null_ptr(ptr) then
                            lib.citum_render_citations_json(ptr, batch_json, format)
                            local s = to_lua_string(lib.citum_render_bibliography_latex(ptr))
                            lib.citum_processor_free(ptr)
                            if s then filtered[key] = s end
                        end
                    end
                    for t in pairs(types_seen) do
                        local y_inc = make_filtered_yaml(hdr, entry_list, t, false)
                        if y_inc then render_filtered("type=" .. t, y_inc) end
                        local y_exc = make_filtered_yaml(hdr, entry_list, t, true)
                        if y_exc then render_filtered("not-type=" .. t, y_exc) end
                    end
                    results.bibliography_filtered = filtered
                end
            end
        end
    end

    -- Compare with current cache to see if we need another rerun
    local changed = false
    if #results.citations ~= #(CITUM.cached_results.citations or {}) then
        changed = true
    else
        for i, v in ipairs(results.citations) do
            if v ~= CITUM.cached_results.citations[i] then
                changed = true
                break
            end
        end
    end
    if not changed and results.bibliography ~= CITUM.cached_results.bibliography then
        changed = true
    end

    CITUM.save_cache(results)

    if changed then
        tex.print("\\PackageWarningNoLine{citum}{Citation(s) may have changed. Rerun to get cross-references right}")
    end
end

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
function CITUM.record_cite(cite_opts)
    table.insert(CITUM.document_citations, cite_opts)
    CITUM.citation_index = CITUM.citation_index + 1
    
    local rendered = CITUM.cached_results.citations[CITUM.citation_index]
    if rendered then
        tex.sprint(rendered)
    else
        tex.sprint("\\textbf{[?]}")
    end
end

function CITUM.do_cite(cite_opts)
    CITUM.record_cite(cite_opts)
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

function CITUM.cites_flush(_proc)
    CITUM.record_cite({ items = CITUM.cites_items })
end

function CITUM.cites_flush_integral(_proc)
    CITUM.record_cite({ mode = "integral", items = CITUM.cites_items })
end

-- Sentence-initial flush variants (capitalized \Citeend / \Textciteend)
function CITUM.cites_flush_sentence_start(_proc)
    CITUM.record_cite({ sentence_start = true, items = CITUM.cites_items })
end

function CITUM.cites_flush_integral_sentence_start(_proc)
    CITUM.record_cite({ mode = "integral", sentence_start = true, items = CITUM.cites_items })
end

function CITUM.cite_single(_proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.record_cite({ items = { item } })
end

function CITUM.textcite_single(_proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.record_cite({ mode = "integral", items = { item } })
end

-- Sentence-initial variants: capitalize the first character of the composed output.
-- Mirrors biblatex \Cite, \Textcite, \Cites, \Textcites.
function CITUM.Cite_single(_proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.record_cite({ sentence_start = true, items = { item } })
end

function CITUM.Textcite_single(_proc, raw_loc, key)
    local label, locator = CITUM.parse_locator(raw_loc)
    local item = { id = key, label = label, locator = locator }
    CITUM.record_cite({ mode = "integral", sentence_start = true, items = { item } })
end

function CITUM.cite_keys(_proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.record_cite({ items = items })
end

function CITUM.textcite_keys(_proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.record_cite({ mode = "integral", items = items })
end

function CITUM.Cite_keys(_proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.record_cite({ sentence_start = true, items = items })
end

function CITUM.Textcite_keys(_proc, keys_str)
    local items = {}
    for _, k in ipairs(CITUM.split_keys(keys_str)) do
        table.insert(items, { id = k })
    end
    CITUM.record_cite({ mode = "integral", sentence_start = true, items = items })
end

function CITUM.init_processor(style_opt, bibfile, locale_opt, jobname, server_path_opt)
    CITUM.load_cache(jobname)

    if server_path_opt and server_path_opt ~= "" then
        CITUM.config.server_path = server_path_opt
    end

    if lib then
        CITUM.config.transport = "ffi"
    else
        local server = find_server_binary()
        if server then
            CITUM.config.transport = "pipe"
            CITUM.config.server_path = server
        else
            error("citum: no backend available. "
                .. "Build libcitum_engine or install citum-server on PATH.")
        end
    end

    if CITUM.config.transport == "pipe" then
        return { dummy = true }
    end

    if bibfile:match("%.bib$") then
        error("citum: biblatex .bib input is not supported via the C FFI. "
          .. "Convert '" .. bibfile .. "' to Citum YAML bib format.")
    end

    local proc, err
    if locale_opt and locale_opt ~= "" then
        proc, err = CITUM.from_yaml_with_locale(style_opt, bibfile, locale_opt)
    else
        proc, err = CITUM.from_yaml(style_opt, bibfile)
    end

    if not proc then
        error("citum: failed to init processor. " .. tostring(err))
    end
    return proc
end

function CITUM.print_bibliography(_proc, opts_str)
    local bib
    if opts_str and opts_str ~= "" then
        bib = (CITUM.cached_results.bibliography_filtered or {})[opts_str]
        if not bib then
            tex.sprint("\\PackageWarning{citum}{Filter '" .. opts_str
                .. "' unavailable (pipe transport or rerun needed); using full bibliography.}")
            bib = CITUM.cached_results.bibliography
        end
    else
        bib = CITUM.cached_results.bibliography
    end
    if bib and bib ~= "" then
        tex.sprint(bib)
    else
        tex.sprint("\\PackageWarning{citum}{Bibliography not yet rendered. Rerun LaTeX.}")
    end
end

return CITUM
