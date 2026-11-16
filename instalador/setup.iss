; Instalador do Minecraft Compartilhado (Inno Setup 6).
;
; Gerado automaticamente pelo GitHub Actions (.github/workflows/instalador.yml)
; a cada versao; o resultado fica na pagina de Releases do repositorio.
;
; O que ele instala: o programa de primeiro uso (launcher.ps1), o icone e os
; atalhos. Nao pede permissao de administrador: tudo fica na pasta do usuario.
; O mundo do grupo NAO vem aqui; ele e baixado depois, do repositorio do grupo.

#define AppName "Minecraft Compartilhado"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define PowerShell "{win}\System32\WindowsPowerShell\v1.0\powershell.exe"

[Setup]
AppId={{6B2E4F0A-3C1D-4E7B-9A52-7D0C8F1E2B43}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=yuriacs
AppPublisherURL=https://github.com/yuriacs/minecraft-compartilhado
AppSupportURL=https://github.com/yuriacs/minecraft-compartilhado
DefaultDirName={localappdata}\Programs\MinecraftCompartilhado
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
LicenseFile=..\LICENSE
SetupIconFile=app.ico
UninstallDisplayIcon={app}\app.ico
UninstallDisplayName={#AppName}
OutputDir=..\dist
OutputBaseFilename=MinecraftCompartilhado-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; escolhe sozinho o idioma do Windows; so pergunta se nao for nenhum dos dois
ShowLanguageDialog=auto

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "launcher.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{#PowerShell}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Comment: "{cm:AppComment}"
Name: "{autodesktop}\{#AppName}"; Filename: "{#PowerShell}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Comment: "{cm:AppComment}"; Tasks: desktopicon

[Run]
Filename: "{#PowerShell}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Messages]
en.FinishedLabel=[name] was installed. The first time you open it, it asks for your group's link and downloads the server.
ptbr.FinishedLabel=O [name] foi instalado. Na primeira vez que abrir, ele pede o link do seu grupo e baixa o servidor.

[CustomMessages]
en.AppComment=Host or join your group's Minecraft server
ptbr.AppComment=Hostear ou entrar no servidor de Minecraft do grupo
en.UninstallNote=The program was removed.%n%nThe folder with the group's world (by default C:\MinecraftCompartilhado) was not deleted. If you won't use it anymore, you can delete it by hand: the world is still kept on GitHub.
ptbr.UninstallNote=O programa foi removido.%n%nA pasta com o mundo do grupo (por padrão C:\MinecraftCompartilhado) não foi apagada. Se não for mais usar, pode apagá-la à mão: o mundo continua guardado no GitHub.

[Code]
// A desinstalacao remove so o programa. O mundo do grupo fica na pasta dele
// (por padrao C:\MinecraftCompartilhado) e no GitHub; avisamos para ninguem
// achar que apagou o mundo, nem que ele foi removido do PC.
// (SuppressibleMsgBox: nao aparece em desinstalacao silenciosa.)
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    SuppressibleMsgBox(CustomMessage('UninstallNote'), mbInformation, MB_OK, IDOK);
end;
