function QIP_MotorTest(test)
% QIP_MotorTest, runs the Motor level QIP for the TGS 2.x motors using the
% GALIL Controller. The following tests are done using this script
% 1. Motor Homing : verifies that the motor encoder index is visible to the
%       encoder read head
% 2. Motor Encoder CPR: measures the count per revolution (CPR) of the
%       motor encoder
% 3. Hall State: measures the hall states in one revolution and check the
%       sequence
% 4. Motor Friction: Measures the static friction (coulomb friction) of the
%       motor
% 5. Motor Drag: Measured the viscous friction of the motor
% 6. HASS Test: Highly Accelerated Stress Screen Test
%
% Syntax:
%     QIP_MotorTest(), runs the complete test
%
%     QIP_MotorTest(test), runs the test specified by the variable 'test',
%     where -
%         test = 1, homing
%         test = 2, motor cpr
%         test = 3, hall state
%         test = 4, motor friction
%         test = 5, motor drag
%         test = 6, hass testing
%
% Required:
%     "configurationfile_motor.mat" is required to be in the current directory to
%     execute this script. The configuration file carries the motor specific
%     data required to run the test.
%
%     The DMCScripts (.dmc) directory should be in the search path to
%     execute the .dmc scripts on the GALIL controller.
%
% Notes:
%     The script generated two files, one log file with the name starting
%     with "HASS_log_" followed by date and time, and a .mat file which
%     holds the results from the test with file name starting with
%     "HASS_log_" followed by date and time and ending with "results.mat".
%
%     The script is written in a nested function fashion with
%     initialization of the GUI and the controller happening in the main
%     function. Most of the variables are also initialized in the main
%     function.
%
%     The sequence of the test is defined in the first nested function,
%     "run_qip_motortest". Modify this function alone to change the order
%     of the test.
%
%     The functions performing measurements (getcpr_motor,friction_motor,
%     drag_motor) are independent functions returning the variable being
%     measured.

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

%% Read Configuration File Function
%put all the limits up front
    function MOTOR = ReadMotorConfiguration()
        % Set motor parameters and save data in a structure variable
        %
        % Syntax: data= ReadMotorConfiguration()
        %            data: output data structure

       % Set Motor Parameters (MKS SSR Doc 472757)

       % define motor pole pairs
       MOTOR.POLEPAIRS = [6  6  6  6  6  6];

       % define CPR count and delta
       MOTOR.CPR =       [65536  65536  65536  65536  32768  32768];
       MOTOR.CPR_DELTA = [   10     10     10     10     10     10];

       % define parameter for Hall State Check
       MOTOR.CORRECT_HALL_SET = [1 5 4 6 2 3];
       MOTOR.HALL_ANGLE_ERROR = 15; %the zero phase angle error manufacutring spec is 10 degree, 
                                    %so the phase angle limit will be 25 degree
       % define motor Kt
       MOTOR.Kt =  [0.679000    0.523000    0.523000    0.305000    0.360000    0.156000];

       % define motor friction and drag limits
       MOTOR.FRICTION_LIMIT = [0.152000    0.212000    0.2030000        nan    0.0606   0.0379];
       MOTOR.DRAG_LIMIT =     [0.141000    0.214000    0.1365000        nan    0.0508   0.0209];
       MOTOR.DRAG_VAR_LIMIT = [    0.02       0.169       0.169       0.053     0.052   0.0220]*5;
        %5x to ensure passing results for data gathering
      
       % define motor homing speeds
       MOTOR.HOMING_SPEED =   [50000  50000  50000  50000  50000  50000];

    end  % end of function ReadMotorConfiguration
%% Main function: Initialize GUI and variables, connect to GALIL controller
% verify input variables
if(nargin == 0)
    do_test = 1;
end

if(nargin == 1)
    do_test = test;
end

if(nargin > 1)
    error('input to the function can only be a single integer or none')
end

% ask for traveller or kit ID
traveller = getMakoJobId;
% if user pressed cancel exit elegantly
if isempty(traveller)
    return;
end

% In the traveller window, enter "debug" to go to Troubleshooting mode. This will
% enable the next previous buttons.
TROUBLESHOOTING = 0;
if strcmp(traveller,'JobID-debug')
    TROUBLESHOOTING = 1;
end

% Open MAKO GUI
guiHandles = generateMakoGui('QIP Motor Testing',[],['Motor ',traveller],1);
% set close request function
set(guiHandles.figure,'CloseRequestFcn',@closeGUI);
% Function to handle the close function request
    function closeGUI(varargin)
        comm(hDmc,'RS');
        comm(hDmc,'AB');
        comm(hDmc,'MO');
        set(hDmc,'DONE', 1);
        pause(0.1)
        exit_script = 1;
        for i = 1:2
            delete(hDmc);
            pause(0.2)
        end
        closereq
    end

% populate the main button
updateMainButtonInfo(guiHandles,'text','Connecting to controller...pls wait');

% define properties of results window
resultsTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.08,...
    'HorizontalAlignment','left');

% Display 1, in the main UI panel
display1 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'Position',[0.02 0.1 .95 0.8],...
    'String','Select ROBOT Type');

