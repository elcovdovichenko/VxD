unit IOCTL;

interface

uses
  Windows, Messages, SysUtils;

const
    //���������
    mesOutputData = 1 ;        //��������� ������ ������ ���������
    mesOutputSymbol = 2 ;      // ������� ��������� ������
    mesInputSymbol = 3 ;       // ������ ��������� ������
    mesLineChange = 4 ;        // ���������� ���������� �������� �������
    mesLineIn = 5 ;            // ������ ������ ��������� ���������� � ������������
    mesPulseIn = 6 ;           // ������ ������� ��������� ���������� � ������������
    mesPulseOut = 7 ;          // ������� ������� ��������� ���������� � ������������
    mesAlarmState = 8 ;        // ���������� ��������� ���������� ������

    //���� ����������
    ecOK = 0 ;                 //������
    ecNoFunc = 1 ;             // ������� �� ��������������
    ecWrongNum = 2 ;           // ������������ ����� �����
    ecNoCtlNum = 3 ;           // ����� � ��������� ������� ��������� �� ��������������
    ecNoInitNum = 4 ;          // ����� � ��������� ������� �� ������������
    ecWrongParam = 5 ;         //������������� �������� ���������
    ecAbsentBuf = 6 ;          // ����� �����������
    ecOverlapBuf = 7 ;         // ���������� �������

    //���� ������ ������������ ��������� �����
    chkAllOff = 0 ;            // ���������
    chkPolarOn = 1 ;           // ��������� ����������
    chkPulseOn = 2 ;           // ����� ��������
    chkAllOn = 3 ;             // ��������� ���������� ��� ����� ��������

    //���� ������� ���������� � ��������� �����
    stStart = 1 ;              // ������� � �����
    stStop = 2;                // ������� � ����
    stSymbolOut = 4 ;          // ������� ��������� ������
    stSymbolIn = 8 ;           // ������ ��������� ������

    //���� ��������� ������
    spd50 = 0 ;                // 50 ���
    spd100 = 1 ;               // 100 ���
    spd200 = 2 ;               // 200 ���
    spd300 = 3 ;               // 300 ���
    spd600 = 4 ;               // 600 ���
    spd1200 = 5 ;              // 1200 ���
    spd2400 = 6 ;              // 2400 ���
    spd4800 = 7 ;              // 4800 ���
    spd9600 = 8 ;              // 9600 ���

    //���� ������ ���������� ������ ������ ������
    bufFull = 0 ;               // ��������
    bufPause = 1 ;              // ����� � ������
    bufPolar = 2 ;              // �������������� ����������
    bufText = 3 ;               // �������������� �����
    bufAlarm = 4 ;              // ������ ������

const
   POINTS : Byte = 0;
   fVxDIsLoaded : Boolean = FALSE;
   hIRQ : DWord = 0;
   sIRQ : Byte = 0;
   pState : Pointer = Nil;
   mINT : Byte = $FF;
   dINT : Byte = $FF;
   codeExit : Integer = 0;

function LoadVxD(NameVxd:String) : DWord;
function CloseVxD : Boolean;
function DIOCFunc1(const addrINT; nIRQ:Byte; hWin:HWnd; wMessage:Longint) : Integer;
function DIOCFunc2(point:Word; speed, infobits, stopbits:Byte; var intstate:Byte; var initime:DWord) : Integer;
function DIOCFunc3(point:Word) : Integer;
function DIOCFunc4(point:Word) : Integer;
function DIOCFunc5(point:Word; size:DWord; var pbuf:Pointer) : Integer;
function DIOCFunc6(point:Word; fill:DWord) : Integer;
function DIOCFunc7(point:Word; symbol:Byte) : Integer;
function DIOCFunc8(point:Word) : Integer;
function DIOCFunc9(point:Word; start:Boolean) : Integer;
function DIOCFunc10(point:Word; start:Boolean; interval:Integer) : Integer;
function DIOCFunc11(point:Word; start:Boolean; interval:Integer; var trap:Word) : Integer;
function DIOCFunc12(point:Word; start:Boolean; intmin:Integer; intmax:Integer; var trap:Word) : Integer;
function DIOCFunc13(point:Word; var trap:Word) : Integer;
function DIOCFunc14(point:Word; var start:Boolean; var interval:Integer) : Integer;
function DIOCFunc15(point:Word; indicate:Word; activate:boolean) : Integer;
function DIOCFunc16(point:Word; interval:Integer) : Integer;
function DIOCFunc17(point:Word) : Integer;
function DIOCFunc18(key:Boolean) : Integer;
function StrToHexAddr(AddrStr:String) : DWord;

implementation

var
   hCVxD : THandle;
   cbBytesReturned : DWord;
   RetInfo : Array[0..9]Of DWord;
   PutInfo : Array[0..9]Of DWord;


