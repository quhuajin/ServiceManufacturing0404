function [] = AutoArmAccuracyCheck(hgs, varargin)
% AutoArmAccuracyCheck Gui is used to collect data for
% checking arm accuracy
%
% Syntax:
%   AutoArmAccuracyCheck(hgs)
%       This will start  the user interface for AutoArmAccuracyCheck data collection
%       for a prescribed set of joint poses (poses)
%
% Notes:
%   This script requires the hgs_robot object as input argument, i.e. a
%   connection to robot must be established before running this script.
%   The script can be run in dev mode to select one of the 5 initial sets
%   randomly used during development
%
% See also:
%   hgs_robot, home_hgs, phase_hgs
%
% $Author: rkhurana$
% Copyright: MAKO Surgical corp (2008)
%
%
% Checks for arguments if any.  If none connect to the default robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% load all the poses
AllPoseData = load('FinalArmAccuracyPoses.mat');
indexVal = 1;
for x=1:length(varargin)
    if strcmpi(varargin{x},'dev')
        AllPoseData = load('FinalArmAccuracyPosesDev.mat');
        % get Random Index Value based on Current Time if script in dev
        % mode. This is to run the script with one of the 5 different sets
        % used during development
        x=clock;
        e=x(6)*1e3;
        rand('seed',(e));
        indexVal = randi(size(AllPoseData.Poses_Left.A,3),1);
        break;
    end
end
% indexVal
% for now arbitarily pick right configuration.  This will update
% once configuration is determined.
ScriptCancelled = 1;
ErasePoseFlag = false;
AllPoses = AllPoseData.Poses_Right;
poses = AllPoses.A(:,:,indexVal);
dataLength = 0;
totalDataLength = 0;
terminate_loops = false;
sideConfig = 'RIGHTY'; % default sideConfig

%% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end

% Sets start position based on location of arm

ballLocation = int32(1);
radialErr = {[],[],[]};
ballLabel = {'A','B','C'};

startCollection = 0;
ReadyToCollect=0;
angleUpdateTimer = [];
%ballbar data structure  initializations:
ArmAccuracyData.dof = hgs.JE_DOF;
ArmAccuracyData.FlangeTransform = reshape(hgs.NOMINAL_FLANGE_TRANSFORM, 4, 4)';
ArmAccuracyData.DH_Matrix = reshape(hgs.NOMINAL_DH_MATRIX,4, ArmAccuracyData.dof)';
ArmAccuracyData.lbb = 0;
ArmAccuracyData.basePos = [];
ArmAccuracyData.baseBall = [];
ArmAccuracyData.data(1).location = [hgs.CALIB_BALL_A]';
ArmAccuracyData.data(2).location = [hgs.CALIB_BALL_B]';
ArmAccuracyData.data(3).location = [hgs.CALIB_BALL_C]';
ArmAccuracyData.data(1).je_angles = [];
ArmAccuracyData.data(2).je_angles = [];
ArmAccuracyData.data(3).je_angles = [];
ArmAccuracyData.indexVal = indexVal;

%% Setup Script Identifiers for generic GUI
scriptName = 'Automated Arm Accuracy Check';

% Create generic Mako GUI
guiHandles = generateMakoGui(scriptName,[],hgs, 1);

% use own callback for cancel button
changeCancelBtnCallBck;

set(guiHandles.figure,...
    'CloseRequestFcn',@closeCallBackFcn);

% Setup the main function
updateMainButtonInfo(guiHandles,'pushbutton',@startScript);

% Add axis for EE image
guiHandles.axis = axes('parent', guiHandles.extraPanel, ...
    'XGrid','off','YGrid','off','box','off','visible','off');

defaultColor = get( guiHandles.uiPanel, 'BackgroundColor');

% load sounds for use later
tinyBeep = wavread(fullfile('Sounds','tinybeep.wav'));
OffTheBarBlip = wavread(fullfile('Sounds','blip3.wav'));

% Add initial UI components.
commonProperties = struct(...
    'Style','text',...
    'HorizontalAlignment', 'left', ...
    'Units','Normalized',...
    'BackgroundColor',defaultColor,...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'SelectionHighlight','off',...
    'Visible','off'...
    );
