; Skrip Inno Setup untuk pemasang Windows

[Setup]
AppName=Waktu Solat
AppVersion=1.1.0
AppPublisher=Keluarga
DefaultDirName={autopf}\Waktu Solat
DefaultGroupName=Waktu Solat
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=WaktuSolat-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\waktu_solat.exe

[Tasks]
Name: "desktopicon"; Description: "Buat ikon di Desktop"; GroupDescription: "Ikon tambahan:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Waktu Solat"; Filename: "{app}\waktu_solat.exe"
Name: "{group}\Nyahpasang Waktu Solat"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Waktu Solat"; Filename: "{app}\waktu_solat.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\waktu_solat.exe"; Description: "Buka Waktu Solat sekarang"; Flags: nowait postinstall skipifsilent
