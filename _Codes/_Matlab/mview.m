function handle = mview(varargin)
%
% function handle = mview(seq1,seq2,...,keywords,...)
%
% functionality
%   - display images or sequences in a window
%   - each mview argument may be a filespec or a matrix
%       - file formats support .mat, .pgm, and anything else imread accepts
%       - filespec may be of the form filename[expr], where expr is a
%       matlab subscripting expression applied to the result of reading
%       filename
%
% input:
%   - mview1,mview2,...: each mview argument may be a filespec or a matrix
%       - file formats support .mat, .pgm, and anything else imread accepts
%       - filespec may be of the form filename[expr], where expr is a
%       matlab subscripting expression applied to the result of reading
%       filename
%   - keywords: entered as name/value pairs
%       - mview(...,'CLim',[cmin cmax]): fixes the image scaling (see CAXIS),
%       default is autoranging
%       - mview(...,'Colormap',cmap): sets the colormap to given M*3 matrix
%       or a named colormap (see COLORMAP), default is 'jet'
%       - mview(...,'imformat',imformat): Set the displayed image format,
%       default = 'scale'.  Options include: '1:1','scale','stretch'
%       - mview(...,'showNaN',shownan): Show NaNs in a different color, with
%       proper colormap rescaling (be careful when setting your own limits)
%       default = true
%       - mview(...,'base',displayBase): Set displayed output format base
%       default = 'decimal'. Options include:
%         'decimal',10,'hex',16,'binary',2
%       - mview(...,'titles',titles): Explicitly specify slide titles.
%       default = "[slide #]".  If titles is a single element, slides will
%       have a title of "title[slide#]".  If titles matches the number of
%       slides, each slide will take its respective title.  If the number
%       of titles is not equal to the number of slides, each will be
%       matched 1:1 until either slides or titles are exhausted.
%
%
%
% output:
%   - handle: handle to the figure window
%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% $Id: seq.m,v 1.46 2012/03/28 00:33:39 mifenton Exp $
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Canesta Confidential Information
%
% (c) Copyright Canesta, Inc. 2008. All Rights Reserved
% Licensed Materials - Property of Canesta, Inc.
%
% This code is provided AS-IS; there is NO WARRANTY,
% expressed or implied.
%
% THE CONTENTS OF THIS FILE MAY NOT BE COPIED
% NOR DISTRIBUTED TO ANY OTHER PARTY, PURSUANT
% TO THE TERMS OF THE PREVAILING LICENSING AGREEMENT.
%
% THIS COPYRIGHT STATEMENT MUST NOT BE ALTERED NOR REMOVED
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin==0
    [fname,fpath] = uigetfile('*.*','Load Image or Sequence');
    if (fname==0), return; end
    if ischar(fname), varargin = {[fpath fname]}; end
    uData.fpath = fpath;
end

clf

% have a preference?  set it here!
% cmap = 'gray';   % Default is gray
% clim = [];   % Default is automatic scaling
% imformat = 'stretch'; %default is stretch to fit
% showNaN = false;

%  My prefs are:
cmap = 'jet';   % Default is jet
clim = [];   % Default is automatic scaling
imformat = 'scale'; %default is scale to fit
showNaN = true;
displayBase = 10;

seqFig = gcf;
set(seqFig,'toolBar','figure'); %always show figure toolbar

% Load images into image objects
uData.imglist = [];  % List of image object uData
uData.KeyPress = [];
titles = {};

% for loading up images
frameCtr = 1;

%hide the axis for now, in case there's a struct to choose from...
ax = axes('nextplot','add','box','on','visible','off'); 