guiHandles.CALEESerialNumberLabel = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Position',[0.1, 0.75 0.8 0.05],...
    'String','Calibration EE Serial Number');
guiHandles.CALEESerialNumberText = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'BackgroundColor','white',...
    'Position',[0.1, 0.65 0.8 0.1],...
    'String',hgs.CALEE_SERIAL_NUMBER);
guiHandles.CALBARSerialNumberLabel = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Position',[0.1, 0.4 0.8 0.05],...
    'String','Calibration Bar Serial Number');
guiHandles.CALBARSerialNumberText = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'BackgroundColor','white',...
    'Position',[0.1, 0.3 0.8 0.1],...
    'String',hgs.CALBAR_SERIAL_NUMBER);

guiHandles.EE_Ball =   uicontrol(guiHandles.extraPanel,...
    commonProperties,...
    'BackgroundColor', 'white',...
    'FontSize',0.7,...
    'Position',[0.1 0.15 0.8 0.1],...
    'String', 'Calib EE Ball: A');
str = sprintf('Robot Configuration: %s','---');
guiHandles.baseB_Location  =   uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'FontSize',0.8,...
    'Position',[0.05 0.9 0.9 0.05],...
    'String', str);

str = sprintf('Ball-bar length [mm]: %s',...
    sprintf('  %3.3f',  hgs.BALLBAR_LENGTH_1*1000));

guiHandles.bbar_Length  =   uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'FontSize',0.8,...
    'Position',[0.05 0.85, 0.9 0.05],...
    'String', str);

guiHandles.radial_err_S = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'FontSize',0.8,...
    'Position',[0.05 0.6 0.6 0.1],...
    'BackgroundColor', defaultColor,...
    'String', sprintf('Radial error [mm]:'));

guiHandles.radial_err_D = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'HorizontalAlignment', 'Right', ...
    'FontSize',0.8,...
    'Position',[0.65 0.6 0.3 0.1],...
    'String', sprintf('%6.3f', 0),...
    'visible', 'off');

guiHandles.nextBallBtn = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'SelectionHighlight','off',...
    'Position',[0.0, 0.12, 0.32 0.1],...
    'BackgroundColor',defaultColor,...
    'String', 'Next Calib EE Ball', ...
    'Callback',@nextBall,...
    'Enable','off',...
    'visible', 'off');


guiHandles.eraseBtn = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'SelectionHighlight','off',...
    'Position',[0.02, 0.12, 0.32 0.1],...
    'BackgroundColor',defaultColor,...
    'Callback',@erasePose,...
    'String', 'Erase Pose', ...
    'Enable','off',...
    'visible', 'off');

guiHandles.eraseAllBtn = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'HorizontalAlignment', 'Left', ...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'SelectionHighlight','off',...
    'Position',[0.0, 0.0, 0.45 0.1],...
    'BackgroundColor',defaultColor,...
    'Callback',@eraseAll,...
    'String', 'Clear All Poses', ...
    'Enable','off',...
    'visible', 'off');

guiHandles.writeToFileBtn = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','Normalized',...
    'HorizontalAlignment', 'Right', ...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'SelectionHighlight','off',...
    'Position',[0.55, 0.0, 0.45 0.1],...
    'BackgroundColor',defaultColor,...
    'Callback',@writeToFile,...
    'String', 'Write output file', ...
    'Enable','off',...
    'visible', 'off');

guiHandles.CareMsg =   uicontrol(guiHandles.extraPanel,...
    commonProperties,...
    'BackgroundColor', 'green',...
    'FontSize',0.8,...
    'Position',[0.1 0.85 0.8 0.04],...
    'String', 'Carefully Place Ball A on Bar',...
    'visible', 'off');

%create local copy of base ball postion
base_ball_right_calib = hgs.NOMINAL_BASEBALL_RIGHT_CALIB';
base_ball_left_calib = hgs.NOMINAL_BASEBALL_LEFT_CALIB';
ArmAccuracyData.basePos = base_ball_left_calib;

