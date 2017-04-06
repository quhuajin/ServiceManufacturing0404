function guiHandles = TransmissionCheck(hgs)

%TransmissionCheck Gui to joint drive transmissions on the Hgs Robot.
%
% Syntax:
%   TransmissionCheck(hgs)
%       Starts the transmission check GUI for performing transmission check
%       on the hgs robot defined by the argument hgs.
%
% Notes:
%   the transmission check procedure oscillates the motor of each joint
%   while measuring both motor and joint angles. It then calculates the
%   phase lag between the motor and joint angles. The measured pase lag is
%   the result of compliance in the drive transmission system. Excessive
%   phase lag above the established limit is an indication of reduced
%   cable tension.
%
% See also:
%   hgs_robot
%
%
% $Author: hqu $
% $Revision: 4159 $
% $Date: 2017-03-31 15:28:51 -0400 (Fri, 31 Mar 2017) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles = '';
        return;
    end
end

%% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: home_hgs argument must be an hgs_robot object');
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

%% Setup Script Identifiers for generic GUI
scriptName = 'Transmission Check';
guiHandles = generateMakoGui(scriptName,[],hgs);
log_message(hgs,'Transmission Check Script Started');

% Setup the main function
set(guiHandles.mainButtonInfo,'CallBack',@TRANSMISSION_TEST);

%override the default close callback for clean exit.
set(guiHandles.figure,'closeRequestFcn',@TRANSMISSION_TEST_CLOSE);

% Setup close test variable
close_test=false;

%% PASS CRITERION
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

%% TEST PARAMETERS

% V2.0 Test Parameters
vib_freqH.V2_0= [10    12   10   13   30   30]; % vib_freqH
vib_amp.V2_0=   [.002 .002 .002 .005 .005 .005]; % vib_amp

% V2.1 Test Parameters
vib_freqH.V2_1= [10    12   10   13   30   30]; % vib_freqH
vib_amp.V2_1=   [.002 .002 .002 .005 .005 .005]; % vib_amp

% V2.2 Test Parameters
vib_freqH.V2_2= [10    12   10   13   30   55]; % vib_freqH
vib_amp.V2_2=   [.002 .002 .002 .005 .005 .05]; % vib_amp

% V2.3 Test Parameters
vib_freqH.V2_3= [10    12   10   13   30   55]; % vib_freqH
vib_amp.V2_3=   [.002 .002 .002 .005 .005 .05]; % vib_amp

% V3.0 Test Parameters
vib_freqH.V3_0= [10    12   10   13   30   55]; % vib_freqH
vib_amp.V3_0=   [.002 .002 .002 .005 .005 .05]; % vib_amp

% V3.1 Test Parameters
vib_freqH.V3_1= [10    12   10   13   30   55]; % vib_freqH
vib_amp.V3_1=   [.002 .002 .002 .005 .005 .05]; % vib_amp


% default test parameters is V2.1
ON.vib_freqH= vib_freqH.V2_1; % vib_freqH
ON.vib_amp= vib_amp.V2_1; % vib_amp

dof = hgs.WAM_DOF;

off.gross_freqH(1:dof)  =0.001;
off.vib_freqH(1:dof)    =0.00001;
off.vib_amp(1:dof)      =0.000001;
off.torque_gain(1:dof)  =1.0;

ON.gross_freqH=[1 1 1 1 1 1]*.001; %gross_freqH
ON.torque_gain= [1 1 1 1 1 1]; % torque_gain

testpositions=[ 0 -pi/2 0 pi*.8 0 0;...
    0 -pi*.45 0 pi*.45 0 0;...
    0 -pi/2 0 pi/2 0 0;...
    0 -pi/2 pi/2 pi/2 0 0;...
    0 -pi/2 0 pi/2 0 0;...
    0 -pi/2 pi/2 pi/2 0 0];


%%  GUI Setup

% Setup boundries for homing boxes
xMin = 0.02;
xRange = 0.96;
spacing = 0.01;

commonBoxProperties = struct(...
    'Style','text',...
    'Units','Normalized',...
    'BackgroundColor',[204 204 204]/255,...
    'FontUnits','normalized',...
    'SelectionHighlight','off',...
    'Enable','Inactive');

