object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Pitchupi'
  ClientHeight = 299
  ClientWidth = 534
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 0
    Top = 169
    Width = 534
    Height = 2
    Cursor = crVSplit
    Align = alTop
    Constraints.MaxHeight = 2
    ExplicitLeft = -8
    ExplicitTop = 176
  end
  object lvwTransfers: TListView
    Left = 0
    Top = 171
    Width = 534
    Height = 109
    Align = alClient
    Columns = <
      item
        Caption = 'Name'
        Width = 140
      end
      item
        Caption = 'Size'
        Width = 60
      end
      item
        Caption = 'Done'
        Width = 60
      end
      item
        Caption = '%'
        Width = 45
      end
      item
        Caption = 'Status'
        Width = 70
      end
      item
        Caption = 'Speed'
        Width = 70
      end
      item
        Caption = 'ETA'
        Width = 84
      end>
    MultiSelect = True
    OwnerData = True
    RowSelect = True
    TabOrder = 0
    TabStop = False
    ViewStyle = vsReport
    OnData = lvwTransfersData
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 280
    Width = 534
    Height = 19
    Panels = <
      item
        Text = 'Ready to rock and roll :-)'
        Width = 50
      end>
  end
  object Panel: TPanel
    Left = 0
    Top = 0
    Width = 534
    Height = 169
    Align = alTop
    TabOrder = 2
    object txtSendMessage: TEdit
      Left = 1
      Top = 147
      Width = 532
      Height = 21
      Align = alTop
      Anchors = [akLeft, akTop, akRight, akBottom]
      Constraints.MaxHeight = 21
      Constraints.MinHeight = 21
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Fixedsys'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnKeyDown = txtSendMessageKeyDown
    end
    object txtOutput: TMemo
      Left = 1
      Top = 58
      Width = 532
      Height = 89
      TabStop = False
      Align = alTop
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Fixedsys'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
      WantReturns = False
    end
    object grpOptions: TGroupBox
      Left = 1
      Top = 1
      Width = 532
      Height = 57
      Align = alTop
      Caption = 'Options'
      Constraints.MaxHeight = 57
      Constraints.MinHeight = 57
      TabOrder = 2
      object lblPort: TLabel
        Left = 103
        Top = 16
        Width = 27
        Height = 13
        Caption = 'Port: '
      end
      object lblHost: TLabel
        Left = 11
        Top = 16
        Width = 29
        Height = 13
        Caption = 'Host: '
      end
      object lblPassword: TLabel
        Left = 151
        Top = 16
        Width = 53
        Height = 13
        Caption = 'Password: '
      end
      object btnListen: TButton
        Left = 306
        Top = 29
        Width = 62
        Height = 21
        Caption = 'Listen'
        TabOrder = 4
        OnClick = btnListenClick
      end
      object txtPort: TEdit
        Left = 103
        Top = 29
        Width = 42
        Height = 21
        TabOrder = 1
        Text = '9999'
      end
      object txtHost: TEdit
        Left = 11
        Top = 29
        Width = 86
        Height = 21
        TabOrder = 0
        Text = 'localhost'
      end
      object btnConnect: TButton
        Left = 238
        Top = 30
        Width = 62
        Height = 21
        Caption = 'Connect'
        TabOrder = 3
        OnClick = btnConnectClick
      end
      object txtPassword: TEdit
        Left = 151
        Top = 29
        Width = 83
        Height = 21
        PasswordChar = '*'
        TabOrder = 2
        Text = 'geez!!!@@'
      end
      object btnAbort: TButton
        Left = 373
        Top = 29
        Width = 62
        Height = 21
        Caption = 'Abort'
        TabOrder = 5
        OnClick = btnAbortClick
      end
      object btnChDir: TButton
        Left = 441
        Top = 29
        Width = 62
        Height = 21
        Caption = 'ChDir'
        TabOrder = 6
        OnClick = btnChDirClick
      end
    end
  end
  object TimerFileQueue: TTimer
    Interval = 500
    OnTimer = TimerFileQueueTimer
    Left = 80
    Top = 64
  end
  object TrayIcon: TTrayIcon
    OnClick = TrayIconClick
    Left = 48
    Top = 64
  end
  object AppEvents: TApplicationEvents
    OnMinimize = AppEventsMinimize
    Left = 16
    Top = 64
  end
  object dlgSelectDir: TSaveDialog
    Left = 112
    Top = 64
  end
end