% Display 2, in the extra UI panel
display2 = uicontrol(guiHandles.extraPanel,...
    resultsTextProperties,...
    'Position',[0.1 0.6 0.9 0.35],...
    'String','Connecting to controller...please wait');

% Tests done through to execution of this script and corresponding Test ID
HOME_MOTOR = 1;
GET_MOTOR_CPR = 2;
HALLSTATE_CHECK = 3;
MEASURE_MOTOR_FRICTION = 4;
MEASURE_MOTOR_DRAG = 5;
HASS_TEST = 6;
ANALYZE_RESULTS = 7;


% Check if this is a compiled version and if the mcr folder exists
% adjust the base directory path accordingly.
% NOTE: The compiled version of the script assumes the mcr directory as
% the base directory. For file operations this has to be the base
% directory to which the relative paths are defined.

MCR_DIR = 'QIPScriptsBin/MotorTestQIP_mcr/MotorTest';
if exist(MCR_DIR,'dir')
    basedir = MCR_DIR;
else
    basedir = '.';
end

% FLAG for indicating hass test
performing_hass = 0;
exit_script = 0;

%====================================================
% Initialize variables in the main function so that it can be accessed from
% all the sub function
%====================================================
motor = 0; %variable for motor id
%define motor data as global
MOTORDATA=[];

%RESULTS, initiating variables for storing results
results_file = [];
results.homemotor = [];
results.cpr_measured = [];
results.hall_state= [];
results.friction_measured = [];
results.drag_measured = [];
results.dragVar_measured = [];
results.hass = [];
results.hass.drag.drag_mean=[];
results.hass.drag.drag_pos=[];
results.hass.drag.drag_neg=[];
results.hass.drag.drag_var=[];
results.hass.friction=[];
results.fail = [];

%================================================
%CONNECT TO THE CONTROLLER. LOAD DEFAULT VALUES
%================================================
%connect to controller using galil_mc function
hDmc = galil_mc('172.16.16.101');
comm(hDmc,'RS');  % reset the controller (erase existing dmc program)
% before using the controller, send abort command ('AO') to abort any
% pre-existing execution. Also, turn the motor off ('MO') for safety
comm(hDmc,'AB');
comm(hDmc,'MO');
% get controller serial number
ControllerSerialNum = get(hDmc, 'MG_BN');
if((isnan(ControllerSerialNum))||(ControllerSerialNum == -666.666))
    set(display2,'String',['Controller ERROR. Power cycle controller.' ,...
        num2str(ControllerSerialNum)]);
    % disconnect from GALIL controller by running GALILDisconnect() function
    delete(hDmc);
    error('Controller fault. Power cycle controller')
end

% set controller parameters and PID
set_motor_defaults(hDmc);

set(display2,'String', ['Connected to Controller: ',...
    num2str(ControllerSerialNum)]);

%% Create text GUI to show controller serial number and ROBOT Type
%  type in the Main UI Panel
handle_txtSN= uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'fontsize',0.45,...
    'Position',[0.02 0.0 0.3 0.05]);

%% Activate the main button to start motor testing
updateMainButtonInfo(guiHandles, 'Select ROBOT Type');

%get Amp Gain from the amplifier
AG = get(hDmc, 'AGX');
%set the corresponding gain
if (AG == 1)
    amp_gain = 0.7; %Nm/Amps
elseif (AG == 2)
    amp_gain = 1.0; %Nm/Amps
else
    set(display2,'String',['Amp gain not set correct. AG = ', num2str(AG)])
    delete(hDmc);
    error('Amplifier Gain too low or not set correct');
end

%% Create the listbox for selecting ROBOT Type
handle_lstApp= uicontrol(guiHandles.uiPanel,'style','listbox',...
                'units','normalized','position',[0.15 0.5 0.7 0.2],...
                'string',{...
                'RIO 2.2', ...
				'RIO 3.0'},...
                'fontunits','normalized','fontsize',0.26, ...
                'value',2);
handle_btnApp= uicontrol(guiHandles.uiPanel,'style','pushbutton',...
                'units','normalized','position',[0.4 0.38 0.2 0.1],...
                'string','OK','fontunits','normalized','fontsize',0.3,...
                'callback',@click_btnApp);
            
%% Create the button group for selecting motor.
handle_buttongroup = uibuttongroup(guiHandles.uiPanel,...
    'visible','off','Position',[0.32 0.05 .25 0.8]);
% Create radio button to select motor
yRange = 80;
ypos = 10;

for repeat = 1:6
    uicontrol('Style','Radio','String',[' ' num2str(repeat)],...
            'pos',[80, ypos, 50, 30],'parent',handle_buttongroup,'HandleVisibility','on',...
            'FontUnits','normalized','FontSize',0.8);
    ypos = ypos + yRange;
end


%% Setup ROBOT Type Callback
    function click_btnApp(hobj,evdata) %#ok<INUSD>
        apptype = get(handle_lstApp,'value');
				
        MOTORDATA = ReadMotorConfiguration();
       
        % hide the type selection UIs
        set(handle_lstApp,'visible','off');
        set(handle_btnApp,'visible','off');
        set(display1,'string','Select Motor');
        
        % show robot type and GALIL controller serial number
        appstr = get(handle_lstApp,'string');
        set(handle_txtSN,...
            'String',{appstr{apptype},...
                      sprintf('GALIL Controller SN: %d',ControllerSerialNum)},...
                      'backgroundcolor','w');
        
        % Initialize some button group properties.
        set(handle_buttongroup,'SelectionChangeFcn',@selcbk);
        set(handle_buttongroup,'SelectedObject',[]);  % No selection
        set(handle_buttongroup,'Visible','on');
    end

