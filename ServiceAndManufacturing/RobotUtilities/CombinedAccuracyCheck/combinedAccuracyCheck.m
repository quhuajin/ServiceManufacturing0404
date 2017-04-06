function guiHandles=combinedAccuracyCheck(hgs,varargin)

% combinedAccuracyCheck Gui to guide user to perform the accuracy check (Camera and Robot combined)
%
% Syntax:
%   combinedAccuracyCheck(hgs)
%       this script can be used to check the accuracy of the Robot and the
%       Camera together.
%
% Notes:
%   The script assumes that there exists a camera connected to the robot.
%   This script will prompt the user to exercise the Robot through various
%   poses and will compare the position measured by the Robot to that
%   measured by the camera.  It checks only the relative distances between
%   measurements in both camera space and robot space uses this to
%   determine if the robot and camera are within specifications.
%
%   The position guidance is assuming the TGS2.0 system.  The user will be
%   haptically guided to move to different positions.  When at the target
%   positions the user may be asked to move the elbow up or down to make
%   sure we get joint space motion
%
% See Also:
%   hgs_robot
%

%
% $Author: dmoses $
% $Revision: 3696 $
% $Date: 2014-12-18 12:55:36 -0500 (Thu, 18 Dec 2014) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot
defaultRobotConnection = false;

realData = 1;

if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles='';
        return;
    end
    
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
elseif(nargin > 1 && strcmp(varargin(1),'simulate'))
    hgs = [];
    realData = 0;
end

if(realData)
    % Check if the specified argument is a hgs_robot
    if (~isa(hgs,'hgs_robot'))
        error('Invalid argument: argument must be an hgs_robot object');
    end
    
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');
else
    % skip robot check and gravity knee
end

% Generate the gui
guiHandles = generateMakoGui('Accuracy Check',[],hgs,true);

userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

% Set the constants for the test
TEST_TOOL_SROM = fullfile('sroms','110740.rom');
CUBE_EDGE_LENGTH = 0.05; % meters

RMS_ERROR_LIMIT = 0.4*0.001; % meters
MAX_ERROR_LIMIT = 0.76*0.001; % meters
RMS_WARNING_RATIO = 0.80;
MAX_WARNING_RATIO = 0.7895;

NUM_OF_SAMPLES_PER_READING = 10;
MAX_SAMPLE_DEV_CAMERA = 0.2*0.001; % meters
MAX_SAMPLE_DEV_ROBOT = 0.2*0.001; % meters

if(~realData)
    %setup simulate variables
    hgs.CALEE_SERIAL_NUMBER = 'Simulated CALEE';
    simRMSError = RMS_ERROR_LIMIT*1.1;
    simMaxError = MAX_ERROR_LIMIT*1.1;
    simRMSWarning = RMS_ERROR_LIMIT*RMS_WARNING_RATIO*1.1;
    simMaxWarning = MAX_ERROR_LIMIT*MAX_WARNING_RATIO*1.1;
    simulateRmsError = 0;
    simulateMaxError = 0;
end

MAX_NUM_POINTS = 9; % DONOT CHANGE -> 9 = 8 points on cube + center point

EE_IMAGE_FILE = fullfile('images','Combocheck.png');

if(realData)
    % gather required data from arm
    endEffectorTransform = eye(4);
    endEffectorTransform(1:3,4) = hgs.CALIB_BALL_A';
else
    % skip end effector transform
end

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@initializeCamera);


% setup the termination function
set(guiHandles.figure,'CloseRequestFcn',@closeFcn);

% initialize location for data capture
capturedToolPosition = zeros(MAX_NUM_POINTS,3);
capturedRobotPosition = zeros(MAX_NUM_POINTS,3);

% initialize variables
terminate_loops = false;
plotTimer=[];
if(realData)
    ndi = ndi_camera(hgs);
else
    % skip camera connect
end
tinybeep = wavread(fullfile('sounds','tinybeep.wav'));

if(realData)
    % clean up the robot
    reset(hgs);
else
    % skip hgs reset
end

% load the image file data
ee_image_file_data = imread(EE_IMAGE_FILE);

