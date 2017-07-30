unit mainForm;

interface

uses
   Windows, Messages, SysUtils, Forms, Classes, Controls,
    Dialogs, StdCtrls, Winsock, Contnrs, ComCtrls, PiUtils, Picrypt,
    FileTransfer, ShellAPI, ExtCtrls, AppEvnts, FileCtrl, IniFiles;

type
    TfrmMain = class(TForm)
    lvwTransfers: TListView;
    StatusBar: TStatusBar;
    TimerFileQueue: TTimer;
    TrayIcon: TTrayIcon;
    AppEvents: TApplicationEvents;
    Splitter: TSplitter;
    Panel: TPanel;
    txtSendMessage: TEdit;
    txtOutput: TMemo;
    grpOptions: TGroupBox;
    lblPort: TLabel;
    lblHost: TLabel;
    lblPassword: TLabel;
    btnListen: TButton;
    txtPort: TEdit;
    txtHost: TEdit;
    btnConnect: TButton;
    txtPassword: TEdit;
    btnAbort: TButton;
    btnChDir: TButton;
    dlgSelectDir: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnListenClick(Sender: TObject);
    procedure handleWMAsyncSelect(var Msg:TMessage); message WM_ASYNC_SELECT;
    procedure btnConnectClick(Sender: TObject);
    procedure txtSendMessageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lvwTransfersData(Sender: TObject; Item: TListItem);
    procedure AcceptFiles( var msg : TMessage ); message WM_DROPFILES;
    procedure TimerFileQueueTimer(Sender: TObject);
    procedure btnAbortClick(Sender: TObject);
    procedure AppEventsMinimize(Sender: TObject);
    procedure TrayIconClick(Sender: TObject);
    procedure DisableControls(Disable: boolean);
    procedure btnChDirClick(Sender: TObject);
    procedure OutputLine(sLine: string);

    private
    public
    end;

var
    CBox: TCryptoBox;
    Connected: boolean;
    DirSave: string;
    frmMain: TfrmMain;
    CanSendFiles: boolean;
    gFTList: TFileTransferList;
    gListening: boolean;
    gServer: boolean;
    gSocket: TSocket;
    gListeningSocket: TSocket;
    gAddrIn: TSockAddrIn;
    gAddrSize: Integer;
    WSInitialized: boolean;
    wsaData: TWSAData;
    szBuffer: array[0..MAXBUF] of char;
    procedure WSInitialize();
    procedure HandleSocketAccept(Sock: TSocket);
    procedure HandleSocketRead(Sock: TSocket);
    procedure HandleSocketClose(Sock: TSocket);
    procedure HandleSocketConnect(Sock: TSocket);
    procedure DoConnect();
    procedure DoListen();
    procedure ParseExecCmd();
    procedure SendCmd(Cmd: Integer; Text: string);
    procedure SendFileCmd(FilePath:string);
    procedure AbortConnection();
    procedure LoadIniSettings();
    procedure SaveIniSettings();

implementation

{$R *.dfm}

procedure TfrmMain.AcceptFiles( var msg : TMessage );
const
    cnMaxFileNameLen = MAX_PATH;
var
i, nCount: integer;
acFileName: array [0..cnMaxFileNameLen] of char;
sName: string;
begin

    if not CanSendFiles then begin
        MessageBox(frmMain.Handle, 'Can''t send until all current transfers have been negotiated', 'Pitchupi', MB_OK + MB_ICONEXCLAMATION);
        Exit;
    end;

    CanSendFiles := false;
    nCount := DragQueryFile( msg.WParam, $FFFFFFFF, acFileName, cnMaxFileNameLen );
    for i := 0 to nCount-1 do begin
        DragQueryFile( msg.WParam, i, acFileName, cnMaxFileNameLen );
        SetString(sName, acFileName, StrLen(acFileName));
        if DirectoryExists(sName) then continue;
        SendFileCmd(sName);
    end;
    DragFinish( msg.WParam );
end;

procedure HandleSocketConnect(Sock: Integer);
begin
    DragAcceptFiles( frmMain.Handle, True );
    SendCmd(CTRL_PASS, HashPassword(frmMain.txtPassword.Text));
    frmMain.StatusBar.Panels[0].Text := 'Connected to ' + frmMain.txtHost.Text;
    CanSendFiles := true;
    Connected := true;
end;

procedure HandleSocketClose(Sock: Integer);
begin
    Connected := false;
    closesocket(Sock);
    DragAcceptFiles( frmMain.Handle, False );
    AbortConnection();
    frmMain.StatusBar.Panels[0].Text := 'Lost connection to ' + AddrToHost(gAddrIn);
