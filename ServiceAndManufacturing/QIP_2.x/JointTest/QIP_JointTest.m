function QIP_JointTest(do_test)
% QIP_JointTest, runs the Joint level QIP for TGS 2.x or 3.0 joints using the
% GALIL Controller.
%
% Syntax:
%     QIP_JointTest(), runs the complete test
%
%     QIP_JointTest(test), runs the test specified by the variable 'test',
%     where -
%             HOME_MOTOR = 1;
%             GET_MOTOR_CPR = 2;
%             HOME_JOINT = 3;
%             GET_JOINT_LIMITS = 4;
%             GET_GEAR_RATIO = 5;
%             GET_HALL_STATES= 6;
%             BRAKE_TEST= 7;
%             MEASURE_JOINT_FRICTION = 8;
%             MEASURE_JOINT_DRAG = 9;
%             MEASURE_CABLE_TENSION = 10;
%             HASS_TEST = 11;
%             ANALYZE_RESULTS = 12;
%
% Required:
%     "configurationfile_joint.mat" is required to be in the current directory to
%     execute this script. The configuration file carries the joint specific
%     data required to run the test.
%
%     The DMCScripts (.dmc) directory should be in the search path to
%     execute the .dmc scripts on the GALIL controller.
%
% Notes:
%     The script generated two files, one log file with the name starting
%     with "HASS_log_" followed by date and time, and a .mat file which
%     holds the results from the test with file name starting with
%     "HASS_log_" followed by date and time and ending with "joint_results.mat".
%
%     The script is written in a nested function fashion with
%     initialization of the GUI and the controller done in the main
%     function. Most of the variables are also initialized in the main
%     function.
%
%     The sequence of the test is defined in the first nested function,
%     "run_qip_jointtest". Modify this function alone to change the order
%     of the test.
%
%     The functions performing measurements (getcpr_motor,friction_motor,
%     drag_motor) are independent functions returning the variable being
%     measured.

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

%% Main function: Initialize GUI and variables, connect to GALIL controller

if(nargin == 0)
    do_test = 1;
elseif(nargin > 1)
    error('input to the function can only be a single integer or none')
end

% ask for traveller or kit ID
traveller = getMakoJobId;
% if user pressed cancel exit elegantly
if isempty(traveller)
    return;
end

% In the traveller window, enter "debug" to go to Troubleshooting mode. This will
% enable the navigation buttons (the "next" and "previous" buttons).
TROUBLESHOOTING = 0;
if strcmp(traveller,'JobID-debug')
TROUBLESHOOTING = 1;
end

% Generate MAKO GUIs
global guiHandles
guiHandles = generateMakoGui('QIP Joint Testing',[],['Joint ',traveller],1);
% set close request function
set(guiHandles.figure,'CloseRequestFcn',@closeGUI);

% populate the main button
updateMainButtonInfo(guiHandles,'text','Connecting to controller...please wait');

% define properties of results window
resultsTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.1,...
    'HorizontalAlignment','left');

% Display 1, in the main UI panel
display1 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'Position',[0.02 0.1 .95 0.8],...
    'String','Select ROBOT Type');

% Display 2, in the extra UI panel
DEFAULT_FONT_SIZE= 0.15;
display2 = uicontrol(guiHandles.extraPanel,...
    resultsTextProperties,...
    'FontSize',DEFAULT_FONT_SIZE,...
    'Position',[0.05 0.82 0.92 0.17],...
    'String','Connecting to controller...please wait');

%====================================================
% Initialize variables in the main function so that it can be accessed from
% all the sub function
%====================================================
joint = 0; %variable for motor id

%RESULTS, initiating variables for storing results
MOTORDATA=[];
JOINTDATA=[];
results_file = [];
results.homemotor = [];
results.cpr_measured = [];
results.homejoint = [];
results.jointlimits = [];
results.gratio = [];
results.hall_state= [];
%results.brake_data= [];
results.friction_measured = [];
results.drag_measured = [];
results.transmission = [];
results.transmissiondata = [];
results.hass = [];
results.fail = [];


% Tests done through to execution of this script and corresponding Test ID
HOME_MOTOR = 1;
GET_MOTOR_CPR = 2;
HOME_JOINT = 3;
GET_JOINT_LIMITS = 4;
GET_GEAR_RATIO = 5;
GET_HALL_STATES= 6;
BRAKE_TEST= 7;
MEASURE_JOINT_FRICTION = 8;
MEASURE_JOINT_DRAG = 9;
MEASURE_JOINT_TRANSMISSION = 10;
HASS_TEST = 11;
ANALYZE_RESULTS = 12;


% Check if this is a compiled version and if the mcr folder exists
% adjust the base directory path accordingly. 
% NOTE: The compiled version of the script assumes the mcr directory as
% the base directory. For file operations this has to be the base
% directory to which the relative paths are defined.
% NOTE: When bulding solo in Matlab, the basedir is JointTestQIP_mcr
% NOTE: When bulding the real deal, the basedir is QIPScriptsBin/JointTestQIP_mcr/JointTest

MCR_DIR = 'QIPScriptsBin/JointTestQIP_mcr/JointTest';
if exist(MCR_DIR,'dir')
    basedir = MCR_DIR;
else
    basedir = '.';
end

% FLAG for indicating hass test
performing_hass = 0;

%================================================
%CONNECT TO THE CONTROLLER. LOAD DEFAULT VALUES
%================================================
%connect to controller using GALILConnect function
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
% set controller parameters
set_motor_defaults(hDmc);

% Display controller serial number in the results window
set(display2,'String', ['Connected to Controller: ',...
    num2str(ControllerSerialNum)]);

% Activate the main button to start motor testing
updateMainButtonInfo(guiHandles,'text','Select ROBOT Type and Joint');

%get Amp Gain from the amplifier
AG = get(hDmc,'AGX');
%set the corresponding gain
if (AG == 1)
    amp_gain = 0.7; %Nm/Amps
elseif (AG == 2)
    amp_gain = 1.0; %Nm/Amps
else
    set(display2,'String',['Amp gain not set correct. AG = ', num2str(AG)])
    error('Amplifier Gain too low or not set correct')
end

%% Create text GUI to show controller serial number and ROBOT Type
%  type in the Main UI Panel
handle_txtSN= uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'fontsize',0.45,...
    'Position',[0.02 0.0 0.3 0.05]);

%% Create the listbox for selecting ROBOT Type
handle_lstApp= uicontrol(guiHandles.uiPanel,'style','listbox',...
                'units','normalized','position',[0.15 0.5 0.7 0.2],...
                'string',{...
                'RIO 2.2', ...
				'RIO 3.0'},...
                'fontunits','normalized','fontsize',0.26,...
                'value',2);
handle_btnApp= uicontrol(guiHandles.uiPanel,'style','pushbutton',...
                'units','normalized','position',[0.4 0.38 0.2 0.1],...
                'string','OK','fontunits','normalized','fontsize',0.3,...
                'callback',@click_btnApp);

            
%% Create the button group for selecting joint            
handle_buttongroup = uibuttongroup(guiHandles.uiPanel,...
    'visible','off',...
    'Position',[0.42 0.0 .3 0.8]);
