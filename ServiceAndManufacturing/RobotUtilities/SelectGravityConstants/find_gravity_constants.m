function gData=find_gravity_constants(hgs,gData,varargin)
% FIND_GRAVITY_CONSTANTS Function to find the gravity constants for the robot
%
% Syntax:
%   find_gravity_constants(hgs,ee_type,varargin)
%       Starts up the GUI for helping the user determine the gravity
%       constants for the hgs_robot
%
% Notes:
%   The gravity constants are computed by moving the robot through a number
%   of poses and storing the torques required to hold the torque at that
%   pose.  This is then used to compute the parameters as required by the
%   gravity compensation equation
%
%   This function is hardware specific and is currently implemented only
%   for the 2.X robots
%
% See also:
%    hgs_robot, home_hgs/mode

%
% $Author: dmoses $
% $Revision: 1759 $
% $Date: 2009-05-30 14:01:33 -0400 (Sat, 30 May 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% Generate the gui
guiHandles = generateMakoGui(gData.mbDisplayText,[],hgs);
log_message(hgs,'Find Gravity Constants Script Started');

%update gui handles in the return data
gData.guiHandles=guiHandles;

%copy over some constants
NOMINAL_GRAV_CONSTANTS=gData.NOMINAL_GRAV_CONSTANTS;
MAX_ALLOWED_DEVIATION=gData.MAX_ALLOWED_DEVIATION;
ee_type=gData.ee_type;

%set nominal weight
hgs.GRAV_COMP_WEIGHTS(:) = 1;

% set warinig ratio
DEVIATION_WARNING_RATIO = gData.DEVIATION_WARNING_RATIO;
% Setup all the constants needed for the test
NUMBER_OF_INTERMEDIATE_POSITIONS=gData.NUMBER_OF_INTERMEDIATE_POSITIONS;

% save the current constants and weights
TESTING_GRAV_COMP_CONSTANTS = gData.TESTING_GRAV_COMP_CONSTANTS;
TESTING_GRAV_COMP_WEIGHTS = gData.TESTING_GRAV_COMP_WEIGHTS;

% setup the cancel button
cancelButtonPressed = false;
set(guiHandles.figure,'CloseRequestFcn',@cancelGravityConstantsProcedure);

% create SQA data structure for checks
dataSQA = [];

%update image
eeImageData=feval(gData.getEEImageData);
ah=axes('Parent',guiHandles.uiPanel,...
    'Box','OFF','Ydir','Reverse','Visible','OFF');
ih=image(eeImageData,'Parent',ah);
axis(ah,'image');
axis(ah, 'off');

% All initialization is complete.  Set up the main button to perform the
% test
updateMainButtonInfo(guiHandles,@start_find_gravity_constants);

%--------------------------------------------------------------------------
% internal function to start the gravity constants procedure
%--------------------------------------------------------------------------
    function start_find_gravity_constants(varargin)
        try
            % update the button and set up required parameters
            updateMainButtonInfo(guiHandles,'text','Initializing (brakes will engage)...');
            
            %hide the image
            set(ih,'visible','OFF');
            
            %zero out gravity constants
            feval(gData.setGravityConstants, TESTING_GRAV_COMP_CONSTANTS);
            
            % restart CRISIS for changes to take effect
            restartCRISIS(hgs);
            
            %set gravity mode accordingly
            feval(gData.setGravityMode);
            
            % wait for upto 3 secs for camera to initialize
            pause(3);
            
            % Set the deafult gravity comp constants to defaults.  These constants will
            % not be effective untill there is a restart.  In case of an error
            % this will leave the defaults in the configuration file rather
            % than zeros.
            feval(gData.setGravityConstants, NOMINAL_GRAV_CONSTANTS);
            
            % get into the routine where user has to press the flashing green
            % button
            if ~robotFrontPanelEnable(hgs,guiHandles)
                return;
            end
            
            % Tell user that arm will move to shown pose
            updateMainButtonInfo(guiHandles,'text',...
                {'Arm will now move','to shown pose'});
            pause(1);
            
            % always start from known safe pose
            updateMainButtonInfo(guiHandles,'text',...
                'Arm Moving to start position');
            go_to_position(hgs,[0 -pi/2 0 pi/2 0 0]);
            
            % generate two progress bars for indicating collection progress
            % Generate a big progressbar
            for i=1:2
                progaxes = axes(...
                    'Parent',guiHandles.uiPanel,...
                    'Color','white',...
                    'Position',[0.1 0.9-i*0.2 0.8 0.1],...
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
                    ); %#ok<AGROW>
                
                text(0.45,0.5,sprintf('Stage %d',i),...
                    'parent',progaxes,...
                    'fontunits','normalized',...
                    'fontsize',0.5)
                
            end
            
            % Try to identify P6 P7 P8 parameters
            updateMainButtonInfo(guiHandles,'text',...
                'Collecting data for stage 1');
            [X1,A78,B78,A1,B1] = collect_forearm_data(progressbar(1)); %#ok<NASGU>
            
            % go back to initial pose
            updateMainButtonInfo(guiHandles,'text',...
                'Arm Moving to start position');
            go_to_position(hgs,[0 -pi/2 0 pi/2 0 0],0.2,...
                hgs.go_to_position.torque_offset);
            
            % Now handle pose for parameters p1 p2 p3 p4
            updateMainButtonInfo(guiHandles,'text',...
                'Collecting data for stage 2');
            [X2,A123456,B123456,A2,B2] =  collect_upperarm_data(X1,progressbar(2)); %#ok<NASGU>
            
            % go back to initial pose
            updateMainButtonInfo(guiHandles,'text',...
                'Arm Moving to start position');
            go_to_position(hgs,[0 -pi/2 0 pi/2 0 0],0.2,...
                hgs.go_to_position.torque_offset);
            
            % all motion is done.  Engage brakes and wait for user
            stop(hgs);
            
            % merge the results
            computedGravConstants = [X2' X1'];
            
            %pass back to the caller
            gData.computedGravConstants=computedGravConstants;

            % define common properties for the text boxes
            commonProperties = struct(...
                'parent',guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontUnits','normalized',...
                'FontSize',0.5);
            
            % clean up the gui
            delete(get(guiHandles.uiPanel,'children'));
            % generate two sets of boxes
            % present the results in boxes and show if any are out of range
            % generate title lines
            uicontrol(commonProperties,...
                'Position',[0.1,0.7,0.8,0.1],...
                'BackgroundColor',[0.7 0.7 0.7],...
                'FontWeight','bold',...
                'String','Computed Gravity Constants');
            
            uicontrol(commonProperties,...
                'Position',[0.1,0.4,0.8,0.1],...
                'BackgroundColor',[0.7 0.7 0.7],...
                'String','Nominal Gravity Constants');
            
            % display the generated constants
            for i=1:length(NOMINAL_GRAV_CONSTANTS)
                
                % also display the nominal for reference
                uicontrol(commonProperties,...
                    'Position',[0.1+0.1*(i-1),0.3,0.1,0.1],...
                    'BackgroundColor',[0.75 0.75 0.75],...
                    'String',sprintf('%3.4f',NOMINAL_GRAV_CONSTANTS(i)));
                
            end
            
            % 2.1 robot use different check methods
            
            switch int32(gData.arm_hardware_version * 10 + 0.05)
                case 20 % 2.0
                    [checkResult,resultColorList] = check_gravity_constants(computedGravConstants);
                    
                    % display the generated constants
                    for i=1:length(NOMINAL_GRAV_CONSTANTS)
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.1*(i-1),0.6,0.1,0.1],...
                            'BackgroundColor',resultColorList{i},...
                            'String',sprintf('%3.4f',computedGravConstants(i)));
                        
                    end
                case 21 % 2.1
                    %check results
                    [checkResult,resultColorList] = check_gravity_constants_v21(A1,X1,B1,A2,X2,B2,gData.GRAV_TORQUE_LIMITS,gData.DEVIATION_WARNING_RATIO);
                    % display the generated constants
                    for i=1:length(NOMINAL_GRAV_CONSTANTS)
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.1*(i-1),0.6,0.1,0.1],...
                            'BackgroundColor',[0.75 0.75 0.75],...
                            'String',sprintf('%3.4f',computedGravConstants(i)));
                    end
                    
                    % display the results
                    for i=1:hgs.WAM_DOF
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.14*(i-1),0.1,0.1,0.1],...
                            'BackgroundColor',resultColorList{i},...
                            'String',sprintf('J%1d',i));
                    end
                case 22 % 2.2
                    %check results
                    [checkResult,resultColorList] = check_gravity_constants_v22(A1,X1,B1,A2,X2,B2,gData.GRAV_TORQUE_LIMITS,gData.DEVIATION_WARNING_RATIO);
                    % display the generated constants
                    for i=1:length(NOMINAL_GRAV_CONSTANTS)
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.1*(i-1),0.6,0.1,0.1],...
                            'BackgroundColor',[0.75 0.75 0.75],...
                            'String',sprintf('%3.4f',computedGravConstants(i)));
                    end
                    
                    % display the results
                    for i=1:hgs.WAM_DOF
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.14*(i-1),0.1,0.1,0.1],...
                            'BackgroundColor',resultColorList{i},...
                            'String',sprintf('J%1d',i));
                    end
                case 23 % 2.3
                    %check results
                    [checkResult,resultColorList] = check_gravity_constants_v23(A1,X1,B1,A2,X2,B2,gData.GRAV_TORQUE_LIMITS,gData.DEVIATION_WARNING_RATIO);
                    % display the generated constants
                    for i=1:length(NOMINAL_GRAV_CONSTANTS)
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.1*(i-1),0.6,0.1,0.1],...
                            'BackgroundColor',[0.75 0.75 0.75],...
                            'String',sprintf('%3.4f',computedGravConstants(i)));
                    end
                    
                    % display the results
                    for i=1:hgs.WAM_DOF
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.14*(i-1),0.1,0.1,0.1],...
                            'BackgroundColor',resultColorList{i},...
                            'String',sprintf('J%1d',i));
                    end
                case 30 % 3.0
                    %check results
                    [checkResult,resultColorList] = check_gravity_constants_v30(A1,X1,B1,A2,X2,B2,gData.GRAV_TORQUE_LIMITS,gData.DEVIATION_WARNING_RATIO);
                    % display the generated constants
                    for i=1:length(NOMINAL_GRAV_CONSTANTS)
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.1*(i-1),0.6,0.1,0.1],...
                            'BackgroundColor',[0.75 0.75 0.75],...
                            'String',sprintf('%3.4f',computedGravConstants(i)));
                    end
                    
                    % display the results
                    for i=1:hgs.WAM_DOF
                        uicontrol(commonProperties,...
                            'Position',[0.1+0.14*(i-1),0.1,0.1,0.1],...
                            'BackgroundColor',resultColorList{i},...
                            'String',sprintf('J%1d',i));
                    end
                otherwise
                    presentMakoResults(guiHandles,'FAILURE',...
                        sprintf('Unsupported Robot version: V%2.1f',gData.arm_hardware_version));
                    log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    sprintf('Find Gravity Constants failed: Unsupported Robot version: V%2.1f',gData.arm_hardware_version));
                    return;
                    
            end
            % save all the data for offline processing if needed
            dataFileName  = ['findGravConstants-' ee_type '-' datestr(now,'yyyy-mm-dd-HH-MM')];
            fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);
            save(fullDataFileName,'A1','B1','A2','B2','A123456','B123456',...
                'A78','B78','computedGravConstants', 'dataSQA')
            
            % create results structure for logging
            results_log = dataSQA;
            results_log.computedGravConstants = computedGravConstants;
            results_log.nominalGravConstants = NOMINAL_GRAV_CONSTANTS;
            
            % if the test passes (ask user to hold arm and press button)
            if checkResult>0
                %test passes,set gravity contants,
                feval(gData.setGravityConstants, computedGravConstants);
                
                updateMainButtonInfo(guiHandles,...
                    'text',{'Setting constants on Arm','Brakes will engage'});
                restartCRISIS(hgs);
                presentMakoResults(guiHandles,'SUCCESS',...
                    {'Press flashing green button','to go to gravity mode'});
                log_results(hgs,guiHandles.scriptName,'PASS', ...
                    'Find Gravity Constants passed', results_log);
                pause(5);
                % change to gravity mode so user can feel it
                mode(hgs,'zerogravity','ia_hold_enable',0);
                %set gravity mode accordingly
                feval(gData.setGravityMode);
                
            elseif checkResult>=0
                %test passes,set gravity contants,
                feval(gData.setGravityConstants, computedGravConstants);
                
                updateMainButtonInfo(guiHandles,...
                    'text',{'Setting constants on Arm','Brakes will engage'});
                restartCRISIS(hgs);
                presentMakoResults(guiHandles,'WARNING',...
                    {'Press flashing green button','to go to gravity mode'});
                log_results(hgs,guiHandles.scriptName,'WARNING', ...
                    'Find Gravity Constants passed with warning', results_log);
                pause(5);
                % change to gravity mode so user can feel it
                mode(hgs,'zerogravity','ia_hold_enable',0);
                %set gravity mode accordingly
                feval(gData.setGravityMode);
            else
                % if the there is an error, set back the default constants
                feval(gData.setGravityConstants, NOMINAL_GRAV_CONSTANTS);
                restartCRISIS(hgs);
                
                %set gravity mode accordingly
                feval(gData.setGravityMode);
                
                presentMakoResults(guiHandles,'FAILURE',...
                    {'Constants have been set to nominal'});
                log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    'Find Gravity Constants Failed', results_log);
            end
        catch
            % script exited for some reason.  reset the gravity to nominals
            % and quit
            feval(gData.setGravityConstants, NOMINAL_GRAV_CONSTANTS);
            
            restartCRISIS(hgs);
            
            %set gravity mode accordingly
            feval(gData.setGravityMode);
            
            if cancelButtonPressed
                return;
            else
                results_log.lasterr = lasterr;
                presentMakoResults(guiHandles,'FAILURE',lasterr);
                log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    'Find Gravity Constants Failed', results_log);
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to check constants against the nominals
%--------------------------------------------------------------------------
    function [checkResult,resultColorList] = check_gravity_constants(computed_constants)
        
        constantsDeviation = abs(NOMINAL_GRAV_CONSTANTS - computed_constants);
        checkResult=ones(length(NOMINAL_GRAV_CONSTANTS),1);
        
        for i=1:length(computed_constants)
            % check if this is an error
            if constantsDeviation(i) > MAX_ALLOWED_DEVIATION(i)
                checkResult(i) = -1;
                resultColorList{i} = 'red'; %#ok<AGROW>
            elseif constantsDeviation(i) ...
                    > MAX_ALLOWED_DEVIATION(i)*DEVIATION_WARNING_RATIO(i);
                % check if this is a warning
                checkResult(i) = 1;
                resultColorList{i} = 'green'; %#ok<AGROW>
            else
                % if i get here all is good
                checkResult(i) = 1;
                resultColorList{i} = 'green'; %#ok<AGROW>
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to check constants against the nominals
%--------------------------------------------------------------------------
    function [checkResult,resultColorList] = check_gravity_constants_v21(A1,X1,B1,A2,X2,B2,gravityLimits,warningRatio)
        
        dof=hgs.WAM_DOF;
        checkResult=ones(dof,1);
        
        %get fit data
        j1234Torques=A2*X2;
        j56Torques=A1*X1;
        jntTorques=[];
        torqueMean=gravityLimits.JntTorqueMean;
        RMSLimitsCross=gravityLimits.JntRMSLimitCross;
        RMSLimitsWithin=gravityLimits.JntRMSLimitWithin;
        
        %get fit torques
        for i=1:4
            jntTorques{i}=j1234Torques(i:4:end);
            jntTorquesMeasured{i}=B2(i:4:end);
        end
        for i=5:6
            jntTorques{i}=j56Torques(i-4:2:end);
            jntTorquesMeasured{i}=B1(i-4:2:end);
        end
        
        %check fit torques vs torque limits
        for i=1:dof
            
            %calculate rms
            jntRMSWithin(i)=sqrt(mean((jntTorques{i}-jntTorquesMeasured{i}).^2));
            jntRMSCross(i)=sqrt(mean((jntTorques{i}-torqueMean{i}).^2));
            
            %verify the measurements and RMS error
            % check if this is an error
            if  jntRMSCross(i)>RMSLimitsCross(i)|| ...
                    jntRMSWithin(i)>RMSLimitsWithin(i)
                checkResult(i) = -1;
                resultColorList{i} = 'red'; %#ok<AGROW>
                
            elseif jntRMSWithin(i)>RMSLimitsWithin(i)*warningRatio(i)
                % check if this is a warning
                if checkResult(i) ~= -1
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            else
                % if i get here all is good
                if (checkResult(i) ~= 0) && (checkResult(i) ~= -1)
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            end
        end
        
        dataSQA.jntRMSCross = jntRMSCross;
        dataSQA.RMSLimitsCross = RMSLimitsCross;
        dataSQA.jntRMSWithin = jntRMSWithin;
        dataSQA.RMSLimitsWithin = RMSLimitsWithin;
        
    end

