function guiHandles = generateMakoGui(scriptName,versionNumberStr,hgs,extraPanelFlag)
% generateMakoGui Generate the default GUI template for the Mako Service and Manufcaturing
%
% Syntax:
%    guiHandles = generateMakoGui(scriptName,versionNumberStr,hgs)
%        This function will generate the default gui for Mako service and
%        manufacturing scripts.  The argument scriptName is used to identify the
%        name of the script or procedure being run.  
%        Ther versionNumberStr should be empty when automatic versioning is
%        needed. This will automatically fill the verision number information 
%        from SVN, branchname or tag.  Passing a string to this argument
%        will overide this setting and use the string as the version number
%        The final argument hgs can be either a hgs_robot object or a string.
%        if it is hgs_robot the robot name/serial number is automatically
%        queried.  If this argument is a string the string will be used to
%        identify the unit (useful for manufacturing).
%
%    guiHandles = generateMakoGui(scriptName,[],hgs,extraPanelFlag)
%        if the extraPanelFlag is set to boolean true, the function will
%        generate an large extra frame, which can be also be used for the GUI.
%        This is to be used for cases where the user interface cannot fit in the
%        uiFrame.
%
% Return Value Description
%        The return value guiHandles is a structure that will contain the
%        handles for the key elements in the gui.
%            guiHandles.figure
%                handle to the figure.
%            guiHandles.uiPanel
%                handle to the frame for all the user interface.  This is the
%                2nd frame that should be used for all script specific user
%                interface
%            guiHandles.mainButtonInfo
%                This is the handle to the main button or info line.
%            guiHandles.extraPanel
%                handle to the extraFrame if requested.  if not this argument
%                will be empty
%            guiHandles.reportDir
%                Directory where the reports will get generated.  This can
%                be used by scripts to dump script relevant data in the
%                same directory
%   
% Notes:
%    Please refer to
%    http://twiki.makosurgical.com/view/Robot/HgsServiceAndManufacturingGUITemplate
%    for description on the GUI concept.
%
%    By default reports will be generated on the Desktop form windows machine
%    and on unix machines this will be in the temp directory.  This can also be
%    specified with the MAKO_LOG_DIR environment variable.  
%
%    The gui will always generate full screen on the default screen and will 
%    assume that none of the monitors have any offset built into it.
%
% See Also:
%    presentMakoResults, resetMakoGui

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)

if isempty(versionNumberStr)
    % generate an automatic version number based on Tag or Branch ID
    
    versionNumberStr = sprintf('(ver: %s )',generateVersionString);
 
else
    % make sure the version number string is text
    if ~ischar(versionNumberStr)
        error('Argument version Number string must be a string');
    end
end

% Check if the hgs is a real robot if not assume that the script
% is not for a robot
if (~isa(hgs,'hgs_robot'))
    unitName = hgs;
else
    if(strncmp(hgs.name,'ROB',3)==1)
        unitName = hgs.name;
    else
        unitName = 'UNNAMED';
    end
end

DEFAULTFONTSIZE = 0.35; %#ok<NASGU>

% Check the frame sizes basaed on if the extraFrame is requested or not
if (nargin==4) && (extraPanelFlag)
    figPosition = [100 200 1200 600];
    infoPanelPos = [0.01 0.82 0.48 0.15];
    uiPanelPos = [0.01 0.14 0.48 0.66];
    repPanelPos = [0.01 0.02 0.48 0.10];
    extraPanelPos = [0.51 0.02 0.48 0.95];
    fontScaling=0.7;
else
    figPosition = [200 200 600 600];
    infoPanelPos = [0.02 0.82 0.96 0.15];
    uiPanelPos = [0.02 0.14 0.96 0.66];
    repPanelPos = [0.02 0.02 0.96 0.10];
    
    % Generate a dummy extra panel with no size.  This will remain hidden
    extraPanelPos = [0.51 0.02 0.48 0.95]; 
    extraPanelFlag = false;
    fontScaling = 1;
end

% Generic GUI options follow

% check to see if there are multiple monitors, if so maximize using the
% smallest size

screenSize = get(0,'MonitorPositions');

% this is a dual monitor, the java function does not
% work
    % assume the dominant monitor is the one with XY as pixel 1,1
% in unix systems the origin is defined as 1,0 and in windows it is 1,1
if ispc
    screenOrigin = [1,1];
else
    screenOrigin = [1,0];
end

for i=1:size(screenSize,1)
    if screenSize(i,1:2) == screenOrigin
        figPosition = screenSize(i,:);
        break;
    end
end

% get a new figure  and set up the static elements
figHandle = figure(...
    'Menubar','none',...
    'Name',scriptName,...
    'NumberTitle','off',...
    'Resize','on',...
    'HandleVisibility','off',...
    'Position',figPosition...
    );

drawnow;

% Full screen the window using java calls if this is a single screen
if size(screenSize,1)==1
    % use simple java to maximize the window
    % turn off the warning issued by matlab to generate java frame in
    % versions 2008 and higher
    warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    set(get(figHandle,'JavaFrame'),'Maximized',true);
