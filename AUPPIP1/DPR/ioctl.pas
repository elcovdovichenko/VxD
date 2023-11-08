unit IOCTL;

interface

uses
  Windows, Messages, SysUtils;

const
   wm_VxD = wm_User;
   hWindow : HWnd = 0;
   fVxDIsLoaded : Boolean = FALSE;
   LineControl : Byte = 0;
   hIRQ : DWORD = 0;
   sIRQ : Byte = 0;

function AUPPIP1_LoadVxD : DWord;
function AUPPIP1_CloseVxD : Boolean;
function AUPPIP1_HookController(nIRQ : Byte; addrINT : Word) : Boolean;
function AUPPIP1_Control : Byte;

implementation

const
   CVXD_APIFUNC_1 = 1;
   CVXD_APIFUNC_2 = 2;
   CVXD_APIFUNC_3 = 3;

var
   hCVxD : THandle;
   cbBytesReturned : DWord;
   RetInfo : Array[0..9]Of DWord;
   PutInfo : Array[0..9]Of DWord;

function AUPPIP1_LoadVxD : DWord;
begin
  Result:=0;
  fVxDIsLoaded:=False;
  hIRQ:=0;

  hCVxD:=CreateFile('\\.\AUPPIP1.VXD', 0, 0, NIL,
                    CREATE_NEW, FILE_FLAG_DELETE_ON_CLOSE, 0);
  if hCVxD = INVALID_HANDLE_VALUE
  then Result:=GetLastError
  else fVxDIsLoaded:=True;

end;

function AUPPIP1_CloseVxD : Boolean;
begin

  Result:=False;

  if not fVxDIsLoaded
  then Exit;

  if LineControl <> 0 then AUPPIP1_Control;

  DeviceIOControl(hCVxD, CVXD_APIFUNC_3, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL);
  CloseHandle(hCVxD);

  fVxDIsLoaded:=False;
  hIRQ:=0;

  Result:=True;

end;

function AUPPIP1_HookController(nIRQ : Byte; addrINT : Word) : Boolean;
begin

  Result:=False;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=nIRQ;
  PutInfo[1]:=addrINT;
  PutInfo[2]:=hWindow;
  PutInfo[3]:=wm_VxD;

  if DeviceIOControl(hCVxD, CVXD_APIFUNC_1, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       hIRQ:=RetInfo[0];
       if hIRQ = 0 then Exit;
       sIRQ:=RetInfo[1];
       Result:=True;
       end;
end;

function AUPPIP1_Control : Byte;
begin

  Result:=0;

  if not fVxDIsLoaded
  then Exit;

  LineControl:=LineControl Xor 1;
  PutInfo[0]:=LineControl;
  DeviceIOControl(hCVxD, CVXD_APIFUNC_2, @PutInfo, sizeof(PutInfo),
                  @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL);

  Result:=LineControl;

end;

end.
