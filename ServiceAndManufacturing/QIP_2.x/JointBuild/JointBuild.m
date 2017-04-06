function JointBuild(varargin)

% JointBuild, Performs cable tension propagation and transmission check
% of the RIO platform joints during the joint build stage of production
%
%   Syntax:
%       JointBuild
%
%   Notes:
%       No inputs required
%       Operation requires ReadJointConfiguration.m with nominal tension values
% 
% $Author: jscrivens $
% $Revision: 0001 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%


%% Main function: Initialize GUI and variables, connect to GALIL controller

% Generate MAKO GUIs
global guiHandles
% ask for traveller or kit ID
traveller = getMakoJobId;
% if user pressed cancel exit elegantly
if isempty(traveller)
    return;
end

guiHandles = generateMakoGui('Joint Build',[],['Joint ',traveller],0);
% set close request function
set(guiHandles.figure,'CloseRequestFcn',@closeGUI);
updateMainButtonInfo(guiHandles,'text','Connecting to controller...please wait');

% define properties of results window
resultsTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'HorizontalAlignment','left');

% Display 1, in the main UI panel
display1 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'Position',[0.02 0.7 .5 0.2],...
    'String','');%,...
%     'BackgroundColor',[.5 0.1 0.5]

% Display 2, in the main UI panel
DEFAULT_FONT_SIZE= 0.25; %#ok<NASGU>
display2 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'FontSize',.04,...
    'Position',[0.02 0.4 0.5 0.3],...
    'String','');

% Display 3, in the main UI panel
display3 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'FontSize',.10,...
    'Position',[0.02 0.05 0.5 0.35],...
    'String','');


exitbutton= uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'FontUnits', 'normalized',...
            'FontSize',0.2,...
            'Position',[0.55 0.40 0.430 0.25],...
            'String','Accept Joint Transmission Results',...
            'Visible','off',...
            'Callback',@closeGUI...
            );

propmorebutton= uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'FontUnits', 'normalized',...
            'FontSize',0.2,...
            'Position',[0.55 0.70 0.430 0.25],...
            'String','Click here to propagate and check transmission',...
            'Visible','off',...
            'Callback',@propagatetrans...
            );

freebutton = uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'FontUnits', 'normalized',...
            'FontSize',0.2,...
            'Position',[0.55 0.05 0.205 0.25],...
            'String','Free Motor',...
            'Visible','off',...
            'Callback',@freemotor...
            );

holdbutton = uicontrol(guiHandles.uiPanel,...
            'Style','pushbutton',...
            'Units','normalized',...
            'FontUnits', 'normalized',...
            'FontSize',0.2,...
            'Position',[0.775 0.05 0.205 0.25],...
            'String','Servo Hold',...
            'Visible','off',...
            'Callback',@servohold...
            );

%====================================================
% Initialize variables in the main function so that it can be accessed from
% all the sub function
%====================================================
joint = 0; %variable for motor id
MOTORDATA=[];
JOINTDATA=[];
results_file='';
results=[];
history=[];
transdata=[];
status='';
sim.posmlimm=0;
sim.negmlimm=0;
sim.posmlimj=0;
sim.negmlimj=0;
sim.results='Phase Lag        AmpRatio';

% Check if this is a compiled version and if the mcr folder exists
% adjust the base directory path accordingly.
% NOTE: The compiled version of the script assumes the mcr directory as
% the base directory. For file operations this has to be the base
% directory to which the relative paths are defined.
% NOTE: When bulding solo in Matlab, the basedir is JointBuild_mcr
% NOTE: When bulding the real deal, the basedir is QIPScriptsBin\JointBuild_mcr\JointBuild

MCR_DIR = 'QIPScriptsBin\JointBuild_mcr\JointBuild';
if exist(MCR_DIR,'dir')
    basedir = MCR_DIR;
else
    basedir = '.';
end

%================================================
%CONNECT TO THE CONTROLLER. LOAD DEFAULT VALUES
%================================================
%connect to controller using GALILConnect function
set(display2,'String','Connecting to controller...please wait');
hDmc = galil_mc('172.16.16.101');
% before using the controller, send abort command ('AO') to abort any
% pre-existing execution. Also, turn the motor off ('MO') for safety
comm(hDmc,'AB');
comm(hDmc,'MO');
comm(hDmc,'SB3'); %For enabling brake switch on Engineering controller 
                     %No effect on production controller
% get controller serial number
ControllerSerialNum = get(hDmc,'MG_BN'); 
if((isnan(ControllerSerialNum))||(ControllerSerialNum == -666.666))
    set(display2,'String',['Controller ERROR. Power cycle controller.' ,...
        num2str(ControllerSerialNum)]);
    % Unload the DMC library by running GALILDisconnect() function
    delete(hDmc);
    error('Controller fault. Power cycle controller')
