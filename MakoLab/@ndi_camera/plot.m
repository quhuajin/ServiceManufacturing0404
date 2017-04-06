function plotHandleReturn = plot(ndi,parent)
%PLOT Overloaded method to graphically display the ndi camera tools
%
% Syntax:
%   plotHandle = plot(ndi)
%       this will display the 3D volume of the ndi charecterized workspace and
%       will display the tools that are being tracked.  This function will
%       automatically put the camera in tracking mode.  The displayed shape will
%       correspond to the calibrated camera volume.  PlotHandle if
%       requested will give the handle to the parent object for the plot.
%       along with the timer id of the plot update function
%
%   plot(ndi,parent)
%       The argument parent can be used to specify a GUI handle of a parent
%       GUI object to allow the user to embed the plot into another gui.
%       By default if a parent is not specified a new plot window will be
%       opened. SEE NOTES (IMPORTANT)
%
% Notes:
%   Since this function utilizes a timer.  the timer must be stopped when
%   the plot is closed.  if the plot is embedded into a figure the close
%   handle for the figure should take care of this
%
% See Also:
%   ndi_camera, ndi_camera/init_tool, ndi_camera/setmode
%

%
% $Author: jforsyth $
% $Revision: 2519 $
% $Date: 2011-11-10 13:28:02 -0500 (Thu, 10 Nov 2011) $
% Copyright: MAKO Surgical corp (2007)
%

% Change the mode to setup mode
setmode(ndi,'Setup');

subPlotHandle=[];

% query the camera for the charecterization shape
camReply = char(comm(ndi,'SFLIST 03'));

% extract charecterization shape
switch str2double(camReply(2))
    case 0
        charShape = 'SILO';
    case 4
        charShape = 'PYRAMID';
    case 5
        charShape = 'EXT_PYRAMID';
    otherwise
        error('Unsupported camera chareterization shape (%d)',camReply(2));
end

% Create the shape based on the dimesions described int the NDI documentation.
switch charShape
    case 'SILO'
        % extract the parameters for the SILO.  Refer to NDI documentation for
        % additional details
        D1 = 500;
        D2 = 0;
        D3 = 0;
        D4 = -1900;

        % Compute coordinates for drawing the described shape
        x = [D2+D1*sin(0:.1:pi/2),D1];
        x = [-x, x(end:-1:1),-x(1)];
        y = [D3+D1*sin(0:.1:pi/2),D1];
        y = [y,-y(end:-1:1),y(1)];
        z = [D4+D1*cos(0:.1:pi/2),D4-D1];
        z = [z,z(end:-1:1),z(1)];

    case 'PYRAMID'
        % Parameters for the PYRAMID shape for Polaris from NDI documentation
        D1 = 2400;
        
        % Compute coordinates for drawing the described shape
        x = [(1000-480)*tand(15), (1670-480)*tand(15), (D1-480)*tand(15)];
        x = [-x, x(end:-1:1),-x(1)];
        y = [(1000-480)*tand(55/2), (1670-480)*tand(55/2), 1560/2];
        y = [y,-y(end:-1:1),y(1)];
        z = [-1000, -1670, -D1];
        z = [z,z(end:-1:1),z(1)];

    case 'EXT_PYRAMID'
        % Parameters for the EXT_PYRAMID shape from NDI documentation
        D1 = -3000;
        D2 = -1532;
        D3 = -950;
        D4 = 572;
        D5 = 398;
        D6 = 569.46;
        D7 = 243.03;
        D8 = 0297.73;

        % Compute coordinates for drawing the described shape
        x = [D5-(D3-D2)*D8/1000, D5, D5+(D2-D1)*D8/1000];
        x = [-x, x(end:-1:1),-x(1)];
        y = [D4-(D3-D2)*D6/1000, D4, D4+(D2-D1)*D7/1000];
        y = [y,-y(end:-1:1),y(1)];
        z = [D3,D2,D1];
        z = [z,z(end:-1:1),z(1)];

end

% get a new figure
% check if there is a parent specified.  if not generate a plot
if (nargin>1)
    figHandle = uipanel('parent',parent);
else
    figHandle = figure(...
        'Position',[300,200,700,600]...
        );
end

% Now plot the images.  This function will display the top view and side view
subPlotHandle(1) = subplot(2,1,1,'Parent',figHandle);

% Draw the range
line('XData',z,'YData',y,'LineWidth',2,'Parent',subPlotHandle(1));
title(subPlotHandle(1),'NDI ToolViewer (top view)');
xlabel(subPlotHandle(1),'Camera Z axis (mm)');
ylabel(subPlotHandle(1),'Camera Y axis (mm)');
grid(subPlotHandle(1),'on');
hold(subPlotHandle(1),'on');
set(subPlotHandle(1),'box','on');
% change scale to add 100 mm beyond range and 50 mm after 0
currentAxis = axis(subPlotHandle(1));
axis(subPlotHandle(1),[currentAxis(1)-100,50,currentAxis(3)-100,currentAxis(4)+100]);

% Now plot the side view
subPlotHandle(2) = subplot(2,1,2,'Parent',figHandle);

