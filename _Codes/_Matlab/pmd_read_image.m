function frame = pmd_read_image(conn)
  width = 162;
  height = 120;
  
  fwrite(conn, 'R');
  fwrite(conn, 0);

  raw_data = fread(conn, width*height, 'uint16');
 
  frame = reshape(raw_data, width, height)';
  frame = flipud(frame);
  frame = frame(:, 10:end);
  frame = rot90(frame, 3);
end