%------------------------------------------------------------------------------
% Callback function to start the script
%------------------------------------------------------------------------------
    function startScript(varargin)
        try
            log_message(hgs,'Automated Arm Accuracy Check Started');

            if ~homingDone(hgs)
                presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
                log_results(hgs,guiHandles.scriptName,'ERROR','Automated Arm Accuracy Check failed (Homing not done)');
                return;
            end
            %E-Stop release function
            robotFrontPanelEnable(hgs,guiHandles);
            comm(hgs,'set_gravity_constants','KNEE');
            mode(hgs,'zerogravity','ia_hold_enable',1);
            % Ask user to confirm the serial number, and if so continue to data
            % collection
            updateMainButtonInfo(guiHandles,'pushbutton',...
                'Click to confirm SNs below and Move to Start Position',...
                @start_pos);
            
            % Show the serial number
            set(guiHandles.CALEESerialNumberText,'Visible','on');
            set(guiHandles.CALEESerialNumberLabel,'Visible','on');
            set(guiHandles.CALBARSerialNumberText,'Visible','on');
            set(guiHandles.CALBARSerialNumberLabel,'Visible','on');
        catch
            % Do Nothing
        end
        try
            while (totalDataLength == 0 && ScriptCancelled)
                if(hgs.joint_angles(3) > 0)
                    DispImg('RobotBarSetupInitLefty1.JPG',guiHandles);
                    pause(0.2);
                    DispImg('RobotBarSetupInitLefty.JPG',guiHandles);
                    pause(0.3)
                else
                    DispImg('RobotBarSetupInitRighty1.JPG',guiHandles);
                    pause(0.2);
                    DispImg('RobotBarSetupInitRighty.JPG',guiHandles);
                    pause(0.3)
                end
            end
        catch
              % check if this was a cancel press
                if terminate_loops
                    return;
                else
                    presentMakoResults(guiHandles,'FAILURE', lasterr); %#ok<*LERR>
                    log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' lasterr,')']);
                    return;
                end
        end
    end
