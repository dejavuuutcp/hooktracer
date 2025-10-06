local _G = _G

local hook_Add, hook_GetTable = _G.hook.Add, _G.hook.GetTable
local timer_Create, timer_Simple = _G.timer.Create, _G.timer.Simple
local SysTime = _G.SysTime
local table_insert, table_remove, table_sort, table_Count = _G.table.insert, _G.table.remove, _G.table.sort, _G.table.Count
local pairs, ipairs, unpack = _G.pairs, _G.ipairs, _G.unpack
local string_format = _G.string.format
local math_max, math_min, math_huge = _G.math.max, _G.math.min, _G.math.huge
local util_TableToJSON = _G.util.TableToJSON
local file_Write = _G.file.Write
local os_time = _G.os.time
local concommand_Add = _G.concommand.Add
local IsValid = _G.IsValid
local print = _G.print
local tonumber = _G.tonumber

-- Srlion's Hook Library support
local PRE_HOOK = _G.PRE_HOOK or -2

local HookTracer = {
	enabled = false,
	data = {},
	stats = {},
	call_stack = {},
	threshold_ms = 1,
	max_entries = 1000,
	original_call = nil,
	hooked = false
}

local stat_mt = {
	__index = {
		calls = 0,
		total_time = 0,
		max_time = 0,
		min_time = math_huge,
		avg_time = 0
	}
}

local function get_stat(hook_name)
	local stat = HookTracer.stats[hook_name]
	if not stat then
		stat = setmetatable({}, stat_mt)
		HookTracer.stats[hook_name] = stat
	end
	return stat
end

local function record_call(hook_name, duration, depth)
	local data = HookTracer.data
	local data_length = #data
	
	if data_length >= HookTracer.max_entries then
		table_remove(data, 1)
	end
	
	table_insert(data, {
		name = hook_name,
		duration = duration,
		time = SysTime(),
		depth = depth,
		slow = duration > HookTracer.threshold_ms
	})
	
	local stat = get_stat(hook_name)
	stat.calls = stat.calls + 1
	stat.total_time = stat.total_time + duration
	stat.max_time = math_max(stat.max_time, duration)
	stat.min_time = math_min(stat.min_time, duration)
	stat.avg_time = stat.total_time / stat.calls
end

local function hook_system()
	if HookTracer.hooked then return end
	
	HookTracer.original_call = _G.hook.Call
	local original_call = HookTracer.original_call
	
	_G.hook.Call = function(name, gm, ...)
		if not HookTracer.enabled then
			return original_call(name, gm, ...)
		end
		
		local start_time = SysTime()
		local call_stack = HookTracer.call_stack
		local depth = #call_stack
		
		table_insert(call_stack, {
			name = name,
			time = start_time,
			depth = depth
		})
		
		local results = {original_call(name, gm, ...)}
		
		table_remove(call_stack)
		
		local end_time = SysTime()
		local duration = (end_time - start_time) * 1000
		
		record_call(name, duration, depth)
		
		return unpack(results)
	end
	
	HookTracer.hooked = true
	print("[Hook Tracer] Hook system intercepted")
end

local function initialize()
	HookTracer.data = {}
	HookTracer.stats = {}
	HookTracer.call_stack = {}
	hook_system()
	print("[Hook Tracer] Initialized")
end

local function clear_data()
	HookTracer.data = {}
	HookTracer.stats = {}
	HookTracer.call_stack = {}
	print("[Hook Tracer] Data cleared")
end