% Create radio button to select motor
yRange = 0.15;
ypos = 0.0;
for repeat = 6:-1:1
    u(repeat) = uicontrol(...
        'Style','Radio',...
        'String',[' ' num2str(repeat)],...
        'Units','normalized',...
        'Position',[.4, ypos, .4, .2],...
        'parent',handle_buttongroup,...
        'HandleVisibility','on',...
        'FontUnits','normalized',...
        'FontSize',0.2); %#ok<AGROW,NASGU>
    ypos = ypos + yRange;
end


%% Setup ROBOT Type Callback
    function click_btnApp(hobj,evdata) %#ok<INUSD>
        apptype= get(handle_lstApp,'value');
           
        % hide the type selection UIs
        set(handle_lstApp,'visible','off');
        set(handle_btnApp,'visible','off');
        set(display1,'string','Select Joint');
        
        % show robot type and GALIL controller serial number
        appstr= get(handle_lstApp,'string');
        set(handle_txtSN,...
            'String',{appstr{apptype},...
                      sprintf('GALIL Controller SN: %d',ControllerSerialNum)},...
                      'backgroundcolor','w');
        
        % Initialize some button group properties.
        set(handle_buttongroup,'SelectionChangeFcn',@selcbk);
        set(handle_buttongroup,'SelectedObject',[]);  % No selection
        set(handle_buttongroup,'Visible','on');
        
        % Load configuration file
        [MOTORDATA, JOINTDATA]= ReadJointConfiguration();
    end

%% Select Joint Callback
    function selcbk(source,eventdata) %#ok<INUSL>
        % refer matlab help doc on 'uibuttongroup' for more info
        joint = str2double(get(eventdata.NewValue,'string'));
        %======================================
        % FILE NAME FOR RESULTS, with joint tag
        %======================================
        % generate results data file name, and safe data file

        dataFileName=['QIP_JointTest-',...
            num2str(joint),'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        results_file = fullfile(guiHandles.reportsDir,dataFileName);

        % SET CONTROLLER TORQUE LIMIT AND GAINS, depending up on which
        % joint is selected
        TL = JOINTDATA.GALIL_TORQUELIMIT(joint);
        set(hDmc,'TL',TL); %torque limit

        % Activate the main button to start motor testing
        updateMainButtonInfo(guiHandles,'pushbutton',...
            ['Click here to Start Testing Joint ',num2str(joint)],...
            @run_qip_jointtest);
    end

%% Run QIP - This is the MAIN function.
% This function controls the sequence of the test.
    function run_qip_jointtest(varargin)

        % turn off the radio button group
        if exist('handle_buttongroup','var')
            set(handle_buttongroup,'Visible','off');
            delete(handle_buttongroup)
            clear('handle_buttongroup')
        end

        % update the main result window
        set(display1,'String', ['Testing JOINT ', num2str(joint)]);
        % save joint id
        results.joint = joint;
        save (results_file,'results');

        % set controller gains
        % PID Transfer function (P+sD+I/s) where
        %    P= KP;  D= T*KD; I= KI/2/T;   T: Sampling Period
        %gains for J1,J2 and J3
        if joint == 1 || joint == 2 || joint == 3
%             GALILCommand ('KP 6.0; KD 60.0; KI 0.06');
            set(hDmc, 'KP', 6.0);
            set(hDmc, 'KD', 60.0);
            set(hDmc, 'KI', 0.06);

        end
        %gains for J4,J5,and J6
        if joint == 4 || joint == 5 || joint == 6
            set(hDmc, 'KP', 12.0);
            set(hDmc, 'KD', 120.0);
            set(hDmc, 'KI', 0.12);

        end

        % button for moving to Previous test (one test back)
        if(do_test > 1)
            % generate the test navigation button. Do so only in the
            % Troubleshooting mode
            if TROUBLESHOOTING
            uicontrol(guiHandles.uiPanel,...
                'Style','pushbutton',...
                'Units','normalized',...
                'FontUnits', 'normalized',...
                'FontSize',0.2,...
                'Position',[0.7 0.05 0.13 0.1],...
                'String','< Previous',...
                'Callback',@previous_test...
                );
            end
        end

        % button for moving one test forward. Just calling the main test
        % function will increment the test.
        if(do_test < 10)
            % if the mode is debug turn the navigation button on
            if TROUBLESHOOTING
            uicontrol(guiHandles.uiPanel,...
                'Style','pushbutton',...
                'Units','normalized',...
                'FontUnits', 'normalized',...
                'FontSize',0.2,...
                'Position',[0.85 0.05 0.13 0.1],...
                'String','Next >',...
                'Callback',@run_qip_jointtest...
                );
            end
        end

        %===================================================
        % SELECT TEST
        %===================================================
        switch do_test %test ID
            case HOME_MOTOR % 1
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to Home Motor',...
                    @home_motor);
                % increment test id by 1
                do_test = do_test+1;
            case GET_MOTOR_CPR % 2
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to Get Motor CPR',...
                    @getcpr_motor);
               % increment test id by 1
                do_test = do_test+1;
            case HOME_JOINT % 3
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to Home Joint',...
                    @home_joint);
               % increment test id by 1
                do_test = do_test+1;
            case GET_JOINT_LIMITS % 4
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to find Joint Limits',...
                    @get_joint_limits);
                % increment test id by 1
                do_test = do_test+1;
            case GET_GEAR_RATIO % 5
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to measure Gear Ratio',...
                    @get_gear_ratio);
                % increment test id by 1
                do_test = do_test+1;
            case GET_HALL_STATES % 6
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to measure Hall States',...
                    @get_hall_states);
                % increment test id by 2, this will ignore the brake check
                do_test = do_test+2;
            case BRAKE_TEST % 7
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to start Brake Test',...
                    @brake_test);
                % increment test id by 1
                do_test = do_test+1;
            case MEASURE_JOINT_FRICTION % 8
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to measure Joint Friction',...
                    @get_friction_joint);
                % increment test id by 1
                do_test = do_test+1;
            case MEASURE_JOINT_DRAG % 9
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to measure Joint Drag',...
                    @get_drag_joint);
                % increment test id by 1
                do_test = do_test+1;
            case MEASURE_JOINT_TRANSMISSION % 10
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to measure Cable Tension',...
                    @check_joint_transmission);
                % increment test id by 1
                do_test = do_test+1;
            case HASS_TEST % 11
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to Start HASS',...
                    @hass_joint_start);
                % increment test id by 1
                do_test = do_test+1;
            case ANALYZE_RESULTS %Analyze Results (12)
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    'Click here to Display Results',...
                    @analyze_results);
        end
    end

%% Navigation functions, Next and Previous
    function previous_test(varargin)
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
        run_qip_jointtest;
        uicontrol(guiHandles.mainButtonInfo) %focus back on main button
    end