%------------------------------------------------------------------------------
% Callback function to collect data
%------------------------------------------------------------------------------

    function collectData(varargin)
        try
            showCallEE();
            set(guiHandles.CareMsg,'BackgroundColor','green');
            flag = 0;
            while (flag == 0 && ScriptCancelled)

                if  ReadyToCollect
                    [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
                    currentRadialErr = computeRadialErr(flange_tx);
                    if(abs(currentRadialErr)*1e3 <1.0 && dataLength > 5)||(dataLength <=5)
                        sound(tinyBeep);
                        ArmAccuracyData.data(ballLocation).je_angles = ...
                            [ArmAccuracyData.data(ballLocation).je_angles; ...
                            joint_angles];
                        radialErr{ballLocation}  = [ radialErr{ballLocation}; ...
                            currentRadialErr]; %#ok<*NASGU>
                    else
                        %                     mode(hgs,'zerogravity');
                    end
                else
                    ReadyToCollect = 1;
                end
                
                % Check if all poses have been collected
                lp=length(poses);
                if all([size(ArmAccuracyData.data(1).je_angles,1)>=lp,...
                        size(ArmAccuracyData.data(2).je_angles,1)>=0,...
                        size(ArmAccuracyData.data(3).je_angles,1)>=0])
                    updateMainButtonInfo(guiHandles,'text',...
                        'Data Collection Complete');
                    %                 for i=1:3
                    %                     sound(tinyBeep);
                    %                 end
                    flag = 1;
                    updateMainButtonInfo(guiHandles,...
                        'text',@writeToFile,'Data Collection Complete ... Saving Data');
                    set(guiHandles.eraseBtn,'Enable', 'off');
                    writeToFile();
                    
                    return
                end
                
                %Check Data length and next pose
                dataLength = size(ArmAccuracyData.data(ballLocation).je_angles,1);
                totalDataLength = (ballLocation-1)*length(poses)+dataLength;
                pose=dataLength+1;
                if dataLength>=length(poses);
                    ReadyToCollect = 0;
                    nextBall(varargin)
                    return
                end
                
                if ~ScriptCancelled
                    break;
                end
                % Move to Next pose
                updateMainButtonInfo(guiHandles,'Text',...
                    sprintf('Moving to Next Pose %d of %d for Ball %c\n\n(Total Progress = %2.1f %%)',...
                    pose,length(poses),ballLabel{ballLocation},double(totalDataLength)*100/(length(poses)*1)));

                target=poses(pose,:);
                try
                    
                    if ~ScriptCancelled
                        break;
                    end
                    mode(hgs,'go_to_position','target_position',target,...
                        'torque_saturation',[10 30 0 5 3 3],'max_velocity',0.35);
                    trajectory_complete = false;
                    counter = 0;
                    while (~trajectory_complete && ScriptCancelled)

                        [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
                        currentRadialErr = computeRadialErr(flange_tx);
                        if(abs(currentRadialErr)*1e3 >1.0 && dataLength > 5)
                            %                         mode(hgs,'zerogravity');
                            updateMainButtonInfo(guiHandles,'text',...
                                'Place Calibration EE Ball A Back on Bar');
                            set(guiHandles.mainButtonInfo,'BackgroundColor','r');
                            for i=1:2
                                sound(OffTheBarBlip);
                            end
                            while (counter <= 10 && ScriptCancelled)

                                [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
                                currentRadialErr = computeRadialErr(flange_tx);
                                if (abs(currentRadialErr)*1e3 <1.0)
                                    counter = counter + 1;
                                else
                                    counter = 0;
                                end
                                pause(0.1);
                                if ErasePoseFlag
                                    ErasePoseFlag = false;
                                    break;
                                end
                            end
                        end
                        % get data from module
                        trajectory_complete = hgs.go_to_position.traj_status;
                        %                     pause(0.1);
                    end
                catch
                    % check if this was a cancel press
                    if terminate_loops
                        return;
                    else
                        presentMakoResults(guiHandles,'FAILURE', ...
                           {sprintf('Configuration: %s', sideConfig) lasterr}); %#ok<*LERR>
                        log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' lasterr,')']);
                        return;
                    end
                end
                
                
                % give some time for user to settle
                %             sound(tinyBeep);
                % Create a pause of 0.3 seconds in total including time
                % needed to calculate base ball position
                tic;
                if(dataLength >= 5)
                    set(guiHandles.CareMsg,'Visible','off');
                    set(guiHandles.extraPanel,'BackgroundColor','white');
                    j3 = [];
                    %stack all joint 3 data to find lefty/righty
                    for i=1: size(ArmAccuracyData.data,2),
                        % make sure for the current Calib EE Ball there is data available
                        if ~isempty(ArmAccuracyData.data(i).je_angles)
                            j3 = [j3;  ArmAccuracyData.data(i).je_angles(:,3)]; %#ok<AGROW>
                        end
                    end
                    numPosJ3 = length(find(j3>0));
                    numNegJ3 = length(find(j3<0));
                    
                    %if most of the data has negative j3 angle then robot is in
                    %righty configuration,  otherwise it's lefty
                    if numNegJ3 > numPosJ3
                        ArmAccuracyData.baseBall = 'BASEBALL_RIGHT_CHECK';
                        if(dataLength <= 5)
                            ArmAccuracyData.basePos = hgs.NOMINAL_BASEBALL_RIGHT_CALIB';
                        else
                            ArmAccuracyData.basePos = hgs.BASEBALL_RIGHT_CHECK';
                        end
                        robotPose = 'righty';
                    else
                        ArmAccuracyData.baseBall = 'BASEBALL_LEFT_CHECK';
                        if(dataLength <= 5)
                            ArmAccuracyData.basePos = hgs.NOMINAL_BASEBALL_LEFT_CALIB';
                        else
                            ArmAccuracyData.basePos = hgs.BASEBALL_LEFT_CHECK';
                        end
                        robotPose = 'lefty';
                    end
                    
                    basepos = MidBaseBallLocation(ArmAccuracyData);
                    if (strcmp(robotPose,'righty'))
                        hgs.BASEBALL_RIGHT_CHECK = basepos;
                    else
                        hgs.BASEBALL_LEFT_CHECK = basepos;
                    end
                    ArmAccuracyData.basePos = basepos;
                else
                    set(guiHandles.CareMsg,'Visible','on');
                end
                
                if ~ScriptCancelled
                    return;
                end
                % Update GUI to Collect pose
                updateMainButtonInfo(guiHandles,'text',sprintf('Collecting Pose %d of %d for Ball %c', ...
                    pose,length(poses),ballLabel{ballLocation}));
                
                if (dataLength >0)
                    set(guiHandles.eraseBtn,'Enable', 'on');
                end
                timeElapsed = toc;
                if timeElapsed < 0.3
                    pause(0.3 - timeElapsed);
                end
            end
        catch
            % check if this was a cancel press
            if terminate_loops
                return;
            else
                presentMakoResults(guiHandles,'FAILURE', ...
                    {sprintf('Configuration: %s', sideConfig) lasterr}); %#ok<*LERR>
                log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' lasterr,')']);
                return;
            end
        end
    end

%------------------------------------------------------------------------------
% Callback function to erase last recorded pose.
%------------------------------------------------------------------------------
    function  erasePose(varargin)
        ErasePoseFlag =true;
        dataLength = size(ArmAccuracyData.data(ballLocation).je_angles,1);
        %if there are data available clear the last data;
        if dataLength > 0
            ArmAccuracyData.data(ballLocation).je_angles(dataLength,:) = [];
            radialErr{ballLocation}(end) = [];
            dataLength = dataLength -1;
            totalDataLength = totalDataLength-1;
            updateMainButtonInfo(guiHandles,'text',sprintf('Erased point %d... Resuming Data Collection', ...
                dataLength+1));
            ReadyToCollect = 0;
            %             mode(hgs,'zerogravity');
        end        
    end

%------------------------------------------------------------------------------
% Callback function to write collected data to file
%------------------------------------------------------------------------------
    function  writeToFile(varargin)
        
        
        % stop and delete gui update timer function,
        %since data collection is done
        if ~isempty(angleUpdateTimer)
            stop(angleUpdateTimer);
            delete(angleUpdateTimer);
            angleUpdateTimer = '';
        end;
        
        % Data collection is complete stop timers
        delete(get(guiHandles.uiPanel,'Children'));
        delete(guiHandles.EE_Ball);
        
%         set(guiHandles.axis,'visible','off');
        
        % check if there is a specific directory specified for all the reports
        % this is specified by MAKO_REPORTS_DIR environment variable
        % if not specified on windows use the desktop directory and on linux use
        % the tmp directory
        %Determine if the collected data is for lefty or righty configuration
        j3 = [];
        %stack all joint 3 data to find lefty/righty
        for i=1: size(ArmAccuracyData.data,2),
            % make sure for the current Calib EE Ball there is data available
            if ~isempty(ArmAccuracyData.data(i).je_angles)
                j3 = [j3;  ArmAccuracyData.data(i).je_angles(:,3)]; %#ok<AGROW>
            end
        end
        numPosJ3 = length(find(j3>0));
        numNegJ3 = length(find(j3<0));
        
        %if most of the data has negative j3 angle then robot is in
        %righty configuration,  otherwise it's lefty
        if numNegJ3 > numPosJ3
            ArmAccuracyData.baseBall = 'BASEBALL_RIGHT_CALIB';
            ArmAccuracyData.basePos = hgs.NOMINAL_BASEBALL_RIGHT_CALIB';
            robotPose = 'righty';
        else
            ArmAccuracyData.baseBall = 'BASEBALL_LEFT_CALIB';
            ArmAccuracyData.basePos = hgs.NOMINAL_BASEBALL_LEFT_CALIB';
            robotPose = 'lefty';
        end
        unitName = hgs.name;
        
        fileName = sprintf('%s-%s-%s-%s.mat',...
            'AutoArmAccuracyData', robotPose, unitName, ...
            datestr(now,'yyyy-mm-dd-HH-MM-SS'));
        fullFileName = fullfile(guiHandles.reportsDir, fileName);
        try
            save(fullFileName, 'ArmAccuracyData');

            updateMainButtonInfo(guiHandles,'text',sprintf('File Saved to\n%s',...
                fullFileName));
            pause(1);

            % save was successful autmatically run the mainArmAccFunction
            % update the guiHandles to be backwards compatible with 
            % mainArmAccFunction function
            
            guiHandles.filename = fullFileName;
            guiHandles.tgs = hgs;
            
            updateMainButtonInfo(guiHandles,'text',sprintf('Processing Data '));
            mainArmAccFunction(guiHandles,hgs,sideConfig);
        catch 
            resultStr{1} = sprintf('Save was not successful');
            resultStr{2} = lasterr; %#ok<LERR>
            presentMakoResults(guiHandles,'FAILURE', ...
                [sprintf('Configuration: %s', sideConfig) resultStr]);
            log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' resultStr,')']);
        end
        
        mode(hgs,'zerogravity','ia_hold_enable',1);
        
        try
            while (ScriptCancelled)
                if(hgs.joint_angles(3) > 0)
                    DispImg('RobotBarSetupInitLefty1.JPG',guiHandles);
                    pause(0.2);
                    DispImg('RobotBarSetupInitLefty2.JPG',guiHandles);
                    pause(0.3)
                else
                    DispImg('RobotBarSetupInitRighty1.JPG',guiHandles);
                    pause(0.2);
                    DispImg('RobotBarSetupInitRighty2.JPG',guiHandles);
                    pause(0.3)
                end
            end
        catch
          % Do Nothing
        end

        delete(guiHandles.axis);
        
    end
