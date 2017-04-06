function guiHandles = find_friction_constants(hgs,varargin)
%FIND_FRICTION_CONSTANTS identifies the friction parameters
%
% Description:
%
% Syntax:
%   find_friction_constants(hgs,varargin)
%   For friction test, the second parameter must be 'test_friction'.
%
%
%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007


%% Setup MakoLab default GUI
scriptName = 'Find Friction Constants';

% Set test constants
NUMBER_OF_RUNS = 4;
TEST_POSITION =  [1.3000, -1.20000, 1.2000, 2.4000, 3.00000, 0.7000];
TEST_POSITION2 = [0.0000, -1.20000, 0.0000, 2.7500, 3.00000, 0.7000];
TEST_VELOCITY =  [  0.20,     0.20,  0.200,  0.200,  0.2000, 0.2000];

% RIO 2.0 Friction Limits
NOMINAL_KINETIC_FRICTIONS.V2_0  = [2.25, 3.02, 1.83, 1.71, 0.16, 0.62];
FRICTION_UPPER_FAIL_LIMITS.V2_0 = [3.25, 5.34, 2.89, 2.39, 0.22, 0.87];
FRICTION_LOWER_WARN_LIMITS.V2_0 = [0.00, 0.00, 0.00, 0.00, 0.00, 0.55];
FRICTION_LOWER_FAIL_LIMITS.V2_0 = [0.00, 0.00, 0.00, 0.00, 0.00, 0.00];

NOMINAL_STDDEVS.V2_0            = [0.41, 1.69, 0.75, 0.40, 0.07, 0.08];
STDDEV_UPPER_WARN_LIMITS.V2_0   = [0.74, 3.30, 0.96, 0.53, 0.13, 0.10];%3-sigma value

% RIO 2.2 Friction Limits
NOMINAL_KINETIC_FRICTIONS.V2_2  = [2.40, 2.84, 1.71, 1.81, 0.32  0.69];
FRICTION_UPPER_FAIL_LIMITS.V2_2 = [3.53, 3.84, 2.29, 2.50, 0.51, 0.94];
FRICTION_LOWER_FAIL_LIMITS.V2_2 = [0.00, 0.00, 0.00, 0.00, 0.00, 0.38];
FRICTION_LOWER_WARN_LIMITS.V2_2 = [0.00, 0.00, 0.00, 0.00, 0.25, 0.50];

NOMINAL_STDDEVS.V2_2            = [0.56, 1.65, 1.55, 0.76, 0.11, 0.25];
STDDEV_UPPER_WARN_LIMITS.V2_2   = [0.86, 1.98, 1.75, 0.81, 0.13, 0.28];%3-sigma value

% RIO 3.0 Friction Limits
NOMINAL_KINETIC_FRICTIONS.V3_0  = [2.40, 2.84, 1.71, 1.81, 0.32  0.69];
FRICTION_UPPER_FAIL_LIMITS.V3_0 = [3.53, 3.84, 2.29, 2.50, 0.51, 0.94];
FRICTION_LOWER_FAIL_LIMITS.V3_0 = [0.00, 0.00, 0.00, 0.00, 0.00, 0.38];
FRICTION_LOWER_WARN_LIMITS.V3_0 = [0.00, 0.00, 0.00, 0.00, 0.25, 0.50];

NOMINAL_STDDEVS.V3_0            = [0.56, 1.65, 1.55, 0.76, 0.11, 0.25];
STDDEV_UPPER_WARN_LIMITS.V3_0   = [0.86, 1.98, 1.75, 0.81, 0.13, 0.28];%3-sigma value

