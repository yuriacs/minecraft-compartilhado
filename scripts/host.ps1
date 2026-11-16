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
    [string]$SetWebhook,# grava o link do webhook do Discord no config.json e sai
                        # ("ask" pergunta no console; "off" desliga os avisos)
    [switch]$ListSaves, # lista os saves guardados no historico
    [string]$Restore,   # volta o mundo para o save indicado (hash do commit)
    [int]$Prune,        # compacta o historico, mantendo so os ultimos N saves
    [switch]$SetTunnel, # grava a chave e o endereco do tunel (playit.gg) no config.json e sai;
                        # le duas linhas da entrada: a chave e o endereco (chave vazia = desliga)
    [switch]$ListVersions,   # lista as versoes do Minecraft disponiveis
    [string]$SetServer,      # troca o tipo e a versao do servidor: "paper|26.3" ou "fabric|26.3"
    [string]$SaveChanges,    # envia o que mudou em server/ (plugins, mods), com esta mensagem
    [switch]$SyncOnly,       # so traz o estado mais recente do GitHub para este PC
    [switch]$UpdateProgram,  # atualiza os scripts do programa para a ultima versao publicada
    [string]$SetDirect,      # "on"/"off": liga ou desliga a conexao direta (porta no roteador)
    [string]$InspectPack,    # examina um modpack (.zip de servidor ou .mrpack) e diz o que achou
    [string]$ImportPack      # importa o modpack: "caminho|tipo|versao|loader[|mundo-novo]"
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
$ConfigPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $ConfigPath)) { $ConfigPath = Join-Path $Root 'config.json' }   # lugar antigo
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
    # segundo endereco, para quando o primeiro (conexao direta) nao funcionar
    if ($ReserveAddress) { $data.reserva = $ReserveAddress }
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

# Endereco que os amigos usam para entrar: o do tunel, se estiver ligado, ou
# o IP do Radmin deste PC. Vazio quando nao da para saber.
function Get-JoinAddress {
    if ($DirectAddress) { return $DirectAddress }
    if ($TunnelKey) { return $TunnelAddress }
    $ip = Get-RadminIp
    if ($ip) { return "${ip}:$(Get-ServerPort)" }
    return ''
}

# ---- conexao direta (porta aberta no roteador)
#
# Pede ao roteador deste PC, por UPnP, para encaminhar a porta do servidor.
# Quando da certo os amigos conectam direto no IP publico do host, sem VPN e
# sem passar por terceiros. Nao funciona se o roteador tiver o UPnP desligado
# ou se a operadora compartilhar o IP entre varios clientes (CGNAT).
$DirectAddress = ''    # "ip:porta" quando a porta foi aberta nesta sessao
$DirectPort = 0
$ReserveAddress = ''   # endereco alternativo gravado na trava

# IPv4 que funciona de fora? (descarta redes internas e a faixa de CGNAT)
function Test-PublicIp($text) {
    $ip = $null
    if (-not [Net.IPAddress]::TryParse([string]$text, [ref]$ip)) { return $false }
    if ($ip.AddressFamily -ne 'InterNetwork') { return $false }
    $b = $ip.GetAddressBytes()
    if ($b[0] -eq 10 -or $b[0] -eq 127 -or $b[0] -eq 0) { return $false }
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return $false }
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $false }
    if ($b[0] -eq 169 -and $b[1] -eq 254) { return $false }
    if ($b[0] -eq 100 -and $b[1] -ge 64 -and $b[1] -le 127) { return $false }   # CGNAT
    return $true
}

