function guiHandles = brake_check(hgs,varargin)
%BRAKE_CHECK  Script to measure brake holding torque and brake release torque
%
% Syntax:
%   brake_check
%       run the script using default options.  User will be prompted when
%       required.  If no argument is presented the script will connect to the
%       hgs_robot specified by the environment variable TARGET_HGS_ARM
%
%   brake_check(hgs)
%       argument hgs specifies the hgs_robot to be used
%
%   brake_engage(guiHandles)
%       argument guiHandles can be used to specify a gui that was already
%       created.  This is useful for reliability scripts that repeatedly
%       run the scripts
%
% Test Description:
%   The arm will be taken to a gravity neutral position.  After that each
%   brake will be engaged and torque ramped through it.  The joint position
%   will be monitored as the torque increases.  If the brake slips
%   before the rated torque on the brake is achieved, the script will stop
%   and declare an error.
%
%   If the holding test passes the script will initiate the release test.
%   In this test a small torque is applied to the motors and the brakes are
%   kept released.  Joint motion is expected.  If joint motion is seen the
%   test is successful
%

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

% Checks for arguments if any
defaultRobotConnection = false;

if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles = '';
        return;
    end

    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
end
HassRun = false;
if nargin ==2
    if(strcmp(varargin{1},'Hass'))
        HassRun = true;
    end
end
%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

guiHandles = generateMakoGui('Brake Check',[],hgs);
updateMainButtonInfo(guiHandles,'pushbutton',@run_brake_check);
set(guiHandles.figure,'CloseRequestFcn',@abortBrakeTestProcedure);

userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

%set up display text location
commonTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'HorizontalAlignment','center');

% Setup Test parameters
% initial setup
robotDOF=hgs.WAM_DOF;
MOTOR_BRAKE = 0;
MID_BRAKE=1;
JOINT_BRAKE=2;

if robotDOF==6
    test_pos=[0, -1.15, 0, 2.85, 1.55, 0];
    BRAKE_HOLDING_TQ_LIMIT = [33.0 59.0 56.0 27.0 6.0 5.6 ]; % Nm
    BRAKE_TQ_TEST_LIMIT_RATIO = [1.1 1.1 1.05 1.1 1.1 1.1];
    BRAKE_RELEASE_TQ_LIMIT = [10.0 10.0 6.0 4.0 1.3 0.6]; % Nm
    BRAKE_RELEASE_WARNING_RATIO = 0.7;
    BRAKE_RELEASE_WARNING_RATIO_J6 = 0.85;
    BRAKE_RELEASE_RAMPUP_TIME = [5 5 5 5 5 5];
    % J2 cannot be put in gravity neutral position and the motion is
    % significant.
    HOLD_MOTION_DETECTION_THRESHOLD = [0.02 0.05 0.03 0.02 0.02 0.02] ; %rad
    RELEASE_MOTION_DETECTION_THRESHOLD = [0.02 0.035 0.05 0.02 0.02 0.055]; %rad

    BRAKE_PLACEMENT = [MOTOR_BRAKE MOTOR_BRAKE JOINT_BRAKE ...
        MID_BRAKE JOINT_BRAKE MID_BRAKE];
else
    test_pos= [0 -pi/2 0 pi/2 0]; % rad
    BRAKE_HOLDING_TQ_LIMIT = [33 33 33 12 2.2]; % Nm
    BRAKE_TQ_TEST_LIMIT_RATIO = [1.0 1.0 1.0 1.33 1.13];
    BRAKE_RELEASE_TQ_LIMIT = [15.0 8.0 6.0 4.0 1.3 0.5]; % Nm
    BRAKE_RELEASE_WARNING_RATIO = 0.7;
    HOLD_MOTION_DETECTION_THRESHOLD = [0.05 0.05 0.05 0.05 0.05 0.05] ; %rad
    RELEASE_MOTION_DETECTION_THRESHOLD = [0.05 0.05 0.05 0.05 0.05 0.05] ; %rad
    BRAKE_RELEASE_RAMPUP_TIME = [5 5 5 5 5 5];
    BRAKE_PLACEMENT = [JOINT_BRAKE JOINT_BRAKE JOINT_BRAKE ...
        JOINT_BRAKE JOINT_BRAKE ];
