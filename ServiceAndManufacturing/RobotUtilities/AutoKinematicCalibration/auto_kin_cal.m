function [] = auto_kin_cal(hgs)
% AUTO_KIN_CAL Gui is used to collect ball-bar data for
% kinematic calibaration
%
% Syntax:
%   bbar_collect_data(hgs,poses)
%       This will start  the user interface for ball-bar data collection
%       for a prescribed set of joint poses (poses)
%
% Notes:
%   This script requires the hgs_robot object as input argument, i.e. a
%   connection to robot must be established before running this script.
%
% See also:
%   hgs_robot, home_hgs, phase_hgs
%
%
% $Author: jscrivens $
% $Revision: 2203 $
% $Date: 2013-05-24 15:13:08 -0400 (Mon, 24 May 2010) $
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

AllPoseData = load('auto_bbar_poses.mat');

% for now arbitarily pick right configuration.  This will update
% once configuration is determined.
AllPoses = AllPoseData.Poses_right;
poses = AllPoses.A;
dataLength = 0;
totalDataLength = 0;
terminate_loops = false;

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
bbarData.dof = hgs.JE_DOF;
bbarData.nominalFlangeTransform = reshape(hgs.NOMINAL_FLANGE_TRANSFORM, 4, 4)';
bbarData.nominalDH_Matrix = reshape(hgs.NOMINAL_DH_MATRIX,4, bbarData.dof)';
bbarData.lbb = 0;
bbarData.basePos = [];
bbarData.baseBall = [];
bbarData.data(1).location = [hgs.CALIB_BALL_A]';
bbarData.data(2).location = [hgs.CALIB_BALL_B]';
bbarData.data(3).location = [hgs.CALIB_BALL_C]';
bbarData.data(1).je_angles = [];
bbarData.data(2).je_angles = [];
bbarData.data(3).je_angles = [];


%% Setup Script Identifiers for generic GUI
scriptName = 'Kinematic Calibration';

% Create generic Mako GUI
guiHandles = generateMakoGui(scriptName,[],hgs, 1);
log_message(hgs,'Auto Kinematic Calibration Script Sarted');
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
    'Position',[0.1 0.85 0.8 0.1],...
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

%create local copy of base ball postion
base_ball_right_calib = hgs.BASEBALL_RIGHT_CALIB';
base_ball_left_calib = hgs.BASEBALL_LEFT_CALIB';
bbarData.basePos = base_ball_left_calib;

%------------------------------------------------------------------------------
% Callback function to start the script
%------------------------------------------------------------------------------
    function startScript(varargin)
        %E-Stop release function
        robotFrontPanelEnable(hgs,guiHandles);
        %set gravity constants to Knee EE
        comm(hgs,'set_gravity_constants','KNEE');
       
        pause(.1)
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
        
        
    end
