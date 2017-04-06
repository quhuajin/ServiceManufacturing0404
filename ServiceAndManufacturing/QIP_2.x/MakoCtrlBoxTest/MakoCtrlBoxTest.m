function MakoCtrlBoxTest(hgs,testMode)

% MakoCtrlBoxTest Gui to monitor the CPCI controller test
%
% Syntax:
%   MakoCtrlBoxTest(hgs)
%       Starts the MakoCtrlBoxTest GUI for performing functional testing
%       of Mako's cPCI motor controller board (see Test Description for
%       details)
%
%   MakoCtrlBoxTest(hgs,testMode)
%       The argument testMode allows the user to select between
%       'Reliability' or 'QIP' mode.  In reliability mode, the code will
%       run forever.  In QIP mode the test will run a max of
%       QIP_TEST_COUNT (50) times.  The test will present results when done
%
% Notes:
%   Tests are handled in CRISIS.  This script is only to monitor the status
%   of the tests.  for a complete description of the tests refer to
%   Reliability test document.  There is a small delay between tests during
%   which no checks are performed.  This is to allow for all hardware
%   resets etc to take effect.
%   The jobId number can be used to change the number of test cycles, i.e.
%   add the characters 'ST' followd by the desired number of cycles. For
%   example, if jobID is 12345 enter and 5 test cycles is needed, input
%   the jobId as 12345ST5. In addition if we add an 'N' at the end (e.g 12345ST5N)
%   then the test will run in non-stop mode, i.e it will not end when an
%   error occur
%
% Test Description
%   This test is meant to test the controller box assembly using the Mako
%   controller simulator.  The mako controller simulator simulates
%   different signals and failures to the system as described below.  This
%   script tests the controller behavior to the expected controller
%   behavior.  Each test is performed for 2 seconds.  The script gets
%   notified when the tests changes and it updates the gui to reflect this
%   change.  The script also logs the number of successful tests and failed
%   tests.  This information can be viewed by placing the mouse over the
%   appropriate axis.
%
%   Below is the list of all the tests and the expected behavior
%
%   Tests performed at all times (software based safeties)
%       estop error     Estop error should not be triggered
%       software error  software error should not be triggered
%       fw_deadlock_error should not be triggered
%       firmware_watchdog should not be triggered
%       pld_watchdog   should not be triggered
%       crisis_watchdog should not be triggered
%       test_time       should never be more than 2 seconds
%
%  ALL GOOD TESTS
%  following conditions should be met during all good tests.  All good
%  tests, are tests where there are no errors simulated.
%       joint encoder error should not be triggered
%       motor encoder error should not be triggered
%       hall error          should not be triggered
%       joint encoder should count at a predetermined rate as simulated by
%           the simulator
%       motor encoder should count at a predetermined rate as simulated by
%           the simulator
%       brake_current       should be at full current for the first 0.45
%           seconds followed by 1 second of reduced brake current.  And
%           and finally by a current at close to 0 indicating that the
%           brakes are engaged.
%       motor_currents      CRISIS commands a sinusoidal current to the
%           simulator.  The simulator has an inductive load, and then the
%           current error is monitored to make sure that the current loop
%           is working fine.
%       hall_states  Simulator changes the hall states at a known rate and
%           this is checked by the script
%       hardware fault should not be triggered
%
%  HALL_HIGH and HALL_LOW
%       joint encoder error should not be triggered
%       motor encoder error should not be triggered
%       hall error          should be triggered
%       motor currents should be around 0
%       brake currents should be around 0
%       hardware fault should be triggered
%
% 'ENCODER_A_HIGH','ENCODER_A_LOW','ENCODER_A_TRISTATE'
% 'ENCODER_B_HIGH','ENCODER_B_LOW','ENCODER_B_TRISTATE'
% 'ENCODER_I_TRISTATE','ENCODER_I_HIGH','ENCODER_I_LOW'
%       joint encoder error should be triggered
%       motor encoder error should be triggered
%       hall error          should not be triggered
%       motor currents should be around 0
%       brake currents should be around 0
%       hardware fault should be triggered
%
%  'RESET_TESTS'
%       No tests are being performed, The test sequence is being reset
%
% See also:
%   hgs_robot
%

%
% $Author: hqu $
% $Revision: 4161 $
% $Date: 2017-03-31 15:38:21 -0400 (Fri, 31 Mar 2017) $
% Copyright: MAKO Surgical corp (2008)
%

%% DETERMINE TEST MODE, SET VARIABLES/PARAMETERS, GET JOBID
if ~exist('testMode','var')
    testMode = 'QIP';
    qipTestMode = true;
