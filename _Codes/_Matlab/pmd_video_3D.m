function pmd_video_3D() 
    pmd_conn = pmd_connect();
    
     % Setup variables and figures for plotting video
  done = false;

  % Setup script to stop on figure close
  fig_handle = figure;
  set(fig_handle, 'CloseRequestFcn', @on_close);

  subplot(2,1, 1);
  amplitude_handle = imagesc(pmd_read_image(pmd_conn));
  colorbar;
  colormap(gray);
  title('Amplitude');
  
  subplot(2, 1, 2);
  colormap(jet);
  phase_handle = imagesc(pmd_read_image(pmd_conn));
  colorbar;
  title('Distance');

  while true
      frame_0 = pmd_read_image(pmd_conn);
      phase_step_90();
      frame_90 = pmd_read_image(pmd_conn);
      phase_step_90();
      frame_180 = pmd_read_image(pmd_conn);
      phase_step_90();
      frame_270 = pmd_read_image(pmd_conn);
      phase_step_90();
      
      c = 3e8;
      f_mod = 35e6;
      phase_image = (c / (4*pi*f_mod)) * atan((frame_270 - frame_90) ./ (frame_180 - frame_0));
      amplitude_image = sqrt((frame_270 - frame_90).^2 + (frame_180 - frame_0).^2)/2;

      set(phase_handle, 'CData', phase_image);
      set(amplitude_handle, 'CData', amplitude_image);
      
      drawnow;
  end
  
  function phase_step_90()
      pmd_phase_step(pmd_conn, 70);
  end

  function on_close(src, event)
    done = true;
    delete(fig_handle);
    disp('Main figure window was closed, stopping script.');
  end

end