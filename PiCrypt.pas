unit Picrypt;

interface

uses Windows, SysUtils, Winsock, PiUtils;

type
    TCryptoBox = class(TObject)
        sPass: string;
        IV: DWORD;
        SBox: array[0..255] of byte;
        Initialized: boolean;
        procedure Init();
        procedure Crypt(PBuf: PByte; len: Integer);
        private
        hi, hj: byte;
    end;

    function HashPassword(const PlainPass: string):string;

implementation
{
   ch <- char to encrypt/decrypte
   i = (i + 1) mod 256
   j = (j + state[i]) mod 256
   swap state[i], state[j]
   n = (state[i] + state[j]) mod 256
   encrypted/decrypted char <- state[n] xor ch
}
procedure TCryptoBox.Crypt(PBuf: PByte; len: Integer);
var
i, j, n: byte;
count: Integer;
begin

    if not Initialized then Exit;

    i := hi;
    j := hj;

    for count := 1 to len do begin
        i := (i + 1) mod 256;
        j := (j + SBox[i]) mod 256;
        SwapBytes(SBox[i], SBox[j]);
        n := (SBox[i] + SBox[j]) mod 256;
        PBuf^ := PBuf^ xor SBox[n];
        Inc(PBuf);
    end;

end;


procedure TCryptoBox.Init();
var
KeyIV:array[0..131] of byte;
i,j:integer;
passlen: Integer;
begin
    passlen := Length(Self.sPass);
    if passlen > 128 then passlen := 128;
    Move(Self.sPass[1], KeyIV, passlen);
    Move(Self.IV, KeyIV[passlen], sizeof(DWORD));
    Inc(passlen, sizeof(DWORD));
    for i := 0 to 255 do
        Self.SBox[i] := i;

    j := 0;
    for i := 0 to 255 do
    begin
       j := (j + Self.SBox[i] + KeyIV[i mod passlen]) mod 256;
        SwapBytes(Self.SBox[i], Self.SBox[j]);
    end;
    Self.hi := 0;
    Self.hj := 0;

    FillChar(sPass, Length(sPass) + 1, 0);
    FillChar(KeyIV, sizeof(KeyIV), 0);
    IV :=0;

    Initialized := True;
end;


function HashPassword(const PlainPass: string):string;
var
hash,h2,h3:DWORD;
buf:array[0..255] of byte;
key:array[0..127] of byte;
i,j:integer;
passlen: Integer;
begin

    passlen := Length(PlainPass);
    if passlen > 128 then passlen := 128;
    Move(PlainPass[1], key, passlen);

    for i := 0 to 255 do
        buf[i] := i;

    j := 0;
    for i := 0 to 255 do
    begin
       j := (j + buf[i] + key[i mod passlen]) mod 256;
        SwapBytes(buf[i], buf[j]);
    end;

    Move(buf, hash, 4);
    Move(buf[8], h2, 4);
    Move(buf[16], h3, 4);
    Inc(h2, passlen);
    hash := hash xor h2 xor h3;

    Result := IntToHex(hash, 8);

end;

end.