end
% set controller parameters
set(hDmc,'ER', 1000); % error limit 1000 counts
set(hDmc,'SP', 10000000); % max speed, encoder counts per sec
set(hDmc,'AC', 67107839); % acceleration 67107840 is the max value
set(hDmc,'DC', 67107839); % deceleration 67107840 is the max value
% Display controller serial number in the results window
set(display2,'String', ['Connected to Controller: ',...
    num2str(ControllerSerialNum)]);

% Activate the main button to start motor testing
updateMainButtonInfo(guiHandles,'text','Select ROBOT Type');

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
                'RIO 2.2',...
				'RIO 3.0'},...
                'fontunits','normalized','fontsize',0.26,...
                'value',2);
handle_btnApp= uicontrol(guiHandles.uiPanel,'style','pushbutton',...
                'units','normalized','position',[0.4 0.38 0.2 0.1],...
                'string','OK','fontunits','normalized','fontsize',0.3,...
                'callback',@click_btnApp);

            
%% Create the button group for selecting joint            
%====================================================
% SELECT JOINT TO BE TESTED (JOINTS 1 TO 6)
%====================================================
% Create the button group.
handle_buttongroup = uibuttongroup(guiHandles.uiPanel,...
    'visible','off',...
    'Position',[0.5 0.1 .075 0.8]);
% Create radio button to select motor
yRange = 0.15;
ypos = 0.0;
for repeat = 6:-1:1
    u(repeat) = uicontrol(...
        'Style','Radio',...
        'String',[' ' num2str(repeat)],...
        'Units','normalized',...
        'Position',[.2, ypos, .4, .25],...
        'parent',handle_buttongroup,...
        'HandleVisibility','on',...
        'FontUnits','normalized',...
        'FontSize',0.2); %#ok<NASGU>
    ypos = ypos + yRange;
end

%% Setup ROBOT Application Type Callback
    function click_btnApp(hobj,evdata) %#ok<INUSD>
        apptype= get(handle_lstApp,'value');
   
        % hide the ROBOT type selection UIs
        set(handle_lstApp,'visible','off');
        set(handle_btnApp,'visible','off');
        set(display1,'string','Select Joint');
        
        % show ROBOT type and GALIL controller serial number
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
        
       % Update the main button to start motor testing
        updateMainButtonInfo(guiHandles,'text','Select Joint');
    end

%% Select Joint Callback
    function selcbk(source,eventdata) %#ok<INUSL>
        % refer matlab help doc on 'uibuttongroup' for more info
        joint = str2double(get(eventdata.NewValue,'string'));
        
        %======================================
        % FILE NAME FOR RESULTS, with joint tag
        %======================================
        % generate results data file name, and safe data file
        dataFileName=['JOINT-',...
            num2str(joint),'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        results_file = fullfile(guiHandles.reportsDir,dataFileName);

        % SET CONTROLLER TORQUE LIMIT AND GAINS, depending up on which
        % joint is selected
        TL = JOINTDATA.GALIL_TORQUELIMIT(joint);
        set(hDmc,'TL', TL); %torque limit
        
         % set controller gains
        % PID Transfer function (P+sD+I/s) where
        %    P= KP;  D= T*KD; I= KI/2/T;   T: Sampling Period
        %gains for J1,J2 and J3
        if joint == 1 || joint == 2 || joint == 3
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

        % Activate the main button to start motor testing
        updateMainButtonInfo(guiHandles,'pushbutton',...
            ['Click here to home Joint ',num2str(joint) ' and find limits'],...
            @home_joint);

    end

%% Home Joint
    function home_joint(varargin)

        % turn off the radio button group
        if exist('handle_buttongroup','var')
            set(handle_buttongroup,'Visible','off');
            delete(handle_buttongroup)
            clear('handle_buttongroup')
        end
        
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop');
        set(display1,'String','Homing Joint Encoder')%,...
                     %'fontsize',DEFAULT_FONT_SIZE);
        set(display2,'String', '');
        %get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);
        % go to bump stop
        goto_bs_vel(hDmc, -speed,basedir);
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
        comm(hDmc,'XQ#HOMEJ,0');
        % monitor result
        STATUS = 0;
        tic
        while (STATUS == 0)
            STATUS = get(hDmc,'DONE');
            % monitor time to exit after 24 sec. Like a timeout
            if(toc > 24)
                % display error message
                set(display2,'String','TIMEOUT. CANNOT SEE JOINT ENCODER INDEX');
                pause(1)
                % Abort execution (AB) and turn motor off (MO)
                comm(hDmc,'AB');
                comm(hDmc,'MO');
                presentMakoResults(guiHandles,'FAILURE','Joint Homing Failed');
                return
                STATUS = 1;
            end
        end
        % if index is read seen, get the current position of the joint by
        % using Tell Position (axis B) command, TPB
        currentpos = get(hDmc,'TPB');
        % display results
        set(display2,'String',{'Joint Homed';['Current Joint pos is ',num2str(currentpos)]});
        %Abort execution of homing script
        comm(hDmc,'AB');
        % Set motor and joint position as Zero
        set(hDmc,'DP', '0,0');
        % Turn off motor (MO)
        comm(hDmc,'MO');
        % Execute get limits function 
        getlimits;
    end