% extract the default MATLAB color order
colorOrder = get(subPlotHandle(2),'ColorOrder');
line('XData',z,'YData',x,'LineWidth',2,'Parent',subPlotHandle(2));
title(subPlotHandle(2),'NDI ToolViewer (side view)');
xlabel(subPlotHandle(2),'Camera Z axis (mm)');
ylabel(subPlotHandle(2),'Camera X axis (mm)');
grid(subPlotHandle(2),'on');
hold(subPlotHandle(2),'on');
set(subPlotHandle(2),'box','on');
currentAxis = axis(subPlotHandle(2));
axis(subPlotHandle(2),[currentAxis(1)-100,50,currentAxis(3)-100,currentAxis(4)+100]);

% Query the number of tools and create all the tool displays
ndiReply = char(comm(ndi,'PHSR 00'));
numPorts = str2double(ndiReply(1:2));

% Make sure there is atleast one tool to track
if numPorts==0
    warning('No Tools Loaded'); %#ok<WNTAG>
    
    if nargin==1
        set(figHandle,...
            'CloseRequestFcn','closereq'...
            );
    elseif nargin==2
        set(figHandle,...
            'DeleteFcn','delete'...
            );
    end
    return
end

% Create a marker for each tool
for i=1:numPorts  %#ok<FXUP>
    colorCode = colorOrder(i,:);
    trackerHandles(i).tracker(1) = plot(subPlotHandle(1),0,0,...
        'Color',colorCode,...
        'Marker','o',...
        'MarkerSize',5,...
        'LineWidth',2,...
        'EraseMode','xor'...
        ); %#ok<AGROW>
    trackerHandles(i).tracker(2) = plot(subPlotHandle(2),0,0,...
        'Color',colorCode,...
        'Marker','o',...
        'MarkerSize',5,...
        'LineWidth',5,...
        'EraseMode','xor'...
        ); %#ok<AGROW>
end

% Define the display key for the different types of tx replies
% append the error message flag
plotStyle.VISIBLE_NO_ERROR.Marker = 'o';
plotStyle.VISIBLE_NO_ERROR.Visible = 'on';
plotStyle.VISIBLE_NO_ERROR.LineWidth = 5;
plotStyle.VISIBLE_NO_ERROR.MarkerSize = 5;

plotStyle.VISIBLE_PartiallyOutOfVolume.Marker = '*';
plotStyle.VISIBLE_PartiallyOutOfVolume.Visible = 'on';
plotStyle.VISIBLE_PartiallyOutOfVolume.LineWidth = 1;
plotStyle.VISIBLE_PartiallyOutOfVolume.MarkerSize = 10;

plotStyle.VISIBLE_OutOfVolume.Marker = 'o';
plotStyle.VISIBLE_OutOfVolume.Visible = 'on';
plotStyle.VISIBLE_OutOfVolume.LineWidth = 1;
plotStyle.VISIBLE_OutOfVolume.MarkerSize = 10;

plotStyle.MISSING_NO_ERROR.Marker = 'o';
plotStyle.MISSING_NO_ERROR.Visible = 'off';
plotStyle.MISSING_NO_ERROR.LineWidth = 5;
plotStyle.MISSING_NO_ERROR.MarkerSize = 1;

plotStyle.DISABLED_NO_ERROR.Marker = 'o';
plotStyle.DISABLED_NO_ERROR.Visible = 'off';
plotStyle.DISABLED_NO_ERROR.LineWidth = 5;
plotStyle.DISABLED_NO_ERROR.MarkerSize = 1;

% Now start the tracking and update the display
setmode(ndi,'Tracking');

% Create a timer to update the plots
% Setup the fixed spacing mode to allow user to be able to
% interact with the system even if ther plot is taking too long
% and also this will allow for multiple plots
plotTimer = timer(...
    'TimerFcn',@updatePlot,...
    'Period',0.005,...
    'ObjectVisibility','off',...
    'BusyMode','drop',...
    'ExecutionMode','fixedSpacing'...
    );

% if this was a new plot add close function
if nargin==1
    set(figHandle,...
        'UserData',plotTimer,...
        'CloseRequestFcn',@closeToolViewer...
        );
elseif nargin==2
    set(figHandle,...
        'UserData',plotTimer,...
        'DeleteFcn',@closeToolViewer...
        );
end

% refresh the plots
drawnow;

% Check if there is a return requested
if (nargout~=0)
    plotHandleReturn.plotHandle = figHandle;
    plotHandleReturn.subPlotHandle=subPlotHandle;
    plotHandleReturn.timer = plotTimer;
end

% Start the plots
start(plotTimer);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% INTERNAL FUNCTIONS  %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Callback function for the timer to update the plot
    function updatePlot(timerObj,data) %#ok<INUSD>
        toolInfo = tx(ndi);
        for i=1:numPorts %#ok<FXUP>
            plotStyleKey = strcat(toolInfo(i).status,'_',toolInfo(i).errorMsg);

            set(trackerHandles(i).tracker(1),...
                'Xdata',toolInfo(i).position(3)*1000,...
                'Ydata',toolInfo(i).position(2)*1000,...
                plotStyle.(plotStyleKey))
            set(trackerHandles(i).tracker(2),...
                'Xdata',toolInfo(i).position(3)*1000,...
                'Ydata',toolInfo(i).position(1)*1000,...
                plotStyle.(plotStyleKey))
        end
        drawnow
    end

% Function to handle the close function request
    function closeToolViewer(hObject, eventData) %#ok<INUSD,DEFNU>
        % send signal to terminate the loop
        timerHandle = get(hObject,'UserData');
        if(ishandle('timerHandle'))
            stop(timerHandle);
            delete(timerHandle)
        end
        if(ishandle(figHandle))
            delete(figHandle);
        end
    end

end




% --------- END OF FILE ----------