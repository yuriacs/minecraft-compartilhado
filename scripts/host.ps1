# Servidor de Minecraft compartilhado: o mundo fica no GitHub e qualquer
# jogador pode hostear. Uma trava (host.lock.json) no repositorio garante
# que so uma pessoa hosteia por vez.
#
# ATENCAO: manter este arquivo so com caracteres ASCII (sem acentos), senao
# o Windows PowerShell 5.1 le o arquivo errado.

param(
    [switch]$Force,     # assume a trava mesmo que outra pessoa esteja hosteando
    [switch]$SaveOnly,  # so envia o que ficou pendente (sessao que fechou errado)
    [switch]$Status,    # so mostra quem esta hosteando
    [switch]$Gui,       # chamado pela interface (scripts\gui.ps1): sem perguntas no console
    [int]$ParentPid,    # PID da interface; se ela morrer, o servidor e encerrado
    [string]$SetWebhook # grava o link do webhook do Discord no config.json e sai
                        # ("ask" pergunta no console; "off" desliga os avisos)
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root       = Split-Path -Parent $PSScriptRoot
$ServerDir  = Join-Path $Root 'server'
$RuntimeDir = Join-Path $Root '.runtime'
$LockPath   = Join-Path $Root 'host.lock.json'
$LockName   = 'host.lock.json'
$PidPath    = Join-Path $RuntimeDir 'host.pid'
$UserAgent  = 'mc-compartilhado/1.0'

# ---------------------------------------------------------------- helpers

# Escreve na tela sem nunca derrubar o script: se a interface morreu, a saida
# esta quebrada e o salvamento precisa continuar mesmo assim.
function Out-Line($text, $color) {
    try {
        if ($color) { Write-Host $text -ForegroundColor $color } else { Write-Host $text }
    } catch { }
}

function Say($msg, $color = 'Cyan') {
    Out-Line ''
    Out-Line "==> $msg" $color
}

function Fail($msg) {
    Write-Host ''
    Write-Host "ERRO: $msg" -ForegroundColor Red
    exit 1
}

# Linhas "@@..." sao lidas pela interface e nao aparecem para o usuario.
function Emit($text) {
    if ($Gui) { Out-Line "@@$text" }
}

# Icones das mensagens do Discord (escritos por codigo para manter o arquivo em ASCII).
$IconOpen   = [char]::ConvertFromUtf32(0x1F7E2)   # circulo verde
$IconClosed = [char]::ConvertFromUtf32(0x1F534)   # circulo vermelho
$IconWarn   = [string][char]0x26A0                # aviso
$IconSwap   = [char]::ConvertFromUtf32(0x1F501)   # setas em ciclo

# Manda um aviso para o canal do Discord do grupo, se houver webhook no
# config.json. Nunca atrapalha o servidor: qualquer erro aqui e ignorado.
# Devolve se o Discord aceitou a mensagem.
function Send-Discord($text, $url = $WebhookUrl) {
    if (-not $url) { return $false }
    try {
        # allowed_mentions vazio: um nick tipo "@everyone" nao marca ninguem
        $payload = @{ content = $text; allowed_mentions = @{ parse = @() } } | ConvertTo-Json -Compress -Depth 4
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 10 -UserAgent $UserAgent | Out-Null
        return $true
    } catch { return $false }
}

# No console pergunta com Read-Host; na interface manda o codigo da pergunta
# e le a resposta (s/n) que a janela devolve.
function Confirm-Yes($question, $code) {
    if ($Gui) {
        Emit "ASK@@$code"
        $answer = [Console]::In.ReadLine()
    } else {
        $answer = Read-Host "$question (s/n)"
    }
    return ($answer -match '^[sSyY]')
}

# Ha uma sessao de host aberta neste PC (em outra janela)?
function Test-LocalSession {
    if (-not (Test-Path $PidPath)) { return $false }
    # o arquivo guarda "PID|inicio" para nao confundir com outro processo que reutilize o PID
    $saved = (Get-Content $PidPath -Raw).Trim() -split '\|'
    $other = Get-Process -Id ([int]$saved[0]) -ErrorAction SilentlyContinue
    return [bool]($other -and "$($other.StartTime.Ticks)" -eq $saved[1])
}

# Todo git roda com "@() |" na frente: isso da ao git uma entrada vazia propria.
# Sem isso ele herda a entrada deste script e TRAVA enquanto o script espera
# o proximo comando digitado (o backup ficaria parado com o autosave desligado).

# Roda git e para tudo se der erro.
function Invoke-Git {
    @() | & git -C $Root @args
    if ($LASTEXITCODE -ne 0) { throw "O comando 'git $($args -join ' ')' falhou." }
}

# Roda git em silencio e devolve se deu certo.
function Test-Git {
    $ErrorActionPreference = 'Continue'
    @() | & git -C $Root @args > $null 2> $null
    return ($LASTEXITCODE -eq 0)
}

# Poe no commit tudo que mudou, relendo o CONTEUDO de cada arquivo do servidor.
# O git do Windows normalmente decide o que mudou pela data e tamanho da pasta,
# e esses dados ficam desatualizados enquanto o Minecraft mantem os arquivos
# abertos: um backup com o servidor rodando sairia velho ou com arquivos vazios.
# Tirar server/ do indice forca a releitura, e core.fscache=false faz o git
# perguntar o tamanho real de cada arquivo.
function Add-World {
    Invoke-Git rm -r --cached --quiet --ignore-unmatch server
    Invoke-Git -c core.fscache=false add -A
}

function Read-Lock {
    if (Test-Path $LockPath) {
        return (Get-Content $LockPath -Raw | ConvertFrom-Json)
    }
    return $null
}

$SignalFormat = 'yyyy-MM-dd HH:mm:ss'

# Grava a trava com o "sinal de vida" (hora UTC) atualizado.
function Write-Lock($since, $address) {
    $data = [ordered]@{
        host     = $Me
        desde    = $since
        endereco = $address
        sinalUtc = (Get-Date).ToUniversalTime().ToString($SignalFormat)
    }
    [IO.File]::WriteAllText($LockPath, ($data | ConvertTo-Json) + "`n")
}

# Ha quantos minutos o host deu o ultimo sinal ($null se a trava nao tem sinal).
function Get-SignalAge($lock) {
    if (-not $lock -or -not $lock.sinalUtc) { return $null }
    try {
        $styles = [Globalization.DateTimeStyles]'AssumeUniversal, AdjustToUniversal'
        $when = [datetime]::ParseExact([string]$lock.sinalUtc, $SignalFormat, [Globalization.CultureInfo]::InvariantCulture, $styles)
        return [int][Math]::Max(0, ((Get-Date).ToUniversalTime() - $when).TotalMinutes)
    } catch { return $null }
}

# Sem sinal por mais de dois intervalos de backup: o host provavelmente caiu.
function Test-SignalStale($lock) {
    $age = Get-SignalAge $lock
    if ($null -eq $age -or $BackupMinutes -le 0) { return $false }
    return ($age -gt ($BackupMinutes * 2 + 5))
}

function Get-RemoteLock {
    $ErrorActionPreference = 'Continue'
    $raw = @() | & git -C $Root show "origin/${Branch}:$LockName" 2> $null
    if ($LASTEXITCODE -eq 0 -and $raw) {
        return (($raw -join "`n") | ConvertFrom-Json)
    }
    return $null
}

function Get-RadminIp {
    $addr = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -like '*Radmin*' } |
        Select-Object -First 1
    if ($addr) { return $addr.IPAddress }
    return $null
}