% Parse arguments
while ~isempty(varargin)
    arg = varargin{1};
    varargin = varargin(2:end);  % shift

    if ~ischar(arg)
        fname = '';
        uData.fpath = pwd;
        img = arg;
        
    elseif strcmpi(arg,'imformat')
        imformat = varargin{1};
        varargin = varargin(2:end);  % shift
        continue;
        
    elseif strcmpi(arg,'CLim')
        clim = varargin{1};
        varargin = varargin(2:end);  % shift
        continue;

    elseif strcmpi(arg,'Colormap')
        cmap = varargin{1};
        varargin = varargin(2:end);  % shift
        continue;

    elseif strcmpi(arg,'showNaN')
        showNaN = varargin{1};
        varargin = varargin(2:end);  % shift
        continue; 
        
    elseif strcmpi(arg,'base')
        displayBase = varargin{1};
        varargin = varargin(2:end);  % shift
        continue; 
        
    elseif strcmpi(arg,'titles')
        titles = varargin{1};
        varargin = varargin(2:end);  % shift
        continue;     
        
    else
        fname = arg;
        % Parse fname -> file[subscripts]
        k = find(fname=='[');
        if ~isempty(k)
            subscripts = fname(k(end)+1:end-1);
            file = fname(1:k(end)-1);
        else
            subscripts = '';
            file = fname;
        end

        % Parse file -> fpath/basename.ext
        [fpath,~,ext] = fileparts(file);
        uData.fpath = fpath;

        if strcmpi(ext,'.pgm')
            img = loadpgm(file,'*'); % * means load into native datatype
        elseif strcmpi(ext,'.ppm')
            img = loadppm(file,'*'); % * means load into native datatype
        elseif strcmpi(ext,'.mat')
            img = load(file);
        else img = imread(file);
        end

        % Apply subscripting expressions
        if ~isempty(subscripts)
            eval(['img = img' subscripts ';']);
        end

    end

    % Prompt user to select one field from a struct
    while isstruct(img)
        choices = fieldnames(img);
        h = uicontrol(seqFig,'style','popupmenu','String',choices,'Value',1,...
            'Units','Normalized','Position',[.1 .1 .8 .2],'Callback','uiresume');
        uiwait(seqFig);  % wait until something is chosen
        c = get(h,'Value');
        delete(h);
        img = img.(choices{c});
    end     

    namestr = sprintf('%s',fname);
    imgstruct = struct('name',namestr,'clim',[0 1]);
    
    if iscell(img)
        for i=1:numel(img)  % Each cell element is a separate frame
            fimg = img{i};
            [h,w,d] = size(fimg);
            if d==3 && strcmp(class(fimg),'uint8')  % 3-channel byte image: assume color                
                imghandle = image(1:w,1:h,fimg,'parent',ax);
                minval = min(vec(fimg));
                maxval = max(vec(fimg));
                
                if (minval == -Inf) || (maxval == Inf)
                    temp = currentImage;
                    temp(currentImage == -Inf) = NaN;
                    temp(currentImage == Inf) = NaN;
                    vt = vec(temp);
                    minval = double(min(vt));
                    maxval = double(max(vt));
                end
                
                if isnan(minval) %if minval == NaN, all points are NaN
                    imgstruct.clim = [0 1];
                elseif (minval == maxval) %all points are the same & non-NaN                 
                    imgstruct.clim = [minval-1 minval+1];
                else
                    imgstruct.clim = [minval maxval];
                end
                set(imghandle,'UserData',imgstruct);
                set(imghandle,'visible','off');
                uData.imglist(frameCtr) = imghandle; 
            else
                for j=1:d
                    currentImage = fimg(:,:,j);
                    imghandle = imagesc(1:w,1:h,currentImage,'parent',ax);
                    minval = double(min(vec(currentImage)));
                    maxval = double(max(vec(currentImage)));
                    
                    if (minval == -Inf) || (maxval == Inf)
                        temp = currentImage;
                        temp(currentImage == -Inf) = NaN;
                        temp(currentImage == Inf) = NaN;
                        vt = vec(temp);
                        minval = double(min(vt));
                        maxval = double(max(vt));
                    end
                    
                    if isnan(minval) %if minval == NaN, all points are NaN
                        imgstruct.clim = [0 1];
                    elseif (minval == maxval) %all points are the same & non-NaN                 
                        imgstruct.clim = [minval-1 minval+1];
                    else
                        imgstruct.clim = [minval maxval];
                    end
                    set(imghandle,'UserData',imgstruct);
                    set(imghandle,'visible','off');
                    uData.imglist(frameCtr) = imghandle;
                    frameCtr = frameCtr + 1;
                end
            end                                   
        end
    else
        [h,w,d,f] = size(img);
        if d==3 && strcmp(class(img),'uint8')  % 3-channel byte image: assume color
            for i=1:f % Each plane is a separate 3-channel frame
                currentImage = img(:,:,:,i);
                imghandle = image(1:w,1:h,currentImage,'parent',ax);      
                minval = double(min(vec(currentImage)));
                maxval = double(max(vec(currentImage)));
                
                if (minval == -Inf) || (maxval == Inf)
                    temp = currentImage;
                    temp(currentImage == -Inf) = NaN;
                    temp(currentImage == Inf) = NaN;
                    vt = vec(temp);
                    minval = double(min(vt));
                    maxval = double(max(vt));
                end
                
                if isnan(minval) %if minval == NaN, all points are NaN
                    imgstruct.clim = [0 1];
                elseif (minval == maxval) %all points are the same & non-NaN                 
                    imgstruct.clim = [minval-1 minval+1];
                else
                    imgstruct.clim = [minval maxval];
                end
                set(imghandle,'UserData',imgstruct);
                set(imghandle,'visible','off');
                uData.imglist(frameCtr) = imghandle;
                frameCtr = frameCtr + 1;
            end
        else            
            for i=1:d   % Each plane is a separate frame
                currentImage = img(:,:,i);
                imghandle = imagesc(1:w,1:h,currentImage,'parent',ax);
                minval = double(min(vec(currentImage)));
                maxval = double(max(vec(currentImage)));
                
                if (minval == -Inf) || (maxval == Inf)
                    temp = currentImage;
                    temp(currentImage == -Inf) = NaN;
                    temp(currentImage == Inf) = NaN;
                    vt = vec(temp);
                    minval = double(min(vt));
                    maxval = double(max(vt));
                end
                
                if isnan(minval) %if minval == NaN, all points are NaN
                    imgstruct.clim = [0 1];
                elseif (minval == maxval) %all points are the same & non-NaN                 
                    imgstruct.clim = [minval-1 minval+1];
                else
                    imgstruct.clim = [minval maxval];
                end
                set(imghandle,'UserData',imgstruct);
                set(imghandle,'visible','off');
                uData.imglist(frameCtr) = imghandle;
                frameCtr = frameCtr + 1;
            end
        end
    end
end

set(ax,'visible','on');
set(ax,'xlim',[0.5 w+0.5]);
set(ax,'ylim',[0.5 h+0.5]);
set(ax,'ydir','reverse');
htitle = get(ax,'title');
set(get(ax,'title'),'interpreter','none');
hxlabel = get(ax,'xlabel');
set(get(ax,'xlabel'),'interpreter','none');
if strcmpi(imformat,'scale')
    set(ax,'DataAspectRatio',[w h 1]);
elseif strcmpi(imformat,'stretch')
    set(ax,'DataAspectRatio',[1 1 1]);
elseif strcmpi(imformat,'1:1')
    set(ax,'DataAspectRatio',[w h 1]);
    oldunits = get(ax,'units');
    set(ax,'units','pixels');
    fullpos = get(ax,'OuterPosition');
    axSize = fullpos(3:4)-fullpos(1:2)+1;
    spaceSize = (axSize-[w h])./2;
	% weird bug -- there is image stretching with pos(3:4) = [w h]
    set(ax,'position',[fullpos(1:2)+spaceSize w-1 h-1]);
    set(ax,'units',oldunits);
else
    imformat = 'scale';
    set(ax,'DataAspectRatio',[w h 1]);
end
set(ax,'PlotBoxAspectRatioMode','auto');

set(ax,'nextplot','replace');

if showNaN
    colormap(cmap);  
%     colormapNaN(cmap);   % Set figure's colormap
else
    colormap(cmap);   % Set figure's colormap
end