# IP deste PC na rede de casa: o da placa por onde sai a internet (nao o de
# VPNs como o Radmin, que tambem tem "gateway").
function Get-LanIp {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object { $_.RouteMetric + (Get-NetIPInterface -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric } |
        Select-Object -First 1
    if (-not $route) { return $null }
    return (Get-NetIPAddress -InterfaceIndex $route.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
}

# Acha o roteador pela rede local (busca SSDP) e devolve por onde mandar os
# pedidos de porta: @{ Url; Service }. $null se nenhum roteador responder.
# Falamos com o roteador direto, sem a API de UPnP do Windows, porque ela nao
# funciona quando a rede esta marcada como "Publica".
function Find-RouterControl($localIp) {
    $locations = @()
    if ($env:MC_TESTE_UPNP) {
        $locations = @($env:MC_TESTE_UPNP)   # so para os testes: endereco de um roteador simulado
    } else {
        $udp = New-Object Net.Sockets.UdpClient ([Net.IPEndPoint]::new([Net.IPAddress]::Parse($localIp), 0))
        try {
            $udp.Client.ReceiveTimeout = 2500
            foreach ($target in 'urn:schemas-upnp-org:device:InternetGatewayDevice:1', 'urn:schemas-upnp-org:service:WANIPConnection:1', 'urn:schemas-upnp-org:service:WANPPPConnection:1') {
                $bytes = [Text.Encoding]::ASCII.GetBytes("M-SEARCH * HTTP/1.1`r`nHOST: 239.255.255.250:1900`r`nMAN: `"ssdp:discover`"`r`nMX: 2`r`nST: $target`r`n`r`n")
                [void]$udp.Send($bytes, $bytes.Length, '239.255.255.250', 1900)
            }
            $deadline = (Get-Date).AddSeconds(4)
            while ((Get-Date) -lt $deadline) {
                try {
                    $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
                    $answer = [Text.Encoding]::ASCII.GetString($udp.Receive([ref]$remote))
                    if ($answer -match '(?im)^LOCATION:\s*(\S+)') { $locations += $Matches[1] }
                } catch { break }
            }
        } finally { $udp.Close() }
    }
    foreach ($location in ($locations | Select-Object -Unique)) {
        try {
            $xml = [string](Invoke-WebRequest -Uri $location -UseBasicParsing -TimeoutSec 6).Content
            foreach ($block in [regex]::Matches($xml, '(?s)<service>.*?</service>')) {
                if ($block.Value -match '<serviceType>\s*(urn:schemas-upnp-org:service:WAN(?:IP|PPP)Connection:\d)\s*</serviceType>') {
                    $service = $Matches[1]
                    if ($block.Value -match '<controlURL>\s*([^<\s]+)\s*</controlURL>') {
                        $url = [Uri]::new([Uri]$location, $Matches[1]).AbsoluteUri
                        return @{ Url = $url; Service = $service }
                    }
                }
            }
        } catch { }
    }
    return $null
}

# Manda um pedido ao roteador (SOAP) e devolve a resposta em texto.
function Invoke-RouterAction($control, $action, $arguments) {
    $body = '<?xml version="1.0"?>' +
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' +
        "<s:Body><u:$action xmlns:u=`"$($control.Service)`">$arguments</u:$action></s:Body></s:Envelope>"
    $headers = @{ SOAPAction = "`"$($control.Service)#$action`"" }
    $response = Invoke-WebRequest -Uri $control.Url -Method Post -Body $body -ContentType 'text/xml; charset="utf-8"' -Headers $headers -UseBasicParsing -TimeoutSec 8
    return [string]$response.Content
}

$RouterControl = $null   # roteador em que esta sessao abriu a porta

function Open-DirectConnection {
    $script:DirectAddress = ''
    $script:ReserveAddress = ''
    if (-not $DirectEnabled) { return }
    Say 'Tentando a conexao direta (abrir a porta no roteador)...'
    $reason = ''
    try {
        $port = [int](Get-ServerPort)
        $localIp = Get-LanIp
        if (-not $localIp) { throw 'Nao achei o endereco deste PC na rede local.' }
        $control = Find-RouterControl $localIp
        if (-not $control) { throw 'O roteador nao respondeu: ele nao aceita abrir portas automaticamente (UPnP desligado ou nao suportado).' }

        $mapping = "<NewRemoteHost></NewRemoteHost><NewExternalPort>$port</NewExternalPort><NewProtocol>TCP</NewProtocol>" +
            "<NewInternalPort>$port</NewInternalPort><NewInternalClient>$localIp</NewInternalClient><NewEnabled>1</NewEnabled>" +
            '<NewPortMappingDescription>Minecraft Compartilhado</NewPortMappingDescription><NewLeaseDuration>0</NewLeaseDuration>'
        Invoke-RouterAction $control 'AddPortMapping' $mapping | Out-Null
        $script:RouterControl = $control
        $script:DirectPort = $port

        $external = ''
        if ((Invoke-RouterAction $control 'GetExternalIPAddress' '') -match '<NewExternalIPAddress>\s*([^<\s]*)\s*</NewExternalIPAddress>') { $external = $Matches[1] }
        if (-not (Test-PublicIp $external)) {
            throw "O roteador abriu a porta, mas o IP dele ($external) nao e alcancavel de fora: a operadora compartilha o IP entre varios clientes (CGNAT)."
        }
        $script:DirectAddress = $external
        if ($port -ne 25565) { $script:DirectAddress = "${external}:$port" }
        if ($TunnelKey -and $TunnelAddress) { $script:ReserveAddress = $TunnelAddress }
        Out-Line "    Porta aberta no roteador. Endereco direto: $($script:DirectAddress)" 'Green'
        return
    } catch {
        $reason = [string]$_.Exception.Message
    }
    Close-DirectConnection
    Out-Line "    Sem conexao direta. $reason" 'Yellow'
    if ($TunnelKey) {
        Out-Line '    Sigo pelo tunel.' 'Yellow'
    } else {
        Out-Line '    Sigo pelo Radmin.' 'Yellow'
    }
}

# Fecha a porta que esta sessao abriu no roteador.
function Close-DirectConnection {
    if (-not $script:DirectPort -or -not $script:RouterControl) { return }
    try {
        $mapping = "<NewRemoteHost></NewRemoteHost><NewExternalPort>$($script:DirectPort)</NewExternalPort><NewProtocol>TCP</NewProtocol>"
        Invoke-RouterAction $script:RouterControl 'DeletePortMapping' $mapping | Out-Null
    } catch { }
    $script:DirectPort = 0
    $script:RouterControl = $null
}

# ---- manter o PC acordado
#
# Se o PC de quem hosteia suspender, o servidor cai para todo mundo. Enquanto
# o servidor esta aberto pedimos ao Windows para nao suspender por inatividade.
function Set-KeepAwake($on) {
    try {
        if (-not ('McShared.Power' -as [type])) {
            Add-Type -Namespace McShared -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);'
        }
        $flags = [uint32]2147483648          # ES_CONTINUOUS
        if ($on) { $flags = [uint32]2147483649 }   # + ES_SYSTEM_REQUIRED
        [void][McShared.Power]::SetThreadExecutionState($flags)
    } catch { }
}

# Le o que o servidor escreveu no log desde a ultima leitura.
function Read-LogSince($path, [ref]$offset) {
    if (-not (Test-Path $path)) { return '' }
    $stream = New-Object IO.FileStream($path, 'Open', 'Read', 'ReadWrite')
    try {
        if ($offset.Value -gt $stream.Length) { $offset.Value = 0 }   # o log foi trocado
        $stream.Position = $offset.Value
        $text = (New-Object IO.StreamReader($stream)).ReadToEnd()
        $offset.Value = $stream.Length
        return $text
    } finally { $stream.Dispose() }
}

# ---- tunel (playit.gg)
#
# O agente oficial do playit roda no Windows em modo portatil: um .exe que fica
# aberto enquanto o servidor esta no ar e le a chave do arquivo abaixo, na
# pasta do usuario. Nada e instalado no PC.
$PlayitSecretPath = Join-Path $env:LOCALAPPDATA 'playit_gg\playit.toml'
$PlayitSecretBackup = "$PlayitSecretPath.antes-do-minecraft-compartilhado"

# Baixa (uma vez) o agente oficial, da pagina de releases do playit no GitHub,
# e confere a assinatura digital do arquivo.
function Get-PlayitAgent {
    $folder = Join-Path $RuntimeDir 'playit'
    $exe = Join-Path $folder "playit-$PlayitVersion.exe"
    if (-not (Test-Path $exe)) {
        Say "Baixando o agente do tunel (playit $PlayitVersion, so na primeira vez)..."
        New-Item -ItemType Directory -Force $folder | Out-Null
        $arch = 'x86_64'
        if (-not [Environment]::Is64BitOperatingSystem) { $arch = 'x86' }
        $url = "https://github.com/playit-cloud/playit-agent/releases/download/v$PlayitVersion/playit-windows-$arch-signed.exe"
        $partial = "$exe.baixando"
        Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing -UserAgent $UserAgent
        $signature = Get-AuthenticodeSignature $partial
        if ($signature.Status -ne 'Valid') {
            Remove-Item $partial -Force
            throw "O agente do tunel baixado nao tem assinatura digital valida ($($signature.Status)). Nao vou usa-lo."
        }
        Move-Item $partial $exe -Force
        Get-ChildItem $folder -Filter 'playit-*.exe' | Where-Object { $_.FullName -ne $exe } | Remove-Item -Force
    }
    return $exe
}

# Sobe o tunel. Devolve o processo do agente, ou $null se nao deu (o servidor
# continua abrindo; so nao fica acessivel de fora).
function Start-Tunnel {
    try {
        $exe = Get-PlayitAgent
        # A chave do grupo vai para o arquivo que o agente le. Se a pessoa ja usa
        # o playit por conta propria, a chave dela e guardada e devolvida no fim.
        New-Item -ItemType Directory -Force (Split-Path $PlayitSecretPath) | Out-Null
        if (Test-Path $PlayitSecretPath) {
            $current = (Get-Content $PlayitSecretPath -Raw)
            if ($current -notmatch [regex]::Escape($TunnelKey) -and -not (Test-Path $PlayitSecretBackup)) {
                Move-Item $PlayitSecretPath $PlayitSecretBackup -Force
            }
        }
        [IO.File]::WriteAllText($PlayitSecretPath, "secret_key = `"$TunnelKey`"`n")

        # O agente roda por tras de um cmd que grava a saida dele num arquivo:
        # e nessa saida que ele diz se a chave foi aceita.
        $log = Join-Path (Split-Path $exe) 'agente.log'
        Remove-Item $log -Force -ErrorAction SilentlyContinue
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$env:SystemRoot\System32\cmd.exe"
        $psi.Arguments = "/d /c `"`"$exe`" --stdout > `"$log`" 2>&1 < NUL`""
        $psi.WorkingDirectory = Split-Path $exe
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true    # entrada propria: nao pode herdar a deste script
        $agent = [System.Diagnostics.Process]::Start($psi)

        # da uns segundos para o agente falar com o playit e ve o que ele respondeu
        $verdict = 'ok'
        for ($i = 0; $i -lt 16; $i++) {
            Start-Sleep -Milliseconds 500
            if ($agent.HasExited) { $verdict = 'fechou'; break }
            if ((Test-Path $log) -and (Test-LogContains $log 0 'InvalidAgentKey')) { $verdict = 'chave'; break }
        }
        if ($verdict -eq 'chave') {
            Stop-Tunnel $agent
            Out-Line '    O playit recusou a chave do tunel (ela foi apagada ou trocada no site).' 'Red'
            Out-Line '    Cole a chave nova em Opcoes > Conexao por tunel. O servidor vai abrir, mas quem esta fora nao consegue entrar.' 'Red'
            return $null
        }
        if ($verdict -eq 'fechou') {
            Stop-Tunnel $null
            Out-Line '    O agente do tunel fechou logo ao abrir. O servidor vai abrir, mas quem esta fora nao consegue entrar.' 'Red'
            Out-Line "    Detalhes em $log. Se o playit ja estiver aberto neste PC, feche-o antes." 'Red'
            return $null
        }
        Out-Line '    Agente do tunel (playit.gg) iniciado.' 'Green'
        return $agent
    } catch {
        Stop-Tunnel $null
        Out-Line "    Nao consegui subir o tunel: $_" 'Red'
        Out-Line '    O servidor vai abrir, mas quem esta fora nao consegue entrar.' 'Red'
        return $null
    }
}

# Encerra o agente e tira a chave do grupo da pasta do usuario.
function Stop-Tunnel($agent) {
    try {
        if ($agent -and -not $agent.HasExited) {
            # /T: encerra o cmd e o agente que ele abriu
            @() | & taskkill /PID $agent.Id /T /F > $null 2> $null
            $agent.WaitForExit(5000) | Out-Null
        }
    } catch { }
    try {
        if (Test-Path $PlayitSecretPath) { Remove-Item $PlayitSecretPath -Force }
        if (Test-Path $PlayitSecretBackup) { Move-Item $PlayitSecretBackup $PlayitSecretPath -Force }
    } catch { }
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
    if ($lock.reserva) { Write-Host "    Se nao conectar, tente: $($lock.reserva)" }
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
        Write-Host 'Confira a internet e use "Enviar mundo agora" antes de qualquer outra pessoa hostear.' -ForegroundColor Red
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

# As tarefas de manutencao (configurar, restaurar, compactar) criam commits
# proprios. Com o servidor aberto eles atropelariam os backups do host, e com
# algo pendente neste PC se misturariam a ele; por isso exigem tudo parado.
function Assert-ServerIdle($what) {
    if (Get-RemoteLock) { Fail "O servidor esta aberto. Espere fechar para $what." }
    $ahead = 0
    if ($HasRemoteBranch) { $ahead = [int](Invoke-Git rev-list --count "origin/$Branch..HEAD") }
    if ((Read-Lock) -or $ahead -gt 0 -or (@() | & git -C $Root status --porcelain)) {
        Fail 'Este PC tem uma sessao ou alteracoes que ainda nao foram enviadas. Envie o mundo primeiro.'
    }
    if ($HasRemoteBranch -and -not (Test-Git merge --ff-only "origin/$Branch")) {
        Fail 'Seu repositorio local divergiu do GitHub.'
    }
}

# Data de um commit no horario deste PC.
function Get-CommitTime($commit) {
    $epoch = [long](Invoke-Git log -1 --format=%ct $commit)
    return [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
}

# Cria um commit novo com os mesmos arquivos, autor e data de $source, em cima
# de $parent (ou sem pai). Usado para compactar o historico: nada do mundo e
# reescrito, so a "linha do tempo" fica mais curta.
function Copy-Commit($source, $parent, $messageOverride) {
    $meta = @(Invoke-Git log -1 '--format=%an%n%ae%n%aI%n%cn%n%ce%n%cI' $source)
    if ($messageOverride) {
        $message = $messageOverride
    } else {
        $message = (@(Invoke-Git log -1 --format=%B $source) -join "`n").TrimEnd()
    }
    $messageFile = Join-Path $RuntimeDir 'commit-msg.txt'
    [IO.File]::WriteAllText($messageFile, $message + "`n")
    $tree = '{0}^{{tree}}' -f $source
    $env:GIT_AUTHOR_NAME = $meta[0];    $env:GIT_AUTHOR_EMAIL = $meta[1];    $env:GIT_AUTHOR_DATE = $meta[2]
    $env:GIT_COMMITTER_NAME = $meta[3]; $env:GIT_COMMITTER_EMAIL = $meta[4]; $env:GIT_COMMITTER_DATE = $meta[5]
    try {
        if ($parent) {
            return (Invoke-Git commit-tree $tree -p $parent -F $messageFile)
        }
        return (Invoke-Git commit-tree $tree -F $messageFile)
    } finally {
        foreach ($name in 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_AUTHOR_DATE', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_COMMITTER_DATE') {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        }
        Remove-Item $messageFile -Force -ErrorAction SilentlyContinue
    }
}

# Um commit que guarda um estado do mundo (e nao so a trava ou a configuracao).
$SavePattern = '^(Mundo salvo|Backup automatico|Mundo restaurado)'

function Get-GitFolderMb {
    $bytes = (Get-ChildItem (Join-Path $Root '.git') -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    return [Math]::Round($bytes / 1MB, 1)
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
    # so serve o Java do PC se for exatamente a versao pedida: servidores com
    # mods antigos nao rodam em Java mais novo
    if ($system -and (Get-JavaMajor $system.Source) -eq $required) { return $system.Source }

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

# Le uma lista em JSON de uma API. O Invoke-RestMethod devolve a lista inteira
# como um unico objeto; aqui ela vira uma lista normal, item por item.
function Get-JsonList($uri) {
    $response = Invoke-RestMethod -Uri $uri -UserAgent $UserAgent -TimeoutSec 20
    return @($response | ForEach-Object { $_ })
}

# Devolve o nome do .jar do servidor Fabric para a versao pedida, baixando se
# faltar. E o "server launcher" oficial do Fabric: um .jar unico que baixa o
# servidor da Mojang e carrega os mods da pasta server\mods.
function Get-FabricJar($version, $loader) {
    $pattern = "fabric-server-$version-*.jar"
    if ($loader) { $pattern = "fabric-server-$version-$loader.jar" }
    $existing = Get-ChildItem $ServerDir -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) { return $existing.Name }

    Say "Baixando o servidor Fabric $version (so na primeira vez)..."
    $meta = 'https://meta.fabricmc.net/v2/versions'
    if (-not $loader) { $loader = Resolve-LoaderVersion 'fabric' $version }
    if (-not $loader) { throw "O Fabric ainda nao tem versao para o Minecraft $version." }
    $installer = (@(Get-JsonList "$meta/installer") | Where-Object { $_.stable } | Select-Object -First 1).version
    if (-not $installer) { throw 'Nao consegui descobrir a versao do instalador do Fabric.' }

    $name = "fabric-server-$version-$loader.jar"
    $target = Join-Path $ServerDir $name
    Invoke-WebRequest -Uri "$meta/loader/$version/$loader/$installer/server/jar" -OutFile "$target.baixando" -UseBasicParsing -UserAgent $UserAgent
    if ((Get-Item "$target.baixando").Length -lt 10000) {
        Remove-Item "$target.baixando" -Force
        throw 'O download do servidor Fabric veio incompleto. Tente de novo.'
    }
    Move-Item "$target.baixando" $target -Force
    Get-ChildItem $ServerDir -Filter 'fabric-server-*.jar' | Where-Object { $_.Name -ne $name } | Remove-Item -Force
    return $name
}

# ---- modpacks
#
# Dois formatos sao aceitos:
#   - "Server Pack" (.zip), como os do CurseForge: um zip com a pasta mods e as
#     configuracoes do servidor. Nao tem formato padrao, entao o tipo e a
#     versao sao deduzidos do que houver dentro e a pessoa confere.
#   - .mrpack do Modrinth: traz um indice com o endereco e o hash de cada mod,
#     que e baixado direto do Modrinth.

# So aceita caminhos relativos e que fiquem dentro da pasta de destino.
function Test-SafeRelativePath($path) {
    $clean = ([string]$path) -replace '\\', '/'
    if (-not $clean -or $clean.StartsWith('/') -or $clean -match '^[A-Za-z]:' ) { return $false }
    foreach ($part in ($clean -split '/')) { if ($part -eq '..') { return $false } }
    return $true
}

# O que nao vem de um Server Pack: o que cada PC instala por conta propria e o
# que e do grupo (mundo, propriedades, licenca).
function Test-PackEntryWanted($relative) {
    $lower = $relative.ToLower()
    if ($lower -match '^(libraries|logs|crash-reports|world|\.git)(/|$)') { return $false }
    if ($lower -notmatch '/') {
        # arquivos soltos na raiz
        if ($lower -match '\.(jar|bat|sh|ps1|cmd|command|log|exe)$') { return $false }
        if ($lower -in 'eula.txt', 'server.properties', 'user_jvm_args.txt', 'variables.txt', 'ops.json', 'whitelist.json', 'banned-ips.json', 'banned-players.json', 'usercache.json') { return $false }
    }
    return $true
}

# Abre o modpack e descreve o que achou, sem alterar nada.
function Get-PackInfo($path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path $path)) { throw 'Nao achei esse arquivo.' }
    $info = [ordered]@{ formato = 'desconhecido'; nome = [IO.Path]::GetFileNameWithoutExtension($path); tipo = ''; mc = ''; loader = ''; mods = 0; raiz = ''; mb = [Math]::Round((Get-Item $path).Length / 1MB) }
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $names = @($zip.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
        $index = $zip.Entries | Where-Object { $_.FullName -eq 'modrinth.index.json' } | Select-Object -First 1
        if ($index) {
            $reader = New-Object IO.StreamReader($index.Open())
            $data = $reader.ReadToEnd() | ConvertFrom-Json
            $reader.Dispose()
            $info.formato = 'mrpack'
            if ($data.name) { $info.nome = [string]$data.name }
            $info.mc = [string]$data.dependencies.minecraft
            foreach ($pair in @(@('fabric-loader', 'fabric'), @('neoforge', 'neoforge'), @('forge', 'forge'), @('quilt-loader', 'quilt'))) {
                $value = $data.dependencies.($pair[0])
                if ($value) { $info.tipo = $pair[1]; $info.loader = [string]$value }
            }
            $info.mods = @($data.files | Where-Object { $_.path -like 'mods/*' -and $_.env.server -ne 'unsupported' }).Count
            return $info
        }

        # Server Pack: a raiz e a pasta (talvez nenhuma) onde esta "mods/"
        $modEntry = $names | Where-Object { $_ -match '(^|/)mods/[^/]+\.jar$' } | Sort-Object Length | Select-Object -First 1
        if (-not $modEntry) {
            if ($names -contains 'manifest.json') { $info.formato = 'cliente-curseforge' }
            return $info
        }
        $root = $modEntry.Substring(0, $modEntry.LastIndexOf('mods/'))
        $info.formato = 'servidor'
        $info.raiz = $root
        $info.mods = @($names | Where-Object { $_.StartsWith($root + 'mods/') -and $_ -match '\.jar$' }).Count
        $rootFiles = @($names | Where-Object { $_.StartsWith($root) -and ($_.Substring($root.Length) -notmatch '/') } | ForEach-Object { $_.Substring($root.Length) })

        # pistas sobre o carregador de mods e a versao
        foreach ($file in $rootFiles) {
            if ($file -match '^neoforge-([\w.+-]+?)-installer\.jar$') { $info.tipo = 'neoforge'; $info.loader = $Matches[1] }
            elseif ($file -match '^forge-(\d+(?:\.\d+){1,2})-([\w.+-]+?)(?:-installer|-shim|-universal)?\.jar$') { $info.tipo = 'forge'; $info.mc = $Matches[1]; $info.loader = $Matches[2] }
            elseif ($file -match '^fabric-server') { if (-not $info.tipo) { $info.tipo = 'fabric' } }
        }
        $variables = $zip.Entries | Where-Object { ($_.FullName -replace '\\', '/') -eq ($root + 'variables.txt') } | Select-Object -First 1
        if ($variables) {
            $reader = New-Object IO.StreamReader($variables.Open())
            $text = $reader.ReadToEnd()
            $reader.Dispose()
            if ($text -match '(?im)^\s*MINECRAFT_VERSION\s*=\s*"?([\d.]+)') { $info.mc = $Matches[1] }
            if ($text -match '(?im)^\s*MODLOADER\s*=\s*"?(\w+)') {
                $loaderName = $Matches[1].ToLower()
                if ($loaderName -in 'fabric', 'forge', 'neoforge') { $info.tipo = $loaderName }
            }
            if ($text -match '(?im)^\s*MODLOADER_VERSION\s*=\s*"?([\w.+-]+)') { $info.loader = $Matches[1] }
        }
        if ($info.tipo -eq 'neoforge' -and -not $info.mc -and $info.loader -match '^(\d+)\.(\d+)\.') {
            # NeoForge 21.1.x e do Minecraft 1.21.1; 26.3.0.x e do 26.3
            if ([int]$Matches[1] -lt 26) { $info.mc = "1.$($Matches[1]).$($Matches[2])" -replace '\.0$', '' }
        }
        return $info
    } finally { $zip.Dispose() }
}

# Copia o conteudo do modpack para a pasta server. Devolve quantos arquivos pos.
function Copy-PackFiles($path, $info) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $count = 0
    # os mods antigos saem todos: misturar dois pacotes quebra o servidor
    $modsDir = Join-Path $ServerDir 'mods'
    if (Test-Path $modsDir) { Get-ChildItem $modsDir -Filter '*.jar' -File | Remove-Item -Force }

    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        if ($info.formato -eq 'mrpack') {
            $index = $zip.Entries | Where-Object { $_.FullName -eq 'modrinth.index.json' } | Select-Object -First 1
            $reader = New-Object IO.StreamReader($index.Open())
            $data = $reader.ReadToEnd() | ConvertFrom-Json
            $reader.Dispose()
            $files = @($data.files | Where-Object { $_.env.server -ne 'unsupported' })
            $done = 0
            foreach ($file in $files) {
                if (-not (Test-SafeRelativePath $file.path)) { throw "O modpack tem um caminho invalido: $($file.path)" }
                $url = [string](@($file.downloads)[0])
                # so os servidores que o formato .mrpack permite
                if ($url -notmatch '^https://(cdn\.modrinth\.com|github\.com|raw\.githubusercontent\.com|gitlab\.com)/') {
                    throw "O modpack aponta para um endereco nao permitido: $url"
                }
                $target = Join-Path $ServerDir ($file.path -replace '/', '\')
                New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
                Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing -UserAgent $UserAgent
                if ($file.hashes.sha1 -and (Get-FileHash $target -Algorithm SHA1).Hash -ne ([string]$file.hashes.sha1).ToUpper()) {
                    Remove-Item $target -Force
                    throw "O arquivo $($file.path) veio diferente do esperado."
                }
                $count++
                $done++
                if ($done % 20 -eq 0) { Out-Line "    $done de $($files.Count) arquivos baixados..." }
            }
            $prefixes = 'overrides/', 'server-overrides/'
        } else {
            $prefixes = @($info.raiz)
        }

        foreach ($prefix in $prefixes) {
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName -replace '\\', '/'
                if ($name.EndsWith('/')) { continue }
                if ($prefix -and -not $name.StartsWith($prefix)) { continue }
                $relative = $name.Substring($prefix.Length)
                if (-not $relative -or -not (Test-SafeRelativePath $relative)) { continue }
                if ($info.formato -ne 'mrpack' -and -not (Test-PackEntryWanted $relative)) { continue }
                if ($info.formato -eq 'mrpack' -and $relative -eq 'modrinth.index.json') { continue }
                $target = Join-Path $ServerDir ($relative -replace '/', '\')
                New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                $count++
            }
        }
    } finally { $zip.Dispose() }
    return $count
}

function Get-TypeLabel($type) {
    switch ($type) {
        'fabric'   { return 'Fabric' }
        'neoforge' { return 'NeoForge' }
        'forge'    { return 'Forge' }
        default    { return 'Paper' }
    }
}

# Versao mais recente do carregador de mods para uma versao do Minecraft
# ('' se nao existir). Ela e gravada no config.json, para todos os hosts do
# grupo instalarem exatamente a mesma.
function Resolve-LoaderVersion($type, $mc) {
    try {
        if ($type -eq 'fabric') {
            $loaders = @(Get-JsonList "https://meta.fabricmc.net/v2/versions/loader/$mc")
            $stable = ($loaders | Where-Object { $_.loader.stable } | Select-Object -First 1).loader.version
            if ($stable) { return [string]$stable }
            if ($loaders.Count -gt 0) { return [string]$loaders[0].loader.version }
        } elseif ($type -eq 'neoforge') {
            # 1.21.1 -> "21.1.x"; 1.21 -> "21.0.x"; 26.3 -> "26.3.0.x"; 26.1.2 -> "26.1.2.x"
            if ($mc -match '^1\.(\d+)(?:\.(\d+))?$') {
                $minor = '0'
                if ($Matches[2]) { $minor = $Matches[2] }
                $prefix = "$($Matches[1]).$minor."
            } elseif (($mc -split '\.').Count -eq 2) {
                $prefix = "$mc.0."
            } else {
                $prefix = "$mc."
            }
            $all = @((Invoke-RestMethod -Uri 'https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge' -UserAgent $UserAgent -TimeoutSec 20).versions)
            $matching = @($all | Where-Object { $_.StartsWith($prefix) })
            $stable = @($matching | Where-Object { $_ -notmatch '-' })
            if ($stable.Count -gt 0) { return [string]$stable[-1] }
            if ($matching.Count -gt 0) { return [string]$matching[-1] }
        } elseif ($type -eq 'forge') {
            $promos = (Invoke-RestMethod -Uri 'https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json' -UserAgent $UserAgent -TimeoutSec 20).promos
            $version = $promos."$mc-recommended"
            if (-not $version) { $version = $promos."$mc-latest" }
            if ($version) { return [string]$version }
        }
    } catch { }
    return ''
}

# Como iniciar um servidor Forge/NeoForge ja instalado na pasta server
# ('' se ainda nao foi instalado).
function Get-ModdedArgs($type, $mc, $loader) {
    if ($type -eq 'neoforge') {
        if (Test-Path (Join-Path $ServerDir "libraries\net\neoforged\neoforge\$loader\win_args.txt")) {
            return "@libraries/net/neoforged/neoforge/$loader/win_args.txt nogui"
        }
        return ''
    }
    $full = "$mc-$loader"
    if (Test-Path (Join-Path $ServerDir "libraries\net\minecraftforge\forge\$full\win_args.txt")) {
        return "@libraries/net/minecraftforge/forge/$full/win_args.txt nogui"
    }
    foreach ($jar in "forge-$full-shim.jar", "forge-$full.jar", "forge-$full-universal.jar") {
        if (Test-Path (Join-Path $ServerDir $jar)) { return "-jar `"$jar`" nogui" }
    }
    return ''
}

# Garante o servidor Forge/NeoForge instalado e devolve como inicia-lo. A
# instalacao roda o instalador oficial dentro da pasta server; o que ele baixa
# (libraries, .jar) fica fora do repositorio e cada PC instala o seu.
function Install-ModdedServer($type, $mc, $loader, $java) {
    $label = Get-TypeLabel $type
    if (-not $loader) { $loader = Resolve-LoaderVersion $type $mc }
    if (-not $loader) { throw "O $label nao tem versao para o Minecraft $mc." }
    $arguments = Get-ModdedArgs $type $mc $loader
    if ($arguments) { return $arguments }

    if ($type -eq 'neoforge') {
        $name = "neoforge-$loader-installer.jar"
        $url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/$loader/$name"
    } else {
        $name = "forge-$mc-$loader-installer.jar"
        $url = "https://maven.minecraftforge.net/net/minecraftforge/forge/$mc-$loader/$name"
    }
    $folder = Join-Path $RuntimeDir 'instaladores'
    New-Item -ItemType Directory -Force $folder | Out-Null
    $installer = Join-Path $folder $name
    if (-not (Test-Path $installer)) {
        Say "Baixando o instalador do $label $loader..."
        Invoke-WebRequest -Uri $url -OutFile "$installer.baixando" -UseBasicParsing -UserAgent $UserAgent
        Move-Item "$installer.baixando" $installer -Force
    }
    Say "Instalando o servidor $label (so na primeira vez neste PC; leva alguns minutos)..."
    # as duas grafias da opcao existem conforme a versao do instalador
    foreach ($option in '--installServer', '--install-server') {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $java
        $psi.Arguments = "-jar `"$installer`" $option"
        $psi.WorkingDirectory = $ServerDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true   # entrada propria: nao pode herdar a deste script
        $process = [System.Diagnostics.Process]::Start($psi)
        if (-not $process.WaitForExit(20 * 60 * 1000)) { $process.Kill() }
        $arguments = Get-ModdedArgs $type $mc $loader
        if ($arguments) { return $arguments }
    }
    throw "A instalacao do servidor $label nao terminou. Veja as mensagens acima."
}

# Versao minima do Java que a Mojang exige para uma versao do Minecraft
# (a informacao vem da API do Paper). $null se nao der para saber.
function Get-JavaMinimum($version) {
    try {
        $info = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/paper/versions/$version" -UserAgent $UserAgent -TimeoutSec 15
        return [int]$info.version.java.version.minimum
    } catch { return $null }
}

# Ha uma versao mais nova do programa publicada? Devolve o numero dela ou ''.
# Consulta o GitHub no maximo uma vez a cada 6 horas (o resultado fica em cache).
function Get-NewerProgramVersion {
    if (-not $ProgramVersion) { return '' }
    $cachePath = Join-Path $RuntimeDir 'versao-check.json'
    $latest = ''
    $fresh = $false
    if (Test-Path $cachePath) {
        try {
            $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
            $latest = [string]$cache.ultima
            $fresh = ((Get-Date) - (Get-Item $cachePath).LastWriteTime).TotalHours -lt 6
        } catch { }
    }
    if (-not $fresh) {
        try {
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$ProgramRepo/releases/latest" -UserAgent $UserAgent -TimeoutSec 8
            $latest = ([string]$release.tag_name).TrimStart('v')
            New-Item -ItemType Directory -Force $RuntimeDir | Out-Null
            [IO.File]::WriteAllText($cachePath, (@{ ultima = $latest } | ConvertTo-Json))
        } catch { }
    }
    try {
        if ($latest -and ([version]$latest -gt [version]$ProgramVersion)) { return $latest }
    } catch { }
    return ''
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

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$WebhookUrl = [string]$Config.discordWebhook   # vazio = sem avisos no Discord
# Tunel do playit.gg: com a chave preenchida, quem hosteia sobe um tunel e os
# outros entram pelo endereco publico dele, sem VPN. Vazio = usa o Radmin.
$TunnelKey     = ([string]$Config.tunelChave).Trim()
$TunnelAddress = ([string]$Config.tunelEndereco).Trim()
$PlayitVersion = '2.0.2'   # versao do agente oficial baixada do GitHub do playit
if ($Config.playitVersao) { $PlayitVersion = [string]$Config.playitVersao }

# Tipo de servidor: "paper" (aceita plugins) ou, com mods, "fabric",
# "neoforge" ou "forge".
$ServerTypes = 'paper', 'fabric', 'neoforge', 'forge'
$ServerType = ([string]$Config.tipoServidor).Trim().ToLower()
if ($ServerType -notin $ServerTypes) { $ServerType = 'paper' }
$LoaderVersion = ([string]$Config.versaoLoader).Trim()   # versao do carregador de mods ('' no Paper)

# Memoria do servidor: cada PC pode ter a sua (arquivo local, fora do
# repositorio); sem isso vale a do grupo, no config.json.
$LocalConfigPath = Join-Path $RuntimeDir 'local.json'
$Memory = [string]$Config.memoria
$AutoCloseMinutes = 0   # fecha sozinho depois de tantos minutos sem ninguem online (0 = nunca)
if (Test-Path $LocalConfigPath) {
    try {
        $localConfig = Get-Content $LocalConfigPath -Raw | ConvertFrom-Json
        if ($localConfig.memoria -match '^\d+[MG]$') { $Memory = [string]$localConfig.memoria }
        if ($localConfig.fecharVazioMinutos) { $AutoCloseMinutes = [int]$localConfig.fecharVazioMinutos }
    } catch { }
}
$DirectEnabled = [bool]$Config.conexaoDireta   # tenta abrir a porta no roteador ao hostear

# De onde vem o programa. Quem fizer um fork e publicar as proprias versoes troca aqui.
$ProgramRepo = 'yuriacs/minecraft-compartilhado'
$VersionFile = Join-Path $PSScriptRoot 'versao.txt'
$ProgramVersion = ''
if (Test-Path $VersionFile) { $ProgramVersion = (Get-Content $VersionFile -Raw).Trim() }
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

$OldRemote = $null   # onde o GitHub estava na ultima vez que este PC olhou
if (Test-Git rev-parse --verify --quiet "refs/remotes/origin/$Branch") {
    $OldRemote = (Invoke-Git rev-parse "origin/$Branch")
}

Say 'Buscando o estado mais recente no GitHub...'
Invoke-Git fetch origin --prune --quiet
$HasRemoteBranch = Test-Git rev-parse --verify --quiet "refs/remotes/origin/$Branch"

# Quando alguem compacta o historico, o GitHub passa a ter commits diferentes
# dos deste PC, e um "pull" normal nao funciona mais. Se este PC nao tem nada
# proprio para enviar (so tinha o que ja estava no GitHub), basta adotar o
# historico novo.
if ($HasRemoteBranch -and $OldRemote) {
    $newRemote = (Invoke-Git rev-parse "origin/$Branch")
    $rewritten = ($newRemote -ne $OldRemote) -and -not (Test-Git merge-base --is-ancestor $OldRemote $newRemote)
    if ($rewritten) {
        $localLock = Read-Lock
        $nothingOfMine = (Test-Git merge-base --is-ancestor HEAD $OldRemote) -and
                         (-not $localLock -or $localLock.host -ne $Me) -and
                         -not (@() | & git -C $Root status --porcelain)
        if ($nothingOfMine) {
            Invoke-Git reset --hard --quiet "origin/$Branch"
            Say 'O historico do mundo foi compactado no GitHub. Este PC foi realinhado.' 'Yellow'
        }
    }
}

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
            tunel       = [bool]$TunnelKey
            tunelEndereco = $TunnelAddress
            tipoServidor = $ServerType
            versaoLoader = $LoaderVersion
            versaoMinecraft = [string]$Config.versaoMinecraft
            memoria     = $Memory
            memoriaGrupo = [string]$Config.memoria
            fecharVazio = $AutoCloseMinutes
            direta      = $DirectEnabled
            versao      = $ProgramVersion
            versaoNova  = (Get-NewerProgramVersion)
        }
        Emit ('STATUS@@' + ($info | ConvertTo-Json -Compress))
        exit 0
    }
    if ($remoteLock) {
        Say 'Servidor ONLINE' 'Green'
        Show-Lock $remoteLock
    } else {
        Say 'Ninguem esta hosteando agora.' 'Yellow'
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

    Assert-ServerIdle 'mudar a configuracao'

    if ($url) {
        Say 'Mandando uma mensagem de teste para o Discord...'
        $hello = "$IconOpen Avisos do **Minecraft Compartilhado** ligados por **$Me**. Este canal vai avisar quando o servidor abrir e fechar."
        if (-not (Send-Discord $hello $url)) {
            Fail 'O Discord nao aceitou esse link. Confira se copiou o webhook inteiro e se ele ainda existe.'
        }
    }

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json   # relido apos o merge
    $Config | Add-Member -NotePropertyName discordWebhook -NotePropertyValue $url -Force
    [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json) + "`n")
    Invoke-Git add $ConfigPath
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

# ---------------------------------------------------------------- sincronizar este PC

if ($SyncOnly) {
    # Para quem so joga: traz plugins/mods/configuracao mais recentes sem hostear.
    $localLock = Read-Lock
    $mine = $localLock -and $localLock.host -eq $Me
    if ($mine -or (@() | & git -C $Root status --porcelain)) {
        Fail 'Este PC tem uma sessao ou alteracoes que ainda nao foram enviadas. Envie o mundo primeiro.'
    }
    if ($HasRemoteBranch -and -not (Test-Git merge --ff-only "origin/$Branch")) {
        Fail 'Seu repositorio local divergiu do GitHub.'
    }
    Say 'Este PC esta com a versao mais recente do servidor.' 'Green'
    exit 0
}

# ---------------------------------------------------------------- versao e tipo do servidor

if ($ListVersions) {
    $list = @()
    try {
        $all = (Invoke-RestMethod -Uri 'https://fill.papermc.io/v3/projects/paper/versions' -UserAgent $UserAgent -TimeoutSec 20).versions
        foreach ($entry in $all) {
            $id = [string]$entry.version.id
            if ($id -notmatch '^\d+(\.\d+){1,2}$') { continue }   # pula pre-releases
            $list += [ordered]@{ id = $id; java = [int]$entry.version.java.version.minimum }
            if ($list.Count -ge 15) { break }
        }
    } catch {
        Fail "Nao consegui consultar a lista de versoes do Minecraft. ($_)"
    }
    if ($Gui) {
        $info = [ordered]@{ tipo = $ServerType; atual = [string]$Config.versaoMinecraft; versoes = @($list) }
        Emit ('VERSIONS@@' + ($info | ConvertTo-Json -Compress -Depth 4))
    } else {
        Say "Servidor atual: $ServerType $($Config.versaoMinecraft). Versoes disponiveis:"
        $list | ForEach-Object { Write-Host "    $($_.id)  (Java $($_.java))" }
    }
    exit 0
}

if ($PSBoundParameters.ContainsKey('SetServer')) {
    $parts = $SetServer.Trim() -split '\|'
    $type = ([string]$parts[0]).ToLower()
    $mc = [string]$parts[1]
    if ($type -notin $ServerTypes) { Fail 'Tipo de servidor invalido. Use paper, fabric, neoforge ou forge.' }
    if ($mc -notmatch '^\d+(\.\d+){1,2}$') { Fail 'Versao do Minecraft invalida.' }
    $label = Get-TypeLabel $type
    Assert-ServerIdle 'trocar o servidor'

    Say "Conferindo se existe $label para o Minecraft $mc..."
    $javaMin = Get-JavaMinimum $mc
    if ($type -eq 'paper' -and -not $javaMin) { Fail "O Paper nao tem a versao $mc." }
    # A versao do carregador de mods fica fixada no config.json. Um modpack
    # pode pedir uma versao especifica (quarto campo); senao vale a mais recente.
    $loaderPin = ''
    if ($type -ne 'paper') {
        $loaderPin = ([string]$parts[3]).Trim()
        if ($loaderPin -and $loaderPin -notmatch '^[\w.+-]+$') { Fail 'Versao do carregador de mods invalida.' }
        if (-not $loaderPin) { $loaderPin = Resolve-LoaderVersion $type $mc }
        if (-not $loaderPin) { Fail "O $label nao tem versao para o Minecraft $mc." }
    }

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json   # relido apos o merge
    $currentType = ([string]$Config.tipoServidor).Trim().ToLower()
    if ($currentType -notin $ServerTypes) { $currentType = 'paper' }
    # O Paper guarda o mundo de um jeito e os servidores com mods (Fabric,
    # Forge, NeoForge) de outro: um lado nao abre o mundo do outro (o servidor
    # trava ao iniciar). Por isso trocar entre Paper e mods so e aceito junto
    # com "mundo-novo", que tira o mundo atual do servidor. Ele continua
    # guardado nos saves.
    $worldFolders = @('world', 'world_nether', 'world_the_end') | Where-Object { Test-Path (Join-Path $ServerDir $_) }
    $newWorld = ([string]$parts[2]) -eq 'mundo-novo'
    $resetWorld = (($type -eq 'paper') -ne ($currentType -eq 'paper')) -and $worldFolders
    if ($resetWorld -and -not $newWorld) {
        Fail 'Trocar entre Paper e um servidor com mods exige comecar um mundo novo, porque um nao abre o mundo do outro. Pela interface (Opcoes) isso e feito com confirmacao.'
    }
    $Config | Add-Member -NotePropertyName tipoServidor -NotePropertyValue $type -Force
    $Config | Add-Member -NotePropertyName versaoLoader -NotePropertyValue $loaderPin -Force
    $Config | Add-Member -NotePropertyName versaoMinecraft -NotePropertyValue $mc -Force
    if ($javaMin) { $Config | Add-Member -NotePropertyName javaVersao -NotePropertyValue $javaMin -Force }
    [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json) + "`n")
    Invoke-Git add $ConfigPath
    $extra = ''
    if ($resetWorld) {
        foreach ($folder in $worldFolders) {
            Invoke-Git rm -r --quiet --ignore-unmatch "server/$folder"
            Remove-Item (Join-Path $ServerDir $folder) -Recurse -Force -ErrorAction SilentlyContinue
        }
        $extra = ', mundo novo'
    }
    if (Test-Git diff --cached --quiet) {
        Say 'O servidor ja estava assim. Nada mudou.' 'Green'
        exit 0
    }
    Invoke-Git commit --quiet -m "Servidor: $label $mc$extra (por $Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar a configuracao para o GitHub. Nada foi alterado.'
    }
    $notice = "$IconSwap **$Me** mudou o servidor para **$label $mc**. Todo mundo precisa jogar nessa vers$([char]0xE3)o do Minecraft."
    if ($resetWorld) { $notice += " O servidor vai come$([char]0xE7)ar um mundo novo; o anterior continua guardado nos saves." }
    Send-Discord $notice | Out-Null
    Say "Servidor configurado: $label $mc. O proximo host baixa o que faltar." 'Green'
    if ($resetWorld) { Say 'Um mundo novo sera criado na proxima vez que o servidor abrir. O anterior continua guardado nos saves.' 'Yellow' }
    exit 0
}

# ---------------------------------------------------------------- modpacks

if ($PSBoundParameters.ContainsKey('InspectPack')) {
    try { $info = Get-PackInfo $InspectPack.Trim('"') } catch { Fail "Nao consegui abrir esse arquivo como modpack. ($_)" }
    if ($Gui) {
        Emit ('PACK@@' + ($info | ConvertTo-Json -Compress))
    } else {
        Say "Modpack: $($info.nome)"
        $info.GetEnumerator() | ForEach-Object { Write-Host "    $($_.Key): $($_.Value)" }
    }
    exit 0
}

if ($PSBoundParameters.ContainsKey('ImportPack')) {
    $parts = $ImportPack -split '\|'
    $packPath = ([string]$parts[0]).Trim('"')
    $type = ([string]$parts[1]).Trim().ToLower()
    $mc = ([string]$parts[2]).Trim()
    $loaderPin = ([string]$parts[3]).Trim()
    $newWorld = ([string]$parts[4]) -eq 'mundo-novo'
    if ($type -notin 'fabric', 'neoforge', 'forge') { Fail 'O modpack precisa ser de Fabric, NeoForge ou Forge.' }
    if ($mc -notmatch '^\d+(\.\d+){1,2}$') { Fail 'Versao do Minecraft invalida.' }
    if ($loaderPin -and $loaderPin -notmatch '^[\w.+-]+$') { Fail 'Versao do carregador de mods invalida.' }
    $label = Get-TypeLabel $type
    try { $info = Get-PackInfo $packPath } catch { Fail "Nao consegui abrir esse arquivo como modpack. ($_)" }
    if ($info.formato -eq 'cliente-curseforge') {
        Fail 'Esse e o pacote do CurseForge para o jogo (so tem a lista dos mods). Baixe o "Server Pack" na pagina do modpack, na aba Files.'
    }
    if ($info.formato -eq 'desconhecido') { Fail 'Nao achei mods dentro desse arquivo. Ele precisa ser um Server Pack (.zip com a pasta mods) ou um .mrpack.' }
    Assert-ServerIdle 'importar um modpack'

    if (-not $loaderPin) { $loaderPin = Resolve-LoaderVersion $type $mc }
    if (-not $loaderPin) { Fail "O $label nao tem versao para o Minecraft $mc." }
    $javaMin = Get-JavaMinimum $mc

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json   # relido apos o merge
    $currentType = ([string]$Config.tipoServidor).Trim().ToLower()
    if ($currentType -notin $ServerTypes) { $currentType = 'paper' }
    $worldFolders = @('world', 'world_nether', 'world_the_end') | Where-Object { Test-Path (Join-Path $ServerDir $_) }
    $resetWorld = $newWorld -and $worldFolders
    if ($currentType -eq 'paper' -and $worldFolders -and -not $newWorld) {
        Fail 'O servidor atual e Paper: importar um modpack exige comecar um mundo novo. Pela interface (Opcoes) isso e feito com confirmacao.'
    }

    Say "Importando o modpack $($info.nome)..."
    try {
        $copied = Copy-PackFiles $packPath $info
        $tooBig = Get-ChildItem $ServerDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 95MB -and $_.FullName -notmatch '\\(libraries|versions|cache|logs)\\' -and $_.DirectoryName -ne $ServerDir } |
            Select-Object -First 1
        if ($tooBig) { throw "O arquivo $($tooBig.Name) tem mais de 95 MB e o GitHub nao aceita." }
        if ($resetWorld) {
            foreach ($folder in $worldFolders) {
                Invoke-Git rm -r --quiet --ignore-unmatch "server/$folder"
                Remove-Item (Join-Path $ServerDir $folder) -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $Config | Add-Member -NotePropertyName tipoServidor -NotePropertyValue $type -Force
        $Config | Add-Member -NotePropertyName versaoMinecraft -NotePropertyValue $mc -Force
        $Config | Add-Member -NotePropertyName versaoLoader -NotePropertyValue $loaderPin -Force
        if ($javaMin) { $Config | Add-Member -NotePropertyName javaVersao -NotePropertyValue $javaMin -Force }
        [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json) + "`n")
        Add-World
        $message = "Modpack importado: $($info.nome) ($label $mc)"
        if ($message.Length -gt 110) { $message = $message.Substring(0, 110) }
        Invoke-Git commit --quiet -m "$message (por $Me)"
    } catch {
        # volta tudo ao que estava (a pasta estava limpa antes de comecar)
        Test-Git reset --hard --quiet HEAD | Out-Null
        Test-Git clean -fd --quiet | Out-Null
        Fail "A importacao falhou e nada foi alterado. ($_)"
    }
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Test-Git clean -fd --quiet | Out-Null
        Fail 'Nao consegui enviar para o GitHub. Nada foi alterado.'
    }
    $notice = "$IconSwap **$Me** instalou o modpack **$($info.nome)** no servidor ($label $loaderPin, Minecraft $mc). Todos precisam do mesmo modpack para entrar."
    if ($resetWorld) { $notice += " O servidor vai come$([char]0xE7)ar um mundo novo." }
    Send-Discord $notice | Out-Null
    Say "Modpack importado: $copied arquivos. Servidor: $label $loaderPin, Minecraft $mc." 'Green'
    if ($resetWorld) { Say 'Um mundo novo sera criado na proxima vez que o servidor abrir. O anterior continua guardado nos saves.' 'Yellow' }
    exit 0
}

# ---------------------------------------------------------------- plugins e mods

if ($PSBoundParameters.ContainsKey('SaveChanges')) {
    $message = (($SaveChanges -replace '[\r\n]+', ' ').Trim())
    if (-not $message) { $message = 'Arquivos do servidor atualizados' }
    if ($message.Length -gt 100) { $message = $message.Substring(0, 100) }

    # Igual as outras tarefas de manutencao, mas aqui as alteracoes locais sao
    # justamente o que se quer enviar.
    if (Get-RemoteLock) { Fail 'O servidor esta aberto. Espere fechar para mudar plugins ou mods.' }
    $ahead = 0
    if ($HasRemoteBranch) { $ahead = [int](Invoke-Git rev-list --count "origin/$Branch..HEAD") }
    if ((Read-Lock) -or $ahead -gt 0) { Fail 'Este PC tem uma sessao que ainda nao foi enviada. Envie o mundo primeiro.' }
    if ($HasRemoteBranch -and -not (Test-Git merge --ff-only "origin/$Branch")) {
        Fail 'Nao consegui juntar com o que esta no GitHub. Atualize a janela e tente de novo.'
    }
    # o GitHub recusa arquivos acima de 100 MB
    $tooBig = Get-ChildItem (Join-Path $ServerDir 'plugins'), (Join-Path $ServerDir 'mods') -Filter '*.jar' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 95MB } | Select-Object -First 1
    if ($tooBig) { Fail "O arquivo $($tooBig.Name) tem mais de 95 MB e o GitHub nao aceita. Remova-o." }

    Add-World
    if (Test-Git diff --cached --quiet) {
        Say 'Nada mudou.' 'Green'
        exit 0
    }
    Invoke-Git commit --quiet -m "$message (por $Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --soft --quiet 'HEAD~1'
        Fail 'Nao consegui enviar para o GitHub. As alteracoes continuam neste PC; tente de novo.'
    }
    Say 'Alteracoes enviadas. Valem a partir da proxima vez que o servidor abrir.' 'Green'
    exit 0
}

# ---------------------------------------------------------------- atualizar o programa

if ($UpdateProgram) {
    Assert-ServerIdle 'atualizar o programa'
    Remove-Item (Join-Path $RuntimeDir 'versao-check.json') -Force -ErrorAction SilentlyContinue
    $latest = Get-NewerProgramVersion
    if (-not $latest) {
        Say "O programa ja esta na versao mais recente ($ProgramVersion)." 'Green'
        exit 0
    }
    Say "Baixando a versao $latest do programa..."
    $staging = Join-Path $RuntimeDir 'atualizacao'
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $staging | Out-Null
    $files = 'host.ps1', 'gui.ps1', 'app.ico', 'versao.txt'
    try {
        foreach ($file in $files) {
            $url = "https://raw.githubusercontent.com/$ProgramRepo/v$latest/scripts/$file"
            Invoke-WebRequest -Uri $url -OutFile (Join-Path $staging $file) -UseBasicParsing -UserAgent $UserAgent
        }
        # nao troca nada se algum script vier quebrado
        foreach ($file in 'host.ps1', 'gui.ps1') {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $staging $file), [ref]$null, [ref]$errors)
            if ($errors.Count -gt 0) { throw "$file veio com erro" }
        }
        if ((Get-Content (Join-Path $staging 'versao.txt') -Raw).Trim() -ne $latest) { throw 'a versao baixada nao confere' }
    } catch {
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        Fail "Nao consegui baixar a atualizacao. Nada foi alterado. ($_)"
    }
    foreach ($file in $files) { Copy-Item (Join-Path $staging $file) (Join-Path $PSScriptRoot $file) -Force }
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-Git add -A -- scripts
    if (Test-Git diff --cached --quiet) {
        Say 'O programa ja estava igual a versao mais recente.' 'Green'
        exit 0
    }
    Invoke-Git commit --quiet -m "Atualiza o programa para a versao $latest (por $Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar a atualizacao para o GitHub. Nada foi alterado.'
    }
    Say "Programa atualizado para a versao $latest. Feche e abra o programa de novo." 'Green'
    exit 0
}

