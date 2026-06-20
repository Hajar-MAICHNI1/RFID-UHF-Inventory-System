object fmMain: TfmMain
  Left = 0
  Top = 0
  Caption = 'Demo'
  ClientHeight = 667
  ClientWidth = 1077
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  DesignSize = (
    1077
    667)
  PixelsPerInch = 96
  TextHeight = 12
  object Label5: TLabel
    Left = 300
    Top = 62
    Width = 54
    Height = 12
    Caption = 'WorkMode:'
  end
  object Label6: TLabel
    Left = 276
    Top = 21
    Width = 78
    Height = 12
    Caption = 'RfPower(dbm):'
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 244
    Height = 123
    Caption = 'Serial Connect'
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 27
      Width = 30
      Height = 12
      Caption = 'Port:'
    end
    object Label2: TLabel
      Left = 16
      Top = 59
      Width = 30
      Height = 12
      Caption = 'Baud:'
    end
    object cmbComportList: TComboBox
      Left = 64
      Top = 24
      Width = 169
      Height = 20
      Style = csDropDownList
      TabOrder = 0
      Items.Strings = (
        'COM1'
        'COM2'
        'COM3'
        'COM4'
        'COM5'
        'COM6')
    end
    object cmbBaudList: TComboBox
      Left = 64
      Top = 56
      Width = 169
      Height = 20
      Style = csDropDownList
      TabOrder = 1
      Items.Strings = (
        '9600'
        '19200'
        '38400'
        '57600'
        '115200')
    end
    object Button1: TButton
      Left = 16
      Top = 82
      Width = 97
      Height = 33
      Action = actSportOpen
      TabOrder = 2
    end
    object Button2: TButton
      Left = 136
      Top = 82
      Width = 97
      Height = 33
      Action = actSportClose
      TabOrder = 3
    end
  end
  object GroupBox3: TGroupBox
    Left = 276
    Top = 91
    Width = 485
    Height = 102
    TabOrder = 1
    object Label7: TLabel
      Left = 16
      Top = 23
      Width = 66
      Height = 12
      Caption = 'Freq Band'#65306
    end
    object Label8: TLabel
      Left = 10
      Top = 68
      Width = 72
      Height = 12
      Caption = 'Freq Start'#65306
    end
    object Label9: TLabel
      Left = 263
      Top = 68
      Width = 30
      Height = 12
      Caption = 'End'#65306
    end
    object cmbRegion: TComboBox
      Left = 88
      Top = 19
      Width = 133
      Height = 20
      Style = csDropDownList
      DropDownCount = 30
      TabOrder = 0
      OnChange = cmbRegionChange
      Items.Strings = (
        'Custom'
        'USA'
        'Korea'
        'Europe'
        'Japan'
        'Malaysia'
        'Europe3'
        'China_1'
        'China_2')
    end
    object Button11: TButton
      Left = 371
      Top = 13
      Width = 97
      Height = 33
      Action = actSetFreq
      TabOrder = 1
    end
    object Button12: TButton
      Left = 263
      Top = 13
      Width = 97
      Height = 33
      Action = actGetFreq
      TabOrder = 2
    end
    object cmbFreqStart: TComboBox
      Left = 88
      Top = 64
      Width = 133
      Height = 20
      Style = csDropDownList
      DropDownCount = 30
      TabOrder = 3
    end
    object cmbFreqEnd: TComboBox
      Left = 307
      Top = 64
      Width = 133
      Height = 20
      Style = csDropDownList
      DropDownCount = 30
      TabOrder = 4
    end
  end
  object GroupBox2: TGroupBox
    Left = 8
    Top = 137
    Width = 244
    Height = 123
    Caption = 'Net Connect'
    TabOrder = 2
    object Label3: TLabel
      Left = 16
      Top = 26
      Width = 48
      Height = 12
      Caption = 'IP Addr:'
    end
    object Label4: TLabel
      Left = 16
      Top = 58
      Width = 30
      Height = 12
      Caption = 'Port:'
    end
    object Button3: TButton
      Left = 16
      Top = 80
      Width = 97
      Height = 33
      Action = actNetConnect
      TabOrder = 0
    end
    object Button4: TButton
      Left = 136
      Top = 80
      Width = 97
      Height = 33
      Action = actNetDiscount
      TabOrder = 1
    end
    object txbIPAddr: TEdit
      Left = 68
      Top = 22
      Width = 160
      Height = 20
      TabOrder = 2
      Text = '192.168.1.120'
    end
    object txbPort: TEdit
      Left = 68
      Top = 54
      Width = 160
      Height = 20
      TabOrder = 3
      Text = '2022'
    end
  end
  object Button5: TButton
    Left = 24
    Top = 266
    Width = 97
    Height = 33
    Action = actClose_Realy
    TabOrder = 3
  end
  object Button6: TButton
    Left = 144
    Top = 266
    Width = 97
    Height = 33
    Action = actRelease_Realy
    TabOrder = 4
  end
  object cmbTxPower: TComboBox
    Left = 360
    Top = 18
    Width = 169
    Height = 20
    Style = csDropDownList
    TabOrder = 5
    Items.Strings = (
      '0'
      '1'
      '2'
      '3'
      '4'
      '5'
      '6'
      '7'
      '8'
      '9'
      '10'
      '11'
      '12'
      '13'
      '14'
      '15'
      '16'
      '17'
      '18'
      '19'
      '20'
      '21'
      '22'
      '23'
      '24'
      '25'
      '26'
      '27'
      '28'
      '29'
      '30'
      '31'
      '32'
      '33')
  end
  object cmbWorkmode: TComboBox
    Left = 360
    Top = 58
    Width = 169
    Height = 20
    Style = csDropDownList
    TabOrder = 6
    Items.Strings = (
      'AnswerMode'
      'ActiveMode')
  end
  object Button7: TButton
    Left = 539
    Top = 13
    Width = 97
    Height = 33
    Action = actGetTxPower
    TabOrder = 7
  end
  object Button8: TButton
    Left = 539
    Top = 52
    Width = 97
    Height = 33
    Action = actGetWorkMode
    TabOrder = 8
  end
  object Button9: TButton
    Left = 647
    Top = 13
    Width = 97
    Height = 33
    Action = actSetTxPower
    TabOrder = 9
  end
  object Button10: TButton
    Left = 647
    Top = 52
    Width = 97
    Height = 33
    Action = actSetWorkMode
    TabOrder = 10
  end
  object Button13: TButton
    Left = 345
    Top = 217
    Width = 112
    Height = 72
    Action = actStart
    TabOrder = 11
  end
  object Button14: TButton
    Left = 481
    Top = 217
    Width = 112
    Height = 72
    Action = actStop
    TabOrder = 12
  end
  object GroupBox4: TGroupBox
    Left = 767
    Top = 8
    Width = 302
    Height = 651
    Caption = #26085#24535
    TabOrder = 13
    object mmoLogs: TMemo
      Left = 2
      Top = 14
      Width = 298
      Height = 635
      Align = alClient
      TabOrder = 0
    end
  end
  object Button15: TButton
    Left = 632
    Top = 241
    Width = 75
    Height = 25
    Caption = 'Button15'
    TabOrder = 14
    Visible = False
    OnClick = Button15Click
  end
  object lstView: TRzListView
    Left = 16
    Top = 312
    Width = 728
    Height = 312
    Columns = <
      item
        Width = 10
      end
      item
        Caption = 'No'
      end
      item
        Caption = 'Data'
        Width = 250
      end
      item
        Caption = 'Len'
        Width = 60
      end
      item
        Caption = 'Cnt(Ant1/2/3/4)'
        Width = 150
      end
      item
        Caption = 'RSSI(dBm)'
        Width = 80
      end
      item
        Caption = 'Channel'
        Width = 107
      end>
    GridLines = True
    TabOrder = 15
    ViewStyle = vsReport
  end
  object Button16: TButton
    Left = 669
    Top = 630
    Width = 75
    Height = 25
    Action = actClearData
    Anchors = [akLeft, akBottom]
    TabOrder = 16
  end
  object actList: TActionList
    Left = 280
    Top = 240
    object actSportOpen: TAction
      Caption = 'OPEN'
      OnExecute = actSportOpenExecute
      OnUpdate = actSportOpenUpdate
    end
    object actSportClose: TAction
      Caption = 'Close'
      OnExecute = actSportCloseExecute
      OnUpdate = actSportCloseUpdate
    end
    object actNetConnect: TAction
      Caption = 'CONNECT(&C)'
      OnExecute = actNetConnectExecute
      OnUpdate = actNetConnectUpdate
    end
    object actNetDiscount: TAction
      Caption = 'DISCONNECT(&D)'
      OnExecute = actNetDiscountExecute
      OnUpdate = actNetDiscountUpdate
    end
    object actGetTxPower: TAction
      Caption = 'Get'
      OnExecute = actGetTxPowerExecute
      OnUpdate = actGetTxPowerUpdate
    end
    object actSetTxPower: TAction
      Caption = 'Set'
      OnExecute = actSetTxPowerExecute
      OnUpdate = actSetTxPowerUpdate
    end
    object actGetWorkMode: TAction
      Caption = 'Get'
      OnExecute = actGetWorkModeExecute
      OnUpdate = actGetWorkModeUpdate
    end
    object actSetWorkMode: TAction
      Caption = 'Set'
      OnExecute = actSetWorkModeExecute
      OnUpdate = actSetWorkModeUpdate
    end
    object actClose_Realy: TAction
      Caption = 'Close_Realy'
      OnExecute = actClose_RealyExecute
      OnUpdate = actClose_RealyUpdate
    end
    object actRelease_Realy: TAction
      Caption = 'Release_Realy'
      OnExecute = actRelease_RealyExecute
      OnUpdate = actRelease_RealyUpdate
    end
    object actGetFreq: TAction
      Caption = 'Get'
      OnExecute = actGetFreqExecute
      OnUpdate = actGetFreqUpdate
    end
    object actSetFreq: TAction
      Caption = 'Set'
      OnExecute = actSetFreqExecute
      OnUpdate = actSetFreqUpdate
    end
    object actStart: TAction
      Caption = 'Start'
      OnExecute = actStartExecute
      OnUpdate = actStartUpdate
    end
    object actStop: TAction
      Caption = 'Stop'
      OnExecute = actStopExecute
      OnUpdate = actStopUpdate
    end
    object actClearData: TAction
      Caption = 'Clear'
      OnExecute = actClearDataExecute
    end
  end
  object ds_list: TDataSource
    DataSet = mt_list
    Left = 304
    Top = 416
  end
  object mt_list: TMemTableEh
    Active = True
    FieldDefs = <
      item
        Name = 'Num'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'Code'
        DataType = ftString
        Size = 500
      end
      item
        Name = 'CodeLen'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'Count'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'Rssi'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'Cw'
        DataType = ftString
        Size = 100
      end
      item
        Name = 'ant'
        DataType = ftInteger
        Precision = 15
      end
      item
        Name = 'ant1'
        DataType = ftInteger
        Precision = 15
      end
      item
        Name = 'ant2'
        DataType = ftInteger
        Precision = 15
      end
      item
        Name = 'ant3'
        DataType = ftInteger
        Precision = 15
      end
      item
        Name = 'ant4'
        DataType = ftInteger
        Precision = 15
      end>
    IndexDefs = <>
    Params = <>
    StoreDefs = True
    Left = 304
    Top = 488
    object mt_listcolNum: TStringField
      DisplayWidth = 12
      FieldName = 'Num'
      Size = 100
    end
    object mt_listcolCode: TStringField
      DisplayWidth = 17
      FieldName = 'Code'
      Size = 500
    end
    object mt_listcolCodeLen: TStringField
      DisplayWidth = 13
      FieldName = 'CodeLen'
      Size = 100
    end
    object mt_listcolCount: TStringField
      DisplayWidth = 22
      FieldName = 'Count'
      Size = 100
    end
    object mt_listcolRssi: TStringField
      DisplayWidth = 18
      FieldName = 'Rssi'
      Size = 100
    end
    object mt_listcolCw: TStringField
      DisplayWidth = 24
      FieldName = 'Cw'
      Size = 100
    end
    object mt_listant: TIntegerField
      FieldName = 'ant'
    end
    object mt_listant1: TIntegerField
      FieldName = 'ant1'
    end
    object mt_listant2: TIntegerField
      FieldName = 'ant2'
    end
    object mt_listant3: TIntegerField
      FieldName = 'ant3'
    end
    object mt_listant4: TIntegerField
      FieldName = 'ant4'
    end
    object MemTableData: TMemTableDataEh
      object DataStruct: TMTDataStructEh
        object Num: TMTStringDataFieldEh
          FieldName = 'Num'
          StringDataType = fdtStringEh
          Size = 100
        end
        object Code: TMTStringDataFieldEh
          FieldName = 'Code'
          StringDataType = fdtStringEh
          Size = 500
        end
        object CodeLen: TMTStringDataFieldEh
          FieldName = 'CodeLen'
          StringDataType = fdtStringEh
          Size = 100
        end
        object Count: TMTStringDataFieldEh
          FieldName = 'Count'
          StringDataType = fdtStringEh
          Size = 100
        end
        object Rssi: TMTStringDataFieldEh
          FieldName = 'Rssi'
          StringDataType = fdtStringEh
          Size = 100
        end
        object Cw: TMTStringDataFieldEh
          FieldName = 'Cw'
          StringDataType = fdtStringEh
          Size = 100
        end
        object ant: TMTNumericDataFieldEh
          FieldName = 'ant'
          NumericDataType = fdtIntegerEh
          AutoIncrement = False
          currency = False
          Precision = 15
        end
        object ant1: TMTNumericDataFieldEh
          FieldName = 'ant1'
          NumericDataType = fdtIntegerEh
          AutoIncrement = False
          currency = False
          Precision = 15
        end
        object ant2: TMTNumericDataFieldEh
          FieldName = 'ant2'
          NumericDataType = fdtIntegerEh
          AutoIncrement = False
          currency = False
          Precision = 15
        end
        object ant3: TMTNumericDataFieldEh
          FieldName = 'ant3'
          NumericDataType = fdtIntegerEh
          AutoIncrement = False
          currency = False
          Precision = 15
        end
        object ant4: TMTNumericDataFieldEh
          FieldName = 'ant4'
          NumericDataType = fdtIntegerEh
          AutoIncrement = False
          currency = False
          Precision = 15
        end
      end
      object RecordsList: TRecordsListEh
      end
    end
  end
end
