unit IOCTL;

interface

uses
  Windows, Messages, SysUtils;

type
   TBuf = String[127];

const
   wm_VxD = wm_User+1;
   hWindow : HWnd = 0;
   cycles : Byte = 0;
   points : Byte = 16;
   fVxDIsLoaded : Boolean = FALSE;
   hIRQ : DWORD = 0;
   sIRQ : Byte = 0;

function LoadVxD : Boolean;
function CloseVxD : Boolean;
function HookController(nCycle : Byte; nIRQ : Byte; addrINT : Word) : Boolean;
function TransmitINT(Key : Byte; Command : TBuf) : Byte;
function ReceiveINT(Key : Byte) : TBuf;
function StateINT(Key : Byte) : Byte;

implementation

const
   CVXD_APIFUNC_1 = 1;
   CVXD_APIFUNC_2 = 2;

type
   TState =  Array[0..1]Of Byte;

var
   hCVxD : THandle;
   cbBytesReturned : DWord;
   RetInfo : Array[0..9]Of DWord;
   PutInfo : Array[0..9]Of DWord;
   pReceive, pTransmit : Array[0..1]Of ^TBuf;
   pINT : ^TState;


function LoadVxD : Boolean;
begin
   Result:=False;
   fVxDIsLoaded:=False;
   hIRQ:=0;

   hCVxD:=CreateFile('\\.\CONPHONE.VXD', 0, 0, NIL,
                     CREATE_NEW, FILE_FLAG_DELETE_ON_CLOSE, 0);
   if hCVxD = INVALID_HANDLE_VALUE
   then Exit;

   fVxDIsLoaded:=True;
   Result:=True;
end;

function CloseVxD : Boolean;
begin

  Result:=False;

  if not fVxDIsLoaded
  then Exit;

  CloseHandle(hCVxD);

  fVxDIsLoaded:=False; hIRQ:=0;
  Result:=True;

end;

function HookController(nCycle : Byte; nIRQ : Byte; addrINT : Word) : Boolean;
begin

  Result:=False;

  if not fVxDIsLoaded
  then Exit;

  if nCycle < 2
  then begin
       cycles:=nCycle;
       points:=16 div (nCycle+1);
       end;

  PutInfo[0]:=nIRQ;
  PutInfo[1]:=addrINT;
  PutInfo[2]:=hWindow;
  PutInfo[3]:=wm_VxD;
  PutInfo[4]:=cycles;

  if DeviceIOControl(hCVxD, CVXD_APIFUNC_1, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       hIRQ:=RetInfo[0];
       if hIRQ = 0 then Exit;
       sIRQ:=RetInfo[1];
       pReceive[0]:=Pointer(RetInfo[2]);
       pTransmit[0]:=Pointer(RetInfo[3]);
       pReceive[1]:=Pointer(RetInfo[4]);
       pTransmit[1]:=Pointer(RetInfo[5]);
       pINT:=Pointer(RetInfo[6]);
       Result:=True;
       end;
end;

function TransmitINT(Key : Byte; Command : TBuf) : Byte;
var Cycle : Byte;
begin

  Result:=0;

  if not fVxDIsLoaded
  then Exit;

  Cycle:=Key div points;
  pTransmit[Cycle]^:=Command;
  PutInfo[0]:=Key;
  if DeviceIOControl(hCVxD, CVXD_APIFUNC_2, @PutInfo, sizeof(PutInfo),
                           @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=pINT^[Cycle];
end;


function ReceiveINT(Key : Byte) : TBuf;
var Cycle : Byte;
begin
  Result:='';

  if not fVxDIsLoaded
  then Exit;

  Cycle:=Key div points;
  Result:=pReceive[Cycle]^;
end;

function StateINT(Key : Byte) : Byte;
begin
  Result:=pINT^[Key div points];
end;

end.