# ---------------------------------------------------------------- conexao direta

if ($PSBoundParameters.ContainsKey('SetDirect')) {
    $on = $SetDirect.Trim().ToLower() -eq 'on'
    Assert-ServerIdle 'mudar a configuracao'
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json   # relido apos o merge
    $Config | Add-Member -NotePropertyName conexaoDireta -NotePropertyValue $on -Force
    [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json) + "`n")
    Invoke-Git add $ConfigPath
    if (Test-Git diff --cached --quiet) {
        Say 'A configuracao ja estava assim. Nada mudou.' 'Green'
        exit 0
    }
    if ($on) { $what = 'Liga' } else { $what = 'Desliga' }
    Invoke-Git commit --quiet -m "$what a conexao direta ($Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar a configuracao para o GitHub. Nada foi alterado.'
    }
    if ($on) {
        Say 'Conexao direta ligada. Quem hostear tenta abrir a porta no proprio roteador.' 'Green'
    } else {
        Say 'Conexao direta desligada.' 'Green'
    }
    exit 0
}

# ---------------------------------------------------------------- tunel

if ($SetTunnel) {
    # A chave nunca passa pela linha de comando nem aparece na tela: vem pela entrada.
    if ($Gui) {
        $key = ([string][Console]::In.ReadLine()).Trim()
        $address = ([string][Console]::In.ReadLine()).Trim()
    } else {
        Write-Host ''
        Write-Host 'Tunel do playit.gg. Deixe a chave vazia para desligar e voltar ao Radmin.'
        $secure = Read-Host 'Chave secreta do agente (nao aparece enquanto voce digita)' -AsSecureString
        $key = ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))).Trim()
        $address = ''
        if ($key) { $address = (Read-Host 'Endereco publico do tunel (ex.: nome.gl.joinmc.link)').Trim() }
    }
    if ($key -eq 'manter') { $key = $TunnelKey }   # so troca o endereco, sem redigitar a chave
    if (-not $key) { $address = '' }
    if ($key -and $key -notmatch '^[0-9a-fA-F]{32,}$') {
        Fail 'Isso nao parece a chave secreta do playit (ela e uma sequencia longa de letras de a ate f e numeros).'
    }
    # o endereco pode ficar para depois: o playit so deixa criar o tunel (e mostra
    # o endereco) depois que o agente se conecta pela primeira vez
    if ($key -and $address -and $address -notmatch '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:\d{1,5})?$') {
        Fail 'O endereco do tunel deve ser como nome.gl.joinmc.link (com :porta no fim, se o playit mostrar uma).'
    }
    Assert-ServerIdle 'mudar a configuracao'

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json   # relido apos o merge
    $Config | Add-Member -NotePropertyName tunelChave -NotePropertyValue $key -Force
    $Config | Add-Member -NotePropertyName tunelEndereco -NotePropertyValue $address -Force
    [IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json) + "`n")
    Invoke-Git add $ConfigPath
    if (Test-Git diff --cached --quiet) {
        Say 'A configuracao ja estava assim. Nada mudou.' 'Green'
        exit 0
    }
    if ($key) { $what = 'Liga' } else { $what = 'Desliga' }
    Invoke-Git commit --quiet -m "$what o tunel do playit.gg ($Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar a configuracao para o GitHub. Nada foi alterado.'
    }
    if ($key -and $address) {
        Say "Tunel ligado para o grupo todo. Endereco para entrar: $address" 'Green'
    } elseif ($key) {
        Say 'Chave do tunel gravada. Falta o endereco: hosteie uma vez, crie o tunel no site do playit e volte aqui para preencher.' 'Green'
    } else {
        Say 'Tunel desligado. O grupo volta a usar o Radmin.' 'Green'
    }
    exit 0
}