else
    if ~strcmpi(testMode,'QIP') && ~strcmpi(testMode,'Reliability')
        error('Invalid testMode: testMode should be ''QIP'' or ''Reliability''');
    end
end

% FTP variables
targetName = '172.16.16.100';
CONFIGURATION_FILES_DIR = '/CRISIS/bin/configuration_files';
CFG_FILENAME = 'hgs_arm.cfg';
DEFAULT_CFG_FILENAME = 'hgs_arm.cfg.default';

% Test Parameters
if strcmpi(testMode,'QIP')
    QIP_TEST_COUNT = 50;
    qipTestMode = true;
    % in qip mode ask for the work order id
    
    % Query the user for the serial number/workid
    jobId = getMakoJobId;
    % handle the cancel button
    if isempty(jobId)
        return;
    end
    
    strIndx = findstr(upper(jobId),'ST'); %if there is ST (Short Run)at the end
    %of jobId reduce the number of  runs
    if ~isempty(strIndx)
        if ~isempty( sscanf(upper(jobId(strIndx:end)), 'ST%d'))
            QIP_TEST_COUNT = sscanf(upper(jobId(strIndx:end)), 'ST%d');
        else
            QIP_TEST_COUNT = 50; %default is 50 runs
        end
        if upper(jobId(end)) == 'N'
            qipTestMode = false;
        end
        jobId(strIndx:end) = []; %take out the Short Run instruction
    end
else
    QIP_TEST_COUNT = inf;
    qipTestMode = false;
    jobId = 'ReliabilityTest-CPCI';
end

%% SANITY CHECK TO SEE IF TARGET IS REACHABLE
 host = getenv('ROBOT_HOST');
    if isempty(host)
        error('Robot host not specified...ROBOT_HOST enviroment variable not set');
    end
    
%% GET HARDWARE VERSION, CRISIS IMAGE, AND CONFIG FILE

% Make user choose hardware version
CPCIversion = questdlg({'This QIP requires an install of CRISIS depending on hardware version.', ...
    'To cancel, press the X in the upper right hand corner of this pop-up.'}, ...
    'Choose CPCI Hardware Version', ...
    'RIO 2.0','RIO 2.2', 'RIO 3.0', 'RIO 3.0');
% Handle response by grabbing correct image/file
switch CPCIversion
    case 'RIO 2.0' % 2.0
        % load Svc-RIO2_0-xxxx.img
        svc_img = 'Svc-RIO2_0.img';
        defaultCfgFile = 'hgs_arm2_0.cfg.default';
        
    case 'RIO 2.2' % 2.2
        % load Svc-RIO2_2-xxxx.img
        svc_img = 'Svc-RIO2_2.img';
        defaultCfgFile = 'hgs_arm2_2.cfg.default';
        
    case 'RIO 3.0' % 3.0
        % load Svc-RIO3_0-xxxx.img
        svc_img = 'Svc-RIO3_0.img';
        defaultCfgFile = 'hgs_arm3_0.cfg.default';
    case 'RIO 3.1' % 3.1
        % load Svc-RIO3_1-xxxx.img
        svc_img = 'Svc-RIO3_1.img';
        defaultCfgFile = 'hgs_arm3_1.cfg.default';
        
    case '' % Canceled
        h = msgbox('User canceled hardware version selection. Script canceled.');
        pause(2)
        try
            close(h)
        catch
        end
        return
        
    otherwise
        error('Error retreiving CRISIS image. Check path.');
end

%% PUSH SELECTED DEFAULT CONFIG FILE ONTO CPCI VIA FTP CONNECTION

% Open FTP connection
try
    ftpId = ftp2(targetName,'service','18thSeA');
catch
    error('Error connecting through FTP.');
end
        
        
% Copy default config file onto cpci
try
    % CD to config directory
    cd(ftpId,CONFIGURATION_FILES_DIR);
    pasv(ftpId);
    
    % Copy default config file to hgs as the current cfg file
    cfgFilePath = which(defaultCfgFile);
    ffn = fullfile(cfgFilePath);
    copyfile(ffn,CFG_FILENAME,'f');
    mput(ftpId,CFG_FILENAME);
    
    % Copy default config file to hgs as the default cfg file
    copyfile(ffn,DEFAULT_CFG_FILENAME,'f');
    mput(ftpId,DEFAULT_CFG_FILENAME);
    
    % clean up temp files
    delete(CFG_FILENAME);
    delete(DEFAULT_CFG_FILENAME);
