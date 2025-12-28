if SERVER then return end

local _G = _G
local setmetatable, type, pcall, error = setmetatable, type, pcall, error
local hook_Add, hook_Call = _G.hook.Add, _G.hook.Call
local SysTime = _G.SysTime
local table_insert, table_remove, table_sort, table_Empty = _G.table.insert, _G.table.remove, _G.table.sort, _G.table.Empty
local pairs, ipairs, select = _G.pairs, _G.ipairs, _G.select
local string_format = _G.string.format
local math_max, math_min, math_huge = _G.math.max, _G.math.min, _G.math.huge
local util_TableToJSON = _G.util.TableToJSON
local file_Write, file_Exists, file_CreateDir = _G.file.Write, _G.file.Exists, _G.file.CreateDir
local os_time, os_date = _G.os.time, _G.os.date
local concommand_Add = _G.concommand.Add
local IsValid = _G.IsValid
local MsgC, Color = _G.MsgC, _G.Color
local tonumber = _G.tonumber

-- Srlion's Hook Library
local PRE_HOOK = _G.PRE_HOOK or -2

local MAX_ENTRIES = 10000
local MAX_POOL = 100
local SLOW_MS = 1.0
local VERY_SLOW_MS = 5.0
local FREQ_LIMIT = 1000
local SPIKE_MULT = 10
local DIR = "HookTracer"

local C_PRE = Color(100, 200, 255)
local C_TXT = Color(220, 220, 220)
local C_VAL = Color(255, 255, 100)
local C_WRN = Color(255, 150, 50)
local C_ERR = Color(255, 80, 80)
local C_OK = Color(100, 255, 150)
local C_HDR = Color(150, 150, 255)

local function msg(...)
    MsgC(C_PRE, "[HookTracer] ", C_TXT, ...)
    MsgC("\n")
end

local function msg_val(t, v, c)
    c = c or C_VAL
    MsgC(C_PRE, "[HookTracer] ", C_TXT, t, c, tostring(v), C_TXT, "\n")
end

local function msg_ok(...)
    MsgC(C_OK, "[HookTracer] ", C_TXT, ...)
    MsgC("\n")
end

local function sep()
    MsgC(C_HDR, string.rep("━", 50) .. "\n")
end

local entry_pool = {}
local entry_pool_sz = 0
local stat_pool = {}
local stat_pool_sz = 0

local function get_entry()
    if entry_pool_sz > 0 then
        local e = entry_pool[entry_pool_sz]
        entry_pool[entry_pool_sz] = nil
        entry_pool_sz = entry_pool_sz - 1
        return e
    end
    return {name = "", dur = 0, t = 0, d = 0, slow = false}
end

local function ret_entry(e)
    if entry_pool_sz < MAX_POOL then
        entry_pool_sz = entry_pool_sz + 1
        entry_pool[entry_pool_sz] = e
    end
end

local stat_mt = {
    __index = {
        n = 0,
        tot = 0,
        max = 0,
        min = math_huge,
        avg = 0
    }
}

local function new_stat()
    if stat_pool_sz > 0 then
        local s = stat_pool[stat_pool_sz]
        stat_pool[stat_pool_sz] = nil
        stat_pool_sz = stat_pool_sz - 1
        s.n = 0
        s.tot = 0
        s.max = 0
        s.min = math_huge
        s.avg = 0
        return s
    end
    return setmetatable({}, stat_mt)
end

local function ret_stat(s)
    if stat_pool_sz < MAX_POOL then
        stat_pool_sz = stat_pool_sz + 1
        stat_pool[stat_pool_sz] = s
    end
end

local tr = {
    on = false,
    live = false,
    ents = {},
    ent_cnt = 0,
    stats = {},
    stat_cnt = 0,
    stk = {},
    stk_d = 0,
    thr = SLOW_MS,
    max = MAX_ENTRIES,
    orig = nil,
    hooked = false
}

local function get_stat(name)
    local s = tr.stats[name]
    if not s then
        s = new_stat()
        tr.stats[name] = s
        tr.stat_cnt = tr.stat_cnt + 1
    end
    return s
end

