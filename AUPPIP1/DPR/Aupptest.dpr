program Aupptest;

uses
  Forms,
  FormUnit in 'FormUnit.pas' {fmTest};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TfmTest, fmTest);
  Application.Run;
end.