%------------------------------------------------------------------------------
% Callback function for switching to next calibration Calib EE Ball
%------------------------------------------------------------------------------
    function nextBall(varargin)
        ballLocation = ballLocation + 1;
        %if ballLocation is larger than available number of cal balls then reset.
        if ballLocation > size(ArmAccuracyData.data,2)
            ballLocation = 1;
        end
        showCallEE();
        updateMainButtonInfo(guiHandles,'text',...
            sprintf('Change to Ball %c',ballLabel{ballLocation}));
        
        for i=1:3
            set(guiHandles.extraPanel,'background','green');
            sound(tinyBeep);
            set(guiHandles.extraPanel,'background','white');
            sound(tinyBeep);
        end
        set(guiHandles.extraPanel,'background','white')
        dataLength = 0;
        updateMainButtonInfo(guiHandles,'pushbutton',...
            sprintf('Change to Ball %c   Click to continue',ballLabel{ballLocation}));
        if dataLength > 0
            set(guiHandles.eraseBtn,'Enable', 'on');
        else
            set(guiHandles.eraseBtn,'Enable', 'off');
        end
        
        % update the poses
        switch ballLocation
            case 1
                poses=AllPoses.A(:,:,indexVal);
            case 2
                poses=AllPoses.B(:,:,indexVal);
            case 3
                poses=AllPoses.C(:,:,indexVal);
        end
        radialErr{ballLocation} = [];
        return
    end
