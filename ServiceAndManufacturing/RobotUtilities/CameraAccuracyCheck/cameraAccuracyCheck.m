function cameraAccuracyCheck(hgs_or_ndi)

% checkAngleDiscrepency Gui to guide user through angle discrepancy check procedure
%
% Syntax:
%   cameraAccuracyCheck(hgs)
%       this script can be used to check the angle discrepancy of the
%       the camera to be tested can be specified by the hgs argument.
%       where hgs is a hgs_robot to which the camera is connected
%
%   cameraAccuracyCheck(ndi)
%       This option allows you to directly use a camera object rather than
%       a camera connected to the robot.  argument ndi is a ndi_camera
%       object
%
%   cameraAccuracyCheck(commPort)
%       This option allows you to specify the comm port where the camera is
%       connected
%
% Notes:
%   The user is guided through a simple pivot.  This uses the service kit
%   socket array.  The script generates a log file that will include the
%   collected data and the final results.  in addition it will also include
%   the socket correction offset
%
% See Also:
%   ndi_camera, hgs_robot
%

%
% $Author: dmoses $
% $Revision: 3739 $
% $Date: 2015-01-16 17:38:50 -0500 (Fri, 16 Jan 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% If there is no argument assume this is for use through the hgs_robot
defaultRobotConnection = false;
if nargin<1
    hgs_or_ndi = connectRobotGui;
    if isempty(hgs_or_ndi)
        return;
    end
    
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
end

% Check if the specified argument
if isa(hgs_or_ndi,'hgs_robot')
    hgs = hgs_or_ndi;
    ndi = ndi_camera(hgs);
    ndiCommand = 'bx';
elseif isa(hgs_or_ndi,'ndi_camera')
    hgs = 'LocalCamera';
    ndi = hgs_or_ndi;
    ndiCommand = 'tx';
elseif ischar(hgs_or_ndi)
    hgs = 'LocalCamera';
    ndi = ndi_camera(hgs_or_ndi);
    ndiCommand = 'tx';
else
    error('Invalid argument, refer documentation for options');
end

% Set test constants
RMS_ERROR_LIMIT = 0.6/1000; % meters
MAX_ERROR_LIMIT = 1.5/1000; % meters
MAX_CONDITION_NUMBER = 10;
WARNING_RATIO = 0.75;
numDataCaptured = 0;
ANGLE_CHANGE_THRESHOLD = 15*pi/180; % radians.  change required before new data is captured
NUM_OF_SAMPLES_REQ = 10;   % number of sample that are averaged for noise
MAX_ALLOWED_STD = 0.005; % rad

TEST_TOOL_SROM = fullfile('sroms','110740.rom');
MAX_NUM_POINTS = 10;

% Generate the gui
guiHandles = generateMakoGui('Camera Accuracy Check',[], hgs,true);

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@initializeCamera);

% initialize location for data capture
capturedToolPosition = zeros(MAX_NUM_POINTS,3);
capturedToolQuat = zeros(MAX_NUM_POINTS,4);

% connect to the camera
terminate_loops = false;
plotTimer=[];
toolInfo = [];
%--------------------------------------------------------------------------
% internal function to initialize the camera
%--------------------------------------------------------------------------
    function initializeCamera(varargin)
        
        % log the test start
        if isa(hgs,'hgs_robot')
            log_message(hgs,'Camera Accuracy check started');
        end
        
        delete(get(guiHandles.uiPanel,'children'));
        updateMainButtonInfo(guiHandles,'text','Initializing Camera...');
        try
            % If this is a rerun.  stop the plot timer
            if isempty(plotTimer)
                % initialize the camera
                init(ndi);

                % add a little dalay before calling init_tool
                % and retry once after the intial failure
                try
                    pause(0.5);
                    init_tool(ndi,TEST_TOOL_SROM);
                catch
                    try
                        pause(1.0);
                        init_tool(ndi,TEST_TOOL_SROM);
                    catch
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Camera Tool Init Failed, Exit and Check Again %s',...
                            lasterr));
			log_results(hgs,'Camera Accuracy Check','FAIL',...
                        	['Camera Accuracy Check init_tool failed,',lasterr]);
                        return;
                    end
                end

                % Generate a plot
                plotHandle = plot(ndi,guiHandles.extraPanel);
                plotTimer = plotHandle.timer;

                % Slow the timer it is not so important
                stop(plotTimer);
                set(plotTimer,'Period',0.05);
                start(plotTimer);

                % setup the termination function
                set(guiHandles.figure,'CloseRequestFcn',@closeFcn);
            end

            % check if tool is visible
            toolInfo = feval(ndiCommand, ndi);

            % Get stuck till the tracker becomes visible
            while ~strcmpi(toolInfo.status,'VISIBLE') && ~terminate_loops
                updateMainButtonInfo(guiHandles,'text',...
                    'Make Sure Tracker is visible');
                toolInfo = feval(ndiCommand, ndi);
            end
        catch
            return;
        end

        % if the loop termination was requested quit
        if terminate_loops
            return
        end

        % Generate a big text box with instructions on where to place the
        % tracker
        
        try
            uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontWeight','bold',...
                'FontUnits','normalized',...
                'FontSize',0.4,...
                'String','Make Sure the tracker is on the rigid Sphere',...
                'Position',[0.1 0.7 0.8 0.2]);

            updateMainButtonInfo(guiHandles,'pushbutton',...
                'Start Data Collection',@collectCameraData);
        catch
            return;
        end

    end