end

% Setup the Service frames
infoPanel = uipanel(figHandle,...
    'Title','Instructions/Results',...
    'FontSize',8,...
    'Position',infoPanelPos...
    );

userInterface = uipanel(figHandle,...
    'Title','User Interface',...
    'FontSize',8,...
    'Position',uiPanelPos...
    );

reportPanel = uipanel(figHandle,...
    'Title','Report Generation',...
    'FontSize',8,...
    'Position',repPanelPos...
    );

% Generate the extra panel
if (extraPanelFlag)
    extraPanel = uipanel(figHandle,...
        'Title','Additional User Interface',...
        'FontSize',8,...
        'Visible','on',...
        'Position',extraPanelPos...
        );
else
    extraPanel = uipanel(figHandle,...
        'Title','Additional User Interface',...
        'FontSize',8,...
        'Visible','off',...
        'Position',extraPanelPos...
        );
end

% Now fill in all the frames with common elements
mainButtonInfo = uicontrol(infoPanel,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[0.02 0.1 0.96 0.85],...
    'FontUnits','normalized',...
    'FontSize',0.3*fontScaling,...
    'FontWeight','demi',...
    'Foregroundcolor','black',...
    'String',...
        sprintf('Click here to Start %s Procedure',...
        scriptName)...
    );


% Generate a report id.  Report Id must identify the machine being worked on
% along with the date stamp of the code execution
procedureDate = now;

if (isa(hgs,'hgs_robot'))
    reportStampText = {sprintf('Serial # %s(V%.1f)  %s',...
        unitName,...
        hgs.ARM_HARDWARE_VERSION,...
        datestr(procedureDate,'HH:MM  mm/dd/yyyy')),...
        sprintf('Script: %s %s',scriptName,versionNumberStr)};
else
    reportStampText = {sprintf('Serial # %s %s',...
        unitName,...
        datestr(procedureDate,'HH:MM  mm/dd/yyyy')),...
        sprintf('Script: %s %s',scriptName,versionNumberStr)};
end

% Generate a directory for reports
reportsDirName = generate_reports_dir;

% Set up the reports frame
commonReportPanelProperties = struct(...
    'Units','normalized',...
    'FontUnits','normalized',...
    'FontSize',0.3*fontScaling);

% generate a section for comments
commentsEditBox = uicontrol(reportPanel,...
    'Units','normalized',...
    'Position',[0.34 0.10 0.35 0.80],...
    'String','Add Comments Here',...
    'BackgroundColor','white',...
    'Style','edit',...
    'Min',0,...
    'Max',10,...
    'Visible','off',...
    'FontUnits','normalized',...
    'FontSize',0.2,...
    'HorizontalAlignment','left',...
    'Callback',@saveUserComments...
    );

uicontrol(reportPanel,...
    commonReportPanelProperties,...
    'Style','text',...
    'HorizontalAlignment','left',...
    'Position',[0.02 0.10 0.30 0.80],...
    'FontSize',0.2,...
    'Tag','reportStamp',...
    'String',reportStampText); 

% generate a button for user comments
commentsButton = uicontrol(reportPanel,...
    commonReportPanelProperties,...
    'Style','pushbutton',...
    'Position',[0.55 0.10 0.13 0.80],...
    'String','Comments',...
    'Callback',@showComments...
    ); 

% generate a button for screen capture
uicontrol(reportPanel,...
    commonReportPanelProperties,...
    'Style','pushbutton',...
    'Position',[0.70 0.10 0.13 0.80],...
    'String','Capture',...
    'Callback',@screenCapture...
    ); 

% generate the cancel button
uicontrol(reportPanel,...
    commonReportPanelProperties,...
    'Style','pushbutton',...
    'Position',[0.85 0.10 0.13 0.80],...
    'String','Cancel',...
    'Callback',@closeFunction...
    );

% generate and hide an exit button.  This button will
% be brought forward when the results are presented.  The 
% location of this button should coincide with the cancel button
% generate the cancel button
uicontrol(reportPanel,...
    commonReportPanelProperties,...
    'Style','pushbutton',...
    'Position',[0.85 0.10 0.13 0.80],...
    'String','Exit',...
    'Visible','off',...
    'Enable','off',...
    'Callback',@exitWithSnapshot...
    );

% Prepare return section
guiHandles.figure = figHandle;
guiHandles.uiPanel = userInterface;
guiHandles.mainButtonInfo = mainButtonInfo;
guiHandles.extraPanel = extraPanel;
guiHandles.reportsDir = reportsDirName;
guiHandles.takeSnapShot=@takeSnapShot;
guiHandles.scriptName=scriptName;
guiHandles.cancelWait=false;

% By defult seletct the main button as the primary footpedal button
uicontrol(mainButtonInfo);

