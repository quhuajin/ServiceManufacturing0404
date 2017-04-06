
function ServiceAndManufacturingMain

% ServiceAndManufacturingMain Top level gui to execute all the service and mfg scripts
%
% Syntax:
%   ServiceAndManufacturingMain
%       Starts up the top level gui to allow user to execute all the
%       service and manufacturing scripts
%
% Notes:
%   If the target machine is not specified the script will assume that the
%   target is the default ROBOT_HOST ip (172.16.16.100)
%
% See Also:
%   mcc, makeRobotUtilities, makeQIPScripts, makeServiceMfgScripts


% detemine the install directory
serviceMainInstallPath = which('ServiceAndManufacturingMain');
serviceMainDirLocation = strfind(serviceMainInstallPath,...
    'ServiceAndManufacturingMain_mcr');
if isempty(serviceMainDirLocation)
%    errordlg('Unable to determine install directory');
%    return;
end
installDir = serviceMainInstallPath(1:serviceMainDirLocation-1);
QIPScriptsDir = fullfile(installDir,'QIPScriptsBin');
RobotUtilitiesDir = fullfile(installDir,'RobotUtilitiesBin');

try 
%Check if it is RIO 3.1 system. If yes, the anspach is removed so there is
%no Burr Status Check in the presurgery check 
hgs=hgs_robot('172.16.16.100');
IsRIO3_1System=0;
rioHardwareVersion = hgs.ARM_HARDWARE_VERSION;
switch (int32(rioHardwareVersion * 10 + 0.05))
    case 31  % 3.1
IsRIO3_1System=1; % the system is V3.1 
end 

catch
    IsRIO3_1System=0;%Default not a RIO 3.1 system 
end
% Define the Menu Lists
% lists are in the format 
% label,BinaryFileName, <NonDefaultDirectory if needed>
fieldServiceMenu = {...
    {'Transmission Check','TransmissionCheck'}
    {'System Propagation','PropagateSystem'}
    {'Find Friction Constants','FindFrictionConstants'}
    {'Phase Check','PhaseCheck'}
    {'Optical Compliance Check','OpticalComplianceTest'}
    {'Motor Phasing','MotorPhasing'}
    {'Auto Kinematic Calibration','AutoKinematicCalibration'}
    {'BallBar Data Collection','BallBarDataCollection'}
    {'Kinematic Calibration','KinematicCalibration'}
    {'Find Gravity Constants','SelectGravityConstants'}
    {'Find Homing Constants','FindHomingConstants'}
    {'Find Transmission Ratio','FindTransmissionRatio'}
    {'Motor Bandwidth Test','FieldMotorBandwidthTest'}
    {'Cutter Test','FieldCutterTest'}
    {'Upload EE File','Upload_EE_File'}
    {'Hall Phase Tool','HallPhaseTool'}
    {'Brakes Tool','BrakesTool'}
    {'HASS Test','FieldHASSTest'}
    
    };

configurationFileSetMenu = {
    {'Check Configuration File','CheckConfigurationParams'}
    {'Save and Load Cfg File','SaveLoadCfgFile'}
    {'Restore Cfg File Defaults','RestoreCfgFileDefaults'}
    {'Set Serial Number','SetArmSerialNumber'}
    {'Motor Phasing','MotorPhasing'}
    {'Find Homing Constants','FindHomingConstants'}
    {'Phase Check','PhaseCheck'}
    {'Find Transmission Ratio','FindTransmissionRatio'}
    {'Find Gravity Constants','SelectGravityConstants'}
    {'Find Friction Constants','FindFrictionConstants'}
    {'Upload EE File','Upload_EE_File'}
    {'Auto Kinematic Calibration','AutoKinematicCalibration'}
    {'Kinematic Calibration','KinematicCalibration'}
    {'BallBar Data Collection','BallBarDataCollection'}
    {'Manual Arm Accuracy Check','ManualArmAccuracyCheck'}
    {'Auto Arm Accuracy Check','AutoArmAccuracyCheck'}
        };


