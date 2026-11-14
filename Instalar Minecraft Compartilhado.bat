@echo off
setlocal
title Instalar Minecraft Compartilhado

rem ====================================================================
rem  INSTALADOR - mande este arquivo para os amigos que vao hostear.
rem
rem  REPO_URL: link do repositorio do SEU grupo (o privado, com o mundo).
rem            Se ficar vazio, o instalador pergunta na hora.
rem  PASTA:    onde o servidor fica no PC de cada um. Deixe fora do
rem            OneDrive / Google Drive.
rem ====================================================================
set "REPO_URL="
set "PASTA=%SystemDrive%\MinecraftCompartilhado"

rem Daqui para baixo e o instalador em si (PowerShell dentro deste arquivo).
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SELF); Invoke-Expression $s.Substring($s.LastIndexOf('#:INICIO-POWERSHELL'))"
echo.
pause
exit /b

#:INICIO-POWERSHELL
# ATENCAO: manter este arquivo so com caracteres ASCII (sem acentos).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Say($msg, $color = 'Cyan') {
    Write-Host ''
    Write-Host "==> $msg" -ForegroundColor $color
}

function Stop-Install($msg) {
    Write-Host ''
    Write-Host "NAO DEU CERTO: $msg" -ForegroundColor Red
    exit 1
}

function Ask-Yes($question) {
    return ((Read-Host "$question (s/n)") -match '^[sSyY]')
}

# Procura o Git no PATH e nas pastas padrao (logo apos instalar, o PATH desta
# janela ainda nao foi atualizado).
function Find-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return $true }
    $folders = @("$env:ProgramFiles\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd", "$env:LOCALAPPDATA\Programs\Git\cmd")
    foreach ($folder in $folders) {
        if (Test-Path (Join-Path $folder 'git.exe')) {
            $env:PATH = "$folder;$env:PATH"
            return $true
        }
    }
    return $false
}

# Deixa dois links de repositorio comparaveis (sem .git, sem barra final, minusculas).
function Get-RepoKey($url) {
    return (("$url".Trim().TrimEnd('/')) -replace '\.git$', '').ToLower()
}

Write-Host ''
Write-Host 'Instalador do Minecraft Compartilhado' -ForegroundColor Green
Write-Host 'Ele vai: conferir o Git, baixar o servidor do grupo e criar um atalho na area de trabalho.'

# ---------------------------------------------------------------- repositorio

$repo = "$env:REPO_URL".Trim()
if (-not $repo) {
    Write-Host ''
    $repo = (Read-Host 'Cole o link do repositorio do grupo (ex.: https://github.com/fulano/nosso-servidor)').Trim()
}
if ($repo -notmatch '^https://github\.com/[\w.-]+/[\w.-]+/?$') {
    Stop-Install "Isto nao parece o link de um repositorio do GitHub: $repo"
}
$repoPage = (("$repo".TrimEnd('/')) -replace '\.git$', '')
$dest = "$env:PASTA".Trim()
if (-not $dest) { $dest = "$env:SystemDrive\MinecraftCompartilhado" }
$dest = [IO.Path]::GetFullPath($dest)   # caminho completo, mesmo que PASTA seja relativa

# ---------------------------------------------------------------- git

if (-not (Find-Git)) {
    Say 'O Git nao esta instalado neste PC. Ele e necessario para baixar e enviar o mundo.' 'Yellow'
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Ask-Yes '    Instalar o Git agora? O Windows vai pedir permissao')) {
        & winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
        if (-not (Find-Git)) {
            Stop-Install 'A instalacao do Git nao terminou. Feche esta janela e rode o instalador de novo.'
        }
    } else {
        Start-Process 'https://git-scm.com/download/win'
        Stop-Install 'Instale o Git pela pagina que abriu (pode aceitar todas as opcoes padrao) e rode este instalador de novo.'
    }
}
Say 'Git encontrado.' 'Green'

# ---------------------------------------------------------------- baixar

if (Test-Path (Join-Path $dest '.git')) {
    $existing = (& git -C $dest remote get-url origin)
    if ((Get-RepoKey $existing) -ne (Get-RepoKey $repo)) {
        Stop-Install "A pasta $dest ja tem outro servidor ($existing). Mude a linha PASTA no comeco deste arquivo para instalar em outro lugar."
    }
    Say "O servidor ja esta em $dest. Vou so refazer o atalho." 'Green'
} elseif ((Test-Path $dest) -and (Get-ChildItem $dest -Force | Select-Object -First 1)) {
    Stop-Install "A pasta $dest ja existe e tem outras coisas dentro. Mude a linha PASTA no comeco deste arquivo."
} else {
    Say "Baixando o servidor do grupo para $dest ..."
    Write-Host '    Se abrir uma janela de login do GitHub, entre com a conta que foi convidada para o repositorio.'
    & git clone $repo $dest
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'O GitHub nao deixou baixar. Os motivos mais comuns:' -ForegroundColor Yellow
        Write-Host "  1. Voce ainda nao aceitou o convite. Abra: $repoPage/invitations"
        Write-Host '  2. Voce entrou com uma conta do GitHub diferente da que foi convidada.'
        Write-Host '  3. O dono do grupo ainda nao te adicionou como colaborador.'
        Stop-Install 'Resolva o item acima e rode o instalador de novo.'
    }
}
if (-not (Test-Path (Join-Path $dest 'scripts\gui.ps1'))) {
    Stop-Install "Baixei o repositorio, mas ele nao tem o programa (scripts\gui.ps1). O link esta certo? $repo"
}

# ---------------------------------------------------------------- nick

$current = (& git -C $dest config user.name)
if (-not $current) { $current = $env:USERNAME }
Write-Host ''
$nick = (Read-Host "Como voce quer aparecer quando estiver hosteando? [Enter = $current]").Trim()
if (-not $nick) { $nick = $current }
& git -C $dest config user.name $nick
if (-not (& git -C $dest config user.email)) {
    & git -C $dest config user.email "$($nick -replace '\s', '')@users.noreply.github.com"
}

# ---------------------------------------------------------------- atalho

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Minecraft Compartilhado.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dest\scripts\gui.ps1`""
$shortcut.WorkingDirectory = $dest
$shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,41"
$shortcut.Description = 'Hostear ou entrar no servidor de Minecraft do grupo'
$shortcut.Save()
Say 'Atalho "Minecraft Compartilhado" criado na area de trabalho.' 'Green'

# ---------------------------------------------------------------- fim

$radmin = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -like '*Radmin*' }
if (-not $radmin) {
    Write-Host ''
    Write-Host 'Dica: nao achei o Radmin VPN neste PC. Se o seu grupo usa o Radmin para se conectar,' -ForegroundColor Yellow
    Write-Host '      instale em https://www.radmin-vpn.com/ e entre na rede do grupo.' -ForegroundColor Yellow
}

Say 'Tudo pronto!' 'Green'
Write-Host '    Para jogar ou hostear, abra o atalho "Minecraft Compartilhado" na area de trabalho.'
Write-Host '    Na primeira vez que voce hostear, ele baixa o Java e o servidor sozinho (alguns minutos).'
Write-Host ''
if (Ask-Yes '    Abrir o Minecraft Compartilhado agora?') {
    Start-Process $shortcutPath
}