# ---------------------------------------------------------------- saves

if ($ListSaves) {
    $ref = 'HEAD'
    if ($HasRemoteBranch) { $ref = "origin/$Branch" }
    $lines = @(Invoke-Git log $ref --first-parent '--format=%H|%ct|%s')
    $saves = @()
    $total = 0
    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        # so os commits que guardam um estado do mundo interessam para restaurar
        if ($parts[2] -notmatch $SavePattern) { continue }
        $total++
        if ($saves.Count -ge 200) { continue }   # a lista mostra os 200 mais recentes
        $when = [DateTimeOffset]::FromUnixTimeSeconds([long]$parts[1]).LocalDateTime
        $saves += [ordered]@{ id = $parts[0]; quando = $when.ToString('dd/MM/yyyy HH:mm'); texto = $parts[2] }
    }
    if ($Gui) {
        $info = [ordered]@{ total = $total; mb = (Get-GitFolderMb); saves = @($saves) }
        Emit ('SAVES@@' + ($info | ConvertTo-Json -Compress -Depth 4))
    } else {
        Say "Saves guardados: $total"
        $saves | ForEach-Object { Write-Host "    $($_.id.Substring(0, 8))  $($_.quando)  $($_.texto)" }
    }
    exit 0
}

if ($PSBoundParameters.ContainsKey('Restore')) {
    $target = $Restore.Trim()
    if ($target -notmatch '^[0-9a-f]{7,40}$') { Fail 'Save invalido.' }
    Assert-ServerIdle 'restaurar um save'
    if (-not (Test-Git merge-base --is-ancestor $target HEAD)) {
        Fail 'Esse save nao faz parte do historico deste servidor (ele pode ter sido compactado).'
    }
    $when = (Get-CommitTime $target).ToString('dd/MM/yyyy HH:mm')
    Say "Restaurando o mundo para o save de $when..."
    try {
        # Troca so a pasta server/ pela daquele save. O programa e a configuracao
        # continuam os atuais, e o mundo de agora fica guardado no historico.
        Invoke-Git rm -r --quiet --ignore-unmatch server
        Invoke-Git checkout $target -- server
        Invoke-Git add -A
    } catch {
        Test-Git reset --hard --quiet HEAD | Out-Null
        Fail "Nao consegui restaurar esse save. Nada foi alterado. ($_)"
    }
    if (Test-Git diff --cached --quiet) {
        Say 'O mundo atual ja e igual a esse save. Nada mudou.' 'Green'
        exit 0
    }
    Invoke-Git commit --quiet -m "Mundo restaurado para o save de $when (por $Me)"
    if (-not (Push-WithRetry)) {
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Fail 'Nao consegui enviar para o GitHub. Nada foi alterado.'
    }
    Send-Discord "$([char]0x21A9) **$Me** restaurou o mundo para o save de $when." | Out-Null
    Say "Mundo restaurado para o save de $when. O mundo que estava antes continua guardado no historico." 'Green'
    exit 0
}