end;

procedure HandleSocketRead(Sock: Integer);
var
buf:array[0..MAXBUF] of char;
pbuf:PChar;
strTmp:string;
bytesRead:Integer;
prevPos, i: Integer;
begin

    FillChar(buf, sizeof(buf), 0);
    bytesRead := recv(Sock, buf, sizeof(buf), 0);
    CBox.Crypt(PByte(@Buf), bytesRead);

    prevPos := 0;
    i := 0;

    while i < bytesRead do begin
        if Ord(buf[i]) = 0 then begin
            pbuf := Addr(buf[prevPos]);
            SetString(strTmp, pbuf, i - prevPos);
            Move(buf[prevPos], szBuffer[StrLen(szBuffer)], i - prevPos);
            ParseExecCmd();
            FillChar(szBuffer, SizeOf(szBuffer), 0);
            prevPos := i;
        end;
        Inc(i);
    end;

    //store last chars, if any.
    if prevPos < i then begin
        Move(buf[prevPos], szBuffer, i - prevPos);
    end;

    //send if theres a complete command queued
    if Ord(buf[i]) = 0 then begin
        ParseExecCmd();
    end;

end;

procedure HandleSocketAccept(Sock: TSocket);
begin
    gAddrSize := sizeof(gAddrIn);
    gSocket := accept(Sock, @gAddrIn, @gAddrSize);
    closesocket(gListeningSocket);
    SendCmd(CTRL_PASS, HashPassword(frmMain.txtPassword.Text));
    gServer := True;
    DragAcceptFiles( frmMain.Handle, True );

    frmMain.StatusBar.Panels[0].Text := 'Accepted connection from ' + AddrToHost(gAddrIn);;
    CanSendFiles := true;
    Connected := true;
end;

procedure TfrmMain.handleWMAsyncSelect(var Msg:TMessage);
var
lParam, sockHandle, ErrNum, notification: Integer;
begin

    lParam := Msg.LParam;
    sockHandle := Msg.WParam;
    errNum := WSAGetSelectError(lParam);
    notification := WSAGetSelectEvent(lParam);

    if ErrNum <= WSABASEERR then
        case notification of
            FD_ACCEPT:  HandleSocketAccept(sockHandle);
            FD_CONNECT: HandleSocketConnect(sockHandle);
            FD_READ:    HandleSocketRead(sockHandle);
            FD_CLOSE:   HandleSocketClose(sockHandle);
    end
    else begin
        MessageBox(frmMain.Handle, PAnsiChar('handleWMAsyncSelect() returned error ' + IntToStr(ErrNum)), 'Pitchupi', MB_OK + MB_ICONERROR);
        AbortConnection();
        Exit;
    end;

end;

procedure TfrmMain.lvwTransfersData(Sender: TObject; Item: TListItem);
var
ft:TFileTransfer;
sStatus: string;
begin

    ft := TFileTransfer(gFTList[Item.Index]);

    if ft.Sender = true then
        sStatus := 'Up'
    else
        sStatus := 'Down';

    if ft.Size = ft.Completed then
        sStatus := sStatus + ' done';
    if ft.Status = STAT_WAIT then sStatus := sStatus + ' Wait';
    if ft.Status = STAT_READY then sStatus := sStatus + ' Ready';
    if ft.Status = STAT_ABRT then sStatus := sStatus + ' Aborted';


    Item.Caption := ExtractFileName(ft.FileName);
    Item.SubItems.Add(AdjustSizeStr(ft.Size));
    Item.SubItems.Add(AdjustSizeStr(ft.Completed));
    if ft.Completed > 0 then
        Item.SubItems.Add(IntToStr(Trunc(ft.Completed * 100 / ft.Size)) + '%')
    else
        Item.SubItems.Add('0%');
    Item.SubItems.Add(sStatus);
    if ft.Speed > 0 then begin
        Item.SubItems.Add(AdjustSizeStr(ft.Speed) + '/s');
        Item.SubItems.Add(TimeStr((ft.Size - ft.Completed) div ft.Speed));
    end;
end;

