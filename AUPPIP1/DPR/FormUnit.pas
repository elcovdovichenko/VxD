unit FormUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, IOCTL,
  StdCtrls;

type
  TfmTest = class(TForm)
    bnLoadVxD: TButton;
    Memo: TMemo;
    bnCloseVxD: TButton;
    bnLine: TButton;
    edNumber: TEdit;
    procedure bnLoadVxDClick(Sender: TObject);
    procedure bnCloseVxDClick(Sender: TObject);
    procedure bnLineClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  protected
    { Protected declarations }
    procedure WndProc (var Mess : TMessage) ; override ;
  end;

var
  fmTest: TfmTest;

implementation

{$R *.DFM}

procedure TfmTest.bnLoadVxDClick(Sender: TObject);
var dwErrorCode : DWord;
begin

   if fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is already loaded');
        Exit;
        end;

   dwErrorCode:=AUPPIP1_LoadVxD;
   if dwErrorCode = 0
   then begin
        Memo.Lines.Add('VxD is ready');
        hWindow:=Handle;
        if AUPPIP1_HookController(11,$360)
        then begin
             if hIRQ = 0 then
               begin
               Memo.Lines.Add('IRQ is not available');
               Exit;
               end;
             Memo.Lines.Add('IRQ Handle: '+IntToHex(hIRQ,8));
             Memo.Lines.Add('IRQ State: '+IntToHex(sIRQ,2));
             end
        else Memo.Lines.Add('Device does not support the requested API');
        end
   else if dwErrorCode = ERROR_NOT_SUPPORTED
        then Memo.Lines.Add('Device does not support IOCTL')
        else Memo.Lines.Add('Unable to open Vxd,Error code: '+IntToStr(dwErrorCode));

end;

procedure TfmTest.bnCloseVxDClick(Sender: TObject);
begin

   if not fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is not loaded');
        Exit;
        end;

   if AUPPIP1_CloseVxD
   then begin
        edNumber.Text:='';
        bnLine.Caption:='Line On';
        Memo.Lines.Add('VxD is unloaded');
        end;

end;

procedure TfmTest.bnLineClick(Sender: TObject);
begin

   if not fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is not loaded');
        Exit;
        end;

   if AUPPIP1_Control = 0
   then bnLine.Caption:='Line On'
   else bnLine.Caption:='Line Off'

end;

procedure TfmTest.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   if fVxDIsLoaded then AUPPIP1_CloseVxD;
end;

procedure TfmTest.WndProc (var Mess : TMessage) ;
var key : byte;
begin
case Mess.Msg of
  wm_VxD: begin
          key:=Byte(Mess.wParam) and $1F;
          case key of
            0 : begin
                edNumber.Text:='';
                Memo.Lines.Add('Поклал трубку');
                end;
            1..9 : edNumber.Text:=edNumber.Text + Chr(key+$30);
            10 : edNumber.Text:=edNumber.Text + '0';
            11 : edNumber.Text:=edNumber.Text + '*';
            12 : edNumber.Text:=edNumber.Text + '#';
            15 : Memo.Lines.Add('Поднял трубку');
            else Memo.Lines.Add('Data is '+IntToHex(key,2));
            end;
          end;
  else
    inherited WndProc(Mess);
  end;
end ;

end.