%% Setup Motor number (1 to 6) Callback 
    function selcbk(source,eventdata) %#ok<INUSL>
        % refer matlab help doc on 'uibuttongroup' for more info
        motor = str2double(get(eventdata.NewValue,'string'));
        %======================================
        % FILE NAME FOR RESULTS, with motor tag
        %======================================
        dataFileName=['MOTOR-',...
            num2str(motor),'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        results_file = fullfile(guiHandles.reportsDir,dataFileName);
        
        % Activate the main button to start motor testing
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Click here to begin motor testing',...
            @run_qip_motortest);
        
    end

%% Run QIP - This is the MAIN function.
% This function controls the sequence of the test.
    function run_qip_motortest(hObject, eventdata) %#ok<INUSD>
        
        % turn off the radio button group
        if exist('handle_buttongroup','var')
            set(handle_buttongroup,'Visible','off');
            delete(handle_buttongroup)
            clear('handle_buttongroup')
        end
        
        % update the main result window
        set(display1,'String', ['Testing MOTOR ', num2str(motor)]);
        % save the motor id
        results.motor = motor;
        
        % button for moving to Previous test (one test back)
        if(do_test > 1)
            if TROUBLESHOOTING
                % generate the test navigation button
                uicontrol(guiHandles.uiPanel,...
                    'Style','pushbutton',...
                    'Units','normalized',...
                    'Position',[0.7 0.10 0.13 0.1],...
                    'String','< Previous',...
                    'Callback',@previous_test);
            end
        end
        
        % button for moving one test forward. Just calling the main test
        % function will increment the test.
        if(do_test < 10)
            if TROUBLESHOOTING
                uicontrol(guiHandles.uiPanel,...
                    'Style','pushbutton',...
                    'Units','normalized',...
                    'Position',[0.85 0.10 0.13 0.1],...
                    'String','Next >',...
                    'Callback',@run_qip_motortest);
            end
        end
        
        set(guiHandles.mainButtonInfo,'enable','on');
        switch do_test %test ID
            case HOME_MOTOR %Home motor (Test 1)
                updateMainButtonInfo(guiHandles, 'Click here to Home Motor',...
                    @home_motor);
                
                % increment test id by 1
                do_test = do_test+1;
            case GET_MOTOR_CPR %Get motor CPR (Test 2)
                updateMainButtonInfo(guiHandles,'Click here to Get Motor CPR',...
                    @getcpr_motor);
                
                % increment test id by 1
                do_test = do_test+1;
            case HALLSTATE_CHECK %Check the state of the Hall sensor (Test 3)
                updateMainButtonInfo(guiHandles,'Click here to check Hall Sensor State',...
                    @get_hall_states);
                
                % increment test id by 1
                do_test = do_test+1;
            case MEASURE_MOTOR_FRICTION %Measure Motor Friction (Test 4)
                updateMainButtonInfo(guiHandles,'Click here to find Motor Friction',...
                    @friction_motor);
                
                % increment test id by 1
                do_test = do_test+1;
            case MEASURE_MOTOR_DRAG %Measure Motor Drag (Test 5)
                updateMainButtonInfo(guiHandles,'Click here to Measure Motor Drag',...
                    @drag_motor);
                
                % increment test id by 1
                do_test = do_test+1;
            case HASS_TEST %HASS Test (Test 6)
                updateMainButtonInfo(guiHandles,'Click here to Start HASS',...
                    @hass_motor_start);
                
                % increment test id by 1
                do_test = do_test+1;
            case ANALYZE_RESULTS %Analyze Results (Test 7)
                updateMainButtonInfo(guiHandles,'Click here to Display Results',...
                    @analyze_results);
        end
    end
%% Navigation functions, Next and Previous
    function previous_test(hObject, eventdata) %#ok<INUSD>
        % this function takes the test sequence one step back
        % decrement the test count by 1
        if do_test > 1
            do_test = do_test - 2;
        end
        % make sure that the min value of do_test is 1.
        if do_test < 1
            do_test = 1;
        end
        %go back to the main function
        run_qip_motortest;
    end
%% Home Motor (Test 1)
%homing checks whether the motor encoder index is visible to the encoder
%read head.
    function home_motor(hObject, eventdata, handles) %#ok<INUSD>
        % change the display on the main button
        updateMainButtonInfo(guiHandles,'Homing motor encoder...');
        set(guiHandles.mainButtonInfo,'enable','off');
        
        %use homemotor(HOMING_SPEED) function to home the motor
        [done,currentposition] = homemotor(hDmc, MOTORDATA.HOMING_SPEED(motor)); %#ok<NASGU>
        
        %run home motor again if current position is close to confirm/settle on homed location
        if ~done &&  abs(currentposition) < 25
        [done,currentposition] = homemotor(hDmc,MOTORDATA.HOMING_SPEED(motor));
        end
        
        % if homing successful...
        if(done == 1)
            % display result
            set(display2, 'String','Homing DONE');
            % add results to results structure
            results.homemotor = [results.homemotor; 1];
        else % if homing failed
            results.homemotor = [results.homemotor; 0];
            if TROUBLESHOOTING
                set(display2,'String','Motor Homing Failed');
            else
                presentMakoResults(guiHandles,'FAILURE','Motor Homing Failed');
                return
            end
        end
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_motortest; end
    end