% For RIO 3.1, there is not Burr Status Check menu 
if (IsRIO3_1System==1)
    
presurgeryMenu = {...
    {'Pre-Surgery Check','PresurgeryCheck'}
    {'Arm Status Check','ArmStatusCheck'}
    {'Home Robotic Arm','HomeRobot'}
    {'Combined Accuracy Check','CombinedAccuracyCheck'}
    {'Auto Arm Accuracy Check','AutoArmAccuracyCheck'}
    {'Brake Check','BrakeCheck'}
    {'Check Angle Discrepancy','CheckAngleDiscrepancy'}
    {'MICS Status Check','MICSStatusCheck'}
    {'Manual Arm Accuracy Check','ManualArmAccuracyCheck'}
    {'Camera Accuracy Check','CameraAccuracyCheck'}
    };
else 
    
presurgeryMenu = {...
    {'Pre-Surgery Check','PresurgeryCheck'}
    {'Arm Status Check','ArmStatusCheck'}
    {'Home Robotic Arm','HomeRobot'}
    {'Combined Accuracy Check','CombinedAccuracyCheck'}
    {'Auto Arm Accuracy Check','AutoArmAccuracyCheck'}
    {'Brake Check','BrakeCheck'}
    {'Check Angle Discrepancy','CheckAngleDiscrepancy'}
    {'Burr Status Check','BurrStatusCheck'}
    {'MICS Status Check','MICSStatusCheck'}
    {'Manual Arm Accuracy Check','ManualArmAccuracyCheck'}
    {'Camera Accuracy Check','CameraAccuracyCheck'}
    };
end

    QIPMenu = {
    {'Motor Test','MotorTestQIP'}
    {'Joint Test','JointTestQIP'}
    {'Joint Build','JointBuild'}
    {'Anspach Box Test','AnspachBoxTest'}
    {'CPCI Controller Box Test','MakoCtrlBoxTest'}
    {'Cutter Test','CutterTest'}
    {'Foot Switch Test','FootSwitchTest'}
    {'MICS Test','MICSTest'}
    {'Motor Bandwidth Test','MotorBandwidthTest'}
    {'Robot Accuracy Test','RobotAccuracyCheck'}
    {'Brake Check','BrakeCheck',RobotUtilitiesDir}
    {'Check Angle Discrepancy','CheckAngleDiscrepancy',RobotUtilitiesDir}
    {'Transmission Check','TransmissionCheck',RobotUtilitiesDir}
    {'System Propagation','PropagateSystem',RobotUtilitiesDir}
    {'Find Friction Constants','FindFrictionConstants',RobotUtilitiesDir}
    {'System Compliance Test','SystemCompliance'}
    {'System Force Transparency Test','ForceTransparency'}
    {'HASS Test','HASSTest'}
    {'Phase Check','PhaseCheck',RobotUtilitiesDir}
    {'Check Configuration File','CheckConfigurationParams',RobotUtilitiesDir}
    };



% Check if the Robot Hosts Environment Variable is set if not use default
if isempty(getenv('ROBOT_HOST'))
    setenv('ROBOT_HOST','172.16.16.100');
    targetArmDisp = {};
else
    targetArmDisp = {['TARGET ROBOT: ' getenv('ROBOT_HOST')]};
end

% Generate the Title String
titleString = 'Service & Manufacturing Scripts';
subtitleString = {['(ver: ',generateVersionString,' )'],targetArmDisp{:}};

% Ask user if QIP or RobotUtilities need to be executed
mainButtonList = {...
    'Home Robotic Arm',...
    '------',...
    'Field Service',...
    'Set Configuration Parameters',...
    'QIP',...
    'Presurgery Checks',...
    '------',...
    'Add Log Entry',...
    'View Robot Logs',...
    'Arm Logger',...
    'Zerogravity/Free Mode',...
    'Turn ON/OFF Camera',...
    'Enable Cutter',...
    '------',...
    'Setup Network Static',...
    'Setup Network Dynamic',...
    '------',...
    'CRISIS LoadNGo',...
    '------',...
    '------ QUIT / SHUTDOWN -----'};