% Make frame 1 visible
uData.ax = ax;
uData.cmap = cmap;
uData.fnum = 1;
uData.imformat = imformat;
uData.showNaN = showNaN;
uData.stepdir = 1;  % Last step direction +1 or -1
uData.fps = 30;      % Frame rate for Run function
uData.clim = clim;
uData.w = w;
uData.h = h;
uData.htitle = htitle;
uData.hxlabel = hxlabel;

if ~iscell(titles)
    titles = {titles};
end

ntitles = numel(titles);
nframes = frameCtr-1;

% is this needed??
if isempty(titles)
    titles = cell(1,nframes);
    for i=1:nframes
        titles{i} = sprintf('%s[%d]',fname,i);
    end
elseif (ntitles==1)
    onlyTitle = titles{1};
    titles = cell(1,nframes);
    for i=1:nframes
        titles{i} = sprintf('%s[%d]',onlyTitle,i);
    end
elseif (ntitles < nframes)
    origTitle = titles;
    titles = cell(1,nframes);
    for i=1:ntitles
        titles{i} = origTitle{i};
    end
    for i=(ntitles+1):nframes
        % options: use old seq style naming
        titles{i} = sprintf('%s[%d]',fname,i);
        % keep blank
%         titles{i} = '';
    end
end

uData.titles = titles;

switch displayBase
    case {2,'binary'}
        displayBase = 2;
    case {10,'decimal'}
        displayBase = 10;
    case {16,'hex'}
        displayBase = 16;
    otherwise
        displayBase = 10;
end
    

axData.displayBase = displayBase;
set(ax,'UserData',axData);

% Menu bar functions
h = uimenu('Label','Play');   % Menu on menu bar
uimenu(h,'Label','Goto frame ...','Callback',@seq_goto,'Accelerator','g');
uimenu(h,'Label','Colormap limits ...','Callback',@seq_caxis);
uimenu(h,'Label','Run','Callback',@seq_run,'Accelerator','r');
uimenu(h,'Label','Frame rate','Callback',@seq_fps,'Accelerator','f');

h = uimenu('Label','Record');   % Menu on menu bar
uimenu(h,'Label','Compression','Checked','on','Tag','compression','Callback',@seq_compress);
uimenu(h,'Label','Create .AVI file...','Callback',@seq_avi);
uimenu(h,'Label','Save Data to Matlab Variable','Callback',@seq_saveToWorkspace,'Separator','on');
uimenu(h,'Label','Save Data to Images','Callback',@seq_saveToImages);

h = uimenu('Label','Image Options');
hBar1t1 = uimenu(h,'Label','1:1','checked','off','Callback',@oneToOneMapping);
hBarScale = uimenu(h,'Label','Scale to Fit','checked','off','Callback',@scaleToFit);
hBarStretch = uimenu(h,'Label','Stretch to Fit','checked','off','Callback',@stretchToFit);

if strcmpi(imformat,'scale')
    set(hBarScale,'checked','on');
elseif strcmpi(imformat,'stretch')
    set(hBarStretch,'checked','on');
elseif strcmpi(imformat,'1:1')
    set(hBar1t1,'checked','on');
else
    set(hBarScale,'checked','on');
end

hBarBin = uimenu(h,'Label','Binary Display','Separator','on','Checked','off','Callback',@binDisp_func);
hBarDec = uimenu(h,'Label','Decimal Display','Checked','off','Callback',@decDisp_func);
hBarHex = uimenu(h,'Label','Hex Display','Checked','off','Callback',@hexDisp_func);
   
hShowNaN = uimenu(h,'Label','ShowNaN','Separator','on','Checked','on','Callback',@shownan_func);

if ~showNaN
    set(hShowNaN,'checked','off');    
end

switch displayBase
    case 2
        set(hBarBin,'checked','on');
    case 10
        set(hBarDec,'checked','on');
    case 16
        set(hBarHex,'checked','on');
    otherwise
        set(hBarDec,'checked','on');
end

uData.hBar1t1 = hBar1t1;
uData.hBarScale = hBarScale;
uData.hBarStretch = hBarStretch;
uData.hBarBin = hBarBin;
uData.hBarDec = hBarDec;
uData.hBarHex = hBarHex;

set(seqFig,'UserData',uData);

set(seqFig,'Pointer','crosshair')

set(seqFig, 'KeyPressFcn',{@KeyPress,'Press'});
set(seqFig, 'KeyReleaseFcn',{@KeyPress,'Release'});
set(seqFig, 'WindowScrollWheelFcn',@seq_scroll);
set(seqFig, 'ResizeFcn',@seq_resize);
set(seqFig, 'renderer','opengl');

showimg(uData,1);

% Setup callbacks
set(seqFig,'WindowButtonMotionFcn',@seq_move);
set(seqFig,'WindowButtonDownFcn',@seq_click);
% set(gca,'DeleteFcn',@seq_cleanup);
set(seqFig,'DeleteFcn',@seq_cleanup);

% Protect GUI from being accidentally overwritten by plotting commands,
% by making handle invisible.
% But return handle if user really wants to know it.
if nargout>0, handle = seqFig; end
drawnow;
% set(gcf,'HandleVisibility','callback');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function showimg(uData,newfnum)

% Get current frame, make invisible
imghandle = uData.imglist(uData.fnum);
set(imghandle,'Visible','off');

% Make new frame visible
imghandle = uData.imglist(newfnum);

if isfield(uData,'fnum')
    uData.fnum = newfnum;
end

if isfield(uData,'titles')
    title = uData.titles{newfnum};
else
    if isfield(uData,'name')
        fname = uData.name;
    else
        fname = '';
    end
    title = sprintf('%s[%d]',fname,newfnum);
end

uData = get(imghandle,'UserData');
set(imghandle,'Visible','on');
axh = get(imghandle,'Parent'); %axes handle
figh = get(axh,'Parent'); %fig handle
figUData = get(figh,'UserData');