%% Get Motor Encoder CPR (Count per Revolution) (Test 2)
%verifies all the counts are visible
    function [cpr,fail] = getcpr_motor(hObject, eventdata, handles) %#ok<INUSD>
        % start with the assumption that the test fails
        fail = 1;
        % change display on main button
        updateMainButtonInfo(guiHandles,'Finding motor encoder CPR');
        set(guiHandles.mainButtonInfo,'enable','off');
        
        latchpos(1:2)=0; %variable for storing latch position
        
        downloadfile(hDmc, fullfile(basedir,'dmcfiles','get_cpr.dmc')); %download dmc file to controller
        pause(0.1)
        set(hDmc, 'SPEED', 50000); %set speed
        
        for n = 1:2
            comm(hDmc, 'XQ');
            STATUS = 0;
            while ( STATUS == 0)
                try
                    STATUS = get(hDmc, 'DONE');
                    pause(0.1);
                catch ME
                    str= sprintf('%s', ME.identifier);
                    errordlg({str,'Cancelled out of test or Controller not reachable'})
                    return
                end
            end
            latchpos(n) = get(hDmc, 'RLA');  %report latch position
            pause(0.1);
        end
        cpr = latchpos(2)-latchpos(1);
        
        cpr_actual= MOTORDATA.CPR(motor);
        cpr_delta= MOTORDATA.CPR_DELTA(motor);
        
        % check pass/fail
        if ~TROUBLESHOOTING
            if (abs(cpr_actual-cpr) > cpr_delta)
                presentMakoResults(guiHandles,'FAILURE',{'CPR check failed',...
                    ['Difference ', num2str(cpr_actual-cpr),' Counts'],...
                    'Limit 10 counts'});
                comm(hDmc, 'AB');
                comm(hDmc, 'MO');
                return
            end
        end
        
        %clear memory
        comm(hDmc, 'DA *,*[]');
        
        %display results
        set(display2,'String',...
            {['Motor encoder CPR, measured: ',num2str(cpr)];...
            ['Actual CPR: ',num2str(cpr_actual)];...
            ['CPR Delta: ',num2str(cpr-cpr_actual)];...
            ['Acceptable CPR Delta: ',num2str(cpr_delta)]});
        
        
        % add the result to results structure
        results.cpr_measured = [results.cpr_measured; cpr];
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_motortest; end
    end

%% Hall State (Test 3)
% measures the hall states in one revolution and check the sequence
    function hall_state= get_hall_states(hObject, eventdata, handles) %#ok<INUSD>
        % update Main button info
        updateMainButtonInfo(guiHandles,'Checking Hall Sensor State');   
        set(guiHandles.mainButtonInfo,'enable','off');
        
        %get parameters
        speedMotor = 2000;
        no_motor_pole_pairs= MOTORDATA.POLEPAIRS(motor);
        %maximal number of hall state changes
        %the first hall angle is not a complete hall angle,
        %this calculation ensures a full turn on the motor,
        MaxNoHallChange = 6*no_motor_pole_pairs+2;  
        
        %download the dcm script to the galil controller
        downloadfile(hDmc, fullfile(basedir, 'dmcfiles','getHALL.dmc'));
        
        % set the jog speed
        set(hDmc, 'SPEED', abs(speedMotor));
        set(hDmc, 'SIZE', MaxNoHallChange);
        
        pause(0.01);
        % execute the dmc script by issuing 'XQ' command
        comm(hDmc, 'XQ');
        
        %wait for some time
        pause(5);
        
        %the check should have been completed at this time, double check
        spd = get(hDmc, 'TVA');
        while(abs(spd) > 100)
            pause(1);
            spd = get(hDmc, 'TVA');
        end
        
        %read the hall sequence
        HallState= get(hDmc, 'QU HALL[]');
        MotorCnt = get(hDmc, 'QU ANGLE[]');
        
        %set motor off
        comm(hDmc, 'MO');
        %clear memory
        comm(hDmc, 'DA *,*[]');
        
        %remove the unwanted elements
        HallState(end-1:end)=[];
        MotorCnt(1)=[];
        %calculate hall angles
        hallAngle=diff(MotorCnt)/MOTORDATA.CPR(motor)*360*no_motor_pole_pairs;
        maxHallAngleError=max(abs(abs(hallAngle)-60));
        
        % Rearrange the hall states so it starts at 1
        ind1= find(HallState==1,1);  % find first index when hall state is 1
        NewHallState= [HallState(ind1:end) ; HallState(1:ind1-1)];
        
        % display the sample hall state sequence
        correctSet= MOTORDATA.CORRECT_HALL_SET;  % Correct hall state sequence for the testing rotaiton direction
        totalRotation= (MotorCnt(end)-MotorCnt(1))/results.cpr_measured(end)*360; 
        
        str= sprintf('Measured Hall State is:');
        str1= sprintf('%2d',NewHallState);
        str2= sprintf('Nominal Hall State Sequence is:%4d%4d%4d%4d%4d%4d',...
            correctSet);
        str3= sprintf('\nMax hall angle error(deg): %3.1f (Limit: %3.1f)',...
            maxHallAngleError,MOTORDATA.HALL_ANGLE_ERROR);        
        str4= sprintf('Total Rotation: %d count (%6.2f deg)',...
            (MotorCnt(end)-MotorCnt(1)),totalRotation);
        
        %-------------------------
        % Check for Hall state
        hallfail= 0; % hall check fail count
        failstr='Hall Check Successful';
        %check sequence
        for i=1:length(NewHallState)
            iCorrect= rem(i,6); % corresponding index for correct hall states sets
            if iCorrect==0, iCorrect=6; end
            if NewHallState(i)~= correctSet(iCorrect)
                hallfail= 1;
                failstr= 'Hall Sequence is Incorrect';
                break;
            end
        end
        
        %check hall angle        
        if maxHallAngleError>MOTORDATA.HALL_ANGLE_ERROR
            hallfail= 1;
            failstr= 'Hall Angle is too large';
        end
        
        % display result
        set(display2,'String',{str,str1,str2,str3,str4,failstr});            
            
      
        % return hall state
        hall_state.new_state= NewHallState;
        hall_state.raw_state= HallState;
        hall_state.count_transition= MotorCnt;
        hall_state.total_rotation= totalRotation;
        hall_state.test_failed= hallfail;
        hall_state.hall_angle=hallAngle;
        
        % save results
        results.hall_state= [results.hall_state; hall_state];
        
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_motortest; end
    end