for i=1:dof
    % Construct Joint Label Boxes
    yRange = 0.15;
    yMin = 0.70;
    boxPosition = [xMin+(xRange+spacing)*(i-1)/dof,...
        yMin+spacing,...
        xRange/dof-spacing,...
        yRange];
    jeBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'Position',boxPosition,...
        'FontWeight','normal','FontSize',0.4,...
        'String',sprintf('J%d',i)); %#ok<AGROW>
    
    % Construct Joint Result Boxes
    yRange = 0.2;
    yMin = 0.5;
    boxPosition = [xMin+(xRange+spacing)*(i-1)/dof,...
        yMin+spacing,...
        xRange/dof-spacing,...
        yRange];
    resultBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'FontWeight','bold','FontSize',0.75,...
        'Position',boxPosition);%#ok<AGROW> %,...
    
    % Construct Joint Limit Boxes
    yRange = 0.25;
    yMin = 0.25;
    boxPosition = [xMin+(xRange+spacing)*(i-1)/dof,...
        yMin+spacing,...
        xRange/dof-spacing,...
        yRange];
    limitsBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'FontWeight','bold','FontSize',0.2,...
        'Position',boxPosition);%#ok<AGROW> %,...
end

%% More startup variables
%--------------------------------------------------------------------------
% Primary Transmission check function. Executes on Start Test button press
%--------------------------------------------------------------------------
    function TRANSMISSION_TEST(varargin)
        
        %Check for robot status first
        try
            robotFrontPanelEnable(hgs,guiHandles);
        catch exception
            presentMakoResults(guiHandles,'FAILURE',exception.message);
            log_results(hgs,guiHandles.scriptName,'FAIL',...
                sprintf('Transmission Check Failed: %s',exception.message));
            return;
        end
        
        %set proper limits and test parameters
        version = hgs.ARM_HARDWARE_VERSION;
        
        switch int32(version * 10 + 0.05)
            case 20 % 2.0
                PHASE_LIMIT= PHASE_LIMITS.V2_0;
                PHASE_WARNING= PHASE_WARNINGS.V2_0;
                PHASE_NOMINAL= PHASE_NOMINALS.V2_0;
                AMP_LIMIT=   AMP_LIMITS.V2_0;
                ON.vib_freqH= vib_freqH.V2_0; % vib_freqH
                ON.vib_amp= vib_amp.V2_0; % vib_amp            
            case 21 % 2.1
                PHASE_LIMIT= PHASE_LIMITS.V2_1;
                PHASE_WARNING= PHASE_WARNINGS.V2_1;
                PHASE_NOMINAL= PHASE_NOMINALS.V2_1;
                AMP_LIMIT=   AMP_LIMITS.V2_1;
                ON.vib_freqH= vib_freqH.V2_1; % vib_freqH
                ON.vib_amp= vib_amp.V2_1; % vib_amp
            case 22 % 2.2
                PHASE_LIMIT= PHASE_LIMITS.V2_2;
                PHASE_WARNING= PHASE_WARNINGS.V2_2;
                PHASE_NOMINAL= PHASE_NOMINALS.V2_2;
                AMP_LIMIT=   AMP_LIMITS.V2_2;
                ON.vib_freqH= vib_freqH.V2_2; % vib_freqH
                ON.vib_amp= vib_amp.V2_2; % vib_amp
            case 23 % 2.3
                PHASE_LIMIT= PHASE_LIMITS.V2_3;
                PHASE_WARNING= PHASE_WARNINGS.V2_3;
                PHASE_NOMINAL= PHASE_NOMINALS.V2_3;
                AMP_LIMIT=   AMP_LIMITS.V2_3;
                ON.vib_freqH= vib_freqH.V2_3; % vib_freqH
                ON.vib_amp= vib_amp.V2_3; % vib_amp
            case 30 % 3.0
                PHASE_LIMIT= PHASE_LIMITS.V3_0;
                PHASE_WARNING= PHASE_WARNINGS.V3_0;
                PHASE_NOMINAL= PHASE_NOMINALS.V3_0;
                AMP_LIMIT=   AMP_LIMITS.V3_0;
                ON.vib_freqH= vib_freqH.V3_0; % vib_freqH
                ON.vib_amp= vib_amp.V3_0; % vib_amp
            case 31 % 3.1
                PHASE_LIMIT= PHASE_LIMITS.V3_1;
                PHASE_WARNING= PHASE_WARNINGS.V3_1;
                PHASE_NOMINAL= PHASE_NOMINALS.V3_1;
                AMP_LIMIT=   AMP_LIMITS.V3_1;
                ON.vib_freqH= vib_freqH.V3_1; % vib_freqH
                ON.vib_amp= vib_amp.V3_1; % vib_amp
            otherwise
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unsupported Robot version: V%2.1f',version));
                 log_results(hgs,guiHandles.scriptName,'FAIL',...
                sprintf('Transmission Check Failed. Unsupported Robot version: V%2.1f',version));
            return;
        end
        
        set(guiHandles.mainButtonInfo,'CallBack',@STOP_TEST);
        
        for joint=1:dof
            try
                if ~close_test
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Moving to test position Joint %d',joint));
                    
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Moving to test position Joint %d',joint));
                    
                    target=testpositions(joint,:);
                    go_to_position(hgs,target,.2)
                    
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Transmission Testing Joint %d',joint));
                    
                    run=SetVariables(off, ON, joint);
                    Transflag = RunTransmissionCheck(hgs,run,guiHandles);
                    if Transflag
                        presentMakoResults(guiHandles,'FAILURE',hgs.vibrate_move.mode_error);
                       err_msg = cellstr(hgs.vibrate_move.mode_error);
                        log_results(hgs,guiHandles.scriptName,'FAIL',...
                            ['Transmission Check Failed: ' err_msg{:}]);

                        return;
                    end
                    transdat=CALCULATE_PHASE(hgs,run);
                    transmissiondata(joint)=transdat; %#ok<AGROW>
                    
                    PHASE_LAG=transmissiondata(joint).phase_lag;
                    AMP_RATIO=transmissiondata(joint).amplitude_ratio;
                    LIMIT=PHASE_LIMIT(joint);
                    WARNING=PHASE_WARNING(joint);
                    NOMINAL=PHASE_NOMINAL(joint);
                    
                    %%%% FAILURE - Above Limit
                    if PHASE_LAG>=LIMIT
                        set(jeBox(joint),'BackgroundColor','red',...
                            'String',sprintf('J%i\nPhase-Lag',joint));
                        set(resultBox(joint),'BackgroundColor','red',...
                            'String',sprintf('%4.1f%c',...
                            [PHASE_LAG*180/pi 176]));
                        set(limitsBox(joint),'BackgroundColor','red',...
                            'String',sprintf(['Limits\n',...
                            'Nominal %4.1f%c\n',...
                            'Warning %4.1f%c\n',...
                            'Failure %4.1f%c'],...
                            [NOMINAL*180/pi 176],WARNING*180/pi,176,LIMIT*180/pi,176));
                        transmissiondata(joint).passfail='FAIL'; %#ok<AGROW>
                        passfail(joint,1)=2; %#ok<AGROW>
                        measures(joint,1,1)=PHASE_LAG; %#ok<AGROW>
                        measures(joint,1,2)=LIMIT; %#ok<AGROW>
                        measures(joint,2,1)=AMP_RATIO; %#ok<AGROW>
                        measures(joint,2,2)=AMP_LIMIT(joint); %#ok<AGROW>
                        if PHASE_LAG>LIMIT
                            %failure is due to Phase_lag
                            passfail(joint,2)=2; %#ok<AGROW>
                        else
                            % Failure is due to Amp_ratio
                            % Not currently used. Failures only due to Phase Lag
                            passfail(joint,2)=2; %#ok<AGROW>
                        end
                        
                        %%%% WARNING - Above Warning
                    else if PHASE_LAG>=WARNING
                            set(jeBox(joint),'BackgroundColor','yellow',...
                                'String',sprintf('J%i\nPhase-Lag',joint));
                            set(resultBox(joint),'BackgroundColor','yellow',...
                                'String',sprintf('%4.1f%c',...
                                [PHASE_LAG*180/pi 176]));
                            set(limitsBox(joint),'BackgroundColor','yellow',...
                                'String',sprintf(['Limits\n',...
                                'Nominal %4.1f%c\n',...
                                'Warning %4.1f%c\n',...
                                'Failure %4.1f%c'],...
                                [NOMINAL*180/pi 176],WARNING*180/pi,176,LIMIT*180/pi,176));
                            transmissiondata(joint).passfail='WARNING'; %#ok<AGROW>
                            passfail(joint,1)=1; %#ok<AGROW>
                            measures(joint,1,1)=PHASE_LAG; %#ok<AGROW>
                            measures(joint,1,2)=LIMIT; %#ok<AGROW>
                            measures(joint,2,1)=AMP_RATIO; %#ok<AGROW>
                            measures(joint,2,2)=AMP_LIMIT(joint); %#ok<AGROW>
                            
                            %%%% SUCCESS - Below Warning
                        else
                            set(jeBox(joint),'BackgroundColor','green',...
                                'String',sprintf('J%i\nPhase-Lag',joint));
                            set(resultBox(joint),'BackgroundColor','green',...
                                'String',sprintf('%4.1f%c',...
                                [PHASE_LAG*180/pi 176]));
                            set(limitsBox(joint),'BackgroundColor','green',...
                                'String',sprintf(['Limits\n',...
                                'Nominal %4.1f%c\n',...
                                'Warning %4.1f%c\n',...
                                'Failure %4.1f%c'],...
                                [NOMINAL*180/pi 176],WARNING*180/pi,176,LIMIT*180/pi,176));
                            transmissiondata(joint).passfail='PASS'; %#ok<AGROW>
                            passfail(joint,1)=0; %#ok<AGROW>
                            measures(joint,1,1)=PHASE_LAG; %#ok<AGROW>
                            measures(joint,1,2)=LIMIT; %#ok<AGROW>
                            measures(joint,2,1)=AMP_RATIO; %#ok<AGROW>
                            measures(joint,2,2)=AMP_LIMIT(joint); %#ok<AGROW>
                        end
                    end
                else
                    break
                end
            catch exception
                if ~close_test
                    presentMakoResults(guiHandles,'FAILURE',exception.message);
                    log_results(hgs,guiHandles.scriptName,'FAIL',...
                            sprintf('Transmission Check Failed: %s',exception.message));
                end
                return
            end
        end
        
        % check if this was a forced exit from the loop.
        % if so exit immediately
        if close_test
            return;
        end
        
        %Present Results to GUI
        try
            failed_joints=find(passfail(:,1)==2);
            warning_joints=find(passfail(:,1)==1);
            result.result='';
            result.failed_joints=failed_joints;
            result.warning_joints=warning_joints;
            result.phase_lag=measures(:,1,1);
            result.phase_limit=measures(:,1,2);
            result.amp_ratio=measures(:,2,1);
            result.amp_limit=measures(:,2,2);
            
            TRANSMISSION_FAIL=2;TRANSMISSION_WARNING=1;TRANSMISSION_PASS=0;
            
            RESULT_CASE=TRANSMISSION_FAIL;% (Default Result)
            
            if max(passfail(:,1))<2
                RESULT_CASE=TRANSMISSION_WARNING;
            end
            
            if max(passfail(:,1))<1
                RESULT_CASE=TRANSMISSION_PASS;
            end
            LogResults.Phaselag = result.phase_lag;
            LogResults.PhaselagLimit = result.phase_limit;
            
            switch RESULT_CASE
                case TRANSMISSION_FAIL
                    result.result='FAIL';
                    returnMessage={['FAILED ' sprintf(' Joint %d ',failed_joints)]};
                    if ~isempty(warning_joints)
                        returnMessage=[returnMessage,...
                            {['WARNING ' sprintf(' Joint %d ',warning_joints)]}];
                    end
                    if passfail(2,1)~=0&&passfail(4,1)~=0
                        returnMessage=[returnMessage,...
                            {'Adjust Joint4 Transmission Before Adjusting Joint2'}];
                    end
                    if passfail(4,1)~=0
                        returnMessage=[returnMessage,...
                            {'Be Sure to Check J4 Cable Helix'}];
                    end
                    presentMakoResults(guiHandles,'FAILURE',returnMessage);
                        displayString = [returnMessage{:}];
                    log_results(hgs,guiHandles.scriptName,'FAIL',...
                        sprintf('Transmission Check Failed. %s',displayString),...
                        LogResults);
                case TRANSMISSION_WARNING
                    result.result='WARNING';
                    returnMessage={['WARNING ' sprintf(' Joint %d ',warning_joints)]};
                    if passfail(2,1)~=0&&passfail(4,1)~=0
                        returnMessage=[returnMessage,...
                            {'Adjust Joint4 Transmission Before Adjusting Joint2'}];
                    end
                    if passfail(4,1)~=0
                        returnMessage=[returnMessage,...
                            {'Be Sure to Check J4 Cable Helix'}];
                    end
                    presentMakoResults(guiHandles,'WARNING',returnMessage);
                    displayString = [returnMessage{:}];
                    log_results(hgs,guiHandles.scriptName,'WARNING',...
                        sprintf('Transmission Check passed with warning. %s',displayString),...
                        LogResults);

                case TRANSMISSION_PASS
                    result.result='PASS';
                    presentMakoResults(guiHandles,'SUCCESS');
                    log_results(hgs,guiHandles.scriptName,'PASS',...
                        'Transmission Check Passed',LogResults);

            end
            
        catch exception
            presentMakoResults(guiHandles,'FAILURE',exception.message);
            log_results(hgs,guiHandles.scriptName,'FAIL',...
                sprintf('Transmission Check Failed: %s',exception.message));
            return
        end
        
        %Save Results
        fileName =[sprintf('transmission_test-%s-',hgs.name),...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        myDataFileName=fullfile(guiHandles.reportsDir,fileName);
        save(myDataFileName, 'transmissiondata','result');
        
        % Save results to UserData to facilitate access from external functions
        % (AKM)
        set(guiHandles.figure,'UserData',{result;transmissiondata})
        
        % Return to rest position
        target=testpositions(1,:);
        go_to_position(hgs,target,.5);
        mode(hgs,'zerogravity','ia_hold_enable',1);
        
    end

%% return function
%--------------------------------------------------------------------------
% internal function response to stop test button press
%--------------------------------------------------------------------------
    function STOP_TEST(src,evt,guiHandles)  %#ok<INUSL>
        % button_press=guidata(guiHandles.mainButtonInfo);
        mode(hgs, 'zerogravity','ia_hold_enable',1);
        set(guiHandles.mainButtonInfo,...
            'String',sprintf...
            ('TRANSMISSION TEST stopped, Press again to restart'),...
            'UserData',testing,...
            'Callback',{@TRANSMISSION_TEST}...
            );
    end

%%  close function
%--------------------------------------------------------------------------
% internal function to cancel transmission check procedure
%--------------------------------------------------------------------------
    function TRANSMISSION_TEST_CLOSE(varargin)
        % button_press=guidata(guiHandles.mainButtonInfo);
        log_message(hgs,'Transmission Check Script Closed');
        mode(hgs, 'zerogravity','ia_hold_enable',1);
        close_test=true; %prevents further execution of phase calculation
        %and figure update
        closereq;
    end

end


%%%%%%%%%% THE FOLLOWING ARE NOT NESTED FUNCTIONS %%%%%%%%
%% Calculate Phase
%--------------------------------------------------------------------------
% internal function to evaluate module data and calculate joint phase lag
%--------------------------------------------------------------------------
function transmissiondata=CALCULATE_PHASE(hgs,run)

transmissiondata.measured_joint =run.joint;
transmissiondata.frequency      =run.vib_freqH(run.joint);
transmissiondata.amplitude      =run.vib_amp(run.joint);

transmissiondata.motor_joint_error  =hgs.joint_angle_error(run.joint);
transmissiondata.c_je_joint_angles  =hgs.vibrate_move.log_je_joint_angles(1:hgs.vibrate_move.log_index);
transmissiondata.c_me_joint_angles  =hgs.vibrate_move.log_me_joint_angles(1:hgs.vibrate_move.log_index);

t=(0:(hgs.vibrate_move.log_index-1))/2000;
Fs = 2000;
npts = length(t);

x=transmissiondata.c_je_joint_angles;
y=transmissiondata.c_me_joint_angles;

% remove bias
x = x - mean(x);
y = y - mean(y);

% remove bias
x = x - mean(x);
y = y - mean(y);

% take the FFT
X=fft(x);
Y=fft(y);

% Calculate the numberof unique points
NumUniquePts = ceil((npts+1)/2);
f = (0:NumUniquePts-1)*Fs/npts;

% Evaluate unique points only
XX=X(1:NumUniquePts);
YY=Y(1:NumUniquePts);
%ignore data below 4hz
XX(1:10)=0;
YY(1:10)=0;

% Determine the max value and max point.
% This is where the sinusoidal
% is located. See Figure 2.
[mag_x idx_x] = max(abs(XX));
[mag_y idx_y] = max(abs(YY));
% Use the index at the frequency of
% maximum MOTOR excitation
idx  = idx_y;
% determine the phase difference
% at the maximum point.
px = angle(X(idx));
py = angle(Y(idx));
phase_lag = py - px;

% Wrap-around correction
% produces phase lag above -180°
if phase_lag <(-pi)
    phase_lag = phase_lag + 2*pi;
end

% determine the amplitude scaling
amplitude_ratio = mag_y/mag_x;

transmissiondata.test_time=clock;
transmissiondata.phase_lag=phase_lag;
transmissiondata.amplitude_ratio=amplitude_ratio;
transmissiondata.frequency_excite=run.vib_freqH;
transmissiondata.frequency_j=f(idx_x);
transmissiondata.frequency_m=f(idx_y);
transmissiondata.passfail='';

end

%% RunTransmissionCheck
%--------------------------------------------------------------------------
% internal function run the vibrate_move module for a joint test
%--------------------------------------------------------------------------
function Transflag = RunTransmissionCheck(hgs,run,guiHandles)

cenpos=hgs.me_joint_angles; %use me_joint_angles, because
%vibrate_move operates on me_joint_angles
%for feedback
pospos=cenpos+.002;
negpos=cenpos-.002;

mode(hgs,'vibrate_move',...
    'pos_limits',pospos, 'neg_limits',negpos,...
    'gross_freqH',run.gross_freqH,'vib_freqH',run.vib_freqH,...
    'vib_amp', run.vib_amp,'torque_gain',run.torque_gain,...
    'joint_index',run.joint);
% Execute mode for 4 seconds and check for any error occurance in the
% vibrate_move mode
timer = tic;
while toc(timer) <= 4.0
    if ~strcmp(mode(hgs),'vibrate_move')
        Transflag = true;
        errMsg =  hgs.vibrate_move.mode_error;
        set(guiHandles.figure,'UserData',{Transflag,errMsg});
        break
    else
        Transflag = false;
    end

end


mode(hgs,'hold_position');

end

%% Set Variables function
%--------------------------------------------------------------------------
% internal function to set the vibrate_move variables for a joint test
%--------------------------------------------------------------------------
function run=SetVariables(off, ON, runjoint)
run.gross_freqH	=off.gross_freqH;
run.vib_freqH	=off.vib_freqH;
run.vib_amp     =off.vib_amp;
run.torque_gain	=off.torque_gain;

run.gross_freqH(runjoint)	=ON.gross_freqH(runjoint);
run.vib_freqH(runjoint)     =ON.vib_freqH(runjoint);
run.vib_amp(runjoint)       =ON.vib_amp(runjoint);
run.torque_gain(runjoint)   =ON.torque_gain(runjoint);

run.joint=runjoint;
end

% --------- END OF FILE ----------
