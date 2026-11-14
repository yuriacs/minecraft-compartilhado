# Minecraft Compartilhado - programa instalado pelo Setup.
#
# O que este arquivo faz:
#   1. Na primeira vez, mostra uma janela pedindo o link do grupo, baixa o
#      servidor do grupo (git clone) e guarda onde ele ficou.
#   2. Nas outras vezes, so abre a interface que vem junto com o servidor do
#      grupo (scripts\gui.ps1).
#
# Ele nao mexe em nada fora da pasta do servidor do grupo e da pasta de dados
# abaixo. Este arquivo precisa ser salvo como UTF-8 COM BOM por causa dos acentos.

param(
    [switch]$NoShow,     # so carrega as funcoes (usado em testes)
    [string]$DataDir     # pasta de dados alternativa (usado em testes)
)

# Um atalho aberto por um programa de 32 bits cairia no PowerShell de 32 bits.
# Num Windows de 64 bits, reabre no de 64.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess -and -not $NoShow) {
    $native = Join-Path $env:windir 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $native) {
        Start-Process $native -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -WindowStyle Hidden
        exit
    }
}

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

if (-not $DataDir) { $DataDir = Join-Path $env:LOCALAPPDATA 'MinecraftCompartilhado' }
$GroupFile = Join-Path $DataDir 'grupo.json'      # guarda a pasta do servidor do grupo
$IconPath  = Join-Path $PSScriptRoot 'app.ico'
$DefaultFolder = Join-Path $env:SystemDrive 'MinecraftCompartilhado'

# ---------------------------------------------------------------- utilidades

