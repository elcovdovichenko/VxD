program Consol;

{%File '..\MTGA0208.VxD\Mtga0208.c'}

uses
  Forms,
  Main in 'Main.pas' {fmPlaierTGAPI},
  IOCTL in 'Ioctl.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TfmPlaierTGAPI, fmPlaierTGAPI);
  Application.Run;
end.