if isfield(figUData,'showNaN')
    if figUData.showNaN
        div = size(colormap,1);
        if isempty(figUData.clim)        
            oldclm = uData.clim;

        else
            oldclm = figUData.clim;
        end
        newMinClm = (oldclm(1)*div - oldclm(2))/(div-1);
        %tiny offset to make sure old min value chooses proper color, not black
        set(axh,'clim',[newMinClm-0.00000001 oldclm(2)]);
    else
        if isempty(figUData.clim)
            set(axh,'clim',uData.clim);
        else
            set(axh,'clim',figUData.clim);
        end
    end
else
    if isfield(figUData,'clim')
        if isempty(figUData.clim)
            set(axh,'clim',uData.clim);
        else
            set(axh,'clim',figUData.clim);
        end
    else
        error('No clim in figUdata!!');
    end
end
    
    
set(figUData.htitle,'string',title);    
seq_cursorinfo(imghandle);

%%%%%%%%%%%%%%% Callbacks %%%%%%%%%%%%%%

function seq_move(hObject, ~, ~)
% figure WindowButtonMoveFcn callback

fig = hObject;
uData = get(fig,'UserData');

% Get current frame
imghandle = uData.imglist(uData.fnum);

if ishandle(imghandle)
    seq_cursorinfo(imghandle);
else
    % The imghandle has disappeared because the figure has been overwritten
    % Turn off the seq callbacks, otherwise errors will occur
    set(fig,'WindowButtonMotionFcn','');
    set(fig,'WindowButtonDownFcn','');
    set(fig,'UserData',[]);
    set(fig,'Pointer','default')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_click(~,~,~)
% figure WindowButtonDownFcn callback
% Called with gcbo = figure object

fig = gcbf;
uData = get(fig,'UserData');

nframes = length(uData.imglist);
% Compute new frame number
but = get(fig,'SelectionType');
if strcmp(but,'normal') &&  isempty(uData.KeyPress)   % Left button => forward
    uData.stepdir = 1;
elseif strcmp(but,'alt')   % Right button => backward
    uData.stepdir = -1;
elseif strcmp(but,'normal') &&  strcmp(uData.KeyPress.Key, 'r')
    % hold r, left click => plot along row    
    uData.KeyPress = [];
    uData.stepdir = 0;

    ax = get(uData.imglist(1),'Parent'); % axes handle
    cursor = get(ax,'CurrentPoint'); % get point

    % only get x and y from first image
    y = round(cursor(1,2));

    %clamp to image extents
    [rows cols colors] = size(get(uData.imglist(1),'CData'));
    y = min(rows, max(y,1));
    if colors==1 %intensity data
        tmpCData = get(uData.imglist(uData.fnum),'CData');
        
        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'row';
            legendstr = {};
        elseif strcmp(uData.figType,'row')
            if ishandle(uData.PlotFig) && ishandle(uData.PlotAx)
                legendstr = guidata(uData.PlotFig);
            else
                uData.PlotFig = figure;
                figpos = get(uData.PlotFig,'position');
                set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
                uData.PlotAx = axes;
                figure(fig);
                uData.figType = 'row';
                legendstr = {};
            end
        else
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'row';
            legendstr = {};
        end
        
        nPlots = length(get(uData.PlotAx,'children')) + 1;   
        bM = circshift(dec2bin(bitshift(nPlots, 3)),[0 3]);
        cVal = ([str2double(bM(end-2)) str2double(bM(end-1)) str2double(bM(end))]);        
        
        plot(uData.PlotAx,1:cols,tmpCData(y,:),'-r.','color',cVal);        
        xlabel(uData.PlotAx,'Column');
        ylabel(uData.PlotAx,'Value');        
        
        title(uData.PlotAx,'Values Along Row');  
        legendstr{length(legendstr)+1} = sprintf('Frame %d, Row %d',uData.fnum,y);
                
        hold(uData.PlotAx,'on');
        grid(uData.PlotAx,'on');
        legend(uData.PlotAx,legendstr);
        guidata(uData.PlotFig,legendstr);
    elseif colors==3 %RGB data
        tmpCData = get(uData.imglist(uData.fnum),'CData');
        plotVec = squeeze(tmpCData(y,:,:));

        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'rowRGB';
        elseif ~strcmp(uData.figType,'rowRGB')
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'rowRGB';
        end        
        
        plot(uData.PlotAx,1:cols,plotVec(:,1),'-r.',...
            1:cols,plotVec(:,2),'-g.',1:cols,plotVec(:,3),'-b.');
        xlabel(uData.PlotAx,'Column');
        ylabel(uData.PlotAx,'Value');
        title(uData.PlotAx,sprintf('Values (Frame %d, Row %d)',uData.fnum,y));
        grid(uData.PlotAx,'on');
    end
elseif strcmp(but,'normal') &&  strcmp(uData.KeyPress.Key, 'c')
    % hold c, left click => plot along columns
    uData.KeyPress = [];
    uData.stepdir = 0;

    ax = get(uData.imglist(1),'Parent'); % axes handle
    cursor = get(ax,'CurrentPoint'); % get point

    % only get x and y from first image
    x = round(cursor(1,1));

    %clamp to image extents
    [rows cols colors] = size(get(uData.imglist(1),'CData'));
    x = min(cols, max(x,1));
    if colors==1 %intensity data
        tmpCData = get(uData.imglist(uData.fnum),'CData');

        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'col';
            legendstr = {};
        elseif strcmp(uData.figType,'col')
            if ishandle(uData.PlotFig) && ishandle(uData.PlotAx)
                legendstr = guidata(uData.PlotFig);
            else
                uData.PlotFig = figure;
                figpos = get(uData.PlotFig,'position');
                set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
                uData.PlotAx = axes;
                figure(fig);
                uData.figType = 'col';
                legendstr = {};
            end
        else
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'col';
            legendstr = {};
        end
           
        nPlots = length(get(uData.PlotAx,'children')) + 1;        
        bM = circshift(dec2bin(bitshift(nPlots, 3)),[0 3]);
        cVal = ([str2double(bM(end-2)) str2double(bM(end-1)) str2double(bM(end))]);
        
        plot(uData.PlotAx,tmpCData(:,x),1:rows,'-r.','color',cVal);
        legendstr{length(legendstr)+1} = sprintf('Frame %d, Column %d',uData.fnum,x);
        set(uData.PlotAx,'ydir','reverse');
        xlabel(uData.PlotAx,'Value');
        ylabel(uData.PlotAx,'Row');
        
        title(uData.PlotAx,'Values Along Column');        
        hold(uData.PlotAx,'on'); 
        grid(uData.PlotAx,'on');
        legend(uData.PlotAx,legendstr);
        guidata(uData.PlotFig,legendstr);        
    elseif colors==3 %RGB data
        tmpCData = get(uData.imglist(uData.fnum),'CData');
        plotVec = squeeze(tmpCData(:,x,:));
        
        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'colRGB';
        elseif ~strcmp(uData.figType,'colRGB')
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'colRGB';
        end
        
        plot(uData.PlotAx,plotVec(:,1),1:rows,'-r.',...
            plotVec(:,2),1:rows,'-g.',plotVec(:,3),1:rows,'-b.');
        xlabel(uData.PlotAx,'Column');
        ylabel(uData.PlotAx,'Value');
        title(uData.PlotAx,'Values Across Columns');
        grid(uData.PlotAx,'on');
    end
