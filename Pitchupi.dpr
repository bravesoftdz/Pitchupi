program Pitchupi;

uses
  Forms,
  mainForm in 'mainForm.pas' {Form2},
  PiUtils in 'PiUtils.pas',
  FileTransfer in 'FileTransfer.pas',
  PiCrypt in 'PiCrypt.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Pitchupi';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
