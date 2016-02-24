function pmd_video()
  pmd_conn = pmd_connect();
  
%   % Acquire fixed-pattern noise image
%   waitfor(msgbox('Please cover the lens in order to calibrate the camera.'));
%   
%   % discard first few frames
%   for i = 0:10
%     pmd_read_image(pmd_conn);
%   end
%   fpn = pmd_read_image(pmd_conn);
%   
%   disp('FPN acquired');

  fpn = 0;
  mod_select = 0;
  
%   load('fpn.mat', 'fpn');
%   load('flat.mat', 'flat');
%   avg_val = 0;
%   for i = 1: 120
%       for j= 1: 153
%           avg_val= (flat(i,j) - fpn(i, j))+avg_val;
%       end 
%   end
  
%   avg_valn= avg_val/(120*153);
%   display(avg_val);
  % Setup variables and figures for plotting video
  done = false;

  % Setup script to stop on figure close
  fig_handle = figure;
  set(fig_handle, 'CloseRequestFcn', @on_close);

%   subplot(3,1, 1);
%   colormap(gray);
%   imagesc(fpn);
%   colorbar;
%   title('FPN');
%   
%   subplot(3, 1, 3);
%   colormap(gray);
%   imagesc(flat);
%   colorbar;
%   title('FLAT');

  subplot(1, 1, 1);
  colormap(gray);
  im_handle = 0;
  while ~done
    % Acquire image, subtract FPN
    frame = process_frame(pmd_read_image(pmd_conn));
%     frame = process_frame(pmd_read_image(pmd_conn));
    
%     c = 3e8;
%     f_mod = 15e6;
%     frame = (c / (4*pi*f_mod)) * atan((frame_270 - frame_90) ./ (frame_180 - frame_0));
%     frame(frame < 0) = 0;
%     mean2(frame)
%     To plot the FFt of the Image frames
%      F = fft(frame, [], 3);
%      F = angle(F);% Get the magnitude

    % If the image plot has already been created, update its CData instead
    if im_handle == 0
      im_handle = imagesc(frame);
      colorbar;
       imcontrast;
      title('PMD video');
    else
      set(im_handle, 'CData', frame);
    end
    
    drawnow;
  end

  function on_close(src, event)
    done = true;
    delete(fig_handle);
    disp('Main figure window was closed, stopping script.');
  end
  
  function new_frame = process_frame(frame)
  
     new_frame = frame; 
%       new_frame = frame - fpn;
%      pause(0.1);
%     new_frame = frame;
  end

  
end

