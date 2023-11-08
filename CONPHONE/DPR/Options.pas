unit Options ;


interface


uses
    Classes ;
//    Globals ;


Const zonZoneCount  = 20;
      cabCabinCount = 16;

type
    TZone = class (TPersistent)
    private
       { System }
       FIndx : string ;

       FIsAttached : boolean ;

       FZoneNo : integer ;
       FTarifRange : integer ;
       FDelayTarif : integer ;
       FPayment : integer ;

       FStartTime : TDateTime ;
       FFinishTime : TDateTime ;
    protected
       procedure SetIsAttached (Value : boolean) ;
    public
       constructor Create (Indx : integer) ;
       procedure Clear ; virtual ;
       procedure Load ;
       procedure Save ;
       procedure Assign (Source : TPersistent) ; override ;
    published
       { Published declaration }
       property IsAttached : boolean read FIsAttached write SetIsAttached default false ;

       property ZoneNo : integer read FZoneNo write FZoneNo default 0 ;
       property TarifRange : integer read FTarifRange write FTarifRange default 60 ;
       property DelayTarif : integer read FDelayTarif write FDelayTarif default 3 ;
       property Payment : integer read FPayment write FPayment default 0 ;

       property StartTime : TDateTime read FStartTime write FStartTime ;
       property FinishTime : TDateTime read FFinishTime write FFinishTime ;
    end ;   { TZone }


    TAttach = class (TPersistent)
    private
       { System }
       FIndx : string ;

       { Telephone set }
       FCurrentDriver : string ;
       FIsManualSetup : boolean ;

       { Cabine }
       FIsAttached : boolean ;
       FCabineNo : byte ;
       FWaitAnsver : byte ;
       FStartStock : byte ;
       FEndStock : byte ;
       FRequest8 : boolean ;

       procedure SetIsAttached (Value : boolean) ;
    protected
       procedure Save ;
       procedure Load ;
       procedure ResetAttach ;
    public
       constructor Create (Indx : byte) ;
       destructor Destroy ; override ;
       procedure Assign (Source : TPersistent) ; override ;
       function Delete (const Key : string) : boolean ;
    published
       { Published declaration }
       { Telephone set }
       property CurrentDriver : string read FCurrentDriver write FCurrentDriver ;
       property IsManualSetup : boolean read FIsManualSetup write FIsManualSetup default false ;

       { Cabine }
       property IsAttached : boolean read FIsAttached write SetIsAttached default false ;
       property CabineNo : byte read FCabineNo write FCabineNo default 1 ;
       property WaitAnsver : byte read FWaitAnsver write FWaitAnsver default 90 ;
       property StartStock : byte read FStartStock write FStartStock default 0 ;
       property EndStock : byte read FEndStock write FEndStock default 0 ;
       property Request8 : boolean read FRequest8 write FRequest8 default true ;
    end ;   { TAttach }


    TTarif = class (TPersistent)
    private
       { System }
       FKey : string ;

       { Other }
       FAvansCheck : boolean ;
       FCheckString : string ;
       { Zone }
       FZone : array [1..zonZoneCount] of TZone ;
    protected
       procedure Save ;
       procedure Load ;

       function GetZone (Index : byte) : TZone ;
       procedure SetZone (Index : byte; Value : TZone) ;
    public
       constructor Create (const Key : string) ;
       destructor Destroy ; override ;
       function Delete (const DelKey : string) : boolean ;
       procedure Assign (Source : TPersistent) ; override ;

       property Key : string read FKey ;
       property Zone [Index : byte] : TZone read GetZone write SetZone ;
    published
       { Published declaration }
       property AvansCheck : boolean read FAvansCheck write FAvansCheck default false ;
       property CheckString : string read FCheckString write FCheckString ;
    end ;   { TTarif }


    TOption = class (TPersistent)
    private
       { System }
       FKey : string ;
       { Controllers }
       FControllerList : TStringList ;
       FControllerLib : TStringList ;
       FCurrentControl : string ;
       { Phones }
       FPhoneList : TStringList ;
       FPhoneLib : TStringList ;
       { Attach points }
       FAttach : array [1..cabCabinCount] of TAttach ;
       { Tarifs }
       FTarif : TTarif ;
       { Calendar }
       FCalendar : TStringList ;
       FDaysCount : integer ;
    protected
       function GetAttach (Index : byte) : TAttach ;
       procedure SetAttach (Index : byte; Value : TAttach) ;
    public
       constructor Create (const Key : string) ;
       destructor Destroy ; override ;
       procedure Load ;
       procedure Save ;
       function Delete (const DelKey : string) : boolean ;
       procedure Assign (Source : TPersistent) ; override ;

       property Key : string read FKey ;
       { Controllers }
       property ControllerList : TStringList read FControllerList write FControllerList ;
       property ControllerLib : TStringList read FControllerLib write FControllerLib ;

       { Phones }
       property PhoneList : TStringList read FPhoneList write FPhoneList ;
       property PhoneLib : TStringList read FPhoneLib write FPhoneLib ;
       { Attach points }
       property Attach [Index : byte] : TAttach read GetAttach write SetAttach ;
       { Calendar }
       property Calendar : TStringList read FCalendar write FCalendar ;
    published
       { Published declaration }
       property CurrentControl : string read FCurrentControl write FCurrentControl ;
       { Tarifs }
       property Tarif : TTarif read FTarif write FTarif ;
       { Calendar }
       property DaysCount : integer read FDaysCount write FDaysCount default 0 ;
    end ;   { TOption }


    { OPTIONS }
