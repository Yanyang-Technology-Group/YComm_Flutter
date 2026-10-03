; YComm Windows installer script (Inno Setup 6).
;
; Invoked by .github/workflows/release.yml via ISCC.
;
; IMPORTANT: this file is intentionally pure ASCII. Inno Setup reads a script
; without a UTF-8 BOM using the system ANSI code page, so non-ASCII text placed
; here would be compiled as mojibake. All localized strings (app name, publisher)
; are injected from the command line with /D instead, where they arrive as UTF-16.
;
; Example:
;   ISCC.exe /DAppVersion=2026.09.19.12 ^
;            /DSourceDir=build\windows\x64\runner\Release ^
;            /DOutputDir=dist ^
;            /DAppName=<localized name> /DAppPublisher=<localized publisher> ^
;            tool\windows_installer.iss

#ifndef AppName
  #define AppName "YComm"
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppPublisher
  #define AppPublisher "Yanyang Technology Group"
#endif
#ifndef AppUrl
  #define AppUrl "https://community.yanyn.cn"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#ifndef OutputBaseName
  #define OutputBaseName "ycomm-windows-setup"
#endif
; Icon shown on the installer .exe itself and in Add/Remove Programs.
; Without this Inno Setup uses its own default icon.
#ifndef IconFile
  #define IconFile "..\windows\runner\resources\app_icon.ico"
#endif
; 安装/升级时窗口标题栏上的文字。Inno 的窗口标题是 [Messages] 里的 SetupWindowTitle，
; 不是 [Setup] 指令；文案仍然按文件头约定由 /D 注入（命令行参数是 UTF-16，不会乱码）。
#ifndef SetupTitle
  #define SetupTitle AppName + " Setup"
#endif

[Setup]
; AppId must never change, otherwise upgrades register as a different product
; and leave duplicate uninstall entries behind.
AppId={{6BD8BBC7-6DA8-4FA6-9813-D8676DBC47EC}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
AppUpdatesURL={#AppUrl}
AppCopyright=Copyright (C) 2026 {#AppPublisher}
; Version info of the installer itself - this is what Explorer's Properties
; dialog shows, and it is where the publisher is declared.
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\YComm
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install, so no administrator rights and no UAC prompt at all.
; Switch the two lines below to PrivilegesRequired=admin for a machine-wide
; install into Program Files (that will show the UAC publisher dialog).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseName}
SetupIconFile={#IconFile}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\ycomm_client.exe
AllowNoIcons=yes

[Messages]
; 升级窗口标题栏文字（默认是 "<AppName> Setup"）。静默升级时这就是用户看到的那扇窗。
SetupWindowTitle={#SetupTitle}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\ycomm_client.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\ycomm_client.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ycomm_client.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall
