@echo off
title Minecraft compartilhado - assumir o servidor
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -Force
echo.
pause