while true
    switch customMenu('Service & Manufacturing Scripts',...
            titleString,...
            subtitleString,...
            mainButtonList)
        case 1
            executeScript(fullfile(RobotUtilitiesDir,'HomeRobot'));
        case 2
            % skip line separator
        case 3
            displayFunctionsMenu(fieldServiceMenu,'Field Service',...
                RobotUtilitiesDir);
        case 4
            displayFunctionsMenu(configurationFileSetMenu,...
                'Set Configuration Parameters',...
                RobotUtilitiesDir);            
        case 5
            displayFunctionsMenu(QIPMenu,'QIP',...
                QIPScriptsDir);
        case 6
            displayFunctionsMenu(presurgeryMenu,'Presurgery Checks',...
                RobotUtilitiesDir);            
        case 7
            % skip line separator
        case 8
            addLogEntry;
        case 9
            executeScript(fullfile(RobotUtilitiesDir,'ViewRobotLogs'));
        case 10
            executeScript(fullfile(RobotUtilitiesDir,'ArmLogger'));    
        case 11
            changeToZerogravity;
        case 12
            turnOnOffCamera;
        case 13
            enableCutter;
        case 14
            % skip line separator            
        case 15
            if ispc
                setup_network_gui('STATIC');
            else
                uiwait(errordlg('Function is disabled on Linux systems'));
            end
        case 16
            if ispc
                setup_network_gui('DYNAMIC');
            else
                uiwait(errordlg('Function is disabled on Linux systems'));
            end
        case 17
            % skip line separator
        case 18
            executeScript(fullfile(RobotUtilitiesDir,'LoadNGo'));
        case 19
            % skip line separator
        case {0,20}
            if shutdownSystem
                % user asked to cancel (just ignore)
            else
                break;
            end
    end
end

end

%--------------------------------------------------------------------------
% internal function to shutdown the system
%--------------------------------------------------------------------------
function cancelRequest = shutdownSystem
% refresh screen to make it feel more responsive
drawnow
cancelRequest = false;
% try to connect to the robot
try
    try
        hgs = hgs_robot;
    catch
        if strcmp(questdlg({...
                sprintf('Unable to connect to Robot'),...
                '','Click Quit to exit Service/Manufacturing Menu'},...
                'robot connection',...
                'Quit','Cancel','Quit'),'Quit')
            return;
        else
            cancelRequest = true;
            return;
        end
    end

    % check if the camera connected variable has been set
    if ~hgs.CAMERA_CONNECTED
        if strcmp(questdlg({'Camera is DISABLED',...
                'Do you want to enable before quitting'},'camera/enable/disable',...
                'Yes','No','Yes'),'Yes')
            hgs.CAMERA_CONNECTED = 1;
        end
    end
    
    % Ask user to confirm
     switch questdlg('Do you want to shutdown the arm or just quit',...
            'Shutdown Yes/No',...
            'Shutdown','Quit','Cancel','Quit')
        case 'Shutdown'
            drawnow
            % Shutdown
            % change to zerogravity
            if homingDone(hgs)
                mode(hgs,'zerogravity','ia_hold_enable',1);
            end
            
            ghdl = msgbox({'Move Arm to Transport Position',...
                'Click OK to Continue'},...
                'TransportPosition');
            uiwait(ghdl);
            
            % Send the shutdown command to the robot
            try
                comm(hgs,'peripheral_comm','UPS_SHUT_DOWN');
            catch
            end
            
            % Constantly Ping to figure out computer shutdown
            tic
            if ispc
                pingCommand = 'ping -w 1000 -n 1 ';
            else
                pingCommand = 'ping -w 1 -c 1 ';
            end
            progressValue = 0;
            progressBar = waitbar(progressValue,...
                {'Shutting down System','Please Wait....'});
            while toc<10
                % ping the robot for a quick check
                [pingFailure,pingReply] = system([pingCommand,hgs.host]); %#ok<NASGU>
                if pingFailure
                    break;
                end
                pause(0.5);
                progressValue = progressValue+1/40;
                waitbar(progressValue,progressBar);
            end

            % Clear up the progressbar
            try
                waitbar(1,progressBar);
                drawnow;
                pause(0.5);
                close(progressBar);
            catch
            end

            % Tell user to turn off POWER
            ghdl = msgbox({'Computer Shutdown Successfully',...
                'Turn OFF MAIN POWER'},...
                'ShutdownComplete','warn');
            uiwait(ghdl);
            close(hgs);
            return;
         case 'Cancel'
             % user changed mind
             cancelRequest = true;
             return;
         otherwise
             drawnow;
     end