%--------------------------------------------------------------------------
% internal function to collect the data from the camera
%--------------------------------------------------------------------------
    function collectCameraData(varargin)
        
        try
            % Clear the GUI
            delete(get(guiHandles.uiPanel,'children'));

            % Generate a big progressbar
            progaxes = axes(...
                'Parent',guiHandles.uiPanel,...
                'Color','white',...
                'Position',[0.1 0.7 0.8 0.2],...
                'XLim',[0 1],...
                'YLim',[0 1],...
                'Box','on',...
                'ytick',[],...
                'xtick',[] );
            progressbar = patch(...
                'Parent',progaxes,...
                'XData',[0 0 0 0],...
                'YData',[0 0 1 1],...
                'FaceColor','green'...
                );

            % Update user instruction
            updateMainButtonInfo(guiHandles,'text',...
                'Move tracker to different orientation on ball');

            tinybeep = wavread(fullfile('sounds','tinybeep.wav'));

            % Now start collection
            numDataCaptured = 1;
            numSamples = 1;

            while ~terminate_loops

                % Get data from camera
                toolInfo = feval(ndiCommand, ndi);

                % check if the cancel button got pressed
                if terminate_loops
                    break;
                end

                % Change Progressbar to text if tracker goes invisible
                if strcmpi(toolInfo.status,'MISSING')
                    mainText = 'Tracker Not Visible';
                    set(progressbar,...
                        'FaceColor','red');
                else
                    set(progressbar,...
                        'FaceColor','green')
                    % Check if the tracker has moved since last data capture
                    % Check the angles to see if the angles have changed
                    trackerPositionChanged = false;

                    if angleChanged
                        trackerPositionChanged = true;
                    end

                    % now check if the tracker is stationary

                    % make sure we have required number of samples if not wait
                    trackerPositionStable = false;
                    if (numSamples <= NUM_OF_SAMPLES_REQ)
                        toolInfoLog(numSamples) = toolInfo;
                        numSamples = numSamples+1;
                    else
                        % maintain a ring buffer
                        toolInfoLog = [toolInfoLog(2:end) toolInfo];

                        % analyze the data
                        toolAngleMat = reshape([toolInfoLog(:).quaternion],4,NUM_OF_SAMPLES_REQ);
                        if std(toolAngleMat,0,2)<MAX_ALLOWED_STD
                            trackerPositionStable=true;
                        end
                    end

                    if ~trackerPositionChanged
                        mainText = 'Please change tracker angle';
                    elseif ~trackerPositionStable
                        mainText = 'Waiting for tracker to stabilize';
                    else
                        mainText = 'Collecting Data';
                        % compute the mean of the position for storing
                        toolPosMat = reshape([toolInfoLog(:).position],3,NUM_OF_SAMPLES_REQ);
                        sound(tinybeep);
                        % compute the data capture progress
                        capturedToolPosition(numDataCaptured,1:3) = mean(toolPosMat,2)';
                        capturedToolQuat(numDataCaptured,1:4) = toolInfo.quaternion;
                        numDataCaptured = numDataCaptured+1;

                        % update the progress bar
                        testProgress = (numDataCaptured-1)/MAX_NUM_POINTS;
                        set(progressbar,...
                            'XData',[0 testProgress testProgress 0]);
                    end

                    % check for termination condition
                    if (numDataCaptured>MAX_NUM_POINTS)
                        drawnow;
                        break;
                    end
                end

                % handle cancel call during a drawnow
                try
                    updateMainButtonInfo(guiHandles,'text',mainText);
                catch
                end
                drawnow;
            end

            if terminate_loops
                return;
            end

            % tell user of data collection completion
            updateMainButtonInfo(guiHandles,'text',...
                'Data collection complete');

            pause(0.5);

            % All data has been captured.   Change the GUI to a button to allow
            % for recapture if necessary
            delete(get(guiHandles.uiPanel,'children'));

            uicontrol(guiHandles.uiPanel,...
                'Style','pushbutton',...
                'Units','Normalized',...
                'FontUnits','normalized',...
                'FontSize',0.4,...
                'String','Recollect Data',...
                'Position',[0.3 0.2 0.4 0.1],...
                'Callback',@initializeCamera);

            % Update the main button to proceed
            updateMainButtonInfo(guiHandles,'pushbutton','Compute Errors',...
                @computePivotError);
        catch
            return;
        end

    end