%% Home Motor (Test 1)
%homing checks whether the motor encoder index is visible to the encoder
%read head.
    function home_motor(varargin)
        %go to bump stop
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop');
        set(display2,'String','Homing Joint Encoder',...
                     'fontsize',DEFAULT_FONT_SIZE);
        %get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);
        % go to bump stop
        goto_bs_vel(hDmc,-speed,basedir);
        
        % change the display on the main button
        updateMainButtonInfo(guiHandles,'text','Homing motor encoder');
        set(display2,'String','Homing motor encoder',...
                     'fontsize',DEFAULT_FONT_SIZE);
        [done,currentposition] = home_motor_jt(hDmc,joint,basedir,MOTORDATA,JOINTDATA); %#ok<NASGU>
        
        %run home motor again if current position is close to confirm/settle on homed location
        if ~done &&  abs(currentposition) < 50
        [done,currentposition] = home_motor_jt(hDmc,joint,basedir,MOTORDATA,JOINTDATA);
        end
        
        % if homing successful...
        if(done == 1)
            % display result
            set(display2, 'String','Homing DONE');
            % add resutls to results structure
            results.homemotor = [results.homemotor; 1];
            save (results_file,'results');
        else % if homing failed
            results.homemotor = [results.homemotor; 0];
            save (results_file,'results');
            if TROUBLESHOOTING
                set(display2,'String','Motor Homing Failed');
            else
            presentMakoResults(guiHandles,'FAILURE','Motor Homing Failed');
            return
            end
        end
        
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Get Motor Encoder CPR (Test 2)
% The test verifies all the counts on the motor encoder are visible.
% Also validates that grounding is proper
    function cpr = getcpr_motor(varargin)
        % change display on main button
        updateMainButtonInfo(guiHandles,'text','Finding motor encoder CPR');
        set(display2,'String','Finding Motor Encoder CPR',...
                     'fontsize',DEFAULT_FONT_SIZE);
        cpr = get_motor_cpr_jt(hDmc,joint,basedir,MOTORDATA,JOINTDATA);
       
        %get actual cpr from configfile
        cpr_actual = MOTORDATA.CPR(joint);
        %display results
        set(display2,'String',{['Motor encoder CPR, Measured: ',num2str(cpr)];...
            ['Motor encoder CPR, Actual: ',num2str(cpr_actual)]});
        % add the result to results structure
        results.cpr_measured = [results.cpr_measured; cpr];
        save (results_file,'results');
        
        % check pass/fail if mode is not troubleshooting
        if ~TROUBLESHOOTING
            if (abs(cpr_actual-cpr) > 10)
                presentMakoResults(guiHandles,'FAILURE',{'CPR check failed',...
                    ['Difference ', num2str(cpr_actual-cpr),' Counts'],...
                    'Limit 10 counts'});
                comm(hDmc,'AB');
                comm(hDmc,'MO');
                return
            end
        end
            
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Home Joint (Test 3)
    function home_joint(varargin)
        %go to bump stop
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop');
        set(display2,'String','Homing Joint Encoder',...
                     'fontsize',DEFAULT_FONT_SIZE);
        %get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);
        % go to bump stop
        goto_bs_vel(hDmc,-speed,basedir);

        % once the joint is at the bump stop, attempt homing
        updateMainButtonInfo(guiHandles,'text','Homing Joint');
        % download the 'homejoint.dmc' file to the galil controller
        downloadfile(hDmc, fullfile(basedir,...
            'dmcfiles','homejoint.dmc'));
        pause(0.05);
        % set joint homing speed
        set(hDmc,'JOGSPEED',JOINTDATA.HOMESPEED(joint));
        pause(0.05);
        % execute galil script using the XQ command
        comm(hDmc, 'XQ'); %#HOMEJ,0');
        % monitor result
        STATUS = 0;
        tic
        while (STATUS == 0)
            STATUS = get(hDmc, 'DONE');
            % monitor time to exit after 24 sec. Like a timeout
            if(toc > 24)
                % display error message
                set(display2,'String','TIMEOUT. CANNOT SEE JOINT ENCODER INDEX');
                pause(1)
                % Abort execution (AB) and turn motor off (MO)
                comm(hDmc, 'AB');
                comm(hDmc, 'MO');
                % save result
                results.homemotor = [results.homejoint; 0];
                save (results_file,'results');
                if ~TROUBLESHOOTING
                    presentMakoResults(guiHandles,'FAILURE','Joint Homing Failed');
                    return
                end
                STATUS = 1;
            end
        end
        % if index is read seen, get the current position of the joint by
        % using Tell Position (axis B) command, TPB
        currentpos = get(hDmc, 'TPB');
        % display results
        set(display2,'String',{'Joint Homed';['Current Joint pos is ',num2str(currentpos)]});
        %Abort execution of homing script
        comm(hDmc, 'AB');
        % Set motor and joint position as Zero
        comm(hDmc, 'DP 0,0');
        %Turn off motor (MO)
        comm(hDmc, 'MO');
        % save result
        results.homejoint = [results.homejoint; 1];
        save (results_file,'results');

        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Joint Limits (Test 4)
    function limits = get_joint_limits(varargin)
        %update display
        updateMainButtonInfo(guiHandles,'text','Finding Joint Limit');
        set(display2,'String','Finding Joint Limits',...
                     'fontsize',DEFAULT_FONT_SIZE);
        %get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);

        % go to bump stop 1, and measure position to get negative limit
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 1');
        goto_bs_vel(hDmc,-speed,basedir);
        pause(0.05);
        limit_neg = get(hDmc, 'TPB');
        pause(0.05);
        % go to bump stop 2, and measure position to get positive limit
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 2');
        goto_bs_vel(hDmc,speed,basedir)
        pause(0.05)
        limit_pos = get(hDmc, 'TPB');

        % get the joint encoder cpr data from the configuration file
        cpr_joint = JOINTDATA.CPR(joint);
        % convert the limits to degrees
        limit_neg = limit_neg*360/cpr_joint;
        limit_pos = limit_pos*360/cpr_joint;
        range = (limit_pos-limit_neg);

        set(display2,'String',{['Joint Limit Positive :',num2str(limit_pos)];...
            ['Joint Limit Negative :',num2str(limit_neg)];...
            ['Joint Range :', num2str(range),' degrees']});
        % save results
        limits = [limit_pos,limit_neg,range];
        results.jointlimits = [results.jointlimits; limits];
        save (results_file,'results');
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Gear Ratio (Test 5)
    function gratio = get_gear_ratio(varargin)
        %update display
        updateMainButtonInfo(guiHandles,'text','Finding Gear Ratio');
        set(display2,'String','Finding Gear Ratio',...
                     'fontsize',DEFAULT_FONT_SIZE);
        
        % get the joint encoder cpr data from the configuration file
        cpr_motor = MOTORDATA.CPR(joint);
        cpr_joint = JOINTDATA.CPR(joint);
        
        %get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);

        % go to bump stop 1
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 1');
        goto_bs_vel(hDmc,-speed,basedir);
        pause(0.05);
        
        % go to bump stop 2, and measure position
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 2');
        arrays= goto_bs_vel(hDmc,speed,basedir);
        pause(0.05)

        % Read Galil arrays
        nArrays= size(arrays.data,1);
        for x=1:nArrays
            if strcmp(arrays.var(x),'MPOS');
                motorAngles= arrays.data{x}/cpr_motor*2*pi;  % in radian
            end
            
            if strcmp(arrays.var(x),'JPOS');
                jointAngles= arrays.data{x}/cpr_joint*2*pi;  % in radian
            end
        end  
                
        % Compute the values for the transmission ratio based on the data
        % collected
        % setup motion limits
        negMotionLimit= min(jointAngles([1 end])) + JOINTDATA.TRATIO_RANGE_TOLERANCE(joint);
        posMotionLimit= max(jointAngles([1 end])) - JOINTDATA.TRATIO_RANGE_TOLERANCE(joint);
        % remove data beyond useful range
        idx = [find(jointAngles>negMotionLimit); find(jointAngles<posMotionLimit)];
        %fit model y'=ax+b
        ft=polyfit(motorAngles(idx),jointAngles(idx),1);
        gratio_measured= 1/ft(1);
        %error e=y-ax
        residual= jointAngles(idx)-motorAngles(idx)/gratio_measured;
        %mean error = sqrt(mean square error)
        fitResidual = sqrt(norm(residual)^2/length(jointAngles(idx)));
        gratio_nominal = JOINTDATA.GRATIO(joint);

        % check whether the Transmission ratio is within specs
        tRatioLimit= JOINTDATA.TRATIO_TRANSMISSION_RATIO_LIMIT(joint);
        fitErrLimit= JOINTDATA.TRATIO_FIT_ERROR_LIMIT(joint);
        if ((abs(1/gratio_measured-1/gratio_nominal)>tRatioLimit) ...
                    || (abs(fitResidual)>fitErrLimit))
           set(display2,'String',{['Gear Ratio is ', num2str(gratio_measured)];...
            ['Nominal Gear Ratio ', num2str(gratio_nominal)]});
        
           test_failed=1;
           answer = questdlg('Transmission Ratio Computation Failed! Continue or Abort the test?', ...
                         'Transmission Ratio Computation Failed!', ...
                         'Continue', 'Abort', 'Continue');
           if strcmp(answer,'Abort')
              close(guiHandles.figure);
              return;
           end
        else
           test_failed=0; 
           set(display2,'String',{['Gear Ratio is ', num2str(gratio_measured)];...
            ['Nominal Gear Ratio ', num2str(gratio_nominal)]});
        end
        
        % set up output data
        gratio.gratio_measured= gratio_measured;
        gratio.gratio_nominal= gratio_nominal;
        gratio.fitResidual= fitResidual;
        gratio.residual= residual;
        gratio.fitResidualLimit= JOINTDATA.TRATIO_FIT_ERROR_LIMIT;
        gratio.test_failed= test_failed;
        gratio.jointAngles= jointAngles(idx);
        gratio.motorAngles= motorAngles(idx);
        
        % save results
        results.gratio = [results.gratio; gratio];
        save (results_file,'results');
        
        
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Hall State (Test 6)
% measures the hall states in one revolution and check the sequence
    function hall_state= get_hall_states(hObject, eventdata, handles) %#ok<INUSD>
        % update Main button info
        updateMainButtonInfo(guiHandles,'text','Checking Hall Sensor State');
        
        % goto test position (0 deg)
        if(joint==2)
            goto_jointpos(hDmc, joint, 15, basedir,MOTORDATA,JOINTDATA);
        elseif joint==4
            goto_jointpos(hDmc, joint, -20, basedir,MOTORDATA,JOINTDATA);
        else
            goto_jointpos(hDmc, joint, 0, basedir,MOTORDATA,JOINTDATA);
        end
        
        %0.05 round per second
        speedMotor = floor(MOTORDATA.CPR(joint)/20);
        no_motor_pole= JOINTDATA.HALL_MOTOR_POLE(joint);
        %maximal number of hall state changes
        %the first hall angle is not a complete hall angle,
        %this calculation ensures a full turn on the motor,
        MaxNoHallChange = 6*no_motor_pole/2+2;  
        
        %download the dcm script to the galil controller
        downloadfile(hDmc, fullfile(basedir,'dmcfiles','getHALL.dmc'));
        
        % set the jog speed
        set(hDmc, 'SPEED', abs(speedMotor));
        set(hDmc, 'SIZE', MaxNoHallChange);
        
        pause(0.01);
        % execute the dmc script by issuing 'XQ' command
        comm(hDmc, 'XQ'); % PERHAPS CHECK/WARN IF AT BUMP 2 BEFORE EXECUTION??
        
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
        
        %remove the unwanted elements
        HallState(end-1:end)=[];
        MotorCnt(1)=[];
        %calculate hall angles
        hallAngle=diff(MotorCnt)/MOTORDATA.CPR(joint)*360*no_motor_pole/2;
        maxHallAngleError=max(abs(abs(hallAngle)-60));
        
        % Rearrange the hall states so it starts at 1
        ind1= find(HallState==1,1);  % find first index when hall state is 1
        NewHallState= [HallState(ind1:end) ; HallState(1:ind1-1)];
        
        % display the sample hall state sequence
        correctSet= MOTORDATA.CORRECT_HALL_SET;  % Correct hall state sequence for the testing rotation direction
        totalRotation= (MotorCnt(end)-MotorCnt(1))/results.cpr_measured*360; 
        
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
        set(display2,'String',{str,str1,str2,str3,str4,failstr},'fontsize',0.11);            
            
      
        % return hall state
        hall_state.new_state= NewHallState;
        hall_state.raw_state= HallState;
        hall_state.count_transition= MotorCnt;
        hall_state.total_rotation= totalRotation;
        hall_state.test_failed= hallfail;
        hall_state.hall_angle=hallAngle;
        
        % save results
        results.hall_state= [results.hall_state; hall_state];
        save (results_file,'results');
        
        if hallfail
            presentMakoResults(guiHandles,'FAILURE','Hall State Test Failed');
            return
        end
        
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Brake Test (Test 7)
    function brake_data = brake_test(varargin)
        %change the display on the main button
        updateMainButtonInfo(guiHandles,'text','Go to Testing Position');
        
        %read the data from configuration file
        testpos = JOINTDATA.BRAKE_TEST_POSE(joint)*180/pi;  % in degrees
        jnt_cpr = JOINTDATA.CPR(joint); 
        cnt_threshold= JOINTDATA.BRAKE_HOLD_MOTION_DETECTION_THRESHOLD(joint)...
                       /2/pi*jnt_cpr;
        % go to test position.
        goto_jointpos(joint, testpos, basedir,MOTORDATA,JOINTDATA);
        pause(1)
        %download braketest_joint.dmc to the controller
        downloadfile(hDmc, fullfile(basedir,...
            'dmcfiles','braketest_joint.dmc'));
        pause(0.1)
        
        % Obtain Maximal holding torque
        hold_joint_torque= JOINTDATA.BRAKE_HOLDING_TQ_LIMIT(joint)*...
                           JOINTDATA.BRAKE_TQ_TEST_LIMIT_RATIO(joint);  % in Nm
        if isempty(results.gratio)  % get gear ratio 
           gratio= JOINTDATA.GRATIO(joint); 
        else
           gratio= results.gratio(1).gratio_measured;
        end
        hold_motor_torque= hold_joint_torque/abs(gratio);
        
        % Assign angle threshold to GALIL controller
        set(hDmc, 'ANGTH',cnt_threshold);  
        pause(0.1);
        % Assign Torque limit (Nm) to GALIL Controller
        set(hDmc, 'TRQLIM',hold_motor_torque);  
        pause(0.1);
        % Assign motor constant Kt to GALIL Program
        Kt= MOTORDATA.Kt(joint);
        set(hDmc, 'Kt', Kt);
        pause(0.1)
        
        %-----------------------------
        % start brake holding test
        uiwait(warndlg('BRAKE the joint and then click ok to continue'));
        
        updateMainButtonInfo(guiHandles,'text','Ramping up the Joint Torque now');
        comm(hDmc, 'XQ');
        pause(0.01);
        STATUS = 0;
        hall_state_brake=[];
        while(STATUS == 0)
            pause(0.02);
            hall_state_brake=[hall_state_brake ; get(hDmc, 'QHA')]; %#ok<AGROW>
            STATUS = get(hDmc, 'ALLDONE');
        end
        pause(0.1)
        
        % obtain torque values
        motor_torque_pos = get(hDmc, 'TRQPOS');
        motor_torque_neg = get(hDmc,'TRQNEG');
        
        joint_torque_pos= max([motor_torque_pos motor_torque_neg]*gratio);
        joint_torque_neg= min([motor_torque_pos motor_torque_neg]*gratio);
        
        %add the results to results structure
        brake_data.gratio_uesd= gratio;
        brake_data.motor_torque_pos= motor_torque_pos;
        brake_data.motor_torque_neg= motor_torque_neg;
        brake_data.joint_torque_pos= joint_torque_pos;
        brake_data.joint_torque_neg= joint_torque_neg;
        brake_data.hold_joint_torque_limit= hold_joint_torque;
        brake_data.hall_state_brake= hall_state_brake;
        
        results.brake_data = [results.brake_data; brake_data];
        save (results_file,'results');
                
        %display final results
        set(display2, 'String',...
            {sprintf('Positive Joint Brake Holding Torque:%8.2f Nm', joint_torque_pos),...
             sprintf('Negative Joint Brake Holding Torque:%8.2f Nm', joint_torque_neg),...
             sprintf('Allowable Joint Brake Holding Torque:%8.2f Nm',hold_joint_torque)},...
              'fontsize',DEFAULT_FONT_SIZE);
        % prompt user to release brake before continue
        uiwait(warndlg('UNBRAKE the joint and then click ok to continue'));
          
          
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Motor Friction (Test 8)
    function friction_average = get_friction_joint(varargin)
        %change the display on the main button
        updateMainButtonInfo(guiHandles,'text','Measuring Joint Friction');
        set(display2,'String','Measuring Joint Friction',...
                     'fontsize',DEFAULT_FONT_SIZE);
        %read the test pose from configuration file
        testpos = JOINTDATA.FRICTION_MEASURE_POSE{joint};

        friction_average = [];
        for n = 1:length(testpos)
            % go to test position.
            goto_jointpos(hDmc,joint, testpos(n),basedir,MOTORDATA,JOINTDATA);

            %download breakaway.dmc to the controller
            downloadfile(hDmc,fullfile(basedir,...
                'dmcfiles','breakaway_joint.dmc')); 
            pause(0.1)
            breakawaycrnt = [];
            motion = [];
            for times = 1:5
                %set flag to zero. the flag gets set to 1 when motion is detected
                set(hDmc,'DONE', 0);
                comm(hDmc,'XQ');
                updateMainButtonInfo(guiHandles,'text',['Joint friction, run ',...
                    num2str(times), ', at position ',num2str(testpos(n)),' deg']);
                while (get(hDmc,'DONE') ~= 1)
                    %wait for motion
                    pause(0.05)
                end
                breakawaycrnt = [breakawaycrnt; get(hDmc,'OFFSET')]; %#ok<AGROW>
                motion = [motion; get(hDmc,'delpos')]; %#ok<AGROW>
            end
            result = [breakawaycrnt, motion];
            %breakaway current in Amps
            %multiplied by the current gain on amp
            % first measurement is ignored. First measurement includes the
            % slack on the motor.
            Kt = MOTORDATA.Kt(joint);
            meanbreakaway = mean(abs(result(2:5,1)))*amp_gain*Kt;

            %display results per position if mode is trouble shoot
            if TROUBLESHOOTING
                set(display2, 'String',...
                    {['Friction : ',num2str(meanbreakaway),' Nm'],...
                    ['Allowable Friction: ',num2str(JOINTDATA.FRICTION_LIMIT(joint)),' Nm']});
                pause(0.1)
            end
            %add the results to results structure
            results.friction_measured = [results.friction_measured; [testpos(n),meanbreakaway]];
            save (results_file,'results');
            friction_average = [friction_average,meanbreakaway]; %#ok<AGROW>
        end
        
        % now take the mean of friction measured at all the test pose to
        % calculate the average friction of the joint
        friction_average = mean(friction_average);
        
        %display final results
        set(display2, 'String',...
            {['Mean Friction: ',num2str(friction_average),' Nm'],...
            ['Allowable Friction: ',num2str(JOINTDATA.FRICTION_LIMIT(joint)),' Nm']});

        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Joint Drag (Test 9)
    function drag_measured = get_drag_joint(varargin)
        % update display
        updateMainButtonInfo(guiHandles,'text','Measuring Joint Drag');
        pause(0.5);
        updateMainButtonInfo(guiHandles,'text','Measuring Drag in negative direction');
        % get drag in the negative direction, but first go to the bump stop
        % to makse sure there is enough room to move
        % but doing before all that, get the speed from configuration file
        dragspeed = 0.2/(2*pi)*JOINTDATA.GRATIO(joint)*MOTORDATA.CPR(joint);
        samplesize = JOINTDATA.DRAG_SAMPLESIZE(joint);
        startPosition=JOINTDATA.DRAGSTART(joint);
        
        %go to start position
        goto_jointpos(hDmc,joint,startPosition,basedir,MOTORDATA,JOINTDATA);  
        %get drag in the negative direction
        [drag_neg,vel_neg] = get_jointdrag(-1,hDmc,joint,samplesize,dragspeed,MOTORDATA,JOINTDATA,basedir); %#ok<NASGU>

        % get drag in the positive direction
        updateMainButtonInfo(guiHandles,'text','Measuring Drag in positive direction');
        [drag_pos, vel_pos] = get_jointdrag(1,hDmc,joint,samplesize,dragspeed,MOTORDATA,JOINTDATA,basedir); %#ok<NASGU>

        % get mean drag (this negates the motor torque offset)
        meandrag = mean([abs(drag_pos) ; abs(drag_neg)]);
        vardrag= max([std(drag_pos) ; std(drag_neg)]);

        %display results
        set(display2, 'String',...
            {sprintf('Mean Drag Measured:%10.4f Nm', meandrag),...
             sprintf('Drag Variance Measured:%10.4f Nm',vardrag),...
             sprintf('Allowable Mean Drag:%10.4f Nm', JOINTDATA.DRAG_LIMIT(joint)),...
             sprintf('Allowable Drag Variance:%10.4f Nm', JOINTDATA.DRAG_VARIANCE_LIMIT(joint))},...
                     'fontsize',DEFAULT_FONT_SIZE);
        
        % add the result to results structure
        drag_measured.drag_pos= drag_pos;
        drag_measured.drag_neg= drag_neg;
        drag_measured.meandrag= meandrag;
        drag_measured.dragvar= vardrag;
        results.drag_measured = [results.drag_measured; drag_measured];
        % and then save results
        save (results_file,'results');
        % Go back the the main function. Do not do so if hass test is being
        % performed
        if(performing_hass == 0); run_qip_jointtest; end
    end