catch
    ghdl = errordlg(lasterr,'Shutdown failure');
    uiwait(ghdl);
end

% if there was a successful connection close it
if exist('hgs','var')
    close(hgs);
end

end

%--------------------------------------------------------------------------
% internal function to Change robot mode to zerogravity
%--------------------------------------------------------------------------
function changeToZerogravity
% refresh screen to make it feel more responsive
drawnow
% try to connect to the robot
try
    hgs = hgs_robot;
    % change to zerogravity
    mode(hgs,'zerogravity','ia_hold_enable',0);
    % check if this was successful
    if ~strcmpi(mode(hgs),'zerogravity')
        % check why the mode didnt change
        ghdl = errordlg(hgs.zerogravity.mode_error,...
            'Zerogravity Set failure');
    else
        ghdl = msgbox({'Arm Successfully set to','Zerogravity/Free mode'},...
            'Zerogravity Set Success');
    end
    close(hgs);
catch
    ghdl = errordlg(lasterr,'Zerogravity Set failure');
end
% wait for user to interact
uiwait(ghdl);
% if there was a successful connection close it
if exist('hgs','var')
    close(hgs);
end

end

%--------------------------------------------------------------------------
% internal function to turn on and turn off the camera
%--------------------------------------------------------------------------
function turnOnOffCamera
% refresh screen to make it feel more responsive
drawnow
try
    % try to connect to the robot
    hgs = hgs_robot;
    % now query the current state of the CAMERA connected variable
    if hgs.CAMERA_CONNECTED
        cameraStateString = 'Current CAMERA Setting : ENABLED';
    else
        cameraStateString = 'Current CAMERA Setting : DISABLED';
    end

    switch questdlg(cameraStateString,...
            'Camera Enable/Disable',...
            'Enable','Disable','Cancel','Enable')
        case 'Enable'
            drawnow
            % enable button was pressed
            hgs.CAMERA_CONNECTED = 1;
            restartCRISIS(hgs);
            ghdl = msgbox('CAMERA Successfully ENABLED',...
                'Camera Setup');
            uiwait(ghdl);
        case 'Disable'
            % disable button was pressed
            drawnow
            hgs.CAMERA_CONNECTED = 0;
            restartCRISIS(hgs);
            ghdl = msgbox('CAMERA Successfully DISABLED',...
                'Camera Setup');
            uiwait(ghdl);
        otherwise
            drawnow;
    end
catch
    ghdl = errordlg(lasterr,'Camera Setup Failure');
    uiwait(ghdl);
end

% if there was a successful connection close it
if exist('hgs','var')
    close(hgs);
end

end
    
%--------------------------------------------------------------------------
% internal function to add log entry
%--------------------------------------------------------------------------
function addLogEntry
% refresh screen to make it feel more responsive
drawnow
try
    % try to connect to the robot
    hgs = hgs_robot;
    
    logEntry = ...
        inputdlg('                      Log entry to record in RIO log file                          .',...
        'Custom Log Entry',1);
    log_message(hgs,logEntry);