end

% compute the test limits
test_holding_tq_limit = BRAKE_HOLDING_TQ_LIMIT.*BRAKE_TQ_TEST_LIMIT_RATIO;

% C style "Defines"
TEST_ABORT = -2;
TEST_ERROR = -2;
TEST_FAILED = -1;
TEST_WARNING = 0;
TEST_PASSED = 1;

% setup test termination conditions
terminate_loops = false;
error_message = '';

% placeholder for release torques and results should the test terminate before that
maxReleaseTq = [];
releaseResult = [];


%--------------------------------------------------------------------------
% internal function for the top level execution of the brake test
%--------------------------------------------------------------------------
    function run_brake_check(varargin)
        log_message(hgs,'Brake Check started');
        
        %check if homing is done
        if ~homingDone(hgs)
            presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
	    log_results(hgs,'BrakeCheck','FAIL','Homing not Done');
            return;
        end

        % Generate the heading labels
        uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.02 0.85 .95 0.1],...
            'FontSize',0.5,...
            'String','Brake Holding Test');

        releaseTestTitle = uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.02 0.3 .95 0.1],...
            'FontSize',0.5,...
            'Visible','off',...
            'String','Brake Release Test');

        uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.1 0.7 0.2 0.1],...
            'HorizontalAlignment','left',...
            'String','Joint');

        uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.1 0.6 0.2 0.1],...
            'HorizontalAlignment','left',...
            'String','Positive');

        uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.1 0.5 0.2 0.1],...
            'HorizontalAlignment','left',...
            'String','Negative');

        releaseGui = uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.1 0.15 0.2 0.1],...
            'HorizontalAlignment','left',...
            'String','Release',...
            'Visible','off');

        % create the rest of the gui to show results
        for i=1:robotDOF

            jointLabel(i) = uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.2+i*0.1 0.7 0.08 0.1],...
                'FontSize',0.5,...
                'String',sprintf('J%d',i),...
                'BackgroundColor',[0.7 0.7 0.7],...
                'Visible','off'); %#ok<AGROW>

            posResGui(i) = uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.2+i*0.1 0.6 0.08 0.1],...
                'FontSize',0.5,...
                'HorizontalAlignment','right',...
                'Visible','off'); %#ok<AGROW>

            negResGui(i) = uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.2+i*0.1 0.5 0.08 0.1],...
                'FontSize',0.5,...
                'HorizontalAlignment','right',...
                'Visible','off');    %#ok<AGROW>

            releaseResGui(i) = uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.2+i*0.1 0.15 0.08 0.1],...
                'FontSize',0.5,...
                'HorizontalAlignment','right',...
                'Visible','off');    %#ok<AGROW>

        end

        % Make sure the arm is enabled
        mode(hgs,'zerogravity','ia_hold_enable',0);

        try
            robotFrontPanelEnable(hgs,guiHandles);
            % go to test position
            updateMainButtonInfo(guiHandles,...
                'text','Moving to test position');
            go_to_position(hgs,test_pos,0.3);
            % move joint 6 to settle
            pause(.1)
            go_to_position(hgs,[test_pos(1:5) -.5],0.3);
            pause(.1)
            go_to_position(hgs,[test_pos(1:5) .5],0.3);
            pause(.1)
            go_to_position(hgs,test_pos,0.3);
        catch
            % check if this was an abort, return silenty
            if terminate_loops
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',lasterr);
                log_results(hgs,'BrakeCheck','FAIL',lasterr);
		%fill in return data
                userDataStruct.results=-2;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
                return;
            end
        end

        if terminate_loops
            return;
        end

        pause(0.25);

        try
            %cycle through the joints
            for i = 1:robotDOF
                set(jointLabel(i),'Visible','on');

                % Test the positive direction
                dir = 1;
                updateMainButtonInfo(guiHandles,'text',...
                    sprintf('Testing Joint %d - Positive',i));

                % show the test block
                set(posResGui(i),'Visible','on');
                            
                [maxPositiveTorquesApplied(i),posResult(i)]=brake_test(i, dir,...
                    posResGui(i)); %#ok<AGROW,NASGU>

                % check if theres been a request to terminate this loop
                if terminate_loops
                    return;
                end
                if posResult(i)==TEST_ERROR
                    presentMakoResults(guiHandles,'FAILURE',error_message);
                    log_results(hgs,'BrakeCheck','FAIL',error_message);
                    %fill in return data
                    userDataStruct.results=-1;
                    set(guiHandles.figure,'UserData',...
                        userDataStruct);
                    return;
                end

                % Now test the negative direction
                % Test the negative direction
                dir = -1;
                updateMainButtonInfo(guiHandles,'text',...
                    sprintf('Testing Joint %d - Negative',i));

                % show the test block
                set(negResGui(i),'Visible','on');
                                
                [maxNegativeTorquesApplied(i),negResult(i)]=brake_test(i, dir,...
                    negResGui(i)); %#ok<AGROW,NASGU>
                % check if theres been a request to terminate this loop
                if terminate_loops
                    return;
                end
                if negResult(i)==TEST_ERROR
                    presentMakoResults(guiHandles,'FAILURE',error_message);
                    log_results(hgs,'BrakeCheck','FAIL',error_message);
                    %fill in return data
                    userDataStruct.results=-2;
                    set(guiHandles.figure,'UserData',...
                        userDataStruct);
                    return;
                end
            end
        catch
            % check to see if this was delibrate cancel else post the error
            if terminate_loops
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',lasterr);
                log_results(hgs,'BrakeCheck','FAIL',lasterr);
                %fill in return data
                userDataStruct.results=-2;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
                return;
            end
        end

        % Test is complete, go to gravity mode
        mode(hgs,'zerogravity','ia_hold_enable',0);

        % if any of the test had failed quit immediately else do the brake
        % release test
        if (~any(posResult<0) &&  ~any(negResult<0)) || HassRun
            set(releaseGui,'Visible','on');
            set(releaseTestTitle,'Visible','on');
            for i=1:robotDOF
                % go to test position
                try
                    % go to test position
                    updateMainButtonInfo(guiHandles,...
                        'text','Moving to test position');
                    go_to_position(hgs,test_pos,0.3);
                    timer = tic;
                    % allow time for joints to settle after move
                    while toc(timer) <= 3.0
                        if ~strcmp(mode(hgs),'go_to_position')
                            presentMakoResults(guiHandles,'FAILURE',hgs.go_to_position.mode_error);
                            log_results(hgs,'BrakeCheck','FAIL',hgs.go_to_position.mode_error);
                            %fill in return data
                            userDataStruct.results=-2;
                            set(guiHandles.figure,'UserData',...
                                userDataStruct);
                            return;
                        end
                        
                    end
                catch
                    % check if this was an abort, return silenty
                    if terminate_loops
                        return;
                    else
                        presentMakoResults(guiHandles,'FAILURE',lasterr);
                    	log_results(hgs,'BrakeCheck','FAIL',lasterr);
                        %fill in return data
                        userDataStruct.results=-2;
                        set(guiHandles.figure,'UserData',...
                            userDataStruct);
                        return;
                    end
                end
                if terminate_loops
                    return;
                end

                set(releaseResGui(i),'Visible','on');
                [maxReleaseTq(i),releaseResult(i)]=brake_release_test(i,...
                    releaseResGui(i)); %#ok<AGROW>
                % check if theres been a request to terminate this loop
                % check if theres been a request to terminate this loop
                if terminate_loops
                    return;
                end
                if releaseResult(i)==TEST_ERROR
                    presentMakoResults(guiHandles,'FAILURE',error_message);
                    log_results(hgs,'BrakeCheck','FAIL',error_message);

                    %fill in return data
                    userDataStruct.results=-2;
                    set(guiHandles.figure,'UserData',...
                        userDataStruct);
                    return;
                end
            end
        else
            % Dont contribute to failure result.  this test has not run
            % as a prior test failed
            releaseResult = ones(1,robotDOF);
        end

        % Now present the final results
        resultString = {};
        if any(posResult==TEST_ERROR) ...
                || any(negResult==TEST_ERROR) ...
                || any(releaseResult==TEST_ERROR)
            presentMakoResults(guiHandles,'FAILURE',error_message);
            log_results(hgs,'BrakeCheck','FAIL',error_message,...
	    	'posBrakeHoldingTorque',maxPositiveTorquesApplied,...
		'negBrakeHoldingTorque',maxNegativeTorquesApplied,...
		'brakeReleasetorque',maxReleaseTq);

            %fill in return data
            userDataStruct.results=-2;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        elseif any(posResult==TEST_FAILED) ...
                || any(negResult==TEST_FAILED) ...
                || any(releaseResult==TEST_FAILED)
            % there was an error
            % find the cause of the error and display
            for i=1:robotDOF
                if posResult(i)==TEST_FAILED
                    resultString{end+1} = sprintf('J%d pos %2.3f (min req %2.3f Nm)',...
                        i,maxPositiveTorquesApplied(i),BRAKE_HOLDING_TQ_LIMIT(i)); %#ok<AGROW>
                end
                if negResult(i)==TEST_FAILED
                    resultString{end+1} = sprintf('J%d neg %2.3f (min req %2.3f Nm)',...
                        i,maxNegativeTorquesApplied(i),BRAKE_HOLDING_TQ_LIMIT(i)); %#ok<AGROW>
                end
                if releaseResult(i)==TEST_FAILED
                    resultString{end+1} = sprintf('J%d release %2.3f (max tq %2.3f Nm)',...
                        i,maxReleaseTq(i),BRAKE_RELEASE_TQ_LIMIT(i)); %#ok<AGROW>
                end
            end
            
            % log the failure
            problemJointList = find(((posResult==TEST_FAILED)...
                | (negResult==TEST_FAILED)...
                | (releaseResult==TEST_FAILED)));
            presentMakoResults(guiHandles,'FAILURE',resultString);
            log_string = ['Brake Check errors (Joints ',num2str(problemJointList,'%d '),' )'];
            log_results(hgs,'BrakeCheck','FAIL',log_string,...
	    	'posBrakeHoldingTorque',maxPositiveTorquesApplied,...
		'negBrakeHoldingTorque',maxNegativeTorquesApplied,...
		'brakeReleasetorque',maxReleaseTq);

            %fill in return data
            userDataStruct.results=-1;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        elseif any(posResult==TEST_WARNING) ...
                || any(negResult==TEST_WARNING) ...
                || any(releaseResult==TEST_WARNING)
            % there was a warning
            % find the cause of the error and display
            for i=1:robotDOF
                if posResult(i)==TEST_WARNING
                    resultString{end+1} = sprintf('J%d pos %2.3f (min req %2.3f Nm)',...
                        i,maxPositiveTorquesApplied(i),BRAKE_HOLDING_TQ_LIMIT(i)); %#ok<AGROW>
                end
                if negResult(i)==TEST_WARNING
                    resultString{end+1} = sprintf('J%d neg %2.3f (min req %2.3f Nm)',...
                        i,maxNegativeTorquesApplied(i),BRAKE_HOLDING_TQ_LIMIT(i)); %#ok<AGROW>
                end
                if releaseResult(i)==TEST_WARNING
                    resultString{end+1} = sprintf('J%d release %2.3f (max tq %2.3f Nm)',...
                        i,maxReleaseTq(i),BRAKE_RELEASE_TQ_LIMIT(i)); %#ok<AGROW>
                end
            end
            presentMakoResults(guiHandles,'WARNING',resultString);
            
            % log the failure
            problemJointList = find(((posResult==TEST_WARNING)...
                | (negResult==TEST_WARNING)...
                | (releaseResult==TEST_WARNING)));


            log_string = ['Brake Check errors (Joints ',num2str(problemJointList,'%d '),' )'];
            log_results(hgs,'BrakeCheck','WARNING',log_string,...
	    	'posBrakeHoldingTorque',maxPositiveTorquesApplied,...
		'negBrakeHoldingTorque',maxNegativeTorquesApplied,...
		'brakeReleasetorque',maxReleaseTq);
            
	    %fill in return data
            userDataStruct.results=2;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        else
            presentMakoResults(guiHandles,'SUCCESS');
            
            log_results(hgs,'BrakeCheck','PASS','Brake Check Successful',...
	    	'posBrakeHoldingTorque',maxPositiveTorquesApplied,...
		'negBrakeHoldingTorque',maxNegativeTorquesApplied,...
		'brakeReleasetorque',maxReleaseTq);
	    
            %fill in return data
            userDataStruct.results=1;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        end

        dataFileName=['brake_data-',...
            hgs.name,'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];

        fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);

        save(fullDataFileName,'maxPositiveTorquesApplied',...
            'maxNegativeTorquesApplied',...
	    'maxReleaseTq',...
            'posResult',...
            'negResult',...
	    'releaseResult');

        userDataStruct.maxPositiveTorquesApplied = maxPositiveTorquesApplied;
        userDataStruct.maxNegativeTorquesApplied = maxNegativeTorquesApplied;
        userDataStruct.posResult = posResult;
        userDataStruct.negResult = negResult;
        userDataStruct.resultString = resultString;
        userDataStruct.releaseResult = releaseResult;
        userDataStruct.BRAKE_HOLDING_TQ_LIMIT = BRAKE_HOLDING_TQ_LIMIT;
        userDataStruct.maxReleaseTq = maxReleaseTq;
        userDataStruct.BRAKE_RELEASE_TQ_LIMIT = BRAKE_RELEASE_TQ_LIMIT;
        % save results to UserData to facilitate access from external
        set(guiHandles.figure,'UserData', userDataStruct);

        mode(hgs,'zerogravity');
    end

