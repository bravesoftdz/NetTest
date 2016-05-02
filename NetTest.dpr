program NetTest;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Winapi.WinSock,
  Winapi.Windows,
  ActiveX,
  ComObj,
  Variants;
function TryIPPort(const IP: AnsiString; Port: integer): Boolean;
var
  Sock                        : TSocket;
  SA                          : TSockaddr;
  n, ul                       : integer;
  TV                          : TTimeVal;
  FDSet                       : TFDSet;
begin
  FillChar(SA, SizeOf(SA), 0);
  SA.sin_family := AF_INET;
  SA.sin_port := htons(Port);
  SA.sin_addr.S_addr := inet_addr(Pointer(IP));
  Sock := Socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  Result := Sock <> invalid_socket;
  if Result then
  begin
    n := 1 * 1000;
    ul := 1;
    if (SetSockopt(Sock, SOL_SOCKET, SO_SNDTIMEO, @n, SizeOf(n)) <> SOCKET_ERROR)
      and (SetSockopt(Sock, SOL_SOCKET, SO_RCVTIMEO, @n, SizeOf(n)) <>
      SOCKET_ERROR) and (ioctlsocket(Sock, FIONBIO, ul) <> SOCKET_ERROR) then
    begin
      Connect(Sock, SA, SizeOf(SA));
      FD_ZERO(FDSet);
      FD_SET(Sock, FDSet);
      TV.tv_sec := 1;
      TV.tv_usec := 0;
      Result := select(0, nil, @FDSet, nil, @TV) > 0;

      if Result and True then
        Result := Send(Sock, SA, 1, 0) = 1;
    end;
    CloseSocket(Sock);
  end;
end;

function GetStatusCodeStr(statusCode:integer) : string;
begin
  case statusCode of
    0     : Result:='Success';
    11001 : Result:='Buffer Too Small';
    11002 : Result:='Destination Net Unreachable';
    11003 : Result:='Destination Host Unreachable';
    11004 : Result:='Destination Protocol Unreachable';
    11005 : Result:='Destination Port Unreachable';
    11006 : Result:='No Resources';
    11007 : Result:='Bad Option';
    11008 : Result:='Hardware Error';
    11009 : Result:='Packet Too Big';
    11010 : Result:='Request Timed Out';
    11011 : Result:='Bad Request';
    11012 : Result:='Bad Route';
    11013 : Result:='TimeToLive Expired Transit';
    11014 : Result:='TimeToLive Expired Reassembly';
    11015 : Result:='Parameter Problem';
    11016 : Result:='Source Quench';
    11017 : Result:='Option Too Big';
    11018 : Result:='Bad Destination';
    11032 : Result:='Negotiating IPSEC';
    11050 : Result:='General Failure'
    else
    result:='Unknow';
  end;
end;

//The form of the Address parameter can be either the computer name (wxyz1234), IPv4 address (192.168.177.124), or IPv6 address (2010:836B:4179::836B:4179).
procedure  Ping(const Address:string;Retries,BufferSize:Word);
var
  FSWbemLocator : OLEVariant;
  FWMIService   : OLEVariant;
  FWbemObjectSet: OLEVariant;
  FWbemObject   : OLEVariant;
  oEnum         : IEnumvariant;
  iValue        : LongWord;
  i             : Integer;

  PacketsReceived : Integer;
  Minimum         : Integer;
  Maximum         : Integer;
  Average         : Integer;
begin;
  PacketsReceived:=0;
  Minimum        :=0;
  Maximum        :=0;
  Average        :=0;
  Writeln('');
  Writeln(Format('Pinging %s with %d bytes of data:',[Address,BufferSize]));
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService   := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', '');
  //FWMIService   := FSWbemLocator.ConnectServer('192.168.52.130', 'root\CIMV2', 'user', 'password');
  for i := 0 to Retries-1 do
  begin
    FWbemObjectSet:= FWMIService.ExecQuery(Format('SELECT * FROM Win32_PingStatus where Address=%s AND BufferSize=%d',[QuotedStr(Address),BufferSize]),'WQL',0);
    oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
    if oEnum.Next(1, FWbemObject, iValue) = 0 then
    begin
      if FWbemObject.StatusCode=0 then
      begin
        if FWbemObject.ResponseTime>0 then
          Writeln(Format('Reply from %s: bytes=%s time=%sms TTL=%s',[FWbemObject.ProtocolAddress,FWbemObject.ReplySize,FWbemObject.ResponseTime,FWbemObject.TimeToLive]))
        else
          Writeln(Format('Reply from %s: bytes=%s time=<1ms TTL=%s',[FWbemObject.ProtocolAddress,FWbemObject.ReplySize,FWbemObject.TimeToLive]));

        Inc(PacketsReceived);

        if FWbemObject.ResponseTime>Maximum then
        Maximum:=FWbemObject.ResponseTime;

        if Minimum=0 then
        Minimum:=Maximum;

        if FWbemObject.ResponseTime<Minimum then
        Minimum:=FWbemObject.ResponseTime;

        Average:=Average+FWbemObject.ResponseTime;
      end
      else
        Writeln(Format('Reply from %s: %s',[FWbemObject.ProtocolAddress,GetStatusCodeStr(FWbemObject.StatusCode)]));
    end;
    FWbemObject:=Unassigned;
    FWbemObjectSet:=Unassigned;
    //Sleep(500);
  end;

  Writeln('');
  Writeln(Format('Ping statistics for %s:',[Address]));
  Writeln(Format('    Packets: Sent = %d, Received = %d, Lost = %d (%d%% loss),',[Retries,PacketsReceived,Retries-PacketsReceived,Round((Retries-PacketsReceived)*100/Retries)]));
  if PacketsReceived>0 then
  begin
   Writeln('Approximate round trip times in milli-seconds:');
   Writeln(Format('    Minimum = %dms, Maximum = %dms, Average = %dms',[Minimum,Maximum,Round(Average/PacketsReceived)]));
  end;
end;


var
  IP,Port:string;
  WSA : TWSAData;
  yn:string;
  label test;
begin
  try

    SetConsoleTitle('�˿ڲ��Թ���'); //����
//    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_BLUE);  //������ɫ
//    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), RGB(100, 200, 255)) ; //��ɫ

    test:
    { TODO -oUser -cConsole Main : Insert code here }
    WriteLn('��������Ҫ����Ŀ�������IP:');
    Readln(IP);
    WriteLn('��������Ҫ���Ե�Ŀ��˿�:');
    Readln(Port);
    WriteLn('����Ping ['+IP+'] ...');
    WriteLn('---------------------------------------------');
    CoInitialize(nil);
    try
      Ping(IP,4,32);
    finally
      CoUninitialize;
    end;
    WriteLn('---------------------------------------------');
    WriteLn('���ڲ��Զ˿���...');
    WSAStartup(MakeWord(2, 2), WSA);
    if TryIPPort(AnsiString(IP),Port.ToInteger()) then
    begin
      WriteLn('�ɹ�, �˿�[' +Port+ '] �ǿ��ŵ�!' );
    end
    else
    begin
       WriteLn('ʧ��, �˿�[' + port +'] δ����!' );
    end;
    WSACleanup;
    WriteLn('---------------------------------------------');
    WriteLn('��Ҫ����������(Y/N):');
    Readln(yn);
    if UpperCase(yn)='Y' then
       goto test;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