%--------------------------------------------------------------------------
% internal function to check constants against the nominals
%--------------------------------------------------------------------------
    function [checkResult,resultColorList] = check_gravity_constants_v22(A1,X1,B1,A2,X2,B2,gravityLimits,warningRatio)
        
        dof=hgs.WAM_DOF;
        checkResult=ones(dof,1);
        
        %get fit data
        j1234Torques=A2*X2;
        j56Torques=A1*X1;
        jntTorques=[];
        torqueMean=gravityLimits.JntTorqueMean;
        RMSLimitsCross=gravityLimits.JntRMSLimitCross;
        RMSLimitsWithin=gravityLimits.JntRMSLimitWithin;
        
        %get fit torques
        for i=1:4
            jntTorques{i}=j1234Torques(i:4:end);
            jntTorquesMeasured{i}=B2(i:4:end);
        end
        for i=5:6
            jntTorques{i}=j56Torques(i-4:2:end);
            jntTorquesMeasured{i}=B1(i-4:2:end);
        end
        
        %check fit torques vs torque limits
        for i=1:dof
            
            %calculate rms
            jntRMSWithin(i)=sqrt(mean((jntTorques{i}-jntTorquesMeasured{i}).^2));
            jntRMSCross(i)=sqrt(mean((jntTorques{i}-torqueMean{i}).^2));
            
            %verify the measurements and RMS error
            % check if this is an error
            if  jntRMSCross(i)>RMSLimitsCross(i)|| ...
                    jntRMSWithin(i)>RMSLimitsWithin(i)
                checkResult(i) = -1;
                resultColorList{i} = 'red'; %#ok<AGROW>
                
            elseif jntRMSWithin(i)>RMSLimitsWithin(i)*warningRatio(i)
                % check if this is a warning
                if checkResult(i) ~= -1
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            else
                % if i get here all is good
                if (checkResult(i) ~= 0) && (checkResult(i) ~= -1)
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            end
        end
        dataSQA.jntRMSCross = jntRMSCross;
        dataSQA.RMSLimitsCross = RMSLimitsCross;
        dataSQA.jntRMSWithin = jntRMSWithin;
        dataSQA.RMSLimitsWithin = RMSLimitsWithin;
    end

