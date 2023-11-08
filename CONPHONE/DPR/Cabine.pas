unit Cabine;

interface

uses
  SysUtils,
  WinTypes,
  WinProcs,
  Messages,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  DatPhone,
  ListStrc,
  Options,
  IOCTL;


Type TCabineState=(csClosed,
                   csDial,
                   csTalk,
                   csPreBlockage,
                   csPreOpen,
                   csPreClose,
                   csCreateProgram,
                   csOpenProgram,
                   csFault);
Type TCabineOperation=(coOpenAdd,coClose,coShowTalks);
Type TCabineCommandType=(ctNone,ctOpen,ctClose,ctAddAdvance);

Const
     ccState     = #$10#$F0;
     ccOpen      = #$80#$80;
     ccClose     = #$40#$C0;
     ccBreakDial = #$08#$F8;

Const
     WM_StateChanged:Word = WM_User;
     WM_SaveTalk:Word     = WM_User;
     WM_ServiceKvit:Word  = WM_User;
     WM_CashCheck:Word    = WM_User;


Var  //DLL Tariff
  TariffInit:Procedure;
  FindZone:Function(Dial:TDialStr; Var Zone:Byte; City:TCityStr):Boolean;
  FindTariff:Function(Zone:Byte; Var Tariff:Currency; Pref:Boolean):Boolean;
  TariffDLLHandle  : THandle;

{--- ������ ���������� ������� ---}
type TCabine = class
     private
     FTimer:LongInt;
     FLastTickCount:LongInt;
     FKey:Byte;          {����� ����� �����������}

     FNumber:Byte;      {����� ������}
     FState:TCabineState; {��������� ������}
     FActInv:TCabineCommandType;

     FAdvanced:Currency;{������� �����}
     FConvTime:Byte;    {��������� ������������ ���������}
     FErrs:Word;        {�������� ������}
     FAdvance:Currency; {�����}
     FTariffDelay:LongInt; //�������� �����������
     FDebug:Boolean;
     FFinal:Boolean;

     FNatCost,FValCost:Currency;
     FReturn:Currency;  {�������}
     FTalks:PList;      {������ ����������}
     FTalk:TTalk;       {������� ��������}
     FConnect:TConnect; {����� ����� �����������}

     FIntState:Byte;    //��������� ����������
     FTlfIn:TTlfBuff;
     FTlfOut:TTlfBuff;

     FPhoneDLLName     : TPathStr;
     PhoneDLLHandle    : THandle;

     {��������� �������������� � ��������� ��������}
     AppDisplayInfo   : Function(State : byte; Avans,isCostAll,isTariff : Currency) : TTlfBuff;
     AppLengthStrInfo : Function : byte;
     GetProperty      : Function(AttachNo:Byte):Word;

     Function  GetInBuffer:String;
     Function  GetOutBuffer:String;
     Procedure SetChanged(Value:Boolean);
     Procedure SaveState;
     Function  BasePhoneTariffFind(Dial:TDialStr; Var City:TCityStr; Var Zone:Byte):Currency;
     protected

     public
       Constructor Create(Key:Byte); Virtual;
       Destructor  Destroy; Override;

       Function  GetCostAll:Currency;
       Procedure SetCostAll(Value:Currency);
       Procedure ProtocolHandler;

       Procedure Open(Sum : Currency; EskeKermen:Boolean);
       Procedure AddAdvance(Sum:Currency);
       Procedure Close;
       Procedure ReadOptions(Manual:Boolean);
       Function  SetPhoneLibrary : boolean;
       Function  UnloadLibrary : boolean;
       Function  PhoneProgram(Options:word; Default:TTlfBuff) : TTlfBuff;
       Procedure IncTimer;
       Function  GetTalkTariff:Currency;

       Property Key : Byte             Read FKey                  Write FKey;
       Property DriverPath : TPathStr  Read FPhoneDLLName         Write FPhoneDLLName;
       Property Number : Byte          Read FNumber               Write FNumber;
       Property Manual : Boolean       Read FConnect.Manual       Write FConnect.Manual;
       Property WaitResponse : Integer Read FConnect.WaitResponse Write FConnect.WaitResponse;
       Property StartStock : Integer   Read FConnect.StartStock   Write FConnect.StartStock;
       Property FinishStock : Integer  Read FConnect.FinishStock  Write FConnect.FinishStock;
       Property Is8 : Boolean          Read FConnect.Is8          Write FConnect.Is8;
       Property CostAll : Currency     Read GetCostAll            Write SetCostAll;

       Property State : TCabineState  Read FState;
       Property InBuffer : String      Read GetInBuffer;
       Property OutBuffer : String     Read GetOutBuffer;
       Property Timer : LongInt        Read FTimer;
       Property TlfOut : TTlfBuff      Read FTlfOut;
       Property TalkTariff : Currency  Read GetTalkTariff;
       Property TalkZone : Byte        Read FTalk.FZone;
       Property Advance : Currency     Read FAdvance;
       Property Return : Currency      Read FReturn;
       Property DialNumber : TDialStr  Read FTalk.FDialNumber;
       Property TalkInterval:Word      Read FTalk.FInterval;

       Property Changed : Boolean      Write SetChanged;
       Property IntState : Byte        Write FIntState;
       Property TlfIn : TTlfBuff       Write FTlfIn;
       Property Talk :TTalk   Read FTalk;
       Property Talks:PList   Read FTalks;
     end;