elseif strcmp(but,'extend')   % Shift + left button => plot along 3rd dim
    ax = get(uData.imglist(1),'Parent'); % axes handle
    cursor = get(ax,'CurrentPoint'); % get point
    uData.stepdir = 0;

    % only get x and y from first image
    x = round(cursor(1,1));
    y = round(cursor(1,2));

    %clamp to image extents
    [rows,cols,colors] = size(get(uData.imglist(1),'CData'));
    x = min(cols, max(x,1));
    y = min(rows, max(y,1));
    if colors==1 %intensity data
        for k=nframes:-1:1
            tmpCData = get(uData.imglist(k),'CData');
            plotVec(k) = tmpCData(y,x);
        end
        
        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'time';
            legendstr = {};
        elseif strcmp(uData.figType,'time')
            if ishandle(uData.PlotFig) && ishandle(uData.PlotAx)
                legendstr = guidata(uData.PlotFig);
            else
                uData.PlotFig = figure;
                figpos = get(uData.PlotFig,'position');
                set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
                uData.PlotAx = axes;
                figure(fig);
                uData.figType = 'time';
                legendstr = {};
            end
        else
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'time';
            legendstr = {};
        end
        
        nPlots = length(get(uData.PlotAx,'children')) + 1;
        bM = circshift(dec2bin(bitshift(nPlots, 3)),[0 3]);
        cVal = ([str2double(bM(end-2)) str2double(bM(end-1)) str2double(bM(end))]);
        
        plot(uData.PlotAx,1:nframes,plotVec,'.-','color',cVal);
        legendstr{length(legendstr)+1} = sprintf('Column %d, Row %d',x,y);
        hold(uData.PlotAx,'on'); 
        grid(uData.PlotAx,'on');
        
        legend(uData.PlotAx,legendstr);
        guidata(uData.PlotFig,legendstr);  
    elseif colors==3 %RGB data
        for k=nframes:-1:1
            tmpCData = get(uData.imglist(k),'CData');
            plotVec(k,:) = squeeze(tmpCData(y,x,:));
        end
        
        if ~isfield(uData, 'PlotFig');
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'timeRGB';
        elseif ~strcmp(uData.figType,'timeRGB')
            uData.PlotFig = figure;
            figpos = get(uData.PlotFig,'position');
            set(uData.PlotFig,'position',figpos+[50 -50 0 0]);
            uData.PlotAx = axes;
            figure(fig);
            uData.figType = 'timeRGB';
        end
        
        plot(uData.PlotAx,1:nframes,plotVec(:,1),'r.-',...
            1:nframes,plotVec(:,2),'g.-',1:nframes,plotVec(:,3),'b.-');
        grid(uData.PlotAx,'on');
    end
    xlabel(uData.PlotAx,'Frame');
    ylabel(uData.PlotAx,'Value');
    title(uData.PlotAx,'Values Over Frames');
    set(gcbo,'UserData',uData);
end
newfnum = rem(uData.fnum+nframes+uData.stepdir,nframes);

if newfnum == 0
    newfnum = nframes;
end

if uData.fnum ~= newfnum    
    showimg(uData,newfnum);
    
    % Save new frame number
    uData.fnum = newfnum;    
end
set(gcbo,'UserData',uData);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_goto(~, ~, ~)
% figure menu callback

fig = gcbf;
uData = get(fig,'UserData');
nframes = length(uData.imglist);

% Prompt for new frame#
sfnum = inputdlg('Frame#','Goto Frame',1,{num2str(uData.fnum)});
if isempty(sfnum), return; end  % user pressed cancel
newfnum = str2double(sfnum{1});
% Ignore invalid frame#
if newfnum~=round(newfnum) || newfnum<1 || newfnum > nframes, return; end

showimg(uData,newfnum);

% Save new frame number
uData.fnum = newfnum;
set(fig,'UserData',uData);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_caxis(~, ~, ~)
% figure menu callback

% Prompt for new axis#
hfig = gcbf;
uData = get(hfig,'UserData');
if isempty(uData.clim)
    scaxis = inputdlg('min max','Colormap Limits',1,{num2str(caxis)});
else
    scaxis = inputdlg('min max','Colormap Limits',1,{num2str(uData.clim)});
end
if isempty(scaxis), return; end  % user pressed cancel
newcaxis = str2num(scaxis{1});

% Illegal caxis limits => auto scaling
if length(newcaxis)~=2    
    uData.clim = [];
    set(hfig,'UserData',uData);
    caxis('auto');