%%  Motor Friction (Test 4)
    function friction_average = friction_motor(hObject, eventdata, handles) %#ok<INUSD>
        %change the display on the main button
        
        updateMainButtonInfo(guiHandles,'Measuring motor friction');
        set(guiHandles.mainButtonInfo,'enable','off');
        
        friction_average = [];
        
        %take three samples
        for samples = 1:3
            % move to a random location
            comm(hDmc, 'SHA');
            set(hDmc, 'JGA', 20000);
            comm(hDmc, 'BGA');
            pause(1);
            comm(hDmc, 'AB');
            pause(0.1);
            
            %download breakaway.dmc to the controller
            downloadfile(hDmc, fullfile(basedir,'dmcfiles','breakaway.dmc'));
            pause(0.2)
            breakawaycrnt = [];
            % take 4 measurement sample per location, the first sample is
            % ignored because it is found to be nosiy.
            for times = 1:3
                %set flag to zero. the flag gets set to 1 when motion is detected
                set(hDmc, 'DONE', 0);
                comm(hDmc, 'XQ');
                
                % update main button info
                updateMainButtonInfo(guiHandles,['Finding motor friction, position ',num2str(samples),...
                    ', run ', num2str(times)]);
                
                while (get(hDmc, 'DONE') ~= 1)
                    %wait for motion
                    pause(0.1)
                end
                breakawaycrnt = [breakawaycrnt; get(hDmc, 'OFFSET')]; %#ok<AGROW>
            end
            %clear memory
            comm(hDmc, 'DA *,*[]');
            comm(hDmc, 'RS'); % reset motor
            %restore default gains and limits
            set_motor_defaults(hDmc);
            
            %breakaway current in Amps
            %multiplied by the current gain on amp
            %load the configuration file with motor parameters, and get Kt from
            %the configuration file
            Kt= MOTORDATA.Kt(motor);
            
            % first measurement is ignored. First measurement includes the
            % slack on the motor.
            meanbreakaway = mean(breakawaycrnt(2:end))*amp_gain*Kt;
            
            set(display2, 'String',...
                {['Mean Friction: ',num2str(meanbreakaway),' Nm'],...
                ['Allowable Friction: ',num2str(MOTORDATA.FRICTION_LIMIT(motor)),' Nm']});
            friction_average = [friction_average, meanbreakaway]; %#ok<AGROW>
            
        end
        %display results
        friction_average = mean(friction_average);
        set(display2, 'String',...
            {['Mean Friction: ',num2str(friction_average),' Nm'],...
            ['Allowable Friction: ',num2str(MOTORDATA.FRICTION_LIMIT(motor)),' Nm']});
        
        %add the results to results structure
        results.friction_measured = [results.friction_measured; friction_average];
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_motortest; end
    end

%% Motor Drag (Test 5)
    function [meandrag, motordrag_pos, motordrag_neg,dragvar] = drag_motor(hObject, eventdata, handles) %#ok<INUSD>
        % change display on the main button
        updateMainButtonInfo(guiHandles, 'Measuring Drag in positive direction');
        set(guiHandles.mainButtonInfo,'enable','off');
        
        %load the configuration file with motor parameters, and get Kt from
        %the configuration file

        Kt= MOTORDATA.Kt(motor);
        %positive drag
        motordrag_pos = get_motordrag(hDmc,1,5000,basedir)*amp_gain*Kt;
        
        updateMainButtonInfo(guiHandles, 'Measuring Drag in negative direction');
        
        %negative drag
        motordrag_neg = get_motordrag(hDmc,-1,5000,basedir)*amp_gain*Kt;
        
        meandrag = (abs(mean(motordrag_pos)) + abs(mean(motordrag_neg)))/2;
        dragvar=max(std(motordrag_pos),std(motordrag_neg));
        
        %display results
        set(display2, 'String',...
            {['Drag Positive: ',num2str(mean(motordrag_pos))];...
            ['Drag Negative: ',num2str(mean(motordrag_neg))];...
            ['Mean Motor Drag, Measured: ',num2str(meandrag)];...
            ['Allowable Motor Drag: ',num2str(MOTORDATA.DRAG_LIMIT(motor))]});
        
        % add the result to results structure
        results.drag_measured = [results.drag_measured; meandrag];
        results.dragVar_measured = [results.dragVar_measured; dragvar];
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_motortest; end
    end

