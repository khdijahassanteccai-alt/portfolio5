[Setup]
AppName=عيادة النور - Doctor
AppVersion=1.0
DefaultDirName={autopf}\DoctorClinic
DefaultGroupName=Doctor Clinic
OutputDir=C:\Users\HP\clinic_app\Output
OutputBaseFilename=DoctorSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "C:\Users\HP\clinic_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\عيادة النور"; Filename: "{app}\clinic_app.exe"
Name: "{commondesktop}\عيادة النور"; Filename: "{app}\clinic_app.exe"

[Run]
Filename: "{app}\clinic_app.exe"; Description: "تشغيل التطبيق"; Flags: nowait postinstall skipifsilent