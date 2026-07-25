$path = Join-Path (Split-Path $PSScriptRoot -Parent) "epbr-logic.lua"
$text = [IO.File]::ReadAllText($path)

if ($text -notmatch "local F = \{\}") {
    $text = $text -replace "(local M = \{\}\r?\n)", "`$1`nlocal F = {}`n"
}

$forwardNames = @(
    "smartTeleportTo",
    "getPartPosition",
    "getPromptWorldPos",
    "getVehicleDriveTune",
    "lookCameraDown"
)

$names = [regex]::Matches($text, "(?m)^local function (\w+)") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$allNames = @($names + $forwardNames | Select-Object -Unique)

foreach ($name in $forwardNames) {
    $text = [regex]::Replace($text, "(?m)^local $name\r?\n", "")
    $text = [regex]::Replace($text, "(?m)^$name = function\b", "function F.$name")
}

foreach ($name in $names) {
    $text = [regex]::Replace($text, "(?m)^local function $name\b", "function F.$name")
}

$allNames = $allNames | Sort-Object { $_.Length } -Descending
foreach ($name in $allNames) {
    $text = [regex]::Replace($text, "(?<![\w.:])$name(?=\s*\()", "F.$name")
    $text = [regex]::Replace($text, "(?<![\w.:])$name(?=\s*[,}\)])", "F.$name")
}

$text = $text -replace "F\.F\.", "F."
$text = $text -replace "function F\.F\.", "function F."

[IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
$top = ([regex]::Matches($text, "(?m)^local ")).Count
Write-Output "top-level locals: $top"