% Setup to show the serial numbers
commonProperties = struct(...
    'Style','text',...
    'HorizontalAlignment', 'left', ...
    'Units','Normalized',...
    'BackgroundColor',get( guiHandles.uiPanel,'BackgroundColor'),...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'SelectionHighlight','off'...
    );

uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Position',[0.1, 0.65 0.8 0.05],...
    'String','Calibration EE Serial Number');
uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'BackgroundColor','white',...
    'Position',[0.1, 0.55 0.8 0.1],...
    'String',hgs.CALEE_SERIAL_NUMBER);

updateMainButtonInfo(guiHandles,'Click to confirm SN and start Accuracy Check');

%initialize tracker mode
trackerMode=0; %0-setup mode,1-tracking mode

%--------------------------------------------------------------------------
% internal function to initialize the camera
%--------------------------------------------------------------------------
    function initializeCamera(varargin)
        try
            log_message(hgs,'Combined Accuracy Check started');
            delete(get(guiHandles.uiPanel,'children'));
            updateMainButtonInfo(guiHandles,'text','Initializing Camera...');
            
            %check if homing done
            if(realData)
                if ~homingDone(hgs)
                    presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
                    log_message(hgs,'Combined Accuracy Check failed (Homing not done)',...
                        'ERROR');
                    return;
                end
            else
                % skip homing check
            end
            
            % Generate a big text box with instructions on where to place the
            % tracker
            
            uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontWeight','bold',...
                'FontUnits','normalized',...
                'FontSize',0.2,...
                'String',{'Place Tracker on CALIB BALL A',...
                'and',...
                'Arm in desired surgical pose'},...
                'Position',[0.1 0.78 0.8 0.2]);
            
            % setup an axis to show the figure
            axisHandle = axes(...
                'parent', guiHandles.uiPanel,...
                'Position',[0.1 0.05 0.8 0.7],...
                'XGrid','off',...
                'YGrid','off',...
                'box','off',...
                'visible','off',...
                'NextPlot', 'replace');
            axis(axisHandle,'equal');
            image(ee_image_file_data,'parent',axisHandle);
            axis(axisHandle, 'off')
            axis(axisHandle,'image')
            drawnow;
            
            try
                
                % If this is a rerun.  stop the plot timer
                if isempty(plotTimer)
                    % initialize the camera
                    init(ndi);
                    
                    % add a little dalay before calling init_tool
                    % and retry once after the intial failure
                    try
                        pause(0.5);
                        init_tool(ndi,TEST_TOOL_SROM);
                    catch
                        try
                            pause(1.0);
                            init_tool(ndi,TEST_TOOL_SROM);
                        catch
                            presentMakoResults(guiHandles,'FAILURE',...
                                sprintf('Camera Tool Init Failed, Exit and Check again: %s',lasterr));
                            
                            log_message(hgs,['Combined Accuracy Check init_tool failed,',...
                                lasterr],'ERROR');
                            return;
                        end
                    end
                    
                    % Generate a plot
                    plotHandle = plot(ndi,guiHandles.extraPanel);
                    plotTimer = plotHandle.timer;
                    
                    % Slow the timer it is not so important
                    stop(plotTimer);
                    set(plotTimer,'Period',0.05);
                    start(plotTimer);
                    
                end
                
                % check if tool is visible
                toolInfo = tx(ndi);
                
                %tracker mode is set to tracking, update flag
                trackerMode=1;
            catch
                return;
            end
            
            % Get stuck till the tracker becomes visible
            try
                robotFrontPanelEnable(hgs,guiHandles);
                while ~strcmpi(toolInfo.status,'VISIBLE') && ~terminate_loops
                    updateMainButtonInfo(guiHandles,'text',...
                        'Make Sure Tracker is visible');
                    toolInfo = tx(ndi);
                end
                
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click to continue, when ready',@accuracyCheck);
            catch
                return;
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to perfom the accuracy test
%--------------------------------------------------------------------------

    function accuracyCheck(varargin)
        try
            % Clear the GUI
            delete(get(guiHandles.uiPanel,'children'));
            
            % Generate a progressbar
            progaxes = axes(...
                'Parent',guiHandles.uiPanel,...
                'Color','white',...
                'Position',[0.1 0.85 0.8 0.075],...
                'XLim',[0 1],...
                'YLim',[0 1],...
                'Box','on',...
                'ytick',[],...
                'xtick',[] );
            progressbar = patch(...
                'Parent',progaxes,...
                'XData',[0 0 0 0],...
                'YData',[0 0 1 1],...
                'FaceColor','green'...
                );
            
            if(realData)
                % get the data and make sure this is not terminated
                try
                    [holdPosActive,capturedToolPosition(1,1:3),capturedRobotPosition(1,1:3)] = collectDataPoint;
                catch
                    if terminate_loops
                        return;
                    end
                end
                if ~holdPosActive
                    errorMsg=char(hgs.hold_position.mode_error);
                    presentMakoResults(guiHandles,'FAILURE',...
                        sprintf('Arm Stopped: %s',errorMsg));
                    
                    log_message(hgs,['Combined Accuracy Check failed (Arm Stopped: ',...
                        errorMsg,')'],'ERROR');
                    return;
                end
                
                % First point captured (update progressbar)
                % update the progressbar
                testProgress = 1/MAX_NUM_POINTS;
                set(progressbar,...
                    'XData',[0 testProgress testProgress 0]);
                
                % generate the list of targets
                % Now establish target positions based on the cartesian position
                % move 0.1 m in every direction
                targetPosList(1,1:3) = capturedRobotPosition(1,1:3) + [-CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH];
                targetPosList(2,1:3) = capturedRobotPosition(1,1:3) + [-CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH];
                targetPosList(3,1:3) = capturedRobotPosition(1,1:3) + [ CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH];
                targetPosList(4,1:3) = capturedRobotPosition(1,1:3) + [ CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH];
                targetPosList(5,1:3) = capturedRobotPosition(1,1:3) + [ CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH];
                targetPosList(6,1:3) = capturedRobotPosition(1,1:3) + [-CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH  CUBE_EDGE_LENGTH];
                targetPosList(7,1:3) = capturedRobotPosition(1,1:3) + [-CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH];
                targetPosList(8,1:3) = capturedRobotPosition(1,1:3) + [ CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH -CUBE_EDGE_LENGTH];
                
                % generate the axis in the uipanel
                cubeEdgeVerts = [...
                    1 2;
                    2 3;
                    3 4;
                    4 5;
                    5 6;
                    6 7;
                    7 8;
                    8 5;
                    4 1;
                    1 6;
                    2 7;
                    3 8;
                    ];
                
                dispAxes = axes(...
                    'Parent',guiHandles.uiPanel,...
                    'Color','white',...
                    'Position',[0.1 0.05 0.8 0.65],...
                    'Visible','off');
                
                % generate a cube based on the points received
                for i=1:length(cubeEdgeVerts)
                    line(...
                        [targetPosList(cubeEdgeVerts(i,1),1) targetPosList(cubeEdgeVerts(i,2),1)],...
                        [targetPosList(cubeEdgeVerts(i,1),2) targetPosList(cubeEdgeVerts(i,2),2)],...
                        [targetPosList(cubeEdgeVerts(i,1),3) targetPosList(cubeEdgeVerts(i,2),3)],...
                        'linestyle','-',...
                        'marker','*',...
                        'linewidth',2,...
                        'markersize',5,...
                        'color',[0.75 0.75 0.75],...
                        'parent',dispAxes);
                end
                
                % select view lefty or righty
                if hgs.joint_angles(3)>0
                    view(dispAxes,[180+37.5,30])
                    text(0.25,0.5,'Arm Configuration: LEFTY',...
                        'parent',progaxes,...
                        'fontunits','normalized',...
                        'fontsize',0.5)
                else
                    view(dispAxes,[-37.5,30]);
                    text(0.25,0.5,'Arm Configuration: RIGHTY',...
                        'parent',progaxes,...
                        'fontunits','normalized',...
                        'fontsize',0.5)
                end
                
                %make it a little bigger so that the the user can deviate form the
                %line
                axis(dispAxes,'equal');
                axis(dispAxes,axis(dispAxes)+[-0.005 0.005 -0.005 0.005 -0.005 0.005]);
                
                % generate a line to show user how to move
                currentRobPos = getTipPosition;
                guideDisplayLine =  line(...
                    [currentRobPos(1) targetPosList(1,1)],...
                    [currentRobPos(2) targetPosList(1,2)],...
                    [currentRobPos(1,3) targetPosList(1,3)],...
                    'linestyle','-',...
                    'marker','o',...
                    'linewidth',4,...
                    'markersize',5,...
                    'erasemode','xor',...
                    'color',[0 0 0],...
                    'parent',dispAxes);
                
                % Now guide user to move through the 8 points
                for i=1:MAX_NUM_POINTS-1
                    updateMainButtonInfo(guiHandles,'text','Please move to next target position');
                    % show the target in a prominant color
                    line(...
                        [targetPosList(i,1),targetPosList(i,1)],...
                        [targetPosList(i,2),targetPosList(i,2)],...
                        [targetPosList(i,3),targetPosList(i,3)],...
                        'linestyle','none',...
                        'marker','*',...
                        'markersize',20,...
                        'color',[0 0 1],...
                        'parent',dispAxes);
                    hapticMode=guideToPosition(targetPosList(i,:),i,guideDisplayLine);
                    % check if the mode is still running
                    % if not fail immediately
                    if ~hapticMode
                        errorMsg=char(hgs.haptic_interact.mode_error);
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Arm Stopped: %s',errorMsg));
                        
                        log_message(hgs,['Combined Accuracy Check failed (Arm Stopped: ',...
                            errorMsg,')'],'ERROR');
                        return;
                    end
                    
                    % if this was a request to quit quit immediately
                    if terminate_loops
                        return;
                    end
                    
                    % get the data and check if the data collection was interrupted
                    try
                        [holdPosActive,capturedToolPosition(i+1,1:3),capturedRobotPosition(i+1,1:3)] = collectDataPoint;
                    catch
                        if terminate_loops
                            return;
                        end
                    end
                    if ~holdPosActive
                        errorMsg=char(hgs.hold_position.mode_error);
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Arm Stopped: %s',errorMsg));
                        
                        log_message(hgs,['Combined Accuracy Check failed (Arm Stopped: ',...
                            errorMsg,')'],'ERROR');
                        return;
                    end
                    
                    robotMotionDist(i) = norm(capturedRobotPosition(i+1,:)-capturedRobotPosition(i,:)); %#ok<AGROW>
                    trackerMotionDist(i) = norm(capturedToolPosition(i+1,:)-capturedToolPosition(i,:)); %#ok<AGROW>
                    
                    % update the progressbar
                    testProgress = (i+1)/MAX_NUM_POINTS;
                    set(progressbar,...
                        'XData',[0 testProgress testProgress 0]);
                end
                
                % free the robot as the test is done
                mode(hgs,'zerogravity');
                
                reset(hgs); % clear haptic data
                
                % free the robot as the test is done
                mode(hgs,'zerogravity');
                
                % compute the errors
                measurementError = robotMotionDist-trackerMotionDist;
                maxError = max(abs(measurementError));
                rmsError = norm(measurementError)/sqrt(MAX_NUM_POINTS-1);
                
            else
                % simulate data
                maxError = simulateMaxError;
                rmsError = simulateRmsError;
                robotMotionDist = [];
                trackerMotionDist = [];
                capturedRobotPosition = [];
                capturedToolPosition = [];
            end
            
            % Save results
            reportFileName  = ['combinedAccuracyTest-' datestr(now,'yyyy-mm-dd-HH-MM')];
            fullReportFile = fullfile(guiHandles.reportsDir,reportFileName);
            
            save(fullReportFile,...
                'capturedRobotPosition','capturedToolPosition',...
                'robotMotionDist','trackerMotionDist',...
                'maxError','rmsError');
            
            % Present the accuracy results
            presentAccuracyResults(rmsError,maxError);
        catch
            return;
        end
        
    end

