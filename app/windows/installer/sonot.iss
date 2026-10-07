; Inno Setup script for the Windows installer (Sonot-Setup.exe).
; Built by .github/workflows/app.yml after `flutter build windows`.
; Paths are relative to this file (app/windows/installer).

#define AppName "Sonot"
#define AppVersion "0.1.0"

[Setup]
AppId={{6F0B3E4A-5C1D-4E2B-9A7F-50A0750E1C0D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=ThatMaxwell
AppPublisherURL=https://github.com/ThatMaxwell/Sonot
DefaultDirName={localappdata}\Programs\Sonot
DefaultGroupName=Sonot
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=Sonot-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Sonot.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Sonot"; Filename: "{app}\Sonot.exe"
Name: "{autodesktop}\Sonot"; Filename: "{app}\Sonot.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\Sonot.exe"; Description: "Open Sonot"; Flags: nowait postinstall skipifsilent
