function PropagateSystem(hgs,varargin)
% PropagateSystem, Performs cable tension propagation and transmission
% check on the joints of the system level RIO platform. This script is to
% be used to facilitate tensioning of joint cables.
%
%   Syntax:
%       PropagateSystem
%
%   Notes:
%       No inputs required
%       Tension limit values presented here should mimic values used the
%       the TransmissionCheck script.
%
% $Author: jscrivens $
% $Revision: 0001 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%



%% PASS CRITERION
% This pass criteria should duplicate values in the TransmissionCheck script
% The pass criteria for Knee and Hip Systems have been revised based on
% collected transmission data from multiple RIO units.
% Refer to Engineering study ES-ROB-0080 for details
% Refer to Engineering study ES-ROB-0204 for details (for J6 on RIO 2.2 and higher).

% V2.0 System Limits
PHASE_LIMITS.V2_0=   [22.9   9.4   5.7  13.7   3.1   6.7]*pi/180;
PHASE_WARNINGS.V2_0= [18.6   8.7   3.8  12.1   2.4   5.7]*pi/180;
PHASE_NOMINALS.V2_0= [14.3   7.9   3.1  10.4   1.7   5.4]*pi/180;
AMP_LIMITS.V2_0=     [0.87  0.56  0.94  0.34  0.95  1.00];

% V2.1 System Limits
PHASE_LIMITS.V2_1=   [18.9   10.3  5.6   15.7  1.5   22.7]*pi/180;
PHASE_WARNINGS.V2_1= [16.2   09.2  4.5   14.0  1.2   20.6]*pi/180;
PHASE_NOMINALS.V2_1= [13.4   08.2  3.4   12.3  0.9   16.3]*pi/180;
AMP_LIMITS.V2_1=   [0.89   0.79  0.95  0.69  0.97  1.01];

% V2.2 System Limits
PHASE_LIMITS.V2_2=   [18.9   10.3  5.6   15.7  1.5   22.7]*pi/180;
PHASE_WARNINGS.V2_2= [16.2   09.2  4.5   14.0  1.2   20.6]*pi/180;
PHASE_NOMINALS.V2_2= [13.4   08.2  3.4   12.3  0.9   16.3]*pi/180;
AMP_LIMITS.V2_2=   [0.89   0.79  0.95  0.69  0.97  1.01];

% V2.3 System Limits
PHASE_LIMITS.V2_3=   [18.9   10.3  5.6   15.7  1.5   22.7]*pi/180;
PHASE_WARNINGS.V2_3= [16.2   09.2  4.5   14.0  1.2   20.6]*pi/180;
PHASE_NOMINALS.V2_3= [13.4   08.2  3.4   12.3  0.9   16.3]*pi/180;
AMP_LIMITS.V2_3=   [0.89   0.79  0.95  0.69  0.97  1.01];

% V3.0 System Limits
PHASE_LIMITS.V3_0=   [18.9   10.3  5.6   15.7  1.5   22.7]*pi/180;
PHASE_WARNINGS.V3_0= [16.2   09.2  4.5   14.0  1.2   20.6]*pi/180;
PHASE_NOMINALS.V3_0= [13.4   08.2  3.4   12.3  0.9   16.3]*pi/180;
AMP_LIMITS.V3_0=   [0.89   0.79  0.95  0.69  0.97  1.01];

% V3.1 System Limits
PHASE_LIMITS.V3_1=   [18.9   10.3  5.6   15.7  1.5   22.7]*pi/180;
PHASE_WARNINGS.V3_1= [16.2   09.2  4.5   14.0  1.2   20.6]*pi/180;
PHASE_NOMINALS.V3_1= [13.4   08.2  3.4   12.3  0.9   16.3]*pi/180;
AMP_LIMITS.V3_1=   [0.89   0.79  0.95  0.69  0.97  1.01];	


% default limit is V3.1
PHASE_LIMIT= PHASE_LIMITS.V3_1;
PHASE_WARNING= PHASE_WARNINGS.V3_1;
PHASE_NOMINAL= PHASE_NOMINALS.V3_1;
AMP_LIMIT=   AMP_LIMITS.V3_1;

