# Run normal / modified / recovered simulation and save logs under evidence/pre.
# Usage (from the repository root):  powershell -ExecutionPolicy Bypass -File tools\run_evidence.ps1
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
New-Item -ItemType Directory -Force evidence\pre | Out-Null
function Run-Sim($tag) {
  Remove-Item wave.vcd -ErrorAction SilentlyContinue
  $out = & { iverilog -g2012 -o sim.out (Get-ChildItem src\*.v).FullName (Get-ChildItem sim\*.sv).FullName 2>&1; vvp sim.out 2>&1 }
  $out | Out-File -Encoding utf8 "evidence\pre\lab2_integrated_$tag.log"
  Write-Host "===== $tag ====="
  $out
  if ($tag -eq "normal" -and (Test-Path wave.vcd)) { Copy-Item wave.vcd evidence\pre\lab2_integrated_wave_normal.vcd -Force }
}
Run-Sim "normal"
$file = Join-Path $Root "src\counter4.v"
$orig = [IO.File]::ReadAllText($file)
$old = "else value <= value + 4'd1;"
$new = "else value <= value + 4'd2;"
if (-not $orig.Contains($old)) { Write-Host "target line not found in counter4.v" -ForegroundColor Red; exit 1 }
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($file, $orig.Replace($old, $new), $utf8)
Run-Sim "mod"
[IO.File]::WriteAllText($file, $orig, $utf8)
Run-Sim "recover"
Write-Host "git diff (must be empty):"
git diff --stat src
