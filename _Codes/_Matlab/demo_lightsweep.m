%%%% Light Sweep Movie Demo %%%%
% This basic code is provided to give the reader a dataset to make their own
% nanophotography style videos. The input to this script is the RAW correlation 
% function. The output is a simple visualization with smoothing. Feel free to experiment
% with Tikhonov or alternate smoothing that you prefer. 

% Note: This is a simple file for didactic purposes to show how you can DIY
% a lightsweep movie from the camera data. There is no deconvolution here. 
% Please see 'demo_deconvolution' for that (performed on a single-pixel). 
% We used the same algorithms, but with heavy parallelization (MDCS). 

% For questions please see FAQ on http://nanophoto.info
% Achuta Kadambi, MIT, (achoo@mit.edu) 

norm_mode=1; % Normalization Mode: Set to 1 to divide by 1/sqrt(N) for Unitary DFT. 
cal_mode = 1; % Set to true since physical setup had FPN. 
filename = 'board.mat'; 

%% Load and Calibrate Cross-Correlation Matrix
load(filename); 
rawMean = frames; 

% Camera Calibration due to Fixed Pattern Noise on CMOS. Specifically,
% certain regions of the CMOS have different sensitivities due to minor
% electronic defects in our camera. This may not be an issue if you build your own setup.
% if cal_mode  == 1                     
%     r1_cal_amp = 0.911;
%     r2_cal_amp = 1;
%     r3_cal_amp = 0.95;
%     r4_cal_amp = 0.957;
%     
%     r1_cal_amp = 1;
%     r2_cal_amp = 1;
%     r3_cal_amp = 1;
%     r4_cal_amp = 1;
%     
%     rawMeanCal = rawMean;
%     rawMeanCal(:,1:40,:) = rawMean(:,1:40,:) * r1_cal_amp;
%     rawMeanCal(:,81:120,:) = rawMean(:,81:120,:) * r3_cal_amp;
%     rawMeanCal(:,121:160,:) = rawMean(:,121:160,:) * r4_cal_amp;
%     rawMean = rawMeanCal; 
%     
%     d12 = -7;
%     d23 = -6;
%     d21 = -1; 
%     d24 = -17;
%     
%     rawMeanCal(:,1:40,:) = circshift(rawMean(:,1:40,:),[0 0 d12]);
%     rawMeanCal(:,81:120,:) = circshift(rawMean(:,81:120,:),[0 0 d23]);
%     rawMeanCal(:,121:160,:) = circshift(rawMean(:,121:160,:),[0 0 d24]);
%     rawMean = rawMeanCal;
% end

tmin=2900; % Start Window on Cross-corr Function. This corresponds to physical distances in scene. 
tmax=3300; % Stop Window on Cross-corr Function. This corresponds to physical distances in scene. 
z = rawMean(1:153,1:120,tmin:tmax); % Windowed Cross-corr function. 

%% Kernel Smoother

% Note: Here, a simple kernel smoother is used for simplicity. 

% Note: Alternate techniques, such as Tikhonov can be used instead, performed per pixel. 
% This can get quite computationally intensive, especially when comparing different 
% algorithms (Figure 7 in paper) so we actually took advantage of parallelization (via MDCS). 

for ii=1:size(z,1) 
    for jj=1:size(z,2)
        tmp = squeeze(z(ii,jj,:));
        tmp = smooth(tmp, 0.1, 'loess');
        z(ii,jj,:) = tmp;
    end
end

%% Remove DC Component

dc = mean(z,3); 
dc = repmat(dc, [1 1 size(z,3)]);
z = z - dc; 

%% Normalization and Output

if norm_mode==1 
    z(z<0)=0;
    z = sqrt(z);
else % Alternatively, Divide by Amplitude of Fundamental Frequency Bin. 
    Z = abs(fft(z, [], 3));
    fun = repmat(Z(:,:,2), [1 1 size(z,3)]);
    z = z./fun;
end

z = flipdim(z, 3); 
z = imnorm(z, 1, 100); 
z = uint8(double(z)); 
z = permute(z, [1 2 4 3]); 

mov=immovie(z,colormap('gray')); 
implay(mov); 

%optional
movie2avi(mov,'8-6.avi');