%--------------------------------------------------------------------------
% internal function to check constants against the nominals
%--------------------------------------------------------------------------
    function [checkResult,resultColorList] = check_gravity_constants_v23(A1,X1,B1,A2,X2,B2,gravityLimits,warningRatio)
        
        dof=hgs.WAM_DOF;
        checkResult=ones(dof,1);
        
        %get fit data
        j1234Torques=A2*X2;
        j56Torques=A1*X1;
        jntTorques=[];
        torqueMean=gravityLimits.JntTorqueMean;
        RMSLimitsCross=gravityLimits.JntRMSLimitCross;
        RMSLimitsWithin=gravityLimits.JntRMSLimitWithin;
        
        %get fit torques
        for i=1:4
            jntTorques{i}=j1234Torques(i:4:end);
            jntTorquesMeasured{i}=B2(i:4:end);
        end
        for i=5:6
            jntTorques{i}=j56Torques(i-4:2:end);
            jntTorquesMeasured{i}=B1(i-4:2:end);
        end
        
        %check fit torques vs torque limits
        for i=1:dof
            
            %calculate rms
            jntRMSWithin(i)=sqrt(mean((jntTorques{i}-jntTorquesMeasured{i}).^2));
            jntRMSCross(i)=sqrt(mean((jntTorques{i}-torqueMean{i}).^2));
            
            %verify the measurements and RMS error
            % check if this is an error
            if  jntRMSCross(i)>RMSLimitsCross(i)|| ...
                    jntRMSWithin(i)>RMSLimitsWithin(i)
                checkResult(i) = -1;
                resultColorList{i} = 'red'; %#ok<AGROW>
                
            elseif jntRMSWithin(i)>RMSLimitsWithin(i)*warningRatio(i)
                % check if this is a warning
                if checkResult(i) ~= -1
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            else
                % if i get here all is good
                if (checkResult(i) ~= 0) && (checkResult(i) ~= -1)
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            end
        end
        dataSQA.jntRMSCross = jntRMSCross;
        dataSQA.RMSLimitsCross = RMSLimitsCross;
        dataSQA.jntRMSWithin = jntRMSWithin;
        dataSQA.RMSLimitsWithin = RMSLimitsWithin;
    end
