program ExchAupp;

uses
  Windows,Messages,Forms,
  Main in 'Main.pas' {Form1},
  IOCTL in 'IOCTL.pas',
  Protocol in 'Protocol.pas';

{$R *.RES}


begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
