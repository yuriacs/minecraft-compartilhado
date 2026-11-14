@echo off
title Minecraft compartilhado - avisos no Discord
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -SetWebhook ask
echo.
pause