%--------------------------------------------------------------------------
% internal function to check constants against the nominals
%--------------------------------------------------------------------------
    function [checkResult,resultColorList] = check_gravity_constants_v30(A1,X1,B1,A2,X2,B2,gravityLimits,warningRatio)
        
        dof=hgs.WAM_DOF;
        checkResult=ones(dof,1);
        
        %get fit data
        j1234Torques=A2*X2;
        j56Torques=A1*X1;
        jntTorques=[];
        torqueMean=gravityLimits.JntTorqueMean;
        RMSLimitsCross=gravityLimits.JntRMSLimitCross;
        RMSLimitsWithin=gravityLimits.JntRMSLimitWithin;
        
        %get fit torques
        for i=1:4
            jntTorques{i}=j1234Torques(i:4:end);
            jntTorquesMeasured{i}=B2(i:4:end);
        end
        for i=5:6
            jntTorques{i}=j56Torques(i-4:2:end);
            jntTorquesMeasured{i}=B1(i-4:2:end);
        end
        
        %check fit torques vs torque limits
        for i=1:dof
            
            %calculate rms
            jntRMSWithin(i)=sqrt(mean((jntTorques{i}-jntTorquesMeasured{i}).^2));
            jntRMSCross(i)=sqrt(mean((jntTorques{i}-torqueMean{i}).^2));
            
            %verify the measurements and RMS error
            % check if this is an error
            if  jntRMSCross(i)>RMSLimitsCross(i)|| ...
                    jntRMSWithin(i)>RMSLimitsWithin(i)
                checkResult(i) = -1;
                resultColorList{i} = 'red'; %#ok<AGROW>
                
            elseif jntRMSWithin(i)>RMSLimitsWithin(i)*warningRatio(i)
                % check if this is a warning
                if checkResult(i) ~= -1
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            else
                % if i get here all is good
                if (checkResult(i) ~= 0) && (checkResult(i) ~= -1)
                    checkResult(i) = 1;
                    resultColorList{i} = 'green'; %#ok<AGROW>
                end
            end
        end
        dataSQA.jntRMSCross = jntRMSCross;
        dataSQA.RMSLimitsCross = RMSLimitsCross;
        dataSQA.jntRMSWithin = jntRMSWithin;
        dataSQA.RMSLimitsWithin = RMSLimitsWithin;
    end