procedure TfrmMain.TimerFileQueueTimer(Sender: TObject);
var
TextCmd: string;
FT: TFileTransfer;
i: integer;
iWait: Integer;
//idx: integer;
begin

    //idx := lvwTransfers.Top;
    //poderia otimizar fazendo um loop apenas
    //for i := 0 to gFTList.Count - 1 do begin
        //lvwTransfers.Items[i].Update();
    //end;
    //lvwTransfers.Top := idx;

    lvwTransfers.Items.BeginUpdate();
    lvwTransfers.Items.EndUpdate();

    iWait := -1;
    for i := 0 to gFTList.Count - 1 do begin
        FT := TFileTransfer(gFTList.Items[i]);
        if FT.Status = STAT_READY then
            Exit;
        if (iWait = -1) and (FT.Status = STAT_WAIT) then
            iWait := i;
    end;

    if iWait = -1 then begin
        CanSendFiles := true; //if no ready and no wait then all OK
        Exit;
    end;

    FT := TFileTransfer(gFTList.Items[iWait]);
    FT.Status := STAT_READY;

    if FT.Sender = true then begin
        TextCmd := IntToStr(FT.Id) + ' ';
        TextCmd := TextCmd + IntToStr(FT.Size) + ' ';
        TextCmd := TextCmd + ExtractFileName(FT.Filename);
        SendCmd(CTRL_FILE, TextCmd);
    end
    else begin
        TextCmd := IntToStr(FT.Id) + ' ' + IntToStr(FT.Completed);
        SendCmd(CTRL_RESM, TextCmd);
    end;

end;

procedure TfrmMain.TrayIconClick(Sender: TObject);
begin
    TrayIcon.Visible := False;
    Application.Restore;
    Application.BringToFront;
end;

procedure TfrmMain.txtSendMessageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if Key = VK_RETURN then begin
        if txtSendMessage.Text = '' then Exit;
        if Connected then begin
            SendCmd(CTRL_MESG, txtSendMessage.Text);
            OutputLine( '<Me> ' + txtSendMessage.Text);
        end;
        txtSendMessage.Text := '';
    end;
end;