function Get-ServerPort {
    $props = Join-Path $ServerDir 'server.properties'
    if (Test-Path $props) {
        $line = Get-Content $props | Where-Object { $_ -match '^server-port=(\d+)' } | Select-Object -First 1
        if ($line -match '^server-port=(\d+)') { return $Matches[1] }
    }
    return '25565'
}

function Show-Lock($lock) {
    Write-Host "    Host:   $($lock.host)"
    Write-Host "    Desde:  $($lock.desde)"
    if ($lock.endereco) { Write-Host "    Entrar: $($lock.endereco)" }
    $age = Get-SignalAge $lock
    if ($null -ne $age) {
        if (Test-SignalStale $lock) {
            Write-Host "    Sinal:  ha $age min  <-- sem sinal ha muito tempo, o host pode ter caido" -ForegroundColor Yellow
        } else {
            Write-Host "    Sinal:  ha $age min"
        }
    }
}

function Push-WithRetry {
    for ($i = 1; $i -le 3; $i++) {
        @() | & git -C $Root push -u origin $Branch | Out-Host
        if ($LASTEXITCODE -eq 0) { return $true }
        if ($i -lt 3) {
            Write-Host "    Envio falhou (tentativa $i de 3). Tentando de novo em 5s..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }
    return $false
}

# Tira a trava, commita o mundo e envia. $closedMessage, se houver, e o aviso
# que vai para o Discord quando o envio da certo.
function Save-AndRelease($closedMessage) {
    Emit 'STATE@@saving'
    Say 'Salvando o mundo no GitHub...'
    if (Test-Path $LockPath) { Remove-Item $LockPath -Force }
    Add-World
    if (-not (Test-Git diff --cached --quiet)) {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        Invoke-Git commit --quiet -m "Mundo salvo por $Me ($stamp)"
    }
    if (Push-WithRetry) {
        Say 'Mundo salvo e trava liberada. Outra pessoa ja pode hostear.' 'Green'
        if ($closedMessage) { Send-Discord $closedMessage | Out-Null }
    } else {
        if ($closedMessage) {
            Send-Discord "$IconWarn **$Me** fechou o servidor, mas o mundo ainda n$([char]0xE3)o foi enviado ao GitHub. N$([char]0xE3)o assumam o servidor at$([char]0xE9) isso ser resolvido." | Out-Null
        }
        Write-Host ''
        Write-Host '!!! O MUNDO NAO FOI ENVIADO PARA O GITHUB !!!' -ForegroundColor Red
        Write-Host 'Seu progresso esta salvo so neste PC e a trava continua no seu nome.' -ForegroundColor Red
        Write-Host 'Confira a internet e rode salvar.bat antes de qualquer outra pessoa hostear.' -ForegroundColor Red
    }
}

# O texto apareceu no log do servidor depois da posicao $offset?
function Test-LogContains($path, $offset, $text) {
    if (-not (Test-Path $path)) { return $false }
    $stream = New-Object IO.FileStream($path, 'Open', 'Read', 'ReadWrite')
    try {
        if ($offset -gt $stream.Length) { $offset = 0 }   # o log foi trocado (virou o dia)
        $stream.Position = $offset
        $reader = New-Object IO.StreamReader($stream)
        return $reader.ReadToEnd().Contains($text)
    } finally { $stream.Dispose() }
}

# O servidor terminou de carregar? Ele escreve "Done (12.3s)!" no log quando
# fica pronto. A data do arquivo descarta o log que sobrou da sessao anterior.
function Test-ServerReady($logPath, $startTime) {
    if (-not (Test-Path $logPath)) { return $false }
    if ((Get-Item $logPath).LastWriteTime -lt $startTime) { return $false }
    return (Test-LogContains $logPath 0 ']: Done (')
}

# Backup com o servidor aberto: pausa o autosave, manda gravar tudo, faz o
# commit com os arquivos parados e so entao religa o autosave e envia.
function Backup-World($server) {
    Say 'Backup automatico: gravando o mundo...'
    $logPath = Join-Path $ServerDir 'logs\latest.log'
    $offset = 0
    if (Test-Path $logPath) { $offset = (Get-Item $logPath).Length }

    $saved = $false
    try {
        $server.StandardInput.WriteLine('save-off')
        $server.StandardInput.WriteLine('save-all flush')
        $deadline = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $deadline -and -not $server.HasExited) {
            Start-Sleep -Milliseconds 500
            if (Test-LogContains $logPath $offset 'Saved the game') { $saved = $true; break }
        }
        if ($saved) {
            $lock = Read-Lock
            Write-Lock $lock.desde $lock.endereco
            Add-World
            Invoke-Git commit --quiet -m "Backup automatico ($Me, $(Get-Date -Format 'HH:mm'))"
        }
    } finally {
        if (-not $server.HasExited) { $server.StandardInput.WriteLine('save-on') }
    }

    if (-not $saved) {
        Out-Line '    O servidor nao confirmou a gravacao. Tento de novo no proximo backup.' 'Yellow'
        return
    }

    @() | & git -C $Root push -u origin $Branch | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Out-Line '    Backup enviado.' 'Green'
        return
    }
    # O envio falhou: internet fora, ou alguem assumiu o servidor achando que este PC caiu.
    Test-Git fetch origin --quiet | Out-Null
    $behind = 0
    if (Test-Git rev-parse --verify --quiet "refs/remotes/origin/$Branch") {
        $behind = [int](Invoke-Git rev-list --count "HEAD..origin/$Branch")
    }
    if ($behind -gt 0) {
        Out-Line '    !!! OUTRA PESSOA ASSUMIU O SERVIDOR. O que for jogado aqui NAO sera salvo. !!!' 'Red'
        Out-Line '    Feche este servidor (stop) e entrem no servidor dela.' 'Red'
    } else {
        Out-Line '    Nao consegui enviar o backup (sem internet?). Tento de novo no proximo.' 'Yellow'
    }
}

