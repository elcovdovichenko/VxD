unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, IOCTL;

type
  TfmPlaierTGAPI = class(TForm)
    Memo: TMemo;
    bnLoadVxD: TButton;
    bnInitAdapter: TButton;
    bnControlLine: TButton;
    bnFreeVxD: TButton;
    editAddrInt: TEdit;
    Label1: TLabel;
    editNumberIRQ: TEdit;
    Label2: TLabel;
    bnControlPulse: TButton;
    editPolarity: TEdit;
    editChannel: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    editInterval: TEdit;
    Label5: TLabel;
    bnInputPulse: TButton;
    bnInputLine: TButton;
    bnOutSymbol: TButton;
    bnInitChannel: TButton;
    bnInputOn: TButton;
    bnInputOff: TButton;
    lTrap: TLabel;
    bnOutBufer: TButton;
    lPolarity: TLabel;
    lInterval: TLabel;
    bnGetStateLine: TButton;
    Label8: TLabel;
    editMode: TEdit;
    bnCall: TButton;
    bnCloseCHannel: TButton;
    bnAlarm: TButton;
    bnSirenOn: TButton;
    bnSirenOff: TButton;
    Label6: TLabel;
    editVxdName: TEdit;
    function IsAccess : Boolean;
    procedure bnLoadVxDClick(Sender: TObject);
    procedure bnControlLineClick(Sender: TObject);
    procedure bnInitAdapterClick(Sender: TObject);
    procedure bnFreeVxDClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure bnControlPulseClick(Sender: TObject);
    procedure bnInputPulseClick(Sender: TObject);
    procedure bnOutSymbolClick(Sender: TObject);
    procedure bnInitChannelClick(Sender: TObject);
    procedure bnInputOnClick(Sender: TObject);
    procedure bnInputOffClick(Sender: TObject);
    procedure bnInputLineClick(Sender: TObject);
    procedure bnOutBuferClick(Sender: TObject);
    procedure bnGetStateLineClick(Sender: TObject);
    procedure bnCallClick(Sender: TObject);
    procedure bnCloseCHannelClick(Sender: TObject);
    procedure bnAlarmClick(Sender: TObject);
    procedure bnSirenOnClick(Sender: TObject);
    procedure bnSirenOffClick(Sender: TObject);
    procedure editVxdNameKeyPress(Sender: TObject; var Key: Char);
    procedure editNumberIRQClick(Sender: TObject);
    procedure editChannelClick(Sender: TObject);
    procedure editPolarityClick(Sender: TObject);
    procedure editModeClick(Sender: TObject);
    procedure MemoChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  protected
    { Protected declarations }
    procedure WndProc (var Mess : TMessage) ; override ;
  end;

var
  fmPlaierTGAPI: TfmPlaierTGAPI;

implementation

{$R *.DFM}

const
  wm_VxD = wm_User;
  MES_OUTPUT_DATA = wm_VxD+1;
  MES_OUTPUT_SYMBOL = wm_VxD+2;
  MES_INPUT_SYMBOL = wm_VxD+3;
  MES_LINE_CHANGE = wm_VxD+4;
  MES_LINE_IN = wm_VxD+5;
  MES_PULSE_IN = wm_VxD+6;
  MES_PULSE_OUT = wm_VxD+7;
  MES_ALARM_STATE = wm_VxD+8;
  MES_TEST = wm_VxD+9;

const
  polarity: array[0..7] of Boolean
    = (True,True,True,True,True,True,True,True);

var
  dwErrorCode : DWord;

function TfmPlaierTGAPI.IsAccess : Boolean;
begin

  Result:=False;

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

  Result:=True;

end;

procedure TfmPlaierTGAPI.WndProc (var Mess : TMessage) ;
begin
case Mess.Msg of
  MES_OUTPUT_DATA:
    Memo.Lines.Add('Data was output on point'+IntToStr(Mess.wParam));
  MES_OUTPUT_SYMBOL:
    Memo.Lines.Add('Symbol was output on point'+IntToStr(Mess.wParam)+'='+IntToStr(Mess.lParam));
  MES_INPUT_SYMBOL:
    Memo.Lines.Add('Symbol was input on point'+IntToStr(Mess.wParam)+'='+IntToHex(Mess.lParam,2));
  MES_LINE_CHANGE:
    Memo.Lines.Add('Line was changed on point'+IntToStr(Mess.wParam)+'='+IntToStr(Mess.lParam)+'ms');
  MES_LINE_IN:
    Memo.Lines.Add('Line on point'+IntToStr(Mess.wParam)+'='+IntToStr(Mess.lParam)+'ms');
  MES_PULSE_IN:
    Memo.Lines.Add('Pulse on point'+IntToStr(Mess.wParam)+'='+IntToStr(Mess.lParam)+'ms');
  MES_PULSE_OUT:
    Memo.Lines.Add('Pulse was output on point'+IntToStr(Mess.wParam));
  MES_ALARM_STATE: Memo.Lines.Add('MES_ALARM_STATE');
  MES_TEST:
    Memo.Lines.Add('Test Symbol on point'+IntToStr(Mess.wParam)+'='+IntToHex(Mess.lParam,2));
  else
    inherited WndProc(Mess);
  end;
