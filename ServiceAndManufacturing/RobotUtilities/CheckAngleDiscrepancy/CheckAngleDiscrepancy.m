function guiHandles=CheckAngleDiscrepancy(hgs,varargin)

% CheckAngleDiscrepancy Gui to guide user through angle  check procedure
%
% Syntax:
%   CheckAngleDiscrepancy(hgs)
%       this script can be used to check the angle  of the
%       hgs_robot specified by the argument "hgs"
%
% Notes:
%   The script will present a GUI to the user and show the user the range
%   to move the axis through.  During that time the code will keep track of
%   the maximum angle .  If this number is beyond the preset
%   threshold the error will be raised.
%
% See Also:
%   hgs_robot
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot
defaultRobotConnection = false;

% initialize real data collection
realData = 1;

if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles='';
        return;
    end
    
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
elseif(nargin > 1 && strcmp(varargin(1),'simulate'))
    hgs = [];
    realData = 0;
end

if(realData)
    % Check if the specified argument is a hgs_robot
    if (~isa(hgs,'hgs_robot'))
        error('Invalid argument: argument must be an hgs_robot object');
    end
    
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');
    
else
    % skip hgs robot check, gravity set
end

% Generate the gui
guiHandles = generateMakoGui('Angle Discrepancy Check',[],hgs);

if(~realData)
    % set simulate parameters
    count = [1 1 1 1 1 1];
    hgs.WAM_DOF = 6;
    hgs.JOINT_ANGLE_MAX = [2.2300 -1.0100 2.4200 2.9700 4.3620 3.9200];
    hgs.JOINT_ANGLE_MIN = [-2.2300 -1.7500 -2.4100 1.0500 -2.2580 -0.7900];
    hgs.JOINT_ANGLE_CONSISTANCY_THRESHOLD = [0.0500 0.0500 0.0500 0.0500 0.0500 0.0750];
    
end

userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@angleDiscrepancyCheckFcn);

% setup for cancel
abortProcedure = false;
set(guiHandles.figure,'CloseRequestFcn',@cancelProcedure);

% Set the limits
switch hgs.WAM_DOF
    case 5
        JointMinLimits = [-0.7854   -1.7453   -2.1817   0        -3.1416 ];
        JointMaxLimits = [1.5708   -1.0472    2.1817    2.9671    3.1414 ];
    case 6
        RANGE_TOLERANCE = [ 0.25 0.1 0.2 0.2 0.25 0.15];
        JointMinLimits = hgs.JOINT_ANGLE_MIN + RANGE_TOLERANCE;
        JointMaxLimits = hgs.JOINT_ANGLE_MAX - RANGE_TOLERANCE;
    otherwise
        error('Only 5 or 6 DOF robotic arm supported');
end

% Query CRISIS for the limits (80% for error and 50% for warning)
ErrorLimit = hgs.JOINT_ANGLE_CONSISTANCY_THRESHOLD * 0.8;
WarnLimit = hgs.JOINT_ANGLE_CONSISTANCY_THRESHOLD * 0.5;

% setup test parameters
ANGLE_LOG_THRESHOLD = pi/180;

display.rescale = 1;

if(display.rescale)
    % simulate joint positions
    % init discrepancy error array
    numSteps = 200;
    sweepA = 66;
    sweepB = numSteps - sweepA;
    % RANGE_TOLERANCE = [ 1 1 1 1 1 1 ].*.0001;
    for k = 1:6
        % create motion simulated parameters
        min(k) = hgs.JOINT_ANGLE_MIN(k) - RANGE_TOLERANCE(k);
        max(k) = hgs.JOINT_ANGLE_MAX(k) + RANGE_TOLERANCE(k);
        ran(k) = abs(min(k)-max(k));
        
        % create display parameters
        display.JointMinLimits(k) = -pi*0.5;
        display.JointMaxLimits(k) =  pi*0.5;
        start_pos(k) = (min(k)+ran(k)/2); % first position
        
    end
end


