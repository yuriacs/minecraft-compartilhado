# Interface grafica do servidor compartilhado.
#
# Esta janela nao faz nada sozinha: ela roda o scripts\host.ps1 em segundo
# plano (com -Gui), mostra a saida dele e responde as perguntas que ele faz.
# Toda a logica de trava, sincronizacao e servidor continua no host.ps1.
#
# Este arquivo precisa ser salvo como UTF-8 COM BOM por causa dos acentos.

param(
    [switch]$NoShow   # monta a janela mas nao abre (usado em testes)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$Root       = Split-Path -Parent $PSScriptRoot
$HostScript = Join-Path $PSScriptRoot 'host.ps1'

# ---------------------------------------------------------------- janela

[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Minecraft Compartilhado" Width="980" Height="760" MinWidth="780" MinHeight="640"
        Background="#161B22" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="#E6EDF3"/>
      <Setter Property="Background" Value="#30363D"/>
      <Setter Property="Padding" Value="18,10"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
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
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SmallBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Padding" Value="6,7"/>
      <Setter Property="Margin" Value="0,0,6,6"/>
      <Setter Property="FontSize" Value="12.5"/>
    </Style>
  </Window.Resources>

  <Grid Margin="22">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="Minecraft Compartilhado" FontSize="22" FontWeight="Bold" Margin="0,0,0,16"/>

    <!-- cartao de status -->
    <Border Grid.Row="1" Background="#21262D" CornerRadius="10" Padding="20">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Ellipse x:Name="Dot" Width="16" Height="16" Fill="#6E7681" VerticalAlignment="Top" Margin="0,6,14,0"/>
        <StackPanel Grid.Column="1">
          <TextBlock x:Name="StatusTitle" FontSize="19" FontWeight="SemiBold" TextWrapping="Wrap"/>
          <TextBlock x:Name="StatusDetail" Foreground="#9DA7B3" TextWrapping="Wrap" Margin="0,4,0,0"/>
          <StackPanel x:Name="AddressRow" Orientation="Horizontal" Margin="0,14,0,0">
            <Border Background="#0D1117" CornerRadius="6" Padding="14,8">
              <TextBlock x:Name="AddressText" FontFamily="Consolas" FontSize="17" Foreground="#7EE787"/>
            </Border>
            <Button x:Name="CopyBtn" Style="{StaticResource Btn}" Content="Copiar endereço" Margin="10,0,0,0"/>
          </StackPanel>
        </StackPanel>
      </Grid>
    </Border>

    <!-- acoes -->
    <DockPanel Grid.Row="2" Margin="0,16,0,16" LastChildFill="False">
      <Button x:Name="PrimaryBtn" Style="{StaticResource Btn}" DockPanel.Dock="Left"/>
      <Button x:Name="SecondaryBtn" Style="{StaticResource Btn}" DockPanel.Dock="Left"/>
      <Button x:Name="RefreshBtn" Style="{StaticResource Btn}" Content="Atualizar" DockPanel.Dock="Right" Margin="0"/>
      <Button x:Name="OptionsBtn" Style="{StaticResource Btn}" Content="Opções ▾" DockPanel.Dock="Right">
        <Button.ContextMenu>
          <ContextMenu>
            <MenuItem x:Name="MenuRestore" Header="Restaurar um save anterior..."/>
            <MenuItem x:Name="MenuPrune" Header="Compactar o histórico de saves..."/>
            <Separator/>
            <MenuItem x:Name="MenuDiscord" Header="Avisos no Discord..."/>
          </ContextMenu>
        </Button.ContextMenu>
      </Button>
    </DockPanel>

    <!-- console + jogadores -->
    <Grid Grid.Row="3">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Border Background="#0D1117" CornerRadius="8" Padding="4">
        <TextBox x:Name="LogBox" IsReadOnly="True" Background="Transparent" Foreground="#C9D1D9"
                 BorderThickness="0" FontFamily="Consolas" FontSize="12.5" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" Padding="8"/>
      </Border>

      <!-- so aparece com o servidor aberto neste PC -->
      <Border x:Name="PlayersPanel" Grid.Column="1" Width="260" Margin="12,0,0,0" Background="#21262D"
              CornerRadius="8" Padding="14" Visibility="Collapsed">
        <DockPanel>
          <TextBlock x:Name="PlayersTitle" DockPanel.Dock="Top" Text="Jogadores online (0)" FontWeight="SemiBold"/>
          <StackPanel DockPanel.Dock="Bottom">
            <TextBlock Text="Nick do jogador (ou clique nele na lista)" Foreground="#9DA7B3" FontSize="12" Margin="0,10,0,4"/>
            <TextBox x:Name="NickBox" Background="#0D1117" Foreground="#E6EDF3" CaretBrush="#E6EDF3"
                     BorderBrush="#30363D" Padding="8,6" Margin="0,0,0,8"/>
            <UniformGrid Columns="2" Margin="0,0,-6,0">
              <Button x:Name="WlAddBtn" Style="{StaticResource SmallBtn}" Content="Pôr na whitelist"/>
              <Button x:Name="WlRemoveBtn" Style="{StaticResource SmallBtn}" Content="Tirar da whitelist"/>
              <Button x:Name="OpBtn" Style="{StaticResource SmallBtn}" Content="Dar admin (op)"/>
              <Button x:Name="DeopBtn" Style="{StaticResource SmallBtn}" Content="Tirar admin"/>
            </UniformGrid>
            <Button x:Name="KickBtn" Style="{StaticResource SmallBtn}" Content="Expulsar do servidor" Margin="0,0,0,10"/>
            <CheckBox x:Name="WhitelistCheck" Content="Só entra quem está na whitelist" Foreground="#E6EDF3" FontSize="12.5"/>
          </StackPanel>
          <ListBox x:Name="PlayersList" Background="#0D1117" Foreground="#E6EDF3" BorderThickness="0"
                   Margin="0,8,0,0" Padding="4" FontSize="13.5" MinHeight="96"/>
        </DockPanel>
      </Border>
    </Grid>

    <Grid Grid.Row="4" Margin="0,10,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBox x:Name="CommandBox" Background="#0D1117" Foreground="#E6EDF3" CaretBrush="#E6EDF3"
               BorderBrush="#30363D" FontFamily="Consolas" Padding="10,8" VerticalContentAlignment="Center"
               ToolTip="Comando do servidor, sem a barra. Ex.: whitelist add Fulano"/>
      <Button x:Name="SendBtn" Grid.Column="1" Style="{StaticResource Btn}" Content="Enviar comando" Margin="10,0,0,0"/>
    </Grid>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))