end ;


procedure TfmPlaierTGAPI.bnLoadVxDClick(Sender: TObject);
begin

   if fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is already loaded');
        Exit;
        end;

   dwErrorCode:=LoadVxD(editVxdName.Text);
   if dwErrorCode = 0
   then Memo.Lines.Add('VxD is ready')
   else if dwErrorCode = ERROR_NOT_SUPPORTED
        then Memo.Lines.Add('Device does not support IOCTL')
        else Memo.Lines.Add('Unable to open Vxd,Error code: '+IntToStr(dwErrorCode));

end;

procedure TfmPlaierTGAPI.bnControlLineClick(Sender: TObject);
var
  channel : Integer;
  exitfunc : Integer;
begin

  if not IsAccess then Exit;

  channel:=StrToInt(editChannel.Text);
  polarity[channel]:=Boolean(StrToInt(editPolarity.Text));
  exitfunc:=DIOCFunc9(channel,polarity[channel]);
  if exitfunc <> 0
  then Memo.Lines.Add('DIOCFunc9: '+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnInitAdapterClick(Sender: TObject);
const
  addrMTGA02 : Array[0..1]Of DWord = ($3E8,$2E8);
type
  TAr = Array[0..127] Of Boolean;
var
  numIRQ, I : Byte;
  baseAddr : DWord;
begin

  if not fVxDIsLoaded
  then begin
       Memo.Lines.Add('VxD is not loaded');
       Exit;
       end;

  numIRQ:=StrToInt(editNumberIRQ.Text);
  if editVxdName.Text = 'MTGA02.VXD'
  then baseAddr:=DWord(Addr(addrMTGA02))
  else baseAddr:=StrToHexAddr(editAddrInt.Text);
  if DIOCFunc1(baseAddr,numIRQ,Handle,wm_VxD) = 0
  then begin
       if hIRQ = 0 then
         begin
         Memo.Lines.Add('IRQ is not available');
         Exit;
         end;
       Memo.Lines.Add('IRQ Handle: '+IntToHex(hIRQ,8));
       Memo.Lines.Add('IRQ State: '+IntToHex(sIRQ,2));
       Memo.Lines.Add('INT Mask: '+IntToHex(mINT,2)+'->'+IntToHex(dINT,2));
       for I:=0 To POINTS-1
       do if TAr(pState^)[I]
          then Memo.Lines.Add('Point'+IntToStr(I)+' is ready')
          else Memo.Lines.Add('Point'+IntToStr(I)+' is absent');
       end
  else Memo.Lines.Add('Device does not support the requested API');

end;

procedure TfmPlaierTGAPI.bnFreeVxDClick(Sender: TObject);
begin

   if not fVxDIsLoaded
   then begin
        Memo.Lines.Add('VxD is not loaded');
        Exit;
        end;

   if CloseVxD
   then Memo.Lines.Add('VxD is unloaded');

end;

procedure TfmPlaierTGAPI.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if fVxDIsLoaded
  then CloseVxD;
end;

procedure TfmPlaierTGAPI.bnControlPulseClick(Sender: TObject);
var
  channel : Integer;
  interval : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   interval:=StrToInt(editInterval.Text);
   exitfunc:=DIOCFunc10(channel,not polarity[channel],interval);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc10: '+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnInputPulseClick(Sender: TObject);
var
  channel : Integer;
  interval : Integer;
  polarity : Boolean;
  trap : Word;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   polarity:=Boolean(StrToInt(editPolarity.Text));
   interval:=StrToInt(editInterval.Text);
   if interval > 0
   then begin
        exitfunc:=DIOCFunc12(channel,polarity,0,interval+100,trap);
        if exitfunc = 0
        then lTrap.Caption:=IntToHex(trap,4)
        else Memo.Lines.Add('DIOCFunc12: '+IntToStr(exitfunc));
        end
   else begin
        trap:=2;
        exitfunc:=DIOCFunc13(channel,trap);
        if exitfunc = 0
        then lTrap.Caption:=IntToHex(trap,4)
        else Memo.Lines.Add('DIOCFunc13: '+IntToStr(exitfunc));
        end;

end;

procedure TfmPlaierTGAPI.bnOutSymbolClick(Sender: TObject);
var
  channel : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc7(channel,15);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc7: '+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnInitChannelClick(Sender: TObject);
var
  channel : Integer;
  state : Byte;
  exitfunc : Integer;
  now : DWord;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc2(channel,2,5,2,state,now);
   if exitfunc = 0
   then begin
        Memo.Lines.Add('INT State of point'+IntToStr(channel)+'='+IntToHex(state,2));
        Memo.Lines.Add('Time init of point'+IntToStr(channel)+'='+IntToStr(now));
        Memo.Lines.Add('GetTickCount of point'+IntToStr(channel)+'='+IntToStr(GetTickCount));
        end
   else Memo.Lines.Add('DIOCFunc2 of point'+IntToStr(channel)+'='+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnInputOnClick(Sender: TObject);
var
  channel : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc3(channel);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc3: '+IntToStr(exitfunc));

end;


procedure TfmPlaierTGAPI.bnInputOffClick(Sender: TObject);
var
  channel : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc4(channel);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc4: '+IntToStr(exitfunc));

end;


procedure TfmPlaierTGAPI.bnInputLineClick(Sender: TObject);
var
  channel : Integer;
  interval : Integer;
  polarity : Boolean;
  trap : Word;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   polarity:=Boolean(StrToInt(editPolarity.Text));
   interval:=StrToInt(editInterval.Text);
   if interval > 0
   then begin
        exitfunc:=DIOCFunc11(channel,polarity,interval,trap);
        if exitfunc = 0
        then lTrap.Caption:=IntToHex(trap,4)
        else Memo.Lines.Add('DIOCFunc11: '+IntToStr(exitfunc));
        end
   else begin
        trap:=1;
        exitfunc:=DIOCFunc13(channel,trap);
        if exitfunc = 0
        then lTrap.Caption:=IntToHex(trap,4)
        else Memo.Lines.Add('DIOCFunc13: '+IntToStr(exitfunc));
        end;

end;

procedure TfmPlaierTGAPI.bnOutBuferClick(Sender: TObject);
const Box = 1000;
type TBuf = array[1..Box]Of Byte;
var
  channel : Integer;
  pBuf : ^TBuf;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc5(channel,Box,Pointer(pBuf));
   if exitfunc = 0
   then begin
        FillChar(pBuf^,Box,$1A);
        exitfunc:=DIOCFunc6(channel,Box);
        if exitfunc <> 0
        then Memo.Lines.Add('DIOCFunc6: '+IntToStr(exitfunc));
        end
   else if exitfunc = 7
        then begin
             exitfunc:=DIOCFunc8(channel);
             if exitfunc = 0
             then Memo.Lines.Add('Output was stopped!')
             else Memo.Lines.Add('DIOCFunc8: '+IntToStr(exitfunc));
             end
         else Memo.Lines.Add('DIOCFunc5: '+IntToStr(exitfunc));


end;

procedure TfmPlaierTGAPI.bnGetStateLineClick(Sender: TObject);
var
  channel : Integer;
  state : Boolean;
  interval : integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc14(channel,state,interval);
   if exitfunc = 0
   then begin
        lPolarity.Caption:=IntToStr(byte(state));
        lInterval.Caption:=IntToStr(interval);
        end
   else Memo.Lines.Add('DIOCFunc14: '+IntToStr(exitfunc));


end;

procedure TfmPlaierTGAPI.bnCallClick(Sender: TObject);
var
  channel : Integer;
  mode : Byte;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   mode:=StrToInt(editMode.Text);
   if mode > 15
   then begin
        Memo.Lines.Add('Mode incorrect!');
        Exit;
        end;
   exitfunc:=DIOCFunc15(channel,mode and 7,true);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc15 of point'+IntToStr(channel)+'='+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnCloseCHannelClick(Sender: TObject);
var
  channel : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   exitfunc:=DIOCFunc17(channel);
   if exitfunc = 0
   then Memo.Lines.Add('Close point'+IntToStr(channel))
   else Memo.Lines.Add('DIOCFunc2 of point'+IntToStr(channel)+'='+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnAlarmClick(Sender: TObject);
var
  channel : Integer;
  interval : Integer;
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   channel:=StrToInt(editChannel.Text);
   interval:=StrToInt(editInterval.Text);
   exitfunc:=DIOCFunc16(channel,interval);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc16: '+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnSirenOnClick(Sender: TObject);
var
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   exitfunc:=DIOCFunc18(TRUE);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc18: '+IntToStr(exitfunc));

end;

procedure TfmPlaierTGAPI.bnSirenOffClick(Sender: TObject);
var
  exitfunc : Integer;
begin

   if not IsAccess then Exit;

   exitfunc:=DIOCFunc18(FALSE);
   if exitfunc <> 0
   then Memo.Lines.Add('DIOCFunc18: '+IntToStr(exitfunc));


end;

procedure TfmPlaierTGAPI.editVxdNameKeyPress(Sender: TObject;
  var Key: Char);
begin
  Key:=UpCase(Key);
end;

procedure TfmPlaierTGAPI.editNumberIRQClick(Sender: TObject);
begin
  editNumberIRQ.Text:=IntToStr(Succ(StrToInt(editNumberIRQ.Text)) mod 16);
end;

procedure TfmPlaierTGAPI.editChannelClick(Sender: TObject);
begin
  editChannel.Text:=IntToStr(Succ(StrToInt(editChannel.Text)) mod 8);
end;

procedure TfmPlaierTGAPI.editPolarityClick(Sender: TObject);
begin
  editPolarity.Text:=IntToStr(Succ(StrToInt(editPolarity.Text)) mod 2);
end;

procedure TfmPlaierTGAPI.editModeClick(Sender: TObject);
begin
  editMode.Text:=IntToStr(Succ(StrToInt(editMode.Text)) mod 8);
end;

procedure TfmPlaierTGAPI.MemoChange(Sender: TObject);
begin
if Memo.Lines.Count>1000 then Memo.Clear;
end;

end.