local function get_slowest_hooks(count)
	count = count or 10
	local sorted = {}
	
	for name, stat in pairs(HookTracer.stats) do
		table_insert(sorted, {
			name = name,
			avg_time = stat.avg_time,
			max_time = stat.max_time,
			calls = stat.calls,
			total_time = stat.total_time
		})
	end
	
	table_sort(sorted, function(a, b)
		return a.avg_time > b.avg_time
	end)
	
	local result = {}
	for i = 1, math_min(count, #sorted) do
		table_insert(result, sorted[i])
	end
	
	return result
end

local function get_frequent_hooks(count)
	count = count or 10
	local sorted = {}
	
	for name, stat in pairs(HookTracer.stats) do
		table_insert(sorted, {
			name = name,
			calls = stat.calls,
			avg_time = stat.avg_time,
			total_time = stat.total_time
		})
	end
	
	table_sort(sorted, function(a, b)
		return a.calls > b.calls
	end)
	
	local result = {}
	for i = 1, math_min(count, #sorted) do
		table_insert(result, sorted[i])
	end
	
	return result
end

local function detect_problems()
	local problems = {}
	local threshold = HookTracer.threshold_ms
	
	for name, stat in pairs(HookTracer.stats) do
		if stat.avg_time > threshold * 5 then
			table_insert(problems, {
				type = "SLOW",
				hook = name,
				severity = "HIGH",
				message = string_format("Hook '%s' is very slow (%.3fms avg)", name, stat.avg_time)
			})
		end
		
		if stat.calls > 1000 then
			table_insert(problems, {
				type = "FREQUENT",
				hook = name,
				severity = "MEDIUM",
				message = string_format("Hook '%s' called %d times", name, stat.calls)
			})
		end
		
		if stat.max_time > stat.avg_time * 10 and stat.calls > 10 then
			table_insert(problems, {
				type = "SPIKE",
				hook = name,
				severity = "MEDIUM",
				message = string_format("Hook '%s' has performance spikes (max: %.3fms, avg: %.3fms)", 
					name, stat.max_time, stat.avg_time)
			})
		end
	end
	
	return problems
end

local function print_stats()
	local stats = HookTracer.stats
	
	print("\n========== Hook Tracer Statistics ==========")
	print(string_format("Total hooks tracked: %d", table_Count(stats)))
	print(string_format("Total calls recorded: %d", #HookTracer.data))
	
	print("\n---Slowest Hooks (by avg time)---")
	local slowest = get_slowest_hooks(10)
	for i, hook in ipairs(slowest) do
		print(string_format("%d. %s: %.3fms avg (%.3fms max, %d calls)",
			i, hook.name, hook.avg_time, hook.max_time, hook.calls))
	end
	
	print("\n---Most Frequent Hooks---")
	local frequent = get_frequent_hooks(10)
	for i, hook in ipairs(frequent) do
		print(string_format("%d. %s: %d calls (%.3fms avg)",
			i, hook.name, hook.calls, hook.avg_time))
	end
	
	print("\n==========================================\n")
end

local function print_problems()
	local problems = detect_problems()
	
	if #problems == 0 then
		print("[Hook Tracer] No problems detected!")
		return
	end
	
	print("\n========== Detected Problems ==========")
	for i, problem in ipairs(problems) do
		print(string_format("[%s] %s: %s", problem.severity, problem.type, problem.message))
	end
	print("=======================================\n")
end

-- Export to JSON
local function export_json()
	local json = util_TableToJSON({
		data = HookTracer.data,
		stats = HookTracer.stats,
		timestamp = os_time(),
		threshold = HookTracer.threshold_ms
	}, true)
	
	local filename = "hooktracer_" .. os_time() .. ".json"
	file_Write(filename, json)
	print("[Hook Tracer] Exported to data/" .. filename)
	
	return filename
end

do
	
	local function is_authorized(ply)
		return not IsValid(ply) or ply:IsSuperAdmin()
	end
	
	concommand_Add("hooktracer_start", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		
		initialize()
		HookTracer.enabled = true
		print("[Hook Tracer] Started tracing")
	end)
	
	concommand_Add("hooktracer_stop", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		
		HookTracer.enabled = false
		print("[Hook Tracer] Stopped tracing")
	end)
	
	concommand_Add("hooktracer_stats", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		print_stats()
	end)
	
	concommand_Add("hooktracer_clear", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		clear_data()
	end)
	
	concommand_Add("hooktracer_export", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		export_json()
	end)
	
	concommand_Add("hooktracer_problems", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		print_problems()
	end)
	
	concommand_Add("hooktracer_threshold", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		
		local threshold = tonumber(args[1])
		if threshold then
			HookTracer.threshold_ms = threshold
			print("[Hook Tracer] Threshold set to " .. threshold .. "ms")
		else
			print("[Hook Tracer] Current threshold: " .. HookTracer.threshold_ms .. "ms")
		end
	end)
	
	concommand_Add("hooktracer_live", function(ply, cmd, args)
		if not is_authorized(ply) then return end
		
		if HookTracer.live_mode then
			HookTracer.live_mode = false
			print("[Hook Tracer] Live mode disabled")
		else
			HookTracer.live_mode = true
			print("[Hook Tracer] Live mode enabled - showing hooks slower than " .. HookTracer.threshold_ms .. "ms")
		end
	end)

end

do
	
	hook_Add("Think", "Live", function()
		if not HookTracer.live_mode then return end
		
		local data = HookTracer.data
		local last_entry = data[#data]
		
		if last_entry and last_entry.slow then
			print(string_format("[SLOW HOOK] %s: %.3fms (depth: %d)", 
				last_entry.name, last_entry.duration, last_entry.depth))
		end
	end, PRE_HOOK)
	
end

print("[Hook Tracer] Loaded successfully")
print("Commands: hooktracer_start, hooktracer_stop, hooktracer_stats, hooktracer_clear")
print("          hooktracer_export, hooktracer_problems, hooktracer_threshold, hooktracer_live")