var
   Option : TOption ;

const
     KeyPath = '\Software\Orca\Sprut' ;


implementation


uses
    XtReg    ,
    Registry ,
    SysUtils ;

constructor TOption.Create (const Key : string) ;
var
   i : byte ;
begin
     inherited Create ;
     FKey := Key ;

     FControllerList := TStringList.Create ;
     FControllerLib := TStringList.Create ;

     FPhoneList := TStringList.Create ;
     FPhoneLib := TStringList.Create ;

     FCurrentControl := '' ;

     for i := 1 to cabCabinCount do
         FAttach [i] := TAttach.Create (i) ;
     FTarif := TTarif.Create (FKey) ;
     FCalendar := TStringList.Create ;
     FDaysCount := 0 ;
end ;   { Create }


destructor TOption.Destroy ;
var
   i : byte ;
begin
     FCalendar.Free ;
     FTarif.Free ;
     for i := cabCabinCount downto 1 do
         FAttach [i].Free ;

     FControllerList.Free ;
     FControllerLib.Free ;

     FPhoneList.Free ;
     FPhoneLib.Free ;

     inherited Destroy ;
end ;   { Destroy }


function TOption.Delete (const DelKey : string) : boolean ;
var
   Reg : TRegistry ;
begin
     Reg := TRegistry.Create ;
     Result := Reg.DeleteKey (DelKey) ;
     Reg.Free ;
end ;   { Delete }


procedure TOption.Assign (Source : TPersistent) ;
var
   i : integer ;
begin
     if Source is TOption then
     begin
          FKey := TOption (Source).Key ;

          FCurrentControl := TOption (Source).CurrentControl ;

          FControllerList.Assign (TOption (Source).ControllerList) ;
          FControllerLib.Assign (TOption (Source).ControllerLib) ;

          FPhoneList.Assign (TOption (Source).PhoneList) ;
          FPhoneLib.Assign (TOption (Source).PhoneLib) ;

          for i := 1 to cabCabinCount do
              FAttach [i].Assign (TOption (Source).FAttach [i]) ;
          FTarif.Assign (TOption (Source).FTarif) ;
          FCalendar.Assign (TOption (Source).Calendar) ;
          FDaysCount := TOption (Source).DaysCount ;
     end ;   { if Source is TOption then }