catch
    ghdl = errordlg(lasterr,'Log Entry failure');
    uiwait(ghdl);
end

% if there was a successful connection close it
if exist('hgs','var')
    close(hgs);
end

end

%--------------------------------------------------------------------------
% internal function to enable cutter
%--------------------------------------------------------------------------
function enableCutter

% refresh screen to make it feel more responsive
drawnow
try
    % try to connect to the robot
    hgs = hgs_robot;
    
catch
    ghdl = errordlg(lasterr,'Enable Cutter Failure');
    uiwait(ghdl);
    return
end

if ~homingDone(hgs)
    errordlg('Can Not Enable Cutter. Homing Not Done.','Error','modal');
    return;
end

burrResetWait = waitbar(0,'Resetting cutter and initiating irrigation');
comm(hgs,'burr','POWER_OFF');
for i=1:3
    pause(.3);
    waitbar(.05*i,burrResetWait);
end
comm(hgs,'burr','DISABLE');
for i=3:10
    pause(.5);
    waitbar(.05*i,burrResetWait);
end

% set gravity
comm(hgs,'set_gravity_constants','KNEE');

delete(burrResetWait);

%Create a timer object to avoid watchdog error
timerObj=timer('Period',0.5,'TimerFcn',@watchdogKeepAliveFcn,...
    'ExecutionMode','fixedRate');
start(timerObj);

%create ans start a haptic cube
create_haptic_cube();

% Ready the watchdog
comm(hgs,'watchdog','ON');

% enable MICS and Anspach
comm(hgs,'burr','ENABLE');

questdlg('CUTTER ENABLED. Press Cancel to disable and close.',...
    'CUTTER ENABLED',...
    'Cancel','Cancel');

%Disable cutter
reset(hgs); % clear haptic data
pause(.2)
comm(hgs,'burr','DISABLE');
comm(hgs,'watchdog','OFF');

%clear timer
stop_clear_timer(timerObj);
close_enableCutter();

    %   Internal function to close enable cutter script
    function close_enableCutter()
        mode(hgs,'zerogravity','ia_hold_enable',1);
        % if there was a successful connection close it
        if exist('hgs','var')
            close(hgs);
            pause(.5)
        end
    end

    %   Internal function to keep the watchdog alive
    function watchdogKeepAliveFcn(varargin)
        % do a basic query to keep the watchdog happy
        try
            comm(hgs,'ping_control_exec');
        catch %#ok<CTCH>
            %do nothing
        end
    end

%   Internal function to stop and clear timer
    function stop_clear_timer(timerObj)
        %stop and delete the time object
        if(isvalid(timerObj))
            %stop the timer object
            stop(timerObj);
            %delete the timer object from memory
            delete(timerObj);
            %clear the timer object from workspace
            clear timerObj;
        end
    end

%   Internal function to create and start a haptic cube
    function create_haptic_cube()
        reset(hgs);
        %big 2D polygon
        vertices = [ -0.12 0.12 0.12 -0.12 -0.12 -0.10 -0.10 0.10 0.10 -0.10 ]*100;

        numVerts = length(vertices)/2;
        flateye = eye(4);
        objName = ['extruded_2Dpoly___',num2str(rand())];
        objwrtref = reshape(hgs.flange_tx,4,4)';
        ee_tx = [1 0 0 .117; 0 1 0 -.120; 0 0 1 0; 0 0 0 1];
        ee_tx(1:3,4) = hgs.CALIB_BALL_A';
        objwrtref = objwrtref*ee_tx;
        objwrtref = objwrtref';


        ee_tx = ee_tx';
        hgs_haptic(hgs,objName,...
            'verts',vertices,...
            'numVerts',numVerts,...
            'stiffness',10000,...
            'damping',20.0,...
            'haptic_wrt_implant',flateye(:),...
            'obj_wrt_ref',objwrtref(:),...
            'forceMax',80,...
            'torqueMax',4,...
            'constrPlaneGain',42,...
            'start_end_cap',[-0.1 0.1],...
            'constrPlaneNormal',[0.0 0.0 0.1],...
            'planarConstrEnable',0,...
            'safetyConstrEnable',0,...
            'safetyPlaneNormal',[0.0 0.0 1.0],...
            'safetyConstrDir',1,...
            'planarConstrDir',1 ...
            );


        mode(hgs,'haptic_interact',...
            'vo_and_frame_list',{objName},...
            'end_effector_tx',ee_tx(:),...
            'burr_prereq_obj_name',objName,...
            'burr_prereq_var_name','hapticMode',...
            'burr_prereq_value',1);
    end