foreach ($name in 'Dot', 'StatusTitle', 'StatusDetail', 'AddressRow', 'AddressText', 'CopyBtn',
                  'PrimaryBtn', 'SecondaryBtn', 'RefreshBtn', 'OptionsBtn', 'MenuRestore', 'MenuPrune', 'MenuDiscord',
                  'LogBox', 'CommandBox', 'SendBtn', 'PlayersPanel', 'PlayersTitle', 'PlayersList', 'NickBox',
                  'WlAddBtn', 'WlRemoveBtn', 'OpBtn', 'DeopBtn', 'KickBtn', 'WhitelistCheck') {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
}

# ---------------------------------------------------------------- estado

$script:Proc           = $null   # processo do host.ps1 em andamento (um por vez)
$script:Kind           = $null   # 'status' | 'saves' | 'host' | 'save' | 'maint'
$script:MaintTitle     = ''      # textos mostrados durante uma tarefa de manutencao
$script:MaintDetail    = ''
$script:Saves          = $null   # resposta do host.ps1 -ListSaves
$script:AfterSaves     = $null   # o que abrir quando a lista de saves chegar: 'restore' | 'prune'
$script:CanMaintain    = $false  # restaurar/compactar/configurar so com o servidor fechado
$script:Players        = New-Object System.Collections.Generic.List[string]
$script:Phase          = $null   # do host: 'sync' | 'running' | 'ready' | 'saving'
$script:OutTask        = $null
$script:ErrTask        = $null
$script:Status         = $null   # ultimo status recebido do host.ps1
$script:StatusFailed   = $false
$script:StatusLines    = @()     # saida da checagem de status (so vai para o log se falhar)
$script:Address        = ''
$script:Stopping       = $false
$script:CloseWhenDone  = $false
$script:PrimaryAction  = $null
$script:SecondaryAction = $null
$script:InTick         = $false
$script:IdleTicks      = 0

$Colors = @{ gray = '#6E7681'; green = '#3FB950'; yellow = '#D29922'; red = '#DA3633'; blue = '#1F6FEB' }

