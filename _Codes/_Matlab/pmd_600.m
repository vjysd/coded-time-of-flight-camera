function [frames] = pmd_600(steps, num_avgs)

if nargin<1
    steps = 10; 
    disp( sprintf('Using %g Steps') ); 
end

if nargin<2
    num_avgs = 1; 
end

conn = pmd_connect();
tmp = pmd_read_image(conn);

frames = zeros(size(tmp,1),size(tmp,2),steps); 

for ii = 1:steps
    pmd_phase_step(conn, 1);
    thisFrame = zeros(size(frames,1),size(frames,2),num_avgs); 
    for jj=1:num_avgs
        thisFrame(:,:,jj) = pmd_read_image(conn); 
    end
    
    thisFrame = mean(thisFrame,3); 
    frames(:,:,ii) = thisFrame;
    disp(ii);
end