local function rec(name, dur, depth)
    if tr.live and dur > tr.thr then
        MsgC(C_WRN, "[SLOW] ", C_TXT, name, C_VAL, string_format(" %.2fms ", dur), C_TXT, "d:", C_VAL, tostring(depth), C_TXT, "\n")
    end

    local ents = tr.ents
    local cnt = tr.ent_cnt

    if cnt >= tr.max then
        local old = table_remove(ents, 1)
        ret_entry(old)
        cnt = cnt - 1
    end

    local e = get_entry()
    e.name = name
    e.dur = dur
    e.t = SysTime()
    e.d = depth
    e.slow = dur > tr.thr

    cnt = cnt + 1
    ents[cnt] = e
    tr.ent_cnt = cnt

    local s = get_stat(name)
    s.n = s.n + 1
    s.tot = s.tot + dur
    s.max = math_max(s.max, dur)
    s.min = math_min(s.min, dur)
    s.avg = s.tot / s.n
end

local function intercept(name, gm, ...)
    if not tr.on then
        return tr.orig(name, gm, ...)
    end

    local t0 = SysTime()
    local stk = tr.stk
    local d = tr.stk_d

    d = d + 1
    stk[d] = name
    tr.stk_d = d

    local ok, a, b, c, d, e, f = pcall(tr.orig, name, gm, ...)

    stk[tr.stk_d] = nil
    tr.stk_d = tr.stk_d - 1

    local dt = (SysTime() - t0) * 1000
    rec(name, dt, tr.stk_d)

    if not ok then error(a, 0) end

    return a, b, c, d, e, f
end

local function hook_sys()
    if tr.hooked then return end
    tr.orig = hook_Call
    hook_Call = intercept
    _G.hook.Call = intercept
    tr.hooked = true
end

local function unhook_sys()
    if not tr.hooked then return end
    _G.hook.Call = tr.orig
    hook_Call = tr.orig
    tr.hooked = false
end

local function clr()
    for i = 1, tr.ent_cnt do
        ret_entry(tr.ents[i])
        tr.ents[i] = nil
    end

    for name, s in pairs(tr.stats) do
        ret_stat(s)
        tr.stats[name] = nil
    end

    table_Empty(tr.stk)

    tr.ent_cnt = 0
    tr.stat_cnt = 0
    tr.stk_d = 0
end

local function init()
    clr()
    hook_sys()
end

local sort_buf = {}

