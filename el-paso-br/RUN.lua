--[[ El Paso, Texas: Border Roleplay
  Запуск:
  loadstring(readfile("el-paso-br/RUN.lua"))()

  Авто-выгрузка при повторном запуске встроена в el-paso-br.lua
]]

if typeof(getgenv) == "function" and getgenv().EPBR_Stop then
	pcall(getgenv().EPBR_Stop)
end

if typeof(getgenv) == "function" then
	getgenv().MaxiHubSkipKey = true
elseif _G then
	_G.MaxiHubSkipKey = true
end

local ROOT = "el-paso-br"
local MAIN = ROOT .. "/el-paso-br.lua"

if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
	warn("[EPBR] Нужен readfile/isfile в executor")
	return
end

if not isfile(MAIN) then
	warn("[EPBR] Нет файла: " .. MAIN)
	return
end

print("[EPBR] -> " .. MAIN)

local loader = loadstring or load
if type(loader) ~= "function" then
	warn("[EPBR] Нет loadstring/load в executor")
	return
end

local source = readfile(MAIN)
if type(source) ~= "string" or source == "" then
	warn("[EPBR] Пустой файл: " .. MAIN)
	return
end

local chunk, compileErr = loader(source, "@el-paso-br")
if type(chunk) ~= "function" then
	warn("[EPBR] compile: " .. tostring(compileErr))
	return
end

local trace = function(e) return tostring(e) end
if debug and type(debug.traceback) == "function" then
	trace = debug.traceback
end

local ok, err = xpcall(chunk, trace)

if not ok then
	warn("[EPBR] " .. tostring(err))
end