%--------------------------------------------------------------------------
% internal function to compute the RMS and Max Pivot error
%--------------------------------------------------------------------------
    function computePivotError(varargin)
        try
            % Clean the GUI
            delete(get(guiHandles.uiPanel,'children'));

            % compute the centroid
            centroid = mean(capturedToolPosition);
            for i=1:MAX_NUM_POINTS
                distance_from_centroid(i) = norm(capturedToolPosition(i,:)-centroid); %#ok<AGROW>
            end

            for i=1:MAX_NUM_POINTS-1
                A((i-1)*3+1:(i-1)*3+3,1:3) = q2rot(capturedToolQuat(i,:))-q2rot(capturedToolQuat(i+1,:));
                b((i-1)*3+1:(i-1)*3+3,1)   = capturedToolPosition(i+1,:)-capturedToolPosition(i,:);
            end

            % Compute the tool correction and store for use if needed
            conditionNumber = cond(A);
            toolCorrection = pinv(A)*b; %#ok<NASGU>

            % compute the max error
            maxError = max(distance_from_centroid);

            % compute the rms error
            rmsError = norm(distance_from_centroid)/sqrt(MAX_NUM_POINTS);

            % Save results
            reportFileName  = ['cameraAccuracyTest-' datestr(now,'yyyy-mm-dd-HH-MM')];
            fullReportFile = fullfile(guiHandles.reportsDir,reportFileName);

            save(fullReportFile,'capturedToolPosition',...
                'capturedToolQuat','maxError','rmsError',...
                'centroid','distance_from_centroid',...
                'A','b','toolCorrection');

            % present the results
            presentAccuracyResults(rmsError,maxError,conditionNumber);
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to present Results
%--------------------------------------------------------------------------
    function presentAccuracyResults(rmsError,maxError,condNumber)
        try
        % Check each parameter
        resString={};
        [results(1),resColor,resString] = checkResults(...
            rmsError,RMS_ERROR_LIMIT,WARNING_RATIO,'RMS Error',resString);

        % display the results and color code
        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'Units','Normalized',...
            'FontUnits','normalized',...
            'FontSize',0.6,...
            'BackgroundColor',resColor,...
            'String',sprintf('RMS Error = %3.4f mm',rmsError*1000),...
            'Position',[0.1 0.8 0.8 0.1]);

        [results(2),resColor,resString] = checkResults(...
            maxError,MAX_ERROR_LIMIT,WARNING_RATIO,'Max Error',resString);

        % display the results and color code
        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'Units','Normalized',...
            'FontUnits','normalized',...
            'FontSize',0.6,...
            'BackgroundColor',resColor,...
            'String',sprintf('Max Error = %3.4f mm',maxError*1000),...
            'Position',[0.1 0.6 0.8 0.1]);

        [results(3),resColor,resString] = checkResults(...
            condNumber,MAX_CONDITION_NUMBER,WARNING_RATIO,...
            'Condition Number',resString);

        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'Units','Normalized',...
            'FontUnits','normalized',...
            'FontSize',0.6,...
            'BackgroundColor',resColor,...
            'String',sprintf('Condition Number = %3.4f',condNumber),...
            'Position',[0.1 0.4 0.8 0.1]);

        % present the results
        if ~any(results<1)
            presentMakoResults(guiHandles,'SUCCESS');
            if isa(hgs,'hgs_robot')
		log_results(hgs,'Camera Accuracy Check','PASS',...
                        	'Camera Accuracy Check Pass',...
				'cameraRmsError',results(1),...
				'cameraMaxError',results(2),...
				'conditionNumber',results(3));
                log_message(hgs,...
                    ['Camera Accuracy check successful [rms_err (mm), ',...
                    'max_err (mm), condition_num ] = ',num2str(results,'%3.3f ')]);
            end
        elseif ~any(results<0)
            presentMakoResults(guiHandles,'WARNING',resString);
            if isa(hgs,'hgs_robot')
		log_results(hgs,'Camera Accuracy Check','WARNING',...
                        	'Camera Accuracy Check Warning',...
				'cameraRmsError',results(1),...
				'cameraMaxError',results(2),...
				'conditionNumber',results(3));
            end
        else
            presentMakoResults(guiHandles,'FAILURE',resString);
            if isa(hgs,'hgs_robot')
		log_results(hgs,'Camera Accuracy Check','FAIL',...
                        	'Camera Accuracy Check failed',...
				'cameraRmsError',results(1),...
				'cameraMaxError',results(2),...
				'conditionNumber',results(3));
            end
        end
        catch
            return;
        end
            
    end