local function top(cnt, cmp)
    cnt = cnt or 10
    table_Empty(sort_buf)

    for name, s in pairs(tr.stats) do
        table_insert(sort_buf, {
            name = name,
            avg = s.avg,
            max = s.max,
            n = s.n,
            tot = s.tot,
            min = s.min
        })
    end

    table_sort(sort_buf, cmp)

    local res = {}
    local lim = math_min(cnt, #sort_buf)
    for i = 1, lim do
        res[i] = sort_buf[i]
    end

    return res
end

local function slowest(cnt)
    return top(cnt, function(a, b) return a.avg > b.avg end)
end

local function frequent(cnt)
    return top(cnt, function(a, b) return a.n > b.n end)
end

local prob_buf = {}

local function issues()
    table_Empty(prob_buf)
    local thr = tr.thr

    for name, s in pairs(tr.stats) do
        if s.avg > thr * VERY_SLOW_MS then
            table_insert(prob_buf, {
                type = "SLOW",
                hook = name,
                sev = "HIGH",
                msg = string_format("'%s' avg %.2fms", name, s.avg)
            })
        end

        if s.n > FREQ_LIMIT then
            table_insert(prob_buf, {
                type = "FREQ",
                hook = name,
                sev = "MED",
                msg = string_format("'%s' called %dx", name, s.n)
            })
        end

        if s.max > s.avg * SPIKE_MULT and s.n > 10 then
            table_insert(prob_buf, {
                type = "SPIKE",
                hook = name,
                sev = "MED",
                msg = string_format("'%s' max %.2fms/avg %.2fms", name, s.max, s.avg)
            })
        end
    end

    return prob_buf
end

local function stats()
    sep()
    MsgC(C_HDR, " STATISTICS\n")
    sep()

    MsgC(C_TXT, "Hooks: ", C_VAL, tostring(tr.stat_cnt), C_TXT,
         " | Calls: ", C_VAL, tostring(tr.ent_cnt), C_TXT, "\n\n")

    MsgC(C_HDR, "SLOWEST (avg)\n")
    local slow = slowest(20)
    for i, h in ipairs(slow) do
        local clr = h.avg > VERY_SLOW_MS and C_ERR or (h.avg > SLOW_MS and C_WRN or C_VAL)
        MsgC(C_TXT, string_format("%2d. ", i), C_TXT, h.name, "\n")
        MsgC(C_TXT, "    ", clr, string_format("%.2f", h.avg), C_TXT, "ms avg | ",
             C_VAL, string_format("%.2f", h.max), C_TXT, "ms max | ",
             C_VAL, tostring(h.n), C_TXT, " calls\n")
    end

    MsgC(C_HDR, "\nFREQUENT\n")
    local freq = frequent(20)
    for i, h in ipairs(freq) do
        local clr = h.n > FREQ_LIMIT and C_WRN or C_VAL
        MsgC(C_TXT, string_format("%2d. ", i), C_TXT, h.name, "\n")
        MsgC(C_TXT, "    ", clr, tostring(h.n), C_TXT, " calls | ",
             C_VAL, string_format("%.2f", h.avg), C_TXT, "ms avg\n")
    end

    sep()
end

local function problems()
    local iss = issues()

    if #iss == 0 then
        msg_ok("No issues")
        return
    end

    sep()
    MsgC(C_ERR, " ISSUES\n")
    sep()

    for i, p in ipairs(iss) do
        local clr = p.sev == "HIGH" and C_ERR or C_WRN
        MsgC(clr, "> ", C_TXT, string_format("[%s/%s] ", p.sev, p.type), clr, p.msg, C_TXT, "\n")
    end

    sep()
end

local function ensure()
    if not file_Exists(DIR, "DATA") then
        file_CreateDir(DIR)
    end
end

local function exp()
    ensure()

    local export_stats = {}
    for name, s in pairs(tr.stats) do
        export_stats[name] = {
            calls = s.n,
            total_time = s.tot,
            avg_time = s.avg,
            max_time = s.max,
            min_time = s.min
        }
    end

    local export_entries = {}
    for i = 1, tr.ent_cnt do
        local e = tr.ents[i]
        export_entries[i] = {
            name = e.name,
            duration = e.dur,
            time = e.t,
            depth = e.d,
            slow = e.slow
        }
    end

    local dat = {
        timestamp = os_time(),
        date = os_date("%Y-%m-%d %H:%M:%S"),
        threshold = tr.thr,
        entry_count = tr.ent_cnt,
        stat_count = tr.stat_cnt,
        stats = export_stats,
        data = export_entries
    }

    local json = util_TableToJSON(dat, true)
    local fname = string_format("%s/trace_%s.json", DIR, os_date("%Y%m%d_%H%M%S"))

    file_Write(fname, json)
    msg_ok(string_format("Exported: data/%s", fname))

    return fname
end

local function auth(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand_Add("tr_start", function(ply)
    if not auth(ply) then return end
    init()
    tr.on = true
    msg_ok("Started")
end)

concommand_Add("tr_stop", function(ply)
    if not auth(ply) then return end
    tr.on = false
    msg("Stopped")
end)

concommand_Add("tr_stats", function(ply)
    if not auth(ply) then return end
    stats()
end)

concommand_Add("tr_clear", function(ply)
    if not auth(ply) then return end
    clr()
    msg_ok("Cleared")
end)

concommand_Add("tr_export", function(ply)
    if not auth(ply) then return end
    exp()
end)

concommand_Add("tr_issues", function(ply)
    if not auth(ply) then return end
    problems()
end)

concommand_Add("tr_threshold", function(ply, cmd, args)
    if not auth(ply) then return end

    local v = tonumber(args[1])
    if v then
        tr.thr = v
        msg_val("Threshold: ", v .. "ms", C_OK)
    else
        msg_val("Threshold: ", tr.thr .. "ms")
    end
end)

concommand_Add("tr_live", function(ply)
    if not auth(ply) then return end

    tr.live = not tr.live
    if tr.live then
        msg_ok(string_format("Live ON (%.1fms)", tr.thr))
    else
        msg("Live OFF")
    end
end)

concommand_Add("tr_unhook", function(ply)
    if not auth(ply) then return end
    unhook_sys()
    msg("Unhooked")
end)

hook_Add("ShutDown", "HT_Cleanup", function()
    unhook_sys()
    clr()
end, PRE_HOOK)

msg_ok("Commands | tr_start, tr_stop, tr_stats, tr_clear, tr_export, tr_issues, tr_live")