%% HASS Test (Test 6)
    function hass_motor_start(hObject, eventdata, handles) %#ok<INUSD>
        
        % Set up Pause button
        pausetest = false;
        pauseButtonHandle = uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'Position',[0.78 0.25 0.2 0.2],...
            'FontUnit','normalized',...
            'FontSize',0.2,...
            'String','Pause',...
            'BackgroundColor',rand(1,3), ... %[34 139 34]/255,...
            'Callback',@pauseHASS...
            );
        function pauseHASS(varargin)
            pausetest = true;
            set(pauseButtonHandle,...
                'String','Resume',...
                'BackgroundColor',rand(1,3), ... %[255 140 0]/255,...
                'Callback',@resumeHASS);
        end
        function resumeHASS(varargin)
            pausetest = false;
            set(pauseButtonHandle,...
                'String','Pause',...
                'BackgroundColor',rand(1,3), ... %[34 139 34]/255,...
                'Callback',@pauseHASS);     
        end
        
        % Set HASS flag to 1
        performing_hass = 1;
        %record hass start time
        results.hass.time.start = datestr(now);
        %handle for plot
        plothandle = axes('parent',guiHandles.extraPanel,'Position',[0.1 0.1 0.8 0.5]);
        grid(plothandle,'on');
        ylabel(plothandle,'Frictional Torque (Nm)');
        xlabel(plothandle,'Cycle');
        
        updateMainButtonInfo(guiHandles,'STOP HASS',@hass_motor_stop);
        
        num_of_testcycles = 24;
        num_of_breakincycles = 10;
        
        STEPSIZE = [3818, 98304, 2000];
        COUNT = [180, 73, 1000];
        SPEED = [10000000, 10000000, 10000000];
        WAIT = [20,100,0];
        
        % Get pass/fail limit for the result plot

        friction_limit = MOTORDATA.FRICTION_LIMIT(motor);
        drag_limit = MOTORDATA.DRAG_LIMIT(motor);
        
        %Break-in Cycles
        for cycle = 1:num_of_breakincycles
            
            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                updateMainButtonInfo(guiHandles, ['Test Paused at Break-in Cycle ',num2str(cycle)]);
            end
            
            % Download the dmc script for step function to controller
            downloadfile(hDmc, fullfile(basedir,...
                'dmcfiles','step_orig.dmc'));
            pause(0.25)
            
            % update main display
            updateMainButtonInfo(guiHandles, 'Performing Pre-HASS Break-in');
            set(guiHandles.mainButtonInfo,'enable','off');
            
            % step input
            for run = 1:length(STEPSIZE)
                set(hDmc, 'STEPSIZE', STEPSIZE(run));
                set(hDmc, 'SPEED', SPEED(run));
                set(hDmc, 'COUNT', COUNT(run));
                set(hDmc, 'WAIT', WAIT(run));
                % wait for a sec
                pause(0.1)
                % Execute
                set(hDmc, 'DONESTEP', 0);
                comm(hDmc, 'XQ#STEP,0');
                
                % Message to GUI
                set(display1,'String','Step function started');
                
                STATUS = 0;
                while (STATUS == 0)
                    try
                        pause(0.25)
                        STATUS = get(hDmc, 'DONE');
                        stepcount = get(hDmc, 'N');
                        set(display1,'String',['Cycle ', num2str(cycle), ' of ',...
                            num2str(num_of_breakincycles),'. Test ',num2str(run)...
                            , '. Count ',num2str(stepcount), ' of ', num2str(COUNT(run))])
                    catch ME
                        str= sprintf('%s', ME.identifier);
                        if ~exit_script
                        errordlg({str,'Not able to talk to the Controller'})
                        end
                        return
                    end
                end
            end %end of test
            
            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                updateMainButtonInfo(guiHandles,['Test Paused at  Break-inCycle ',num2str(cycle)]);
            end
        end            

        
        %Test Cycles
        result = [];
        for cycle = 1:num_of_testcycles
            
            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                updateMainButtonInfo(guiHandles, ['Test Paused at Cycle ',num2str(cycle)]);
            end
            
            % Download the dmc script for step function to controller
            downloadfile(hDmc, fullfile(basedir,...
                'dmcfiles','step_orig.dmc'));
            pause(0.25)
            
            % update main display
            updateMainButtonInfo(guiHandles, 'Performing HASS Test');
            set(guiHandles.mainButtonInfo,'enable','off');
            
            % step input
            for run = 1:length(STEPSIZE)
                set(hDmc, 'STEPSIZE', STEPSIZE(run));
                set(hDmc, 'SPEED', SPEED(run));
                set(hDmc, 'COUNT', COUNT(run));
                set(hDmc, 'WAIT', WAIT(run));
                % wait for a sec
                pause(0.1)
                % Execute
                set(hDmc, 'DONESTEP', 0);
                comm(hDmc, 'XQ#STEP,0');
                
                % Message to GUI
                set(display1,'String','Step function started');
                
                STATUS = 0;
                while (STATUS == 0)
                    try
                        pause(0.25)
                        STATUS = get(hDmc, 'DONE');
                        stepcount = get(hDmc, 'N');
                        set(display1,'String',['Cycle ', num2str(cycle), ' of ',...
                            num2str(num_of_testcycles),'. Test ',num2str(run)...
                            , '. Count ',num2str(stepcount), ' of ', num2str(COUNT(run))])
                    catch ME
                        str= sprintf('%s', ME.identifier);
                        if ~exit_script
                        errordlg({str,'Not able to talk to the Controller'})
                        end
                        return
                    end
                end
            end %end of test
            
            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                updateMainButtonInfo(guiHandles,['Test Paused at Cycle ',num2str(cycle)]);
            end
            
            % motor encoder cpr
            cpr = getcpr_motor();
            % hall state check
            hall_state= get_hall_states();
            % terminate program if hall state check fails (empty state)
            if isempty(hall_state)
                return;
            end
            % measure columb friction,
            %only do friction check every eight cycle
            if(cycle==1 || mod(cycle,8)==0)
                breakaway = friction_motor();
                results.hass.friction=[results.hass.friction,breakaway];
            end
            
            
            results.hass.friction=[results.hass.friction,breakaway];
            
            % measure motor drag
            [meandrag,drag_pos,drag_neg,drag_var] = drag_motor();
            
            % log measurements
            result = [result;cycle, cpr, breakaway, meandrag]; %#ok<AGROW>
            
            results.hass.drag.drag_pos=[results.hass.drag.drag_pos,drag_pos];
            results.hass.drag.drag_neg=[results.hass.drag.drag_neg,drag_neg];
            results.hass.drag.drag_var=[results.hass.drag.drag_var,drag_var];
            results.hass.drag.drag_mean=[results.hass.drag.drag_mean,meandrag];
            
            % Plot results
            set(display2,'String','HASS Result')
            
            cla(plothandle);
            
            %only plot friction the first cycle and every eighth cycle
            if(cycle==1)
                plot(plothandle,result(:,1),result(:,3),'bo-',result(:,1),result(:,4),'g^-');
            else
                
                plot(plothandle,result([1,8:8:end],1),result([1,8:8:end],3),'bo-',result(:,1),result(:,4),'g^-');
            end
                    
            hold(plothandle,'on')
            
            xlimits= get(plothandle,'xlim');
            
            hFric= plot(plothandle, xlimits,[friction_limit friction_limit]); % draw friction limit line
            set(hFric,'linewidth',3, 'color','b', 'linestyle',':');
            hold(plothandle,'on');
            
            hDrag= plot(plothandle, xlimits,[drag_limit drag_limit]); % draw drag limit line
            set(hDrag,'linewidth',3, 'color','g', 'linestyle', ':');
            legend(plothandle,'friction','drag','friction limit','drag limit','Location','bestoutside');
            
            % add labels on x and y axes
            xlabel(plothandle,'Cycle');
            ylabel(plothandle,'Frictional Torque (Nm)');
        end %end of cycle
        
        
        % Once the hass test is done, set back the hass flag to 0
        performing_hass = 0;
        
        %record end time and save to results
        results.hass.time.end = datestr(now);
        
        % Delete pause button
            delete(pauseButtonHandle);
        
        % Go back the the main function
        run_qip_motortest;
    end