%connect to robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
    defaultRobotConnection = true;
end

%set proper limit
version = hgs.ARM_HARDWARE_VERSION;

switch int32(version * 10 + 0.05)
    case 20 % 2.0
        TRANSMISSION_LIMIT= PHASE_LIMITS.V2_0;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V2_0;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V2_0;
        AMP_LIMIT=   AMP_LIMITS.V2_0;                 %#ok<NASGU>
    case 21 % 2.1
        TRANSMISSION_LIMIT= PHASE_LIMITS.V2_1;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V2_1;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V2_1;
        AMP_LIMIT=   AMP_LIMITS.V2_1; %#ok<NASGU>
    case 22 % 2.2
        TRANSMISSION_LIMIT= PHASE_LIMITS.V2_2;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V2_2;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V2_2;
        AMP_LIMIT=   AMP_LIMITS.V2_2; %#ok<NASGU>
    case 23 % 2.3
        TRANSMISSION_LIMIT= PHASE_LIMITS.V2_3;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V2_3;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V2_3;
        AMP_LIMIT=   AMP_LIMITS.V2_3; %#ok<NASGU>
    case 30 % 3.0
        TRANSMISSION_LIMIT= PHASE_LIMITS.V3_0;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V3_0;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V3_0;
        AMP_LIMIT=   AMP_LIMITS.V3_0; %#ok<NASGU>
    case 31 % 3.1
        TRANSMISSION_LIMIT= PHASE_LIMITS.V3_1;
        TRANSMISSION_WARNING= PHASE_WARNINGS.V3_1;
        TRANSMISSION_NOMINAL= PHASE_NOMINALS.V3_1;
        AMP_LIMIT=   AMP_LIMITS.V3_1; %#ok<NASGU>
    otherwise
        tex = sprintf(...
            'Invalid hardware version %.1f, exiting script...',version);
        h = msgbox(tex);
        return;
end
%Propagation Time
proptime=30;%seconds

userCancel=false;

%% Main function: Initialize GUI and variables

% Generate MAKO GUIs
global guiHandles
scriptName = 'PropagateSystem';
guiHandles = generateMakoGui(scriptName,[],hgs);
log_message(hgs,'Propogate System Started');

% set close request function
set(guiHandles.figure,'CloseRequestFcn',@closeGUI);

updateMainButtonInfo(guiHandles,'pushbutton',...
    'Click Here to Start Propagation of System Joints',@START);

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
    'String','');

% Display 2, in the main UI panel
display2 = uicontrol(guiHandles.uiPanel,...
    resultsTextProperties,...
    'FontSize',.15,...
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
    'String','Click Here to Accept Joint Transmission Results',...
    'Visible','off',...
    'Callback',@closeGUI...
    );

propmorebutton= uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','normalized',...
    'FontUnits', 'normalized',...
    'FontSize',0.2,...
    'Position',[0.55 0.70 0.430 0.25],...
    'String','Click here to Propagate and Check Joint Transmission',...
    'Visible','off',...
    'Callback',@propagatetrans...
    );

freebutton = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','normalized',...
    'FontUnits', 'normalized',...
    'FontSize',0.2,...
    'Position',[0.55 0.05 0.205 0.25],...
    'String','Free Joints',...
    'Visible','off',...
    'Callback',@freemotor...
    );

holdbutton = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units','normalized',...
    'FontUnits', 'normalized',...
    'FontSize',0.2,...
    'Position',[0.775 0.05 0.205 0.25],...
    'String','Hold Joints',...
    'Visible','off',...
    'Callback',@servohold...
    );

%====================================================
% Initialize variables in the main function so that it can be accessed
% from all sub functions
%====================================================
joint = 0; %variable for motor id
resultdisplay='Phase Lag        AmpRatio';
results_file='';
results=[]; phistory=[]; ahistory=[]; thistory=[];
joint=[]; nominal=[]; warning=[]; limit=[];
status='';