%% Measure Joint Transmission (Test 10)
    function transmission = check_joint_transmission(varargin)
        % update display
        set(display2,'String','Measuring Joint Transmission',...
                     'fontsize',DEFAULT_FONT_SIZE);
        updateMainButtonInfo(guiHandles,'text','Measuring Transmission Phase Lag');
        
        [phase_lag amplitude_ratio transmissiondata] = transmissioncheck_qip(hDmc,joint,basedir);
        
        warning= JOINTDATA.TRANSMISSION_WARNING(joint);
        limit= JOINTDATA.TRANSMISSION_LIMIT(joint);
        % display results
        set(display2, 'String',...
            {sprintf('Joint %1.0f Phase Lag : %4.3f(rad)    % 3.2f°',...
               joint,phase_lag,phase_lag*180/pi);...
            sprintf('Joint %1.0f Warning    : %4.3f(rad)    % 3.2f°',...
               joint,warning,warning*180/pi);...
            sprintf('Joint %1.0f Limit          : %4.3f(rad)    % 3.2f°',...
               joint,limit,limit*180/pi)});

        % add the result to results structure
        transmission = [phase_lag amplitude_ratio];
        results.transmission = [results.transmission; transmission];
        results.transmissiondata = [results.transmissiondata; transmissiondata];
        % and then save results
        save (results_file,'results');
        
        if (performing_hass == 0) && (abs(phase_lag) > limit)
            presentMakoResults(guiHandles,'FAILURE','Joint Transmission Check Failed');
        elseif (performing_hass == 0); 
        % Go back the the main function. Do not do so if hass test is being performed
            run_qip_jointtest;
            
        end

    end

