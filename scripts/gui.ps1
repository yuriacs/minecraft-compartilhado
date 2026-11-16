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

# ---------------------------------------------------------------- idioma
#
# Portugues ou ingles: o escolhido em Ajustes deste PC ou, sem escolha, o do
# Windows. Cada texto aparece como (Tx 'portugues' 'ingles'); os das janelas
# (XAML) sao trocados pela tabela abaixo antes de cada janela ser montada.
$Lang = ''
try { $Lang = [string](Get-Content (Join-Path $Root '.runtime\local.json') -Raw -ErrorAction Stop | ConvertFrom-Json).idioma } catch { }
if ($Lang -notin 'pt', 'en') {
    $Lang = 'en'
    if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'pt') { $Lang = 'pt' }
}
function Tx($pt, $en) {
    if ($Lang -eq 'en') { return $en }
    return $pt
}

$XamlEnglish = [ordered]@{
    'Copiar endereço' = 'Copy address'
    'Atualizar' = 'Refresh'
    'Opções ▾' = 'Options ▾'
    'Atualizar o programa...' = 'Update the program...'
    'Plugins do servidor...' = 'Server plugins...'
    'Importar modpack (.zip ou .mrpack)...' = 'Import modpack (.zip or .mrpack)...'
    'Mods para jogar neste PC...' = 'Mods to play on this PC...'
    'Tipo de servidor e versão do Minecraft...' = 'Server type and Minecraft version...'
    'Ajustes deste PC (memória, idioma, fechar quando esvaziar)...' = 'This PC''s settings (memory, language, close when empty)...'
    'Restaurar um save anterior...' = 'Restore a previous save...'
    'Compactar o histórico de saves...' = 'Compact the save history...'
    'Avisos no Discord...' = 'Discord notifications...'
    'Conexão por túnel (sem Radmin)...' = 'Tunnel connection (no Radmin)...'
    'Conexão direta (porta no roteador)...' = 'Direct connection (router port)...'
    'Jogadores online (0)' = 'Players online (0)'
    'Nick do jogador (ou clique nele na lista)' = 'Player nickname (or click it in the list)'
    'Pôr na whitelist' = 'Add to whitelist'
    'Tirar da whitelist' = 'Unwhitelist'
    'Dar admin (op)' = 'Make admin (op)'
    'Tirar admin' = 'Remove admin'
    'Expulsar do servidor' = 'Kick from server'
    'Só entra quem está na whitelist' = 'Only whitelisted players can join'
    'Comando do servidor, sem a barra. Ex.: whitelist add Fulano' = 'Server command, without the slash. E.g.: whitelist add Steve'
    'Enviar comando' = 'Send command'
    'Adicionar arquivos...' = 'Add files...'
    'Remover selecionado' = 'Remove selected'
    'Salvar e enviar' = 'Save and upload'
    'Cancelar' = 'Cancel'
    'Nenhum arquivo ainda.' = 'No files yet.'
    'Importar modpack' = 'Import modpack'
    'Confira o que o programa deduziu do arquivo. Os valores certos estão na página do modpack.' = 'Check what the program worked out from the file. The correct values are on the modpack page.'
    'Carregador de mods' = 'Mod loader'
    'Versão do Minecraft' = 'Minecraft version'
    'Versão do carregador' = 'Loader version'
    'Em branco usa a versão mais recente para esse Minecraft' = 'Leave empty to use the latest version for that Minecraft'
    'Começar um mundo novo' = 'Start a new world'
    'Importar' = 'Import'
    'Tipo de servidor e versão do Minecraft' = 'Server type and Minecraft version'
    'Tipo de servidor' = 'Server type'
    'Paper: aceita plugins. Quem joga usa o Minecraft normal, sem instalar nada.' = 'Paper: accepts plugins. Players use regular Minecraft, without installing anything.'
    'Fabric: aceita mods. Todos precisam do Fabric e dos mesmos mods no jogo.' = 'Fabric: accepts mods. Everyone needs Fabric and the same mods in the game.'
    'NeoForge (experimental): aceita mods; o mais usado em modpacks recentes.' = 'NeoForge (experimental): accepts mods; the most used in recent modpacks.'
    'Forge (experimental): aceita mods; comum em modpacks de versões antigas.' = 'Forge (experimental): accepts mods; common in modpacks for older versions.'
    'Todos do grupo precisam jogar na mesma versão. Voltar para uma versão mais antiga pode estragar partes do mundo. Trocar entre Paper e um servidor com mods começa um MUNDO NOVO, porque um não abre o mundo do outro; o mundo atual continua guardado nos saves.' = 'Everyone in the group needs to play on the same version. Going back to an older version can break parts of the world. Switching between Paper and a modded server starts a NEW WORLD, because one can''t open the other''s world; the current world is still kept in the saves.'
    'Salvar' = 'Save'
    'Ajustes deste PC' = 'This PC''s settings'
    'Memória do servidor' = 'Server memory'
    'Fechar sozinho quando esvaziar' = 'Close by itself when empty'
    'Se ninguém estiver online por esse tempo, o servidor salva o mundo, fecha e libera a vez para outra pessoa hostear. Enquanto o servidor está aberto, o programa já impede o PC de suspender por inatividade.' = 'If nobody is online for this long, the server saves the world, closes and frees the turn for someone else to host. While the server is open, the program already keeps the PC from going to sleep due to inactivity.'
    'Idioma do programa' = 'Program language'
    'Mods para jogar neste PC' = 'Mods to play on this PC'
    '2. Copie os mods do grupo' = '2. Copy the group''s mods'
    'Copia os mods do servidor para a pasta de mods do seu Minecraft. Repita sempre que o grupo mudar os mods. Mods que você colocou por conta própria não são apagados.' = 'Copies the server''s mods into your Minecraft mods folder. Repeat whenever the group changes the mods. Mods you added yourself are not deleted.'
    'Copiar os mods do grupo' = 'Copy the group''s mods'
    'Abrir a pasta dos mods do grupo' = 'Open the group''s mods folder'
    'Fechar' = 'Close'
    'Conexão por túnel' = 'Tunnel connection'
    'Com o túnel do playit.gg, quem hosteia abre um endereço público e os amigos entram por ele sem instalar o Radmin nem nada. Vale para o grupo todo.' = 'With the playit.gg tunnel, whoever hosts opens a public address and friends join through it without installing Radmin or anything else. Applies to the whole group.'
    'Chave secreta do agente' = 'Agent secret key'
    'No site do playit.gg, ao criar um agente do tipo Docker: é o valor que aparece depois de SECRET_KEY=. Ela fica guardada no repositório privado do grupo.' = 'On the playit.gg site, when creating an agent of type Docker: it is the value shown after SECRET_KEY=. It is kept in the group''s private repository.'
    'Já existe uma chave gravada. Deixe em branco para mantê-la.' = 'A key is already saved. Leave empty to keep it.'
    'Endereço público do túnel' = 'Public tunnel address'
    'O endereço que o playit mostra para o túnel de Minecraft Java, como nome.gl.joinmc.link. É o que os amigos digitam no jogo. Se ainda não criou o túnel, deixe em branco: salve a chave, hosteie uma vez para o playit reconhecer o agente, crie o túnel no site e volte aqui.' = 'The address playit shows for the Minecraft Java tunnel, like name.gl.joinmc.link. It is what friends type in the game. If you haven''t created the tunnel yet, leave it empty: save the key, host once so playit recognizes the agent, create the tunnel on the site and come back here.'
    'Com o túnel, o servidor fica alcançável pela internet. Mantenha ligada a opção &quot;Só entra quem está na whitelist&quot;.' = 'With the tunnel, the server is reachable from the internet. Keep the &quot;Only whitelisted players can join&quot; option on.'
    'Desligar o túnel' = 'Turn off the tunnel'
    'Restaurar um save anterior' = 'Restore a previous save'
    'Escolha para qual save o mundo deve voltar. O mundo de agora não é apagado: ele continua nesta lista e dá para voltar a ele depois.' = 'Choose which save the world should go back to. The current world is not deleted: it stays in this list and you can go back to it later.'
    'Restaurar este save' = 'Restore this save'
}
function Convert-Xaml([string]$text) {
    if ($Lang -ne 'en') { return $text }
    foreach ($pair in $XamlEnglish.GetEnumerator()) {
        $text = $text.Replace('="' + $pair.Key + '"', '="' + $pair.Value + '"')
    }
    return $text
}

