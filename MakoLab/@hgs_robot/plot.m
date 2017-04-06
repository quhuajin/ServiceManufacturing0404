function plotHandleReturn = plot(hgs,varNameIndex,plotProperties)
%PLOT Overloaded method to graphically display hgs_robot variables
%
% Syntax:
%   plotHandle = PLOT(hgs,varNameIndex)
%       this will plot the variable specified by varNameIndex with respect to
%       time.  The variable will constantly be queiried from the connected
%       hgs robot.  The varNameIndex is a text variable that can specify
%       the element in the vector to be plotted.  plotHandle is the handle for
%       the figure generated.
%   PLOT(hgs,varNameIndex,plotProperties)
%       Specifying the plotProperties will apply to the generated plots.  for a
%       list of plot properties refer to the documentation in the plot function
%
% Examples
%   plot(hgs,'joint_angles')
%   plot(hgs,'joint_angles(2)')
%   plot(hgs,'joint_angles(2:4)')
%
% Notes
%   using end in the the index is not supported, this means
%   plot(hgs,'joint_angles(2:end)') is not supported.
%
% See Also:
%   hgs_robot, hgs_robot/get, hgs_robot/subsref, plot
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% predefined properties
scrollPlotWindowSize = 15;  % sec

% parse the input string for any index
bracketStart = findstr(varNameIndex,'(');
bracketEnd = findstr(varNameIndex,')');

if (nargin<3)
    plotProperties='';
end

% if there are no brackets assume this is the whole name
if (isempty(bracketStart))
    variableName = varNameIndex;
    variableIndex = ':';
else
    % make sure there is only one bracket and it is paired
    if ((length(bracketStart)==1)...
            &&(length(bracketEnd)==1)...
            &&(bracketEnd>bracketStart))
        % everything before the bracket Start is the variable
        % name
        variableName = varNameIndex(1:bracketStart-1);
        variableIndex = eval(varNameIndex(bracketStart+1:bracketEnd-1));
    else
        error('Imporper brackets in argument');
    end
end

% get a new figure
plotHandle = figure;

% process the Variable Name to remove _ and any other
% special charecters
variableNameDisp = strrep(varNameIndex,'_','\_');
% Create the plots
[plotData.timeList, variableValue] = get(hgs,'time',variableName);
plotData.variableList = variableValue(1,variableIndex);
plotData.axes = axes;
plotData.handles = plot(plotData.timeList,plotData.variableList,...
    plotProperties);

% create legend text for when it is required
if (variableIndex==':')
    % All variables are requested, create a label for each one
    for i=1:length(variableValue)
        legendNames(i,:) = {sprintf('%s(%d)',...
            variableNameDisp,i)}; %#ok<AGROW>
    end
else
    % create labels for the specific elements desired
    for i=1:length(variableIndex)
        legendNames(i,:) = {sprintf('%s(%d)',...
            variableNameDisp,variableIndex(i))}; %#ok<AGROW>
    end
end

% Setup common plot properties
title([variableNameDisp,' vs time']);
xlabel('time');
ylabel(variableNameDisp);
legend(legendNames);
legend off;
grid on;
hold on;

% Store data for later use during plot update, these dont have to be in a
% structure but keeping them in a structure will allow it to be incorporated
% with UserData property if needed.
plotData.numHandles = length(plotData.handles);
plotData.variableName = variableName;
plotData.variableIndex = variableIndex;
plotData.hgs = hgs;
plotData.clearPlot = false;
plotData.scrollOn = false;
plotData.scrollUpdateTime = 0;

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

set(plotHandle,...
    'CloseRequestFcn',@closeToolViewer...
    );


% Since these are live plots create a button to be able to pause and resume the
% plots.

plotIconData = load('PlotIconData.mat');
figToolBar = uitoolbar(plotHandle);
playPauseButton = uitoggletool(figToolBar,...
    'TooltipString','Play or Pause the plot',...
    'CData',plotIconData.pauseIcon,...
    'onCallBack',@pausePlot,...
    'offCallBack',@resumePlot...
    ); %#ok<NASGU>
clearButton = uipushtool(figToolBar,...
    'TooltipString','Clear current plot',...
    'CData',plotIconData.clearIcon,...
    'ClickedCallback', @clearPlot...
    ); %#ok<NASGU>

playPauseButton = uitoggletool(figToolBar,...
    'TooltipString','Turn on/off scrolling mode (Experimental)',...
    'CData',plotIconData.scrollIcon,...
    'ClickedCallback',@plotScrollControl...
    ); %#ok<NASGU>
% refresh the plots
drawnow;

% update fresh data to account for all delays uptill this point
[plotData.timeList, variableValue] = get(hgs,'time',variableName);
plotData.variableList = variableValue(1,variableIndex);

% Start the plots
start(plotTimer);

% Check if there is a return requested
if (nargout~=0)
    plotHandleReturn = plotHandle;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setup internal functions to handle GUI aspects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%------------------------------------------------------------------------------
% Internal function to update the screen
%------------------------------------------------------------------------------
    function updatePlot(varargin)
        % update the data
        [time, variableValue] = get(plotData.hgs,...
            'time',plotData.variableName);

        variableValue = variableValue(1,plotData.variableIndex);

        % check if there is a request to clear plots
        if (plotData.clearPlot);
            plotData.timeList = time;
            plotData.variableList = variableValue;
            % reset the flag to indicate it has been serviced
            plotData.clearPlot = false;
        else
            % if the scrolling mode is on show only data for the last
            % n seconds specified by the scrollPlotWindowSize parameter
            if ((plotData.scrollOn)...
                    && (time>plotData.scrollUpdateTime+2))
                xlim(plotData.axes,[time-scrollPlotWindowSize-3;time+3]);
                plotData.scrollUpdateTime = time;
            end

            % now update the plot
            plotData.timeList = [plotData.timeList;time];
            plotData.variableList = [plotData.variableList;variableValue];
        end

        for i=1:plotData.numHandles
            set(plotData.handles(i),...
                'XData',plotData.timeList,...
                'YData',plotData.variableList(:,i));
        end

        drawnow;
    end

%-------------------------------------------------------------------------------
% Internal function to handle the clearing/reseting of the plot data
%-------------------------------------------------------------------------------
    function clearPlot(varargin)
        plotData.clearPlot = true;
    end

%-------------------------------------------------------------------------------
% Internal function to handle the pausing the plot data
%-------------------------------------------------------------------------------
    function pausePlot(varargin)
        stop(plotTimer);
    end
%-------------------------------------------------------------------------------
% Internal function to handle the pausing the plot data
%-------------------------------------------------------------------------------
    function resumePlot(varargin)
        start(plotTimer);
    end

%-------------------------------------------------------------------------------
% Internal function to handle scrolling plots
%-------------------------------------------------------------------------------
    function plotScrollControl(buttonHandle,varargin)
        if(strcmp(get(buttonHandle,'state'),'on'))
            plotData.scrollOn = true;
            xlim(plotData.axes,'manual');
        else
            plotData.scrollOn = false;
            xlim(plotData.axes,'auto');
        end
    end

%-------------------------------------------------------------------------------
% Internal function to cleanly close the plot window
%-------------------------------------------------------------------------------
% Function to handle the close function request
    function closeToolViewer(varargin)
        % try to stop the update timer.  The timer might have died due to some
        % other reason.  So this is only an attempt.  If if fails the window
        % should still close
        try
            stop(plotTimer);
            delete(plotTimer);
        catch
        end
        closereq
    end

end


% --------- END OF FILE ----------