%% HASS Test (Test 11)
    function hass_joint_start(varargin)

        % update main display
        updateMainButtonInfo(guiHandles,'text','Performing HASS Test');

        % Set up Pause button
        pausetest = false;
        pauseButtonHandle = uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'Position',[0.78 0.25 0.2 0.2],...
            'FontUnit','normalized',...
            'FontSize',0.2,...
            'String','Pause',...
            'BackgroundColor',[0.8 0.05 0.05],...
            'Callback',@pauseHASS...
            );
         set(pauseButtonHandle,'enable','on');

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

        % TURN ON SAFETY
%         global safetyHandle
%         global safety %variable safety = true is safety
        %         is clear (updated in the safety check function)
%         safetyHandle = safetycheck(joint);

        % HASS TESTING STARTS HERE
        % Set HASS flag to 1
        performing_hass = 1;
        % Set number of cycles
        num_of_testcycles = 24; % 24
        num_of_breakincycles= 10; % 10

        STEPSIZE = JOINTDATA.HASS_STEPSIZE{joint};
        COUNT = JOINTDATA.HASS_COUNT{joint};
        SPEED = JOINTDATA.HASS_SPEED{joint};
        WAIT = JOINTDATA.HASS_WAIT{joint};

        % update display
        display1_show = ['Performing HASS test, Joint ',num2str(joint)];
        set(display1,'String',display1_show);

        %handle for plot 1
        plothandle1 = axes('parent',guiHandles.extraPanel,'Position',[0.1 0.63 0.8 0.15]);
        grid(plothandle1,'on');
        title(plothandle1,'Index Check');
        ylabel(plothandle1,'Position (deg)');
        xlim(plothandle1,[0 num_of_testcycles]);
        %handle for plot 2
        plothandle2 = axes('parent',guiHandles.extraPanel,'Position',[0.1 0.43 0.8 0.15]);
        grid(plothandle2,'on');
        title(plothandle2,'Joint Stiction');
        ylabel(plothandle2,'Torque (Nm)');
        xlim(plothandle2,[0 num_of_testcycles]);
        %handle for plot 3
        plothandle3 = axes('parent',guiHandles.extraPanel,'Position',[0.1 0.23 0.8 0.15]);
        grid(plothandle3,'on');
        title(plothandle3,'Joint Drag');
        ylabel(plothandle3,'Torque (Nm)');
        xlim(plothandle3,[0 num_of_testcycles]);
        %handle for plot3
        plothandle4 = axes('parent',guiHandles.extraPanel,'Position',[0.1 0.03 0.8 0.15]);
        grid(plothandle4,'on');
        title(plothandle4,'Transmission Check');
        ylabel(plothandle4,'Phase Lag (deg)');
        xlabel(plothandle4,'Count');
        xlim(plothandle4,[0 num_of_testcycles]);


        results.hass.friction = [];
        results.hass.gratio = [];
        %results.hass.brake_data=[];
        results.hass.drag_measured = [];
        results.hass.tension = [];
        results.hass.transmission = [];
        results.hass.limitcheck.poslim = [];
        results.hass.limitcheck.neglim = [];
        results.hass.limitcheck.cyclenum = [];
        results.hass.limitcheck.posave = [];
        results.hass.limitcheck.negave = [];
        results.hass.limitcheck.jindex = [];
        results.hass.indexcheck.pospts = [];
        results.hass.indexcheck.negpts = [];
        results.hass.indexcheck.pos = [];
        results.hass.indexcheck.neg = [];

        % Break-In Cycles
       set(display1,'String',...
           sprintf('Performing HASS Break-In, Joint %d',joint));

       for cycle = 1:num_of_breakincycles
            % change display 2
            set(display2,'String','HASS RESULT',...
                     'fontsize',DEFAULT_FONT_SIZE);
            xlims=[0 num_of_testcycles];
            cycles=1:cycle;

            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                set(guiHandles.mainButtonInfo,...
                    'String',['Test Paused at Cycle ',num2str(cycle)])
            end

            %read the test pose from configuration file
            testpos = JOINTDATA.HASSTEST_POSE(joint);
            % go to test position.
            goto_jointpos(hDmc,joint,testpos,basedir,MOTORDATA,JOINTDATA);

            % --- step excitation ---
            % Download step.dmc to the controller
            downloadfile(hDmc,fullfile(basedir,...
                'dmcfiles','step_orig.dmc'));
            pause(0.2)
            
            % update main display
            updateMainButtonInfo(guiHandles,'text','Performing HASS Break-In');
            % step input
            for run = 1:length(STEPSIZE)
                set(hDmc,'STEPSIZE',STEPSIZE(run));
                set(hDmc,'SPEED', SPEED(run));
                set(hDmc,'COUNT', COUNT(run));
                set(hDmc,'WAIT', WAIT(run));
                pause(0.1)
                
                % if pause button is pressed, hold the test
                while(pausetest == true)
                    pause(1)
                    updateMainButtonInfo(guiHandles,'text',...
                        ['Test Paused at Cycle ',num2str(cycle)])
                end
                
                % Execute
                set(hDmc,'DONESTEP', 0);
                comm(hDmc,'XQ#STEP,0');

                STATUS = 0;
                while (STATUS == 0)
                    pause(0.2)
                    STATUS = get(hDmc,'DONE');
                    stepcount = get(hDmc,'N');
                    set(display2,'String',['Cycle ', num2str(cycle), ' of ',...
                        num2str(num_of_breakincycles),'. Test ',num2str(run)...
                        , '. Count ',num2str(stepcount), ' of ', num2str(COUNT(run))]);
                    set(display1, 'String',{display1_show;...
                        ['Cycle ', num2str(cycle), ' of ',...
                        num2str(num_of_breakincycles)]});
                end
            end %end of hass loop

            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                set(guiHandles.mainButtonInfo,...
                    'String',['Test Paused at Cycle ',num2str(cycle)])
            end

            % JOINT RANGE LIMIT CHECK
            %get jog speed from the configuration file
            speed = JOINTDATA.JOGSPEED(joint);
            bumpnum=2;
            updateMainButtonInfo(guiHandles,'text',...
                'String',['Performing Range of motion, 1/' num2str(bumpnum)]);
            goto_bs_vel(hDmc,speed,basedir);
            for n = 1:bumpnum
                updateMainButtonInfo(guiHandles,'text',...
                    'String',['Performing Range of motion, ',num2str(n),'/' num2str(bumpnum)]);
                speed = -1*speed;
                goto_bs_vel(hDmc,speed,basedir);
                pause(0.5)
            end

            % go to test position.
            goto_jointpos(hDmc,joint,testpos,basedir,MOTORDATA,JOINTDATA);
            
        end %end of Break-in cycles
        
        % HASS Test Cycles
        set(display1,'String',...
            sprintf('Performing HASS Break-In, Joint %d',joint));
        for cycle = 1:num_of_testcycles
            % change display 2
            set(display2,'String','HASS RESULT',...
                     'fontsize',DEFAULT_FONT_SIZE);
            xlims=[0 num_of_testcycles];
            cycles=1:cycle;

            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                set(guiHandles.mainButtonInfo,...
                    'String',['Test Paused at Cycle ',num2str(cycle)])
            end

            %read the test pose from configuration file
            testpos = JOINTDATA.HASSTEST_POSE(joint);
            % go to test position.
            goto_jointpos(hDmc,joint,testpos,basedir,MOTORDATA,JOINTDATA);

            % --- step excitation ---
            % Download step.dmc to the controller
            downloadfile(hDmc,fullfile(basedir,...
                'dmcfiles','step_orig.dmc'));
            pause(0.2)
            
            % update main display
            updateMainButtonInfo(guiHandles,'text','Performing HASS Test');
            % step input
            for run = 1:length(STEPSIZE)
                set(hDmc,'STEPSIZE', num2str(STEPSIZE(run)));
                set(hDmc,'SPEED', num2str(SPEED(run)));
                set(hDmc,'COUNT', num2str(COUNT(run)));
                set(hDmc,'WAIT', num2str(WAIT(run)));
                pause(0.1)
                
                % if pause button is pressed, hold the test
                while(pausetest == true)
                    pause(1)
                    updateMainButtonInfo(guiHandles,'text',...
                        ['Test Paused at Cycle ',num2str(cycle)])
                end
                
                % Execute
                set(hDmc,'DONESTEP', 0);
                comm(hDmc,'XQ#STEP,0');

                STATUS = 0;
                while (STATUS == 0)
                    pause(0.2)
                    STATUS = get(hDmc,'DONE');
                    stepcount = get(hDmc,'N');
                    set(display2,'String',['Cycle ', num2str(cycle), ' of ',...
                        num2str(num_of_testcycles),'. Test ',num2str(run)...
                        , '. Count ',num2str(stepcount), ' of ', num2str(COUNT(run))]);
                    set(display1, 'String',{display1_show;...
                        ['Cycle ', num2str(cycle), ' of ',...
                        num2str(num_of_testcycles)]});
                end
            end %end of hass loop

            % if pause button is pressed, hold the test
            while(pausetest == true)
                pause(1)
                set(guiHandles.mainButtonInfo,...
                    'String',['Test Paused at Cycle ',num2str(cycle)])
            end

            % JOINT RANGE LIMIT CHECK
            %get jog speed from the configuration file
            speed = JOINTDATA.JOGSPEED(joint);
            posread=[];
            negread=[];
            jindexp=[];
            jindexn=[];
            bumpnum=2;
            updateMainButtonInfo(guiHandles,'text',...
                'String',['Performing Range of motion, 1/' num2str(bumpnum)]);
            goto_bs_vel(hDmc,speed,basedir);
            for n = 1:bumpnum
                updateMainButtonInfo(guiHandles,'text',...
                    'String',['Performing Range of motion, ',num2str(n),'/' num2str(bumpnum)]);
                speed = -1*speed;
                comm(hDmc,'ALTB');
                goto_bs_vel(hDmc,speed,basedir);
                position=get(hDmc,'TP'); %#ok<ST2NM>
                if sign(speed)==1
                    results.hass.limitcheck.poslim = [results.hass.limitcheck.poslim; cycle position];
                    posread=[posread;position]; %#ok<AGROW>
                    latchpos = get(hDmc,'RLB');  %report latch position
                    results.hass.indexcheck.pospts = [results.hass.indexcheck.pospts; cycle latchpos];
                    jindexp=[jindexp; latchpos]; %#ok<AGROW>
                end
                if sign(speed)==-1
                    results.hass.limitcheck.neglim = [results.hass.limitcheck.neglim; cycle position];
                    negread=[negread;position]; %#ok<AGROW>
                    latchneg = get(hDmc,'RLB');  %report latch position
                    results.hass.indexcheck.negpts = [results.hass.indexcheck.negpts; cycle latchneg];
                    jindexn=[jindexn; latchneg]; %#ok<AGROW>
                end
                pause(0.5)
            end
            results.hass.limitcheck.posave=[results.hass.limitcheck.posave; mean(posread)];
            results.hass.limitcheck.negave=[results.hass.limitcheck.negave; mean(negread)];
            results.hass.indexcheck.pos=[results.hass.indexcheck.pos; latchpos];
            results.hass.indexcheck.neg=[results.hass.indexcheck.neg; latchneg];
            % plot results, limitcheck
            phandle = plothandle1;
            posave=results.hass.indexcheck.pos;
            negave=results.hass.indexcheck.neg;
            poslim = results.hass.indexcheck.pospts;
            neglim = results.hass.indexcheck.negpts;
            posnominal=posave(1,:);
            negnominal=negave(1,:);
            limit=100;
            plot(phandle,poslim(:,1),poslim(:,2)-posnominal,'.c',...
                cycles,posave-posnominal,'.-b',...
                neglim(:,1),neglim(:,2)-negnominal,'.y',...
                cycles,negave-negnominal,'.-g',...
                xlims,[limit limit],'r',...
                xlims,-[limit limit],'r','LineWidth',2);
            axis(phandle,[0 num_of_testcycles -2*limit 2*limit]);
            grid(phandle,'on');
            ylabel(phandle,'Position (encoder counts)');
            title(phandle,'Index Check');
            legend(phandle,'Positive Points','Positive Index','Negative Points','Negative Index','Location','bestoutside');

            % go to test position.
            goto_jointpos(hDmc,joint,testpos,basedir,MOTORDATA,JOINTDATA);
            
            % MEASURE JOINT FRICTION
            if rem(cycle,8) == 0  % run friction test at every 8 cycle
                results.hass.friction = [results.hass.friction; get_friction_joint()];
            else
                % generate nan results when not testing
                results.hass.friction = [results.hass.friction; nan];
            end
            % plot results, friction
            phandle = plothandle2;
            friction=results.hass.friction;
            limit= JOINTDATA.FRICTION_LIMIT(joint);
            plot(phandle,cycles,friction,'.-b',...
                xlims,[limit limit],'r','LineWidth',2);
            axis(phandle,[0 num_of_testcycles 0 2*limit]);
            grid(phandle,'on');
            ylabel(phandle,'Torque (Nm)');
            title(phandle,'Joint Stiction');
            legend(phandle,'friction','Failure Limit','Location','bestoutside');
            
            % MEASURE JOINT DRAG
            results.hass.drag_measured = [results.hass.drag_measured; get_drag_joint()];
            % plot results, drag
            phandle = plothandle3;
            
            drag=zeros(cycle,1);
            for nc=1:cycle
                drag(nc,1)=results.hass.drag_measured(nc).meandrag;
            end                
            limit= JOINTDATA.DRAG_LIMIT(joint);
            plot(phandle,cycles,drag,'.-b',...
               xlims,[limit limit],'r','LineWidth',2);
            axis(phandle,[0 num_of_testcycles 0 2*limit]);
            grid(phandle,'on');
            ylabel(phandle,'Torque (Nm)');
            title(phandle,'Joint Drag');
            legend(phandle,'drag','Failure Limit','Location','bestoutside');
            
            % MEASURE TRANSMISSION
            results.hass.transmission = [results.hass.transmission; check_joint_transmission()];
            % plot transmission
            phandle = plothandle4;
            transmission=180/pi*results.hass.transmission(:,1);
            warning=180/pi*JOINTDATA.TRANSMISSION_WARNING(joint);
            limit=180/pi*JOINTDATA.TRANSMISSION_LIMIT(joint);
            plot(phandle,cycles,transmission,'.-b',...
                xlims,[warning warning],'y',...
                xlims,[limit limit],'r','LineWidth',2);
            axis(phandle,[0 num_of_testcycles 0 2*limit]);
            grid(phandle,'on');
            ylabel(phandle,'Phase Lag (deg)');
            title(phandle,'Transmission Check');
            legend(phandle,'Phase Lag','Warning Limit','Failure Limit','Location','bestoutside');
            
            % MEASURE GEAR RATIO and Brake check AT LAST CYCLE
            if cycle== num_of_testcycles
                results.hass.gratio = [results.hass.gratio; get_gear_ratio()];
                %ignore brake check results
                %results.hass.brake_data = [results.hass.brake_data; brake_test()];
            end
             
            % save results file
            save (results_file,'results');

            pause(0.2)
        end %end of cycle

        % Once the hass test is done, set back the hass flag to 0
        performing_hass = 0;
        
        % disable pause/resume button
        set(pauseButtonHandle,'enable','off');
        % Go back the the main function
        run_qip_jointtest;
    end