%--------------------------------------------------------------------------
% internal function with the implementation of the brake test routine
% described earlier.  This tests the brake holding strength
%--------------------------------------------------------------------------
    function [maxTorqueTested,testResult]= brake_test(Joint, direction,...
            textBoxHandle)

        maxTorqueTested = 0;

        %begin brake testing
        mode(hgs,'brake_test',...
            'axis',Joint-1,...
            'brake_location',BRAKE_PLACEMENT(Joint),...
            'test_mode','brake_holding_test',...
            'rampup_time',2,...
            'rampdn_time',2,...
            'angle_threshold',HOLD_MOTION_DETECTION_THRESHOLD(Joint),...
            'max_torque',direction* test_holding_tq_limit(Joint));

        % check if the module is still executing
        while (strcmp(mode(hgs),'brake_test') && ~terminate_loops)
            % update the text box with the latest values
            brakeModuleVars = hgs.brake_test;
            appliedTorque = abs(brakeModuleVars.max_applied_torque);

            % save the maximum applied torque
            if (abs(appliedTorque)>abs(maxTorqueTested))
                maxTorqueTested = appliedTorque*direction;
            end
            
            if brakeModuleVars.test_status == 1
                set(textBoxHandle,...
                    'String',sprintf('%2.2f\nRampDown',maxTorqueTested),...
                    'FontSize',0.3);
            else
                set(textBoxHandle,...
                    'String',sprintf('%2.2f',maxTorqueTested),...
                    'FontSize',0.5);
            end

            % check the status of the test
            if brakeModuleVars.test_status == 0
                % Test was successful but still test
                testResult = TEST_PASSED;
                set(textBoxHandle,...
                    'BackgroundColor','green');
                break;
            elseif brakeModuleVars.test_status == -1
                % test for warning
                if (abs(maxTorqueTested)>BRAKE_HOLDING_TQ_LIMIT(Joint))
                    set(textBoxHandle,'BackgroundColor','yellow');
                    testResult = TEST_WARNING;
                else
                    set(textBoxHandle,'BackgroundColor','red');
                    testResult = TEST_FAILED;
                end
                break;
            end

            % pause a little to allow other actions
            pause(0.01);
            drawnow;
        end

        % if this was a request to terminate the loop call it a failure
        if terminate_loops
            testResult = 0;
        end

        % this was a mode error keep track of it
        if ~strcmp(mode(hgs),'brake_test')
            error_message = cell2mat(hgs.brake_test.mode_error);
            testResult = TEST_ERROR;
            set(textBoxHandle,'BackgroundColor','red');
        end

    end

