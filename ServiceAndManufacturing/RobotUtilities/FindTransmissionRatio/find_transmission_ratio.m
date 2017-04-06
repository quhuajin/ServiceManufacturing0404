function find_transmission_ratio(hgs)
%FIND_TRANSMISSION_RATIO Gui to help to find transmission ratio of the hgs robot.
%
% Syntax:
%   find_transmission_ratio(hgs)
%       Compute the transmission ratio for the given Robot
%
% See also:
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
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
    
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
end

% Check if the specified argument is a hgs_robot
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end
try
% Generate the gui
guiHandles = generateMakoGui('Find Transmission Ratio',[],hgs,true);
log_message(hgs,'Find Transmission Ratio Started');
%setup for cancel
terminateScript = false;
set(guiHandles.figure,'CloseRequestFcn',@find_transmission_ratio_close);

% Check if robot is homed
if ~homingDone(hgs)
    presentMakoResults(guiHandles,'FAILURE','Homing Not Done');

    log_results(hgs,guiHandles.scriptName,'ERROR','Find Transmission Ratio failed (Homing not done)');
    return;
end

robotFrontPanelEnable(hgs,guiHandles);

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@find_transmission_ratio_callback);

%define parameters for the test
%get hardware version, transmission ratio is different for different version
hgsHardwareVersion=hgs.ARM_HARDWARE_VERSION;

switch int32(hgsHardwareVersion * 10 + 0.05)
    case 20 % 2.0
        NOMINAL_TRANSMISSION_RATIO =     [-0.0665665  -0.06472746    0.077   -0.0458  -0.21482  -0.200011];
        TRANSMISSION_RATIO_UPPER_LIMIT = [-0.0649836  -0.06368376   0.0788   -0.0447  -0.21143  -0.197102];
        TRANSMISSION_RATIO_LOWER_LIMIT = [-0.0681495  -0.06577188   0.0752   -0.0468  -0.21821  -0.202938];
    case 21 % 2.1
        %
        NOMINAL_TRANSMISSION_RATIO = [-0.066566546	-0.064727819   0.07697334  -0.045780589  -0.218160531  -0.133259838];
        TRANSMISSION_RATIO_LIMIT =   [ 0.001582985	 0.001044063  0.001815973   0.001062183   0.003382334    0.00247914];
    case 22 % 2.2
        %
        NOMINAL_TRANSMISSION_RATIO = [-0.066566546	-0.064727819   0.07697334  -0.045780589  -0.218160531  -0.133259838];
        TRANSMISSION_RATIO_LIMIT =   [ 0.001582985	 0.001044063  0.001815973   0.001062183   0.003382334    0.00247914];
    case 23 % 2.3
        %
        NOMINAL_TRANSMISSION_RATIO = [-0.066566546	-0.064727819   0.07697334  -0.045780589  -0.218160531  -0.133259838];
        TRANSMISSION_RATIO_LIMIT =   [ 0.001582985	 0.001044063  0.001815973   0.001062183   0.003382334    0.00247914];
    case 30 % 3.0
        %
        NOMINAL_TRANSMISSION_RATIO = [-0.066566546	-0.064727819   0.07697334  -0.045780589  -0.218160531  -0.133259838];
        TRANSMISSION_RATIO_LIMIT =   [ 0.001582985	 0.001044063  0.001815973   0.001062183   0.003382334    0.00247914];
    otherwise
        presentMakoResults(guiHandles,'FAILURE',...
            sprintf('Unsupported Robot version: V%2.1f',hgsHardwareVersion));
        return;
end

RANGE_TOLERANCE = [5,3,5,5,5,5]/180*pi; % radians


FIT_ERROR_LIMIT = [0.05   0.05   0.05   0.05   0.05   0.05]; %consistent with CRISIS joint angle discrepancy check.
ANGLE_CHANGE_THRESHOLD = 0.1*pi/180; %radians

% Direction of Motor torque
% to motor motion
%    1 => same direction
%   -1 => opposite direction
MOTOR_TORQUE_DIRECTION = [ -1 -1 -1 -1 -1 -1];

