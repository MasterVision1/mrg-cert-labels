@echo off
REM ============================================================================
REM  Cert Label Station — one-time station setup. Just DOUBLE-CLICK this file.
REM  It downloads and runs the provisioning script, which asks for admin itself
REM  (click YES on the prompt). Fixes "works for admins, not for normal users".
REM ============================================================================
echo Setting up this PC for the Cert Label Station...
echo A Windows admin prompt will appear - click YES.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/provision-station.ps1 | iex"
echo.
echo If a new admin window opened, follow the steps there.
pause