function Get-JavaMajor($exe) {
    $ErrorActionPreference = 'Continue'
    $out = & cmd /c "`"$exe`" -version 2>&1"
    if (($out -join ' ') -match 'version "(\d+)(?:\.(\d+))?') {
        $major = [int]$Matches[1]
        if ($major -eq 1 -and $Matches[2]) { $major = [int]$Matches[2] }   # "1.8" = Java 8
        return $major
    }
    return 0
}

# Devolve o caminho de um java.exe na versao exigida, baixando um Java
# portatil (Eclipse Temurin) para .runtime se o PC nao tiver.
function Get-Java($required) {
    $portableDir = Join-Path $RuntimeDir "java-$required"
    if (Test-Path $portableDir) {
        $found = Get-ChildItem $portableDir -Recurse -Filter 'java.exe' | Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    $system = Get-Command java -ErrorAction SilentlyContinue
    if ($system -and (Get-JavaMajor $system.Source) -ge $required) { return $system.Source }

    Say "Java $required nao encontrado. Baixando uma copia portatil (so na primeira vez)..."
    New-Item -ItemType Directory -Force $RuntimeDir | Out-Null
    $zip = Join-Path $RuntimeDir "java-$required.zip"
    $url = "https://api.adoptium.net/v3/binary/latest/$required/ga/windows/x64/jre/hotspot/normal/eclipse"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -UserAgent $UserAgent
    Expand-Archive -Path $zip -DestinationPath $portableDir -Force
    Remove-Item $zip -Force
    $found = Get-ChildItem $portableDir -Recurse -Filter 'java.exe' | Select-Object -First 1
    if (-not $found) { throw 'Nao consegui preparar o Java portatil.' }
    return $found.FullName
}

# Devolve o nome do .jar do Paper na versao do config.json, baixando se faltar.
function Get-PaperJar($version) {
    $existing = Get-ChildItem $ServerDir -Filter "paper-$version-*.jar" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($existing) { return $existing.Name }

    Say "Baixando o Paper $version (so na primeira vez)..."
    $api = "https://fill.papermc.io/v3/projects/paper/versions/$version/builds/latest"
    $build = Invoke-RestMethod -Uri $api -UserAgent $UserAgent
    $download = $build.downloads.'server:default'
    $target = Join-Path $ServerDir $download.name
    Invoke-WebRequest -Uri $download.url -OutFile $target -UseBasicParsing -UserAgent $UserAgent

    $hash = (Get-FileHash $target -Algorithm SHA256).Hash
    if ($hash -ne $download.checksums.sha256) {
        Remove-Item $target -Force
        throw 'O download do Paper veio corrompido. Tente de novo.'
    }
    # apaga jars de versoes antigas
    Get-ChildItem $ServerDir -Filter 'paper-*.jar' | Where-Object { $_.Name -ne $download.name } | Remove-Item -Force
    return $download.name
}

function Confirm-Eula {
    $eula = Join-Path $ServerDir 'eula.txt'
    if ((Test-Path $eula) -and ((Get-Content $eula -Raw) -match 'eula\s*=\s*true')) { return $true }

    Say 'Licenca do Minecraft (EULA)' 'Yellow'
    Write-Host '    Para rodar o servidor e preciso aceitar a EULA da Mojang:'
    Write-Host '    https://aka.ms/MinecraftEULA'
    if (-not (Confirm-Yes '    Voce leu e aceita a EULA?' 'eula')) { return $false }
    [IO.File]::WriteAllText($eula, "eula=true`n")
    return $true
}

