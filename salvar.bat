@echo off
title Minecraft compartilhado - salvar
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -SaveOnly
echo.
pause