%--------------------------------------------------------------------------
% internal function with the implementation of the brake test routine
% described earlier.  This tests the brake_release
%--------------------------------------------------------------------------
    function [maxTorqueTested,testResult]= brake_release_test(Joint,...
            textBoxHandle)

        maxTorqueTested = 0;
        set(textBoxHandle,'String',sprintf('%2.2f',maxTorqueTested));
        
        reconnect(hgs); % make sure hgs is connected
        
        %begin brake testing
        mode(hgs,'brake_test',...
            'axis',Joint-1,...
            'brake_location',BRAKE_PLACEMENT(Joint),...
            'test_mode','brake_release_test',...
            'rampup_time',BRAKE_RELEASE_RAMPUP_TIME(Joint),...
            'disengage_time',0.2,...
            'max_torque',BRAKE_RELEASE_TQ_LIMIT(Joint),...
            'angle_threshold',RELEASE_MOTION_DETECTION_THRESHOLD(Joint));

        % check if the module is still executing
        while (strcmp(mode(hgs),'brake_test') && ~terminate_loops)
            % update the text box with the latest values
            brakeModuleVars = hgs.brake_test;
            appliedTorque = brakeModuleVars.max_applied_torque;

            if (appliedTorque>abs(maxTorqueTested))
                maxTorqueTested = appliedTorque;
                set(textBoxHandle,'String',sprintf('%2.2f',maxTorqueTested));
            end
            % check the status of the test
            if brakeModuleVars.test_status == 0
                % Test was successful (still check if this is in warning
                % level)
                if (Joint==6)
                    % add special handling for J6 to allow for higher
                    % friction as indicated by friction test
                    brake_release_warning_ratio = BRAKE_RELEASE_WARNING_RATIO_J6;
                    
                else
                    brake_release_warning_ratio = BRAKE_RELEASE_WARNING_RATIO;
                end
                if (abs(maxTorqueTested)>BRAKE_RELEASE_TQ_LIMIT(Joint)*brake_release_warning_ratio)
                    testResult = TEST_WARNING;
                    set(textBoxHandle,'BackgroundColor','yellow');
                else
                    testResult = TEST_PASSED;
                    set(textBoxHandle,'BackgroundColor','green');
                end
                break;
            elseif brakeModuleVars.test_status == -1
                % this is an error
                set(textBoxHandle,'BackgroundColor','red');
                testResult = TEST_FAILED;
                break;
            end

            % pause a little to allow other actions
            pause(0.01);
            drawnow;
        end

        % if this was a request to terminate the loop call it a failure
        if terminate_loops
            testResult = TEST_ABORT;
        end

        % this was a mode error keep track of it
        if ~strcmp(mode(hgs),'brake_test')
            error_message = cell2mat(hgs.brake_test.mode_error);
            testResult = TEST_ERROR;
            set(textBoxHandle,'BackgroundColor','red');
        end
    end
%--------------------------------------------------------------------------
% internal function to cancel the brake test procedure
%--------------------------------------------------------------------------
    function abortBrakeTestProcedure(varargin)
        terminate_loops = true;
        mode(hgs,'zerogravity');
        pause(0.3);

        % close the connection if it was established by this script
        if defaultRobotConnection
            log_message(hgs,'Brake Check script closed');
            close(hgs);
        end
        closereq;
    end
end


%------------- END OF FILE ----------------