% setup values needed by the script
dof=hgs.WAM_DOF;
negMotionLimit = hgs.JOINT_ANGLE_MIN + RANGE_TOLERANCE(1:dof);
posMotionLimit = hgs.JOINT_ANGLE_MAX - RANGE_TOLERANCE(1:dof);
dataCollectionDone(1:dof) = false;

% compute an offset so all the graphics is centered about vertical
angleOffset = -negMotionLimit-(posMotionLimit-negMotionLimit)/2;

% Generate the basic GUI.  This is going to be pies on the extra panel.
%  This is done to make it look different from the find homing
%  constants
%set up display text location
commonTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.8,...
    'HorizontalAlignment','left');

nextAxis = uicontrol(commonTextProperties,...
    'Parent',guiHandles.uiPanel,...
    'Position',[0.1 0.3 0.8 0.3],...
    'FontSize',0.3,...
    'BackgroundColor','white');

for i=1:dof %#ok<FXUP>
    dispText(i) = uicontrol(commonTextProperties,...
        'Parent',guiHandles.extraPanel,...
        'Position',[0.05, 0.95+0.05-0.15*i, 0.5, 0.075],...
        'FontWeight','Normal',...
        'String',sprintf('Joint %d',i),...
        'BackgroundColor','white'); %#ok<AGROW>
    dispAxis(i) = axes(...
        'Parent',guiHandles.extraPanel,...
        'Position',[0.6 0.95-0.15*i 0.3 0.15],...
        'XLim',[-1.2 1.2],...
        'YLim',[-1.2 1.2],...
        'Box','off',...
        'ytick',[],...
        'xtick',[],...
        'Visible','off'); %#ok<AGROW>
    
    % set axis aspect ratio so that pie plot is always circular
    axis(dispAxis(i),'equal');
    
    % Generate the require patches
    basePatch(i) = patch(0,0,'white',...
        'parent',dispAxis(i)); %#ok<AGROW>
    regionCoveredPatch(i) = patch(0,0,[0.6 0.6 0.6],...
        'parent',dispAxis(i)); %#ok<AGROW>
    currentPositionLine(i) = line([0 0],[0 0],...
        'linewidth',3,...
        'parent',dispAxis(i)); %#ok<AGROW>
    
    [x,y] = generateArcPoints(negMotionLimit(i)+angleOffset(i),...
        posMotionLimit(i)+angleOffset(i));
    set(basePatch(i),'XData',x,'YData',y);
end
catch
    
    if terminateScript
        find_transmission_ratio_close({})
    else
        presentMakoResults(guiHandles,'FAILURE',lasterr); %#ok<*LERR>
        return;
    end