implementation

Function Byte_Recover(datum : byte):string;
Var Lo_Datum , i : byte;
    str2 : string[2];
Begin
str2:='';
For i:=1 to 2 do
  begin
  Lo_datum:=datum mod $10; datum:=datum div $10;
  if Lo_datum < 10 then str2:= chr(Lo_datum + $30) + str2
  else str2:=chr(Lo_datum + $37) + str2;
  end;
Byte_recover:=str2;
End;

Constructor TCabine.Create;
Begin
  Inherited Create;
  FKey:=Key;
  FTalks:=New(PList,Init);
  FLastTickCount:=GetTickCount;
  PhoneDLLHandle:=0;
  FTimer:=0;

  DriverPath:=Option.Attach[Succ(FKey)].CurrentDriver;
  Number:=Option.Attach[Succ(FKey)].CabineNo;
  Manual:=Option.Attach[Succ(FKey)].IsManualSetup;
  WaitResponse:=Option.Attach[Succ(FKey)].WaitAnsver;
  StartStock:=Option.Attach[Succ(FKey)].StartStock;
  FinishStock:=Option.Attach[Succ(FKey)].EndStock;
  Is8:=Option.Attach[Succ(FKey)].Request8;
  SetPhoneLibrary;
  ReadOptions(Option.Attach[Succ(FKey)].IsManualSetup);

  FDebug:=False;
  FTlfIn:='';
  FState:=csCreateProgram;
  FTlfOut:=ccState;
  FErrs:=0;
End;

Destructor TCabine.Destroy;
Begin
  Dispose(FTalks,Done);
  UnloadLibrary;
  Inherited Destroy;
End;

Procedure TCabine.ReadOptions;
Begin
  FConnect.Options:=GetProperty(FKey);
  If Manual Then FConnect.Options:=FConnect.Options or $0100;
End;


Procedure TCabine.Open(Sum : Currency; EskeKermen:Boolean);
Begin
  FAdvance:=Sum; FAdvanced:=Sum;
  FActInv:=ctOpen;
  FDebug:=EskeKermen;
End;

Procedure TCabine.Close;
Begin
  FActInv:=ctClose;
End;

Procedure TCabine.AddAdvance(Sum:Currency);
Begin
  FAdvance:=FAdvance+Sum;
  FAdvanced:=FAdvanced+Sum;
  FActInv:=ctAddAdvance;
End;