if(~realData)
    % simulate joint positions
    % init discrepancy error array
    numSteps = 200;
    sweepA = 66;
    sweepB = numSteps - sweepA;
    % RANGE_TOLERANCE = [ 1 1 1 1 1 1 ].*.0001;
    JointMinLimits = hgs.JOINT_ANGLE_MIN + RANGE_TOLERANCE;
    JointMaxLimits = hgs.JOINT_ANGLE_MAX - RANGE_TOLERANCE;
    for k = 1:6
        % create motion simulated parameters
        min(k) = hgs.JOINT_ANGLE_MIN(k) - RANGE_TOLERANCE(k);
        max(k) = hgs.JOINT_ANGLE_MAX(k) + RANGE_TOLERANCE(k);
        ran(k) = abs(min(k)-max(k));
        start_pos(k) = (min(k)+ran(k)/2); % first position
        simMotion{k}(1:sweepA) = (min(k)+ran(k)/2):-(ran(k)/2)/(sweepA-1):min(k); % first sweep
        simMotion{k}(sweepA+1:numSteps) =  min(k):(ran(k))/(sweepB-1):max(k);  % second sweep
        angleError{k} = [zeros(1,numSteps)];
        
    end
    
    % simulate a discrepancy error
    %joint = 1;
    %angleError{joint}(floor(numSteps/2)) = ErrorLimit(joint)*1.1;
    
    % simulate a discrepancy warning
    %joint = 1;
    %angleError{joint}(floor(numSteps/2)) = WarnLimit(joint)*1.1;
end

