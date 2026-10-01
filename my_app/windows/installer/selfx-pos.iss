; Build with scripts/build-windows-installer.ps1. Keep AppId stable across releases.
#ifndef AppVersion
  #error AppVersion must be supplied by the build script
#endif
#ifndef AppBuild
  #error AppBuild must be supplied by the build script
#endif
#define AppName "SELFX POS"
#define AppExeName "selfx_pos.exe"
#define ReleaseDir SourcePath + "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B730C285-709F-45DB-BA76-7A362FAFEAC7}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
VersionInfoVersion={#AppVersion}.{#AppBuild}
AppPublisher=SELFX
AppPublisherURL=https://app.selfx.in
DefaultDirName={localappdata}\Programs\SELFX POS
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\installer
OutputBaseFilename=SELFX-POS-{#AppVersion}+{#AppBuild}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; Preserve settings from the former product name without overwriting new data.
Source: "{userappdata}\com.example\my_app\*"; DestDir: "{userappdata}\com.example\SELFX POS"; Flags: external skipifsourcedoesntexist onlyifdoesntexist recursesubdirs createallsubdirs uninsneveruninstall; Check: MigrateRoamingData
Source: "{localappdata}\com.example\my_app\*"; DestDir: "{localappdata}\com.example\SELFX POS"; Flags: external skipifsourcedoesntexist onlyifdoesntexist recursesubdirs createallsubdirs uninsneveruninstall; Check: MigrateLocalData
Source: "{#ReleaseDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Excludes: "{#AppExeName},*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
var
  ShouldMigrateRoaming: Boolean;
  ShouldMigrateLocal: Boolean;

function MigrateRoamingData(): Boolean;
begin
  Result := ShouldMigrateRoaming;
end;

function MigrateLocalData(): Boolean;
begin
  Result := ShouldMigrateLocal;
end;

function InitializeSetup(): Boolean;
begin
  { Decide once, before copying creates directories. Do not resurrect old files
    on later upgrades after users have cleared their settings. }
  ShouldMigrateRoaming := not DirExists(ExpandConstant('{userappdata}\com.example\SELFX POS'));
  ShouldMigrateLocal := not DirExists(ExpandConstant('{localappdata}\com.example\SELFX POS'));
  Result := True;
end;
