object fmTest: TfmTest
  Left = 190
  Top = 107
  Width = 503
  Height = 419
  Caption = 'Test AUPPIP1.VxD'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object bnLoadVxD: TButton
    Left = 408
    Top = 8
    Width = 75
    Height = 25
    Caption = 'LoadVxD'
    TabOrder = 0
    OnClick = bnLoadVxDClick
  end
  object Memo: TMemo
    Left = 8
    Top = 48
    Width = 385
    Height = 329
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object bnCloseVxD: TButton
    Left = 408
    Top = 48
    Width = 75
    Height = 25
    Caption = 'CloseVxD'
    TabOrder = 2
    OnClick = bnCloseVxDClick
  end
  object bnLine: TButton
    Left = 408
    Top = 88
    Width = 75
    Height = 25
    Caption = 'Line On'
    TabOrder = 3
    OnClick = bnLineClick
  end
  object edNumber: TEdit
    Left = 8
    Top = 8
    Width = 385
    Height = 21
    TabOrder = 4
  end
end