function Add-Log($text) {
    $clean = $text -replace "\x1B\[[0-9;?]*[A-Za-z]", ''   # tira codigos de cor ANSI
    $script:LogBox.AppendText($clean + "`r`n")
    if ($script:LogBox.Text.Length -gt 400000) {
        $script:LogBox.Text = $script:LogBox.Text.Substring($script:LogBox.Text.Length - 200000)
    }
    $script:LogBox.ScrollToEnd()
}

function Set-Button($button, $text, $color, $enabled) {
    if ($text) {
        $button.Content = $text
        $button.Background = $color
        $button.IsEnabled = $enabled
        $button.Visibility = 'Visible'
    } else {
        $button.Visibility = 'Collapsed'
    }
}

# Redesenha a janela inteira a partir do estado atual.
function Update-Ui {
    $dot = 'gray'; $title = ''; $detail = ''; $address = $null
    $primary = $null; $primaryText = $null; $primaryColor = $Colors.green; $primaryEnabled = $true
    $secondary = $null; $secondaryText = $null
    $busy = $null -ne $script:Proc
    $st = $script:Status

    if ($busy -and $script:Kind -eq 'host') {
        switch ($script:Phase) {
            'sync' {
                $dot = 'yellow'; $title = 'Preparando o servidor...'
                $detail = 'Baixando o mundo mais recente e reservando o servidor para você.'
                $primaryText = 'Aguarde...'; $primaryEnabled = $false
            }
            'running' {
                $dot = 'yellow'; $title = 'Carregando o mundo...'
                $detail = 'O Minecraft está iniciando. Leva cerca de meio minuto.'
                $address = $script:Address
                $primary = 'stop'; $primaryText = 'Parar e salvar'; $primaryColor = $Colors.red
            }
            'ready' {
                $dot = 'green'; $title = 'Você está hosteando'
                $detail = 'Passe o endereço abaixo para seus amigos. Você mesmo entra por: localhost'
                $address = $script:Address
                $primary = 'stop'; $primaryText = 'Parar e salvar'; $primaryColor = $Colors.red
            }
            'saving' {
                $dot = 'yellow'; $title = 'Salvando o mundo no GitHub...'
                $detail = 'Não feche esta janela nem desligue o PC até terminar.'
                $primaryText = 'Salvando...'; $primaryEnabled = $false
            }
        }
        if ($script:Stopping -and $script:Phase -ne 'saving') {
            $title = 'Fechando o servidor...'; $detail = 'Gravando o mundo no disco.'
            $primaryText = 'Parando...'; $primaryEnabled = $false; $primary = $null
        }
    }
    elseif ($busy -and $script:Kind -eq 'save') {
        $dot = 'yellow'; $title = 'Enviando o mundo para o GitHub...'
        $detail = 'Não feche esta janela até terminar.'
        $primaryText = 'Enviando...'; $primaryEnabled = $false
    }
    elseif ($busy -and $script:Kind -eq 'maint') {
        $dot = 'yellow'; $title = $script:MaintTitle
        $detail = $script:MaintDetail
        $primaryText = 'Aguarde...'; $primaryEnabled = $false
    }
    elseif (-not $st) {
        if ($busy) {
            $title = 'Verificando o servidor...'; $detail = 'Consultando o GitHub.'
        } else {
            $dot = 'red'; $title = 'Não consegui verificar o servidor'
            $detail = 'Confira a internet e o acesso ao repositório (detalhes no quadro abaixo) e clique em Atualizar.'
        }
        $primaryText = 'Hostear servidor'; $primaryEnabled = $false
    }
    elseif ($st.rodandoAqui) {
        $dot = 'green'; $title = 'O servidor já está aberto neste PC'
        $detail = 'Ele está rodando em outra janela. Feche por lá (digitando stop) para poder usar esta.'
        if ($st.trava) { $address = $st.trava.endereco }
        $primaryText = 'Hostear servidor'; $primaryEnabled = $false
    }
    elseif ($st.pendente) {
        $dot = 'yellow'; $title = 'Sua última sessão não foi enviada'
        $detail = 'O mundo que você jogou está salvo só neste PC. Envie agora, ou continue hosteando de onde parou.'
        $primary = 'save'; $primaryText = 'Enviar mundo agora'
        $secondary = 'host'; $secondaryText = 'Continuar hosteando'
    }
    elseif ($st.trava -and $st.trava.host -ne $st.eu) {
        $dot = 'green'; $title = "$($st.trava.host) está hosteando"
        $detail = "Desde $($st.trava.desde). Entre no Minecraft pelo endereço abaixo."
        $address = $st.trava.endereco
        if (-not $address) { $detail = "Desde $($st.trava.desde). Peça o endereço para $($st.trava.host)." }
        if ($st.semSinal) {
            # o host manda um sinal a cada backup automatico; sem sinal, provavelmente caiu
            $dot = 'yellow'; $title = "$($st.trava.host) pode ter caído"
            $detail = "Sem sinal há $($st.semSinalMin) min (o normal é um a cada $($st.backupMin) min). " +
                      'Se o servidor não responde, você pode assumir: perde-se só o que foi jogado depois do último backup.'
        } elseif ($null -ne $st.semSinalMin) {
            $detail += " Último sinal há $($st.semSinalMin) min."
        }
        $secondary = 'force'; $secondaryText = 'Assumir o servidor'
    }
    elseif ($st.trava) {
        $dot = 'yellow'; $title = 'O servidor está reservado no seu nome'
        $detail = 'Uma sessão sua em outro PC não foi encerrada. Você pode hostear daqui a partir do último mundo salvo.'
        $primary = 'host'; $primaryText = 'Hostear servidor'
    }
    else {
        $title = 'Ninguém está hosteando'
        $detail = 'Clique em Hostear servidor para abrir o mundo para o grupo.'
        $primary = 'host'; $primaryText = 'Hostear servidor'
    }

    # durante uma checagem de status os botoes ficam travados
    if ($busy -and $script:Kind -in 'status', 'saves') { $primaryEnabled = $false }

    $script:Dot.Fill = $Colors[$dot]
    $script:StatusTitle.Text = $title
    $script:StatusDetail.Text = $detail
    if ($address) {
        $script:AddressText.Text = $address
        $script:AddressRow.Visibility = 'Visible'
    } else {
        $script:AddressRow.Visibility = 'Collapsed'
    }

    $script:PrimaryAction = $primary
    $script:SecondaryAction = $secondary
    Set-Button $script:PrimaryBtn $primaryText $primaryColor $primaryEnabled
    Set-Button $script:SecondaryBtn $secondaryText '#30363D' (-not $busy)

    $script:RefreshBtn.IsEnabled = -not $busy
    # restaurar, compactar e configurar valem para o grupo todo e so podem ser
    # feitos com o servidor fechado e nada pendente neste PC
    $script:CanMaintain = [bool]((-not $busy) -and $st -and (-not $st.trava) -and (-not $st.pendente) -and (-not $st.rodandoAqui))
    $script:OptionsBtn.IsEnabled = -not $busy
    $script:MenuDiscord.Header = if ($st -and $st.discord) { 'Avisos no Discord: ligados...' } else { 'Ligar avisos no Discord...' }
    $serverUp = $busy -and $script:Kind -eq 'host' -and $script:Phase -in 'running', 'ready' -and -not $script:Stopping
    $script:CommandBox.IsEnabled = $serverUp
    $script:SendBtn.IsEnabled = $serverUp
    $script:PlayersPanel.Visibility = if ($serverUp) { 'Visible' } else { 'Collapsed' }
}

