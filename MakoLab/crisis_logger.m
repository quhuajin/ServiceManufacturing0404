function figHandle = crisis_logger(hgs)
%crisis_logger GUI interface to view various crisis variables
%
% Syntax:
%   crisis_logger(hgs)
%       This will start up a gui to view various crisis variables
%
% Notes:
%   There are some variables that can be configured (later this will be changed
%   to options).  See the initial section of the code for details
%
% See also:
%    hgs_robot, hgs_robot/get, hgs_robot/subref

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2007)
%

% some configurable variables
screenUpdateRate = 0.05;  % sec (do not go below 0.001)

% check the inputs
if (nargin~=1)
    error('Invalid number of inputs');
end

if ~isa(hgs,'hgs_robot')
    error('Argument must be a hgs_robot object');
end

% Generate the GUI
guiHandles = generateMakoGui('Arm Logger',[],hgs);
set(guiHandles.figure,'closerequestfcn',@closeCrisisLogger);

% see if a output handle is desired
if nargout==1
    figHandle = guiHandles.figure;
end

% tweak the gui to shrink the title, this is not as important
updateMainButtonInfo(guiHandles,'text','Arm Logger');
set(guiHandles.mainButtonInfo,'fontsize',0.8);
set(guiHandles.uiPanel,'Position',[0.02 0.14 0.96 0.76])
set(get(guiHandles.mainButtonInfo,'Parent'),...
    'Position',[0.02 0.92 0.96 0.06]);

variableTypeSel = uicontrol(get(guiHandles.mainButtonInfo,'Parent'),...
    'Style','popupmenu',...
    'String',{
                'Internal Arm Variables',...
                'Configuration Parameters',...
                'State at last Error'...
             },...
    'Value',1,...
    'Units','normalized',...
    'Position',[0.84 0.7 0.14 0.1],...
    'Callback',@updateSlider);


dispTextHandle = uicontrol(guiHandles.uiPanel,...
    'units','normalized',...
    'Position',[0.02 0.02 0.96 0.96],...
    'fontname','fixedwidth',...
    'fontsize',9,...
    'Style','text',...
    'String',convertStructToString(hgs(:)),...
    'HorizontalAlignment','left'...
    );

% query data once to establish lengths
crisisData = crisisComm(hgs,'get_state');
dataString = convertStructToString(...
    parseCrisisReply(crisisData,'-DataPairRaw'));
numOfVarLines = length(strfind(dataString,10));
crisisData = crisisComm(hgs,'get_cfg_params');
dataString = convertStructToString(...
    parseCrisisReply(crisisData,'-DataPairRaw'));
numOfCfgLines = length(strfind(dataString,10));
crisisData = crisisComm(hgs,'get_state_at_last_error');
dataString = convertStructToString(...
    parseCrisisReply(crisisData,'-DataPairRaw'));
numOfErrStateLines = length(strfind(dataString,10));

sliderBar = uicontrol(guiHandles.uiPanel,...
    'units','normalized',...
    'Position',[0.98 0.0 0.02 1.01],...
    'background','white',...
    'style','slider',...
    'Min',1,...
    'Max',numOfVarLines+1,...
    'Value',numOfVarLines+1);

% Create a timer to update the screen
% Setup the fixed spacing mode to allow user to be able to
% interact with the system even if ther plot is taking too long
% and also this will allow for multiple plots
updateTimer = timer(...
    'TimerFcn',@updateScreen,...
    'Period',screenUpdateRate,...
    'ObjectVisibility','off',...
    'BusyMode','drop',...
    'ExecutionMode','fixedSpacing'...
    );

% start the timer
start(updateTimer);

%------------------------------------------------------------------------------
% Internal function to update the screen
%------------------------------------------------------------------------------
    function updateScreen(varargin)
        % query for the new data from crisis and show on screen
        if get(variableTypeSel,'Value')==3
            crisisData = crisisComm(hgs,'get_state_at_last_error');
            numOfLines = numOfErrStateLines;
        elseif get(variableTypeSel,'Value')==2
            crisisData = crisisComm(hgs,'get_cfg_params');
            numOfLines = numOfCfgLines;
        else
            crisisData = crisisComm(hgs,'get_state');
            numOfLines = numOfVarLines;
        end
        dispString = convertStructToString(...
            parseCrisisReply(crisisData,'-DataPairRaw'));
        lineEndings = strfind(dispString,10);
        
        firstLineNum = int32(numOfLines - get(sliderBar,'Value'));
        if firstLineNum>0
            dispString = dispString(lineEndings(firstLineNum)+1:end);
        end
        
        set(dispTextHandle,...
            'String',dispString);
        drawnow;
    end

%--------------------------------------------------------------------------
% Internal function to update slider
%--------------------------------------------------------------------------
    function updateSlider(varargin)
        if get(variableTypeSel,'Value')==1
            numOfLines = numOfVarLines;
        else
            numOfLines = numOfCfgLines;
        end
        set(sliderBar,...
            'Min',1,...
            'Max',numOfLines+1,...
            'Value',numOfLines+1);
    end

%-------------------------------------------------------------------------------
% Internal function to cleanly close the crisis logger
%-------------------------------------------------------------------------------
    function closeCrisisLogger(varargin)
        % try to stop the update timer.  The timer might have died due to some
        % other reason.  So this is only an attempt.  If if fails the window
        % should still close
        try
            stop(updateTimer);
            delete(updateTimer);
        catch %#ok<CTCH>
        end
        % close the window
        closereq
        % to prevent hanging of script if in deploy mode force exit
        if isdeployed
            exit;
        end
    end
end


% --------- END OF FILE ----------