%% Analyze and Display Results (Test 12)
    function analyze_results(varargin)

        % use the analyze_results_joint, function to evaluate the results
        results = analyze_results_joint(joint,results,MOTORDATA,JOINTDATA);

        %save results
        save (results_file, 'results')

        testnames = fieldnames(results.fail);

        display_result = {};
        failSTATUS = 0;
        warnSTATUS = 0;
        for n = 1:size(testnames,1)
            if(results.fail.(testnames{n}) == 0 && results.warn.(testnames{n}) == 0)
                display_result = cat(1,display_result,{[testnames{n},' PASS']});
                
            elseif (results.fail.(testnames{n}) == 0 && results.warn.(testnames{n}) > 0)
                display_result = cat(1,display_result,{[testnames{n},' WARNING']});
                warnSTATUS = 1;
                
            else
                display_result = cat(1,display_result,{[testnames{n},' FAIL']});
                failSTATUS = 1;
            end

        end

        display_result = cat(1,{['Joint : ',num2str(joint)]},display_result);

        % display results in Main Button
        if(failSTATUS == 0) && (warnSTATUS == 0)
            presentMakoResults(guiHandles,'SUCCESS',display_result);
        elseif (failSTATUS == 0) && (warnSTATUS == 1)
            presentMakoResults(guiHandles,'WARNING',display_result);
        else
            presentMakoResults(guiHandles,'FAILURE',display_result);
        end

    end