# ---------------------------------------------------------------- jogadores

function Update-Players {
    $script:PlayersList.Items.Clear()
    foreach ($name in $script:Players) { [void]$script:PlayersList.Items.Add($name) }
    $script:PlayersTitle.Text = "Jogadores online ($($script:Players.Count))"
}

# Acompanha quem esta online pelas mensagens do proprio servidor.
function Watch-Players($line) {
    if ($line -match '\]: (\S+) joined the game$') {
        if (-not $script:Players.Contains($Matches[1])) { $script:Players.Add($Matches[1]) }
    } elseif ($line -match '\]: (\S+) left the game$') {
        [void]$script:Players.Remove($Matches[1])
    } elseif ($line -match 'There are \d+ of a max of \d+ players online:(.*)$') {
        # resposta do comando "list": acerta a lista inteira
        $script:Players.Clear()
        $Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { $script:Players.Add($_) }
    } else {
        return
    }
    Update-Players
}

function Read-WhitelistOn {
    $file = Join-Path $Root 'server\server.properties'
    if (-not (Test-Path $file)) { return $false }
    return [bool](@(Get-Content $file) -match '^white-list=true')
}

# Manda ao servidor um comando sobre o jogador do campo de nick.
function Send-PlayerCommand($template) {
    $nick = $script:NickBox.Text.Trim()
    if ($nick -notmatch '^[.\w]{2,32}$') {
        [Windows.MessageBox]::Show($Window, 'Digite o nick do jogador, ou clique nele na lista de quem está online.',
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    $command = $template -f $nick
    Add-Log "> $command"
    Send-ToHost $command
}

# ---------------------------------------------------------------- host.ps1

function Start-HostScript($kind, $extraArgs) {
    if ($script:Proc) { return }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$HostScript`" -Gui -ParentPid $PID $extraArgs"
    $psi.WorkingDirectory = $Root
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

    $script:Kind = $kind
    $script:Phase = if ($kind -eq 'host') { 'sync' } else { $null }
    if ($kind -eq 'host') { $script:Players.Clear(); Update-Players }
    $script:Stopping = $false
    $script:StatusLines = @()
    $script:Proc = [System.Diagnostics.Process]::Start($psi)
    # Leitura assincrona consultada pelo timer: nenhum codigo PowerShell roda
    # fora da thread da janela.
    $script:OutTask = $script:Proc.StandardOutput.ReadLineAsync()
    $script:ErrTask = $script:Proc.StandardError.ReadLineAsync()
    Update-Ui
}

function Send-ToHost($line) {
    if ($script:Proc -and -not $script:Proc.HasExited) {
        $script:Proc.StandardInput.WriteLine($line)
        $script:Proc.StandardInput.Flush()
    }
}

function Ask-User($code, $arg) {
    $text = switch ($code) {
        'eula' {
            "Para rodar o servidor é preciso aceitar a licença (EULA) do Minecraft:`n" +
            "https://aka.ms/MinecraftEULA`n`nVocê leu e aceita a EULA?"
        }
        'descartar-local' {
            "Existem alterações neste PC que não estão no GitHub (a lista está no quadro de mensagens).`n`n" +
            "Descartar essas alterações e usar a versão do GitHub?"
        }
        'descartar-superada' {
            "Sua última sessão não foi salva e outra pessoa já hosteou depois.`n`n" +
            "O progresso que ficou só neste PC precisa ser descartado para continuar. Descartar?"
        }
        'assumir' {
            "Assumir vai usar o último backup do mundo.`n" +
            "O que $arg jogou depois dele será perdido.`n`nAssumir mesmo assim?"
        }
        default { "Confirmar ($code)?" }
    }
    $icon = if ($code -eq 'eula') { 'Question' } else { 'Warning' }
    $answer = [Windows.MessageBox]::Show($Window, $text, 'Minecraft Compartilhado', 'YesNo', $icon)
    return ($answer -eq 'Yes')
}