%% Get Limits Function
    function getlimits(varargin)

        % turn off the radio button group
        if exist('handle_buttongroup','var')
            set(handle_buttongroup,'Visible','off');
            delete(handle_buttongroup)
            clear('handle_buttongroup')
        end

        % update the main result window
        set(display1,'String', ['Finding JOINT ' num2str(joint) ' limits']);
        set(display1,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'))

        %update Main Button
        updateMainButtonInfo(guiHandles,'text','Finding Joint Limit');
        set(display2,'String','',...
            'fontsize',.15);
        set(display2,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'));

        % get jog speed from the configuration file
        speed = JOINTDATA.JOGSPEED(joint);
        %  Enable motor
        comm(hDmc,'SH');

        % go to bump stop 1, and measure position to get negative limit
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 1');
        goto_bs_vel(hDmc,-speed,basedir);
        pause(0.05);
        sim.neglimm = get(hDmc,'TPA');
        sim.neglimj = get(hDmc,'TPB');
        pause(0.05);
        % go to bump stop 2, and measure position to get positive limit
        updateMainButtonInfo(guiHandles,'text','Moving to bump stop 2');
        goto_bs_vel(hDmc,speed,basedir)
        pause(0.05)
        sim.poslimm = get(hDmc,'TPA');
        sim.poslimj = get(hDmc,'TPB');

        % get the joint encoder cpr data from the configuration file
        cpr_joint = JOINTDATA.CPR(joint);
        % convert the limits to degrees
        limit_neg = sim.neglimj*360/cpr_joint;
        limit_pos = sim.poslimj*360/cpr_joint;
        limit_range = (limit_pos-limit_neg);

        % Turn off motor
        comm(hDmc,'MO');
        
        % Make motor control buttons visible
        set(freebutton,'Visible','on');
        set(holdbutton,'Visible','on');

        % Display Results and Update Main Button
        set(display1,'String', '');
        set(display2,'String',{['Joint Limit Positive :' num2str(limit_pos)];...
            ['Joint Limit Negative :' num2str(limit_neg)];...
            ['Joint Range :'  num2str(limit_range) '°']});

        % Activate the main button for propagation and transmission test
        updateMainButtonInfo(guiHandles,'pushbutton',...
            ['Click Here to Propagate and Check Joint ' num2str(joint) ' Transmission'],...
            @propagatetrans);
    end
%% Propagation and Transmission Check Function
    function propagatetrans(varargin)
        % update Main Button
        updateMainButtonInfo(guiHandles,'text','Propagating Cable Tension');
        % update the main result window
        set(display1,'String', ['Propagating JOINT ' num2str(joint)]);
        set(display1,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'))
        set(display2,'String', '');
        set(display2,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'))
        
        set(propmorebutton,'Visible','off');
        set(exitbutton,'Visible','off','Callback',@closeGUI);
        set(freebutton,'Visible','off');
        set(holdbutton,'Visible','off');
        status='';

%% Propagate Cables
        % Set range limits
        range=(sim.poslimm-sim.neglimm)/2;
        center=(sim.poslimm+sim.neglimm)/2;
        poslim=center+range*.90;
        neglim=center-range*.90;
        
        % Enable motor in servo mode
        comm(hDmc,'SH');
        
        % Execute Vibrate Range of Motion Command
        % Parameters obtained from  the ReadJointConfiguration command
        vibrateROM(hDmc,JOINTDATA.PROPAGATE_FREQO(joint),...
            JOINTDATA.PROPAGATE_AMPO(joint),...
            JOINTDATA.PROPAGATE_GRCYCLS(joint),...
            neglim,poslim,...
            JOINTDATA.PROPAGATE_GROPER(joint),...
            JOINTDATA.PROPAGATE_STEPS(joint));
        
        % Wait for completion of the vibration cycle
        while ~get(hDmc,'DONE')
            pause(1)
        end
        pause(0.5)
        
        % Execute full ROM rotations 
        for x=1:JOINTDATA.PROPAGATE_BIGTURNS(joint)
            gotomotorpos(hDmc,floor(poslim));
            gotomotorpos(hDmc,floor(neglim));
        end

        pause(0.5)

%% Transmission Test
        % update the main result window
        updateMainButtonInfo(guiHandles,'text','String',sprintf('Measuring JOINT %i Transmission Phase Lag',joint));
        set(display1,'String', '');

        % Check transmission using the transmissioncheck_qip.m script
        [phase_lag amplitude_ratio transmissiondata] = transmissioncheck_qip(hDmc,joint,basedir);

        % Turn off motor
        comm(hDmc,'MO');

%% Display Transmission Test Results
        % display results of the transmission check
        nominal= JOINTDATA.TRANSMISSION_NOMINAL(joint);
        warning= JOINTDATA.TRANSMISSION_WARNING(joint);
        limit= JOINTDATA.TRANSMISSION_LIMIT(joint);
        
        history = [history;phase_lag];
        transdata = [transdata, transmissiondata];
        sim.results=[sim.results,...
            sprintf('\n   % 3.1f°                  %1.2f' ,phase_lag*180/pi, amplitude_ratio)];
        set(display1,'String', '');
        set(display2, 'String',...
            {sprintf('Joint %1.0f Phase Lag : %4.3f(rad)    % 4.1f° \n',...
            joint,phase_lag,phase_lag*180/pi);...
            sprintf('Joint %1.0f Nominal    : %4.3f(rad)    % 4.1f°',...
            joint,nominal,nominal*180/pi);...
            sprintf('Joint %1.0f Warning    : %4.3f(rad)    % 4.1f°',...
            joint,warning,warning*180/pi);...
            sprintf('Joint %1.0f Limit          : %4.3f(rad)    % 4.1f°',...
            joint,limit,limit*180/pi)});
        set(display3,'String', sim.results);
        
        results.joint=joint;
        results.nominal=nominal;
        results.warning=warning;
        results.limit=limit;
        results.phaselag=phase_lag;
        results.phasehistory=history;
        results.transmissiondata=transdata;

        % Display appropriate result color
        if phase_lag>=limit
            status='FAILURE';
            set(display1,'String', sprintf('Transmission Check Failed \nTighten Transmission Cables'));
            set(display1,'BackgroundColor','red');
            % Set the main button to redo propagation and transmission test
            updateMainButtonInfo(guiHandles,'pushbutton',...
                ['Click Here to Propagate and Check Joint ' num2str(joint) ' Transmission'],...
                @propagatetrans);
            set(exitbutton,'Visible','on','Callback',@savenexit);
            
        else if phase_lag>=warning
            status='WARNING';
            set(display1,'String',...
                sprintf('Transmission Check Warning \nTighten Transmission Cables'));
            set(display1,'BackgroundColor','yellow');
            % Set the main button to redo propagation and transmission test
            updateMainButtonInfo(guiHandles,'pushbutton',...
                ['Click Here to Propagate and Check Joint ' num2str(joint) ' Transmission'],...
                @propagatetrans);
            set(exitbutton,'Visible','on','Callback',@savenexit);
            else
                status='SUCCESS';
                set(display1,'String', sprintf('Transmission in Nominal Range'));
                set(display1,'BackgroundColor','green');
                % Set the main button to exit the script
                updateMainButtonInfo(guiHandles,'pushbutton',...
                    ['Click Here to Accept Joint ' num2str(joint) ' Transmission Results'],...
                    @savenexit);
                set(propmorebutton,'Visible','on');
            end
        end
        
        set(freebutton,'Visible','on');
        set(holdbutton,'Visible','on');
        
    end % end of the propagation function

%% Embedded functions
% Free motor
    function freemotor(varargin)
        comm(hDmc,'MO');
    end

% Hold position
    function servohold(varargin)
        comm(hDmc,'SH');
    end

% Goto motor position
    function gotomotorpos(galilObj,position)
        comm(galilObj,'AB');
        speed=get(galilObj,'SP');
        set(galilObj,'PA', position); % 67228
        set(galilObj,'SP', 275000);
        comm(galilObj,'BGA');
        moving=1;
        while moving
            pause(.5);
            moving=get(galilObj,'MG _BGA');
        end
        set(galilObj,'SP', speed);
        comm(galilObj,'AB');
    end

%% Function to Save and Exit
    function savenexit(varargin)
        save (results_file,'results');
        set(propmorebutton,'Visible','off');
        set(exitbutton,'Visible','off');
        presentMakoResults(guiHandles,status,sprintf(['Final Joint %i Phase Lag %2.1f°\n'...
            'Nominal Phase Lag %2.1f° (Limit %2.1f°)'],...
            joint,results.phaselag*180/pi,results.nominal*180/pi,results.limit*180/pi))
        set(freebutton,'Visible','off');
        set(holdbutton,'Visible','off');
    end

%% Function to handle the close function request

    function closeGUI(varargin) 
        comm(hDmc,'AB');
        pause(0.2)
        comm(hDmc,'MO');
        pause(0.1)
        delete(hDmc);
        pause(0.2)
        closereq
        clear functions
        return
    end

%% End of test
end % End of main function

%--------- END OF FILE -------------