%------------------------------------------------------------------------------
% Internal function to show the image of the current calibration Calib EE Ball
%------------------------------------------------------------------------------
    function showCallEE()
        EE_BallString = {'Calib EE Ball: A',...
            'Calib EE Ball: B',...
            'Calib EE Ball: C',...
            'Calib EE Ball: D'};
            
        imageEE = {'eeBall_inv_A.png','eeBall_inv_B.png', ...
                'eeBall_inv_C.png'};

        imageFile = fullfile('robot_images',imageEE{ballLocation});
        set(guiHandles.EE_Ball, 'string', ...
            EE_BallString{ballLocation});
        eeImg = imread(imageFile);
        set(guiHandles.axis, 'NextPlot', 'replace');
        image(eeImg,'parent', guiHandles.axis);
        axis (guiHandles.axis, 'off')
        axis (guiHandles.axis, 'image')
        drawnow;
    end

%------------------------------------------------------------------------------
% Call back function to Change call back function for cancel button
%------------------------------------------------------------------------------
    function [] = changeCancelBtnCallBck()
        frames = get(guiHandles.figure,'Children');
        % Search for the report generation frame
        for i=1:length(frames)
            if (strcmp(get(frames(i),'Title'),'Report Generation'))
                % Now look for the buttons in the report frame
                repButtonList = get(frames(i),'Children');
                break;
            end
        end
        % Now search the buttons for the cancel button
        for i=1:length(repButtonList)
            if strcmp(get(repButtonList(i),'string'),'Cancel')
                set(repButtonList(i),...
                    'Callback', @closeCallBackFcn,...
                    'String','Cancel');
            end
        end
    end