%-------------------------------------------------------------------------------
% Internal function to abort a procedure
%-------------------------------------------------------------------------------
% close function to exiting the application
    function closeFunction(varargin)
        while (guiHandles.cancelWait)
            pause(0.5);
        end
        % call the close function associated with the figure
        try
            feval(get(figHandle,'closeRequestFcn'));
            closereq;
        catch
            closereq;
        end
    end

%-------------------------------------------------------------------------------
% Internal function to take a screenshot
%-------------------------------------------------------------------------------
% Screen Capture function for taking screenshots
    function screenCapture(varargin)
        try
            guiHandles.cancelWait=true;
            
            buttonHandle = varargin{1};
            takeSnapShot;
            set(buttonHandle,...
                'Style','text',...
                'String',sprintf('Screenshot\nSaved')...
                );
            pause(0.4);
            set(buttonHandle,...
                'Style','pushbutton',...
                'String','Capture'...
                );
            guiHandles.cancelWait=false;
        catch
            guiHandles.cancelWait=false;
            return;
        end
    end

%-------------------------------------------------------------------------------
% Internal function to take a show the comments section
%-------------------------------------------------------------------------------
% Screen Capture function for taking screenshots
    function showComments(varargin)
        guiHandles.cancelWait=true;
        % show the comments section
        set(commentsEditBox,'Visible','on');

        % hide the comments button
        set(commentsButton,'Visible','off');
        
        % change focus to comments section, since the user pressed the 
        % comments button, assume that the user wants to enter comments
        uicontrol(commentsEditBox);
        guiHandles.cancelWait=false;
        
    end

%-------------------------------------------------------------------------------
% Internal function to take a screenshot and exit
%-------------------------------------------------------------------------------
    function exitWithSnapshot(varargin) %#ok<DEFNU>
        % automatically take a screenshot ane exit
        buttonHandle = varargin{1};
        takeSnapShot;
        set(buttonHandle,...
            'Style','text',...
            'String',sprintf('Screenshot\nSaved')...
            );
        pause(0.6);
        
        % call the close function associated with the figure
        try
            feval(get(figHandle,'closeRequestFcn'));
        catch
        end
        closereq;
    end

%-------------------------------------------------------------------------------
% Internal function to take a screenshot
%-------------------------------------------------------------------------------
    function takeSnapShot(varargin)
        if(nargin==1)
            figureName=varargin{1};
        else
            figureName=guiHandles.scriptName;
        end
        guiHandles.cancelWait=true;
        
        % All screenshots will be saved in a directory which is the
        % name of the unit followed by date
        captureFilename = sprintf('%s-%s-%s',...
            strrep(figureName,' ',''),...
            unitName,...
            datestr(now,'yyyy-mm-dd-HH-MM-SS'));
        
	% use high resolution captures under Windows and print under linux
	% the getframe works a lot better in windows maintaining native resolution
        if ispc
            screenShotData = getframe(guiHandles.figure);
            imwrite(screenShotData.cdata,fullfile(reportsDirName,...
                [captureFilename '.png']));	
	else
            % print the image as 200 dpi
	    print(guiHandles.figure,fullfile(reportsDirName,...
                [captureFilename '.png']),'-dpng','-r200');
        end
	guiHandles.cancelWait=false;
    end

%-------------------------------------------------------------------------------
% Internal function to save comments
%-------------------------------------------------------------------------------
    function saveUserComments(varargin)
        guiHandles.cancelWait=true;
        % All screenshots will be saved in a directory which is the
        % name of the unit followed by date
        commentsFilename = sprintf('%s-%s-comments-%s',...
            strrep(scriptName,' ',''),...
            unitName,...
            datestr(now,'yyyy-mm-dd-HH-MM-SS')); %#ok<NASGU>
        userComments = get(commentsEditBox,'String'); %#ok<NASGU>
        save(fullfile(reportsDirName,commentsFilename),...
            'userComments');
        guiHandles.cancelWait=false;
    end

%--------------------------------------------------------------------------
% Internal function to generate and create the reports directory
%--------------------------------------------------------------------------
    function generatedReportsDir = generate_reports_dir
        % check if there is a specific directory specified for all the reports
        % this is specified by MAKO_REPORTS_DIR environment variable
        % if not specified on windows use the desktop directory and on linux use
        % the tmp directory
        if ispc
            if isempty(getenv('MAKO_LOG_DIR'))
                baseDir = fullfile(getenv('USERPROFILE'),'Desktop');
            else
                baseDir = getenv('MAKO_LOG_DIR');
            end
        else
            if isempty(getenv('LOG_DIR'))
                baseDir = tempdir;
            else
                baseDir = getenv('LOG_DIR');
            end
        end
        
        generatedReportsDir  = fullfile(baseDir,...
            sprintf('%s-%s-Reports',...
            unitName,...
            datestr(now,'yyyy-mm-dd')));

        if (~isdir(generatedReportsDir))
            mkdir(generatedReportsDir);
        end
    end

end


% --------- END OF FILE ----------
