function pmd_set_integration_time(conn, integration_time)

fwrite(conn, 'W');
fwrite(conn, 1, 'uint8');
fwrite(conn, integration_time, 'uint32');

end