%------------------------------------------------------------------------------
% Update function for timer object
%------------------------------------------------------------------------------
    function []= updateAnglesAndError(varargin)
        if  ~startCollection
            if ~strcmp(mode(hgs),'zerogravity')
                if ~strcmp(mode(hgs),'go_to_position')
                    errorMsg=char(hgs.go_to_position.mode_error);
                    if strcmp('NO_ERROR',errorMsg) || strcmp('',errorMsg)
                        errorMsg=char(hgs.zerogravity.mode_error);
                    end
                    ScriptCancelled = 0;
                    set(guiHandles.eraseBtn,'Enable', 'off');
                    presentMakoResults(guiHandles,'FAILURE', ...
                        {sprintf('Configuration: %s', sideConfig) errorMsg});
                    log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' errorMsg,')']);
                    %dataLength=dataLengthCheck;
                    stop(angleUpdateTimer);
                    delete(angleUpdateTimer);
                    return;
                end
            end
        end
        [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
        
        if totalDataLength == 0
            if joint_angles(3) < 0
                set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                    'RIGHTY']);
            else
                set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                    'LEFTY']);
            end
        end
        
        %compute radial error
       currentRadialErr = computeRadialErr(flange_tx);
        set(guiHandles.radial_err_D, 'String', ...
            sprintf('%6.3f', currentRadialErr*1000));
        
        drawnow;
    end

%------------------------------------------------------------------------------
% This Internal function computes radial error
%------------------------------------------------------------------------------
    function rdlErr = computeRadialErr(flange_tx)
        flange_tx = reshape(flange_tx,4,4)';
        ballPos_wrt_base = flange_tx(1:3, 1:3) * ...
            ArmAccuracyData.data(ballLocation).location + flange_tx(1:3,4);
        rdlErr =  norm (ballPos_wrt_base -  ArmAccuracyData.basePos) - ...
            ArmAccuracyData.lbb;
    end

%------------------------------------------------------------------------------
% Call back function to close the gui
%------------------------------------------------------------------------------
    function closeCallBackFcn(varargin)
        ScriptCancelled = 0;
        terminate_loops = true;
        log_message(hgs,'Automated Arm Accuracy Check Script Closed');
        pause(0.3);
        try
            mode(hgs,'zerogravity','ia_hold_enable',1);
            if  ~isempty(angleUpdateTimer)
                stop(angleUpdateTimer);
                delete(angleUpdateTimer);
            end
        catch %#ok<*CTCH>
        end
        
        closereq;
    end