%PID parameters
KDS.V2_0= [10.00, 40.00, 35.00, 30.00, 0.75, 1.5];
KPS.V2_0= [3800.0, 20000.0, 8000.00, 2000.00, 400.00, 300.0];
KDS.V2_1= [10.00, 40.00, 35.00, 30.00, 0.75, 3.0];
KPS.V2_1= [3800.0, 20000.0, 8000.00, 2000.00, 400.00, 800.0];
KDS.V2_2= [10.00, 40.00, 35.00, 30.00, 0.75, 3.0];
KPS.V2_2= [3800.0, 20000.0, 8000.00, 2000.00, 400.00, 800.0];
KDS.V2_3= [10.00, 40.00, 35.00, 30.00, 0.75, 3.0];
KPS.V2_3= [3800.0, 20000.0, 8000.00, 2000.00, 400.00, 800.0];
KDS.V3_0= [10.00, 40.00, 35.00, 30.00, 0.75, 3.0];
KPS.V3_0= [3800.0, 20000.0, 8000.00, 2000.00, 400.00, 800.0];
KI=zeros(1,6);

RANGE_OF_MOTION=[pi/4,pi/8,pi/6,pi/6,pi/4,pi/4];

TEST_FRICTION=1;
FIND_FRICTION=0;

%decide which mode should be based on inputs.
if (nargin==2) && (strcmp(varargin(1),'test_friction'))
    mode_flag=TEST_FRICTION;
else
    mode_flag=FIND_FRICTION;
end

