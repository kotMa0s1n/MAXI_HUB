$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$uiPath = Join-Path (Split-Path $base -Parent) "maxi-hub\maxi-hub\maxi-hub-ui.lua"
$logicPath = Join-Path $base "epbr-logic.lua"
$bootPath = Join-Path $base "epbr-bootstrap.lua"
$outPath = Join-Path $base "el-paso-br.lua"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Read-Utf8NoBom([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    return $utf8NoBom.GetString($bytes)
}

$ui = Read-Utf8NoBom $uiPath
$logic = Read-Utf8NoBom $logicPath
$boot = Read-Utf8NoBom $bootPath

$header = @'
-- El Paso, Texas: Border Roleplay
-- PlaceId: 14502598369
-- Run: loadstring(readfile("el-paso-br/RUN.lua"))()

local TELEGRAM_LINK = "https://t.me/MAXI_HUB"
local PLACE_ID = 14502598369
local BUILD = "v0.14.4"

local Players = game:GetService("Players")
local DEFAULT_UI_POS = UDim2.new(0, 16, 0.5, -270)

local player
local playerGui
local EpbrLogic

local genv
if typeof(getgenv) == "function" then
	genv = getgenv()
else
	genv = _G
end
genv.MaxiHubSkipKey = true

local function ensurePlayer()
	if player and playerGui and playerGui.Parent then
		return true
	end
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 30)
	return playerGui ~= nil
end

-- ===== embedded: maxi-hub-ui.lua =====
local MaxiHubUI = (function()

'@

$mid = @'

end)()

-- ===== embedded: epbr-logic.lua =====
local EpbrLogicModule = (function()

'@

$out = $header + $ui + "`n" + $mid + $logic + "`n" + $boot
[IO.File]::WriteAllText($outPath, $out, $utf8NoBom)
Write-Output "OK $($out.Length) chars -> $outPath"

$deploy = Join-Path $base "deploy-to-potassium.ps1"
if ($env:EPBR_SKIP_DEPLOY -eq "1") {
    Write-Output "SKIP deploy (EPBR_SKIP_DEPLOY=1)"
}
elseif (Test-Path $deploy) {
    & $deploy
}