end
%--------------------------------------------------------------------------
% internal function to update the GUI and compute the transmission ratio
%--------------------------------------------------------------------------
    function find_transmission_ratio_callback(varargin)
        try
            % Check if the arm version number matches if not error immediately
            if hgs.ARM_HARDWARE_VERSION<2.0
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unsupported Robot version %2.2f',hgs.ARM_HARDWARE_VERSION));
                return;
            end
            %get into the routine where user has to press the
            %flashing green button
            robotFrontPanelEnable(hgs,guiHandles);
            
            %put the arm in zero gravity
            updateMainButtonInfo(guiHandles,'text',...
                'Move each joint from one joint stop to the other');
            mode(hgs,'zerogravity','ia_hold_enable',0);
            
            % Capture the current location as the start point
            [jointAngles(1,:),motorAngles(1,:)] = get(hgs,'joint_angles','motor_angles');
            minRegionCovered = jointAngles;
            maxRegionCovered = jointAngles;
            
            terminateScript = false;
            while(~terminateScript)
                
                % get the data from the arm
                [currentJointAngles,currentMotorAngles] = get(hgs,...
                    'joint_angles','motor_angles');
                
                % add data to list only if angles have changed
                if (max(abs(jointAngles(end,:)-currentJointAngles))>ANGLE_CHANGE_THRESHOLD)
                    jointAngles(end+1,:) = currentJointAngles; %#ok<AGROW>
                    motorAngles(end+1,:) = currentMotorAngles; %#ok<AGROW>
                    
                    % update the min and max values
                    minRegionCovered = min(jointAngles);
                    maxRegionCovered = max(jointAngles);
                end
                
                for i=1:dof %#ok<FXUP>
                    % Update the display
                    x = [0,sin(currentJointAngles(i)+angleOffset(i))];
                    y = [0,cos(currentJointAngles(i)+angleOffset(i))];
                    set(currentPositionLine(i),'XData',x,'YData',y);
                    
                    % Update the region covered display
                    [x,y] = generateArcPoints(minRegionCovered(i)+angleOffset(i),...
                        maxRegionCovered(i)+angleOffset(i));
                    set(regionCoveredPatch(i),'XData',x,'YData',y);
                    
                    % Check each axis to make sure full motion has been
                    % achieved
                    if (~dataCollectionDone(i)) ...
                            && (minRegionCovered(i)<negMotionLimit(i) ...
                            && maxRegionCovered(i)>posMotionLimit(i))
                        dataCollectionDone(i) = true;
                        set(regionCoveredPatch(i),'facecolor','g');
                        set(dispText(i),'BackgroundColor','green');
                    end
                end
                
                if isempty(find(dataCollectionDone,1))
                    set(nextAxis,'String',...
                        {'Please Move','Joint 1'});
                else
                    set(nextAxis,'String',...
                        {'Please Move',sprintf('Joint %d',find(~dataCollectionDone,1))});
                end
                
                % check if the mode is still running
                % if not fail immediately
                if ~strcmpi(mode(hgs),'zerogravity')
                    presentMakoResults(guiHandles,'FAILURE',...
                        sprintf('Arm Stopped: %s',char(hgs.zerogravity.mode_error)));
                    return;
                end
                
                % pause a little while to update GUI
                pause(0.01);
                drawnow;
                
                %set complete flag and exit
                if dataCollectionDone
                    break;
                end
            end
        catch
            if terminateScript
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',lasterror);
            end
        end
        
        % if this was a cancel, just exit elegantly
        if terminateScript
            return;
        end
        
        % Compute the values for the transmission ratio based on the data
        % collected
        for i=1:dof %#ok<FXUP>
            residual=[];
            % remove data beyond useful range
            idx = [find(jointAngles(:,i)>negMotionLimit(i));
                find(jointAngles(:,i)<posMotionLimit(i))];
            %fit model y'=ax+b
            ft=polyfit(motorAngles(idx,i),jointAngles(idx,i),1);
            transmissionRatio(i)=ft(1);
            %error e=y-ax
            residual(i,:)=jointAngles(idx,i)-motorAngles(idx,i)*transmissionRatio(i);
            %mean error = sqrt(mean square error)
            fitResidual(i) =sqrt(norm(residual(i,:))^2/length(jointAngles(idx,i)));
        end
        
        % generate the matrices
        motorAnglesToJointAngles = diag(transmissionRatio);
        jointTorquesToMotorTorques = diag(transmissionRatio.*MOTOR_TORQUE_DIRECTION);
        
        % we have all the data collected save the data in a log file
        logFile = ['TransmissionRatio-', datestr(now,'yyyy-mm-dd-HH-MM')];
        fullLogFile = fullfile(guiHandles.reportsDir,logFile);
        save(fullLogFile,'motorAngles','jointAngles','transmissionRatio',...
            'motorAnglesToJointAngles','jointTorquesToMotorTorques','fitResidual', 'FIT_ERROR_LIMIT');
        
        % Show the results
        % generate title lines
        set(nextAxis,'visible','off');
        uicontrol(commonTextProperties,...
            'Parent',guiHandles.uiPanel,...
            'Position',[0.1,0.7,0.84,0.1],...
            'BackgroundColor',[0.7 0.7 0.7],...
            'FontWeight','bold',...
            'String','Computed Transmission Ratio');
        
        uicontrol(commonTextProperties,...
            'Parent',guiHandles.uiPanel,...
            'Position',[0.1,0.4,0.84,0.1],...
            'BackgroundColor',[0.7 0.7 0.7],...
            'String','Nominal Transmission Ratio');
        
        % display the generated constants
        errorOccured = false;
        for i=1:dof %#ok<FXUP>
            
        hgsHardwareVersion=hgs.ARM_HARDWARE_VERSION;

            switch int32(hgsHardwareVersion * 10 + 0.05)
                case 20
                     if ((transmissionRatio(i) > TRANSMISSION_RATIO_UPPER_LIMIT(i)) ...
                            || (transmissionRatio(i) < TRANSMISSION_RATIO_LOWER_LIMIT(i)) ...
                            || (abs(fitResidual(i))>FIT_ERROR_LIMIT(i)))
                        errorOccured = true;
                        resultColor = 'red';
                    else
                        resultColor = 'green';
                    end
                    
                otherwise
            
                    if ((abs(transmissionRatio(i)-NOMINAL_TRANSMISSION_RATIO(i))>TRANSMISSION_RATIO_LIMIT(i)) ...
                            || (abs(fitResidual(i))>FIT_ERROR_LIMIT(i)))
                        errorOccured = true;
                        resultColor = 'red';
                    else
                        resultColor = 'green';
                    end
            end
            
            uicontrol(commonTextProperties,...
                'Parent',guiHandles.uiPanel,...
                'Position',[0.1+0.14*(i-1),0.6,0.14,0.1],...
                'BackgroundColor',resultColor,...
                'FontSize',0.4,...
                'String',sprintf('%3.5f',transmissionRatio(i)));
            
            % also display the nominal for reference
            uicontrol(commonTextProperties,...
                'Parent',guiHandles.uiPanel,...
                'Position',[0.1+0.14*(i-1),0.3,0.14,0.1],...
                'BackgroundColor',[0.75 0.75 0.75],...
                'FontSize',0.4,...
                'String',sprintf('%3.5f',NOMINAL_TRANSMISSION_RATIO(i)));
            
        end
        
        
        % declare success or warning
        if  errorOccured
            presentMakoResults(guiHandles,'FAILURE',...
                'Transmission Ratio Computation Failed');
        else
            % send data to the Robot
            hgs.MOTOR_2_JOINT_ANGLE = motorAnglesToJointAngles;
            hgs.JOINT_TQ_2_MOTOR_TQ = jointTorquesToMotorTorques;
            
            try
                cautionTitle = uicontrol(guiHandles.uiPanel,...
                    'Style','text',...
                    'String','ATTENTION',...
                    'fontUnits','normalized',...
                    'fontSize',0.8,...
                    'Units','normalized',...
                    'background','yellow',...
                    'Position',[0.05 0.75 0.9 0.2]);
                cautionHandle = uicontrol(guiHandles.uiPanel,...
                    'Style','text',...
                    'fontUnits','normalized',...
                    'fontSize',0.1,...
                    'Units','normalized',...
                    'background','white',...
                    'Position',[0.05 0.05 0.9 0.7]);
                for countDown=3:-1:0
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Restarting Arm in %d sec',countDown));
                    set(cautionHandle,...
                        'String',{'Transmission Ratio Updated Successfully',...
                        sprintf('Restarting Arm in %d sec',countDown),...
                        ' ','BRAKES WILL ENGAGE'});
                    pause(1);
                end
                updateMainButtonInfo(guiHandles,'text',...
                    'Restarting Arm...Please Wait');
                delete(cautionHandle);
                delete(cautionTitle);
                drawnow
            catch
            end
            
            % check for cancel button press
            if terminateScript
                return;
            end
            
            restartCRISIS(hgs);
            presentMakoResults(guiHandles,'SUCCESS',...
                {'Transmission Ratio Updated Successfully',...
                'Press Enable button to continue'});
        end
%       stop(hgs);  
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
%   Internal function to close the figures when cancel button is pressed
%--------------------------------------------------------------------------
    function find_transmission_ratio_close(varargin)
        
        %set cancel flag
        terminateScript=true;
        pause(0.3);

        % go to gravity mode on exit
        try
        mode(hgs,'zerogravity','ia_hold_enable',0);
        log_message(hgs,'Find Transmission Ratio Closed');
        % close the connection to the robot
        if defaultRobotConnection
            close(hgs);
        end
        catch
        end
        % close the image
        closereq

    end
end

% --------- END OF FILE ----------