end ;   { Assign }


procedure TOption.Load ;
var
   i : integer ;
   Reg : TRegistry ;
begin
     LoadFromKey (Self, FKey) ;
     for i := 1 to cabCabinCount do
         FAttach [i].Load ;
     FTarif.Load ;

     FCalendar.Clear ;
     Reg := TRegistry.Create ;
     for i := 0 to FDaysCount - 1 do
     begin
          if Reg.OpenKey (FKey + '\Calendar', false) then
             FCalendar.Add (Reg.ReadString ('Day' + IntToStr (i))) ;
          Reg.CloseKey ;
     end ;   { for i := 0 to FDaysCount - 1 do }
     Reg.Free ;
end ;   { Load }


procedure TOption.Save ;
var
   i : integer ;
   Reg : TRegistry ;
begin
     FDaysCount := FCalendar.Count ;
     SaveToKey (Self, FKey) ;
     for i := 1 to cabCabinCount do
         FAttach [i].Save ;
     FTarif.Save ;

     Delete (FKey + '\Calendar') ;
     Reg := TRegistry.Create ;
     for i := 0 to FDaysCount - 1 do
     begin
          if Reg.OpenKey (FKey + '\Calendar', true) then
             Reg.WriteString ('Day' + IntToStr (i), FCalendar [i]) ;
          Reg.CloseKey ;
     end ;   { for i := 0 to FDaysCount - 1 do }
     Reg.Free ;
end ;   { Save }


function TOption.GetAttach (Index : byte) : TAttach ;
begin
     Result := FAttach [Index] ;
end ;   { GetAttach }


procedure TOption.SetAttach (Index : byte; Value : TAttach) ;
begin
     if Value <> FAttach [Index] then
        FAttach [Index] := Value ;
end ;   { SetAttach }


{ *************** Attach point *************** }

constructor TAttach.Create (Indx : byte) ;
begin
     inherited Create ;
     FIndx := IntToStr (Indx) ;

     ResetAttach ;
end ;   { Create }


destructor TAttach.Destroy ;
begin
     { Attach points }
     inherited Destroy ;
end ;   { Destroy }


function TAttach.Delete (const Key : string) : boolean ;
var
   Reg : TRegistry ;
begin
     Result := false ;
     Reg := TRegistry.Create ;
     if Reg.DeleteKey (Key) then
        Result := true ;
     Reg.Free ;
end ;   { Delete }


procedure TAttach.Assign (Source : TPersistent) ;
begin
     if Source is TAttach then
     begin
          FCurrentDriver := TAttach (Source).CurrentDriver ;
          FIsManualSetup := TAttach (Source).IsManualSetup ;

          { Cabine }
          FIsAttached := TAttach (Source).IsAttached ;
          FCabineNo := TAttach (Source).CabineNo ;
          FWaitAnsver := TAttach (Source).WaitAnsver ;
          FStartStock := TAttach (Source).StartStock ;
          FEndStock := TAttach (Source).EndStock ;
          FRequest8 := TAttach (Source).Request8 ;
     end ;   { if Source is TAttach then }
end ;   { Assign }


procedure TAttach.ResetAttach ;
begin
     { Telephone set }
     FCurrentDriver := '' ;
     FIsManualSetup := false ;

     { Cabine }
     FIsAttached := false ;
     FCabineNo := 1 ;
     FWaitAnsver := 90 ;
     FStartStock := 0 ;
     FEndStock := 0 ;
     FRequest8 := true ;
end ;   { ResetAttach }


procedure TAttach.SetIsAttached (Value : boolean) ;
begin
     if FIsAttached <> Value then
     begin
          FIsAttached := Value ;
          if not FIsAttached then
             ResetAttach ;
     end ;   { if FIsAttached <> Value then }
end ;   { SetIsAttached }


procedure TAttach.Load ;
begin
     LoadFromKey (Self, KeyPath + '\Phone\Attach' + FIndx) ;
