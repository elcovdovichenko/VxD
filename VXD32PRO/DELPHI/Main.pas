unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

const
     wm_VxD = wm_User+1;

type
  TForm1 = class(TForm)
    Memo: TMemo;
    LoadVxD: TButton;
    HookIRQ: TButton;
    TransmitINT: TButton;
    FreeVxD: TButton;
    AddrINT: TEdit;
    Label1: TLabel;
    NumberIRQ: TEdit;
    Label2: TLabel;
    TransmitPNN: TButton;
    procedure LoadVxDClick(Sender: TObject);
    procedure TransmitINTClick(Sender: TObject);
    procedure HookIRQClick(Sender: TObject);
    procedure FreeVxDClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TransmitPNNClick(Sender: TObject);
  private
    { Private declarations }
    procedure VxdProc (var Mess : TMessage) ; message wm_VxD ;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

const
   CVXD_APIFUNC_1 = 1;
   CVXD_APIFUNC_2 = 2;
   CVXD_APIFUNC_3 = 3;

type
   TBuf = String[79];

var
   hCVxD : THandle;
   cbBytesReturned, dwErrorCode : DWord;
   RetInfo : Array[0..9]Of DWord;
   PutInfo : Array[0..9]Of DWord;
   pReceive, pTransmit : ^TBuf;

const
   fVxDIsLoaded : Boolean = FALSE;
   hIRQ : DWORD = 0;

procedure TForm1.VxdProc (var Mess : TMessage) ;
var S0, S1 : String; I : Byte;
begin
//  ShowMessage('!!!!!!!!!!');

  S0:=pReceive^; pReceive^:=''; S1:='';
  for I:=1 to Length(S0) do S1:=S1+IntToHex(Byte(S0[I]),2);
  Memo.Lines.Add('WParam='+IntToHex(Mess.WParam,8)+' Receive symbols: '+S1);
end ;


procedure TForm1.LoadVxDClick(Sender: TObject);
begin

   if fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is already loaded');
        Exit;
        end;

   hCVxD:=CreateFile('\\.\CVXDSAMP.VXD', 0, 0, NIL,
                     CREATE_NEW, FILE_FLAG_DELETE_ON_CLOSE, 0);

   if hCVxD = INVALID_HANDLE_VALUE
   then begin
        dwErrorCode:=GetLastError;
        if dwErrorCode = ERROR_NOT_SUPPORTED
        then Memo.Lines.Add('Device does not support IOCTL')
        else Memo.Lines.Add('Unable to open Vxd,Error code: '+IntToStr(dwErrorCode));
        end
   else begin
        Memo.Lines.Add('VxD is ready');
        fVxDIsLoaded:=True; hIRQ:=0;
        end;

end;

procedure TForm1.TransmitINTClick(Sender: TObject);
begin

  if not fVxDIsLoaded
  then begin
       Memo.Lines.Add('VxD is not loaded');
       Exit;
       end;

   if hIRQ = 0 then
     begin
     Memo.Lines.Add('IRQ is not available');
     Exit;
     end;

  pTransmit^:=#8#2#0#19#5#1#28#4#22#10#6#19#1#16;

  if DeviceIOControl(hCVxD, CVXD_APIFUNC_2, NIL, 0,
                       @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       Memo.Lines.Add('Transmit symbols: '+IntToStr(RetInfo[0]));
       Memo.Lines.Add('State INT: '+IntToHEX(RetInfo[1],1));
       Memo.Lines.Add('Transmit time: '+IntToStr(RetInfo[2]));
       Memo.Lines.Add('Transmit updated time: '+IntToStr(RetInfo[3]));
       Memo.Lines.Add('System time: '+IntToStr(GetTickCount));
      end
  else Memo.Lines.Add('Device does not support the requested API');

  end;

procedure TForm1.HookIRQClick(Sender: TObject);
begin

  if not fVxDIsLoaded
  then begin
       Memo.Lines.Add('VxD is not loaded');
       Exit;
       end;

   if hIRQ <> 0 then
     begin
     Memo.Lines.Add('IRQ is already hooked!');
     Exit;
     end;

  PutInfo[0]:=3;
  PutInfo[1]:=$2F8;
  PutInfo[2]:=Handle;
  PutInfo[3]:=wm_VxD;


  if DeviceIOControl(hCVxD, CVXD_APIFUNC_1, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       hIRQ:=RetInfo[4];
       if hIRQ = 0 then
         begin
         Memo.Lines.Add('IRQ is not available');
         Exit;
         end;
       Memo.Lines.Add('Sysyem VxD Handle: '+IntToHex(RetInfo[0],8));
       Memo.Lines.Add('IRQ State: '+IntToHex(RetInfo[1],2));
       Memo.Lines.Add('IRQ Handle: '+IntToHex(RetInfo[2],8));
       Memo.Lines.Add('INT State: '+IntToHex(RetInfo[3],1));
       Memo.Lines.Add('IRQ Mask: '+IntToHex(RetInfo[4],1));
       pTransmit:=Pointer(RetInfo[5]);
       pReceive:=Pointer(RetInfo[6]);
       end
  else Memo.Lines.Add('Device does not support the requested API');

end;

procedure TForm1.FreeVxDClick(Sender: TObject);
begin

  if not fVxDIsLoaded
  then begin
       Memo.Lines.Add('VxD is not loaded');
       Exit;
       end;

  CloseHandle(hCVxD);
  Memo.Lines.Add('VxD is unloaded');
  fVxDIsLoaded:=False; hIRQ:=0;

end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if fVxDIsLoaded then CloseHandle(hCVxD);
end;

procedure TForm1.TransmitPNNClick(Sender: TObject);
begin

  if not fVxDIsLoaded
  then begin
       Memo.Lines.Add('VxD is not loaded');
       Exit;
       end;

   if hIRQ = 0 then
     begin
     Memo.Lines.Add('IRQ is not available');
     Exit;
     end;

  if DeviceIOControl(hCVxD, CVXD_APIFUNC_3, NIL, 0, NIL, 0, cbBytesReturned, NIL)
  then Memo.Lines.Add('Transmit PNN')
  else Memo.Lines.Add('Device does not support the requested API');

end;

end.