else    
    uData.clim = newcaxis;
    if uData.showNaN
        div = size(colormap,1);
        oldclm = newcaxis;
        newMinClm = (oldclm(1)*div - oldclm(2))/(div-1);
        %tiny offset to make sure old min value chooses proper color, not NaN
        newclm = [newMinClm-0.00000001 oldclm(2)];    
        caxis(newclm);
    else
        caxis(newcaxis);
    end
    
    set(hfig,'UserData',uData);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_run(~, ~, ~)
% figure menu callback
% Called with gcbo = menu item

cbo = gcbo;

if strcmp(get(cbo,'Checked'),'on')
    set(cbo,'Checked','off')
    return
end

set(cbo,'Checked','on')
fig = gcbf;
uData = get(fig,'UserData');
nframes = length(uData.imglist);

set(fig,'WindowButtonDownFcn',''); %ignore clicks while running
tic;
cumulativePlotTime = 0;
cumulativeWaitTime = 1/uData.fps;
cumulativeFrames = 0;
measuredFramerate = uData.fps;
while strcmp(get(cbo,'Checked'),'on')
    % Compute new frame number
    newfnum = rem(uData.fnum+nframes+uData.stepdir,nframes);
    if newfnum == 0
        newfnum = nframes;
    end
    
    showimg(uData,newfnum);
%         % Get current frame, make invisible
%         imghandle = uData.imglist(uData.fnum);
%         set(imghandle,'Visible','off');
% 
%         % Make new frame visible
%         uData.fnum = newfnum;
%         imghandle = uData.imglist(uData.fnum);
%         imgData = get(imghandle,'UserData');
%         fname = imgData.name;
%         set(imghandle,'Visible','on');
%         axh = uData.ax;
%         if uData.showNaN
%             div = size(colormap,1);
%             if isempty(uData.clim)        
%                 oldclm = imgData.clim;
%             else
%                 oldclm = uData.clim;
%             end
%             newMinClm = (oldclm(1)*div - oldclm(2))/(div-1);
%             %tiny offset to make sure old min value chooses proper color, not black
%             set(axh,'clim',[newMinClm-0.00000001 oldclm(2)]);
%         else
%             if isempty(uData.clim)
%                 set(axh,'clim',imgData.clim);
%             else
%                 set(axh,'clim',uData.clim);
%             end
%         end
% 
    oldtitle = get(uData.htitle,'string');
    set(uData.htitle,'string',sprintf('%s, FPS: %3.1f',oldtitle,measuredFramerate));    
%         seq_cursorinfo(imghandle); 
    drawnow;
    uData = get(fig,'userdata');

    uData.fnum = newfnum;
    plotTime = toc;   
    waitTime = 1/uData.fps-plotTime;
    cumulativePlotTime = cumulativePlotTime+plotTime;
    cumulativeWaitTime = cumulativeWaitTime+max(waitTime,0);
    cumulativeFrames = cumulativeFrames + 1;
    if cumulativePlotTime > 0.1
        measuredFramerate = cumulativeFrames./(cumulativePlotTime+cumulativeWaitTime);
        cumulativePlotTime = plotTime;
        cumulativeWaitTime = max(waitTime,0);
        cumulativeFrames = 1;
    end
    if (waitTime>0)
        pause(1/uData.fps-plotTime);
    end
    tic;
end

%figure closed while running, avoid errors
if ~ishandle(fig), return; end

set(fig,'WindowButtonDownFcn',@seq_click); %reenable clicks

% Save new frame number
set(fig,'UserData',uData);
showimg(uData,uData.fnum);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_fps(~, ~, ~)
% figure menu callback

fig = gcbf;
uData = get(fig,'UserData');

% Prompt for new frame rate
sfps = inputdlg('fps','Frame rate',1,{num2str(uData.fps)});
if isempty(sfps), return; end  % user pressed cancel
uData.fps = str2double(sfps{1});
% Ignore invalid frame rate
if uData.fps<=0, return; end

% Save new frame rate
set(fig,'UserData',uData);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_compress(~, ~, ~)
%check/uncheck compression
hcomp = gcbo;
if strcmp(get(hcomp,'Checked'),'on')
    set(hcomp,'Checked','off')
else
    set(hcomp,'Checked','on')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function seq_avi(~, ~, ~)
% figure menu callback

fig = gcbf;
uData = get(fig,'UserData');

fprintf('Converting AVI...');
[fname,fpath] = uiputfile('*.avi','Save AVI file as...',uData.fpath);
if ~fname %user canceled or quit
    return
end
tic;
uData.fpath = fpath;
% Save new file path
set(fig,'UserData',uData);

imgCell = get(uData.imglist(:),'CData');
if ~iscell(imgCell)
    errordlg('Sequence is only a single frame, avi not supported')
    return
end

imgArray = cat(4,imgCell{:});
if size(imgArray,3) == 1 %intensity images, use colormap
    cmap = get(fig,'Colormap');
    clim = get(get(fig,'CurrentAxes'),'CLim');
    %create indexed image array (scale to colormap based on clims)
    cmax = size(cmap,1) - 1;
    imgArray = min(max(imgArray-clim(1), 0),clim(2)-clim(1)).*(cmax/(clim(2)-clim(1))) + 1;
    %convert array to movie (uses a dummy figure)
    htemp = figure('visible','off');
    mov = immovie(imgArray,cmap);
    delete(htemp)
elseif size(imgArray,3) == 3 %RGB images
    htemp = figure('visible','off');
    mov = immovie(imgArray);
    delete(htemp)
else %not supported
    errordlg(sprintf('Unsupported Data Format, mxnx%d',size(imgArray,3)))
    return
end
hcomp = findobj(fig,'Tag','compression');
if strcmp(get(hcomp,'Checked'),'on')%use default compression
    movie2avi(mov,fullfile(fpath,fname),'compression','Cinepak','fps',uData.fps)
else %no compression
    movie2avi(mov,fullfile(fpath,fname),'compression','None','fps',uData.fps)
end
fprintf('complete in %2.2f seconds!\n',toc);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function KeyPress(~, eventdata, str)

fig = gcbf;
figData = get(fig,'userdata');

if strcmp(str, 'Press')
    figData.KeyPress = eventdata;
