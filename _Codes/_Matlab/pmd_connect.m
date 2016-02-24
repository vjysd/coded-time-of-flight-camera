function conn = pmd_connect()
  conn = tcpip('18.85.54.78', 30);
  conn.InputBufferSize = 19440*2;
  conn.ByteOrder = 'littleEndian';
  conn.Timeout = 60*10;
  fopen(conn);
end