# ---------------------------------------------------------------- preparo

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 'Git nao esta instalado. Instale em https://git-scm.com/download/win e rode de novo.'
}
if (-not (Test-Git rev-parse --git-dir)) {
    Fail 'Esta pasta nao e um repositorio git. Clone o repositorio do servidor em vez de baixar o ZIP.'
}
if (-not (Test-Git remote get-url origin)) {
    Fail "O repositorio nao tem um remoto 'origin'. Veja o README (secao 'Primeira configuracao')."
}

$Config = Get-Content (Join-Path $Root 'config.json') -Raw | ConvertFrom-Json
$WebhookUrl = [string]$Config.discordWebhook   # vazio = sem avisos no Discord
$BackupMinutes = 20   # intervalo do backup automatico; 0 desliga
if ($null -ne $Config.backupMinutos) { $BackupMinutes = [double]$Config.backupMinutos }
$Branch = (Invoke-Git rev-parse --abbrev-ref HEAD)

$Me = (@() | & git -C $Root config user.name)
if (-not $Me -and $Gui) { $Me = $env:USERNAME }
if (-not (@() | & git -C $Root config user.name)) {
    if (-not $Me) { $Me = Read-Host 'Qual seu nome/nick? (aparece para os outros quando voce hosteia)' }
    if (-not $Me) { Fail 'Preciso de um nome para identificar quem esta hosteando.' }
    Invoke-Git config user.name $Me
}
if (-not (@() | & git -C $Root config user.email)) {
    Invoke-Git config user.email "$($Me -replace '\s', '')@users.noreply.github.com"
}