else
    figData.KeyPress = [];
end
set(fig,'UserData',figData);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_cleanup(~, ~, ~)
% Called with gcbo = axis object being deleted

% h = gcbf;   % figure object

% set(h,'UserData',[]);  % remove image list

% set(h,'Pointer','default')

% If you don't remove the callbacks, they cause errors once the axes with
% its images are gone
% set(h,'WindowButtonMotionFcn','');
% set(h,'WindowButtonDownFcn','');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_scroll(~, eventdata, ~)

fig = gcbf;
uData = get(fig,'UserData');
nframes = length(uData.imglist);
newfnum = mod(uData.fnum + sign(eventdata.VerticalScrollCount),nframes);

if newfnum == 0
    newfnum = nframes;
end

showimg(uData,newfnum);
uData.fnum = newfnum;

% Save new frame number
set(gcbf,'UserData',uData);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_resize(~, ~, ~)

fig = gcbf;
uData = get(fig,'UserData');
imformat = uData.imformat;
ax = uData.ax;
w = uData.w;
h = uData.h;

oldunits = get(ax,'units');
set(ax,'units','normalized');
set(ax,'OuterPosition',[0 0 1 1]);
if any(strcmp(get(get(fig,'children'),'tag'),'Colorbar'))
    set(ax,'Position',[0.13 0.11 0.650330687830688 0.815]); %default axes pos
else
    set(ax,'Position',[0.13 0.11 0.775 0.815]); %default axes pos
end

if strcmpi(imformat,'scale')
    set(ax,'DataAspectRatio',[1 1 1]);
elseif strcmpi(imformat,'stretch')
    set(ax,'DataAspectRatioMode','auto');
elseif strcmpi(imformat,'1:1')
    set(ax,'units','pixels');
    set(ax,'DataAspectRatio',[1 1 1]);
    fullpos = get(ax,'OuterPosition');
    axSize = fullpos(3:4)-fullpos(1:2)+1;
    spaceSize = (axSize-[w h])./2;
    set(ax,'position',[fullpos(1:2)+spaceSize w h]);      
else    
    set(ax,'DataAspectRatio',[1 1 1]);   
end
set(ax,'units',oldunits);
set(ax,'PlotBoxAspectRatioMode','auto');
drawnow;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function oneToOneMapping(~, ~, ~)

fig = gcbf;
uData = get(fig,'UserData');
set(uData.hBarStretch,'checked','off');
set(uData.hBarScale,'checked','off');
set(uData.hBar1t1,'checked','on');
uData.imformat = '1:1';
set(fig,'UserData',uData);
ax = uData.ax;
set(ax,'DataAspectRatio',[1 1 1]);
oldunits = get(ax,'units');
set(ax,'units','normalized');
set(uData.ax,'OuterPosition',[0 0 1 1]); %default axes pos
if any(strcmp(get(get(fig,'children'),'tag'),'Colorbar'))
    set(ax,'Position',[0.13 0.11 0.650330687830688 0.815]); %default axes pos
else
    set(ax,'Position',[0.13 0.11 0.775 0.815]); %default axes pos
end
set(ax,'units','pixels');
fullpos = get(ax,'OuterPosition');
axSize = fullpos(3:4)-fullpos(1:2)+1;
spaceSize = (axSize-[uData.w uData.h])./2;
% weird bug -- there is image stretching with pos(3:4) = [uData.w uData.h]
set(ax,'position',[fullpos(1:2)+spaceSize uData.w-1 uData.h-1]);
set(ax,'units',oldunits);
set(ax,'PlotBoxAspectRatioMode','auto');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function scaleToFit(~, ~, ~)

fig = gcbf;
uData = get(fig,'UserData');
set(uData.hBarStretch,'checked','off');
set(uData.hBarScale,'checked','on');
set(uData.hBar1t1,'checked','off');
ax = uData.ax;
uData.imformat = 'scale';
set(fig,'UserData',uData);
set(ax,'DataAspectRatio',[1 1 1]);
oldunits = get(ax,'units');
set(ax,'units','normalized');
if any(strcmp(get(get(fig,'children'),'tag'),'Colorbar'))
    set(ax,'Position',[0.13 0.11 0.650330687830688 0.815]); %default axes pos
else
    set(ax,'Position',[0.13 0.11 0.775 0.815]); %default axes pos
end
set(ax,'units',oldunits);
set(ax,'PlotBoxAspectRatioMode','auto');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function stretchToFit(~, ~, ~)

fig = gcbf;
uData = get(fig,'UserData');
set(uData.hBarStretch,'checked','on');
set(uData.hBarScale,'checked','off');
set(uData.hBar1t1,'checked','off');
ax = uData.ax;
uData.imformat = 'stretch';
set(fig,'UserData',uData);
set(ax,'DataAspectRatioMode','auto');
% set(ax,'DataAspectRatio',[uData.h uData.w 1]);
oldunits = get(ax,'units');
set(ax,'units','normalized');
if any(strcmp(get(get(fig,'children'),'tag'),'Colorbar'))
    set(ax,'Position',[0.13 0.11 0.650330687830688 0.815]); %default axes pos
else
    set(ax,'Position',[0.13 0.11 0.775 0.815]); %default axes pos
end
set(ax,'units',oldunits);
set(ax,'PlotBoxAspectRatioMode','auto');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function shownan_func(~, ~, ~)

obj = gcbo;
fig = gcbf;
uData = get(fig,'UserData');
shownan = ~strcmpi(get(obj,'checked'),'on');
if shownan
    set(obj,'checked','on');
    colormapNaN(uData.cmap);   % Set figure's colormap
else
    set(obj,'checked','off');
    colormap(uData.cmap);   % Set figure's colormap
end
uData.showNaN = shownan;
set(fig,'UserData',uData);
showimg(uData,uData.fnum)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_cursorinfo(imghandle)
%old cursorinfo was SOOO SLOW -- used to update string for every frame
%(even the non-visible ones)... now just updates the current (visible)
%frame
img = get(imghandle,'CData');
alpha = get(imghandle,'alphadata');
ax = get(imghandle,'Parent'); % axes handle
axData = get(ax,'userdata');