if ($PSBoundParameters.ContainsKey('Prune')) {
    $keep = $Prune
    if ($keep -lt 5) { Fail 'Mantenha pelo menos os 5 saves mais recentes.' }
    Assert-ServerIdle 'compactar o historico'
    [Console]::OutputEncoding = [Text.Encoding]::UTF8   # nomes com acento nas mensagens dos commits
    # do mais novo para o mais antigo; "hash|assunto"
    $entries = @(Invoke-Git log --first-parent '--format=%H|%s' HEAD)
    $commits = @($entries | ForEach-Object { ($_ -split '\|', 2)[0] })
    $saveIndexes = @()
    for ($i = 0; $i -lt $entries.Count; $i++) {
        if ((($entries[$i] -split '\|', 2)[1]) -match $SavePattern) { $saveIndexes += $i }
    }
    # O novo comeco do historico e o commit logo antes do N-esimo save: assim os
    # N saves mais recentes continuam inteiros e restauraveis.
    $baseIndex = -1
    if ($saveIndexes.Count -gt $keep) { $baseIndex = $saveIndexes[$keep - 1] + 1 }
    if ($baseIndex -lt 1 -or $baseIndex -ge $commits.Count - 1) {
        Say "O historico tem $($saveIndexes.Count) saves. Nada para compactar." 'Green'
        exit 0
    }
    $oldTip = $commits[0]
    $base = $commits[$baseIndex]
    $baseWhen = (Get-CommitTime $base).ToString('dd/MM/yyyy HH:mm')
    $sizeBefore = Get-GitFolderMb
    Say "Compactando: ficam os $keep saves mais recentes; os $($saveIndexes.Count - $keep) mais antigos saem do historico..."
    New-Item -ItemType Directory -Force $RuntimeDir | Out-Null

    $newTip = Copy-Commit $base $null "Historico compactado: comeca em $baseWhen"
    for ($i = $baseIndex - 1; $i -ge 0; $i--) {
        $newTip = Copy-Commit $commits[$i] $newTip $null
    }
    # o mundo nao pode mudar em nada: o ultimo commit novo tem que ter os mesmos arquivos do antigo
    $treeOld = Invoke-Git rev-parse ('{0}^{{tree}}' -f $oldTip)
    $treeNew = Invoke-Git rev-parse ('{0}^{{tree}}' -f $newTip)
    if ($treeOld -ne $treeNew) { Fail 'A conferencia do historico novo falhou. Nada foi alterado.' }

    Invoke-Git update-ref "refs/heads/$Branch" $newTip $oldTip
    @() | & git -C $Root push "--force-with-lease=${Branch}:$oldTip" origin $Branch | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Invoke-Git update-ref "refs/heads/$Branch" $oldTip $newTip
        Fail 'Nao consegui enviar o historico compactado para o GitHub. Nada foi alterado.'
    }
    # apaga deste PC os saves antigos (no GitHub eles somem sozinhos depois de um tempo)
    Invoke-Git reflog expire --expire=now --all
    Invoke-Git gc --prune=now --quiet
    Send-Discord "$IconSwap **$Me** compactou o hist$([char]0xF3)rico do mundo: ficaram os $keep saves mais recentes." | Out-Null
    Say "Historico compactado: de $($saveIndexes.Count) para $keep saves. Pasta .git neste PC: $sizeBefore MB -> $(Get-GitFolderMb) MB." 'Green'
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
        # renova o sinal de vida (e o endereco) para os outros verem que este PC voltou
        Open-DirectConnection
        $address = Get-JoinAddress
        if (-not $address) { $address = $lock.endereco }
        Write-Lock $lock.desde $address
        Add-World
        Invoke-Git commit --quiet -m "$Me voltou a hostear"
        if (-not (Push-WithRetry)) {
            Close-DirectConnection
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
            Fail "Seu repositorio local divergiu do GitHub. Se este PC nao tem progresso proprio para enviar, rode nesta pasta: git reset --hard origin/$Branch"
        }
    }

    $lock = Read-Lock
    if ($lock -and $lock.host -ne $Me) {
        Say 'O servidor ja esta sendo hosteado:' 'Yellow'
        Show-Lock $lock
        if (-not $Force) {
            Write-Host ''
            Write-Host '    Entre no endereco acima para jogar.'
            Write-Host '    Se essa pessoa caiu e nao vai voltar, use "Assumir o servidor".'
            exit 0
        }
        Write-Host ''
        Write-Host "    Assumir vai usar o ultimo backup. O que $($lock.host) jogou depois dele sera perdido." -ForegroundColor Red
        if (-not (Confirm-Yes '    Assumir mesmo assim?' "assumir@@$($lock.host)")) { exit 1 }
        $tookOverFrom = $lock.host
    }

    # Pega a trava. O push e o que decide: se duas pessoas tentarem ao mesmo
    # tempo, o GitHub aceita so o primeiro.
    Open-DirectConnection
    $address = Get-JoinAddress
    if (-not $address) { $address = $null }
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
            Close-DirectConnection
            exit 0
        }
        Invoke-Git reset --hard --quiet 'HEAD~1'
        Close-DirectConnection
        Fail 'Nao consegui enviar para o GitHub. Confira a internet, o login e se voce tem permissao de escrita no repositorio.'
    }
    if ($tookOverFrom) {
        Send-Discord "$IconSwap **$Me** assumiu o servidor que estava com **$tookOverFrom**, a partir do $([char]0xFA)ltimo backup." | Out-Null
    }
}

