unit DATPhone;

interface

const
  LenCity   = 20;
  LenNumber = 15;
  LenCode   = 9;


type
  TPathStr  = string[79];
  TTlfBuff  = string[83];
  TDialStr = string[LenNumber];
  TCityStr = string[LenCity];
  TPathChar= array[0..79] of char;

Type TExchange=Record
     Readed:Boolean;
     Buffer:TTlfBuff;
     IntState:Byte;
     End;

{--- ����� ����� ����������� ---}
Type TConnect=Record
     PathPhoneDLL:TPathStr;   {���� � DLL ��������}
     PathProtocolDLL:TPathStr;{���� � DLL ���������}
     Options:Word;            {������������ ����� ��}
     Manual:Boolean;          {���� ������ ��������� ����������}
     Is8:Boolean;             {���������� ������ "8" �� �����}
     StartStock:LongInt;         {��������� �����}
     FinishStock:LongInt;        {�������� �����}
     WaitResponse:LongInt;       {����� �������� ������� ������ "�����"}
     end;


Type PTalk = ^TTalk;
     TTalk = Record
     FInterval:Word;       {������������ ���������}
     FPrice:Currency;      {��������� ���������}
     FTariff:Currency;     {�����}
     FTariffInterval:Word; {�������� ����������� (c)}
     FStartTime:TDateTime; {����� ������ ���������}
     FAdvanceCab:Currency; {��������� ����� �� ����� ���������}
     FZone:Byte;           {�������� ���� �������� �}
     FCityTo:TCityStr;     {���������� ����� �������� �}
     FDialNumber:TDialStr; {����� �������� �}
     FPayment:Integer;     {����� �������}
     End;


Type TPhoneStateRec=Record
     Talk:TTalk;
     Advance:Currency;
     Cost:Currency;
     Return:Currency;
     End;


Const CifFloat:Byte=2;

Function CostStr(Value:Currency):String;
Function GetValCourse:Currency;

implementation
Uses SysUtils,Registry;

Var Reg : TRegistry ;


Function GetValCourse;
Begin
  Result:=1;
  try
    if Reg.OpenKey ('\Software\Orca\Medusa', false)
    then Result := Reg.ReadFloat ('CurrencyRate') ;
  except Result:=1; end ;
End;

Function CostStr(Value:Currency):String;
Begin
{  If Value<0
  Then
  Else } Result:=Format('%10.2f',[Abs(Value)]);
End;


Initialization
  Reg := TRegistry.Create ;
Finalization
  Reg.Free;
end.