function Receive-Line($line) {
    if ($line.StartsWith('@@')) {
        $parts = $line.Substring(2) -split '@@'
        switch ($parts[0]) {
            'STATUS' {
                $script:Status = ($parts[1..($parts.Count - 1)] -join '@@') | ConvertFrom-Json
                $script:StatusFailed = $false
            }
            'SAVES' {
                $script:Saves = ($parts[1..($parts.Count - 1)] -join '@@') | ConvertFrom-Json
            }
            'STATE' {
                $script:Phase = $parts[1]
                if ($parts[1] -eq 'running') { $script:Address = $parts[2] }
            }
            'ASK' {
                $yes = Ask-User $parts[1] $parts[2]
                Send-ToHost $(if ($yes) { 's' } else { 'n' })
            }
        }
        Update-Ui
        return
    }

    if ($script:Kind -in 'status', 'saves') {
        $script:StatusLines += $line
        return
    }

    Add-Log $line
    # O Paper escreve "Done (12.3s)!" quando o mundo terminou de carregar.
    if ($script:Kind -eq 'host' -and $script:Phase -eq 'running' -and $line -match '\]: Done \(') {
        $script:Phase = 'ready'
        $script:WhitelistCheck.IsChecked = Read-WhitelistOn
        Update-Ui
    }
    if ($script:Kind -eq 'host') { Watch-Players $line }
}