[xml]$Xaml = Convert-Xaml @'
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
            <MenuItem x:Name="MenuUpdate" Header="Atualizar o programa..." Visibility="Collapsed" FontWeight="Bold"/>
            <MenuItem x:Name="MenuAddons" Header="Plugins do servidor..."/>
            <MenuItem x:Name="MenuPack" Header="Importar modpack (.zip ou .mrpack)..."/>
            <MenuItem x:Name="MenuClientMods" Header="Mods para jogar neste PC..." Visibility="Collapsed"/>
            <MenuItem x:Name="MenuServer" Header="Tipo de servidor e versão do Minecraft..."/>
            <MenuItem x:Name="MenuMemory" Header="Ajustes deste PC (memória, idioma, fechar quando esvaziar)..."/>
            <Separator/>
            <MenuItem x:Name="MenuRestore" Header="Restaurar um save anterior..."/>
            <MenuItem x:Name="MenuPrune" Header="Compactar o histórico de saves..."/>
            <Separator/>
            <MenuItem x:Name="MenuDiscord" Header="Avisos no Discord..."/>
            <MenuItem x:Name="MenuTunnel" Header="Conexão por túnel (sem Radmin)..."/>
            <MenuItem x:Name="MenuDirect" Header="Conexão direta (porta no roteador)..."/>
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
$IconPath = Join-Path $PSScriptRoot 'app.ico'
if (Test-Path $IconPath) { try { $Window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$IconPath) } catch { } }
foreach ($name in 'Dot', 'StatusTitle', 'StatusDetail', 'AddressRow', 'AddressText', 'CopyBtn',
                  'PrimaryBtn', 'SecondaryBtn', 'RefreshBtn', 'OptionsBtn', 'MenuRestore', 'MenuPrune', 'MenuDiscord', 'MenuTunnel',
                  'MenuUpdate', 'MenuAddons', 'MenuClientMods', 'MenuServer', 'MenuMemory', 'MenuDirect', 'MenuPack',
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
$script:AfterSaves     = $null   # o que fazer quando uma consulta silenciosa terminar:
                                 # 'restore' | 'prune' | 'server' | 'copymods'
$script:Versions       = $null   # resposta do host.ps1 -ListVersions
# consultas que rodam sem mostrar nada no quadro de mensagens
$script:QuietKinds     = 'status', 'saves', 'versions', 'sync', 'inspect'
$script:Pack           = $null   # resposta do host.ps1 -InspectPack
$script:PackPath       = ''      # arquivo do modpack escolhido
$script:CanMaintain    = $false  # restaurar/compactar/configurar so com o servidor fechado
$script:Players        = New-Object System.Collections.Generic.List[string]
$script:Phase          = $null   # do host: 'sync' | 'running' | 'ready' | 'saving'
$script:OutTask        = $null
$script:ErrTask        = $null
$script:Status         = $null   # ultimo status recebido do host.ps1
$script:StatusFailed   = $false
$script:StatusLines    = @()     # saida da checagem de status (so vai para o log se falhar)
$script:Address        = ''
$script:Reserve        = ''      # endereco alternativo (tunel) quando a conexao e direta
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
                $dot = 'yellow'; $title = (Tx 'Preparando o servidor...' 'Preparing the server...')
                $detail = (Tx 'Baixando o mundo mais recente e reservando o servidor para você.' 'Downloading the latest world and reserving the server for you.')
                $primaryText = (Tx 'Aguarde...' 'Please wait...'); $primaryEnabled = $false
            }
            'running' {
                $dot = 'yellow'; $title = (Tx 'Carregando o mundo...' 'Loading the world...')
                $detail = (Tx 'O Minecraft está iniciando. Leva cerca de meio minuto.' 'Minecraft is starting. It takes about half a minute.')
                $address = $script:Address
                $primary = 'stop'; $primaryText = (Tx 'Parar e salvar' 'Stop and save'); $primaryColor = $Colors.red
            }
            'ready' {
                $dot = 'green'; $title = (Tx 'Você está hosteando' 'You''re hosting')
                $detail = (Tx 'Passe o endereço abaixo para seus amigos. Você mesmo entra por: localhost' 'Give the address below to your friends. You join through: localhost')
                if ($script:Reserve) { $detail += (Tx "`nSe algum amigo não conseguir conectar, o endereço reserva é: $($script:Reserve)" "`nIf a friend can't connect, the backup address is: $($script:Reserve)") }
                $address = $script:Address
                $primary = 'stop'; $primaryText = (Tx 'Parar e salvar' 'Stop and save'); $primaryColor = $Colors.red
            }
            'saving' {
                $dot = 'yellow'; $title = (Tx 'Salvando o mundo no GitHub...' 'Saving the world to GitHub...')
                $detail = (Tx 'Não feche esta janela nem desligue o PC até terminar.' 'Don''t close this window or turn off the PC until it finishes.')
                $primaryText = (Tx 'Salvando...' 'Saving...'); $primaryEnabled = $false
            }
        }
        if ($script:Stopping -and $script:Phase -ne 'saving') {
            $title = (Tx 'Fechando o servidor...' 'Closing the server...'); $detail = (Tx 'Gravando o mundo no disco.' 'Writing the world to disk.')
            $primaryText = (Tx 'Parando...' 'Stopping...'); $primaryEnabled = $false; $primary = $null
        }
    }
    elseif ($busy -and $script:Kind -eq 'save') {
        $dot = 'yellow'; $title = (Tx 'Enviando o mundo para o GitHub...' 'Uploading the world to GitHub...')
        $detail = (Tx 'Não feche esta janela até terminar.' 'Don''t close this window until it finishes.')
        $primaryText = (Tx 'Enviando...' 'Uploading...'); $primaryEnabled = $false
    }
    elseif ($busy -and $script:Kind -eq 'maint') {
        $dot = 'yellow'; $title = $script:MaintTitle
        $detail = $script:MaintDetail
        $primaryText = (Tx 'Aguarde...' 'Please wait...'); $primaryEnabled = $false
    }
    elseif (-not $st) {
        if ($busy) {
            $title = (Tx 'Verificando o servidor...' 'Checking the server...'); $detail = (Tx 'Consultando o GitHub.' 'Checking GitHub.')
        } else {
            $dot = 'red'; $title = (Tx 'Não consegui verificar o servidor' 'Couldn''t check the server')
            $detail = (Tx 'Confira a internet e o acesso ao repositório (detalhes no quadro abaixo) e clique em Atualizar.' 'Check your internet and your access to the repository (details in the box below) and click Refresh.')
        }
        $primaryText = (Tx 'Hostear servidor' 'Host server'); $primaryEnabled = $false
    }
    elseif ($st.rodandoAqui) {
        $dot = 'green'; $title = (Tx 'O servidor já está aberto neste PC' 'The server is already open on this PC')
        $detail = (Tx 'Ele está rodando em outra janela. Feche por lá (digitando stop) para poder usar esta.' 'It''s running in another window. Close it there (by typing stop) to use this one.')
        if ($st.trava) { $address = $st.trava.endereco }
        $primaryText = (Tx 'Hostear servidor' 'Host server'); $primaryEnabled = $false
    }
    elseif ($st.pendente) {
        $dot = 'yellow'; $title = (Tx 'Sua última sessão não foi enviada' 'Your last session wasn''t uploaded')
        $detail = (Tx 'O mundo que você jogou está salvo só neste PC. Envie agora, ou continue hosteando de onde parou.' 'The world you played is saved only on this PC. Upload it now, or keep hosting from where you stopped.')
        $primary = 'save'; $primaryText = (Tx 'Enviar mundo agora' 'Upload world now')
        $secondary = 'host'; $secondaryText = (Tx 'Continuar hosteando' 'Keep hosting')
    }
    elseif ($st.trava -and $st.trava.host -ne $st.eu) {
        $dot = 'green'; $title = (Tx "$($st.trava.host) está hosteando" "$($st.trava.host) is hosting")
        $detail = (Tx "Desde $($st.trava.desde). Entre no Minecraft pelo endereço abaixo." "Since $($st.trava.desde). Join in Minecraft using the address below.")
        $address = $st.trava.endereco
        if (-not $address) { $detail = (Tx "Desde $($st.trava.desde). Peça o endereço para $($st.trava.host)." "Since $($st.trava.desde). Ask $($st.trava.host) for the address.") }
        if ($st.trava.reserva) { $detail += (Tx " Se não conectar, tente: $($st.trava.reserva)" " If that doesn't connect, try: $($st.trava.reserva)") }
        if ($st.semSinal) {
            # o host manda um sinal a cada backup automatico; sem sinal, provavelmente caiu
            $dot = 'yellow'; $title = (Tx "$($st.trava.host) pode ter caído" "$($st.trava.host) may have dropped")
            $detail = (Tx "Sem sinal há $($st.semSinalMin) min (o normal é um a cada $($st.backupMin) min). " "No signal for $($st.semSinalMin) min (normally one every $($st.backupMin) min). ") +
                      (Tx 'Se o servidor não responde, você pode assumir: perde-se só o que foi jogado depois do último backup.' 'If the server isn''t responding, you can take over: only what was played after the latest backup is lost.')
        } elseif ($null -ne $st.semSinalMin) {
            $detail += (Tx " Último sinal há $($st.semSinalMin) min." " Last signal $($st.semSinalMin) min ago.")
        }
        $secondary = 'force'; $secondaryText = (Tx 'Assumir o servidor' 'Take over the server')
    }
    elseif ($st.trava) {
        $dot = 'yellow'; $title = (Tx 'O servidor está reservado no seu nome' 'The server is reserved in your name')
        $detail = (Tx 'Uma sessão sua em outro PC não foi encerrada. Você pode hostear daqui a partir do último mundo salvo.' 'A session of yours on another PC wasn''t closed. You can host from here, starting from the latest saved world.')
        $primary = 'host'; $primaryText = (Tx 'Hostear servidor' 'Host server')
    }
    else {
        $title = (Tx 'Ninguém está hosteando' 'Nobody is hosting')
        $detail = (Tx 'Clique em Hostear servidor para abrir o mundo para o grupo.' 'Click Host server to open the world for the group.')
        if ($st.versaoMinecraft) {
            $kindName = Get-TypeName $st.tipoServidor
            if ($st.tipoServidor -ne 'paper') { $kindName += ' (mods)' }
            $detail += (Tx "`nServidor: $kindName, Minecraft $($st.versaoMinecraft). Memória neste PC: $($st.memoria)." "`nServer: $kindName, Minecraft $($st.versaoMinecraft). Memory on this PC: $($st.memoria).")
        }
        $primary = 'host'; $primaryText = (Tx 'Hostear servidor' 'Host server')
    }

    # durante uma checagem de status os botoes ficam travados
    if ($busy -and $script:Kind -in $script:QuietKinds) { $primaryEnabled = $false }

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
    $script:MenuDiscord.Header = if ($st -and $st.discord) { (Tx 'Avisos no Discord: ligados...' 'Discord notifications: on...') } else { (Tx 'Ligar avisos no Discord...' 'Turn on Discord notifications...') }
    $script:MenuTunnel.Header = if ($st -and $st.tunel) { (Tx 'Conexão por túnel: ligada...' 'Tunnel connection: on...') } else { (Tx 'Conexão por túnel (sem Radmin)...' 'Tunnel connection (no Radmin)...') }
    $script:MenuDirect.Header = if ($st -and $st.direta) { (Tx 'Conexão direta: ligada...' 'Direct connection: on...') } else { (Tx 'Conexão direta (porta no roteador)...' 'Direct connection (router port)...') }
    $isModded = [bool]($st -and $st.tipoServidor -and $st.tipoServidor -ne 'paper')
    $script:MenuAddons.Header = if ($isModded) { (Tx 'Mods do servidor...' 'Server mods...') } else { (Tx 'Plugins do servidor...' 'Server plugins...') }
    $script:MenuClientMods.Visibility = if ($isModded) { 'Visible' } else { 'Collapsed' }
    if ($st -and $st.versaoNova) {
        $script:MenuUpdate.Header = (Tx "Atualizar o programa para a versão $($st.versaoNova)..." "Update the program to version $($st.versaoNova)...")
        $script:MenuUpdate.Visibility = 'Visible'
        $script:OptionsBtn.Content = (Tx 'Opções ▾  (atualização)' 'Options ▾  (update)')
    } else {
        $script:MenuUpdate.Visibility = 'Collapsed'
        $script:OptionsBtn.Content = (Tx 'Opções ▾' 'Options ▾')
    }
    $serverUp = $busy -and $script:Kind -eq 'host' -and $script:Phase -in 'running', 'ready' -and -not $script:Stopping
    $script:CommandBox.IsEnabled = $serverUp
    $script:SendBtn.IsEnabled = $serverUp
    $script:PlayersPanel.Visibility = if ($serverUp) { 'Visible' } else { 'Collapsed' }
}