Say 'Buscando o estado mais recente no GitHub...'
Invoke-Git fetch origin --prune --quiet
$HasRemoteBranch = Test-Git rev-parse --verify --quiet "refs/remotes/origin/$Branch"

# ---------------------------------------------------------------- status

if ($Status) {
    $remoteLock = Get-RemoteLock
    if ($Gui) {
        $localLock = Read-Lock
        $ahead = 0
        if ($HasRemoteBranch) { $ahead = [int](Invoke-Git rev-list --count "origin/$Branch..HEAD") }
        $info = [ordered]@{
            eu          = $Me
            trava       = $remoteLock
            pendente    = [bool](($localLock -and $localLock.host -eq $Me) -or ($ahead -gt 0))
            rodandoAqui = [bool](Test-LocalSession)
            semSinalMin = (Get-SignalAge $remoteLock)
            semSinal    = [bool](Test-SignalStale $remoteLock)
            backupMin   = $BackupMinutes
            discord     = [bool]$WebhookUrl
        }
        Emit ('STATUS@@' + ($info | ConvertTo-Json -Compress))
        exit 0
    }
    if ($remoteLock) {
        Say 'Servidor ONLINE' 'Green'
        Show-Lock $remoteLock
    } else {
        Say 'Ninguem esta hosteando agora. Rode iniciar.bat para hostear.' 'Yellow'
    }
    exit 0
}

# ---------------------------------------------------------------- outra janela

if (Test-LocalSession) {
    Fail 'O servidor ja esta aberto em outra janela neste PC. Feche por la (stop) antes.'
}

# ---------------------------------------------------------------- discord