%--------------------------------------------------------------------------
% internal function to do the actual work for the angle  check
%--------------------------------------------------------------------------
    function angleDiscrepancyCheckFcn(varargin)
        if(realData)
            log_message(hgs,'Angle Discrepancy Check started');
            
            % First of all check for homing
            if ~homingDone(hgs)
                presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
                log_results(hgs,'Angle Discrepancy Check','FAIL',...
                    'Homing not done');
                return;
            end
            
            % make sure the enable button is pressed
            try
                robotFrontPanelEnable(hgs,guiHandles);
            catch
            end
            
        else
            % skip log homing check and LED
        end
        
        % check if this was a canceled procedure
        if abortProcedure
            return
        end
        
        
        % generate a region to plot
        dispAxis = axes(...
            'Parent',guiHandles.uiPanel,...
            'Position',[0.1 0.2 0.8 0.8],...
            'XLim',[-1.2 1.2],...
            'YLim',[-1.2 1.2],...
            'Box','off',...
            'ytick',[],...
            'xtick',[],...
            'Visible','off');
        
        % Generate the require patches
        basePatch = patch(0,0,'white','parent',dispAxis);
        regionCoveredPatch = patch(0,0,'green','parent',dispAxis);
        currentPositionLine = line([0 0],[0 0],...
            'linewidth',3,...
            'parent',dispAxis);
        % set axis aspect ratio so that pie plot is always circular
        axis(dispAxis,'equal');
        % Allocate some storage for results
        maxTestError = zeros(1,hgs.WAM_DOF);
        
        if(realData)
            % Put the robot in gravity mode
            mode(hgs,'zerogravity','ia_hold_enable',0);
        else
            % skip zerogravity
        end
        
        % setup logs
        angleLog{hgs.WAM_DOF} = [];
        errorLog{hgs.WAM_DOF} = [];
        
        % Handle one axis at a time
        for i=1:hgs.WAM_DOF
            updateMainButtonInfo(guiHandles,'text',...
                sprintf('Please Exercise Joint %d',i));
            
            
            if(realData)
                % reset the min-max angle moved
                minAngle = hgs.joint_angles(i);
                maxAngle = hgs.joint_angles(i);
            else
                hgs.joint_angles(i) = start_pos(i);
                minAngle = hgs.joint_angles(i);
                maxAngle = hgs.joint_angles(i);
            end
            
            if(display.rescale)
                display.minAngle = rescaleRange(minAngle,JointMinLimits(i),JointMaxLimits(i),display.JointMinLimits(i),display.JointMaxLimits(i));
                display.maxAngle = display.minAngle;
            end
            
            
            % Setup the traditional pie type plot as in the 1.X
            % system
            
            % Start with the base pie for the range
            if(display.rescale)
                [x,y] = generateArcPoints(display.JointMinLimits(i),display.JointMaxLimits(i));
            else
                [x,y] = generateArcPoints(JointMinLimits(i),JointMaxLimits(i));
            end
            set(basePatch,'XData',x,'YData',y);
            
            % Reset the plots
            if(display.rescale)
                [x,y] = generateArcPoints(display.minAngle,display.maxAngle);
            else
                [x,y] = generateArcPoints(minAngle,maxAngle);
            end
            set(regionCoveredPatch,'XData',x,'YData',y,'facecolor','green');
            
            % Setup test status
            testSuccessful = true;
            
            % setup logs
            prevAngle = 0;
            
            % Start processing the data
            while ~abortProcedure
                
                if(realData)
                    % query robot for current angles
                    hgsVars = get(hgs);
                    currentAngle = hgsVars.joint_angles(i);
                    currentAngleError = abs(hgsVars.joint_angle_error(i));
                else
                    hgsVars.joint_angle_error(i) = angleError{i}(count(i));
                    currentAngle = simMotion{i}(count(i));
                    currentAngleError = abs(hgsVars.joint_angle_error(i));
                    count(i) = count(i) + 1;
                end
                if(display.rescale)
                    display.currentAngle = rescaleRange(currentAngle,JointMinLimits(i),JointMaxLimits(i),display.JointMinLimits(i),display.JointMaxLimits(i));
                end
                % update logs if needed
                if abs(prevAngle-currentAngle)>ANGLE_LOG_THRESHOLD
                    angleLog{i}(end+1) = currentAngle;
                    errorLog{i}(end+1) = hgsVars.joint_angle_error(i);
                end
                
                % current position line display coords
                if(display.rescale)
                    x = [0,sin(display.currentAngle)];
                    y = [0,cos(display.currentAngle)];
                else
                    x = [0,sin(currentAngle)];
                    y = [0,cos(currentAngle)];
                end
                set(currentPositionLine,'XData',x,'YData',y);
                
                % Check if the max range needs to be updated
                if minAngle>currentAngle
                    minAngle = currentAngle;
                    if(display.rescale)
                        display.minAngle = rescaleRange(currentAngle,JointMinLimits(i),JointMaxLimits(i),display.JointMinLimits(i),display.JointMaxLimits(i));
                    end
                end
                
                if maxAngle<currentAngle
                    maxAngle = currentAngle;
                    if(display.rescale)
                        display.maxAngle = rescaleRange(currentAngle,JointMinLimits(i),JointMaxLimits(i),display.JointMinLimits(i),display.JointMaxLimits(i));
                    end
                end
                
                % Update the plots
                if(display.rescale)
                    [x,y] = generateArcPoints(display.minAngle,display.maxAngle);
                else
                    [x,y] = generateArcPoints(minAngle,maxAngle);
                end
                set(regionCoveredPatch,'XData',x,'YData',y);
                
                % Do the checks here
                if maxTestError(i)<currentAngleError
                    maxTestError(i) = currentAngleError;
                end
                
                % Change color if in warning region
                if maxTestError(i)>WarnLimit(i)
                    set(regionCoveredPatch,'FaceColor','yellow');
                end
                
                % Stop if in error region
                if maxTestError(i)>ErrorLimit(i)
                    testSuccessful = false;
                    break;
                end
                
                % Check if the desired range has been achieved
                if(realData)
                    if (minAngle<JointMinLimits(i)) && (maxAngle>JointMaxLimits(i))
                        break;
                    end
                else
                    if (minAngle<JointMinLimits(i)) && (maxAngle>JointMaxLimits(i))
                        break;
                    end
                end
                
                % check if the mode is still running
                % if not fail immediately
                if(realData)
                    if ~strcmpi(mode(hgs),'zerogravity')
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Arm Stopped: %s',char(hgs.zerogravity.mode_error)));
                        log_results(hgs,'Angle Discrepancy Check','FAIL',...
                        ['Angle Discrepancy Check failed (Arm Stopped: ',...
                            char(hgs.zerogravity.mode_error),')']);
                        userDataStruct.results=-1;
                        set(guiHandles.figure,'UserData',...
                            userDataStruct);
                        return;
                    end
                else
                    % skip zerogravity (no-error) check
                end
                
                pause(0.01);
                drawnow;
            end
            
            % if this was an abort request exit quietly
            if abortProcedure
                return;
            end
            
            % Check if the test passed or failed.  If it failed quit
            % immediately
            
            if ~testSuccessful
                break;
            end
            
        end
        
        % Turn off all the displays
        delete(dispAxis);
        
        % save the logs
        logFile = ['AngleDiscrepancy-', datestr(now,'yyyy-mm-dd-HH-MM')];
        fullLogFile = fullfile(guiHandles.reportsDir,logFile);
        save(fullLogFile,'maxTestError','angleLog','errorLog');
        
        if(realData)
            % Put the robot in gravity mode with hold enabled
            mode(hgs,'zerogravity');
        else
            % skip zerogravity
        end
        
        % Present the results
        if ~testSuccessful
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Joint %d: max angle error = %3.4f (limit %3.4f rad)',...
                i,maxTestError(i),ErrorLimit(i)));
            
            if(realData)
                % log the results
                log_results(hgs,'Angle Discrepancy Check','FAIL',...
                'Angle Discrepancy check failed',...
                    'maxAngleDiscrepancy',maxTestError);
            else
                % skip log
            end
            userDataStruct.results=-1;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
            
        else
            % The tests were successful, check if there were any warnings
            if any(maxTestError>WarnLimit)
                % construct the warning message
                warnStringIndex = 1;
                for i=1:hgs.WAM_DOF
                    if maxTestError(i)>WarnLimit(i)
                        warnString{warnStringIndex} = sprintf(...
                            'Joint %d: max angle error = %3.4f (limit %3.4f rad)',...
                            i,maxTestError(i),ErrorLimit(i));%#ok<AGROW>
                        warnStringIndex = warnStringIndex+1;
                    end
                end
                presentMakoResults(guiHandles,'WARNING',warnString);
                if(realData)
                    log_results(hgs,'Angle Discrepancy Check','WARNING',...
                    'Angle Discrepancy check warning',...
                        'maxAngleDiscrepancy',maxTestError);
                else
                    % skip log
                end
                userDataStruct.results=2;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
            else
                presentMakoResults(guiHandles,'SUCCESS');
                if(realData)
                    log_results(hgs,'Angle Discrepancy Check','PASS',...
                    'Angle Discrepancy check passed',...
                        'maxAngleDiscrepancy',maxTestError);
                else
                    % skip log
                end
                userDataStruct.results=1;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
            end
        end
    end