Procedure TCabine.ProtocolHandler;
Var amount, i, k, c, m:Byte;

  procedure RestOfAvans;
  var amount, i, k : byte;
  begin
    If (FAdvance-CostAll) <= TalkTariff
    Then FTlfOut:=#$24
    Else FTlfOut:=#$20;

    FTlfOut:=FTlfOut+AppDisplayInfo(Byte(FState),FAdvance,CostAll,TalkTariff);
    amount:=0; k:=Length(FTlfOut);
    for i:=1 to k do Inc(amount,Byte(FTlfOut[i]));
    FTlfOut:=FTlfOut+Chr(amount xor $FF);
  end;

  procedure BreakDial;
  begin
    if (FState = csDial) and
       (FTimer > (FConnect.WaitResponse*1000)) and
       (Length(FTalk.FDialNumber)>=5)
    then FTlfOut:=ccBreakDial
    else FTlfOut:=ccState;
  end;

  procedure TalkInit;
  begin
  with FTalk do
    begin
    FDialNumber:=''; FInterval:=0; FPrice:=0; FTariff:=0; FCityTo:=''; FZone:=0;
    FTimer:=0; FFinal:=False;
    end;
  end;

  procedure SaveCost;
  begin
    If FTalk.FPrice<>0
    Then Begin

         if FConvTime > FTalk.FInterval then FAdvanced:=-FAdvanced;
         FTalk.FAdvanceCab:=FAdvanced;

         FTalk.FPayment:=0;
         PostMessage(HWND_BROADCAST,WM_SaveTalk,Key,Integer(@FTalk));

        (* //����� ������ ������� �� ����
         For I:=1 to zonZoneCount{Option.Tarif.Zone.Count}
         Do Begin
            If Option.Tarif.Zone[I].IsAttached Then
            If Option.Tarif.Zone[I].ZoneNo=FTalk.FZone
            Then Begin
                 FTalk.FPayment:=Option.Tarif.Zone[I].Payment;
                 Break;
                 End;
            End;

        If FDebug Then Exit;
        If Talk.FPrice<0 Then Talk.FPrice:=Abs(Talk.FPrice) * GetValCourse;
        TCabinesList(Owner).AppendArc(Number,Talk);

        *)

         FAdvanced:=0;
         FTalks^.InsertOne (FTalk,SizeOf(FTalk),FTalks^.SizeList);
         End;

    TalkInit;
  end;

  procedure ServiceKvit(Num : byte; Sum : Currency);
  begin
    PostMessage(HWND_BROADCAST,WM_ServiceKvit,Key,Integer(@Sum));
    {
    If (Not TCabinesList(Owner).UseCash) or FDebug Then Exit;

    If Option.Tarif.AvansCheck and (Sum <> 0)
    then Begin
         If Not TCabinesList(Owner).ForAnver
         Then try
              SpoolOLE := CoSpoolAuto.Create;
              if SpoolOLE<>nil then
              If Sum>0 Then SpoolOLE.AddCash(Sum)
                       Else SpoolOLE.ReturnCash(-Sum);
              except
              end;
         End;}
  end;

  procedure KvitPrint;
  var i, n : word; p : pointer;
      C:Currency;
  begin
    begin
    ServiceKvit(Number,-FAdvance);

    if FTalks^.Fill > 0 then
    for i:=0 to pred(FTalks^.Fill) do
      begin
      FTalks^.GetOnePtr(p,n,i);
      if TTalk(p^).FPrice = 0 then
        begin
          C:=TTalk(p^).FTariff * TTalk(p^).FInterval;
          If C<0
          Then FValCost:=FValCost-C
          Else FNatCost:=FNatCost-C;
        end;
      end;
    FReturn:=FAdvance-CostAll;

    if FAdvance >= CostAll then
      if (FAdvance > 0) and (CostAll > 0) then
        begin

        PostMessage(HWND_BROADCAST,WM_CashCheck,Key,Integer(FTalks));