if ($PSBoundParameters.ContainsKey('SetWebhook')) {
    $url = $SetWebhook.Trim()
    if ($url -eq 'ask') {
        Write-Host ''
        Write-Host 'No Discord: Editar canal > Integracoes > Webhooks > Novo webhook > Copiar URL do webhook.'
        $url = (Read-Host 'Cole o link do webhook (ou deixe vazio para desligar os avisos)').Trim()
    }
    if ($url -eq 'off') { $url = '' }
    if ($url -and $url -notmatch '^https://([a-z]+\.)?discord(app)?\.com/api/webhooks/\d+/[\w-]+$') {
        Fail 'Isso nao parece um link de webhook do Discord. Ele comeca com https://discord.com/api/webhooks/'
    }

    # A configuracao vai num commit proprio. Com o servidor aberto esse commit
    # atropelaria os backups do host, entao so e permitido com ele fechado.
    if (Get-RemoteLock) { Fail 'O servidor esta aberto. Espere fechar para mudar a configuracao.' }
    $ahead = 0
    if ($HasRemoteBranch) { $ahead = [int](Invoke-Git rev-list --count "origin/$Branch..HEAD") }
    if ((Read-Lock) -or $ahead -gt 0 -or (@() | & git -C $Root status --porcelain)) {
        Fail 'Este PC tem uma sessao ou alteracoes que ainda nao foram enviadas. Resolva isso primeiro (Enviar mundo agora / salvar.bat).'
    }
    if ($HasRemoteBranch -and -not (Test-Git merge --ff-only "origin/$Branch")) {
        Fail 'Seu repositorio local divergiu do GitHub.'
    }

    if ($url) {
        Say 'Mandando uma mensagem de teste para o Discord...'
        $hello = "$IconOpen Avisos do **Minecraft Compartilhado** ligados por **$Me**. Este canal vai avisar quando o servidor abrir e fechar."
        if (-not (Send-Discord $hello $url)) {
            Fail 'O Discord nao aceitou esse link. Confira se copiou o webhook inteiro e se ele ainda existe.'
        }
    }

    $Config = Get-Content (Join-Path $Root 'config.json') -Raw | ConvertFrom-Json   # relido apos o merge
    $Config | Add-Member -NotePropertyName discordWebhook -NotePropertyValue $url -Force
    [IO.File]::WriteAllText((Join-Path $Root 'config.json'), ($Config | ConvertTo-Json) + "`n")
    Invoke-Git add config.json
    if (Test-Git diff --cached --quiet) {
        Say 'A configuracao ja estava assim. Nada mudou.' 'Green'
        exit 0
    }
    if ($url) { $what = 'Liga' } else { $what = 'Desliga' }
    Invoke-Git commit --quiet -m "$what os avisos no Discord ($Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar a configuracao para o GitHub. Nada foi alterado.'
    }
    if ($url) {
        Say 'Avisos no Discord ligados para o grupo todo.' 'Green'
    } else {
        Say 'Avisos no Discord desligados.' 'Green'
    }
    exit 0
}

# ---------------------------------------------------------------- so salvar

if ($SaveOnly) {
    $lock = Read-Lock
    $ahead = 0
    if ($HasRemoteBranch) { $ahead = [int](Invoke-Git rev-list --count "origin/$Branch..HEAD") }
    if ($lock -and $lock.host -eq $Me) {
        Save-AndRelease "$IconClosed **$Me** enviou o mundo da sess$([char]0xE3)o que tinha ficado pendente. Servidor livre para hostear."
    } elseif ($ahead -gt 0) {
        Say 'Enviando o que ficou pendente...'
        if (Push-WithRetry) { Say 'Enviado.' 'Green' } else { Fail 'O envio falhou de novo. Confira a internet e o login do GitHub.' }
    } else {
        Say 'Nada pendente para salvar.' 'Green'
    }
    exit 0
}

# ---------------------------------------------------------------- sincronizar

$lock = Read-Lock
$resume = $false
$tookOverFrom = $null

if ($lock -and $lock.host -eq $Me) {
    # Minha ultima sessao nao fechou direito (janela fechada, PC desligou...).
    $behind = 0
    if ($HasRemoteBranch) { $behind = [int](Invoke-Git rev-list --count "HEAD..origin/$Branch") }
    if ($behind -gt 0) {
        Say 'Sua ultima sessao nao foi salva e outra pessoa ja hosteou depois.' 'Yellow'
        Write-Host '    O progresso que ficou so no seu PC precisa ser descartado para continuar.'
        if (-not (Confirm-Yes '    Descartar e usar a versao do GitHub?' 'descartar-superada')) { exit 1 }
        Invoke-Git reset --hard --quiet "origin/$Branch"
        Invoke-Git clean -fd --quiet
    } else {
        Say 'Sua ultima sessao nao fechou direito. Continuando de onde parou neste PC.' 'Yellow'
        $resume = $true
        # renova o sinal de vida para os outros verem que este PC voltou
        Write-Lock $lock.desde $lock.endereco
        Add-World
        Invoke-Git commit --quiet -m "$Me voltou a hostear"
        if (-not (Push-WithRetry)) {
            Fail 'Nao consegui enviar para o GitHub. Confira a internet e tente de novo.'
        }
    }
}