procedure DoListen();
begin

    FillChar(gAddrIn, sizeof(gAddrIn), 0);
    with gAddrIn do begin
        sin_family := AF_INET;
        sin_port := htons(StrToInt(frmMain.txtPort.Text));
        sin_addr.S_addr := INADDR_ANY;
    end;

    if bind(gListeningSocket, gAddrIn, sizeof(gAddrIn)) <> 0 then begin
        MessageBox(frmMain.Handle, 'DoListen() could not bind.', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    if listen(gListeningSocket, 1) <> 0 then begin
        MessageBox(frmMain.Handle, 'DoListen() could not listen.', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;
end;

procedure DoConnect();
var
szHost: array[0..255] of char;
Status: Integer;
PortNumber: Integer;
Host:string;
begin

    Host := frmMain.txtHost.Text;
    portNumber := StrToInt(frmMain.txtPort.Text);

    FillChar(gAddrIn, sizeof(gAddrIn), 0);
    StrPCopy(szHost, Host);

    if inet_addr(szHost) = -1 then begin
        Host := GetIPFromHost(Host);
        StrPCopy(szHost, Host);
    end;

    with gAddrIn do begin
        sin_family := AF_INET;
        sin_port := htons(PortNumber);
        sin_addr.S_addr := INADDR_ANY;
        sin_addr.s_Addr:= inet_addr(szHost);
    end;

    Status := connect(gSocket, gAddrIn, sizeof(gAddrIn));
    if (Status <> SOCKET_ERROR) or (WSAGetLastError() <> WSAEWOULDBLOCK) then begin
        MessageBox(frmMain.Handle, 'DoConnect() could not connect.', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;
end;

procedure TfrmMain.AppEventsMinimize(Sender: TObject);
begin
//hold
    frmMain.Hide();
    TrayIcon.Visible := True;
end;

procedure TfrmMain.btnAbortClick(Sender: TObject);
begin
    AbortConnection();
end;

procedure TfrmMain.btnChDirClick(Sender: TObject);
begin
    SelectDirectory(DirSave, [sdAllowCreate, sdPerformCreate], 0);
    ChDir(DirSave);
    OutputLine('*** Storing files at ' + DirSave);
end;

procedure TfrmMain.btnConnectClick(Sender: TObject);
begin

    if txtPassword.Text = '' then begin
        MessageBox(frmMain.handle, 'Don''t be so careless. Provide a password and exchange your files with weak built-in crypto.', 'Password needed', MB_OK or MB_ICONEXCLAMATION);
        Exit;
    end;
    DisableControls(true);
    if not WSInitialized then WSInitialize();
    DoConnect();

end;

procedure TfrmMain.btnListenClick(Sender: TObject);
begin
    if txtPassword.Text = '' then begin
        MessageBox(frmMain.handle, 'Don''t be so careless. Provide a password and exchange your files with weak built-in crypto.', 'Password needed', MB_OK or MB_ICONEXCLAMATION);
        Exit;
    end;
    if gListening = false then begin
        gListening := true;
        if not WSInitialized then WSInitialize();
        DoListen();
        StatusBar.Panels[0].Text := 'Listening on ' + txtPort.Text;
    end;
    DisableControls(gListening);

    btnAbort.Enabled := gListening;

end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    if gSocket > 0 then closesocket(gSocket);
    SaveIniSettings();
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
    LoadIniSettings();
    CBox := TCryptoBox.Create();
    WSInitialized := false;
    gSocket := 0;
    gAddrSize := 0;
    gListening := false;
    gFTList := TFileTransferList.Create();
end;

procedure WSInitialize();
begin

    if WSAStartup($0101, wsaData) <> 0 then begin
        MessageBox(frmMain.Handle, 'WSInitialize() could not... initialize', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    gSocket := Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if gSocket = INVALID_SOCKET then begin
        MessageBox(frmMain.Handle, 'WSInitialize() could not create socket', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    gListeningSocket := Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if gListeningSocket = INVALID_SOCKET then begin
        MessageBox(frmMain.Handle, 'WSInitialize() could not create listening socket', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    if WSAAsyncSelect(gSocket, frmMain.Handle, WM_ASYNC_SELECT,
            FD_CONNECT + FD_READ + FD_CLOSE) <> 0 then
    begin
        MessageBox(frmMain.Handle, 'WSInitialize() could not call WSAAsyncSelect() properly.', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    if WSAAsyncSelect(gListeningSocket, frmMain.Handle, WM_ASYNC_SELECT,
            FD_READ + FD_ACCEPT + FD_CLOSE) <> 0 then
    begin
        MessageBox(frmMain.Handle, 'WSInitialize() could not call WSAAsyncSelect() properly for the listening socket.', 'Pitchupi', MB_OK + MB_ICONERROR);
        Exit;
    end;

    WSInitialized := true;

end;

procedure ParseExecCmd();
var
strParam: String;
PBuf1: PChar;
i: Integer;
FileId: Integer;
newFileTransfer: TFileTransfer;
szTmp:array[0..3] of char;
begin

    PBuf1 := Addr(szBuffer[1]);
    SetString(strParam, PBuf1, StrLen(PBuf1));

    case Ord(szBuffer[0]) of
        CTRL_MESG: begin
            frmMain.OutputLine('<Peer> ' + strParam);
        end;

        CTRL_FILE: begin
            CanSendFiles := false;
            i := Pos(' ', strParam);
            FileId := StrToInt(Copy(strParam, 1, i - 1));
            Delete(strParam, 1, i);
            i := Pos(' ', strParam);
            newFileTransfer := TFileTransfer.Create(True);
            with newFileTransfer do begin
                HostPort := StrToInt(frmMain.txtPort.Text);
                Host := frmMain.txtHost.Text;
                Id := FileId;
                Size := StrToInt64(Copy(strParam, 1, i - 1));
                Filename := Copy(strParam, i + 1, Length(strParam));
                Sender := false;
                Server := gServer;
                OpenFile();
                Status := STAT_WAIT;
                Resume();
            end;
            gFTList.Add(newFileTransfer);
            frmMain.lvwTransfers.Items.Insert(frmMain.lvwTransfers.Items.Count);
        end;

        CTRL_RESM: begin
            i := Pos(' ', strParam);
            FileId := StrToInt(Copy(strParam, 1, i - 1));
            Delete(strParam, 1, i);
            newFileTransfer := TFileTransfer(gFTList.byFileId(FileId));
            newFileTransfer.Completed := StrToInt(strParam);
            newFileTransfer.Resume();
        end;

        CTRL_PASS: begin
            if strParam <> HashPassword(frmMain.txtPassword.Text) then begin
                MessageBox(frmMain.Handle, 'Password doesn''t match with peer''s one.' + #13#10 + 'Aborting connection now.', 'Pitchupi', MB_OK + MB_ICONERROR);
                AbortConnection();
            end;
            CBox := TCryptoBox.Create();
            CBox.sPass := frmMain.txtPassword.Text;
            HexToBin(PAnsiChar(strParam), szTmp, 4);
            Move(szTmp, CBox.IV, 4);
            CBox.Init();
        end;

    end;

    FillChar(szBuffer, sizeof(szBuffer), 0);
end;

procedure SendCmd(Cmd: Integer; Text: string);
var
szBuf: array[0..MAXBUF] of Char;
FullLen: Integer;
begin
    FillChar(szBuf, sizeof(szBuf), 0);
    szBuf[0] := Chr(Cmd);
    StrLCopy(@szBuf[1], PChar(@Text[1]), SizeOf(szBuf) - 1);
    FullLen := StrLen(szBuf) + 1;
    CBox.Crypt(PByte(@szBuf), FullLen);
    send(gSocket, szBuf, FullLen, 0);
end;

procedure SendFileCmd(FilePath:string);
var
newFileTransfer:TFileTransfer;
begin
    newFileTransfer := TFileTransfer.Create(True);
    with newFileTransfer do begin
        Sender := True;
        Server := gServer;
        Host := frmMain.txtHost.Text;
        HostPort := StrToInt(frmMain.txtPort.Text);
        Filename := FilePath;
        OpenFile();
        GenerateId();
        Status := STAT_WAIT;
    end;

    gFTList.Add(newFileTransfer);
    frmMain.lvwTransfers.Items.Insert(frmMain.lvwTransfers.Items.Count);

end;


procedure AbortConnection();
var
i:integer;
ft: TFileTransfer;
begin
    Connected := False;
    DragAcceptFiles(frmMain.handle, False);
    closesocket(gSocket);
    closesocket(gListeningSocket);
    for i:= 0 to gFTList.Count - 1 do begin
        ft := TFileTransfer(gFTList.Items[i]);
        if ft.Completed <> ft.Size then ft.Status := STAT_ABRT;
        ft.Terminate();
    end;
    gListening := false;
    frmMain.DisableControls(false);
    WSInitialized := false;
    frmMain.StatusBar.Panels[0].Text := 'Connection aborted.';
end;

procedure TfrmMain.DisableControls(Disable: boolean);
begin
    txtPort.Enabled := not Disable;
    txtHost.Enabled := not Disable;
    txtPassword.Enabled := not Disable;
    btnListen.Enabled := not Disable;
    btnConnect.Enabled := not Disable;
    btnChDir.Enabled := not Disable;
end;

procedure LoadIniSettings();
var
IniFile: TIniFile;
begin
    IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini'));
    DirSave := ExtractFilePath(Application.ExeName);
    DirSave := IniFile.ReadString('Settings', 'DirSave', DirSave);
    frmMain.txtHost.Text := IniFile.ReadString('Settings', 'Host', 'localhost');
    frmMain.txtPort.Text := IniFile.ReadString('Settings', 'Port', '9999');
    frmMain.Top := IniFile.ReadInteger('Settings','Top', frmMain.Top);
    frmMain.Left := IniFile.ReadInteger('Settings','Left', frmMain.Left);
    frmMain.Width := IniFile.ReadInteger('Settings','Width', frmMain.Width);
    frmMain.Height := IniFile.ReadInteger('Settings','Height', frmMain.Height);
    frmMain.WindowState := TWindowState(IniFile.ReadInteger('Settings','WindowState', Integer(frmMain.WindowState)));
    frmMain.Panel.Height := IniFile.ReadInteger('Settings', 'Splitter', frmMain.Panel.Height);
    IniFile.Free;
    ChDir(DirSave);
    frmMain.txtPassword.Text := '';
end;

procedure SaveIniSettings();
var
IniFile: TIniFile;
begin
    IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini'));
    IniFile.WriteString('Settings', 'DirSave', DirSave);
    IniFile.WriteString('Settings', 'Host', frmMain.txtHost.Text);
    IniFile.WriteString('Settings', 'Port', frmMain.txtPort.Text);
    if frmMain.WindowState <> wsMaximized then begin
        IniFile.WriteInteger('Settings','Top', frmMain.Top);
        IniFile.WriteInteger('Settings','Left', frmMain.Left);
        IniFile.WriteInteger('Settings','Width', frmMain.Width);
        IniFile.WriteInteger('Settings','Height', frmMain.Height);
    end;
    IniFile.WriteInteger('Settings','WindowState', Integer(frmMain.WindowState));
    IniFile.WriteInteger('Settings', 'Splitter', frmMain.Panel.Height);
    IniFile.Free;
end;

procedure TfrmMain.OutputLine(sLine: string);
begin
    txtOutput.Lines.Add('[' + TimeToStr(Now) +'] '+ sLine);
    txtOutput.Text := Trim(txtOutput.Text);
end;

end.