catch
    close(ftpId);
    error('Error loading default config file through FTP.');
end

% Close FTP connection
close(ftpId);

        
%% INSTALL SELECTED SERVICE CRISIS IMAGE ONTO CPCI

% close hgs if exists
try
    close(hgs);
catch
end

% Use low level loadngo to install crisis
try
    response = load_arm_software_direct(host,svc_img);
catch
    error('Error loading arm software')
end  
    
%% GENERATE GUI AND CONTINUE WITH TEST
guiHandles = generateMakoGui('Mako Controller Box Test',[],jobId,true);           

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
elseif nargin > 1
    hgs = reconnect(hgs);
end

TEST_TIME = 2.0; %secs.  This is hardcoded in hardware
BRAKE_SIM_RESISTANCE = 25; % ohms
brake_fullcurrent = hgs.BUS_VOLTAGE_NOMINAL(1)/BRAKE_SIM_RESISTANCE;
BRAKE_VOLTAGE_NOMINAL = 12; % volts
brake_lowcurrent = BRAKE_VOLTAGE_NOMINAL/BRAKE_SIM_RESISTANCE;
BRAKE_CURRENT_TOLERANCE = 0.26; % Amp
CURRENT_ERROR_RMS_THRESHOLD = 0.150; % Amp

JE_ENC_SIM_RATE = 32000; % enc/cycle
ME_ENC_SIM_RATE = 32000; % enc/cycle
ENC_SIM_TOLERANCE = 500; % enc/cycle

% Check if the argument is correct
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end

% generate the log file name
LOG_FILE_NAME = fullfile(guiHandles.reportsDir,...
    sprintf('MakoCtrlBoxTest-%s.txt',...
    datestr(now,'yyyy-mm-dd-HH-MM-SS')));

commonGuiProperties = struct(...
    'Style','text',...
    'Units','Normalized',...
    'FontUnits','normalized',...
    'FontSize',0.8...
    );

% Add the test specific GUI

% Create a label for the test name being run
for i=1:hgs.WAM_DOF %#ok<FXUP>
    
    ypos = 0.95 - 0.125*i;
    
    if isfinite(QIP_TEST_COUNT)
        jointText = sprintf('Joint %d (0/%d)',i,QIP_TEST_COUNT);
    else
        jointText = sprintf('Joint %d (0)',i);
    end
    
    jointLabel(i) = uicontrol(guiHandles.uiPanel,...
        commonGuiProperties,...
        'FontWeight','bold',...
        'Position',[0.01 ypos 0.25 0.04],...
        'String',jointText ...
        ); %#ok<AGROW>
    testNameLabel(i) = uicontrol(guiHandles.uiPanel,...
        commonGuiProperties,...
        'Position', [0.275 ypos 0.34 0.04],...
        'String','---'...
        ); %#ok<AGROW>
    
    % Display a progress bar for the test completion time
    progaxes = axes(...
        'Parent',guiHandles.uiPanel,...
        'Color','white',...
        'Position',[0.65 ypos 0.3 0.05],...
        'XLim',[0 1],...
        'YLim',[0 1],...
        'Box','on',...
        'ytick',[],...
        'xtick',[] );
    progressbar(i) = patch(...
        'Parent',progaxes,...
        'XData',[0 0 0 0],...
        'YData',[0 0 1 1],...
        'FaceColor','green'...
        );     %#ok<AGROW>
end

% Create a text box for log files
uicontrol(guiHandles.extraPanel,...
    commonGuiProperties,...
    'Position',[0.05 0.9 0.9 0.05],...
    'Style','text',...
    'String','Recent Logs',...
    'FontUnits','points',...
    'FontWeight','bold',...
    'FontSize',16 ...
    );
logListBox = uicontrol(guiHandles.extraPanel,...
    commonGuiProperties,...
    'Style','listbox',...
    'Position',[0.05 0.05 0.9 0.8],...
    'FontUnits','points',...
    'FontSize',8 ...
    );

logEntryList=[];
terminateTest = false;
cancelTest = false;

% Display a test box to indicate test errors

% setup the cancel button
set(guiHandles.figure,'CloseRequestFcn',@cancelProcedure);

% Backup configuration params
hgsBackup.DEVICE_NAME = hgs.DEVICE_NAME;
hgsBackup.SAFETY_CHECKS = hgs.SAFETY_CHECKS;
hgsBackup.DEFAULT_USER_INTERFACE = hgs.DEFAULT_USER_INTERFACE;
hgsBackup.TRACKING_SYSTEM = hgs.TRACKING_SYSTEM;
hgsBackup.PERIPHERAL_SYSTEM = hgs.PERIPHERAL_SYSTEM;
hgsBackup.DEFAULT_CONTROLLER = hgs.DEFAULT_CONTROLLER;