try
    % if no robot is specified connect to the default robot
    % If no arguments are specified create a connection to the default
    % hgs_robot
    if nargin<1
        hgs = connectRobotGui;
        if isempty(hgs)
            guiHandles='';
            return;
        end
    end
    
    if (~isa(hgs,'hgs_robot'))
        error('Invalid argument: find_friction_constants argument must be an hgs_robot object');
    end
    
    guiHandles = generateMakoGui(scriptName,[],hgs);
    log_message(hgs,'Find Friction Constants Started');
    
    if ~homingDone(hgs)
        presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
        
        log_results(hgs,guiHandles.scriptName,'FAIL','Find Friction Constants failed (Homing not done)');
        return;
    end
    
    robotFrontPanelEnable(hgs,guiHandles);
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');
    
    
    set(guiHandles.mainButtonInfo,...
        'String',sprintf('%s: Click to start',scriptName),...
        'Callback',@start_friction_parameter_identification...
        );
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@find_friction_constants_close);
    
    %set nominal value based on hardware version
    armHardwareVersion = hgs.ARM_HARDWARE_VERSION;
    
    switch int32(armHardwareVersion * 10 + 0.05)
        case 20 % 2.0
            NOMINAL_KINETIC_FRICTION  = NOMINAL_KINETIC_FRICTIONS.V2_0;
            FRICTION_UPPER_FAIL_LIMIT = FRICTION_UPPER_FAIL_LIMITS.V2_0;
            FRICTION_LOWER_FAIL_LIMIT = FRICTION_LOWER_FAIL_LIMITS.V2_0;
            FRICTION_LOWER_WARN_LIMIT = FRICTION_LOWER_WARN_LIMITS.V2_0;
            
            NOMINAL_STDDEV            = NOMINAL_STDDEVS.V2_0;
            STDDEV_UPPER_WARN_LIMIT   = STDDEV_UPPER_WARN_LIMITS.V2_0;
            NOMINAL_KINETIC_FRICTION  = NOMINAL_KINETIC_FRICTIONS.V2_0;
            
            KD=KDS.V2_0;
            KP=KPS.V2_0;

        case 22 % 2.2
            NOMINAL_KINETIC_FRICTION  = NOMINAL_KINETIC_FRICTIONS.V2_2;
            FRICTION_UPPER_FAIL_LIMIT = FRICTION_UPPER_FAIL_LIMITS.V2_2;
            FRICTION_LOWER_FAIL_LIMIT = FRICTION_LOWER_FAIL_LIMITS.V2_2;
            FRICTION_LOWER_WARN_LIMIT = FRICTION_LOWER_WARN_LIMITS.V2_2;
            
            NOMINAL_STDDEV            = NOMINAL_STDDEVS.V2_2;
            STDDEV_UPPER_WARN_LIMIT   = STDDEV_UPPER_WARN_LIMITS.V2_2;
            NOMINAL_KINETIC_FRICTION  = NOMINAL_KINETIC_FRICTIONS.V2_2;
            
            KD=KDS.V2_2;
            KP=KPS.V2_2;

        case 30 % 3.0
            NOMINAL_KINETIC_FRICTION  = NOMINAL_KINETIC_FRICTIONS.V3_0;
            FRICTION_UPPER_FAIL_LIMIT = FRICTION_UPPER_FAIL_LIMITS.V3_0;
            FRICTION_LOWER_FAIL_LIMIT = FRICTION_LOWER_FAIL_LIMITS.V3_0;
            FRICTION_LOWER_WARN_LIMIT = FRICTION_LOWER_WARN_LIMITS.V3_0;
            
            NOMINAL_STDDEV            = NOMINAL_STDDEVS.V3_0;
            STDDEV_UPPER_WARN_LIMIT   = STDDEV_UPPER_WARN_LIMITS.V3_0;

            KD=KDS.V3_0;
            KP=KPS.V3_0;
            
        otherwise
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf(...
                'Invalid hardware version %.1f',armHardwareVersion));
                log_message(hgs,sprintf('Invalid hardware version %.1f',...
                    armHardwareVersion),'ERROR');
            return;
    end
    
    % Initialize find friction in progress flag
    isFindFrictionInProgress=false;
    isFindFrictionCanceled=false;
    isPass=ones(1,6);
    
    
    %% Set additional GUI
    dof=hgs.WAM_DOF;
    
    xMin = 0.02;
    xRange = 0.95;
    yRange = 0.05;
    spacing = 0.005;
    
    %%set up display text location
    commonTextProperties =struct(...
        'Style','text',...
        'Units','normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'FontSize',0.6,...
        'HorizontalAlignment','Left');
    
    %%set up display text location
    commonEditProperties =struct(...
        'Style','edit',...
        'Units','normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'FontSize',0.3,...
        'Enable','inactive',...
        'String','---',...
        'HorizontalAlignment','Left');
    %add text for measured kinetic friction
    yMin=0.70;
    uicontrol(guiHandles.uiPanel,...
        commonTextProperties,...
        'Position',[xMin yMin xRange yRange],...
        'HorizontalAlignment','Center',...
        'FontSize',0.8,...
        'String','Measured Kinetic Friction (Nm)');
    
    %add edit for measured kinetic friction
    yMin=0.60;
    yRange=0.1;
    for i=1:dof %#ok<FXUP>
        position = [xMin+(xRange+spacing)*(i-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        kineticEdit(i) = uicontrol(guiHandles.uiPanel,...
            commonEditProperties,...
            'Position',position...
            ); %#ok<AGROW>
    end
    
    %add text for nominal kinetic friction
    yMin=0.5;
    yRange = 0.05;
    uicontrol(guiHandles.uiPanel,...
        commonTextProperties,...
        'Position',[xMin yMin xRange yRange],...
        'HorizontalAlignment','Center',...
        'FontSize',0.8,...
        'String','Nominal Kinetic Friction (Nm)');
    
    %add edit for nominal kinetic friction
    yMin=0.40;
    yRange=0.1;
    for i=1:dof %#ok<FXUP>
        position = [xMin+(xRange+spacing)*(i-1)/dof,...
            yMin,xRange/dof-spacing,yRange];
        kineticNomEdit(i) = uicontrol(guiHandles.uiPanel,...
            commonEditProperties,...
            'Position',position...
            ); %#ok<AGROW>
    end
catch
    findFrictionErrorHandling();
end



%% mainButton callback
    function start_friction_parameter_identification(varargin)
        
        try
            %get into the routine where user has to press the
            %flashing green button
            robotFrontPanelEnable(hgs,guiHandles);
        catch
            %handle the error
            findFrictionErrorHandling();
            return;
        end
        
        %initial setup
        isFindFrictionInProgress=true;
        isWarning=0;
        
        %trajectory status as defined in CRISIS
        trajectoryCruise=64; %0x40
        targetReached=1;
        
        %number of runs
        numberOfRuns=NUMBER_OF_RUNS;
        
        %array to store final results
        friction_viscous_coeff=zeros(1,dof);
        frictionDataCellArray=cell(dof,4);
        
        %error message
        error_message_mean='';
        error_message_std='';
        try
            if(dof==6)
                
                % home position, this is hard coded, make sure these are
                % consistent with the real robots.
                home_position=TEST_POSITION;
                velocity_command=TEST_VELOCITY;
                
                %nominal friction parameters
                kinetic_nominal          = NOMINAL_KINETIC_FRICTION;
                kinetic_upper_fail_limit = FRICTION_UPPER_FAIL_LIMIT;
                kinetic_lower_fail_limit = FRICTION_LOWER_FAIL_LIMIT;
                kinetic_lower_warn_limit = FRICTION_LOWER_WARN_LIMIT;
                
                std_nominal              = NOMINAL_STDDEV;
                std_upper_warn_limit     = STDDEV_UPPER_WARN_LIMIT;
                
                
                %range of motion
                range_of_motion=RANGE_OF_MOTION;
                
                %update the nominal values
                for i=1:dof %#ok<FXUP>
                    set(kineticNomEdit(i),'String',...
                        sprintf('%.3f',kinetic_nominal(i)),...
                        'BackgroundColor',[0.75 0.75 0.75]);
                end
            else
                %update mainbutton
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf(...
                    'Robot has %d DOF, but only 6 DOF supported',dof));
                    log_message(hgs,sprintf('Robot has %d DOF, but only 6 DOF supported',dof),'ERROR');
                return;
            end
        catch
            findFrictionErrorHandling();
            return;
        end
        
        %initialize local variables
        jointTorquesTemp=zeros(1,10000);
        gravityTorquesTemp=zeros(1,10000);
        jointVelocityTemp=zeros(1,10000);
        error_message='';
        
        try
            %update mainbutton
            updateMainButtonInfo(guiHandles,'text',...
                'Moving to test position');
            
            %go to home position
            if(~isFindFrictionCanceled)
                go_to_position(hgs,home_position);
            end
        catch
            %handle the error
            findFrictionErrorHandling();
            return;
        end
        
        try
            %start the routine
            for i=1:dof%#ok<FXUP>
                
                %goto test position
                if i==2
                    go_to_position(hgs,TEST_POSITION2);
                else
                    go_to_position(hgs,home_position);
                end
                
                for j=1:numberOfRuns
                    %update main button
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('%s: joint %d, run %d/%d',...
                        scriptName,i,j,numberOfRuns));
                    
                    %initializations
                    start_position=hgs.joint_angles;
                    end_position=start_position;
                    cntTemp=0;
                    
                    %move the same joint back and forth as specified by
                    %numberOfRuns
                    velocity=velocity_command(i);
                    end_position(i)=start_position(i)+(-1)^j*range_of_motion(i);
                    
                    %start friction parameter module
                    try
                        mode(hgs,'friction_parameter',...
                            'start_point',start_position,...
                            'end_point',end_position,...
                            'KP',KP,...
                            'KD',KD,...
                            'KI',KI,...
                            'velocity_max',velocity,...
                            'joint_number',i-1);
                        
                    catch
                        findFrictionErrorHandling();
                        return
                    end
                    
                    %wait until the motion is cancelled or completed
                    while(isFindFrictionInProgress)
                        %check if cancel button pressed
                        if(isFindFrictionCanceled)
                            break;
                        end
                        %check if completed
                        if(hgs.friction_parameter.trajectory_status~=targetReached)
                            %check if the commanded velocity reach the maximum
                            if(hgs.friction_parameter.trajectory_status==trajectoryCruise)
                                cntTemp=cntTemp+1;
                                jointTorquesTemp(cntTemp)=...
                                    hgs.friction_parameter.joint_torques(i);
                                gravityTorquesTemp(cntTemp)=...
                                    hgs.friction_parameter.gravity_torques(i);
                                jointVelocityTemp(cntTemp)=hgs.joint_velocity(i);
                            end
                            pause(0.01);
                        else
                            break;
                        end
                        %check for crisis error
                        if hgs.ce_error_code(1)>0
                            stateAtLastError=commDataPair(hgs,'get_state_at_last_error');
                            error_message=sprintf('%s(J%d),',...
                                stateAtLastError.error_msg{1},stateAtLastError.error_axis+1);
                            isPass(i)=0;
                            isFindFrictionCanceled=true;
                            findFrictionErrorHandling();
                            break;
                        end
                    end
                    
                    %calculate the friction torques absolute values
                    frictionTorques=jointTorquesTemp(1:cntTemp);
                    
                    jointVelocityAbs=abs(jointVelocityTemp(1:cntTemp));
                    
                    
                    %calculate the mean of friction and velocity
                    frictionTorquesMean(j)=mean(frictionTorques); %#ok<AGROW>
                    frictionTorquesStd(j)=std(frictionTorques); %#ok<AGROW>
                    %save the data for later plot
                    testDataTemp(j)={[frictionTorques(1:cntTemp);...
                        jointVelocityAbs(1:cntTemp)]}; %#ok<AGROW>
                    %check if cancelled
                    if(isFindFrictionCanceled)
                        break;
                    end
                end
                %check if cancelled
                if(isFindFrictionCanceled)
                    isPass(i)=0;
                    break;
                end
                %calculate the standard deviation
                frictionTorquesStdMax(i)=max(frictionTorquesStd); %#ok<AGROW>
                
                %calculate the friction parameters
                friction_kinetic(i)=...
                    get_friction_parameters(frictionTorquesMean); %#ok<AGROW>
                
                %fill in the friction data cell array.
                frictionDataCellArray(i,1)={testDataTemp};
                frictionDataCellArray(i,2)={friction_kinetic(i)};
                frictionDataCellArray(i,3)={friction_viscous_coeff(i)};
                frictionDataCellArray(i,4)={frictionTorquesStdMax(i)};
                            
                %check and update the nominal friction display,
                if(friction_kinetic(i) > kinetic_upper_fail_limit(i)) % FAIL if friction > upper fail limit
                    error_message_mean=sprintf('%s %d,',error_message_mean,i);
                    set(kineticEdit(i),...
                        'BackgroundColor','red',...
                        'String',sprintf('%.3f',friction_kinetic(i)));
                    error_message = sprintf('Joint %d friction above upper limit',i);
                    isPass(i)=0;
                    
                elseif(friction_kinetic(i) < kinetic_lower_fail_limit(i)) % FAIL if friction < lower fail limit
                    error_message_mean=sprintf('%s %d,',error_message_mean,i);
                    set(kineticEdit(i),...
                        'BackgroundColor','red',...
                        'String',sprintf('%.3f',friction_kinetic(i)));
                    error_message = 'Joint friction below lower limit';
                    isPass(i)=0;
                    
                elseif(friction_kinetic(i) < kinetic_lower_warn_limit(i)) % WARN if friction < lower warn limit
                    set(kineticEdit(i),...
                        'BackgroundColor','yellow',...
                        'String',sprintf('%.3f',friction_kinetic(i)));
                    error_message = 'Joint friction low';
                    isWarning = 1;
                    
                elseif isnan(friction_kinetic(i)) % FAIL if friction data not collected properly
                    set(kineticEdit(i),...
                        'BackgroundColor','red',...
                        'String',sprintf('%.3f',friction_kinetic(i)));
                    error_message = 'Error collecting data. No friction torques recorded.';
                    isPass(i)=0;

                else
                    set(kineticEdit(i),... % PASS
                        'BackgroundColor','green',...
                        'String',sprintf('%.3f',friction_kinetic(i)));
                    isPass(i)=1;
                    
                end
                
                %check the standard deviation
                if(frictionTorquesStdMax(i) > std_upper_warn_limit(i))
                    error_message_std=sprintf('%s %d,',error_message_std,i);