%------------------------------------------------------------------------------
% Callback function to collect data
%------------------------------------------------------------------------------

    function collectData(varargin)

        % if this is the first pose determine lefty or righty
        
        
        %update info about robot's lefty/righty configuration
        %based on J3 joint angle
        
        if totalDataLength == 0
            radialErr{ballLocation} = [];
            
            if hgs.joint_angles(3) < 0
                set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                    'RIGHTY']);
                
                bbarData.basePos = base_ball_right_calib;
                
                AllPoses = AllPoseData.Poses_right;
                poses=AllPoses.A;
            else
                set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                    'LEFTY']);
                
                bbarData.basePos = base_ball_left_calib;
                AllPoses = AllPoseData.Poses_left;
                poses=AllPoses.A;
            end
        end
        
               
        if  ReadyToCollect
            [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
            
            bbarData.data(ballLocation).je_angles = ...
                [bbarData.data(ballLocation).je_angles; ...
                joint_angles];
            %compute radial error
            currentRadialErr = computeRadialErr(flange_tx);
            radialErr{ballLocation}  = [ radialErr{ballLocation}; ...
                currentRadialErr]; %#ok<*NASGU>
        else
            ReadyToCollect = 1;
        end
        
        % Check if all poses have been collected
        lp=length(poses);
        if all([size(bbarData.data(1).je_angles,1)>=lp,...
                size(bbarData.data(2).je_angles,1)>=lp,...
                size(bbarData.data(3).je_angles,1)>=lp])
            updateMainButtonInfo(guiHandles,'text',...
                'Data Collection Complete');
            for i=1:3
                sound(tinyBeep);
            end
            updateMainButtonInfo(guiHandles,...
                'PushButton',@writeToFile,'Data Collection Complete ... Click to Save Data');
            set(guiHandles.eraseBtn,'Enable', 'off');
            return
        end
        
        %Check Data length and next pose
        dataLength = size(bbarData.data(ballLocation).je_angles,1);
        totalDataLength = (ballLocation-1)*length(poses)+dataLength;
        pose=dataLength+1;
        if dataLength>=length(poses);
            ReadyToCollect = 0;
            nextBall(varargin)
            return
        end
        
        % Move to Next pose
        updateMainButtonInfo(guiHandles,'Text',...
            sprintf('Moving to Next Pose %d of %d for Ball %c\n\n(Total Progress = %2.1f %%)',...
            pose,length(poses),ballLabel{ballLocation},double(totalDataLength)*100/(length(poses)*3)));
        set(guiHandles.eraseBtn,'Enable', 'off');
        target=poses(pose,:);
        try
            mode(hgs,'go_to_position','target_position',target,...
                'torque_saturation',[10 30 0 5 3 3],'max_velocity',0.35);
            trajectory_complete = false;
            while ~trajectory_complete
                if terminate_loops
                   return;
                end
                % get data from module
                trajectory_complete = hgs.go_to_position.traj_status;
                pause(0.1);
            end
        catch
            % check if this was a cancel press
            if terminate_loops
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',lasterr); %#ok<*LERR>
                log_results(hgs,guiHandles.scriptName,'FAILURE',...
                    sprintf('Auto Kinematic Calibration Failed due to %s',lasterr));
                return;
            end
        end
        
        % give some time for user to settle
        sound(tinyBeep);

        % Update GUI to Collect pose
        updateMainButtonInfo(guiHandles,'pushButton',sprintf('Click to Collect Pose %d of %d for Ball %c', ...
            pose,length(poses),ballLabel{ballLocation}));
        
        if (dataLength >0)
            set(guiHandles.eraseBtn,'Enable', 'on');
        end
    end

%------------------------------------------------------------------------------
% Callback function to erase last recorded pose.
%------------------------------------------------------------------------------
    function  erasePose(varargin)
        dataLength = size(bbarData.data(ballLocation).je_angles,1);
        %if there are data available clear the last data;
        if dataLength > 0
            bbarData.data(ballLocation).je_angles(dataLength,:) = [];
            radialErr{ballLocation}(end) = [];
            dataLength = dataLength -1;
            totalDataLength = totalDataLength-1;
            updateMainButtonInfo(guiHandles,'pushButton',sprintf('Erased point %d... click to resume', ...
                dataLength+1));
            ReadyToCollect = 0;
        end        
    end

%------------------------------------------------------------------------------
% Callback function to write collected data to file
%------------------------------------------------------------------------------
    function  writeToFile(varargin)
        
        % Data collection is complete stop timers and hide all graphics
        delete(get(guiHandles.uiPanel,'Children'));
        delete(guiHandles.axis);
        delete(guiHandles.EE_Ball);
        
        % stop and delete gui update timer function,
        %since data collection is done
        if ~isempty(angleUpdateTimer)
            stop(angleUpdateTimer);
            delete(angleUpdateTimer);
            angleUpdateTimer = '';
        end;
        
        
        % check if there is a specific directory specified for all the reports
        % this is specified by MAKO_REPORTS_DIR environment variable
        % if not specified on windows use the desktop directory and on linux use
        % the tmp directory
        %Determine if the collected data is for lefty or righty configuration
        j3 = [];
        %stack all joint 3 data to find lefty/righty
        for i=1: size(bbarData.data,2),
            % make sure for the current Calib EE Ball there is data available
            if ~isempty(bbarData.data(i).je_angles)
                j3 = [j3;  bbarData.data(i).je_angles(:,3)]; %#ok<AGROW>
            end
        end
        numPosJ3 = length(find(j3>0));
        numNegJ3 = length(find(j3<0));
        
        %if most of the data has negative j3 angle then robot is in
        %righty configuration,  otherwise it's lefty
        if numNegJ3 > numPosJ3
            bbarData.baseBall = 'BASEBALL_RIGHT_CALIB';
            bbarData.basePos = hgs.NOMINAL_BASEBALL_RIGHT_CALIB';
            robotPose = 'righty';
        else
            bbarData.baseBall = 'BASEBALL_LEFT_CALIB';
            bbarData.basePos = hgs.NOMINAL_BASEBALL_LEFT_CALIB';
            robotPose = 'lefty';
        end
        unitName = hgs.name;
        if isempty(getenv('ROBOT_BBAR_ORIG'))
            if ispc
                baseDir = fullfile(getenv('USERPROFILE'),'Desktop');
            else
                baseDir = tempdir;
            end
            dirName  = fullfile(baseDir,...
                [unitName,'-bbar-Data']);
        else
            dirName = getenv('ROBOT_BBAR_ORIG');
        end
        if (~isdir(dirName))
            mkdir(dirName);
        end
        fileName = sprintf('%s-%s-%s-%s.mat',...
            'bbar', robotPose, unitName, ...
            datestr(now,'yyyy-mm-dd-HH-MM-SS'));
        fullFileName = fullfile(dirName, fileName);
        try
            save(fullFileName, 'bbarData');

            updateMainButtonInfo(guiHandles,'text',sprintf('File Saved to\n%s',...
                fullFileName));
            pause(1);

            % save was successful autmatically run the Kincal
            % update the guiHandles to be backwards compatible with kincal
            % function
            
            guiHandles.filename = fullFileName;
            guiHandles.tgs = hgs;
            
            updateMainButtonInfo(guiHandles,'pushbutton',sprintf('Click to Start Data processing'));
            updateMainButtonInfo(guiHandles,{@mainKincalFunction,guiHandles});
        catch 
            resultStr{1} = sprintf('Save was not successful for %s configuration', upper(robotPose));
            resultStr{2} = lasterr; %#ok<LERR>
            presentMakoResults(guiHandles,'FAILURE', resultStr);
            log_results(hgs,guiHandles.scriptName,'FAILURE',...
                sprintf('Auto Kinematic Calibration Failed since %s',lasterr));
        end
        
        mode(hgs,'zerogravity','ia_hold_enable',1);
    end
%------------------------------------------------------------------------------
% Callback function for switching to next calibration Calib EE Ball
%------------------------------------------------------------------------------
    function nextBall(varargin)
        ballLocation = ballLocation + 1;
        %if ballLocation is larger than available number of cal balls then reset.
        if ballLocation > size(bbarData.data,2)
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
                poses=AllPoses.A;
            case 2
                poses=AllPoses.B;
            case 3
                poses=AllPoses.C;
        end
        radialErr{ballLocation} = [];
        return
    end
%------------------------------------------------------------------------------
% Internal function to show the emage of the current calibration Calib EE Ball
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
            bbarData.data(ballLocation).location + flange_tx(1:3,4);
        rdlErr =  norm (ballPos_wrt_base -  bbarData.basePos) - ...
            bbarData.lbb;
    end

%------------------------------------------------------------------------------
% Call back function to close the gui
%------------------------------------------------------------------------------
    function closeCallBackFcn(varargin)
        log_message(hgs,'Auto Kinematic Calibration Script Closed');
        terminate_loops = true;
        pause(0.1);
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
            'Place bar on ball showin in picture (pick initial pose)',@collectData);
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
            
            bbarData.lbb = hgs.BALLBAR_LENGTH_1;
            
            str = sprintf('Ball-bar length [mm]: %s',...
                sprintf('  %3.3f', ...
                bbarData.lbb*1000));
            set(guiHandles.bbar_Length,'string',str);
            showCallEE();
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
            dataLength = 0;
            set(guiHandles.eraseBtn,'Enable', 'off');
            set(guiHandles.eraseAllBtn,'Enable', 'off');
        end
    end
end


% --------- END OF FILE ----------
