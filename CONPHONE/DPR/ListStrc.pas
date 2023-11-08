{$G+,R-,S-,B-,I-}
{                  Copyright  (C)  SuperSoft   1993,1995                     }

Unit ListStrc;

Interface

Const
    {Минимальная память для ограничения загрузки списка}
    ListMemoryLimit : longint = 16;

Type
    {}
    PListOne = ^TListOne;
    TListOne = record
      Owner  : pointer;
      Size   : word;
      Next   : PListOne;
      end;

    { Список структур }
    PList = ^TList;
    TList = object
      Top         : PListOne;
      Fill        : word;
      constructor Init;
      destructor  Done; virtual;
      procedure   InsertOne(var V; Size : word; Place : word); virtual;
      procedure   DeleteOne(Place : word); virtual;
      procedure   LocateOne(Size : word; Place : word); virtual;
      procedure   PutOne(var V; Place : word); virtual;
      procedure   ChangeOne(var V; Size : word; Place : word); virtual;
      procedure   GetOne(var V; var Size : word; Place : word); virtual;
      procedure   ExchangeOne(Place1 , Place2 : word); virtual;
      procedure   DeleteAll; virtual;
      procedure   LoadList; virtual;
      procedure   Draw; virtual;
      procedure   GetOnePtr(var VPtr : pointer;var Size : word;Place : word);
      procedure   SetSizeOne(Size : word; Place : word);
      function    SizeOne(Place : word) : word;
      function    SizeList : word;
      private
      function    SearchNextPtr(Place : word) : pointer;
      end;

Var
    { Результат операции над списком:
      =  0 - норма
      = -1 - нет свободной памяти
      = -2 - выход за пределы списка
      = -3 - выход за пределы элемента списка
    }
    ListResult : integer;

Implementation

{==========================================================================}

{ TList}

constructor TList.Init;
begin
ListResult:=0; Top:=nil; Fill:=0;
LoadList;
end;

destructor TList.Done;
begin
DeleteAll;
{Inherited Done;}
end;

procedure TList.InsertOne(var V; Size : word; Place : word);
var P , P1 : pointer;
begin
{if MaxAvail < (Size + ListMemoryLimit) then ListResult:=-1
else}
  begin
  ListResult:=0;
  P:=SearchNextPtr(Place); P1:=Pointer(P^);
  new(PListOne(P^)); P:=Pointer(P^);
  GetMem(PListOne(P)^.Owner,Size);
  Move(V,PListOne(P)^.Owner^,Size);
  PListOne(P)^.Size:=Size; PListOne(P)^.Next:=P1;
  Inc(Fill);
  Draw;
  end;
end;

procedure TList.DeleteOne(Place : word);
var P , P1 : pointer;
begin
ListResult:=-2;
if Fill > 0 then
  begin
  P:=SearchNextPtr(Place); P1:=Pointer(P^);
  if P1 <> nil then
    begin
    PListOne(P^):=PListOne(P^)^.Next;
    FreeMem(PListOne(P1)^.Owner,PListOne(P1)^.Size);
    Dispose(PListOne(P1)); Dec(Fill); Draw; ListResult:=0;
    end;
  end;
end;

procedure TList.LocateOne(Size : word; Place : word);
var P , P1 : pointer;
begin
{if MaxAvail < (Size + ListMemoryLimit) then ListResult:=-1
else}
  begin
  ListResult:=0;
  P:=SearchNextPtr(Place); P1:=Pointer(P^);
  new(PListOne(P^)); P:=Pointer(P^);
  GetMem(PListOne(P)^.Owner,Size);
  PListOne(P)^.Size:=Size; PListOne(P)^.Next:=P1;
  Inc(Fill);
  end;
end;

procedure TList.PutOne(var V; Place : word);
var P : pointer;
begin
P:=Pointer(SearchNextPtr(Place)^);
if P <> nil then
  begin
  ListResult:=0; Move(V,PListOne(P)^.Owner^,PListOne(P)^.Size); Draw;
  end
else ListResult:=-2;
end;

procedure TList.ChangeOne(var V; Size : word; Place : word);
var P , P1 : pointer; s : word;
begin
{if MaxAvail < (Size + ListMemoryLimit) then ListResult:=-1
else}
  begin
  ListResult:=0;
  P:=Pointer(SearchNextPtr(Place)^);
  if P = Nil then
    begin
    ListResult:=-2; Exit;
    end;
  P1:=PListOne(P)^.Owner; s:=PListOne(P)^.Size;
  GetMem(PListOne(P)^.Owner,Size); Move(V,PListOne(P)^.Owner^,Size);
  PListOne(P)^.Size:=Size;
  FreeMem(P1,s);
  Draw;
  end;
end;

procedure TList.GetOne(var V; var Size : word; Place : word);
var P : pointer;
begin
P:=Pointer(SearchNextPtr(Place)^);
if P <> nil then
  begin
  ListResult:=0; Size:=PListOne(P)^.Size; Move(PListOne(P)^.Owner^,V,Size);
  end
else ListResult:=-2;
end;

procedure TList.GetOnePtr(var VPtr : pointer;var Size : word;Place : word);
var P : pointer;
begin
P:=Pointer(SearchNextPtr(Place)^);
if P <> nil then
  begin
  ListResult:=0; VPtr:=PListOne(P)^.Owner; Size:=PListOne(P)^.Size;
  end
else
  begin
  ListResult:=-2; VPtr:=nil; Size:=0;
  end
end;

procedure TList.SetSizeOne(Size : word; Place : word);
var P : pointer;
begin
ListResult:=0; P:=Pointer(SearchNextPtr(Place)^);
if P <> nil then
  if Size <= PListOne(P)^.Size then
    PListOne(P)^.Size:=Size
  else ListResult:=-3
else ListResult:=-2;
end;

function TList.SizeOne(Place : word) : word;
var P : pointer;
begin
P:=Pointer(SearchNextPtr(Place)^);
if P <> nil then
  begin
  ListResult:=0; SizeOne:=PListOne(P)^.Size;
  end
else
  begin
  ListResult:=-2; SizeOne:=0;
  end;
end;

procedure TList.ExchangeOne(Place1 , Place2 : word);
var P , P1 , P2 , P1n , P2n : pointer;
begin
P1:=SearchNextPtr(Place1); P2:=SearchNextPtr(Place2);
P1n:=@PListOne(P1^)^.Next; P2n:=@PListOne(P2^)^.Next;
P:=Pointer(P1^); PListOne(P1^):=PListOne(P2^); PListOne(P2^):=PListOne(P);
P:=Pointer(P1n^); PListOne(P1n^):=PListOne(P2n^); PListOne(P2n^):=PListOne(P);
ListResult:=0; Draw;
end;

procedure TList.DeleteAll;
var P , P1 : pointer;
begin
if Fill > 0 then
  begin
  P:=Pointer(Top);
  while P <> nil do
    begin
    P1:=P; P:=Pointer(PListOne(P)^.Next);
    FreeMem(PListOne(P1)^.Owner,PListOne(P1)^.Size);
    Dispose(PListOne(P1));
    end;
  Top:=nil; Fill:=0; Draw;
  end;
end;

procedure TList.LoadList;
begin
end;

procedure TList.Draw;
begin
end;

function TList.SizeList : word;
begin
SizeList:=Fill;
end;

function TList.SearchNextPtr(Place : word) : pointer;
var P : pointer; Count : word;
begin
P:=@Top; Count:=0;
while (Pointer(P^) <> nil) and (Count < Place) do
  begin
  inc(Count); P:=@PListOne(P^)^.Next;
  end;
SearchNextPtr:=P;
end;

End.