%% Function to handle the close function request
    function closeGUI(varargin) 
        comm(hDmc,'RS');   % reset the controller and erase the existing program
        comm(hDmc,'AB');
        comm(hDmc,'MO');
        for i = 1:2
            delete(hDmc);
            pause(0.2)
        end
%         global safetyHandle;
%         if exist('safetyHandle','var')
%             close(safetyHandle.timer)
%             delete(safetyHandle.timer)
%         end
        closereq
        clear functions
        return
    end

%% Set motor defaults
    function set_motor_defaults(galilObj)
        
        % set controller parameters (General)
        set(galilObj, 'AG', 1);
        set(galilObj, 'ER', 1000); % error limit 1000 counts
        set(galilObj, 'SP', 10000000); %max speed, encoder counts per sec
        set(galilObj, 'AC', 67107839); % acceleration, 67107840 is the max value
        set(galilObj, 'DC', 67107839); % acceleration and deceleration 67107840 is the max value
        
        % set controller parameters (AXIS A)
        set(galilObj, 'SPA', 10000000); %max speed, encoder counts per sec
        set(galilObj, 'ACA', 67107839); % acceleration, 67107840 is the max value
        set(galilObj, 'DCA', 67107839); % acceleration and deceleration 67107840 is the max value
%         
        % set controller parameters (AXIS B)
        set(galilObj, 'SPB', 10000000); %max speed, encoder counts per sec
        set(galilObj, 'ACB', 67107839); % acceleration, 67107840 is the max value
        set(galilObj, 'DCB', 67107839); % acceleration and deceleration 67107840 is the max value


    end
%% End of test
end %/end for main function

%--------- END OF FILE -------------