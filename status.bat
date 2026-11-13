@echo off
title Minecraft compartilhado - status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -Status
echo.
pause
