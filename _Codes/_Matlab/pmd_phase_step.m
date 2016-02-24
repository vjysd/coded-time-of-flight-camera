function pmd_phase_step( conn, steps)
% Increments the phase by the given number of steps

fwrite(conn, 'W');
fwrite(conn, 3, 'uint8');
fwrite(conn, steps, 'uint32');

end