%--------------------------------------------------------------------------
% internal function to decouple identification of parameter for upperarm
%--------------------------------------------------------------------------
    function [X2,A123456,B123456,A2,B2] =  collect_upperarm_data(X1,progBar)
        init_pose =[ 0.0    -95.0   -90.0  90.0    0.0    0.0]; %init
        j3_end_angle   =  90.0;
        j3_delta_angle =  45.0;
        j3_angle  = init_pose(3):j3_delta_angle:j3_end_angle;
        joint_perturb = [ ...
            0.0   0.0  0.0  45.0 0.0 0.0;
            0.0  25.0  0.0   0.0 0.0 0.0;
            0.0   0.0  0.0 -45.0 0.0 0.0;
            0.0 -25.0  0.0   0.0 0.0 0.0;
            0.0   0.0 45.0   0.0 0.0 0.0];
        numPerturb = size(joint_perturb,1);
        
        target_pose_list(1,1:6)=init_pose;
        for i=1:size(j3_angle,2)
            for j=1:numPerturb
                k = (i-1)*numPerturb+j+1;
                target_pose_list(k,1:6)=target_pose_list(k-1,1:6)+joint_perturb(j,1:6);
                target_pose_list(k,3)=j3_angle(i)+joint_perturb(j,3);
            end
        end
        
        % remove the last pose it is bogus
        target_pose_list = target_pose_list(1:end-1,:);
        
        % generate the extended target list
        extended_target_pose_list = generate_target_list(target_pose_list);
        numOfPose = size(extended_target_pose_list,1);
        
        % convert the target pose list to radians
        extended_target_pose_list = extended_target_pose_list.*pi/180;
        
        %% initialize the regressor matrix
        A=zeros(numOfPose*6,8);
        B=zeros(numOfPose*6,1);
        
        % go to the initial pose
        prev_torque = hgs.go_to_position.torque_offset;
        
        
        for ip=1:numOfPose
            q_rad = extended_target_pose_list(ip,1:6);
            
            % move to the target position
            go_to_position(hgs,q_rad, 0.1,prev_torque);
            pause(2);
            qm = hgs.joint_angles;
            
            % these are bigger motions so slow down
            taum = hgs.go_to_position.torque_offset;
            
            prev_torque = taum;
            
            % form the regressor matrix
            [A,B] = form_regressor(qm, taum, ip,...
                TESTING_GRAV_COMP_CONSTANTS,...
                TESTING_GRAV_COMP_WEIGHTS,A,B);
            
            % update the progress bar
            set(progBar,...
                'XData',[0 ip/numOfPose ip/numOfPose 0]);
        end
        
        % do some math to decouple the p1,p2,p3,p4,p5,p6 for getting better accuracy
        for i=1:numOfPose
            A2((i-1)*4+1:(i-1)*4+4,1:6)=A((i-1)*6+1:(i-1)*6+4,1:6);
            for j=1:4
                B2((i-1)*4+j,1)=B((i-1)*6+j,1)-A((i-1)*6+j,7:8)*X1; %#ok<AGROW>
            end
        end
        
        % final computation
        A123456=A;
        B123456=B;
        X2=pinv(A2)*B2;
    end