# Procura o Git no PATH e nas pastas padrao e garante que ele fique no PATH
# deste processo (logo apos instalar, o PATH ainda nao foi atualizado).
function Find-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return $true }
    $folders = @("$env:ProgramW6432\Git\cmd", "$env:ProgramFiles\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd", "$env:LOCALAPPDATA\Programs\Git\cmd")
    foreach ($folder in $folders) {
        if ($folder -and (Test-Path (Join-Path $folder 'git.exe'))) {
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

# Pasta do servidor do grupo ja configurada neste PC, ou $null.
function Get-GroupFolder {
    if (-not (Test-Path $GroupFile)) { return $null }
    try {
        $saved = Get-Content $GroupFile -Raw | ConvertFrom-Json
        if ($saved.pasta -and (Test-Path (Join-Path $saved.pasta 'scripts\gui.ps1'))) { return [string]$saved.pasta }
    } catch { }
    return $null
}

function Save-GroupFolder($folder) {
    New-Item -ItemType Directory -Force $DataDir | Out-Null
    [IO.File]::WriteAllText($GroupFile, (@{ pasta = $folder } | ConvertTo-Json) + "`n")
}

function Invoke-GitQuiet($arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $text = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    return $text.Trim()
}

# ---------------------------------------------------------------- janela de primeiro uso

# Mostra a janela, faz o download do servidor do grupo e devolve a pasta
# (ou $null se a pessoa fechar a janela sem concluir).
function Show-SetupWindow {
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Minecraft Compartilhado" Width="620" SizeToContent="Height" ResizeMode="CanMinimize"
        Background="#161B22" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <Window.Resources>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#0D1117"/>
      <Setter Property="Foreground" Value="#E6EDF3"/>
      <Setter Property="CaretBrush" Value="#E6EDF3"/>
      <Setter Property="BorderBrush" Value="#30363D"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="Margin" Value="0,5,0,16"/>
    </Style>
    <Style x:Key="Label" TargetType="TextBlock">
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#9DA7B3"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
  </Window.Resources>
  <StackPanel Margin="26">
    <TextBlock Text="Entrar no servidor do grupo" FontSize="22" FontWeight="Bold"/>
    <TextBlock Style="{StaticResource Hint}" FontSize="14" Margin="0,6,0,22"
               Text="Isso só precisa ser feito uma vez neste PC. O programa baixa o servidor do seu grupo e, daí em diante, abre direto."/>

    <TextBlock Style="{StaticResource Label}" Text="Link do grupo"/>
    <TextBlock Style="{StaticResource Hint}" Text="É o endereço do repositório do grupo no GitHub. Quem criou o grupo te passa. Ex.: https://github.com/fulano/nosso-servidor"/>
    <TextBox x:Name="RepoBox"/>

    <TextBlock Style="{StaticResource Label}" Text="Seu nick"/>
    <TextBlock Style="{StaticResource Hint}" Text="Aparece para os outros quando você estiver hosteando."/>
    <TextBox x:Name="NickBox"/>

    <TextBlock Style="{StaticResource Label}" Text="Pasta do servidor neste PC"/>
    <TextBlock Style="{StaticResource Hint}" Text="Onde o mundo fica guardado. Não use uma pasta do OneDrive ou do Google Drive."/>
    <TextBox x:Name="FolderBox"/>

    <Border x:Name="StatusCard" Background="#21262D" CornerRadius="8" Padding="14,12" Margin="0,2,0,18" Visibility="Collapsed">
      <TextBlock x:Name="StatusText" TextWrapping="Wrap"/>
    </Border>

    <Button x:Name="GoBtn" Content="Entrar no grupo" HorizontalAlignment="Left" Padding="22,11"
            Background="#2DA44E" Foreground="#FFFFFF" FontWeight="SemiBold" Cursor="Hand">
      <Button.Template>
        <ControlTemplate TargetType="Button">
          <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="Bd" Property="Opacity" Value="0.85"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter TargetName="Bd" Property="Opacity" Value="0.4"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Button.Template>
    </Button>
  </StackPanel>
</Window>
'@
    $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
    if (Test-Path $IconPath) { try { $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$IconPath) } catch { } }

    # Tudo que os botoes precisam fica em $script:Setup, porque o codigo de um
    # clique roda fora desta funcao.
    $script:Setup = @{ Window = $window; Result = $null; Clone = $null; Folder = $null; Timer = $null }
    foreach ($name in 'RepoBox', 'NickBox', 'FolderBox', 'StatusCard', 'StatusText', 'GoBtn') {
        $script:Setup[$name] = $window.FindName($name)
    }
    $script:Setup.NickBox.Text = $env:USERNAME
    $script:Setup.FolderBox.Text = $DefaultFolder

    # O download roda em segundo plano; este timer so confere quando terminou,
    # para a janela nao travar.
    $script:Setup.Timer = New-Object Windows.Threading.DispatcherTimer
    $script:Setup.Timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:Setup.Timer.Add_Tick({ Watch-SetupClone })

    $script:Setup.GoBtn.Add_Click({ Start-Setup })
    $window.Add_Closing({
        if ($script:Setup.Clone -and -not $script:Setup.Clone.HasExited) {
            $_.Cancel = $true
            [Windows.MessageBox]::Show($script:Setup.Window, 'Ainda estou baixando o servidor do grupo. Espere terminar.',
                'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        }
    })

    $window.ShowDialog() | Out-Null
    $script:Setup.Timer.Stop()
    return $script:Setup.Result
}

function Set-SetupStatus($text, $color = '#E6EDF3') {
    $script:Setup.StatusText.Text = $text
    $script:Setup.StatusText.Foreground = $color
    $script:Setup.StatusCard.Visibility = 'Visible'
}

function Set-SetupBusy($busy) {
    foreach ($name in 'GoBtn', 'RepoBox', 'NickBox', 'FolderBox') { $script:Setup[$name].IsEnabled = -not $busy }
}

# Ultimo passo: grava o nick, lembra a pasta e fecha a janela.
function Complete-Setup {
    $folder = $script:Setup.Folder
    if (-not (Test-Path (Join-Path $folder 'scripts\gui.ps1'))) {
        Set-SetupStatus 'O link foi baixado, mas esse repositório não tem o programa do Minecraft Compartilhado. Confira se o link é o do seu grupo.' '#F85149'
        Set-SetupBusy $false
        return
    }
    $nick = $script:Setup.NickBox.Text.Trim()
    Invoke-GitQuiet "-C `"$folder`" config user.name `"$nick`"" | Out-Null
    if (-not (Invoke-GitQuiet "-C `"$folder`" config user.email")) {
        Invoke-GitQuiet "-C `"$folder`" config user.email `"$($nick -replace '\s', '')@users.noreply.github.com`"" | Out-Null
    }
    Save-GroupFolder $folder
    $script:Setup.Result = $folder
    $script:Setup.Window.Close()
}

# Chamado pelo timer: o download terminou?
function Watch-SetupClone {
    $clone = $script:Setup.Clone
    if (-not $clone -or -not $clone.HasExited) { return }
    $script:Setup.Timer.Stop()
    $script:Setup.Clone = $null
    if ($clone.ExitCode -eq 0) {
        Complete-Setup
        return
    }
    $page = (($script:Setup.RepoBox.Text.Trim().TrimEnd('/')) -replace '\.git$', '')
    Set-SetupStatus ("O GitHub não deixou baixar. Os motivos mais comuns:`n" +
        "1. Você ainda não aceitou o convite. Abra no navegador: $page/invitations`n" +
        "2. Você entrou com uma conta do GitHub diferente da que foi convidada.`n" +
        "3. Quem criou o grupo ainda não te adicionou como colaborador.") '#F85149'
    Set-SetupBusy $false
}

# Clique em "Entrar no grupo".
function Start-Setup {
    $window = $script:Setup.Window
    $repo = $script:Setup.RepoBox.Text.Trim()
    $nick = $script:Setup.NickBox.Text.Trim()
    $folderText = $script:Setup.FolderBox.Text.Trim()
    if ($repo -notmatch '^https://github\.com/[\w.-]+/[\w.-]+/?$') {
        Set-SetupStatus 'O link do grupo precisa ser o endereço de um repositório do GitHub, como https://github.com/fulano/nosso-servidor' '#F85149'
        return
    }
    if ($nick -notmatch '^[\w .-]{2,32}$') {
        Set-SetupStatus 'Escolha um nick de 2 a 32 caracteres, só com letras, números, espaço, ponto, hífen ou sublinhado.' '#F85149'
        return
    }
    if (-not $folderText) { $folderText = $DefaultFolder }
    try { $folder = [IO.Path]::GetFullPath($folderText) } catch {
        Set-SetupStatus 'Esse caminho de pasta não é válido.' '#F85149'
        return
    }
    $script:Setup.Folder = $folder

    if (-not (Find-Git)) {
        $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        $question = "O Git não está instalado neste PC. Ele é o programa que baixa e envia o mundo.`n`n"
        if ($hasWinget) {
            $question += 'Instalar o Git agora? Vai abrir uma janela do instalador do Windows, que pode pedir permissão.'
        } else {
            $question += 'Abrir a página de download do Git? Instale com as opções padrão e depois clique em Entrar no grupo de novo.'
        }
        $answer = [Windows.MessageBox]::Show($window, $question, 'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        if (-not $hasWinget) {
            Start-Process 'https://git-scm.com/download/win'
            return
        }
        Set-SetupStatus 'Instalando o Git... acompanhe a janela que abriu.'
        Start-Process winget -ArgumentList 'install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements' -Wait
        if (-not (Find-Git)) {
            Set-SetupStatus 'A instalação do Git não terminou. Tente de novo, ou instale pelo site git-scm.com e volte aqui.' '#F85149'
            return
        }
    }

    if (Test-Path (Join-Path $folder '.git')) {
        # ja existe um servidor nessa pasta (instalacao anterior): reaproveita
        $existing = Invoke-GitQuiet "-C `"$folder`" remote get-url origin"
        if ((Get-RepoKey $existing) -ne (Get-RepoKey $repo)) {
            Set-SetupStatus "Essa pasta já tem o servidor de outro grupo ($existing). Escolha outra pasta." '#F85149'
            return
        }
        Complete-Setup
        return
    }
    if ((Test-Path $folder) -and (Get-ChildItem $folder -Force | Select-Object -First 1)) {
        Set-SetupStatus 'Essa pasta já existe e tem outras coisas dentro. Escolha uma pasta nova ou vazia.' '#F85149'
        return
    }

    Set-SetupBusy $true
    Set-SetupStatus 'Baixando o servidor do grupo... Se abrir uma janela de login do GitHub, entre com a conta que foi convidada para o grupo.'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = "clone `"$repo`" `"$folder`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $script:Setup.Clone = [System.Diagnostics.Process]::Start($psi)
    $script:Setup.Timer.Start()
}

# ---------------------------------------------------------------- inicio

if (-not $NoShow) {
    [void](Find-Git)   # deixa o Git no PATH para a interface e o servidor
    $folder = Get-GroupFolder
    if (-not $folder) { $folder = Show-SetupWindow }
    if ($folder) {
        & (Join-Path $folder 'scripts\gui.ps1')
    }
}