//������ ��������� ����
        (*If TCabinesList(Owner).UseCash
        Then Begin
             If Not FDebug  Then

             If TCabinesList(Owner).ForAnver
             Then Try  //��� ������
                  TTT:=CreateOLEObject('P1.ttt');
                  TTT.Ident:=Option.Tarif.CheckString+' '+IntToStr(Number);
                  For I:=0 To Pred(FTalks^.Fill)
                  Do Begin
                     FTalks^.GetOne(Talk,W,I);
                     If Talk.FPrice<0
                        Then IsPrice:=Abs(Talk.FPrice)*GetValCourse
                        Else IsPrice:=Talk.FPrice;
                     TTT.AddPayArt(IsPrice, Talk.FPayment,Res);
                     End;
                  TTT.CloseCheck(Res);
                  Except
                  End

             Else Try  //��� ���
                  SpoolOLE := CoSpoolAuto.Create;
                  if SpoolOLE<>nil
                  Then Begin
                       SpoolOLE.IdentOnce:=Option.Tarif.CheckString+' '+IntToStr(Number);
                       For I:=0 To Pred(FTalks^.Fill)
                       Do Begin
                          FTalks^.GetOne(Talk,W,I);
                          If Talk.FPrice<0
                          Then IsPrice:=Abs(Talk.FPrice)*GetValCourse
                          Else IsPrice:=Talk.FPrice;
                          SpoolOLE.AddPayArt(IsPrice, Talk.FPayment);
                          End;
                       SpoolOLE.CloseCheck(Advance);
                       end;
                  Except
                  End;
             FDebug:=False;
             End;
        *)
        end
      else
    else FReturn:=0;

    FTalks:=New(PList,Init);
    FAdvance:=0; FAdvanced:=0; CostAll:=0;
    end;
  end;

  procedure RepeatProtocol;
  begin
   FTlfOut:=ccState;
   {if (Byte(FTlfOut[1]) and $20) = $20 then FTlfOut[0]:=Chr(AppLengthStrInfo);
   inc(FTlfOut[0],2);}
  end;

  procedure ErrorHandle(Kind : byte);
  Var F:Text;
  begin
    FErrs:=FErrs  and $FF00 or Kind;

    If FState = csFault
    Then FTlfOut:=ccClose
    Else Begin
         If Kind = $80 then FErrs:=FErrs or (FIntState and $1F);

//         ShowMessage(IntToHex(Kind,2));

         {-- �������� �� ���������� ����� ������ --}
         If (FErrs and $600) = $600
         Then Begin

              {-- ����� ��������� � ���� --}
              Try
              {$I-}
              Assign(F,'Errors.msg');
              Append(F); If IOResult<>0 Then Rewrite(F);
              Writeln(F,DateToStr(Date)+' '+ TimeToStr(Now)+' ������ '+ IntToStr(Number)+' ������ '+IntToHex(FErrs,2));
              Finally
              System.Close(F);
              End;

              {-- �������� ������� ������ --}
              FErrs:=FErrs and $00FF;

              {-- ���� � ��������� ��������� - ������ ��� --}
              If FState in [csDial,csTalk,csPreOpen]
              Then Begin
                   SaveCost;
                   KvitPrint;
                   End;

              {-- ��������� � ��������� ������ --}
              FState:=csFault;
              FTlfOut:=ccClose;
              Changed:=True;
              end

         Else Begin
              {-- ����������� ������� ������ --}
              If (FErrs and $600) = 0
              Then Inc(FErrs,$100);
              RepeatProtocol;
              End;
      End

  end;

  Function ShowProtocol(S:String):String;
  Var I:Integer;
  Begin
    Result:='';
    For I:=1 to Length(S)
    Do Result:=Result+IntToHex(Byte(S[I]),2)
  End;