% Now setup the callback to allow user to press and start the test
        updateMainButtonInfo(guiHandles,@updateDisplay);


%--------------------------------------------------------------------------
% Internal function to update the gui display elements
%--------------------------------------------------------------------------
    function updateDisplay(varargin)
        
        try
            updateMainButtonInfo(guiHandles,'text','Starting Tests');
            pause(0.5);
            updateMainButtonInfo(guiHandles,'text','Turning off all safety checks');
            
            % Turn off all the safety checks and restart CRISIS
            hgs.DEVICE_NAME = {'MakoCtrlSimulator'};
            hgs.SAFETY_CHECKS{:} = {'NONE'};
            hgs.SAFETY_CHECKS{end} = {'END'};
            
            hgs.DEFAULT_USER_INTERFACE = {'no_ui'};
            hgs.TRACKING_SYSTEM = {'Simulate'};
            if(strcmp(hgs.PERIPHERAL_SYSTEM,'pcm_anspach')==1)
                hgs.PERIPHERAL_SYSTEM = {'Simulate'};
            else
                hgs.PERIPHERAL_SYSTEM = {'simulate_ups', 'simulate_anspach', 'END'};
            end
            hgs.DEFAULT_CONTROLLER = {'no_controller'};
            
            
            restartCRISIS(hgs);
            pause(1);
            reconnect(hgs);
            
            
            logEntry('Mako Controller Box Test Started',false,-1);
            if (qipTestMode == false)
                logEntry('A non-stop test is requested',false,-1);
            end
            logEntry(sprintf('Testing on %d cards',hgs.WAM_DOF),false,-1);
            
            % change the button to a text box so that it doesnt get pressed
            % again
            updateMainButtonInfo(guiHandles,'text','Running Tests...');
            
            % get the DOF of the arm
            dof = hgs.WAM_DOF;
            
            % default all testSuccess to failure
            testLogDone = zeros(1,dof);
            prevTestCode = ones(1,dof)*-1;
            digital_error_fail_count = zeros(1,dof);
            current_error_sumErr = zeros(1,dof);
            current_error_num_sample = zeros(1,dof);
            hgsVar = hgs(:);
            total_cycles = zeros(1,dof)-1;
            num_encoder_rate_counts = zeros(1,dof);
            old_je_encoder_ = zeros(dof);
            old_me_encoder = zeros(dof);
            ttt = zeros(dof);
            je_encoder_rate = zeros(1,dof) + JE_ENC_SIM_RATE;
            me_encoder_rate = zeros(1,dof) + ME_ENC_SIM_RATE;
            sss = 0;
            % start updating the gui
            while(~terminateTest && ~cancelTest )
                
                % if the required number of tests are done. stop it
                
                % get the variables
                prevHgsVar = hgsVar;
                hgsVar = hgs(:);
                for i=1:dof %#ok<FXUP>
                    
                    set(testNameLabel(i),'String',hgsVar.test_name{i});
                    % update the progress bar
                    testProgress = hgsVar.test_time(i)/TEST_TIME;
                    
                    if prevTestCode(i) ~= hgsVar.test_code(i)
                        % if the test is a reset tests increment the test loop
                        % count
                        if strcmp(hgsVar.test_name{i},'RESET_TESTS')
                            total_cycles(i) = total_cycles(i)+1;
                            if isfinite(QIP_TEST_COUNT)
                                set(jointLabel(i),'String',sprintf('Joint %d (%d/%d)',...
                                    i,total_cycles(i),QIP_TEST_COUNT));
                            else
                                set(jointLabel(i),'String',sprintf('Joint %d (%d)',...
                                    i,total_cycles(i)));
                            end
                        end
                        
                        %increment the test counts
                        try
                            testStatus.(prevHgsVar.test_name{i}).count(i) ...
                                = testStatus.(prevHgsVar.test_name{i}).count(i) + 1;
                        catch
                            % New test name found
                            testStatus.(prevHgsVar.test_name{i}).count = zeros(1,dof);
                            testStatus.(prevHgsVar.test_name{i}).success_count = zeros(1,dof);
                            testStatus.(prevHgsVar.test_name{i}).failure_count = zeros(1,dof);
                            
                            % Now try again
                            testStatus.(prevHgsVar.test_name{i}).count(i) ...
                                = testStatus.(prevHgsVar.test_name{i}).count(i) + 1;
                        end
                        
                        %setup success count
                        if ~testLogDone(i)
                            testStatus.(prevHgsVar.test_name{i}).success_count(i) ...
                                = testStatus.(prevHgsVar.test_name{i}).success_count(i) + 1;
                        else
                            testStatus.(prevHgsVar.test_name{i}).failure_count(i) ...
                                = testStatus.(prevHgsVar.test_name{i}).failure_count(i) + 1;
                        end
                        
                        % convert struct to string
                        executedTestNames = fieldnames(testStatus);
                        
                        for j=1:length(executedTestNames)
                            testStatusString.(executedTestNames{j}) = sprintf(...
                                'Successful %d / Failed %d / Total %d',...
                                testStatus.(executedTestNames{j}).success_count(i),...
                                testStatus.(executedTestNames{j}).failure_count(i),...
                                testStatus.(executedTestNames{j}).count(i));
                        end
                        % update the display string
                        set(jointLabel(i),'TooltipString',convertStructToString(testStatusString));
                        
                        % reset the test state
                        testLogDone(i) = false;
                        prevTestCode(i) = hgsVar.test_code(i);
                        
                    elseif (hgsVar.test_time(i) < 0.3) || hgsVar.test_time(i)>2.0
                        % skip the first .3 sec to allow for error reset
                        testLogDone(i) = false;
                        digital_error_fail_count(i) = 0;
                    else
                        % do the common checks first
                        
                        % fail the test if the test is taking too long
                        if (testProgress > 1.1)
                            % log the error and set the flag to prevent
                            % duplicates
                            logEntry(sprintf('%s Test took too long',...
                                hgsVar.test_name{i}),testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        % check for card overheating
                        if (hgsVar.card_temperature(i)> hgs.SAFETY_TEMPERATURE_LIMIT(1)*.85) % 85
                            logEntry(sprintf(...
                                'high card temperature %3.2f',...
                                hgsVar.card_temperature(i)),testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        if (hgsVar.card_temperature(i) < hgs.SAFETY_TEMPERATURE_LIMIT(2)) % 0 
                            logEntry(sprintf(...
                                'Card temperature out of range %3.2f',...
                                hgsVar.card_temperature(i)),testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        % check monitored bus voltage
                        if abs(hgsVar.bus_voltage(i)-24.95)>2.0
                            logEntry(sprintf(...
                                'Measured bus voltage out of range (got %f expected 24.95V)',...
                                hgsVar.bus_voltage(i)),testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        % check monitored brake voltage
                        if abs(hgsVar.brake_voltage(i)-12)>1.0
                            logEntry(sprintf(...
                                'Measured brake voltage out of range (got %f expected 12V)',...
                                hgsVar.brake_voltage(i)),testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        
                        % check if the digital outputs are working fine.
                        % digital outputs go through a not gate and fed back to
                        % digital inputs
                        if mod(floor(hgsVar.time),2)
                            if hgsVar.digital_inputs(2*i-1)
                                digital_error_fail_count(i) = digital_error_fail_count(i)+1;
                                if (digital_error_fail_count(i)>5)
                                    logEntry(sprintf(...
                                        ['Incorrect digital state during %s ',...
                                        '(expected HIGH got LOW)'],...
                                        hgsVar.test_name{i}),...
                                        testLogDone(i),i);
                                    testLogDone(i) = true;
                                end
                            end
                        else
                            if ~hgsVar.digital_inputs(2*i-1)
                                digital_error_fail_count(i) = digital_error_fail_count(i)+1;
                                if (digital_error_fail_count(i)>5)
                                    logEntry(sprintf(...
                                        ['Incorrect digital state during %s ',...
                                        '(expected LOW got HIGH)'],...
                                        hgsVar.test_name{i}),...
                                        testLogDone(i),i);
                                    testLogDone(i) = true;
                                end
                            end
                        end
                        
                        % Do the common hardware checks
                        if (hgsVar.estop_error(i) ...
                                || hgsVar.software_error(i) ...
                                || hgsVar.fw_deadlock_error(i) ...
                                || hgsVar.firmware_watchdog(i) ...
                                || hgsVar.pld_watchdog(i) ...
                                || hgsVar.crisis_watchdog(i))
                            if hgsVar.estop_error(i)
                                errorReason = 'ESTOP error';
                            elseif hgsVar.software_error(i)
                                errorReason = 'Software error';
                            elseif hgsVar.fw_deadlock_error(i)
                                errorReason = 'Firmware DeadLock';
                            elseif hgsVar.firmware_watchdog(i)
                                errorReason = 'Firmware Watchdog';
                            elseif hgsVar.pld_watchdog(i)
                                errorReason = 'PLD Watchdog';
                            elseif hgsVar.crisis_watchdog(i)
                                errorReason = 'CRISIS watchdog';
                            else
                                errorReason = 'Unknown error';
                            end
                            
                            logEntry(sprintf('Test %s failed (%s)',...
                                hgsVar.test_name{i},errorReason),...
                                testLogDone(i),i);
                            testLogDone(i) = true;
                        end
                        
                        if ~strcmp(char(hgsVar.test_name{i}), 'ALL_GOOD')
                            num_encoder_rate_counts(i) = 0;
                        end
                        
                        
                        % Now take test specific action
                        switch char(hgsVar.test_name{i})
                            case {'ALL_GOOD'}
                                % check if it is really all good
                                % determine the reason for the error
                                
                                %ignore the first 250msec in case of timing issue
                                if hgsVar.test_time > .5
                                    if  num_encoder_rate_counts(i) == 1
                                        %read first encoder reading
                                        old_je_encoder( i ) = ...
                                            hgsVar.joint_encoder(i);
                                        old_me_encoder( i ) = ...
                                            hgsVar.motor_encoder(i);
                                        ttt = hgsVar.time;
                                        num_encoder_rate_counts(i) = ...
                                            num_encoder_rate_counts(i) + 1;
                                    else
                                        num_encoder_rate_counts(i) = ...
                                            num_encoder_rate_counts(i) + 1;
                                    end
                                    %calculate rate after 25 iteration
                                    %(there are roughly 10
                                    %iteration per test step)
                                    if  num_encoder_rate_counts(i) == 25
                                        num_encoder_rate_counts(i) = 0;
                                        deltaT = hgsVar.time - ttt;
                                        
                                        je_encoder_rate(i) = ...
                                            abs( double(hgsVar.joint_encoder(i) - ...
                                            old_je_encoder( i ) ) / ...
                                            deltaT );
                                        me_encoder_rate(i) = ...
                                            abs( double(hgsVar.motor_encoder(i) - ...
                                            old_me_encoder( i ) ) / ...
                                            deltaT );
                                        %   sprintf('time %f,case %d: %d , %d ', hgsVar.test_time, hgsVar.test_code,...
                                        %        int32(average_je_encoder_rate(i)), int32(average_me_encoder_rate(i)))
                                        num_encoder_rate_counts(i) = 0 ;
                                        
                                    end
                                else
                                    num_encoder_rate_counts(i) = 0;
                                end
                                %                             if (num_encoder_rate_counts(i) ~= 60)
                                %                                 sum_je_encoder_rate(i) = ...
                                %                                     sum_je_encoder_rate(i) + ...
                                %                                     abs(hgsVar.je_enc_rate(i));
                                %                                 sum_me_encoder_rate(i) = ...
                                %                                     sum_me_encoder_rate(i) + ...
                                %                                     abs(hgsVar.je_enc_rate(i));
                                %                                 num_encoder_rate_counts(i) = num_encoder_rate_counts(i)+1;
                                %                             else
                                %                                 average_je_encoder_rate(i) = ...
                                %                                     sum_je_encoder_rate(i)/ ...
                                %                                     num_encoder_rate_counts(i) ;
                                %                                 average_me_encoder_rate(i) = ...
                                %                                     sum_me_encoder_rate(i)/ num_encoder_rate_counts(i);
                                %                                 num_encoder_rate_counts(i) = 0; %reset counts
                                %                                 sum_je_encoder_rate(i) = 0; %reset counts
                                %                                 sum_me_encoder_rate(i) = 0; %reset counts
                                %                             end
                                
                                
                                
                                errorReason = 'none';
                                if hgsVar.je_error(i)
                                    errorReason = 'Joint Encoder error';
                                elseif hgsVar.me_error(i)
                                    errorReason = 'Motor Encoder error';
                                elseif hgsVar.hall_error(i)
                                    errorReason = 'Hall error';
                                elseif hgsVar.hardware_error(i)
                                    errorReason = 'Hardware error';
                                elseif hgsVar.test_time(i) < 2.0 && ...
                                        abs(je_encoder_rate(i) - JE_ENC_SIM_RATE) > ...
                                        ENC_SIM_TOLERANCE
                                    
                                    errorReason = sprintf(...
                                        'Joint Encoder count rate out of spec expected %d got %d counts/sec',...
                                        JE_ENC_SIM_RATE, int32(je_encoder_rate(i)));
                                elseif hgsVar.test_time(i)<2.0 && ...
                                        abs(me_encoder_rate(i) - ME_ENC_SIM_RATE) > ...
                                        ENC_SIM_TOLERANCE
                                    errorReason = sprintf(...
                                        'Motor Encoder count rate out of spec expected %d got %d counts/sec',...
                                        ME_ENC_SIM_RATE, int32(me_encoder_rate(i)));
                                elseif (hgsVar.test_time(i)<0.45)
                                    if (abs(hgsVar.brake_current(i) ...
                                            - brake_fullcurrent)>BRAKE_CURRENT_TOLERANCE)
                                        errorReason = sprintf(...
                                            'Brake Current error expected %f got %f Amps',...
                                            brake_fullcurrent,hgsVar.brake_current(i));
                                    end
                                elseif (hgsVar.test_time(i)>0.6) && (hgsVar.test_time(i)<1.4)
                                    if (abs(hgsVar.brake_current(i) ...
                                            - brake_lowcurrent)>BRAKE_CURRENT_TOLERANCE)
                                        errorReason = sprintf(...
                                            'Brake Current error expected %f got %f Amps',...
                                            brake_lowcurrent,hgsVar.brake_current(i));
                                    end
                                elseif (hgsVar.test_time(i) > 1.6) ...
                                        && (abs(hgsVar.brake_current(i))>BRAKE_CURRENT_TOLERANCE)
                                    errorReason = sprintf(...
                                        'Brake current during brake engagement (%3.2f)',...
                                        hgsVar.brake_current(i));
                                elseif (hgsVar.test_time(i) > 1.6)
                                    current_error_sumErr(i) = current_error_sumErr(i) ...
                                        + hgsVar.current_error(i)^2;
                                    current_error_num_sample(i) = ...
                                        current_error_num_sample(i) + 1;
                                    if 40 == current_error_num_sample(i)
                                        current_error_RMS = sqrt(current_error_sumErr(i)/...
                                            current_error_num_sample(i));
                                        current_error_sumErr(i) = 0;
                                        current_error_num_sample(i) = 0;
                                        if current_error_RMS > CURRENT_ERROR_RMS_THRESHOLD
                                            errorReason = sprintf(...
                                                'Current error RMS (%f A) exceeds  %f A',...
                                                current_error_RMS, ...
                                                CURRENT_ERROR_RMS_THRESHOLD);
                                        end
                                    end
                                end
                                
                                % if there is any error log it
                                if ~strcmpi(errorReason,'none')
                                    
                                    logEntry(sprintf('Test %s failed (%s)',...
                                        hgsVar.test_name{i},errorReason),...
                                        testLogDone(i),i);
                                    testLogDone(i) = true;
                                    
                                end
                                
                            case {'HALL_LOW','HALL_HIGH'}
                                % Hall error should be true
                                errorReason = 'none';
                                if ~hgsVar.hall_error(i)
                                    errorReason = 'Undetected Hall error';
                                elseif hgsVar.me_error(i)
                                    errorReason = 'Motor Encoder error';
                                elseif hgsVar.je_error(i)
                                    errorReason = 'Joint Encoder error';
                                elseif hgsVar.hardware_error(i)
                                    errorReason = 'Hall error generated system error';
                                end
                                
                                % if there is any error log it
                                if ~strcmpi(errorReason,'none')
                                    logEntry(sprintf('Test %s failed (%s)',...
                                        hgsVar.test_name{i},errorReason),...
                                        testLogDone(i),i);
                                    testLogDone(i) = true;
                                end
                                
                            case {'ENCODER_A_HIGH','ENCODER_A_LOW',...
                                    'ENCODER_A_TRISTATE','ENCODER_B_HIGH',...
                                    'ENCODER_B_LOW','ENCODER_B_TRISTATE',...
                                    'ENCODER_I_TRISTATE','ENCODER_I_HIGH',...
                                    'ENCODER_I_LOW'}
                                % Encoder error should be true
                                errorReason = 'none';
                                if hgsVar.hall_error(i)
                                    errorReason = 'Hall error';
                                elseif ~hgsVar.me_error(i)
                                    errorReason = 'Undetected Motor Encoder error';
                                elseif ~hgsVar.je_error(i)
                                    errorReason = 'Undetected Joint Encoder error';
                                elseif ~hgsVar.hardware_error(i)
                                    errorReason = 'Encoder error did not generate system error';
                                end
                                
                                % if there is any error log it
                                if ~strcmpi(errorReason,'none')
                                    logEntry(sprintf('Test %s failed (%s)',...
                                        hgsVar.test_name{i},errorReason),...
                                        testLogDone(i),i);
                                    testLogDone(i) = true;
                                end
                            case {'RESET_TESTS'}
                                % Do nothing the tests are resetting
                            otherwise
                                % this is an unknown test state
                                logEntry(sprintf('Unknown Test State %s',...
                                    hgsVar.test_name{i},testLogDone(i),i));
                                testLogDone(i) = true;
                        end
                    end
                    
                    % scale test progress at 1.0
                    if (testProgress>1.0)
                        testProgress = 1.0;
                    end
                    
                    % Update color based on test
                    if testLogDone(i)
                        barColor = [1 0 0];
                        % failure occured, in case of a QIP stop immediately
                        if qipTestMode
                            terminateTest = true;
                        end
                    else
                        barColor = [0 1 0];
                    end
                    
                    % Update the progress bar
                    set(progressbar(i),...
                        'FaceColor',barColor,...
                        'XData',[0 testProgress testProgress 0]);
                end
                
                % check if all the tests are done
                if (total_cycles>=QIP_TEST_COUNT)
                    terminateTest = true;
                end
                
                % Update the display
                drawnow;
            end
            
        catch ER
            if(~cancelTest)
                presentMakoResults(guiHandles,'FAILURE',ER.message);
            end
            return
        end
        
        % check if this was a request to cancel the test
        if cancelTest
            return
        end
        
        % Tests are complete
        restoreConfigurationParams;
        % show pass/fail resulst only in QIP mode.
        if   qipTestMode == true
            % Tests have been terminated check if this was done because of
            % successfully completing all tests
            if (total_cycles>=QIP_TEST_COUNT)
                presentMakoResults(guiHandles,'SUCCESS','All tests Passed');
                logEntry(sprintf('All %d cards passed all tests',...
                    dof),false,-1);
            else
                presentMakoResults(guiHandles,'FAILURE');
                logEntry('QIP failed',false,-1);
            end
        else
            updateMainButtonInfo(guiHandles,'Test Completed');
        end
    end

%--------------------------------------------------------------------------
% Internal function to create a log entry and save the entry to log file
%
% Arguments
%   logSring: String to be logged
%   logDoneFlag:  if true logging will be ignored this is used to prevent
%                   multiple log entries
%   logAxis:  Associate errors with a particular axis
%--------------------------------------------------------------------------
    function logEntry(logString,logDoneFlag,logAxis)
        
        % if a log entry was already done skip this
        if logDoneFlag
            return;
        end
        
        % check if there is a logAxis specified to be logged
        if (logAxis==-1)
            % process the log entry
            logEntry = sprintf('%s      %s',datestr(now,31),logString);
        else
            logEntry = sprintf('%s      %s (J%d)',datestr(now,31),...
                logString,logAxis);
        end
        
        logEntryList{end+1} = logEntry;
        
        % update the display
        set(logListBox,...
            'String',logEntryList,...
            'Value',length(logEntryList)...
            );
        
        % Append to the log file
        fid = fopen(LOG_FILE_NAME,'a');
        fprintf(fid,'%s\n',logEntry);
        fclose(fid);
    end

%--------------------------------------------------------------------------
% Internal function to be able to handle cancelling the script prematurely
%--------------------------------------------------------------------------
    function cancelProcedure(varargin)
        cancelTest = true;
        % wait for the loop to complete
        pause(0.1);
        % try to restore the constants changed
        restoreConfigurationParams;
        closereq;
    end

%--------------------------------------------------------------------------
% Internal function to restore the Changed constants
%--------------------------------------------------------------------------
    function restoreConfigurationParams
        updateMainButtonInfo(guiHandles,'text',{'Restoring Constants', ...
            'Please Wait ...'});
        % restore the configuration parameters
        hgs.DEVICE_NAME = hgsBackup.DEVICE_NAME;
        hgs.SAFETY_CHECKS = hgsBackup.SAFETY_CHECKS;
        hgs.DEFAULT_USER_INTERFACE = hgsBackup.DEFAULT_USER_INTERFACE;
        hgs.TRACKING_SYSTEM = hgsBackup.TRACKING_SYSTEM;
        hgs.PERIPHERAL_SYSTEM = hgsBackup.PERIPHERAL_SYSTEM;
        hgs.DEFAULT_CONTROLLER = hgsBackup.DEFAULT_CONTROLLER;
        restartCRISIS(hgs);
        updateMainButtonInfo(guiHandles,'text','Constants Restored');
    end
end

% --------- END OF FILE ----------
