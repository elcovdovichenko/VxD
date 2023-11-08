unit Protocol;

interface

uses Windows, Classes, SysUtils, IOCTL, Cabine,DatPhone;

procedure ControlWindowRegister(Handle:HWnd; TariffDLLName:String);
procedure ControlPhoneInit(Cycles, IRQ:Byte; Addr:Word);
procedure ControlPhoneDone;
procedure ControlPhoneRegister(Key:Byte);
procedure ControlMessageHandle(Key:Byte);
function  GetPhoneState(Key:Byte) : TPhoneStateRec;
procedure PhoneOpen(Key:Byte; Summ:Currency);
procedure PhoneAddAdvance(Key:Byte; Summ:Currency);
procedure PhoneClose(Key:Byte);
Function  GetPhoneTalks(Key:Byte):Pointer;
Procedure ControlMessageRegister(StateChanged,SaveTalk,ServiceKvit,CashCheck:Word);

implementation

var
  ActPhone : array[0..1] of Integer;
  CabList :  array[0..1] of TList;

{=================================================================}

procedure SwitchNextCab(Key : Byte);
var k : Integer; cycle : Byte;
begin
  if Key > 15 then Exit;

  cycle:=Key div points;
  k:=CabList[cycle].Count;
  if k = 0 then Exit;

  ActPhone[cycle]:=succ(ActPhone[cycle]) mod k;
  TransmitInt(Key,TCabine(CabList[cycle][ActPhone[cycle]]).TlfOut);
end;

function FindByKey(Key : Byte):TCabine;
var i:Integer;
    cycle:Byte;
begin
  Result:=NIL;
  if Key > 15 then Exit;

  cycle:=Key div points;
  if CabList[cycle].Count > 0 then
  for i:=0 to pred(CabList[cycle].Count)
  do if TCabine(CabList[cycle][I]).Key=Key
     then begin
          Result:=CabList[cycle][I];
          Break;
          end;
end;

{=================================================================}

procedure ControlWindowRegister(Handle:HWnd; TariffDLLName:String);
Var PathDll:TPathChar;
begin
  hWindow:=Handle;
  StrPCopy(PathDll,TariffDLLName);

  TariffDLLHandle:=LoadLibrary(PathDll);
  if TariffDLLHandle < 32 then Raise Exception.Create('Tariff DLL not found');

  Try
  @FindZone:=GetProcAddress(TariffDLLHandle,'FindZone');
  if (@FindZone = nil) Then Raise Exception.Create('TariffDLL initialization failed!');
  @FindTariff:=GetProcAddress(TariffDLLHandle,'FindTariff');
  if (@FindTariff = nil) Then Raise Exception.Create('TariffDLL initialization failed!');
  @TariffInit:=GetProcAddress(TariffDLLHandle,'TariffInit');
  if (@TariffInit = nil) Then Raise Exception.Create('TariffDLL initialization failed!');

  Except
  FreeLibrary(TariffDLLHandle);
  End;

  TariffInit;

end;

procedure ControlPhoneInit(Cycles,IRQ:Byte; Addr:Word);
var Cycle : Byte;
begin

  if Cycles in [1,2]
  then dec(Cycles)
  else Exit;

  for Cycle:=0 to Cycles do
    begin
    CabList[Cycle]:=TList.Create;
    ActPhone[Cycle]:=0;
    end;

  HookController(Cycles,IRQ,Addr);

end;

procedure ControlPhoneRegister(Key:Byte);
var Cabine:TCabine;
    cycle:Byte;
begin
  if (Key > 15) or Assigned(FindByKey(Key))
  then Exit;

  cycle:=Key div points;
  Cabine:=TCabine.Create(Key);
  CabList[cycle].Add(Cabine);

  if CabList[cycle].Count = 1
  then SwitchNextCab(Key);
end;

procedure ControlPhoneDone;
var Cycle : byte;
begin
  for Cycle:=0 to cycles
  do CabList[Cycle].Free;
end;

procedure ControlMessageHandle(Key : Byte);
var cycle : Byte;
begin
  if Key > 15 then Exit;

  cycle:=Key div points;
  if CabList[cycle].Count=0 then Exit;

  TCabine(CabList[cycle][ActPhone[cycle]]).ProtocolHandler;
  SwitchNextCab(Key);
end;

function  GetPhoneState(Key:Byte) : TPhoneStateRec;
Var Cab:TCabine;
Begin
  Cab:=FindByKey(Key);
  If Not Assigned(Cab) Then Exit;

  Result.Talk:=Cab.Talk;
  Result.Advance:=Cab.Advance;
  Result.Cost:=Cab.CostAll;
  Result.Return:=Cab.Return;
End;

procedure PhoneOpen(Key:Byte; Summ:Currency);
Var Cab:TCabine;
Begin
  Cab:=FindByKey(Key);
  If Not Assigned(Cab) Then Exit;
  Cab.Open(Summ,False);
End;


procedure PhoneAddAdvance(Key:Byte; Summ:Currency);
Var Cab:TCabine;
Begin
  Cab:=FindByKey(Key);
  If Not Assigned(Cab) Then Exit;
  Cab.AddAdvance(Summ);
End;

procedure PhoneClose(Key:Byte);
Var Cab:TCabine;
Begin
  Cab:=FindByKey(Key);
  If Not Assigned(Cab) Then Exit;
  Cab.Close;
End;

Function  GetPhoneTalks(Key:Byte):Pointer;
Var Cab:TCabine;
Begin
  Result:=nil;
  Cab:=FindByKey(Key);
  If Not Assigned(Cab) Then Exit;
  Result:=Cab.Talks;
End;

Procedure ControlMessageRegister(StateChanged,SaveTalk,ServiceKvit,CashCheck:Word);
Begin
  WM_StateChanged:=StateChanged;
  WM_SaveTalk:=SaveTalk;
  WM_ServiceKvit:=ServiceKvit;
  WM_CashCheck:=CashCheck;
End;

end.