begin
  // ������������
  IncTimer;
  // ��������� ����������� ��������
  If FActInv > ctNone
  Then Begin
       Case FActInv of
        ctOpen: begin
                TalkInit;
                ServiceKvit(Number,FAdvance);
                CostAll:=0; FReturn:=0; FConvTime:=0;
                FState:=csOpenProgram;
                FTlfOut:=PhoneProgram(FConnect.Options,#$10#$F0);
                FErrs:=0;
                end;

        ctClose:
                begin  //��������� �������� ������
                SaveCost; KvitPrint;
                FState:=csPreClose;
                FTlfOut:=ccClose;
                FErrs:=0;
                end;

        ctAddAdvance:
                begin  //���������� ������
                case FState  of
                   csTalk: RestOfAvans;
                   csPreBlockage: FTlfOut:=ccClose;
                   else FTlfOut:=ccState;
                   end;
                FErrs:=0;
                Changed:=True;
                end;
        end; {Case}
       FActInv:=ctNone;
       Exit;
       End;

  // ����� ���������
  FTlfIn:=ReceiveINT(FKey);
  FIntState:=StateINT(FKey) and $9F;

  // ������ ����������
  if FIntState <> $01
  then begin
       ErrorHandle($80);
       //ShowMessage(ShowProtocol(FTlfIn)+' '+IntToHex(FIntState,2));
       Exit;
       end;

  // ����������� �����
  amount:=0; k:=Length(FTlfIn);
  for i:=1 to k do Inc(amount,Byte(FTlfIn[i]));
  if not (amount in [$00,$FF])
  then begin
       ErrorHandle($08);
       //ShowMessage(ShowProtocol(FTlfIn)+' '+IntToHex(Amount,2));
       Exit;
       end;

  // ����� ���������
  c:=Byte(FTlfIn[1]);
  If c and $10 = $10 then m:=$0F Else m:=$07;
  if (c and m) <> (k - 2)
  then begin
       ErrorHandle($04);
       Exit;
       end;

  //��������� �������������� ���������
  if (c and $80) = $80
  then Begin
       case FState of
         csClosed,csPreBlockage,csDial,csTalk:
           begin
           FTlfOut:=ccState;
           FErrs:=0;
           end;

         csPreOpen:ErrorHandle($01);

         csPreClose:
           begin
           FState:=csClosed;
           FTlfOut:=ccState;
           Changed:=True;
           FErrs:=0;
           end;

         csCreateProgram:
           Begin
           FTlfOut:=PhoneProgram(FConnect.Options,ccState);
           FState:=csClosed;
           FErrs:=0;
           Changed:=True;
           End;

         csOpenProgram:
           Begin
           FState:=csPreOpen;
           FTlfOut:=ccOpen;
           FErrs:=0;
           End;

         csFault:
           begin
           FState:=csCreateProgram;
           FAdvance:=0;
           FAdvanced:=0;
           CostAll:=0;
           FTlfOut:=ccClose;
           FErrs:=0;
           end;

         else
           begin
           FTlfOut:=ccState;
           FErrs:=0;
           end;
         end; { Case FState of }
       exit;
       end;

  //��������� ����������������� ���������
  if (c and $40) = $40
  then Begin
       if FState in [csClosed,csPreBlockage,csPreClose,csFault]
       Then Begin
            ErrorHandle($02);
            Exit;
            End;

       with FTalk
       do begin
          FErrs:=0;
          case FState of
            csPreOpen:
              begin
              TalkInit; FState:=csDial;
              Changed:=True;
              RestOfAvans;
              end;
            Else {Case}
              begin

              // ����� ������
              if (c and $18) <> 0
              then begin
                   if FState = csTalk then SaveCost;
                   FState:=csDial;

                   if (c and $18) = $08
                   then begin
                        TalkInit;
                        RestOfAvans;
                        Changed:=True;
                        Exit;
                        end;

                   if (c and $10) = $10
                   then begin
//                        ShowMessage(ShowProtocol(FTlfIn));
                        c:=c and $0F; FDialNumber:='';
                        for i:=2 to succ(c)
                        do if FTlfIn[i] <= #$0A
                           then begin
                                if FTlfIn[i] = #$0A then FTlfIn[i]:=#0;
                                FDialNumber:=FDialNumber+Chr(Byte(FTlfIn[i])+$30);
                                end;
                        Changed:=True;

                        if Length(FDialNumber) <= 7
                        then begin
                             FTariff:=0;
                             FTlfOut:=ccState;
                             if Length(FDialNumber) <= 5 then FTimer:=0;
                             end
                        else if FTariff = 0
                             then begin
                                  if FConnect.Is8 and (FDialNumber[1] = '8')
                                  then m:=2
                                  else m:=1;
                                  FTariff:=BasePhoneTariffFind(Copy(FDialNumber,m,LenCode),FCityTo,FZone);
                                  if (FTariff = 0) or ((FAdvance - CostAll) < TalkTariff)
                                  then Begin
                                       TalkInit;
                                       FTlfOut:=ccBreakDial;
                                       End
                                  else Begin
                                       FTimer:=0;
                                       FTlfOut:=ccState;
                                       end;
                                  end
                             else BreakDial;
                        end
                   else FTlfOut:=ccState;

                   exit;
                   end;

              //��������
              if (c and $20) = $20
              then begin
                   if FState = csDial
                   then begin
                        if FTariff = 0
                        then if FConnect.Is8 and (FDialNumber[1] <> '8')
                             then FTariff:=BasePhoneTariffFind('',FCityTo,FZone)
                             else begin
                                  TalkInit;
                                  FTlfOut:=ccBreakDial;
                                  Exit;
                                  end;

                        FTimer:=FConnect.StartStock*1000;
                        FStartTime:=0;
                        FTalk.FInterval:=0;

                        //����� ��������� �����������
                        FTalk.FTariffInterval:=60000;
                        For I:=1 to zonZoneCount
                        Do Begin
                           If Option.Tarif.Zone[I].IsAttached
                           Then If Option.Tarif.Zone[I].ZoneNo=FTalk.FZone
                                Then Begin
                                     FTalk.FTariffInterval:=Option.Tarif.Zone[I].TarifRange*1000;
                                     Break;
                                     End;
                           End;
                        FState:=csTalk;
                        Changed:=True;
                        end;

                   If (FInterval>0) and not FFinal
                   Then FFinal:= (FTimer- pred(FInterval)*FTariffInterval) >=
                                 (FTariffInterval - FConnect.FinishStock);


                   If (FInterval=0) and (FTimer > FTariffDelay+ FConnect.StartStock*1000)
                       or (FInterval>0) and ((FTimer div FTalk.FTariffInterval)>=FInterval)
                   then begin
                        if (FAdvance - CostAll) < TalkTariff
                        then begin
                             SaveCost;
                             FState:=csDial;
                             FTlfOut:=ccBreakDial;
                             Changed:=True;
                             end

                        else begin
                             if FStartTime > 0
                             then begin
                                  Inc(FTalk.FInterval); Inc(FConvTime);
                                  FPrice:=FPrice+FTariff;
                                  If FTariff<0
                                  Then FValCost:=FValCost+FTariff
                                  Else FNatCost:=FNatCost+FTariff;

                                  Changed:=True;
                                  FFinal:=False;
                                  end
                             else FStartTime:=Now;
                             RestOfAvans;
                             end;
                        end
                   else FTlfOut:=ccState;
                   end
              else if FState = csTalk
                   then begin
                        SaveCost; FState:=csDial;
                        If FFinal
                        Then Begin //������ � ���� ��������� ������
                             Inc(FTalk.FInterval); Inc(FConvTime);
                             FPrice:=FPrice+FTariff;

                             If FTariff<0
                             Then FValCost:=FValCost+FTariff
                             Else FNatCost:=FNatCost+FTariff;
                             FFinal:=False;
                             End;

                        RestOfAvans;
                        Changed:=True;
                        end
                   else BreakDial;
              end;
            end; {Case}
          end;
       End;
End;

Procedure TCabine.IncTimer;
Var NewTickCount:LongInt;
Begin
  NewTickCount:=GetTickCount;
  FTimer:=FTimer+Abs(NewTickCount-FLastTickCount);
  FLastTickCount:=NewTickCount;
End;

function TCabine.SetPhoneLibrary : boolean;
var PathDll : TPathChar;
begin
  Result:=False;
  If FPhoneDLLName='' Then Exit;

  StrPCopy(PathDll,FPhoneDLLName);
  PhoneDLLHandle:=LoadLibrary(PathDll);
  if PhoneDLLHandle < 32 then Exit;

  @AppDisplayInfo:=GetProcAddress(PhoneDLLHandle,'AppDisplayInfo');
  if (@AppDisplayInfo = nil) and UnloadLibrary then Exit;
  @AppLengthStrInfo:=GetProcAddress(PhoneDLLHandle,'AppLengthStrInfo');
  if (@AppLengthStrInfo = nil) and UnloadLibrary then Exit;
  @GetProperty:=GetProcAddress(PhoneDLLHandle,'GetProperty');
  if (@GetProperty = nil) and UnloadLibrary then Exit;

  Result:=True;
end;

function TCabine.PhoneProgram(Options:word; Default:TTlfBuff) : TTlfBuff;
begin
if Hi(Options) = 0 then
  PhoneProgram:=Default
else
  PhoneProgram:=#$01+Chr(Lo(Options))+Chr(succ(Lo(Options)) xor $FF);
end;

function TCabine.UnloadLibrary : boolean;
Begin
  Result:=False;
  if PhoneDLLHandle < 32 then Exit;
  FreeLibrary(PhoneDLLHandle);
  PhoneDLLHandle:=0;
  Result:=True;
End;

Function TCabine.GetInBuffer:String;
Var I:Integer;
Begin
  Result:='';
  For I:=1 to Length(FTlfIn) do Result:=Result+Byte_Recover(Byte(FTlfIn[i]));
End;

Function TCabine.GetOutBuffer:String;
Var I:Integer;
Begin
  Result:='';
  For I:=1 to Length(FTlfOut) do Result:=Result+Byte_Recover(Byte(FTlfOut[i]));
End;

Function TimeInRange(IsTime,Start,Stop:Integer):Boolean;

  Function Interval(Time1,Time2:Integer):Integer;
  Const   MaxTime=86400000;
  Begin
  if Time2 >= Time1
  then Interval := Time2-Time1
  else Interval := Time2+MaxTime-Time1;
  End;

Begin
  TimeInRange:=Interval(Start,Stop)>=Interval(Start,isTime);
End;

Function TCabine.BasePhoneTariffFind;
Var I:Integer;
    Pref:Boolean;
    NowIs,Start,Finish:Integer;
Begin
  Result:=0;

  //����� ����
  If Dial=''
  Then Begin
       Zone:=0; City:='�������';
       End
  Else If Not FindZone(Dial,Zone,City) Then Exit;

  //�������� �� �������� �����
  Pref:=Option.Calendar.IndexOf(DateToStr(Now))>=0;

  //����� �������� �����������
  FTariffDelay:=3000;
  For i:=1 To zonZoneCount {Option.Tarif.Zone.Count}
  Do Begin
     If Option.Tarif.Zone[I].IsAttached Then
     If Option.Tarif.Zone[I].ZoneNo=Zone
     Then Begin
          FTariffDelay:=Option.Tarif.Zone[I].DelayTarif*1000;
          If Not Pref
          Then Begin //�������� �� �������� ����� �����������
               Start:=DateTimeToTimeStamp(Option.Tarif.Zone[I].StartTime).Time;
               Finish:=DateTimeToTimeStamp(Option.Tarif.Zone[I].FinishTime).Time;
               NowIs:=DateTimeToTimeStamp(Now).Time;
               Pref:= TimeInRange(NowIs,Start,Finish);
               End;
          Break;
          End;
     End;

  //!!!����� ������
  FindTariff(Zone,Result,Pref);
End;


Procedure TCabine.SetChanged;
Begin
  PostMessage({HWindow}HWND_BROADCAST,WM_StateChanged,Key,0);
//  ShowMessage(IntToStr(WM_StateChanged));
  SaveState;
End;

(*
Procedure TCabine.ShowTalks;
Begin
  Case State Of
   0,6,7,255:If Not TCabinesList(Owner).ShowArchiveCab(Number)
         Then InformMe('�� ������ '+IntToStr(Number)+' ���������� �� ����!');

   Else Begin
        TalksForm:=TTalksForm.Create(Application);
        TalksForm.Caption:='������ ���������� �� ������ '+IntToStr(Number);
        TalksForm.SetTalks(FTalks);
        TalksForm.ShowModal;
        TalksForm.Free;
        UpdateTalks;

      {  FValCost:=0;
        FNatCost:=0;
         if FTalks^.Fill > 0
         then for i:=0 to pred(FTalks^.Fill)
              do begin
                 FTalks^.GetOnePtr(p,n,i);
                 if TTalk(p^).FPrice <> 0
                 then begin
                      C:=TTalk(p^).FTariff * TTalk(p^).FInterval;
                      If C<0
                      Then FValCost:=FValCost+C
                      Else FNatCost:=FNatCost+C;
                      end;
                 end;

         Changed:=True;}
        End;
  End;
End;


Procedure TCabine.UpdateTalks;
Var I:Integer;
    PT:PTalk;
    N:Word;
Begin
  For I:=1 to FTalks^.Fill
  Do Begin
     FTalks^.GetOnePTR(Pointer(PT),N,Pred(i));
     If PT^.FPrice<0 Then PT^.FPrice:= abs(PT^.FPrice) * GetValCourse;
     TCabinesList(Owner).UpdateTalk(Number,PT^);
     End;
End;
*)


Procedure TCabine.SetCostAll;
Begin
  If Value=0
  Then Begin
       FNatCost:=0;
       FValCost:=0;
       End
  Else If Value<0
       Then FValCost:=Value
       Else FNatCost:=Value;
End;

Function TCabine.GetCostAll;
Begin
  Result:=Abs(FValCost)*GetValCourse+FNatCost;
{  Result:=0;
  For I:=0 To Pred(FTalks^.Fill)
  Do Begin
     FTalks^.GetOne(Talk,W,I);
     If Talk.FPrice<0
     Then Result:=Result + StrToFloat( Format('%f7.2',[(Abs(Talk.FPrice)*GetValCourse)]))
     Else Result:=Result + StrToFloat( Format('%f7.2',[Talk.FPrice]));
     End;}
End;

Function TCabine.GetTalkTariff;
Begin
  If FTalk.FTariff<0
  Then Result:=GetValCourse*Abs(FTalk.FTariff)
  Else Result:=FTalk.FTariff;
End;

(*
Function  TCabine.GetTalkTariffStr:String;
Begin
  If FTalk.FTariff = 0
  Then Result:=''
  Else Result:=Format('%7.2f',[TalkTariff]);
End;

Function  TCabine.GetTalkZoneStr:String;
Begin
  If FTalk.FTariff = 0
  Then Result:=''
  Else Result:=IntToStr(FTalk.FZone);
End;

Procedure TCabine.ManuallyOpen;
Begin
  AskSummForm:=TAskSummForm.Create(Application);
  AskSummForm.FAddAdvance:=False;
  AskSummForm.Caption:='������ '+IntToStr(Number);

  If AskSummForm.ShowModal=mrOk
  Then Open(StrToCurr(AskSummForm.Edit1.Text),F_Debug);
  AskSummForm.Free;

End;

Procedure TCabine.ManuallyAddAdvance;
Begin
  AskSummForm:=TAskSummForm.Create(Application);
  AskSummForm.FAddAdvance:=True;
  AskSummForm.Caption:='�������� ����� � ������ '+IntToStr(Number);
  AskSummForm.Edit1.Text:='0.00';

  If AskSummForm.ShowModal=mrOk
  Then AddAdvance(StrToCurr(AskSummForm.Edit1.Text));
  AskSummForm.Free;
End;

Procedure TCabine.MakeOperation;
Begin
  If System.Assigned(TCabinesList(Owner).OnOperation)
  Then TCabinesList(Owner).OnOperation(Self);

  case Operation Of
  coOpenAdd:Case State of
              0,6,7:manuallyOpen;
              255:Begin End;
              Else ManuallyAddAdvance;
            End;
  coClose:If Not (State in [0,6,7,255]) Then Close;

  coShowTalks:ShowTalks;
  End;

End;
*)

Procedure TCabine.SaveState;
Begin
{  FQuery.SQL.Clear;
  FQuery.SQL.Add(

   UPDATE CabState
   SET 78888
   WHERE Key = FKey


  INSERT INTO CabState
  WHERE (Exist(Select * FROM CabState WHERE Key = FKey) ) AND (Key = FKey)

 }
End;

end.