%                     error_message = 'High joint friction standard deviation';
                    isWarning=1;
                end
            end
        catch
            findFrictionErrorHandling();
            return;
        end
        
        %set find friction in progress flag
        isFindFrictionInProgress=false;
        
        % Create results structure for logging
        Results.friction_kinetic = friction_kinetic;
        Results.friction_viscous_coeff = friction_viscous_coeff;
        Results.frictionTorquesStdMax = frictionTorquesStdMax;
        
        try
            % Present the results
            if (isPass)
                %update friction constants if the mode is correct
                if(mode_flag==FIND_FRICTION)
                    %update friction constants for J1 to J4, and set
                    %J5 and J6 to be zero explicitly.
                    hgs.FRICTION_KINETIC(1:4)=friction_kinetic(1:4)*0.5;
                    hgs.FRICTION_KINETIC(5)=0.0;
                    hgs.FRICTION_KINETIC(6)=0.0;
                end
                if isWarning                    
                    if(length(error_message_std)>1)
                        error_message=sprintf('%s\n,Joint %s variation out of range,',...
                            error_message,  error_message_std(1:length(error_message_std)-1));
                    end                    
                    presentMakoResults(guiHandles,'WARNING',...
                        sprintf('Constants updated successfully\n, %s',error_message));
                    log_results(hgs,guiHandles.scriptName,'WARNING','The test passed with warning',Results);
                else
                    presentMakoResults(guiHandles,'SUCCESS',...
                        'Constants updated successfully');
                    log_results(hgs,guiHandles.scriptName,'PASS','The test passed',Results);
                end
            else
                %present result
                if(length(error_message_mean)>1)
                    error_message=sprintf(...
                        'Joint %s average out of range,',...
                        error_message_mean(1:length(error_message_mean)-1));
                end
                if(length(error_message_std)>1)
                    error_message=sprintf('%s Joint %s variation out of range,',...
                        error_message,error_message_std(1:length(error_message_std)-1));
                end
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('%s Nominal constants restored.',...
                    error_message));
                log_results(hgs,guiHandles.scriptName,'FAIL','The test failed',Results);
            end
            
            if(mode_flag==FIND_FRICTION && min(isPass))
                %restart crisis
                restartCRISIS(hgs);
                pause(3);
            else
                %do nothing
            end
        catch
            findFrictionErrorHandling();
            return;
        end
        
        try
            %save the data no matter pass or fail
            fileName =[sprintf('%s-%s-',scriptName,hgs.name),...
                datestr(now,'yyyy-mm-dd-HH-MM')];
            myDataFileName=fullfile(guiHandles.reportsDir,fileName);
            save(myDataFileName, 'frictionDataCellArray','friction_kinetic');
            % save results to UserData to facilitate access from external
            % functions (AKM)
            userDataStruct.isPass = isPass;
            userDataStruct.friction_kinetic = friction_kinetic;
            userDataStruct.kinetic_friction_limit = FRICTION_UPPER_FAIL_LIMIT;
            userDataStruct.kinetic_friction_lowerlimit = FRICTION_LOWER_WARN_LIMIT;
            userDataStruct.error_message = error_message;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        catch
            %do nothing
        end
    end

