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

{--- Опции точки подключения ---}
Type TConnect=Record
     PathPhoneDLL:TPathStr;   {Путь к DLL аппарата}
     PathProtocolDLL:TPathStr;{Путь к DLL протокола}
     Options:Word;            {Интегральная опция ТА}
     Manual:Boolean;          {Флаг ручной настройки параметров}
     Is8:Boolean;             {Требование набора "8" на линии}
     StartStock:LongInt;         {Начальный запас}
     FinishStock:LongInt;        {Конечный запас}
     WaitResponse:LongInt;       {Время ожидания нажатия кнопки "Ответ"}
     end;


Type PTalk = ^TTalk;
     TTalk = Record
     FInterval:Word;       {Длительность разговора}
     FPrice:Currency;      {Стоимость разговора}
     FTariff:Currency;     {Тариф}
     FTariffInterval:Word; {Интервал тарификации (c)}
     FStartTime:TDateTime; {Время начала разговора}
     FAdvanceCab:Currency; {Внесенный аванс во время разговора}
     FZone:Byte;           {Тарифная зона абонента В}
     FCityTo:TCityStr;     {Населенный пункт абонента В}
     FDialNumber:TDialStr; {Номер абонента В}
     FPayment:Integer;     {Номер платежа}
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
