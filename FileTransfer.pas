unit FileTransfer;

interface

uses
    Classes, Winsock, Windows, Contnrs, SysUtils, Dialogs,
    PiUtils, PiCrypt, Mmsystem;

type
    TFileTransfer = class(TThread)
    private
        AddrIn: TSockAddrIn;
        Sock: TSocket;
        wsaData: TWSAData;
        LastTime: DWORD;
        LastCompleted: Int64;
    protected
        procedure Execute; override;

    public
        HostPort: Integer;
        Host: string;
        Filename: string;
        Size: Int64;
        Completed: Int64;
        FileStream: TFileStream;
        Id: DWORD;
        Sender: boolean;
        Server: boolean;
        Status: Integer;
        Speed: Integer;
        procedure OpenFile();
        procedure GenerateId();
        procedure PrepareConnection();
    end;

    TFileTransferList = class(TObjectList)
    public
        function byFileId(Id: DWORD): TFileTransfer;
    end;

implementation
uses mainForm;



procedure TFileTransfer.OpenFile();
begin

    if not Self.Sender then begin
        if not FileExists(Self.Filename) then
            FileStream := TFileStream.Create(Self.FileName, fmCreate or fmShareDenyWrite)
        else
            FileStream := TFileStream.Create(Self.FileName, fmOpenWrite or fmShareDenyWrite);

        Self.Completed := FileStream.Size;
    end
    else begin
        FileStream := TFileStream.Create(Self.Filename, fmOpenRead or fmShareDenyWrite);
        Self.Size := FileStream.Size;
    end;

end;

procedure TFileTransfer.GenerateId();
var
perm: Int64;
begin
    QueryPerformanceCounter(perm);
    Self.Id := (perm + FileStream.Size) mod $7FFFFFFF;
end;

procedure TFileTransfer.Execute;
var
buf:array[0..255] of byte;
bytesRead:Integer;
bytesSent: Integer;
ThisTime: DWORD;
CBox: TCryptoBox;
begin

    while Self.Status <> STAT_READY do
        Sleep(50);

    PrepareConnection();

    CBox := TCryptoBox.Create();
    CBox.sPass := frmMain.txtPassword.Text;
    CBox.IV := Self.Id;
    CBox.Init();

    Self.Status := STAT_OK;

    FileStream.Seek(Self.Completed, soBeginning);

    Self.LastTime := timeGetTime();
    Self.LastCompleted := Self.Completed;
    if Sender then begin
        while (not Self.Terminated) and (Self.FileStream.Position < Self.FileStream.Size) do begin
            bytesRead := Self.FileStream.Read(buf, sizeof(buf));
            CBox.Crypt(@buf[0], bytesRead);
            bytesSent := send(Self.Sock, buf, bytesRead, 0);
            Inc(Self.Completed, bytesSent);
            ThisTime := timeGetTime();
            if (ThisTime - Self.LastTime) > 1000 then begin
                Self.Speed := (Self.Completed - Self.LastCompleted);
                Self.LastTime := ThisTime;
                Self.LastCompleted := Self.Completed;
            end;
        end;
    end
    else begin
        while (not Self.Terminated) and (Self.FileStream.Position < Self.Size) do begin
            bytesRead := recv(Self.Sock, buf, sizeof(buf), 0);
            CBox.Crypt(@buf[0], bytesRead);
            Self.FileStream.Write(buf, bytesRead);
            Inc(Self.Completed, bytesRead);
            ThisTime := timeGetTime();
            if (ThisTime - Self.LastTime) > 1000 then begin
                Self.Speed := (Self.Completed - Self.LastCompleted);
                Self.LastTime := ThisTime;
                Self.LastCompleted := Self.Completed;
            end;
        end;
    end;

    Self.FileStream.Free();
    closesocket(Self.Sock);
    CBox.Free();

end;

function TFileTransferList.byFileId(Id: DWORD): TFileTransfer;
var
i: Integer;
begin

    Result := nil;
    for i := 0 to Self.Count - 1 do begin
        if TFileTransfer(Self.Items[i]).Id = Id then begin
            Result := TFileTransfer(Self.Items[i]);
            Exit;
        end;
    end;

end;

procedure TFileTransfer.PrepareConnection();
var
szHost:array[0..255] of char;
Status:Integer;
sockListen: TSocket;
begin

    if WSAStartup($0101, wsaData) <> 0 then begin
        ShowMessage('TODO: gosh, winsock is not startuping!');
        Exit;
    end;

    StrPCopy(szHost, Host);
    if inet_addr(szHost) = -1 then begin
        Host := GetIPFromHost(Host);
        StrPCopy(szHost, Host);
    end;

    Self.Sock := Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if Self.Sock = INVALId_SOCKET then begin
        ShowMessage('TODO: erro criando socket');
        Exit;
    end;

    FillChar(Self.AddrIn, sizeof(Self.AddrIn), 0);
    with Self.AddrIn do begin
        sin_family := AF_INET;
        sin_port := htons(HostPort);
        sin_addr.S_addr := INADDR_ANY;
        if not Server then sin_addr.s_Addr:= inet_addr(szHost);
    end;

    if not Server then begin
        Status := connect(Sock, Self.AddrIn, sizeof(Self.AddrIn));
        if Status = SOCKET_ERROR then begin
            ShowMessage('TODO: (Status = SOCKET_ERROR) WSAGetLastError() = ' + inttostr(wsagetlasterror()));
            Exit;
        end;
    end
    else begin
        sockListen := Socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if sockListen = INVALID_SOCKET then begin
            ShowMessage('TODO: erro criando sockListen');
            Exit;
        end;
        if bind(sockListen, Self.AddrIn, sizeof(Self.AddrIn)) <> 0 then begin
            ShowMessage('TODO: couldnt bind!');
            Exit;
        end;

        if listen(sockListen, 1) <> 0 then begin
            ShowMessage('TODO: couldnt listen');
            Exit;
        end;

        Self.Sock := accept(sockListen, nil, nil);
        closesocket(sockListen);
        if Self.Sock = SOCKET_ERROR then begin
            ShowMessage('TODO: error accept''ing (Self.Socket = SOCKET_ERROR) WSAGetLastError() = ' + inttostr(wsagetlasterror()));
            Exit;
        end;
    end;

end;


end.