end ;   { Load }


procedure TAttach.Save ;
begin
     SaveToKey (Self, KeyPath + '\Phone\Attach' + FIndx) ;
end ;   { Save }


{ *************** Tarif *************** }

constructor TTarif.Create (const Key : string) ;
var
   i : integer ;
begin
     inherited Create ;
     FKey := Key ;

     FAvansCheck := false ;
     FCheckString := '' ;

     { Zone }
     for i := 1 to zonZoneCount do
         FZone [i] := TZone.Create (i) ;
end ;   { Create }


destructor TTarif.Destroy ;
var
   i : integer ;
begin
     { Zone }
     for i := zonZoneCount downto 1 do
         FZone [i].Free ;

     inherited Destroy ;
end ;   { Create }


procedure TTarif.Assign (Source : TPersistent) ;
var
   i : integer ;
begin
     if Source is TTarif then
     begin
          FAvansCheck := TTarif (Source).AvansCheck ;
          FCheckString := TTarif (Source).CheckString ;
          for i := 1 to zonZoneCount do
              FZone [i].Assign (TTarif (Source).FZone [i]) ;
     end ;   { if Source is TTarif then }
end ;   { Assign }


function TTarif.Delete (const DelKey : string) : boolean ;
var
   Reg : TRegistry ;
begin
     Reg := TRegistry.Create ;
     Result := Reg.DeleteKey (DelKey) ;
     Reg.Free ;
end ;   { Delete }


procedure TTarif.Save ;
var
   i : integer ;
begin
     for i := 1 to zonZoneCount do
         FZone [i].Save ;
end ;   { Save }


procedure TTarif.Load ;
var
   i : integer ;
begin
     for i := 1 to zonZoneCount do
         FZone [i].Load ;
end ;   { Load }


function TTarif.GetZone (Index : byte) : TZone ;
begin
     Result := FZone [Index] ;
end ;   { GetZone }


procedure TTarif.SetZone (Index : byte; Value : TZone) ;
begin
     if Value <> FZone [Index] then
        FZone [Index] := Value ;
end ;   { GetZone }


{ *************** Zone options **************** }

constructor TZone.Create (Indx : integer) ;
begin
     inherited Create ;

     FIndx := IntToStr (Indx) ;

     Clear ;
end ;   { Create }


procedure TZone.Clear ;
begin
     FZoneNo := 0 ;
     FTarifRange := 60 ;
     FDelayTarif := 3 ;
     FPayment := 0 ;

     FStartTime := 0 ;
     FFinishTime := 0 ;
end ;   { Clear }


procedure TZone.Assign (Source : TPersistent) ;
begin
     if Source is TZone then
     begin
          FIsAttached := TZone (Source).IsAttached ;

          FZoneNo := TZone (Source).ZoneNo ;
          FTarifRange := TZone (Source).TarifRange ;
          FDelayTarif := TZone (Source).DelayTarif ;
          FPayment := TZone (Source).Payment ;

          FStartTime := TZone (Source).StartTime ;
          FFinishTime := TZone (Source).FinishTime ;
     end ;   { if Source is TZone then }
end ;   { Assign }


procedure TZone.Load ;
begin
     LoadFromKey (Self, KeyPath + '\Tarif\Zone' + FIndx) ;
end ;   { Load }


procedure TZone.Save ;
begin
     SaveToKey (Self, KeyPath + '\Tarif\Zone' + FIndx) ;
end ;   { Save }


procedure TZone.SetIsAttached (Value : boolean) ;
begin
     if FIsAttached <> Value then
     begin
          FIsAttached := Value ;
          if not FIsAttached then
             Clear ;
     end ;   { if FIsAttached <> Value then }
end ;   { SetIsAttached }


initialization
   Option := TOption.Create (KeyPath) ;
   Option.Load ;

finalization
   Option.Free ;

end .