%--------------------------------------------------------------------------
% internal function to rescale range
%--------------------------------------------------------------------------

    function [new_pos] = rescaleRange(cur_pos, cur_min, cur_max, new_min, new_max)
        new_pos = (cur_pos - cur_min)*(abs(new_max-new_min))/abs(cur_max-cur_min)+new_min;
    end

%--------------------------------------------------------------------------
% internal function to generate the patch points for an arc
%--------------------------------------------------------------------------
    function [arcXpts, arcYpts] = generateArcPoints(minAng,maxAng)
        resAng = (maxAng-minAng)/100;
        
        t = minAng:resAng:maxAng;
        
        % generate the arc and stick a (0,0) at the end to make it join at the
        % center of the circle
        arcXpts = [sin(t) 0];
        arcYpts = [cos(t) 0];
    end

%--------------------------------------------------------------------------
% Internal function to handle the script cancel
%--------------------------------------------------------------------------
    function cancelProcedure(varargin)
        abortProcedure = true;
        
        % Put the robot in gravity mode with hold enabled
        mode(hgs,'zerogravity');
        
        % indicate cancel to calling script
        userDataStruct.results=0;
        
        % close the connection if it was established by this script
        if defaultRobotConnection
            log_message(hgs,'Angle Discrepancy Check script closed');
            close(hgs);
        end
        closereq;
    end
end


% --------- END OF FILE ----------