%% Analyze and Display Results
    function analyze_results(hObject, eventdata, handles) %#ok<INUSD,INUSD>
        
        cpr_actual = MOTORDATA.CPR(motor);
        friction_limit = MOTORDATA.FRICTION_LIMIT(motor);
        drag_limit = MOTORDATA.DRAG_LIMIT(motor);
        drag_var_limit = MOTORDATA.DRAG_VAR_LIMIT(motor);
        cpr_delta = MOTORDATA.CPR_DELTA(motor);
        
        % Check for cpr
        fail.cprcheck = [0 0];
        for n = 1:size(results.cpr_measured,1)
            if(abs(cpr_actual-results.cpr_measured(n))>cpr_delta) && n == 1 % Pre-HASS
                fail.cprcheck(1) = fail.cprcheck(1) + 1;
            elseif (abs(cpr_actual-results.cpr_measured(n))>cpr_delta) % HASS
                fail.cprcheck(2) = fail.cprcheck(2) + 1;
            end
        end
        
        % Check for Hall state
        fail.hallcheck = [0 0];
        for n = 1:length(results.hall_state)  % for each cycle
            hallStates= results.hall_state(n).new_state;
            correctSet= [1 5 4 6 2 3];  % Correct hall state sequence for the testing rotaiton direction
            % Only one set of sequence to ensure correct UVW wiring
            % Fixed Bug # 3536, item 3
            hallfail= 0; % hall check fail count
            for i=1:length(hallStates)
                iCorrect= rem(i,6); % corresponding index for correct hall states sets
                if iCorrect==0, iCorrect=6; end
                if hallStates(i)~= correctSet(iCorrect)
                    hallfail= 1;
                    break;
                end
            end
            
            if n == 1
                fail.hallcheck(1) = fail.hallcheck(1) + hallfail;
            else
                fail.hallcheck(2) = fail.hallcheck(2) + hallfail;
            end
            
        end
        
        % Check for friction
        fail.friction = [0 0];
        for n = 1:length(results.friction_measured)
            if(results.friction_measured(n) > friction_limit) && n == 1 % Pre-HASS
                fail.friction(1) = fail.friction(1) + 1;
            elseif (results.friction_measured(n) > friction_limit) % HASS
                fail.friction(2) = fail.friction(2) + 1;
            end
        end
        
        % Check for drag
        fail.drag = [0 0];
        for n = 1:length(results.drag_measured )
            if(results.drag_measured (n) > drag_limit) && n == 1 % Pre-HASS
                fail.drag(1) = fail.drag(1) + 1;
            elseif (results.drag_measured(n) > drag_limit) % HASS
                fail.drag(2) = fail.drag(2) + 1;
            end
        end
        
        fail.dragVar = [0 0];
        for n = 1:length(results.dragVar_measured)
            if(results.dragVar_measured(n) > drag_var_limit) && n == 1 % Pre-HASS
                fail.dragVar(1) = fail.dragVar(1) + 1;
            elseif (results.dragVar_measured(n) > drag_var_limit) % HASS
                fail.dragVar(2) = fail.dragVar(2) + 1;
            end
        end
        
        save (results_file,'results','fail')
        results.fail = fail;
        
        % DISPLAY RESULTS
        if(fail.cprcheck == 0)
            result_cprcheck = {'CPR Check PASS'};
        else
            result_cprcheck = {sprintf('CPR Check FAIL: %d Pre-HASS, %d HASS instance(s)',fail.cprcheck(1),fail.cprcheck(2))};
        end
        if(fail.hallcheck == 0)
            result_hallstate = {'Hall State Test PASS'};
        else
            result_hallstate = {sprintf('Hall State Test FAIL: %d Pre-HASS, d% HASS instance(s)',fail.hallcheck(1),fail.hallcheck(2))};
        end
        if(fail.friction == 0)
            result_friction = {'Coulomb Friction Test PASS'};
        else
            result_friction = {sprintf('Coulomb Friction Test FAIL: %d Pre-HASS, %d HASS instance(s)',fail.friction(1),fail.friction(2))};
        end
        if(fail.drag == 0)
            result_drag = {'Motor Drag Test PASS'};
        else
            result_drag = {sprintf('Motor Drag Test FAIL: %d Pre-HASS, %d HASS instance(s)',fail.drag(1),fail.drag(2))};
        end
        
        if(fail.dragVar == 0)
            result_dragVar = {'Motor Drag Variance Test PASS'};
        else
            result_dragVar = {sprintf('Motor Drag Variance Test FAIL: %d Pre-HASS, %d HASS instance(s)',fail.dragVar(1),fail.dragVar(2))};
        end
        
        result = [date;...
            ['Motor : ',num2str(motor)];...
            result_cprcheck;...
            result_hallstate;...
            result_friction;...
            result_drag;...
            result_dragVar];
        
        % display results in display1
        set(display1,'String', result);
        
        % display results in Main Button
        if all ([fail.cprcheck,fail.friction,fail.drag,fail.hallcheck fail.dragVar] == 0)
            presentMakoResults(guiHandles,'SUCCESS')
        else
            presentMakoResults(guiHandles,'FAILURE')
        end
    end