# Le o que ja chegou de uma das saidas. Devolve a proxima leitura pendente,
# ou $null quando a saida acabou.
function Read-Pending($task, $reader) {
    $count = 0
    while ($task -and $task.IsCompleted -and $count -lt 300) {
        $line = $task.Result
        if ($null -eq $line) { return $null }
        Receive-Line $line
        $task = $reader.ReadLineAsync()
        $count++
    }
    return $task
}

function Complete-HostScript {
    $kind = $script:Kind
    $code = $script:Proc.ExitCode
    $script:Proc.Dispose()
    $script:Proc = $null
    $script:Kind = $null
    $script:Phase = $null
    $script:Stopping = $false

    if ($kind -eq 'status') {
        if ($code -ne 0) {
            $script:Status = $null
            $script:StatusFailed = $true
            $script:StatusLines | Where-Object { $_.Trim() } | ForEach-Object { Add-Log $_ }
        }
        Update-Ui
    } elseif ($kind -eq 'saves') {
        Update-Ui
        if ($code -ne 0 -or -not $script:Saves) {
            $script:StatusLines | Where-Object { $_.Trim() } | ForEach-Object { Add-Log $_ }
            Add-Log 'Não consegui ler a lista de saves.'
        } elseif ($script:AfterSaves -eq 'restore') {
            Show-RestoreDialog
        } elseif ($script:AfterSaves -eq 'prune') {
            Show-PruneDialog
        }
    } else {
        Add-Log ''
        Start-HostScript 'status' '-Status'   # mostra o resultado real apos hostear/salvar
    }

    if ($script:CloseWhenDone -and $kind -ne 'status') { $Window.Close() }
}

$Timer = New-Object Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(100)
$Timer.Add_Tick({
    if ($script:InTick) { return }   # uma caixa de pergunta aberta mantem o timer rodando
    $script:InTick = $true
    try {
        if ($script:Proc) {
            $script:IdleTicks = 0
            $script:OutTask = Read-Pending $script:OutTask $script:Proc.StandardOutput
            $script:ErrTask = Read-Pending $script:ErrTask $script:Proc.StandardError
            if ($null -eq $script:OutTask -and $null -eq $script:ErrTask -and $script:Proc.HasExited) {
                Complete-HostScript
            }
        } else {
            # parado: confere o status sozinho a cada 30 segundos
            $script:IdleTicks++
            if ($script:IdleTicks -ge 300) {
                $script:IdleTicks = 0
                Start-HostScript 'status' '-Status'
            }
        }
    } catch {
        Add-Log "[interface] $_"
    } finally {
        $script:InTick = $false
    }
})

# ---------------------------------------------------------------- botoes

function Invoke-Action($action) {
    switch ($action) {
        'host'  { $script:LogBox.Clear(); Start-HostScript 'host' '' }
        'force' { $script:LogBox.Clear(); Start-HostScript 'host' '-Force' }
        'save'  { $script:LogBox.Clear(); Start-HostScript 'save' '-SaveOnly' }
        'stop'  {
            $script:Stopping = $true
            Send-ToHost 'stop'
            Update-Ui
        }
    }
}

function Send-Command {
    $command = $script:CommandBox.Text.Trim().TrimStart('/')
    if (-not $command) { return }
    Add-Log "> $command"
    if ($command -eq 'stop') { Invoke-Action 'stop' } else { Send-ToHost $command }
    $script:CommandBox.Clear()
}

$PrimaryBtn.Add_Click({ Invoke-Action $script:PrimaryAction })
$SecondaryBtn.Add_Click({ Invoke-Action $script:SecondaryAction })
$RefreshBtn.Add_Click({ Start-HostScript 'status' '-Status' })
$SendBtn.Add_Click({ Send-Command })
# ---------------------------------------------------------------- opcoes

function Start-Maintenance($title, $detail, $arguments) {
    $script:MaintTitle = $title
    $script:MaintDetail = $detail
    $script:LogBox.Clear()
    Start-HostScript 'maint' $arguments
}