%--------------------------------------------------------------------------
% internal function to decouple identification of parameter for forearm
%--------------------------------------------------------------------------
    function [X1,A78,B78,A1,B1] = collect_forearm_data(progBar)
        % target pose for p7, and p8
        target_pose_list =[ ...
            0.0    -90.0   -90.0   90.0     90.0     0.0;
            0.0    -90.0   -90.0   90.0    200.0    40.0;
            0.0    -90.0   -90.0   90.0      0.0   -37.0;
            0.0    -90.0   -90.0   90.0    -75.0    40.0;
            0.0    -90.0   -90.0   90.0    -75.0   -37.0;
            0.0    -90.0   -90.0   90.0    -75.0    40.0;
            0.0    -90.0   -90.0   90.0    150.0   -37.0;
            0.0    -90.0   -90.0   90.0    -75.0    40.0;
            0.0    -90.0   -90.0   90.0    150.0   0.0];
        
        % generate the extended target list
        extended_target_pose_list = generate_target_list(target_pose_list);
        numOfPose = size(extended_target_pose_list,1);
        
        % Convert the extendended target pose list to radians
        extended_target_pose_list = extended_target_pose_list.*pi/180;
        
        % Now start performing actual motion and collect data
        prev_torque = hgs.go_to_position.torque_offset;
        
        % initialize the regressor matrix
        A=zeros(numOfPose*6,8);
        B=zeros(numOfPose*6,1);
        
        for ip=1:numOfPose
            q_rad = extended_target_pose_list(ip,1:6);
            
            % move to the target position
            go_to_position(hgs,q_rad, 0.2,prev_torque);
            pause(2);
            qm = hgs.joint_angles;
            taum = hgs.go_to_position.torque_offset;
            prev_torque = taum;
            
            % form the regressor matrix
            [A,B] = form_regressor(qm, taum, ip,...
                TESTING_GRAV_COMP_CONSTANTS,...
                TESTING_GRAV_COMP_WEIGHTS,A,B);
            
            % update the progress bar
            set(progBar,...
                'XData',[0 ip/numOfPose ip/numOfPose 0]);
        end
        
        % do some math to decouple the p7,p8 for getting better accuracy
        for i=1:numOfPose
            % For p7,p8
            A1((i-1)*2+1:(i-1)*2+2,1:2)=A((i-1)*6+5:(i-1)*6+6,7:8);
            B1((i-1)*2+1:(i-1)*2+2,1)=B((i-1)*6+5:(i-1)*6+6,1);
        end
        
        % debugging purpose
        A78=A;
        B78=B;
        X1=pinv(A1)*B1;
    end