%====================================================
% SELECT JOINT TO BE TESTED (JOINTS 1 TO 6)
%====================================================
% Create the button group.
handle_buttongroup = uibuttongroup(guiHandles.uiPanel,...
    'visible','off',...
    'Position',[0.5 0.0 .1 0.82]);
% Create radio button to select motor
yRange = 0.18;
ypos = 0.0;
for repeat = 6:-1:1
    u(repeat) = uicontrol(...
        'Style','Radio',...
        'String',num2str(repeat),...
        'Units','normalized',...
        'Position',[.2, ypos, .4, .3],...
        'parent',handle_buttongroup,...
        'HandleVisibility','on',...
        'FontUnits','normalized',...
        'FontSize',0.15); %#ok<NASGU>
    ypos = ypos + yRange;
end

    function START(varargin)
        % Activate the main button to start motor testing
        updateMainButtonInfo(guiHandles,'text','Select Joint');
        
        % Initialize some button group properties.
        set(handle_buttongroup,'SelectionChangeFcn',@selcbk);
        set(handle_buttongroup,'SelectedObject',[]);  % No selection
        set(handle_buttongroup,'Visible','on');
    end

%% Select Joint Callback
    function selcbk(source,eventdata) %#ok<INUSL>
        % refer matlab help doc on 'uibuttongroup' for more info
        joint = str2double(get(eventdata.NewValue,'string'));
        
        %======================================
        % FILE NAME FOR RESULTS, with joint tag
        %======================================
        % generate results data file name, and safe data file
        dataFileName=['Propagation-J',...
            num2str(joint),'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        results_file = fullfile(guiHandles.reportsDir,dataFileName);
        
        % Activate the main button for propagation and transmission test
        updateMainButtonInfo(guiHandles,'pushbutton',...
            ['Click Here to Adjust Joint ' num2str(joint) ' Transmission'],...
            @commit_joint);
    end

%% Commit Joint
    function commit_joint(varargin)
        % Commits joint selection and removes Joint selection option
        set(handle_buttongroup,'Visible','off');
        % Make motor control buttons visible
        set(freebutton,'Visible','on');
        set(holdbutton,'Visible','on');
        % Display Results and Update Main Button
        set(display1,'String', '');
        set(display2,'String', '');
        
        % Obtain joint appropriate nominal, warning, and limit values
        nominal= TRANSMISSION_NOMINAL(joint);
        warning= TRANSMISSION_WARNING(joint);
        limit= TRANSMISSION_LIMIT(joint);
        results.joint       =joint;
        results.nominal     =nominal;
        results.warning     =warning;
        results.limit       =limit;
        
        % Activate the main button for propagation and transmission test
        updateMainButtonInfo(guiHandles,'pushbutton',...
            sprintf('Click Here to Propagate and Check Joint %i Transmission',joint),...
            @propagatetrans);
        % Set text to display proper joint number
        set(propmorebutton,'String',...
            sprintf('Propagate and Check Joint %i Transmission',joint),...
            'Visible','off');
        set(exitbutton,'String',...
            sprintf('Accept Joint %i Transmission Results',joint),...
            'Visible','off');
        
    end
%% Propagation and Transmission Check Function
    function propagatetrans(varargin)
        try
            % Check if the robot is enabled if not go into the enable
            % procedure.
            if hgs.arm_status ~= 1
                if ~robotFrontPanelEnable(hgs,guiHandles)
                    % log the failure of the procedure
                    log_message(hgs,'System Propagation failed to enable robotic arm.');
                    return;
                end
            end
            
            
            % Update Displays
            % update Main Button
            updateMainButtonInfo(guiHandles,'text',sprintf('Propagating JOINT %i Transmission',joint));
            % update the main result window
            set(display1,'String',''); % ['Propagating JOINT ' num2str(joint)]);
            set(display1,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'))
            set(display2,'String', '');
            set(display2,'BackgroundColor',get(guiHandles.uiPanel,'BackgroundColor'))
            
            set(propmorebutton,'Visible','off');
            set(exitbutton,'Visible','off','Callback',@closeGUI);
            set(freebutton,'Visible','off');
            set(holdbutton,'Visible','off');
            status='';
            
            % Propagate Cables
            if joint==3
                go_to_position(hgs,[0 -1 0 pi*.8 0 0],0.5);
            else
                go_to_position(hgs,[0 -pi/2 0 pi*.8 0 0],0.5);
            end
            % Propagate Cables using the Propagate0.m script
            Propagate0(hgs,joint);
            
            %check if time expires or user cancel button is pressed
            tic
            while(toc<proptime)
                if userCancel
                    return;
                end
                pause(0.5)
            end
            
            % Transmission Test
            % update the main result window
            updateMainButtonInfo(guiHandles,'text','String',sprintf('Measuring JOINT %i Transmission Phase Lag',joint));
            set(display1,'String','');
            
            % Check transmission using the Transmission1Joint.m script
            [phase_lag amplitude_ratio transmissiondata] = Transmission1Joint(hgs,'joint',joint,'collect');
            %         [phase_lag amplitude_ratio transmissiondata] = Transmission1Joint(hgs,'joint',joint);
            
            % Display Transmission Test Results
            phistory = [phistory;phase_lag];
            ahistory = [ahistory;amplitude_ratio];
            thistory = [thistory transmissiondata];
            resultdisplay=[resultdisplay,...
                sprintf('\n   % 3.1f°                  %1.2f' ,...
                phase_lag*180/pi, amplitude_ratio)];
            set(display1,'String', '');
            set(display2, 'String',...
                {sprintf('Joint %1.0f Phase Lag :   % 4.1f° \n',...
                joint,phase_lag*180/pi);...
                sprintf('Joint %1.0f Nominal    :   % 4.1f°',...
                joint,nominal*180/pi);...
                sprintf('Joint %1.0f Warning    :   % 4.1f°',...
                joint,warning*180/pi);...
                sprintf('Joint %1.0f Limit         :   % 4.1f°',...
                joint,limit*180/pi)});
            set(display3,'String', resultdisplay);
            
            results.phaselag    =phase_lag;
            results.phasehistory=phistory;
            results.amphistory  =ahistory;
            results.transmissiondata=thistory;
            
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
                    % Set the main button to accept resultst
                    updateMainButtonInfo(guiHandles,'pushbutton',...
                        ['Click Here to Accept Joint ' num2str(joint) ' Transmission Results'],...
                        @savenexit);
                    set(propmorebutton,'Visible','on');
                end
            end
            
            set(freebutton,'Visible','on');
            set(holdbutton,'Visible','on');
        catch %#ok<CTCH>
            if userCancel
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',lasterr); %#ok<LERR>
            end
        end
        
    end % end of the propagation and check function

%% Embedded functions
% Free motor
    function freemotor(varargin)
        mode(hgs, 'zerogravity','ia_hold_enable',1);
    end

% Hold position
    function servohold(varargin)
        stop(hgs);
    end

%% Function to Save and Exit
    function savenexit(varargin)
        save (results_file,'results');
        set(propmorebutton,'Visible','off');
        set(exitbutton,'Visible','off');
        set(freebutton,'Visible','off');
        set(holdbutton,'Visible','off');
        presentMakoResults(guiHandles,status,sprintf(['Final Joint %i Phase Lag %2.1f°\n'...
            'Nominal Phase Lag %2.1f° (Limit %2.1f°)'],...
            joint,results.phaselag*180/pi,results.nominal*180/pi,results.limit*180/pi))
    end

%% Function to handle the close function request

    function closeGUI(varargin) % global safetyHandle;
        userCancel=true;
        mode(hgs,'zerogravity','ia_hold_enable',1);
        pause(.2)
        log_message(hgs,'Propogate System Closed');
        if defaultRobotConnection
            close(hgs);
        end
        closereq
        clear functions
        return
    end

%% End of test
end % End of main function

%--------- END OF FILE -------------