# As opcoes mexem no repositorio do grupo todo: so com o servidor fechado.
function Test-CanMaintain {
    if ($script:CanMaintain) { return $true }
    [Windows.MessageBox]::Show($Window,
        'Isso só pode ser feito com o servidor fechado e sem nada pendente para enviar neste PC.',
        'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
    return $false
}

function Show-DiscordDialog {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $prompt = "Cole aqui o link do webhook do canal onde os avisos devem aparecer.`n`n" +
              "No Discord: Editar canal > Integrações > Webhooks > Novo webhook > Copiar URL do webhook.`n`n" +
              'Para desligar os avisos, deixe em branco.'
    $url = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, 'Avisos no Discord', '').Trim()
    if (-not $url) {
        # em branco tambem e o que o botao Cancelar devolve: so desliga se confirmar
        if (-not ($script:Status -and $script:Status.discord)) { return }
        $answer = [Windows.MessageBox]::Show($Window, 'Desligar os avisos no Discord para o grupo todo?',
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $url = 'off'
    }
    if ($url -match '[\s"]') {
        [Windows.MessageBox]::Show($Window, 'Esse link tem espaços ou aspas. Copie de novo a URL do webhook.',
            'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    Start-Maintenance 'Configurando os avisos do Discord...' 'Testando o link e gravando a configuração para o grupo todo.' "-SetWebhook `"$url`""
}

# Texto de um save na lista: "13/11/2026 18:27   Mundo salvo por Fulano"
function Format-Save($save) {
    $text = $save.texto -replace '\s*\(\d{4}-\d\d-\d\d \d\d:\d\d\)$', ''
    $text = $text -replace '^Backup automatico \((.+?), \d\d:\d\d\)$', 'Backup automático ($1)'
    return "$($save.quando)    $text"
}

function Show-RestoreDialog {
    $saves = @($script:Saves.saves)
    if ($saves.Count -eq 0) {
        [Windows.MessageBox]::Show($Window, 'Ainda não há nenhum save guardado.', 'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    [xml]$dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Restaurar um save anterior" Width="680" Height="520" MinWidth="420" MinHeight="320"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <DockPanel Margin="18">
    <TextBlock DockPanel.Dock="Top" TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,0,0,12"
               Text="Escolha para qual save o mundo deve voltar. O mundo de agora não é apagado: ele continua nesta lista e dá para voltar a ele depois."/>
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,0">
      <Button Name="CancelBtn" Content="Cancelar" Padding="18,9" Margin="0,0,10,0" IsCancel="True"/>
      <Button Name="OkBtn" Content="Restaurar este save" Padding="18,9" IsEnabled="False"/>
    </StackPanel>
    <ListBox Name="SaveList" Background="#0D1117" Foreground="#E6EDF3" BorderThickness="0" Padding="6"
             ScrollViewer.HorizontalScrollBarVisibility="Disabled"
             FontFamily="Consolas" FontSize="13"/>
  </DockPanel>
</Window>
'@
    $dialog = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dialogXaml))
    $dialog.Owner = $Window
    $list = $dialog.FindName('SaveList')
    $ok = $dialog.FindName('OkBtn')
    foreach ($save in $saves) { [void]$list.Items.Add((Format-Save $save)) }
    if ($saves.Count -gt 0) { $list.Items[0] = "$($list.Items[0])    (mundo atual)" }
    $list.Add_SelectionChanged({ $ok.IsEnabled = ($list.SelectedIndex -gt 0) }.GetNewClosure())
    $ok.Add_Click({ $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }

    $chosen = $saves[$list.SelectedIndex]
    $answer = [Windows.MessageBox]::Show($Window,
        "Voltar o mundo para o save de $($chosen.quando)?`n`nTudo que foi jogado depois disso sai do mundo (mas continua guardado na lista de saves).",
        'Minecraft Compartilhado', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    Start-Maintenance 'Restaurando o mundo...' "Voltando para o save de $($chosen.quando) e enviando para o GitHub." "-Restore $($chosen.id)"
}

function Show-PruneDialog {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $total = [int]$script:Saves.total
    $prompt = "O histórico tem $total saves guardados (a pasta do histórico ocupa $($script:Saves.mb) MB neste PC).`n`n" +
              "Quantos dos saves mais recentes você quer manter?`n`n" +
              'Os mais antigos são apagados de vez e não poderão mais ser restaurados. O mundo atual não muda.'
    $typed = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, 'Compactar o histórico de saves', '30').Trim()
    if (-not $typed) { return }
    $keep = 0
    if (-not [int]::TryParse($typed, [ref]$keep) -or $keep -lt 5) {
        [Windows.MessageBox]::Show($Window, 'Digite um número a partir de 5.', 'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    if ($total -le $keep) {
        [Windows.MessageBox]::Show($Window, "O histórico só tem $total saves. Não há nada para compactar ainda.",
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    $answer = [Windows.MessageBox]::Show($Window,
        "Apagar de vez os $($total - $keep) saves mais antigos e manter os $keep mais recentes?`n`nIsso não pode ser desfeito.",
        'Minecraft Compartilhado', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    Start-Maintenance 'Compactando o histórico...' 'Reescrevendo o histórico e enviando para o GitHub. Pode levar alguns minutos em mundos grandes.' "-Prune $keep"
}

$OptionsBtn.Add_Click({
    $menu = $script:OptionsBtn.ContextMenu
    $menu.PlacementTarget = $script:OptionsBtn
    $menu.Placement = 'Bottom'
    $menu.IsOpen = $true
})
$MenuDiscord.Add_Click({ if (Test-CanMaintain) { Show-DiscordDialog } })
$MenuRestore.Add_Click({
    if (Test-CanMaintain) { $script:AfterSaves = 'restore'; $script:Saves = $null; Start-HostScript 'saves' '-ListSaves' }
})
$MenuPrune.Add_Click({
    if (Test-CanMaintain) { $script:AfterSaves = 'prune'; $script:Saves = $null; Start-HostScript 'saves' '-ListSaves' }
})

# ---------------------------------------------------------------- jogadores (botoes)

$PlayersList.Add_SelectionChanged({
    if ($script:PlayersList.SelectedItem) { $script:NickBox.Text = [string]$script:PlayersList.SelectedItem }
})
$WlAddBtn.Add_Click({ Send-PlayerCommand 'whitelist add {0}' })
$WlRemoveBtn.Add_Click({ Send-PlayerCommand 'whitelist remove {0}' })
$OpBtn.Add_Click({ Send-PlayerCommand 'op {0}' })
$DeopBtn.Add_Click({ Send-PlayerCommand 'deop {0}' })
$KickBtn.Add_Click({ Send-PlayerCommand 'kick {0}' })
$WhitelistCheck.Add_Click({
    $command = if ($script:WhitelistCheck.IsChecked) { 'whitelist on' } else { 'whitelist off' }
    Add-Log "> $command"
    Send-ToHost $command
})
$CommandBox.Add_KeyDown({ if ($_.Key -eq 'Return') { Send-Command } })
$CopyBtn.Add_Click({
    [Windows.Clipboard]::SetText($script:AddressText.Text)
    $script:CopyBtn.Content = 'Copiado!'
})
$CopyBtn.Add_MouseLeave({ $script:CopyBtn.Content = 'Copiar endereço' })

$Window.Add_Closing({
    if (-not $script:Proc -or $script:Kind -in 'status', 'saves') { return }
    if ($script:CloseWhenDone) { $_.Cancel = $true; return }   # ja esta fechando, so falta salvar

    $_.Cancel = $true
    $serverUp = $script:Kind -eq 'host' -and $script:Phase -in 'running', 'ready'
    if ($serverUp -and -not $script:Stopping) {
        $answer = [Windows.MessageBox]::Show($Window,
            "O servidor está aberto.`n`nParar o servidor, salvar o mundo no GitHub e fechar?",
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -eq 'Yes') {
            $script:CloseWhenDone = $true
            Invoke-Action 'stop'
        }
    } else {
        [Windows.MessageBox]::Show($Window,
            'Ainda estou sincronizando com o GitHub. Espere terminar para fechar.',
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
    }
})

$Window.Add_Closed({
    $Timer.Stop()
    if ($script:Proc -and -not $script:Proc.HasExited) { $script:Proc.Kill() }   # so sobra checagem de status
})

# ---------------------------------------------------------------- inicio

Update-Ui
$Timer.Start()
Start-HostScript 'status' '-Status'

if (-not $NoShow) {
    # impede duas janelas da interface no mesmo PC
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, 'MinecraftCompartilhadoGui', [ref]$created)
    if (-not $created) {
        [Windows.MessageBox]::Show('O Minecraft Compartilhado já está aberto.', 'Minecraft Compartilhado') | Out-Null
        exit
    }
    $Window.ShowDialog() | Out-Null
    $mutex.ReleaseMutex()
}