end

    
%--------------------------------------------------------------------------
% internal function to change network settings
%--------------------------------------------------------------------------
function setup_network_gui(netType)
progressValue = 0;
progressBar = waitbar(progressValue,...
    {['Setting up network to ',netType],'Please Wait....'});
% Specially on Windows computer
networkSetupTimer = timer(...
    'ExecutionMode','fixedRate',...
    'period',0.2,'TimerFcn',@updateNetworkProgressBar);
start(networkSetupTimer)
try
    setup_network(netType);

    stop(networkSetupTimer);
    delete(networkSetupTimer);
    % setup is done finish the progressbar and close
    waitbar(1,progressBar);
    pause(0.5);
    close(progressBar);
    uiwait(msgbox(['Network Successfully setup to ',netType]));
catch
    % There was some error
    % stop the timers and display message
    stop(networkSetupTimer)
    delete(networkSetupTimer);
    close(progressBar);
    errMsg = lasterror;
    uiwait(errordlg(errMsg.message));
end

%--------------------------------------------------------------------------
% internal function to update the progress bar during certain operations
%--------------------------------------------------------------------------
    function updateNetworkProgressBar(varargin)
        progressValue = progressValue+0.2/25;
        waitbar(progressValue,progressBar);
    end

end

%--------------------------------------------------------------------------
% internal function to automatically display the list of files supported
%--------------------------------------------------------------------------
function displayFunctionsMenu(fileList,displayTitle,defaultFolder)

displayList = {};
% Generate a list of names to display
for i=1:length(fileList)
    if length(fileList{i})==1
       % single element might mean it is a line separator
       % skip this
       displayList{i} = fileList{i}; %#ok<AGROW>
    elseif length(fileList{i})==3
        % if there are 3 elements the 3rd element is directory
        displayList{i} = fileList{i}{1}; %#ok<AGROW>
        functionList{i} = fullfile(fileList{i}{3},fileList{i}{2}); %#ok<AGROW>
    else
        % use the default folder
        displayList{i} = fileList{i}{1}; %#ok<AGROW>
        functionList{i} = fullfile(defaultFolder,fileList{i}{2}); %#ok<AGROW>
    end
end

% Add a QUIT button
displayList{end+1} = '----------- CLOSE ----------';

% Generate a menu for the user to click
while true
    selChoice = customMenu(displayTitle,displayTitle,'',displayList);
    if selChoice==0 || selChoice==length(displayList)
        break;
    end
    % Execute the selected script
    executeScript(functionList{selChoice});
end

end

%--------------------------------------------------------------------------
% internal function to execute the desired script
%--------------------------------------------------------------------------

function executeScript(execFileName)

% Add extension if this is on a PC
if ispc
    execFileNameWithExt = [execFileName,'.exe'];
else
    execFileNameWithExt = execFileName;
end

[execResult,resultMessage] = system(execFileNameWithExt);

if execResult
    uiwait(errordlg(resultMessage));
end

end

%--------------------------------------------------------------------------
% internal function to customize matlabs default menu function
%--------------------------------------------------------------------------