# ---------------------------------------------------------------- jogadores

function Update-Players {
    $script:PlayersList.Items.Clear()
    foreach ($name in $script:Players) { [void]$script:PlayersList.Items.Add($name) }
    $script:PlayersTitle.Text = (Tx "Jogadores online ($($script:Players.Count))" "Players online ($($script:Players.Count))")
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
        [Windows.MessageBox]::Show($Window, (Tx 'Digite o nick do jogador, ou clique nele na lista de quem está online.' 'Type the player''s nickname, or click it in the list of who''s online.'),
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
            (Tx "Para rodar o servidor é preciso aceitar a licença (EULA) do Minecraft:`n" "To run the server you need to accept the Minecraft license (EULA):`n") +
            (Tx "https://aka.ms/MinecraftEULA`n`nVocê leu e aceita a EULA?" "https://aka.ms/MinecraftEULA`n`nHave you read and do you accept the EULA?")
        }
        'descartar-local' {
            (Tx "Existem alterações neste PC que não estão no GitHub (a lista está no quadro de mensagens).`n`n" "There are changes on this PC that aren't on GitHub (the list is in the message box).`n`n") +
            (Tx "Descartar essas alterações e usar a versão do GitHub?" "Discard these changes and use the version on GitHub?")
        }
        'descartar-superada' {
            (Tx "Sua última sessão não foi salva e outra pessoa já hosteou depois.`n`n" "Your last session wasn't saved and someone else has hosted since.`n`n") +
            (Tx "O progresso que ficou só neste PC precisa ser descartado para continuar. Descartar?" "The progress left only on this PC has to be discarded to continue. Discard it?")
        }
        'assumir' {
            (Tx "Assumir vai usar o último backup do mundo.`n" "Taking over uses the world's latest backup.`n") +
            (Tx "O que $arg jogou depois dele será perdido.`n`nAssumir mesmo assim?" "Whatever $arg played after it will be lost.`n`nTake over anyway?")
        }
        default { (Tx "Confirmar ($code)?" "Confirm ($code)?") }
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
            'PACK' {
                $script:Pack = ($parts[1..($parts.Count - 1)] -join '@@') | ConvertFrom-Json
            }
            'VERSIONS' {
                $script:Versions = ($parts[1..($parts.Count - 1)] -join '@@') | ConvertFrom-Json
            }
            'SAVES' {
                $script:Saves = ($parts[1..($parts.Count - 1)] -join '@@') | ConvertFrom-Json
            }
            'STATE' {
                $script:Phase = $parts[1]
                if ($parts[1] -eq 'running') { $script:Address = $parts[2]; $script:Reserve = [string]$parts[3] }
            }
            'ASK' {
                $yes = Ask-User $parts[1] $parts[2]
                Send-ToHost $(if ($yes) { 's' } else { 'n' })
            }
        }
        Update-Ui
        return
    }

    if ($script:Kind -in $script:QuietKinds) {
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
    } elseif ($kind -in $script:QuietKinds) {
        Update-Ui
        $after = $script:AfterSaves
        $script:AfterSaves = $null
        if ($code -ne 0) {
            $script:StatusLines | Where-Object { $_.Trim() } | ForEach-Object { Add-Log $_ }
            Add-Log (Tx 'Não consegui concluir a consulta. Veja a mensagem acima.' 'Couldn''t complete the check. See the message above.')
        } elseif ($after -eq 'restore' -and $script:Saves) {
            Show-RestoreDialog
        } elseif ($after -eq 'prune' -and $script:Saves) {
            Show-PruneDialog
        } elseif ($after -eq 'server' -and $script:Versions) {
            Show-ServerDialog
        } elseif ($after -eq 'copymods') {
            Copy-GroupMods
        } elseif ($after -eq 'pack' -and $script:Pack) {
            Show-PackDialog
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
        (Tx 'Isso só pode ser feito com o servidor fechado e sem nada pendente para enviar neste PC.' 'This can only be done with the server closed and nothing pending to upload on this PC.'),
        'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
    return $false
}

function Show-DiscordDialog {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $prompt = (Tx "Cole aqui o link do webhook do canal onde os avisos devem aparecer.`n`n" "Paste here the webhook link of the channel where the notifications should appear.`n`n") +
              (Tx "No Discord: Editar canal > Integrações > Webhooks > Novo webhook > Copiar URL do webhook.`n`n" "In Discord: Edit Channel > Integrations > Webhooks > New Webhook > Copy Webhook URL.`n`n") +
              (Tx 'Para desligar os avisos, deixe em branco.' 'To turn notifications off, leave it empty.')
    $url = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, (Tx 'Avisos no Discord' 'Discord notifications'), '').Trim()
    if (-not $url) {
        # em branco tambem e o que o botao Cancelar devolve: so desliga se confirmar
        if (-not ($script:Status -and $script:Status.discord)) { return }
        $answer = [Windows.MessageBox]::Show($Window, (Tx 'Desligar os avisos no Discord para o grupo todo?' 'Turn off Discord notifications for the whole group?'),
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $url = 'off'
    }
    if ($url -match '[\s"]') {
        [Windows.MessageBox]::Show($Window, (Tx 'Esse link tem espaços ou aspas. Copie de novo a URL do webhook.' 'That link has spaces or quotes. Copy the webhook URL again.'),
            'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    Start-Maintenance (Tx 'Configurando os avisos do Discord...' 'Setting up Discord notifications...') (Tx 'Testando o link e gravando a configuração para o grupo todo.' 'Testing the link and saving the settings for the whole group.') "-SetWebhook `"$url`""
}

function Get-TypeName($type) {
    switch ($type) {
        'fabric'   { return 'Fabric' }
        'neoforge' { return 'NeoForge' }
        'forge'    { return 'Forge' }
        default    { return 'Paper' }
    }
}

# Monta uma janela de dialogo a partir de XAML, ja com dono e icone.
function New-Dialog([string]$xamlText) {
    [xml]$doc = Convert-Xaml $xamlText
    $dialog = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $doc))
    $dialog.Owner = $Window
    $dialog.Icon = $Window.Icon
    return $dialog
}

# ---- plugins (Paper) ou mods (Fabric) do servidor

function Update-AddonsList {
    $list = $script:Addons.List
    $list.Items.Clear()
    foreach ($name in $script:Addons.Existing) {
        if ($script:Addons.Remove -contains $name) { continue }
        [void]$list.Items.Add($name)
    }
    foreach ($path in $script:Addons.Add) { [void]$list.Items.Add((Tx "$(Split-Path -Leaf $path)    (novo)" "$(Split-Path -Leaf $path)    (new)")) }
    $script:Addons.Empty.Visibility = if ($list.Items.Count -eq 0) { 'Visible' } else { 'Collapsed' }
}

function Show-AddonsDialog {
    $isFabric = [bool]($script:Status -and $script:Status.tipoServidor -and $script:Status.tipoServidor -ne 'paper')   # servidor com mods
    $loaderName = Get-TypeName $script:Status.tipoServidor
    $folderName = if ($isFabric) { 'mods' } else { 'plugins' }
    $word = if ($isFabric) { 'mods' } else { 'plugins' }
    $folder = Join-Path $Root "server\$folderName"
    $hint = if ($isFabric) {
        (Tx "Arquivos .jar de mods para $loaderName, na mesma versão do Minecraft do servidor. Quem joga precisa dos mesmos mods no próprio Minecraft (Opções > Mods para jogar neste PC)." ".jar mod files for $loaderName, for the same Minecraft version as the server. Players need the same mods in their own Minecraft (Options > Mods to play on this PC).")
    } else {
        (Tx 'Arquivos .jar de plugins para Paper/Spigot/Bukkit. Eles rodam só no servidor: quem joga não precisa instalar nada.' '.jar plugin files for Paper/Spigot/Bukkit. They run only on the server: players don''t need to install anything.')
    }
    $dialog = New-Dialog @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Width="600" Height="500" MinWidth="460" MinHeight="340"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <DockPanel Margin="18">
    <TextBlock Name="HintText" DockPanel.Dock="Top" TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,0,0,12"/>
    <DockPanel DockPanel.Dock="Bottom" Margin="0,14,0,0" LastChildFill="False">
      <Button Name="AddBtn" DockPanel.Dock="Left" Content="Adicionar arquivos..." Padding="16,9" Margin="0,0,10,0"/>
      <Button Name="RemoveBtn" DockPanel.Dock="Left" Content="Remover selecionado" Padding="16,9"/>
      <Button Name="SaveBtn" DockPanel.Dock="Right" Content="Salvar e enviar" Padding="18,9" IsDefault="True"/>
      <Button Name="CancelBtn" DockPanel.Dock="Right" Content="Cancelar" Padding="16,9" Margin="0,0,10,0" IsCancel="True"/>
    </DockPanel>
    <Grid>
      <ListBox Name="AddonList" Background="#0D1117" Foreground="#E6EDF3" BorderThickness="0" Padding="6"
               ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
      <TextBlock Name="EmptyText" Text="Nenhum arquivo ainda." Foreground="#6E7681" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Grid>
  </DockPanel>
</Window>
'@
    $dialog.Title = if ($isFabric) { (Tx 'Mods do servidor' 'Server mods') } else { (Tx 'Plugins do servidor' 'Server plugins') }
    $dialog.FindName('HintText').Text = $hint
    $existing = @()
    if (Test-Path $folder) { $existing = @(Get-ChildItem $folder -Filter '*.jar' -File | Sort-Object Name | ForEach-Object { $_.Name }) }
    $script:Addons = @{
        Existing = $existing
        Add      = New-Object System.Collections.Generic.List[string]
        Remove   = New-Object System.Collections.Generic.List[string]
        List     = $dialog.FindName('AddonList')
        Empty    = $dialog.FindName('EmptyText')
        Dialog   = $dialog
    }
    Update-AddonsList

    $dialog.FindName('AddBtn').Add_Click({
        $picker = New-Object Microsoft.Win32.OpenFileDialog
        $picker.Filter = (Tx 'Arquivos .jar|*.jar' 'JAR files|*.jar')
        $picker.Multiselect = $true
        if ($picker.ShowDialog($script:Addons.Dialog)) {
            foreach ($file in $picker.FileNames) {
                if ((Get-Item $file).Length -gt 95MB) {
                    [Windows.MessageBox]::Show($script:Addons.Dialog, (Tx "$(Split-Path -Leaf $file) tem mais de 95 MB. O GitHub não aceita arquivos desse tamanho." "$(Split-Path -Leaf $file) is larger than 95 MB. GitHub doesn't accept files that big."),
                        'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
                    continue
                }
                $name = Split-Path -Leaf $file
                # um arquivo com o mesmo nome substitui o anterior
                $old = @($script:Addons.Add | Where-Object { (Split-Path -Leaf $_) -eq $name })
                foreach ($entry in $old) { [void]$script:Addons.Add.Remove($entry) }
                $script:Addons.Add.Add($file)
            }
            Update-AddonsList
        }
    })
    $dialog.FindName('RemoveBtn').Add_Click({
        $selected = [string]$script:Addons.List.SelectedItem
        if (-not $selected) { return }
        if ($selected -match '^(.*)    \((?:novo|new)\)$') {
            $name = $Matches[1]
            $entry = $script:Addons.Add | Where-Object { (Split-Path -Leaf $_) -eq $name } | Select-Object -First 1
            if ($entry) { [void]$script:Addons.Add.Remove($entry) }
        } else {
            $script:Addons.Remove.Add($selected)
        }
        Update-AddonsList
    })
    $dialog.FindName('SaveBtn').Add_Click({ $script:Addons.Dialog.DialogResult = $true })
    if (-not $dialog.ShowDialog()) { return }
    if ($script:Addons.Add.Count -eq 0 -and $script:Addons.Remove.Count -eq 0) { return }

    # so agora os arquivos sao mexidos de verdade; em seguida o host.ps1 envia
    New-Item -ItemType Directory -Force $folder | Out-Null
    foreach ($name in $script:Addons.Remove) { Remove-Item (Join-Path $folder $name) -Force -ErrorAction SilentlyContinue }
    foreach ($path in $script:Addons.Add) { Copy-Item $path (Join-Path $folder (Split-Path -Leaf $path)) -Force }
    $message = if ($isFabric) { 'Mods do servidor atualizados' } else { 'Plugins do servidor atualizados' }
    Start-Maintenance (Tx "Enviando os $word..." "Uploading the $word...") (Tx 'Gravando a mudança para o grupo todo.' 'Saving the change for the whole group.') "-SaveChanges `"$message`""
}

# ---- importar modpack

function Show-PackDialog {
    $pack = $script:Pack
    if ($pack.formato -eq 'cliente-curseforge') {
        [Windows.MessageBox]::Show($Window,
            (Tx "Esse é o pacote do CurseForge para o jogo: ele só tem a lista dos mods, não os mods.`n`nNa página do modpack, na aba Files, baixe o arquivo marcado como Server Pack e importe esse." "That is the CurseForge pack for the game: it only has the list of mods, not the mods themselves.`n`nOn the modpack page, in the Files tab, download the file marked as Server Pack and import that one."),
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    if ($pack.formato -eq 'desconhecido') {
        [Windows.MessageBox]::Show($Window,
            (Tx 'Não achei mods dentro desse arquivo. Ele precisa ser um Server Pack (.zip com a pasta mods) ou um .mrpack do Modrinth.' 'Couldn''t find mods inside that file. It needs to be a Server Pack (.zip with a mods folder) or a Modrinth .mrpack.'),
            'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    if ($pack.tipo -eq 'quilt') {
        [Windows.MessageBox]::Show($Window, (Tx 'Esse modpack é para Quilt, que o programa ainda não suporta.' 'That modpack is for Quilt, which the program doesn''t support yet.'), 'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    $currentIsPaper = (-not $script:Status.tipoServidor) -or ($script:Status.tipoServidor -eq 'paper')
    $dialog = New-Dialog @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Importar modpack" Width="600" SizeToContent="Height" ResizeMode="NoResize"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <StackPanel Margin="22">
    <TextBlock Name="NameText" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock Name="SummaryText" TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,4,0,16"/>
    <TextBlock Text="Confira o que o programa deduziu do arquivo. Os valores certos estão na página do modpack."
               TextWrapping="Wrap" Foreground="#9DA7B3" FontSize="12.5" Margin="0,0,0,10"/>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="220"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Grid.Row="0" Text="Carregador de mods" VerticalAlignment="Center"/>
      <ComboBox Name="TypeBox" Grid.Row="0" Grid.Column="1" Padding="8,6" Margin="0,0,0,10"/>
      <TextBlock Grid.Row="1" Text="Versão do Minecraft" VerticalAlignment="Center"/>
      <TextBox Name="McBox" Grid.Row="1" Grid.Column="1" Background="#0D1117" Foreground="#E6EDF3" CaretBrush="#E6EDF3" BorderBrush="#30363D" Padding="8,6" Margin="0,0,0,10"/>
      <TextBlock Grid.Row="2" Text="Versão do carregador" VerticalAlignment="Center"/>
      <TextBox Name="LoaderBox" Grid.Row="2" Grid.Column="1" Background="#0D1117" Foreground="#E6EDF3" CaretBrush="#E6EDF3" BorderBrush="#30363D" Padding="8,6" Margin="0,0,0,4"
               ToolTip="Em branco usa a versão mais recente para esse Minecraft"/>
    </Grid>
    <CheckBox Name="WorldCheck" Content="Começar um mundo novo" Foreground="#E6EDF3" Margin="0,14,0,0"/>
    <TextBlock Name="WorldText" TextWrapping="Wrap" Foreground="#D29922" FontSize="12.5" Margin="0,6,0,18"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="CancelBtn" Content="Cancelar" Padding="16,9" Margin="0,0,10,0" IsCancel="True"/>
      <Button Name="SaveBtn" Content="Importar" Padding="22,9" IsDefault="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $dialog.FindName('NameText').Text = [string]$pack.nome
    $kind = if ($pack.formato -eq 'mrpack') { (Tx 'Pacote do Modrinth (.mrpack)' 'Modrinth pack (.mrpack)') } else { 'Server Pack (.zip)' }
    $dialog.FindName('SummaryText').Text = (Tx "$kind com $($pack.mods) mods. Os mods que estão hoje no servidor serão trocados pelos do modpack. Quem joga precisa instalar o mesmo modpack no próprio Minecraft (pelo aplicativo do CurseForge ou do Modrinth)." "$kind with $($pack.mods) mods. The mods currently on the server will be replaced by the modpack's. Players need to install the same modpack in their own Minecraft (through the CurseForge or Modrinth app).")
    $typeBox = $dialog.FindName('TypeBox')
    $types = 'fabric', 'neoforge', 'forge'
    foreach ($type in $types) { [void]$typeBox.Items.Add((Get-TypeName $type)) }
    $typeBox.SelectedIndex = [Math]::Max(0, [array]::IndexOf($types, [string]$pack.tipo))
    $mcBox = $dialog.FindName('McBox'); $mcBox.Text = [string]$pack.mc
    $loaderBox = $dialog.FindName('LoaderBox'); $loaderBox.Text = [string]$pack.loader
    $worldCheck = $dialog.FindName('WorldCheck')
    $worldText = $dialog.FindName('WorldText')
    if ($currentIsPaper) {
        $worldCheck.IsChecked = $true
        $worldCheck.IsEnabled = $false
        $worldText.Text = (Tx 'O servidor atual é Paper, que guarda o mundo de outro jeito: o modpack começa um mundo novo. O mundo atual continua guardado nos saves.' 'The current server is Paper, which stores the world differently: the modpack starts a new world. The current world is still kept in the saves.')
    } else {
        $worldCheck.IsChecked = $true
        $worldText.Text = (Tx 'Recomendado ao trocar de modpack: um mundo criado com outros mods costuma quebrar. Desmarque só se o modpack for uma atualização do que já está no servidor. O mundo atual continua guardado nos saves.' 'Recommended when changing modpacks: a world created with other mods usually breaks. Uncheck only if the modpack is an update of the one already on the server. The current world is still kept in the saves.')
    }
    $dialog.FindName('SaveBtn').Add_Click({ $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }

    $type = $types[$typeBox.SelectedIndex]
    $mc = $mcBox.Text.Trim()
    $loader = $loaderBox.Text.Trim()
    if ($mc -notmatch '^\d+(\.\d+){1,2}$') {
        [Windows.MessageBox]::Show($Window, (Tx 'Preencha a versão do Minecraft do modpack, por exemplo 1.20.1 ou 26.3.' 'Fill in the modpack''s Minecraft version, for example 1.20.1 or 26.3.'), 'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    if ($loader -and $loader -notmatch '^[\w.+-]+$') {
        [Windows.MessageBox]::Show($Window, (Tx 'A versão do carregador tem caracteres inválidos.' 'The loader version has invalid characters.'), 'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    $argument = "$($script:PackPath)|$type|$mc|$loader"
    if ($worldCheck.IsChecked) { $argument += '|mundo-novo' }
    Start-Maintenance (Tx 'Importando o modpack...' 'Importing the modpack...') (Tx "Copiando os arquivos de $($pack.nome) e enviando para o grupo. Pode levar alguns minutos." "Copying the files of $($pack.nome) and uploading them for the group. It may take a few minutes.") "-ImportPack `"$argument`""
}

# ---- tipo de servidor e versao do Minecraft

function Show-ServerDialog {
    $info = $script:Versions
    $dialog = New-Dialog @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Tipo de servidor e versão do Minecraft" Width="620" Height="620" MinWidth="480" MinHeight="480"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <DockPanel Margin="18">
    <StackPanel DockPanel.Dock="Top">
      <TextBlock Text="Tipo de servidor" FontWeight="SemiBold"/>
      <RadioButton Name="PaperRadio" GroupName="Kind" Foreground="#E6EDF3" Margin="0,8,0,0"
                   Content="Paper: aceita plugins. Quem joga usa o Minecraft normal, sem instalar nada."/>
      <RadioButton Name="FabricRadio" GroupName="Kind" Foreground="#E6EDF3" Margin="0,6,0,0"
                   Content="Fabric: aceita mods. Todos precisam do Fabric e dos mesmos mods no jogo."/>
      <RadioButton Name="NeoForgeRadio" GroupName="Kind" Foreground="#E6EDF3" Margin="0,6,0,0"
                   Content="NeoForge (experimental): aceita mods; o mais usado em modpacks recentes."/>
      <RadioButton Name="ForgeRadio" GroupName="Kind" Foreground="#E6EDF3" Margin="0,6,0,16"
                   Content="Forge (experimental): aceita mods; comum em modpacks de versões antigas."/>
      <TextBlock Text="Versão do Minecraft" FontWeight="SemiBold" Margin="0,0,0,6"/>
    </StackPanel>
    <StackPanel DockPanel.Dock="Bottom">
      <TextBlock TextWrapping="Wrap" Foreground="#D29922" FontSize="12.5" Margin="0,12,0,14"
                 Text="Todos do grupo precisam jogar na mesma versão. Voltar para uma versão mais antiga pode estragar partes do mundo. Trocar entre Paper e um servidor com mods começa um MUNDO NOVO, porque um não abre o mundo do outro; o mundo atual continua guardado nos saves."/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="CancelBtn" Content="Cancelar" Padding="16,9" Margin="0,0,10,0" IsCancel="True"/>
        <Button Name="SaveBtn" Content="Salvar" Padding="22,9" IsDefault="True"/>
      </StackPanel>
    </StackPanel>
    <ListBox Name="VersionList" Background="#0D1117" Foreground="#E6EDF3" BorderThickness="0" Padding="6" FontFamily="Consolas"/>
  </DockPanel>
</Window>
'@
    $paper = $dialog.FindName('PaperRadio')
    $fabric = $dialog.FindName('FabricRadio')
    $list = $dialog.FindName('VersionList')
    $neoforge = $dialog.FindName('NeoForgeRadio')
    $forge = $dialog.FindName('ForgeRadio')
    switch ($info.tipo) {
        'fabric'   { $fabric.IsChecked = $true }
        'neoforge' { $neoforge.IsChecked = $true }
        'forge'    { $forge.IsChecked = $true }
        default    { $paper.IsChecked = $true }
    }
    $versions = @($info.versoes)
    foreach ($version in $versions) {
        $label = "$($version.id)".PadRight(10) + "Java $($version.java)"
        if ($version.id -eq $info.atual) { $label += (Tx '    (atual)' '    (current)') }
        [void]$list.Items.Add($label)
    }
    for ($i = 0; $i -lt $versions.Count; $i++) { if ($versions[$i].id -eq $info.atual) { $list.SelectedIndex = $i } }
    $dialog.FindName('SaveBtn').Add_Click({ $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }
    if ($list.SelectedIndex -lt 0) { return }

    $type = 'paper'
    if ($fabric.IsChecked) { $type = 'fabric' } elseif ($neoforge.IsChecked) { $type = 'neoforge' } elseif ($forge.IsChecked) { $type = 'forge' }
    $chosen = [string]$versions[$list.SelectedIndex].id
    if ($type -eq $info.tipo -and $chosen -eq $info.atual) { return }
    $typeName = Get-TypeName $type
    $question = (Tx "Mudar o servidor do grupo para $typeName, Minecraft $chosen?`n`nTodo mundo vai precisar jogar nessa versão." "Change the group's server to $typeName, Minecraft $chosen?`n`nEveryone will need to play on this version.")
    $argument = "$type|$chosen"
    if (($type -eq 'paper') -ne ($info.tipo -eq 'paper')) {
        $question += (Tx "`n`nATENÇÃO: trocar entre Paper e um servidor com mods começa um MUNDO NOVO. O mundo atual sai do servidor, mas continua guardado nos saves: para tê-lo de volta, volte para o tipo anterior e use Restaurar um save anterior." "`n`nWARNING: switching between Paper and a modded server starts a NEW WORLD. The current world leaves the server but is still kept in the saves: to get it back, switch back to the previous type and use Restore a previous save.")
        $argument += '|mundo-novo'
    }
    $answer = [Windows.MessageBox]::Show($Window, $question, 'Minecraft Compartilhado', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    Start-Maintenance (Tx 'Configurando o servidor...' 'Setting up the server...') (Tx "Mudando para $typeName, Minecraft $chosen." "Switching to $typeName, Minecraft $chosen.") "-SetServer `"$argument`""
}

# ---- memoria do servidor neste PC (ajuste local, nao vai para o repositorio)

function Show-MemoryDialog {
    $st = $script:Status
    $totalGb = 0
    try { $totalGb = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { }
    $dialog = New-Dialog @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Ajustes deste PC" Width="540" SizeToContent="Height" ResizeMode="NoResize"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <StackPanel Margin="22">
    <TextBlock Text="Memória do servidor" FontWeight="SemiBold"/>
    <TextBlock Name="InfoText" TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,4,0,8"/>
    <ComboBox Name="MemoryBox" Padding="10,7" Margin="0,0,0,18"/>
    <TextBlock Text="Fechar sozinho quando esvaziar" FontWeight="SemiBold"/>
    <TextBlock TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,4,0,8"
               Text="Se ninguém estiver online por esse tempo, o servidor salva o mundo, fecha e libera a vez para outra pessoa hostear. Enquanto o servidor está aberto, o programa já impede o PC de suspender por inatividade."/>
    <ComboBox Name="CloseBox" Padding="10,7" Margin="0,0,0,18"/>
    <TextBlock Text="Idioma do programa" FontWeight="SemiBold"/>
    <ComboBox Name="LangBox" Padding="10,7" Margin="0,4,0,18"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="CancelBtn" Content="Cancelar" Padding="16,9" Margin="0,0,10,0" IsCancel="True"/>
      <Button Name="SaveBtn" Content="Salvar" Padding="22,9" IsDefault="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $ramText = if ($totalGb -gt 0) { (Tx "Este PC tem $totalGb GB de memória. " "This PC has $totalGb GB of memory. ") } else { '' }
    $dialog.FindName('InfoText').Text = $ramText + (Tx 'Quanto dela o servidor de Minecraft pode usar quando você hosteia. ' 'How much of it the Minecraft server can use when you host. ') +
        (Tx 'Deixe pelo menos uns 4 GB livres para o Windows e para o seu próprio jogo. Os ajustes desta janela valem só para este PC.' 'Leave at least about 4 GB free for Windows and for your own game. The settings in this window apply only to this PC.')
    $box = $dialog.FindName('MemoryBox')
    $groupDefault = [string]$st.memoriaGrupo
    $values = @('')   # '' = padrao do grupo
    [void]$box.Items.Add((Tx "Padrão do grupo ($groupDefault)" "Group default ($groupDefault)"))
    foreach ($gb in 2, 3, 4, 6, 8, 10, 12, 16) {
        if ($totalGb -gt 0 -and $gb -gt ($totalGb - 2)) { continue }
        $values += "${gb}G"
        [void]$box.Items.Add("$gb GB")
    }
    $localFile = Join-Path $Root '.runtime\local.json'
    $current = ''
    $currentClose = 0
    $currentLang = ''
    if (Test-Path $localFile) {
        try {
            $saved = Get-Content $localFile -Raw | ConvertFrom-Json
            $current = [string]$saved.memoria
            if ($saved.fecharVazioMinutos) { $currentClose = [int]$saved.fecharVazioMinutos }
            if ($saved.idioma) { $currentLang = [string]$saved.idioma }
        } catch { }
    }
    $box.SelectedIndex = [Math]::Max(0, [array]::IndexOf($values, $current))
    $closeBox = $dialog.FindName('CloseBox')
    $closeValues = 0, 10, 20, 30, 60, 120
    [void]$closeBox.Items.Add((Tx 'Nunca (eu mesmo fecho)' 'Never (I''ll close it myself)'))
    foreach ($minutes in $closeValues | Select-Object -Skip 1) { [void]$closeBox.Items.Add((Tx "Depois de $minutes minutos vazio" "After $minutes minutes empty")) }
    $closeBox.SelectedIndex = [Math]::Max(0, [array]::IndexOf($closeValues, $currentClose))
    $langBox = $dialog.FindName('LangBox')
    $langValues = '', 'pt', 'en'
    [void]$langBox.Items.Add((Tx 'Automático (idioma do Windows)' 'Automatic (Windows language)'))
    [void]$langBox.Items.Add('Português')
    [void]$langBox.Items.Add('English')
    $langBox.SelectedIndex = [Math]::Max(0, [array]::IndexOf($langValues, $currentLang))
    $dialog.FindName('SaveBtn').Add_Click({ $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }

    $settings = @{}
    if ($values[$box.SelectedIndex]) { $settings.memoria = $values[$box.SelectedIndex] }
    if ($closeValues[$closeBox.SelectedIndex] -gt 0) { $settings.fecharVazioMinutos = $closeValues[$closeBox.SelectedIndex] }
    if ($langValues[$langBox.SelectedIndex]) { $settings.idioma = $langValues[$langBox.SelectedIndex] }
    if ($settings.Count -gt 0) {
        New-Item -ItemType Directory -Force (Split-Path $localFile) | Out-Null
        [IO.File]::WriteAllText($localFile, ($settings | ConvertTo-Json) + "`n")
    } else {
        Remove-Item $localFile -Force -ErrorAction SilentlyContinue
    }
    Start-HostScript 'status' '-Status'   # mostra o valor novo
    if ($langValues[$langBox.SelectedIndex] -ne $currentLang) {
        [Windows.MessageBox]::Show($Window, (Tx 'Feche e abra o programa para trocar o idioma.' 'Close and reopen the program to change the language.'),
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
    }
}

# ---- mods no Minecraft de quem joga (so com servidor Fabric)

# Copia os mods do grupo para a pasta de mods do Minecraft deste PC. So mexe
# nos arquivos que ele mesmo colocou antes (lista guardada num arquivo ao lado).
# Devolve o que aconteceu, sem mostrar nada na tela.
function Sync-GroupMods($gameFolder) {
    $source = Join-Path $Root 'server\mods'
    $mods = @()
    if (Test-Path $source) { $mods = @(Get-ChildItem $source -Filter '*.jar' -File) }
    $result = @{ Status = 'ok'; Source = $source; Target = (Join-Path $gameFolder 'mods'); Copied = $mods.Count; Others = 0 }
    if ($mods.Count -eq 0) { $result.Status = 'sem-mods'; return $result }
    if (-not (Test-Path $gameFolder)) { $result.Status = 'sem-jogo'; return $result }

    $target = $result.Target
    New-Item -ItemType Directory -Force $target | Out-Null
    $manifest = Join-Path $target '.minecraft-compartilhado.json'
    $previous = @()
    if (Test-Path $manifest) { try { $previous = @((Get-Content $manifest -Raw | ConvertFrom-Json).arquivos) } catch { } }
    $names = @($mods | ForEach-Object { $_.Name })

    # tira os mods do grupo que sairam; os que a pessoa colocou por conta propria ficam
    foreach ($name in $previous) {
        if ($names -notcontains $name) { Remove-Item (Join-Path $target $name) -Force -ErrorAction SilentlyContinue }
    }
    foreach ($mod in $mods) { Copy-Item $mod.FullName (Join-Path $target $mod.Name) -Force }
    [IO.File]::WriteAllText($manifest, (@{ arquivos = $names } | ConvertTo-Json) + "`n")
    $result.Others = @(Get-ChildItem $target -Filter '*.jar' -File | Where-Object { $names -notcontains $_.Name }).Count
    return $result
}

function Copy-GroupMods {
    $result = Sync-GroupMods (Join-Path $env:APPDATA '.minecraft')
    if ($result.Status -eq 'sem-mods') {
        [Windows.MessageBox]::Show($Window, (Tx 'O grupo ainda não tem nenhum mod no servidor.' 'The group doesn''t have any mods on the server yet.'), 'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    if ($result.Status -eq 'sem-jogo') {
        [Windows.MessageBox]::Show($Window,
            (Tx "Não achei o Minecraft na pasta padrão (%APPDATA%\.minecraft).`n`nSe você usa outro launcher, copie os mods à mão: vou abrir a pasta onde eles estão." "Couldn't find Minecraft in the default folder (%APPDATA%\.minecraft).`n`nIf you use another launcher, copy the mods by hand: I'll open the folder where they are."),
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        Start-Process explorer.exe $result.Source
        return
    }
    $text = (Tx "$($result.Copied) mods do grupo copiados para:`n$($result.Target)" "$($result.Copied) group mods copied to:`n$($result.Target)")
    if ($result.Others -gt 0) {
        $text += (Tx "`n`nEssa pasta também tem $($result.Others) mods que não são do grupo. Não mexi neles, mas se o jogo não abrir ou não conectar, tire-os de lá." "`n`nThat folder also has $($result.Others) mods that aren't from the group. I didn't touch them, but if the game doesn't start or can't connect, take them out of there.")
    }
    [Windows.MessageBox]::Show($Window, $text, 'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
}

function Show-ClientModsDialog {
    $st = $script:Status
    $dialog = New-Dialog @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Mods para jogar neste PC" Width="600" SizeToContent="Height" ResizeMode="NoResize"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <StackPanel Margin="22">
    <TextBlock Name="IntroText" TextWrapping="Wrap" Margin="0,0,0,16"/>
    <TextBlock Name="LoaderTitle" FontWeight="SemiBold"/>
    <TextBlock Name="FabricText" TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,4,0,8"/>
    <Button Name="FabricBtn" HorizontalAlignment="Left" Padding="16,9" Margin="0,0,0,18"/>
    <TextBlock Text="2. Copie os mods do grupo" FontWeight="SemiBold"/>
    <TextBlock TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,4,0,8"
               Text="Copia os mods do servidor para a pasta de mods do seu Minecraft. Repita sempre que o grupo mudar os mods. Mods que você colocou por conta própria não são apagados."/>
    <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
      <Button Name="CopyBtn" Content="Copiar os mods do grupo" Padding="16,9" Margin="0,0,10,0"/>
      <Button Name="FolderBtn" Content="Abrir a pasta dos mods do grupo" Padding="16,9"/>
    </StackPanel>
    <Button Name="CloseBtn" Content="Fechar" HorizontalAlignment="Right" Padding="22,9" IsCancel="True"/>
  </StackPanel>
</Window>
'@
    $loaderName = Get-TypeName $st.tipoServidor
    $loaderVersion = if ($st.versaoLoader) { " $($st.versaoLoader)" } else { '' }
    $script:LoaderSite = switch ($st.tipoServidor) {
        'neoforge' { 'https://neoforged.net/' }
        'forge'    { 'https://files.minecraftforge.net/' }
        default    { 'https://fabricmc.net/use/installer/' }
    }
    $dialog.FindName('IntroText').Text = (Tx "O servidor do grupo usa mods ($loaderName$loaderVersion, Minecraft $($st.versaoMinecraft)). Para entrar, o seu Minecraft precisa do $loaderName e dos mesmos mods. Se o grupo usa um modpack do CurseForge ou do Modrinth, o jeito mais fácil é instalar o mesmo modpack pelo aplicativo deles e pular os passos abaixo." "The group's server uses mods ($loaderName$loaderVersion, Minecraft $($st.versaoMinecraft)). To join, your Minecraft needs $loaderName and the same mods. If the group uses a CurseForge or Modrinth modpack, the easiest way is to install the same modpack through their app and skip the steps below.")
    $dialog.FindName('LoaderTitle').Text = (Tx "1. Instale o $loaderName no seu Minecraft" "1. Install $loaderName in your Minecraft")
    $loaderPart = if ($loaderVersion) { ", $loaderName$loaderVersion" } else { '' }
    $dialog.FindName('FabricText').Text = (Tx "No site, baixe o instalador para Windows, abra-o e escolha a versão $($st.versaoMinecraft) do Minecraft (cliente)$loaderPart. Ele cria um perfil no launcher oficial; é com esse perfil que você joga." "On the website, download the Windows installer, open it and choose Minecraft version $($st.versaoMinecraft) (client)$loaderPart. It creates a profile in the official launcher; that is the profile you play with.")
    $dialog.FindName('FabricBtn').Content = (Tx "Abrir o site do $loaderName" "Open the $loaderName website")
    $choice = @{ Action = $null }
    $dialog.FindName('FabricBtn').Add_Click({ Start-Process $script:LoaderSite })
    $dialog.FindName('FolderBtn').Add_Click({
        $folder = Join-Path $Root 'server\mods'
        New-Item -ItemType Directory -Force $folder | Out-Null
        Start-Process explorer.exe $folder
    })
    $dialog.FindName('CopyBtn').Add_Click({ $choice.Action = 'copy'; $dialog.DialogResult = $true }.GetNewClosure())
    [void]$dialog.ShowDialog()
    if ($choice.Action -ne 'copy') { return }
    # antes de copiar, traz os mods mais recentes do GitHub para este PC
    $script:AfterSaves = 'copymods'
    Start-HostScript 'sync' '-SyncOnly'
}

# Liga, troca ou desliga o tunel do playit.gg para o grupo.
function Show-TunnelDialog {
    $isOn = [bool]($script:Status -and $script:Status.tunel)
    [xml]$dialogXaml = Convert-Xaml @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Conexão por túnel" Width="600" SizeToContent="Height" ResizeMode="NoResize"
        Background="#161B22" WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        FontFamily="Segoe UI" FontSize="14" Foreground="#E6EDF3">
  <StackPanel Margin="22">
    <TextBlock TextWrapping="Wrap" Foreground="#9DA7B3" Margin="0,0,0,16"
               Text="Com o túnel do playit.gg, quem hosteia abre um endereço público e os amigos entram por ele sem instalar o Radmin nem nada. Vale para o grupo todo."/>
    <TextBlock Text="Chave secreta do agente" FontWeight="SemiBold"/>
    <TextBlock TextWrapping="Wrap" Foreground="#9DA7B3" FontSize="12.5"
               Text="No site do playit.gg, ao criar um agente do tipo Docker: é o valor que aparece depois de SECRET_KEY=. Ela fica guardada no repositório privado do grupo."/>
    <TextBlock Name="KeepHint" TextWrapping="Wrap" Foreground="#3FB950" FontSize="12.5" Visibility="Collapsed"
               Text="Já existe uma chave gravada. Deixe em branco para mantê-la."/>
    <PasswordBox Name="KeyBox" Background="#0D1117" Foreground="#E6EDF3" BorderBrush="#30363D" Padding="10,8" Margin="0,5,0,16"/>
    <TextBlock Text="Endereço público do túnel" FontWeight="SemiBold"/>
    <TextBlock TextWrapping="Wrap" Foreground="#9DA7B3" FontSize="12.5"
               Text="O endereço que o playit mostra para o túnel de Minecraft Java, como nome.gl.joinmc.link. É o que os amigos digitam no jogo. Se ainda não criou o túnel, deixe em branco: salve a chave, hosteie uma vez para o playit reconhecer o agente, crie o túnel no site e volte aqui."/>
    <TextBox Name="AddressBox" Background="#0D1117" Foreground="#E6EDF3" CaretBrush="#E6EDF3" BorderBrush="#30363D" Padding="10,8" Margin="0,5,0,8"/>
    <TextBlock TextWrapping="Wrap" Foreground="#D29922" FontSize="12.5" Margin="0,0,0,18"
               Text="Com o túnel, o servidor fica alcançável pela internet. Mantenha ligada a opção &quot;Só entra quem está na whitelist&quot;."/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="OffBtn" Content="Desligar o túnel" Padding="16,9" Margin="0,0,10,0" Visibility="Collapsed"/>
      <Button Name="CancelBtn" Content="Cancelar" Padding="16,9" Margin="0,0,10,0" IsCancel="True"/>
      <Button Name="SaveBtn" Content="Salvar" Padding="22,9" IsDefault="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $dialog = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dialogXaml))
    $dialog.Owner = $Window
    $dialog.Icon = $Window.Icon
    $keyBox = $dialog.FindName('KeyBox')
    $addressBox = $dialog.FindName('AddressBox')
    $offBtn = $dialog.FindName('OffBtn')
    $choice = @{ Action = $null }
    if ($isOn) {
        $offBtn.Visibility = 'Visible'
        $dialog.FindName('KeepHint').Visibility = 'Visible'
        $addressBox.Text = [string]$script:Status.tunelEndereco
    }
    $dialog.FindName('SaveBtn').Add_Click({ $choice.Action = 'save'; $dialog.DialogResult = $true }.GetNewClosure())
    $offBtn.Add_Click({ $choice.Action = 'off'; $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }

    $key = ''
    $address = ''
    if ($choice.Action -eq 'save') {
        $key = $keyBox.Password.Trim()
        $address = $addressBox.Text.Trim() -replace '^\w+://', ''
        if (-not $key -and $isOn) {
            $key = 'manter'   # o host.ps1 mantem a chave ja gravada
        } elseif ($key -notmatch '^[0-9a-fA-F]{32,}$') {
            [Windows.MessageBox]::Show($Window, (Tx 'Cole a chave secreta do agente: uma sequência longa de números e letras de a até f.' 'Paste the agent secret key: a long sequence of numbers and the letters a to f.'),
                'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
            return
        }
        if ($address -and $address -notmatch '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:\d{1,5})?$') {
            [Windows.MessageBox]::Show($Window, (Tx 'O endereço do túnel deve ser como nome.gl.joinmc.link (com :porta no fim, se o playit mostrar uma).' 'The tunnel address should look like name.gl.joinmc.link (with :port at the end, if playit shows one).'),
                'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
            return
        }
    } else {
        $answer = [Windows.MessageBox]::Show($Window, (Tx 'Desligar o túnel? O grupo volta a se conectar pelo Radmin.' 'Turn off the tunnel? The group goes back to connecting through Radmin.'),
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
    }
    Start-Maintenance (Tx 'Configurando a conexão por túnel...' 'Setting up the tunnel connection...') (Tx 'Gravando a configuração para o grupo todo.' 'Saving the settings for the whole group.') '-SetTunnel'
    # a chave vai pela entrada do processo, nunca pela linha de comando
    Send-ToHost $key
    Send-ToHost $address
}

# Texto de um save na lista: "13/11/2026 18:27   Mundo salvo por Fulano"
function Format-Save($save) {
    $text = $save.texto -replace '\s*\(\d{4}-\d\d-\d\d \d\d:\d\d\)$', ''
    $text = $text -replace '^Backup automatico \((.+?), \d\d:\d\d\)$', 'Backup automático ($1)'
    if ($Lang -eq 'en') {
        $text = $text -replace '^Backup automático \((.+)\)$', 'Automatic backup ($1)'
        $text = $text -replace '^Mundo salvo por (.+)$', 'World saved by $1'
        $text = $text -replace '^Mundo restaurado para o save de (.+) \(por (.+)\)$', 'World restored to the save from $1 (by $2)'
        $text = $text -replace '^Histórico compactado: começa em (.+)$', 'History compacted: starts at $1'
    }
    return "$($save.quando)    $text"
}

function Show-RestoreDialog {
    $saves = @($script:Saves.saves)
    if ($saves.Count -eq 0) {
        [Windows.MessageBox]::Show($Window, (Tx 'Ainda não há nenhum save guardado.' 'There are no saves kept yet.'), 'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    [xml]$dialogXaml = Convert-Xaml @'
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
    $dialog.Icon = $Window.Icon
    $list = $dialog.FindName('SaveList')
    $ok = $dialog.FindName('OkBtn')
    foreach ($save in $saves) { [void]$list.Items.Add((Format-Save $save)) }
    if ($saves.Count -gt 0) { $list.Items[0] = (Tx "$($list.Items[0])    (mundo atual)" "$($list.Items[0])    (current world)") }
    $list.Add_SelectionChanged({ $ok.IsEnabled = ($list.SelectedIndex -gt 0) }.GetNewClosure())
    $ok.Add_Click({ $dialog.DialogResult = $true }.GetNewClosure())
    if (-not $dialog.ShowDialog()) { return }

    $chosen = $saves[$list.SelectedIndex]
    $answer = [Windows.MessageBox]::Show($Window,
        (Tx "Voltar o mundo para o save de $($chosen.quando)?`n`nTudo que foi jogado depois disso sai do mundo (mas continua guardado na lista de saves)." "Restore the world to the save from $($chosen.quando)?`n`nEverything played after that leaves the world (but is still kept in the list of saves)."),
        'Minecraft Compartilhado', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    Start-Maintenance (Tx 'Restaurando o mundo...' 'Restoring the world...') (Tx "Voltando para o save de $($chosen.quando) e enviando para o GitHub." "Going back to the save from $($chosen.quando) and uploading to GitHub.") "-Restore $($chosen.id)"
}

function Show-PruneDialog {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $total = [int]$script:Saves.total
    $prompt = (Tx "O histórico tem $total saves guardados (a pasta do histórico ocupa $($script:Saves.mb) MB neste PC).`n`n" "The history has $total saves kept (the history folder takes $($script:Saves.mb) MB on this PC).`n`n") +
              (Tx "Quantos dos saves mais recentes você quer manter?`n`n" "How many of the most recent saves do you want to keep?`n`n") +
              (Tx 'Os mais antigos são apagados de vez e não poderão mais ser restaurados. O mundo atual não muda.' 'The oldest ones are deleted for good and can no longer be restored. The current world doesn''t change.')
    $typed = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, (Tx 'Compactar o histórico de saves' 'Compact the save history'), '30').Trim()
    if (-not $typed) { return }
    $keep = 0
    if (-not [int]::TryParse($typed, [ref]$keep) -or $keep -lt 5) {
        [Windows.MessageBox]::Show($Window, (Tx 'Digite um número a partir de 5.' 'Type a number of 5 or more.'), 'Minecraft Compartilhado', 'OK', 'Warning') | Out-Null
        return
    }
    if ($total -le $keep) {
        [Windows.MessageBox]::Show($Window, (Tx "O histórico só tem $total saves. Não há nada para compactar ainda." "The history only has $total saves. There's nothing to compact yet."),
            'Minecraft Compartilhado', 'OK', 'Information') | Out-Null
        return
    }
    $answer = [Windows.MessageBox]::Show($Window,
        (Tx "Apagar de vez os $($total - $keep) saves mais antigos e manter os $keep mais recentes?`n`nIsso não pode ser desfeito." "Delete the $($total - $keep) oldest saves for good and keep the $keep most recent ones?`n`nThis can't be undone."),
        'Minecraft Compartilhado', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    Start-Maintenance (Tx 'Compactando o histórico...' 'Compacting the history...') (Tx 'Reescrevendo o histórico e enviando para o GitHub. Pode levar alguns minutos em mundos grandes.' 'Rewriting the history and uploading it to GitHub. It may take a few minutes for large worlds.') "-Prune $keep"
}

$OptionsBtn.Add_Click({
    $menu = $script:OptionsBtn.ContextMenu
    $menu.PlacementTarget = $script:OptionsBtn
    $menu.Placement = 'Bottom'
    $menu.IsOpen = $true
})
$MenuDiscord.Add_Click({ if (Test-CanMaintain) { Show-DiscordDialog } })
$MenuTunnel.Add_Click({ if (Test-CanMaintain) { Show-TunnelDialog } })
$MenuAddons.Add_Click({ if (Test-CanMaintain) { Show-AddonsDialog } })
$MenuPack.Add_Click({
    if (-not (Test-CanMaintain)) { return }
    $picker = New-Object Microsoft.Win32.OpenFileDialog
    $picker.Title = (Tx 'Escolha o modpack: Server Pack (.zip) ou .mrpack' 'Choose the modpack: Server Pack (.zip) or .mrpack')
    $picker.Filter = 'Modpacks (*.zip;*.mrpack)|*.zip;*.mrpack'
    if (-not $picker.ShowDialog($Window)) { return }
    if ($picker.FileName -match '["|]') { return }
    $script:PackPath = $picker.FileName
    $script:Pack = $null
    $script:AfterSaves = 'pack'
    Start-HostScript 'inspect' "-InspectPack `"$($script:PackPath)`""
})
$MenuDirect.Add_Click({
    if (-not (Test-CanMaintain)) { return }
    if ($script:Status.direta) {
        $answer = [Windows.MessageBox]::Show($Window, (Tx 'A conexão direta está ligada para o grupo. Desligar?' 'The direct connection is on for the group. Turn it off?'),
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -eq 'Yes') { Start-Maintenance (Tx 'Configurando a conexão direta...' 'Setting up the direct connection...') (Tx 'Gravando a configuração para o grupo todo.' 'Saving the settings for the whole group.') '-SetDirect off' }
        return
    }
    $text = (Tx "Com a conexão direta, quem hosteia pede ao próprio roteador para abrir a porta do servidor, e os amigos conectam direto, sem Radmin e com o menor ping possível.`n`n" "With the direct connection, whoever hosts asks their own router to open the server port, and friends connect directly, without Radmin and with the lowest possible ping.`n`n") +
            (Tx "Só funciona em parte das redes: o roteador precisa aceitar isso (UPnP) e a operadora não pode compartilhar o IP (CGNAT). Quando não dá, o programa avisa e segue pelo túnel ou pelo Radmin. Se o túnel estiver configurado, ele continua no ar como endereço reserva.`n`n" "It only works on some networks: the router has to allow it (UPnP) and the ISP can't share the IP (CGNAT). When it doesn't work, the program says so and continues through the tunnel or Radmin. If the tunnel is set up, it stays on as a backup address.`n`n") +
            (Tx "Atenção: o endereço divulgado passa a ser o IP público da casa de quem está hosteando, e o servidor fica alcançável pela internet. Mantenha a whitelist ligada.`n`n" "Note: the shared address becomes the public IP of the host's home, and the server is reachable from the internet. Keep the whitelist on.`n`n") +
            (Tx 'Ligar a conexão direta para o grupo?' 'Turn on the direct connection for the group?')
    $answer = [Windows.MessageBox]::Show($Window, $text, 'Minecraft Compartilhado', 'YesNo', 'Question')
    if ($answer -eq 'Yes') { Start-Maintenance (Tx 'Configurando a conexão direta...' 'Setting up the direct connection...') (Tx 'Gravando a configuração para o grupo todo.' 'Saving the settings for the whole group.') '-SetDirect on' }
})
$MenuServer.Add_Click({
    if (Test-CanMaintain) { $script:AfterSaves = 'server'; $script:Versions = $null; Start-HostScript 'versions' '-ListVersions' }
})
$MenuMemory.Add_Click({ if ($script:Status) { Show-MemoryDialog } })
$MenuClientMods.Add_Click({ if ($script:Status) { Show-ClientModsDialog } })
$MenuUpdate.Add_Click({
    if (-not (Test-CanMaintain)) { return }
    $answer = [Windows.MessageBox]::Show($Window,
        (Tx "Atualizar o programa do grupo para a versão $($script:Status.versaoNova)?`n`nA atualização vale para todos do grupo. Depois, feche e abra o programa de novo." "Update the group's program to version $($script:Status.versaoNova)?`n`nThe update applies to everyone in the group. Afterwards, close and reopen the program."),
        'Minecraft Compartilhado', 'YesNo', 'Question')
    if ($answer -eq 'Yes') {
        Start-Maintenance (Tx 'Atualizando o programa...' 'Updating the program...') (Tx 'Baixando a versão nova e gravando para o grupo todo.' 'Downloading the new version and saving it for the whole group.') '-UpdateProgram'
    }
})
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
    $script:CopyBtn.Content = (Tx 'Copiado!' 'Copied!')
})
$CopyBtn.Add_MouseLeave({ $script:CopyBtn.Content = (Tx 'Copiar endereço' 'Copy address') })

$Window.Add_Closing({
    if (-not $script:Proc -or $script:Kind -in $script:QuietKinds) { return }
    if ($script:CloseWhenDone) { $_.Cancel = $true; return }   # ja esta fechando, so falta salvar

    $_.Cancel = $true
    $serverUp = $script:Kind -eq 'host' -and $script:Phase -in 'running', 'ready'
    if ($serverUp -and -not $script:Stopping) {
        $answer = [Windows.MessageBox]::Show($Window,
            (Tx "O servidor está aberto.`n`nParar o servidor, salvar o mundo no GitHub e fechar?" "The server is open.`n`nStop the server, save the world to GitHub and close?"),
            'Minecraft Compartilhado', 'YesNo', 'Question')
        if ($answer -eq 'Yes') {
            $script:CloseWhenDone = $true
            Invoke-Action 'stop'
        }
    } else {
        [Windows.MessageBox]::Show($Window,
            (Tx 'Ainda estou sincronizando com o GitHub. Espere terminar para fechar.' 'I''m still syncing with GitHub. Wait for it to finish before closing.'),
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
        [Windows.MessageBox]::Show((Tx 'O Minecraft Compartilhado já está aberto.' 'Minecraft Compartilhado is already open.'), 'Minecraft Compartilhado') | Out-Null
        exit
    }
    $Window.ShowDialog() | Out-Null
    $mutex.ReleaseMutex()
}