%--------------------------------------------------------------------------
% internal function to check results
%--------------------------------------------------------------------------
    function [checkStatus,resultColor,resString] = checkResults(...
            measuredValue,limit,warning_ratio,paramName,resString)
        try

            if measuredValue<limit*warning_ratio
                % All is good
                checkStatus=1;
                resultColor = 'green';
            elseif measuredValue<limit
                % This is in warning range
                checkStatus=0;
                resultColor = 'yellow';
                % Append to results string
                resString{end+1} = sprintf('%s : %3.2f (lim %3.2f mm)',...
                    paramName,measuredValue*1000,limit*1000);
            else
                % this is in error state
                resultColor = 'red';
                checkStatus=-1;
                resString{end+1} = sprintf('%s : %3.2f (lim %3.2f mm)',...
                    paramName,measuredValue*1000,limit*1000);
            end
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to close the GUI
%--------------------------------------------------------------------------
    function closeFcn(varargin)
        try
            % stop the timer
            stop(plotTimer);
            delete(plotTimer);
            terminate_loops = true;
        catch
        end
        
        try
        % close the connection if it was established by this script
        if defaultRobotConnection
            if isa(hgs_or_ndi,'hgs_robot')
            	log_message(hgs,'Camera Accuracy check script closed');
            end
            close(hgs_or_ndi);
        end
        catch
        end        
        closereq
    end

%--------------------------------------------------------------------------
% internal function to close the GUI
%--------------------------------------------------------------------------
    function out = angleChanged()
        
        %For the first captured data, we assume angle has changed
        if numDataCaptured<=1,
            out = true;
            return
        end
            
        R1 = q2rot( capturedToolQuat(max(1,numDataCaptured-1),:) );
        R2 = q2rot( toolInfo.quaternion );

        %if the angle between two coordinate frame axes is above 
        %threshold the angle change is acceptable
        ang = acos( dot( R1(:,1), R2(:,1) ) );
        if abs(ang) > ANGLE_CHANGE_THRESHOLD
            out = true;
            return
        end
        ang = acos( dot( R1(:,2), R2(:,2) ));
        if abs(ang) > ANGLE_CHANGE_THRESHOLD
            out = true;
            return
        end  
        ang = acos( dot( R1(:,3), R2(:,3) ) );
        if abs(ang) > ANGLE_CHANGE_THRESHOLD
            out = true;
        else
            out = false;
        end 
    end
end

%--------------------------------------------------------------------------
% internal function to convert quaternions to rot matrix.  This function is
% based on Peter Corke's Robot Toolbox
%--------------------------------------------------------------------------
%Q2TR	Convert unit-quaternion to homogeneous transform
%
%	T = q2tr(Q)
%
%	Return the rotational homogeneous transform corresponding to the unit
%	quaternion Q.
%
%	See also: TR2Q, Robot package

%	Copyright (C) 1993 Peter Corke
    function r = q2rot(q)

        q = double(q);
        s = q(1);
        x = q(2);
        y = q(3);
        z = q(4);

        r = [	1-2*(y^2+z^2)	2*(x*y-s*z)	2*(x*z+s*y)
            2*(x*y+s*z)	1-2*(x^2+z^2)	2*(y*z-s*x)
            2*(x*z-s*y)	2*(y*z+s*x)	1-2*(x^2+y^2)	];
    end

% --------- END OF FILE ----------