%------------------------------------------------------------------------------
% Call back function for Ball Transition
%------------------------------------------------------------------------------
    function start_pos(varargin)

        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Place bar on ball(pick initial pose)',@collectData);
        ReadyToCollect=0;
        if  ~startCollection
            hndls = [...
                guiHandles.CALEESerialNumberLabel,...
                guiHandles.CALEESerialNumberText,...
                guiHandles.CALBARSerialNumberLabel,...
                guiHandles.CALBARSerialNumberText];
            set(hndls, 'Enable','off', 'visible','off');
            
            hndls = [guiHandles.EE_Ball, guiHandles.baseB_Location , ...
                guiHandles.bbar_Length,  guiHandles.radial_err_S, ...
                guiHandles.radial_err_D, ...
                guiHandles.eraseBtn];
            
            
            set(hndls, 'visible','on', 'Enable', 'on');
            set(guiHandles.extraPanel,'BackgroundColor','white');
            
            ArmAccuracyData.lbb = hgs.BALLBAR_LENGTH_1;
            
            str = sprintf('Ball-bar length [mm]: %s',...
                sprintf('  %3.3f', ...
                ArmAccuracyData.lbb*1000));
            set(guiHandles.bbar_Length,'string',str);
            
            %             showCallEE();
            %create a timer object to shown joint angles
            angleUpdateTimer = timer(...
                'TimerFcn',@updateAnglesAndError,...
                'Period',0.2,...
                'ObjectVisibility','off',...
                'BusyMode','drop',...
                'ExecutionMode','fixedSpacing'...
                );
            %start timer
            start(angleUpdateTimer)
            try
                dataLength = 0;
                set(guiHandles.eraseBtn,'Enable', 'off');
                set(guiHandles.eraseAllBtn,'Enable', 'off');
                set(guiHandles.CareMsg,'Visible','on');
                Flag = [];
                while size(ArmAccuracyData.data(1).je_angles,1) < 1 && ScriptCancelled
                    %update info about robot's lefty/righty configuration
                    %based on J3 joint angle
                    if totalDataLength == 0
                        radialErr{ballLocation} = [];
                        PrevFlag = Flag;
                        if hgs.joint_angles(3) < 0
                            set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                                'RIGHTY']);
                            sideConfig = 'RIGHTY';
                            
                            ArmAccuracyData.basePos = base_ball_right_calib;
                            ArmAccuracyData.FlangeTransform = reshape(hgs.CALIBRATED_FLANGE_RIGHTY, 4, 4)';
                            ArmAccuracyData.DH_Matrix = reshape(hgs.CALIBRATED_DH_RIGHTY,4, ArmAccuracyData.dof)';
                            
                            AllPoses = AllPoseData.Poses_Right;
                            poses=AllPoses.A(:,:,indexVal);
                            drawnow;
                            Flag = 1;
                        else
                            set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                                'LEFTY']);
                            sideConfig = 'LEFTY';
                            
                            ArmAccuracyData.basePos = base_ball_left_calib;
                            AllPoses = AllPoseData.Poses_Left;
                            ArmAccuracyData.FlangeTransform = reshape(hgs.CALIBRATED_FLANGE_LEFTY, 4, 4)';
                            ArmAccuracyData.DH_Matrix = reshape(hgs.CALIBRATED_DH_LEFTY,4, ArmAccuracyData.dof)';
                            
                            poses=AllPoses.A(:,:,indexVal);
                            drawnow;
                            Flag = 0;
                        end
                        if PrevFlag == Flag
                            % Do Nothing
                        else
                            % Change Image Display based on Robot Config
                            if Flag == 1
                                imageFile = fullfile('robot_images','RobotCalRight.JPG');
                                eeImg = imread(imageFile);
                                set(guiHandles.axis, 'NextPlot', 'replace');
                                image(eeImg,'parent', guiHandles.axis,'visible','off');
                                image(eeImg,'parent', guiHandles.axis,'visible','on');
                                axis (guiHandles.axis, 'off')
                                axis (guiHandles.axis, 'image')
                            else
                                imageFile = fullfile('robot_images','RobotCalLeft.JPG');
                                eeImg = imread(imageFile);
                                set(guiHandles.axis, 'NextPlot', 'replace');
                                image(eeImg,'parent', guiHandles.axis,'visible','off');
                                image(eeImg,'parent', guiHandles.axis,'visible','on');
                                axis (guiHandles.axis, 'off')
                                axis (guiHandles.axis, 'image')
                            end
                        end
                    end
                    set(guiHandles.CareMsg,'BackgroundColor','white');
                    pause(0.2);
                    set(guiHandles.CareMsg,'BackgroundColor','green');
                    pause(0.2);
                end
            catch
                % check if this was a cancel press
                if terminate_loops
                    return;
                else
                    presentMakoResults(guiHandles,'FAILURE', ...
                        {sprintf('Configuration: %s', sideConfig) lasterr}); %#ok<*LERR>
                    log_results(hgs,guiHandles.scriptName,'ERROR',['Automated Arm Accuracy Check failed ( ' lasterr,')']);
                    return;
                end
            end
        end
    end
end
%------------------------------------------------------------------------------
% Internal function to show an image
%------------------------------------------------------------------------------
    function DispImg(name,guiHandles)
        imageFile = fullfile('robot_images',name);
        eeImg = imread(imageFile);
        set(guiHandles.axis, 'NextPlot', 'replace');
        image(eeImg,'parent', guiHandles.axis);
        axis (guiHandles.axis, 'off')
        axis (guiHandles.axis, 'image')
        drawnow;
    end
% --------- END OF FILE ----------