function LoadVxD(NameVxd:String) : DWord;
begin
   Result:=0;
   fVxDIsLoaded:=False;
   hIRQ:=0;

   hCVxD:=CreateFile(PChar('\\.\'+NameVxD), 0, 0, NIL,
                     CREATE_NEW, FILE_FLAG_DELETE_ON_CLOSE, 0);

   if hCVxD = INVALID_HANDLE_VALUE
   then Result:=GetLastError
   else fVxDIsLoaded:=True;
end;

function CloseVxD : Boolean;
var i : Word;
begin

  Result:=False;

  if not fVxDIsLoaded
  then Exit;

  for i:=1 to POINTS
  do DIOCFunc17(pred(i));

  CloseHandle(hCVxD);

  fVxDIsLoaded:=False;
  hIRQ:=0;
  Result:=True;

end;

function DIOCFunc1(const addrINT; nIRQ:Byte; hWin:HWnd; wMessage:Longint) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=DWORD(addrINT);
  PutInfo[1]:=nIRQ;
  PutInfo[2]:=hWin;
  PutInfo[3]:=wMessage;

  if DeviceIOControl(hCVxD, 1, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       Result:=0;
       hIRQ:=RetInfo[0];
       if hIRQ = 0 then Exit;
       sIRQ:=RetInfo[1];
       POINTS:=RetInfo[2];
       pState:=Pointer(RetInfo[3]);
       mINT:=RetInfo[4];
       dInt:=RetInfo[5];
       end
  else Result:=-2;
end;

function DIOCFunc2(point:Word; speed, infobits, stopbits:Byte; var intstate:Byte; var initime:DWord) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=speed;
  PutInfo[2]:=infobits;
  PutInfo[3]:=stopbits;

  if DeviceIOControl(hCVxD, 2, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       Result:=RetInfo[0];
       intstate:=RetInfo[1];
       initime:=RetInfo[2];
       end
  else Result:=-2;

end;

function DIOCFunc3(point:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;

  if DeviceIOControl(hCVxD, 3, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc4(point:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;

  if DeviceIOControl(hCVxD, 4, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc5(point:Word; size:DWord; var pbuf:Pointer) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=size;

  if DeviceIOControl(hCVxD, 5, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       Result:=RetInfo[0];
       pbuf:=Pointer(RetInfo[1]);
       end
  else Result:=-2;

end;

function DIOCFunc6(point:Word; fill:DWord) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=fill;

  if DeviceIOControl(hCVxD, 6, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;


function DIOCFunc7(point:Word; symbol:Byte) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=Dword(symbol);

  if DeviceIOControl(hCVxD, 7, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc8(point:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;

  if DeviceIOControl(hCVxD, 8, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc9(point:Word; start:Boolean) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=Dword(start);

  if DeviceIOControl(hCVxD, 9, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc10(point:Word; start:Boolean; interval:Integer) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=Dword(start);
  PutInfo[2]:=interval;

  if DeviceIOControl(hCVxD, 10, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc11(point:Word; start:Boolean; interval:Integer; var trap:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=Dword(start);
  PutInfo[2]:=interval;

  if DeviceIOControl(hCVxD, 11, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       trap:=RetInfo[1];
       Result:=RetInfo[0];
       end
  else Result:=-2;

end;

function DIOCFunc12(point:Word; start:Boolean; intmin:Integer; intmax:Integer; var trap:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=Dword(start);
  PutInfo[2]:=intmin;
  PutInfo[3]:=intmax;

  if DeviceIOControl(hCVxD, 12, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       trap:=RetInfo[1];
       Result:=RetInfo[0];
       end
  else Result:=-2;

end;

function DIOCFunc13(point:Word; var trap:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=trap;

  if DeviceIOControl(hCVxD, 13, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       trap:=RetInfo[1];
       Result:=RetInfo[0];
       end
  else Result:=-2;

end;

function DIOCFunc14(point:Word; var start:Boolean; var interval:Integer) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;

  if DeviceIOControl(hCVxD, 14, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then begin
       Result:=RetInfo[0];
       start:=Boolean(RetInfo[1]);
       interval:=RetInfo[2];
       end
  else Result:=-2;

end;

function DIOCFunc15(point:Word; indicate:Word; activate:boolean) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=indicate;
  PutInfo[2]:=DWORD(activate);

  if DeviceIOControl(hCVxD, 15, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc16(point:Word; interval:Integer) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;
  PutInfo[1]:=interval;

  if DeviceIOControl(hCVxD, 16, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc17(point:Word) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=point;

  if DeviceIOControl(hCVxD, 17, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function DIOCFunc18(key:Boolean) : Integer;
begin

  Result:=-1;

  if not fVxDIsLoaded
  then Exit;

  PutInfo[0]:=DWord(key);

  if DeviceIOControl(hCVxD, 18, @PutInfo, sizeof(PutInfo),
                         @RetInfo, sizeof(RetInfo), cbBytesReturned, NIL)
  then Result:=RetInfo[0]
  else Result:=-2;

end;

function StrToHexAddr(AddrStr:String) : DWord;
var i:Integer; cif:DWord; ch:Char;
begin
result:=0;
AddrStr:=UpperCase(AddrStr);
cif:=0;
for i:=1 to Length(AddrStr)
do begin
   ch:=AddrStr[i];
   case ch of
     '0'..'9': cif:=(Ord(ch)-Ord('0'));
     'A'..'F': cif:=(Ord(ch)-Ord('A')+10);
     else begin
          result:=$FFFFFFFF;
          exit;
          end;
     end;
   result:=result*16+cif;
   end;
end;

end.
