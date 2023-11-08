unit XtReg ;

{ Secrets of Delphi 2, by Ray Lischner. (1996, Waite Group Press).
  Chapter 8: Registry Secrets
  Copyright © 1996 The Waite Group, Inc. }

{ Useful routines for saving configuration data to the
  Windows registry. }
  
interface

uses SysUtils, Classes, Registry;

procedure SaveToRegistry(Obj: TPersistent; Reg: TRegistry);
procedure SaveToKey(Obj: TPersistent; const KeyPath: string);
procedure LoadFromRegistry(Obj: TPersistent; Reg: TRegistry);
procedure LoadFromKey(Obj: TPersistent; const KeyPath: string);

implementation

uses TypInfo;

{ Define a set type for accessing an integer's bits. }
const
  BitsPerByte = 8;
type
  TIntegerSet = set of 0..SizeOf(Integer)*BitsPerByte - 1;



{ Save a set property as a subkey. Each element of the enumerated type
  is a separate Boolean value. True means the item is in the set, and
  False means the item is excluded from the set. This lets the user
  modify the configuration easily, with REGEDIT. }
procedure SaveSetToRegistry(const Name: string; Value: Integer;
   TypeInfo: PTypeInfo; Reg: TRegistry);
var
  OldKey: string;
  I: Integer;
begin
{$ifdef DELPHI2}
  TypeInfo := GetTypeData(TypeInfo)^.CompType;  //??
{$ELSE}
  TypeInfo := GetTypeData(TypeInfo)^.CompType^;  //??
{$ENDIF}
  OldKey := '\' + Reg.CurrentPath;
  if not Reg.OpenKey(Name, True) then
    raise ERegistryException.CreateFmt('Cannot create key: %s', [Name]);

  { Loop over all the items in the enumerated type. }
  with GetTypeData(TypeInfo)^ do
    for I := MinValue to MaxValue do
      { Write a Boolean value for each set element. }
      Reg.WriteBool(GetEnumName(TypeInfo, I), I in TIntegerSet(Value));

  { Return to the parent key. }
  Reg.OpenKey(OldKey, False);
end;

{ Save an object to the registry by saving it as a subkey. }
procedure SaveObjToRegistry(const Name: string; Obj: TPersistent;
   Reg: TRegistry);
var
  OldKey: string;
begin
  OldKey := '\' + Reg.CurrentPath;
  { Open a subkey for the object. }
  if not Reg.OpenKey(Name, True) then
    raise ERegistryException.CreateFmt('Cannot create key: %s', [Name]);

  { Save the object's properties. }
  SaveToRegistry(Obj, Reg);

  { Return to the parent key. }
  Reg.OpenKey(OldKey, False);
end;

{ Save a method to the registry by saving its name. }
procedure SaveMethodToRegistry(const Name: string; const Method: TMethod;
   Reg: TRegistry);
var
  MethodName: string;
begin
  { If the method pointer is nil, then store an empty string. }
  if Method.Code = nil then
    MethodName := ''
  else
    { Look up the method name. }
    MethodName := TObject(Method.Data).MethodName(Method.Code);
  Reg.WriteString(Name, MethodName);
end;

{ Save a single property to the registry, as a value of the current key. }
procedure SavePropToRegistry(Obj: TPersistent; PropInfo: PPropInfo; Reg: TRegistry);
begin
  with PropInfo^ do
//{$IFDEF DELPHI2}
    case PropType^.Kind of
//{$ELSE}
//    case PropType^^.Kind of
//{$ENDIF}
    tkInteger,
    tkChar,
    tkWChar:
      { Store ordinal properties as integer. }
      Reg.WriteInteger(Name, GetOrdProp(Obj, PropInfo));
    tkEnumeration:
      { Store enumerated values by name. }
{$IFDEF DELPHI2}
      Reg.WriteString(Name, GetEnumName(PropType, GetOrdProp(Obj, PropInfo)));
{$ELSE}
      Reg.WriteString(Name, GetEnumName(PropType^, GetOrdProp(Obj, PropInfo)));
{$ENDIF}
    tkFloat:
      { Store floating point values as Doubles. }
      Reg.WriteFloat(Name, GetFloatProp(Obj, PropInfo));
    tkString,
    tkLString,
{$IFDEF DELPHI2}
    tkLWString:
{$ELSE}
    tkWString:
{$ENDIF}
      { Store strings as strings. }
      Reg.WriteString(Name, GetStrProp(Obj, PropInfo));
    tkVariant:
      { Store variant values as strings. }
      Reg.WriteString(Name, GetVariantProp(Obj, PropInfo));      
    tkSet:
      { Store a set as a subkey. }
{$IFDEF DELPHI2}
      SaveSetToRegistry(Name, GetOrdProp(Obj, PropInfo), PropType, Reg);
{$ELSE}
      SaveSetToRegistry(Name, GetOrdProp(Obj, PropInfo), PropType^, Reg);
{$ENDIF}
    tkClass:
      { Store a class as a subkey, with its properties as values
        of the subkey. }
      SaveObjToRegistry(Name, TPersistent(GetOrdProp(Obj, PropInfo)), Reg);
    tkMethod:
      { Save a method by name. }
      SaveMethodToRegistry(Name, GetMethodProp(Obj, PropInfo), Reg);
    end;
end;

{ Save an object to the registry by storing its published properties. }
procedure SaveToRegistry(Obj: TPersistent; Reg: TRegistry);
var
  PropList: PPropList;
  PropCount: Integer;
  I: Integer;
begin
  { Get the list of published properties. }
  PropCount := GetTypeData(Obj.ClassInfo)^.PropCount;
  GetMem(PropList, PropCount*SizeOf(PPropInfo));
  try
    GetPropInfos(Obj.ClassInfo, PropList);
    { Store each property as a value of the current key. }
    for I := 0 to PropCount-1 do
      SavePropToRegistry(Obj, PropList^[I], Reg);
  finally
    FreeMem(PropList, PropCount*SizeOf(PPropInfo));
  end;
end;

{ Save the published properties as values of the given key.
  The key is relative to HKEY_CURRENT_USER. }
procedure SaveToKey(Obj: TPersistent; const KeyPath: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    if not Reg.OpenKey(KeyPath, True) then
      raise ERegistryException.CreateFmt('Cannot create key: %s', [KeyPath]);
    SaveToRegistry(Obj, Reg);
  finally
    Reg.Free;
  end;
end;

{ Load a set property as a subkey. Each element of the enumerated type
  is a separate Boolean value. True means the item is in the set, and
  False means the item is excluded from the set. This lets the user
  modify the configuration easily, with the Windows registry editor. }
function LoadSetFromRegistry(const Name: string; TypeInfo: PTypeInfo;
    Reg: TRegistry): Integer;
var
  OldKey: string;
  ResultSet: TIntegerSet;
  I: Integer;
begin
  { Get the enumerated base type. }
{$IFDEF DELPHI2}
  TypeInfo := GetTypeData(TypeInfo)^.CompType;
{$ELSE}
  TypeInfo := GetTypeData(TypeInfo)^.CompType^;
{$ENDIF}
  OldKey := '\' + Reg.CurrentPath;
  { The caller ensures that the key exists. }
  Reg.OpenKey(Name, False);

  { Start with an empty set, and include only True items. }
  ResultSet := [];
  with GetTypeData(TypeInfo)^ do
    for I := MinValue to MaxValue do
      { Ignore values that are not in the enumerated type. }
      if Reg.ValueExists(GetEnumName(TypeInfo, I)) and
         Reg.ReadBool(GetEnumName(TypeInfo, I))
      then
        Include(ResultSet, I);

  Reg.OpenKey(OldKey, False);
  Result := Integer(ResultSet);
end;

{ Load an object from its subkey. }
procedure LoadObjFromRegistry(const Name: string; Obj: TPersistent;
   Reg: TRegistry);
var
  OldKey: string;
begin
  OldKey := '\' + Reg.CurrentPath;
  if Reg.OpenKey(Name, False) then
  begin
    LoadFromRegistry(Obj, Reg);
    { Return to the parent key. }
    Reg.OpenKey(OldKey, False);
  end;
end;

{ Load a method from the registry by looking up its name. }
procedure LoadMethodFromRegistry(const Name: string; Obj: TObject;
   PropInfo: PPropInfo; Reg: TRegistry);
var
  Method: TMethod;
  MethodName: string;
begin
  if Reg.ValueExists(Name) then
  begin
    Method := GetMethodProp(Obj, PropInfo);
    MethodName := Reg.ReadString(Name);
    if MethodName = '' then
      Method.Code := nil
    else
      { Look up the method name. }
      Method.Code := TObject(Method.Data).MethodAddress(MethodName);
    SetMethodProp(Obj, PropInfo, Method);
  end;
end;

{ Load a single property from the registry, as a value of the current key.
  If the value does not exist, then do nothing. }
procedure LoadPropFromRegistry(Obj: TPersistent; PropInfo: PPropInfo; Reg: TRegistry);
begin
  with PropInfo^ do
    case PropType^.Kind of
    tkInteger,
    tkChar,
    tkWChar:
      if Reg.ValueExists(Name) then
        SetOrdProp(Obj, PropInfo, Reg.ReadInteger(Name));
    tkEnumeration:
      { Enumerated values are stored by name. }
      if Reg.ValueExists(Name) then
        SetOrdProp(Obj, PropInfo,
{$IFDEF DELPHI2}
          GetEnumValue(PropType, Reg.ReadString(Name)));
{$ELSE}
          GetEnumValue(PropType^, Reg.ReadString(Name)));
{$ENDIF}
    tkFloat:
      if Reg.ValueExists(Name) then
        SetFloatProp(Obj, PropInfo, Reg.ReadFloat(Name));
    tkString,
    tkLString,
{$IFDEF DELPHI2}
    tkLWString:
{$ELSE}
    tkWString:
{$ENDIF}
      if Reg.ValueExists(Name) then
        SetStrProp(Obj, PropInfo, Reg.ReadString(Name));
    tkVariant:
      { Variants are stored in their string representations. }
      if Reg.ValueExists(Name) then
        SetVariantProp(Obj, PropInfo, Reg.ReadString(Name));      
    tkSet:
      { A set is stored as a subkey, where set elements are values of
        the subkey. If the subkey does not exist, then skip the
        set property. }
      if Reg.KeyExists(Name) then
{$IFDEF DELPHI2}
        SetOrdProp(Obj, PropInfo, LoadSetFromRegistry(Name, PropType, Reg));
{$ELSE}
        SetOrdProp(Obj, PropInfo, LoadSetFromRegistry(Name, PropType^, Reg));
{$ENDIF}
    tkClass:
      LoadObjFromRegistry(Name, TPersistent(GetOrdProp(Obj, PropInfo)), Reg);
    tkMethod:
      LoadMethodFromRegistry(Name, Obj, PropInfo, Reg);
    end;
end;

{ Load property values from the registry. }
procedure LoadFromRegistry(Obj: TPersistent; Reg: TRegistry);
var
  PropList: PPropList;
  PropCount: Integer;
  I: Integer;
begin
  { Get the list of published properties. }
  PropCount := GetTypeData(Obj.ClassInfo)^.PropCount;
  GetMem(PropList, PropCount*SizeOf(PPropInfo));
  try
    GetPropInfos(Obj.ClassInfo, PropList);
    { Load each property as a value of the current key. }
    for I := 0 to PropCount-1 do
      LoadPropFromRegistry(Obj, PropList^[I], Reg);
  finally
    FreeMem(PropList, PropCount*SizeOf(PPropInfo));
  end;
end;

{ Load the published properties as values of the given key.
  The key is relative to HKEY_CURRENT_USER. }
procedure LoadFromKey(Obj: TPersistent; const KeyPath: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    if Reg.OpenKey(KeyPath, False) then
      LoadFromRegistry(Obj, Reg);
  finally
    Reg.Free;
  end;
end;

end.