if (-not $resume) {
    if (@() | & git -C $Root status --porcelain) {
        Say 'Existem alteracoes neste PC que nao estao no GitHub:' 'Yellow'
        @() | & git -C $Root status --short | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" }
        if (-not (Confirm-Yes '    Descartar essas alteracoes e usar a versao do GitHub?' 'descartar-local')) { exit 1 }
        Invoke-Git reset --hard --quiet
        Invoke-Git clean -fd --quiet
    }

    if ($HasRemoteBranch) {
        if (-not (Test-Git merge --ff-only "origin/$Branch")) {
            Fail "Seu repositorio local divergiu do GitHub. Se voce tem progresso nao enviado, rode salvar.bat; senao rode: git reset --hard origin/$Branch"
        }
    }

    $lock = Read-Lock
    if ($lock -and $lock.host -ne $Me) {
        Say 'O servidor ja esta sendo hosteado:' 'Yellow'
        Show-Lock $lock
        if (-not $Force) {
            Write-Host ''
            Write-Host '    Entre no endereco acima para jogar.'
            Write-Host '    Se essa pessoa caiu e nao vai voltar, rode forcar.bat para assumir.'
            exit 0
        }
        Write-Host ''
        Write-Host "    Assumir vai usar o ultimo backup. O que $($lock.host) jogou depois dele sera perdido." -ForegroundColor Red
        if (-not (Confirm-Yes '    Assumir mesmo assim?' "assumir@@$($lock.host)")) { exit 1 }
        $tookOverFrom = $lock.host
    }

    # Pega a trava. O push e o que decide: se duas pessoas tentarem ao mesmo
    # tempo, o GitHub aceita so o primeiro.
    $ip = Get-RadminIp
    $address = $null
    if ($ip) { $address = "${ip}:$(Get-ServerPort)" }
    Write-Lock (Get-Date -Format 'yyyy-MM-dd HH:mm') $address
    Invoke-Git add $LockName
    Invoke-Git commit --quiet -m "$Me comecou a hostear"

    Say 'Reservando o servidor...'
    @() | & git -C $Root push -u origin $Branch | Out-Host
    if ($LASTEXITCODE -ne 0) {
        $before = $null
        if ($HasRemoteBranch) { $before = (Invoke-Git rev-parse "origin/$Branch") }
        Test-Git fetch origin --quiet | Out-Null
        $after = $null
        if (Test-Git rev-parse --verify --quiet "refs/remotes/origin/$Branch") { $after = (Invoke-Git rev-parse "origin/$Branch") }

        if ($after -and $after -ne $before) {
            Invoke-Git reset --hard --quiet "origin/$Branch"
            Say 'Outra pessoa comecou a hostear no mesmo instante:' 'Yellow'
            $other = Read-Lock
            if ($other) { Show-Lock $other }
            exit 0
        }
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar para o GitHub. Confira a internet, o login e se voce tem permissao de escrita no repositorio.'
    }
    if ($tookOverFrom) {
        Send-Discord "$IconSwap **$Me** assumiu o servidor que estava com **$tookOverFrom**, a partir do $([char]0xFA)ltimo backup." | Out-Null
    }
}

# ---------------------------------------------------------------- servidor

