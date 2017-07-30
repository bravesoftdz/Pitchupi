unit PiUtils;

interface

uses Messages, Winsock, Windows, SysUtils;

    function GetIPFromHost(const HostName: string): string;
    function AddrToHost(AddrIn:TSockAddrIn): string;
    function AdjustSizeStr(numBytes: Integer): string;
    function TimeStr(numSecs: Integer): string;
    procedure SwapBytes(var a:byte; var b:byte);

    const MAXBUF = 4095;

    const WM_ASYNC_SELECT = WM_USER + $01;

    const CTRL_MESG = $01;
    const CTRL_NAME = $02;
    const CTRL_FILE = $03;
    const CTRL_RESM = $04;
    const CTRL_PASS = $05;

    const STAT_WAIT  = $01;
    const STAT_OK    = $02;
    const STAT_READY = $03;
    const STAT_ABRT  = $04;



implementation

procedure SwapBytes(var a:byte; var b:byte);
var
tmp: byte;
begin
    tmp := a;
    a := b;
    b := tmp;
end;

function AddrToHost(AddrIn:TSockAddrIn): string;
begin

    Result := IntToStr(Ord(AddrIn.sa_data[2])) + '.';
    Result := Result + IntToStr(Ord(AddrIn.sa_data[3])) + '.';
    Result := Result + IntToStr(Ord(AddrIn.sa_data[4])) + '.';
    Result := Result + IntToStr(Ord(AddrIn.sa_data[5]));

end;

function AdjustSizeStr(numBytes: Integer): string;
begin

    if numBytes = 0 then begin
        Result := '';
        Exit;
    end;

    if numBytes < $400 then
        Result := FloatToStrF(numBytes, ffGeneral, 4, 0) + ' bytes'
    else if numBytes < $100000 then
        Result := FloatToStrF(numBytes / $400, ffGeneral, 4, 0) + ' KiB'
    else if numBytes < $40000000 then
        Result := FloatToStrF(numBytes / $100000, ffGeneral, 4, 0) + ' MiB'
    else
        Result := FloatToStrF(numBytes / $40000000, ffGeneral, 4, 0) + ' GiB';

    Result := StringReplace(Result, ',', '.', []); //no brazilian look :)

end;

function TimeStr(numSecs: Integer): string;
var
nMeasures: integer;
begin

    nMeasures := 0;
    Result := '';

    if numSecs > 604800 then begin
        Result := IntToStr(numSecs div 604800) + 'w ';
        numSecs := numSecs mod 604800;
        Inc(nMeasures);
    end;

    if numSecs > 86400 then begin
        Result := IntToStr(numSecs div 86400) + 'd ';
        numSecs := numSecs mod 86400;
        Inc(nMeasures);
    end;

    if nMeasures > 1 then begin
        Result := Trim(Result);
        Exit;
    end;

    if numSecs > 3600 then begin
        Result := Result + IntToStr(numSecs div 3600) + 'h ';
        numSecs := numSecs mod 3600;
        Inc(nMeasures);
    end;

    if nMeasures > 1 then begin
        Result := Trim(Result);
        Exit;
    end;

    if numSecs > 60 then begin
        Result := Result + IntToStr(numSecs div 60) + 'm ';
        numSecs := numSecs mod 60;
        Inc(nMeasures);
    end;

    if nMeasures > 1 then begin
        Result := Trim(Result);
        Exit;
    end;

    if numSecs > 0 then begin
        Result := Result + IntToStr(numSecs) + 's';
    end;

end;

function GetIPFromHost(const HostName: string): string;
type
TaPInAddr = array[0..10] of PInAddr;
PaPInAddr = ^TaPInAddr;
var
phe: PHostEnt;
pptr: PaPInAddr;
i: Integer;
GInitData: TWSAData;
begin
    WSAStartup($101, GInitData);
    Result := '';
    phe := GetHostByName(PChar(HostName));
    if phe = nil then Exit;
    pPtr := PaPInAddr(phe^.h_addr_list);
    i := 0;
    while pPtr^[i] <> nil do
    begin
        Result := inet_ntoa(pptr^[i]^);
        Inc(i);
    end;
    WSACleanup;
end;


end.