function [itemNumber,stringValue] = customMenu(figTitle,menuTitle,subTitle,stringList)

screenSize = get(0,'MonitorPositions');

% Setup
topMargin = 5;
bottomMargin = 10;
itemSpacing = 5;
buttonHeight = 25; %per button
lineSeparatorHeight = 3;

% default to the first screen size
screenSize = screenSize(1,:);

% determine the required height
menuTitleHeight = 25;

if isempty(subTitle)
    subTitleHeight = 0;
else
    if iscell(subTitle)
        subTitleHeight = 15*length(subTitle);
    else
        subTitleHeight = 15;
    end
end

% number of lineSeparators
numLineSeparators = length(find(strcmp(stringList,'------')));
numOfButtons = length(stringList)-numLineSeparators;

% now process the buttons
stringListHeight = buttonHeight*numOfButtons;

% Compute the total required Height

totalRequiredHeight = menuTitleHeight+subTitleHeight...
    +topMargin+bottomMargin...
    +stringListHeight + numOfButtons*itemSpacing...
    +numLineSeparators*(lineSeparatorHeight+itemSpacing);


% make the dialog box exactly in the middle of the screenSize
dialogSize = [(screenSize(3)-screenSize(1))/2-150 ...
    (screenSize(4)-totalRequiredHeight)/2 300 totalRequiredHeight];

% create a new figure
figHandle = dialog;
set(figHandle,...
    'Position',dialogSize,...
    'Color',[0.7 0.7 0.7],...
    'Name',figTitle);

% start making the buttons

% make title text
titleYLocation = totalRequiredHeight-topMargin-menuTitleHeight;
uicontrol(figHandle,...
    'Style','text',...
    'Position',[20 titleYLocation 260 menuTitleHeight],...
    'Background','white',...
    'fontsize',16,...
    'Background',[0.7 0.7 0.7],...
    'String',menuTitle);

if ~isempty(subTitle)
    subTitleYLocation = titleYLocation-subTitleHeight;
    uicontrol(figHandle,...
        'Style','text',...
        'Position',[20 subTitleYLocation 260 subTitleHeight],...
        'Background','white',...
        'fontsize',8,...
        'Background',[0.7 0.7 0.7],...
        'String',subTitle);
else
    subTitleYLocation = titleYLocation;
end

% Now starting making all the buttons
numButtonsRendered = 0;
numLinesRendered = 0;
for i=1:length(stringList)
    if strcmp(stringList{i},'------')
        numLinesRendered = numLinesRendered+1;
        buttonYLocation = subTitleYLocation ...
            -(itemSpacing+buttonHeight)*numButtonsRendered...
            -(itemSpacing+lineSeparatorHeight)*numLinesRendered;
        uicontrol(figHandle,...
            'BackgroundColor','black',...
            'Style','togglebutton',...
            'Value',1,...
            'Position',[5 buttonYLocation 290 lineSeparatorHeight],...
            'Enable','off');
    else
        numButtonsRendered = numButtonsRendered+1;
        buttonYLocation = subTitleYLocation ...
            -(itemSpacing+buttonHeight)*numButtonsRendered...
            -(itemSpacing+lineSeparatorHeight)*numLinesRendered;
        uicontrol(figHandle,...
            'Style','pushbutton',...
            'Position',[20 buttonYLocation 260 buttonHeight],...
            'HorizontalAlignment','left',...
            'fontsize',10,...
            'String',stringList{i},...
            'UserData',i,...
            'Callback',@buttonPressCallback);
    end
end

itemNumber = 0;
stringValue = '';
uiwait(figHandle);

%-------------------------------------------------------------------------------
% Internal function for callback
%-------------------------------------------------------------------------------
    function buttonPressCallback(objHandle,varargin)
        stringValue = get(objHandle,'String');
        itemNumber = get(objHandle,'UserData');
        closereq;
    end

end

% --------- END OF FILE ----------