%% Set motor defaults
    function set_motor_defaults(galilObj)
        
        % set controller parameters (General)
        set(galilObj, 'ER', 1000); % error limit 1000 counts
        set(galilObj, 'TL', 9); %torque limit
        % PID Transfer function (P+sD+I/s) where
        %    P= KP;  D= T*KD; I= KI/2/T;   T: Sampling Period
        set(galilObj, 'KP', 12.0);
        set(galilObj, 'KD', 120.0);
        set(galilObj, 'KI', .2);
        set(galilObj, 'SP', 10000000); %max speed, encoder counts per sec
        set(galilObj, 'AC', 67107839); % acceleration, 67107840 is the max value
        set(galilObj, 'DC', 67107839); % deceleration, 67107840 is the max value
        
        % set controller parameters (AXIS A)
        set(galilObj, 'ERA', 1000); % error limit 1000 counts
        set(galilObj, 'TLA', 9); %torque limit
        % PID Transfer function (P+sD+I/s) where
        %    P= KP;  D= T*KD; I= KI/2/T;   T: Sampling Period
        set(galilObj, 'KPA', 12.0);
        set(galilObj, 'KDA', 120.0);
        set(galilObj, 'KIA', .2);
        set(galilObj, 'SPA', 10000000); %max speed, encoder counts per sec
        set(galilObj, 'ACA', 67107839); % acceleration, 67107840 is the max value
        set(galilObj, 'DCA', 67107839); % deceleration, 67107840 is the max value

    end
%% End of test
end %/end for main function

% --------- END OF FILE ----------