$server = $null
$announcedOpen = $false
try {
    New-Item -ItemType Directory -Force $ServerDir | Out-Null
    New-Item -ItemType Directory -Force $RuntimeDir | Out-Null
    [IO.File]::WriteAllText($PidPath, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)")
    if (Confirm-Eula) {
        $java = Get-Java ([int]$Config.javaVersao)
        $jar  = Get-PaperJar $Config.versaoMinecraft

        Say 'Servidor iniciando!' 'Green'
        $ip = Get-RadminIp
        if ($ip) {
            Write-Host "    Seus amigos entram em: ${ip}:$(Get-ServerPort)" -ForegroundColor Green
        } else {
            Write-Host '    Radmin VPN nao encontrado neste PC. Abra o Radmin e entre na rede do grupo.' -ForegroundColor Yellow
        }
        Write-Host '    Para fechar e salvar: digite  stop  e aperte Enter. NAO feche a janela no X.'
        Write-Host ''

        # terminal.jline=false: o servidor le comandos como texto simples, porque
        # quem entrega os comandos a ele e este script (ver o laco abaixo).
        $javaArgs = "-Xms$($Config.memoria) -Xmx$($Config.memoria) -Dterminal.jline=false -jar `"$jar`" nogui"
        if ($Gui) { $javaArgs = "-Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 $javaArgs" }
        $shown = ''
        if ($ip) { $shown = "${ip}:$(Get-ServerPort)" }
        Emit "STATE@@running@@$shown"
        # A entrada do servidor passa por este script: assim ele repassa o que
        # voce digita (ou o que a interface manda) e tambem consegue mandar os
        # comandos do backup automatico. A saida do servidor vai direto para a tela.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $java
        $psi.Arguments = $javaArgs
        $psi.WorkingDirectory = $ServerDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $server = [System.Diagnostics.Process]::Start($psi)

        $keyboard = New-Object IO.StreamReader([Console]::OpenStandardInput())
        $typed = $keyboard.ReadLineAsync()
        $queued = New-Object System.Collections.Generic.List[string]
        $logPath = Join-Path $ServerDir 'logs\latest.log'
        $ready = $false
        $nextBackup = $null
        $orphanDeadline = $null
        $ticks = 0

        while (-not $server.WaitForExit(250)) {
            $ticks++

            # O servidor rejeita (e perde) qualquer comando que chegue antes de ele
            # terminar de carregar, inclusive "stop". Por isso os comandos ficam
            # na fila ate ele estar pronto, e o relogio do backup so comeca ai.
            if (-not $ready -and ($ticks % 4 -eq 0) -and (Test-ServerReady $logPath $server.StartTime)) {
                $ready = $true
                $nextBackup = (Get-Date).AddMinutes($BackupMinutes)
                if ($shown) {
                    $where = "Entrem por: ``$shown``"
                } else {
                    $where = "Pe$([char]0xE7)am o endere$([char]0xE7)o para **$Me**."
                }
                Send-Discord "$IconOpen **$Me** abriu o servidor de Minecraft! $where" | Out-Null
                $announcedOpen = $true
            }

            # recolhe as linhas ja digitadas (ou mandadas pela interface)
            while ($typed -and $typed.IsCompleted) {
                $line = $typed.Result
                if ($null -eq $line) { $typed = $null; break }   # entrada fechada
                $queued.Add($line)
                $typed = $keyboard.ReadLineAsync()
            }

            # Se a interface morreu, ninguem mais consegue mandar "stop": fecha o
            # servidor para nao ficar um processo escondido segurando a trava.
            if ($ParentPid -and ($ticks % 8 -eq 0) -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) {
                if (-not $orphanDeadline) {
                    $queued.Add('stop')
                    $orphanDeadline = (Get-Date).AddMinutes(5)
                } elseif ((Get-Date) -gt $orphanDeadline) {
                    $server.Kill()
                }
            }

            if ($ready -and $queued.Count -gt 0) {
                foreach ($line in $queued) { $server.StandardInput.WriteLine($line) }
                $queued.Clear()
            }

            if ($ready -and $BackupMinutes -gt 0 -and -not $orphanDeadline -and (Get-Date) -ge $nextBackup) {
                try { Backup-World $server } catch { Out-Line "    Backup automatico falhou: $_" 'Yellow' }
                $nextBackup = (Get-Date).AddMinutes($BackupMinutes)
            }
        }
    } else {
        Say 'EULA nao aceita. O servidor nao foi iniciado.' 'Yellow'
    }
}
catch {
    Write-Host ''
    Write-Host "ERRO: $_" -ForegroundColor Red
}
finally {
    # Em caso de Ctrl+C, espera o Minecraft terminar de gravar o mundo.
    if ($server -and -not $server.HasExited) {
        Write-Host 'Esperando o servidor terminar de gravar o mundo...'
        $server.WaitForExit(120000) | Out-Null
    }
    Remove-Item $PidPath -Force -ErrorAction SilentlyContinue
    $closedMessage = $null
    if ($announcedOpen) {
        $closedMessage = "$IconClosed **$Me** fechou o servidor. Mundo salvo; quem quiser j$([char]0xE1) pode hostear."
    }
    Save-AndRelease $closedMessage
}