cursor = get(ax,'CurrentPoint'); % get point

% only get x and y from first image
x = round(cursor(1,1));
y = round(cursor(1,2));
xlim = get(imghandle,'XData');
ylim = get(imghandle,'YData');

if x<xlim(1) || x>xlim(end) || y<ylim(1) || y>ylim(end)
    vstr = '???';
else
    if isfield(axData,'displayBase')
        switch axData.displayBase
            case 2
                if numel(alpha)==1
                    fmt = ' 0b%s';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    val = img(yind,xind);
                    if val < 0
                        val = 2^16+val;
                    end
                    vstr = sprintf(fmt,dec2bin(val,16));
                else
                    fmt = ' 0b%s 0b%s';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    val = img(yind,xind);
                    if val < 0
                        val = 2^16+val;
                    end
                    val2 = alpha(yind,xind);
                    if val2 < 0
                        val2 = 2^16+val2;
                    end
                    vstr = sprintf(fmt,dec2bin(val,16),dec2bin(val2,16));
                end  
            case 10
                if numel(alpha)==1
                    fmt = ' %16.8g';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    vstr = sprintf(fmt,img(yind,xind));
                else        
                    fmt = ' %16.8g %16.8g';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    vstr = sprintf(fmt,img(yind,xind),alpha(yind,xind));
                end
            case 16
                if numel(alpha)==1
                    fmt = ' 0x%04x';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    val = img(yind,xind);
                    if val < 0
                        val = 2^16+val;
                    end
                    vstr = sprintf(fmt,val);
                else        
                    fmt = ' 0x%04x 0x%04x';
                    xind = x-xlim(1)+1;
                    yind = y-ylim(1)+1;
                    val = img(yind,xind);
                    if val < 0
                        val = 2^16+val;
                    end
                    val2 = alpha(yind,xind);
                    if val2 < 0
                        val2 = 2^16+val2;
                    end
                    vstr = sprintf(fmt,val,val2);
                end            
        end
    else
        if numel(alpha)==1
            fmt = ' %16.8g';
            xind = x-xlim(1)+1;
            yind = y-ylim(1)+1;
            vstr = sprintf(fmt,img(yind,xind));
        else        
            fmt = ' %16.8g %16.8g';
            xind = x-xlim(1)+1;
            yind = y-ylim(1)+1;
            vstr = sprintf(fmt,img(yind,xind),alpha(yind,xind));
        end
    end
end

str = sprintf('x:%4d y:%4d %s',x,y,vstr);

% if no output desired, set str to xlabel of axes
if nargout<1
    set(get(ax,'xlabel'),'string',str);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function binDisp_func(~, ~, ~)

obj = gcbo;
fig = gcbf;
uData = get(fig,'UserData');
set(uData.hBarBin,'checked','on');
set(uData.hBarDec,'checked','off');
set(uData.hBarHex,'checked','off');

axData.displayBase = 2;
set(uData.ax,'UserData',axData);
showimg(uData,uData.fnum);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function decDisp_func(~, ~, ~)

obj = gcbo;
fig = gcbf;
uData = get(fig,'UserData');
set(uData.hBarBin,'checked','off');
set(uData.hBarDec,'checked','on');
set(uData.hBarHex,'checked','off');

axData.displayBase = 10;
set(uData.ax,'UserData',axData);
showimg(uData,uData.fnum);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function hexDisp_func(~, ~, ~)

obj = gcbo;
fig = gcbf;
uData = get(fig,'UserData');
if isfield(uData,'hBarBin')
    set(uData.hBarBin,'checked','off');
    set(uData.hBarDec,'checked','off');
    set(uData.hBarHex,'checked','on');
    
    axData.displayBase = 16;
else
    if isfield(uData,'hBarHex')
        nowChecked = get(uData.hBarHex,'checked');
        set(uData.hBarHex,'checked','on');
        axData.displayBase = 16;
    else
        hexDisp = ~strcmpi(get(obj,'checked'),'on');
        if hexDisp
            set(obj,'checked','on');    
            axData.displayBase = 16;
        else
            set(obj,'checked','off');    
            axData.displayBase = 10;
        end               
    end

end

set(uData.ax,'UserData',axData);
showimg(uData,uData.fnum)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_saveToWorkspace(~, ~, ~)

answer = inputdlg('Variable Name...','',1,{''});
if isempty(answer)
    return;
end

fig = gcbf;
uData = get(fig,'UserData');

nimgs = numel(uData.imglist);
[h w d] = size(get(uData.imglist(1),'cdata'));
outclass = class(get(uData.imglist(1),'cdata'));

output = zeros(h,w,nimgs,outclass);
for i=1:nimgs
    output(:,:,i) = get(uData.imglist(i),'cdata');
end
assignin('base',answer{1},output);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function seq_saveToImages(~, ~, ~)

fig = gcbf;
uData = get(fig,'UserData');
nimgs = numel(uData.imglist);

% prompt for where to save
% get file
pathName = uigetdir(pwd,'Folder to save images in');

% if user hits cancel
if pathName == 0
    return;
end

% TODO: this method sucks, but in lieu of a custom warning dialog box, this 
% is the best I could come up with in short order...
if nimgs > 10
    answer = inputdlg(sprintf('Are you sure you want to save %d images?  (This will take a while...)\n\nEnter 1 below to do this anyway... ',nimgs),'Warning: Many Images!',1,{''});
    
    if isempty(answer)
        return;
    end
    
    if answer{1} ~= '1'
        return;
    end
end

set(fig,'PaperPositionMode','auto');
% TODO: for now just save as individual png files, eventually add support 
% for PDF generation
for i=1:nimgs    
    showimg(uData,i);
    print(fig,'-dpng','-r0',fullfile(pathName,sprintf('%s.png',uData.titles{i})));
end
set(fig,'PaperPositionMode','manual');

showimg(uData,uData.fnum);