%--------------------------------------------------------------------------
%Internal function to use polynomial to fit the test data
%--------------------------------------------------------------------------
%this is kept as a separate function for higher order polynomial fit,
%currently, average are used to fit the data
    function kinetic_friction=get_friction_parameters(friction_torque)
        %calculate the kinetic friction
        kinetic_friction=mean(abs(...
            friction_torque(1:2:length(friction_torque))-...
            friction_torque(2:2:length(friction_torque))))/2;
    end

%--------------------------------------------------------------------------
%Internal function to close the gui
%--------------------------------------------------------------------------
    function find_friction_constants_close(varargin)
        log_message(hgs,'Find Friction Constants Closed');
        isFindFrictionCanceled=true;
        pause(0.2);
        if(~isFindFrictionInProgress)
            closereq;
        end
        try
            reset(hgs);
        catch
        end
    end
%--------------------------------------------------------------------------
%Internal function to represent catch error message
%--------------------------------------------------------------------------
    function findFrictionErrorHandling()
        try
            userDataStruct.isPass = -1;
            findFrictionConstantsError=lasterror;
            findFrictionConstantsMsg=findFrictionConstantsError.message;
            userDataStruct.errorMsg = findFrictionConstantsMsg;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
            isPass(i)=0;
            presentMakoResults(guiHandles,'FAILURE',...
                findFrictionConstantsMsg);
            log_message(hgs,lasterror,'ERROR');
            
            reset(hgs);
        catch
        end
    end

end


%* --------- END OF FILE ----------