%--------------------------------------------------------------------------
% internal function form regressor
%--------------------------------------------------------------------------
    function [A,B] = form_regressor(q,tau,i,consts, weights,A,B)
        s1=sin(q(1)); c1=cos(q(1)); %#ok<NASGU>
        s2=sin(q(2)); c2=cos(q(2));
        s3=sin(q(3)); c3=cos(q(3));
        s4=sin(q(4)); c4=cos(q(4));
        s5=sin(q(5)); c5=cos(q(5));
        s6=sin(q(6)); c6=cos(q(6));
        
        % form the regressor matrix
        Ai = [...
            0,...
            0,...
            0,...
            0,...
            0,...
            0,...
            0,...
            0;
            
            s2*s4-c2*c3*c4,...
            s2*c4+c2*c3*s4,...
            -c2*c3,...
            c2*s3,...
            -s2,...
            -c2,...
            c2*s3*c5-s2*s4*s5+c2*c3*c4*s5,...
            s2*s4*c5*c6+s2*c4*s6+c2*c3*s4*s6+c2*s3*s5*c6-c2*c3*c4*c5*c6;
            
            
            s2*s3*c4,...
            -s2*s3*s4,...
            s2*s3,...
            s2*c3,...
            0,...
            0,...
            s2*c3*c5-s2*s3*c4*s5,...
            s2*c3*s5*c6+s2*s3*c4*c5*c6-s2*s3*s4*s6;
            
            -c2*c4+s2*c3*s4,...
            c2*s4+s2*c3*c4,...
            0,...
            0,...
            0,...
            0,...
            c2*c4*s5-s2*c3*s4*s5,...
            c2*s4*s6+s2*c3*c4*s6-c2*c4*c5*c6+s2*c3*s4*c5*c6;
            
            0,...
            0,...
            0,...
            0,...
            0,...
            0,...
            s2*c3*c4*c5+c2*s4*c5-s2*s3*s5,...
            s2*c3*c4*s5*c6+c2*s4*s5*c6+s2*s3*c5*c6;
            
            0,...
            0,...
            0,...
            0,...
            0,...
            0,...
            0,...
            s2*c3*c4*c5*s6+c2*s4*c5*s6-s2*s3*s5*s6+s2*c3*s4*c6-c2*c4*c6];
        
        tau_ff = Ai*consts';
        tau_wff = tau_ff.*weights';
        B((i-1)*6+1:(i-1)*6+6,1) = tau'+tau_wff;
        A((i-1)*6+1:(i-1)*6+6,1:8) = Ai;
    end


%--------------------------------------------------------------------------
% internal function to generate extended target list
%--------------------------------------------------------------------------
    function extended_target_pose_list = generate_target_list(target_pose_list)
        numOfTargetPose = size(target_pose_list,1);
        for i=1:numOfTargetPose-1;
            TravelAngle = target_pose_list(i+1,1:6)-target_pose_list(i,1:6);
            deltaAngle = TravelAngle./NUMBER_OF_INTERMEDIATE_POSITIONS;
            for j=1:NUMBER_OF_INTERMEDIATE_POSITIONS
                k=(i-1)*NUMBER_OF_INTERMEDIATE_POSITIONS+j;
                extended_target_pose_list(k,1:6) = target_pose_list(i,1:6)...
                    +deltaAngle.*j; %#ok<AGROW>
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to cancel the find gravity constants procedure
%--------------------------------------------------------------------------
    function cancelGravityConstantsProcedure
        log_message(hgs,'Find Gravity Constants Script Closed');
        cancelButtonPressed = true;
        closereq;
    end

end

% --------- END OF FILE ----------