# ---------------------------------------------------------------- servidor

$server = $null
$tunnel = $null
$autoClosing = $false
$announcedOpen = $false
try {
    New-Item -ItemType Directory -Force $ServerDir | Out-Null
    New-Item -ItemType Directory -Force $RuntimeDir | Out-Null
    [IO.File]::WriteAllText($PidPath, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)")
    if (Confirm-Eula) {
        $java = Get-Java ([int]$Config.javaVersao)
        if ($ServerType -eq 'fabric') {
            $jar = Get-FabricJar $Config.versaoMinecraft $LoaderVersion
            $serverArgs = "-jar `"$jar`" nogui"
        } elseif ($ServerType -in 'neoforge', 'forge') {
            $serverArgs = Install-ModdedServer $ServerType $Config.versaoMinecraft $LoaderVersion $java
        } else {
            # terminal.jline=false: o Paper le comandos como texto simples, porque
            # quem entrega os comandos a ele e este script (ver o laco abaixo).
            $jar = Get-PaperJar $Config.versaoMinecraft
            $serverArgs = "-Dterminal.jline=false -jar `"$jar`" nogui"
        }

        Say 'Servidor iniciando!' 'Green'
        if ($TunnelKey) { $tunnel = Start-Tunnel }
        $shown = Get-JoinAddress
        $reserve = ''
        if ($DirectAddress -and $tunnel -and $TunnelAddress) { $reserve = $TunnelAddress }
        if ($TunnelKey -and -not $tunnel -and -not $DirectAddress) {
            # o tunel nao subiu; o aviso em vermelho acima ja explicou
        } elseif ($shown) {
            Write-Host "    Seus amigos entram em: $shown" -ForegroundColor Green
            if ($reserve) { Write-Host "    Se algum deles nao conseguir conectar, o endereco reserva e: $reserve" -ForegroundColor Green }
        } elseif ($TunnelKey) {
            Write-Host '    O tunel esta ligado, mas falta o endereco dele. Crie o tunel de Minecraft Java no site do playit' -ForegroundColor Yellow
            Write-Host '    e, depois de fechar o servidor, preencha o endereco em Opcoes > Conexao por tunel.' -ForegroundColor Yellow
        } else {
            Write-Host '    Radmin VPN nao encontrado neste PC. Abra o Radmin e entre na rede do grupo.' -ForegroundColor Yellow
        }
        if ($TunnelKey -or $DirectAddress) {
            $props = Join-Path $ServerDir 'server.properties'
            if ((Test-Path $props) -and (@(Get-Content $props) -match '^white-list=false')) {
                Write-Host '    ATENCAO: o servidor fica aberto para a internet e a whitelist esta desligada.' -ForegroundColor Yellow
                Write-Host '    Ligue "So entra quem esta na whitelist" para so o seu grupo conseguir entrar.' -ForegroundColor Yellow
            }
        }
        Write-Host '    Para fechar e salvar: digite  stop  e aperte Enter. NAO feche a janela no X.'
        Write-Host ''

        $javaArgs = "-Xms$Memory -Xmx$Memory $serverArgs"
        if ($Gui) { $javaArgs = "-Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 $javaArgs" }
        Emit "STATE@@running@@$shown@@$reserve"
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

        Set-KeepAwake $true
        $online = New-Object System.Collections.Generic.HashSet[string]
        $logOffset = 0
        $emptySince = $null
        while (-not $server.WaitForExit(250)) {
            $ticks++

            # O servidor rejeita (e perde) qualquer comando que chegue antes de ele
            # terminar de carregar, inclusive "stop". Por isso os comandos ficam
            # na fila ate ele estar pronto, e o relogio do backup so comeca ai.
            if (-not $ready -and ($ticks % 4 -eq 0) -and (Test-ServerReady $logPath $server.StartTime)) {
                $ready = $true
                $nextBackup = (Get-Date).AddMinutes($BackupMinutes)
                $logOffset = 0
                if (Test-Path $logPath) { $logOffset = (Get-Item $logPath).Length }
                $emptySince = Get-Date
                if ($AutoCloseMinutes -gt 0) {
                    Out-Line "    O servidor fecha sozinho se ficar $AutoCloseMinutes minutos sem ninguem online."
                }
                if ($shown) {
                    $where = "Entrem por: ``$shown``"
                    if ($reserve) { $where += " (se n$([char]0xE3)o conectar: ``$reserve``)" }
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

            # Acompanha quem entra e sai pelo log do servidor, para fechar sozinho
            # quando ele fica vazio por muito tempo (se a pessoa pediu isso).
            if ($ready -and $AutoCloseMinutes -gt 0 -and -not $autoClosing -and ($ticks % 20 -eq 0)) {
                foreach ($entry in ((Read-LogSince $logPath ([ref]$logOffset)) -split "`n")) {
                    if ($entry -match '\]: (\S+) joined the game\s*$') {
                        [void]$online.Add($Matches[1])
                    } elseif ($entry -match '\]: (\S+) left the game\s*$') {
                        [void]$online.Remove($Matches[1])
                    }
                }
                if ($online.Count -gt 0) {
                    $emptySince = $null
                } elseif (-not $emptySince) {
                    $emptySince = Get-Date
                } elseif (((Get-Date) - $emptySince).TotalMinutes -ge $AutoCloseMinutes) {
                    Out-Line ''
                    Out-Line "==> Ninguem online ha $AutoCloseMinutes minutos. Fechando e salvando o servidor..." 'Yellow'
                    $autoClosing = $true
                    $queued.Add('stop')
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
    if ($TunnelKey) { Stop-Tunnel $tunnel }
    Close-DirectConnection
    Set-KeepAwake $false
    $closedMessage = $null
    if ($announcedOpen) {
        $closedMessage = "$IconClosed **$Me** fechou o servidor. Mundo salvo; quem quiser j$([char]0xE1) pode hostear."
        if ($autoClosing) {
            $closedMessage = "$IconClosed O servidor de **$Me** fechou sozinho por ficar vazio. Mundo salvo; quem quiser j$([char]0xE1) pode hostear."
        }
    }
    Save-AndRelease $closedMessage
}