%--------------------------------------------------------------------------
% internal function to collect robot and camera position
%--------------------------------------------------------------------------
    function [holdPosActive,cameraPos,robotPos] = collectDataPoint
        
        try
            updateMainButtonInfo(guiHandles,'text','Collecting Data');
            % Put the robot in hold_position mode and wait for short while to
            % settle
            mode(hgs,'hold_position');
            pause(0.5);
            
            % take 20 samples and compute the mean
            robPosList = zeros(NUM_OF_SAMPLES_PER_READING,3);
            camPosList = zeros(NUM_OF_SAMPLES_PER_READING,3);
            
            cameraPos = mean(camPosList);
            robotPos = mean(robPosList);
            
            %initialize hold position active to true
            holdPosActive=true;
            
            numOfPoints = 1;
            while ~terminate_loops
                %check if hold position active, if not, return.
                if ~strcmp(mode(hgs),'hold_position')
                    holdPosActive=false;
                    return;
                end
                
                currentRobPos = getTipPosition;
                camReply = bx(ndi);
                if strcmpi(camReply.status,'MISSING')
                    mesgText = 'TRACKER NOT VISIBLE';
                else
                    mesgText = 'Collecting Data';
                    currentCamPos = camReply.position;
                    
                    if numOfPoints <= NUM_OF_SAMPLES_PER_READING
                        robPosList(numOfPoints,1:3) = currentRobPos;
                        camPosList(numOfPoints,1:3) = currentCamPos;
                        numOfPoints = numOfPoints+1;
                    else
                        mesgText = 'Waiting for data to settle';
                        % keep a ring buffer
                        robPosList = [robPosList(2:end,:);currentRobPos];
                        camPosList = [camPosList(2:end,:);currentCamPos];
                        
                        % check if the camera and robot are stable if so
                        % average and return immediatelys
                        if all(std(camPosList)<MAX_SAMPLE_DEV_CAMERA) ...
                                && all(std(robPosList)< MAX_SAMPLE_DEV_ROBOT)
                            cameraPos = mean(camPosList);
                            robotPos = mean(robPosList);
                            sound(tinybeep);
                            return;
                        end
                    end
                end
                updateMainButtonInfo(guiHandles,mesgText);
            end
            
            % if i get here there was a request to terminate the function
            % return with error
            error('Data collection terminated');
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to present Results
%--------------------------------------------------------------------------
    function presentAccuracyResults(rmsError,maxError)
        try
            % clean up the uipanel
            delete(get(guiHandles.uiPanel,'children'));
            
            % Check each parameter
            resString={};
            [results(1),resColor,resString] = checkResults(...
                rmsError,RMS_ERROR_LIMIT,RMS_WARNING_RATIO,'RMS Error',resString);
            
            % display the results and color code
            uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontUnits','normalized',...
                'FontSize',0.6,...
                'BackgroundColor',resColor,...
                'String',sprintf('RMS Error = %3.4f mm',rmsError*1000),...
                'Position',[0.1 0.8 0.8 0.1]);
            
            [results(2),resColor,resString] = checkResults(...
                maxError,MAX_ERROR_LIMIT,MAX_WARNING_RATIO,'Max Error',resString);
            
            % display the results and color code
            uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontUnits','normalized',...
                'FontSize',0.6,...
                'BackgroundColor',resColor,...
                'String',sprintf('Max Error = %3.4f mm',maxError*1000),...
                'Position',[0.1 0.6 0.8 0.1]);
            
            % present the results
            if ~any(results<1)
                presentMakoResults(guiHandles,'SUCCESS');
                
                % log the success
                if(realData)
                    log_message(hgs,sprintf(['Combined Accuracy Check successful ',...
                        '(Max Err %3.3f mm, RMS Err %3.3f mm)'],maxError*1000,rmsError*1000));
                else
                    % skip log
                end
                
                %fill in user data
                userDataStruct.results=1;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
            elseif ~any(results<0)
                presentMakoResults(guiHandles,'WARNING',resString);
                
                % log the results
                if(realData)
                    log_message(hgs,sprintf(['Combined Accuracy Check warning ',...
                        '(Max Err %3.3f mm, RMS Err %3.3f mm)'],maxError*1000,rmsError*1000),'WARNING');
                else
                    % skip log
                end
                %fill in user data
                userDataStruct.results=2;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
            else
                presentMakoResults(guiHandles,'FAILURE',resString);
                if(realData)
                    % log the results
                    log_message(hgs,sprintf(['Combined Accuracy Check error ',...
                        '(Max Err %3.3f mm, RMS Err %3.3f mm)'],maxError*1000,rmsError*1000),'ERROR');
                else
                    % skip log
                end
                %fill in user data
                userDataStruct.results=-1;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
            end
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to check results
%--------------------------------------------------------------------------
    function [checkStatus,resultColor,resString] = checkResults(...
            measuredValue,limit,warning_ratio,paramName,resString)
        try
            if measuredValue<limit*warning_ratio
                % All is good
                checkStatus=1;
                resultColor = 'green';
            elseif measuredValue<limit
                % This is in warning range
                checkStatus=0;
                resultColor = 'yellow';
                % Append to results string
                resString{end+1} = sprintf('%s : %3.2f (lim %3.2f mm)',...
                    paramName,measuredValue*1000,limit*1000);
            else
                % this is in error state
                resultColor = 'red';
                checkStatus=-1;
                resString{end+1} = sprintf('%s : %3.2f (lim %3.2f mm)',...
                    paramName,measuredValue*1000,limit*1000);
            end
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to get tip position from robot
%--------------------------------------------------------------------------
    function tipPosition = getTipPosition
        try
            tipTransform = reshape(hgs.flange_tx,4,4)' * endEffectorTransform;
            tipPosition = tipTransform(1:3,4)';
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to haptically guide to the next target position
%--------------------------------------------------------------------------
    function hapticMode=guideToPosition(targetPosition,targetIndex,lineHandle)
        try
            
            % create the haptic object with a random name
            moveToHaptics = hgs_haptic(hgs,...
                sprintf('MoveTo___Point%d',targetIndex),...
                'target_position',targetPosition,...
                'moveto_stiffness',12000,...
                'moveto_damping',10,...
                'moveto_fmax',50,...
                'moveto_radius',0.2,...
                'confine_radius',0.2,...
                'confine_stiffness',12000,...
                'confine_damping',30,...
                'confine_fmax',60,...
                'switch_radius',0.002);
            
            % create the haptic interaction module
            mode(hgs,'haptic_interact',...
                'end_effector_tx',endEffectorTransform,...
                'vo_and_frame_list',moveToHaptics.name);
            
            % Wait for user to get to target
            targetReached = false;
            
            %initialize haptic
            hapticMode=true;
            
            while ~targetReached && ~terminate_loops
                moveToVars = get(moveToHaptics);
                if moveToVars.target_reached == 1
                    targetReached = true;
                end
                %check if module is running, if not, return.
                if ~strcmp(mode(hgs),'haptic_interact')
                    hapticMode=false;
                    return;
                end
                
                currentRobPos = getTipPosition;
                
                
                % update the graphics
                set(lineHandle,...
                    'XData',[currentRobPos(1),targetPosition(1)],...
                    'YData',[currentRobPos(2),targetPosition(2)],...
                    'ZData',[currentRobPos(3),targetPosition(3)]...
                    );
                
                % pause and give the user a chance to interact if need be
                pause(0.05);
                drawnow;
            end
        catch
            return;
        end
    end


%--------------------------------------------------------------------------
% internal function to close the GUI
%--------------------------------------------------------------------------
    function closeFcn(varargin)
        try
            if ~isempty(plotTimer)
                % stop the timer
                stop(plotTimer);
                delete(plotTimer);
            end
            terminate_loops = true;
            % cleanup
            reset(hgs);
            % Put the robot in gravity mode with hold enabled
            mode(hgs,'zerogravity');
            %set tracker to setup mode if it is in tracking mode
            if trackerMode
                setmode(ndi,'SETUP');
            end
        catch
        end
        
        % close the connection if it was established by this script
        if defaultRobotConnection
            log_message(hgs,'Combined accuracy check script closed');
            close(hgs);
        end
        
        closereq
    end

end

% --------- END OF FILE ----------
