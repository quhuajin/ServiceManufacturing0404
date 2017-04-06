function OpticalComplianceTest(hgs)

% OpticalComplianceTest Compliance test performed using the NDI camera
%
% Syntax:
%   OpticalComplianceTest(hgs)
%       this script performs the optical compliance test on the hgs_Robot
%       using the NDI camera
%
% Notes:
%   The script prompts the user to apply forces in particular directions
%   and hold.  The observed position change at that force is measured using
%   the robot and the camera.  The difference of this measurement is taken
%   as the tip compliance of the robot (assuming the camera is perfect)
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
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% Check if the specified argument is a hgs_robot
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% Generate the gui
guiHandles = generateMakoGui('OpticalCompliance',[],hgs,true);
log_message(hgs,'Optical Compliance Test Started');

% Set the constants for the test
TEST_TOOL_SROM = fullfile('sroms','110740.rom');

NUM_OF_SAMPLES_PER_READING = 10;
MAX_SAMPLE_DEV_CAMERA = 0.2*0.001; % meters
MAX_SAMPLE_DEV_ROBOT = 0.2*0.001; % meters
MAX_SAMPLE_DEV_FORCE = 3; % N
COMPLIANCE_LIMIT = .035/1000; % m/N
COMPLIANCE_WARN_RATIO = .75; % percent of comliance limit

CUBE_SIDE_LENGTH = 0.1; % meters
DESIRED_FORCE = 30; % N


EE_IMAGE_FILE = fullfile('images','SocketArrayInCalibEE.png');

% gather required data from arm
endEffectorTransform = eye(4);
endEffectorTransform(1:3,4) = hgs.CALIB_BALL_A';

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@initializeCamera);

% initialize variables
terminate_loops = false;
plotTimer=[];
ndi = ndi_camera(hgs);
tinybeep = wavread(fullfile('sounds','tinybeep.wav'));
defaultColor = [0.8 0.8 0.8];

% clean up the robot
reset(hgs);

% load the image file data
ee_image_file_data = imread(EE_IMAGE_FILE);

% Setup to show the serial numbers
commonProperties = struct(...
    'Style','text',...
    'HorizontalAlignment', 'left', ...
    'Units','Normalized',...
    'BackgroundColor',get( guiHandles.uiPanel,'BackgroundColor'),...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'SelectionHighlight','off'...
    );

uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Position',[0.1, 0.65 0.8 0.05],...
    'String','Calibration EE Serial Number');
uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'BackgroundColor','white',...
    'Position',[0.1, 0.55 0.8 0.1],...
    'String',hgs.CALEE_SERIAL_NUMBER);

updateMainButtonInfo(guiHandles,'Confirm SN and click to start Compliance Test');

%--------------------------------------------------------------------------
% internal function to initialize the camera
%--------------------------------------------------------------------------
    function initializeCamera(varargin)
        delete(get(guiHandles.uiPanel,'children'));
        updateMainButtonInfo(guiHandles,'text','Initializing Camera...');

        % Generate a big text box with instructions on where to place the
        % tracker

        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'Units','Normalized',...
            'FontWeight','bold',...
            'FontUnits','normalized',...
            'FontSize',0.2,...
            'String',{'Place Tracker on CALIB BALL A',...
            'and',...
            'Arm in desired surgical pose'},...
            'Position',[0.1 0.78 0.8 0.2]);

        % setup an axis to show the figure
        axisHandle = axes(...
            'parent', guiHandles.uiPanel,...
            'Position',[0.1 0.05 0.8 0.7],...
            'XGrid','off',...
            'YGrid','off',...
            'box','off',...
            'visible','off',...
            'NextPlot', 'replace');
        axis(axisHandle,'equal');
        image(ee_image_file_data,'parent',axisHandle);
        axis(axisHandle, 'off')
        axis(axisHandle,'image')
        drawnow;

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
                        sprintf('Camera Tool Init Failed, Exit and Check again: %s',lasterr));
                    log_results(hgs,guiHandles.scriptName,'FAIL', ...
                        sprintf('Optical Compliance test failed, init_tool failed: (%s)', lasterr));
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
        toolInfo = tx(ndi);


        % Get stuck till the tracker becomes visible
        try
            while ~strcmpi(toolInfo.status,'VISIBLE') && ~terminate_loops
                updateMainButtonInfo(guiHandles,'text',...
                    'Make Sure Tracker is visible');
                toolInfo = tx(ndi);
            end
        catch
        end

        % if the loop termination was requested quit
        if terminate_loops
            return
        end

        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Click to initialize Haptics',@opticalComplianceCheck);

    end

%--------------------------------------------------------------------------
% internal function to perfom opticalComplianceCheck
%--------------------------------------------------------------------------
    function opticalComplianceCheck(varargin)
        updateMainButtonInfo(guiHandles,'text','Initializing Haptics');
        % Clear the GUI
        delete(get(guiHandles.uiPanel,'children'));

        % Generate a forceIndicator
        progaxes = axes(...
            'Parent',guiHandles.uiPanel,...
            'Color','white',...
            'Position',[0.9 0.1 0.05 0.8],...
            'XLim',[0 1],...
            'YLim',[0 1],...
            'Box','on',...
            'ytick',[],...
            'xtick',[] );
        forceIndicator = patch(...
            'Parent',progaxes,...
            'XData',[0 1 1 0],...
            'YData',[0 0 0 0],...
            'FaceColor','green'...
            );
        
        % mark the good force region  this will be between 50-75%
        patch(...
            'Parent',progaxes,...
            'XData',[0 1 1 0],...
            'YData',[.7 .7 .7 .7],...
            'FaceColor','black'...
            );
        patch(...
            'Parent',progaxes,...
            'XData',[0 1 1 0],...
            'YData',[.8 .8 .8 .8],...
            'FaceColor','black'...
            );        
        
        dispAxes = axes(...
            'Parent',guiHandles.uiPanel,...
            'Color','white',...
            'Position',[0.05 0.05 0.75 0.9],...
            'Visible','off');
        
        
        % Generate the graphics for a cube

        % cube size is not important so just hardcode a cube
        sideVerts1 = [
            -1 -1 -1 -1;
            1  1  1  1;
            ]*CUBE_SIDE_LENGTH;
        sideVerts2 = [
            -1  1  1  -1;
            -1 -1  1   1;
            ]*CUBE_SIDE_LENGTH;
        sideVerts3 = [
            -1 -1  1   1;
            -1  1  1  -1;
            ]*CUBE_SIDE_LENGTH;

        for i=1:6
            patchHandle(i) = patch(0,0,defaultColor,...
                'parent',dispAxes); %#ok<AGROW>
            set(patchHandle(i),'FaceAlpha',0.2);
        end

        % Now construct the cube in the order X faces (+/-) Y and then Z
        set(patchHandle(1),...
            'XData',sideVerts1(1,:),...
            'YData',sideVerts2(1,:),...
            'ZData',sideVerts3(1,:));
        set(patchHandle(2),...
            'XData',sideVerts1(2,:),...
            'YData',sideVerts2(2,:),...
            'ZData',sideVerts3(2,:));

        % Y faces
        set(patchHandle(3),...
            'XData',sideVerts2(1,:),...
            'YData',sideVerts1(1,:),...
            'ZData',sideVerts3(1,:));
        set(patchHandle(4),...
            'XData',sideVerts2(2,:),...
            'YData',sideVerts1(2,:),...
            'ZData',sideVerts3(2,:));

        % Z faces
        set(patchHandle(5),...
            'XData',sideVerts3(1,:),...
            'YData',sideVerts2(1,:),...
            'ZData',sideVerts1(1,:));
        set(patchHandle(6),...
            'XData',sideVerts3(2,:),...
            'YData',sideVerts2(2,:),...
            'ZData',sideVerts1(2,:));
        
        % create a tip marker position
        hold(dispAxes,'on');
        eeDisplay = plot3(0,0,0,'o',...
            'parent',dispAxes,...
            'MarkerSize',5,...
            'LineWidth',5,...
            'EraseMode','xor');
        
        axis(dispAxes,'equal');
              
        % update view for righty or lefty
        if hgs.joint_angles(3)>0
            view(dispAxes,[180+37.5,30]);
        else
            view(dispAxes,-37.5,30);
        end

        % store the cube center
        mode(hgs,'hold_position');
        [toolCubeCenter,robCubeCenter,dummyForce] ...
            = collectDataPoint(i,forceIndicator,...
            patchHandle,eeDisplay,[0 0 0],true); %#ok<NASGU>
        createHapticCube;   
        
        for i=1:6
            % get the data and make sure this is not terminated
            try
                % Try to take the reading
                [toolPositionList(i,1:3),robPositionList(i,1:3),robForceList(i,1)] ...
                    = collectDataPoint(i,forceIndicator,...
                        patchHandle,eeDisplay,robCubeCenter,false); %#ok<AGROW>
            catch
                if terminate_loops
                    return;
                end
            end
        end

        if terminate_loops
            return;
        end

        % make sure the user is not pushing into the wall
        currentForces = hgs.haptic_interact.forces(1:3);
        while ~terminate_loops && any(abs(currentForces)>3)
            currentForces = hgs.haptic_interact.forces(1:3);
            updateMainButtonInfo(guiHandles,'text','Back Away from the wall');
            pause(0.05);
        end

        if terminate_loops
            return;
        end

        % free the robot as the test is done
        mode(hgs,'zerogravity','ia_hold_enable',0);
        updateMainButtonInfo(guiHandles,'text','Test Complete');

         % compute the errors
         for i=1:6
            toolMotion(i) = norm(toolPositionList(i,1:3)-toolCubeCenter); %#ok<AGROW>
            robMotion(i) = norm(robPositionList(i,1:3)-robCubeCenter); %#ok<AGROW>
            positionError(i,1) = abs(toolMotion(i)-robMotion(i)); %#ok<AGROW>
         end
         
         measuredCompliance = positionError./robForceList;
         
         % Save results
         reportFileName  = ['OpticalComplianceTest-' datestr(now,'yyyy-mm-dd-HH-MM')];
         fullReportFile = fullfile(guiHandles.reportsDir,reportFileName);
 
         save(fullReportFile,...
             'toolMotion','robMotion',...
             'toolPositionList','robPositionList',...
             'toolCubeCenter','robCubeCenter',...
             'measuredCompliance');
         
         % Present the accuracy results
         presentComplianceResults(measuredCompliance);

    end

%--------------------------------------------------------------------------
% Internal function to create the cube
%--------------------------------------------------------------------------
    function createHapticCube
                % generate a 2DPoly Cube (10 cm) - copied from
        % development/test2dpoly
        %set vertices and cap for extruded 2D poly to
        % generate a cube
        vertices = [ -1 1 1 -1 -1 -1 -1 1 1 ...
            -1 ] * CUBE_SIDE_LENGTH/2;
        caps = [-1 1] * CUBE_SIDE_LENGTH/2;
        numVerts = length(vertices)/2;
        objName = 'extruded_2Dpoly___CompTest';
        objwrtref = reshape(hgs.flange_tx,4,4)';
        objwrtref = objwrtref * endEffectorTransform;
        objwrtref(1:3,1:3) = eye(3);
        objwrtref = objwrtref';
        haptic_obj = hgs_haptic(hgs,objName,...
                  'verts',vertices,...
                  'numVerts',numVerts,...
                  'stiffness',15000,...
                  'damping',10.0,...
                  'haptic_wrt_implant',eye(4),...
                  'obj_wrt_ref',objwrtref(:),...
                  'forceMax',80,...
                  'torqueMax',8,...
                  'constrPlaneGain',150,...
                  'start_end_cap', caps,...
                  'constrPlaneNormal',[0.0 0.0 1.0],...
                  'planarConstrEnable',0,...
                  'safetyConstrEnable',0,...
                  'safetyPlaneNormal',[0.0 0.0 1.0],...
                  'safetyConstrDir',1,...
                  'planarConstrDir',0 ...
                  ); 
        jtobjName = ['JtDamp___',num2str(rand())];
        comm(hgs,'create_haptic_object',jtobjName,...
            'Kd',[0.2 0 0 0.0 0.05 0.2]...
            );
        mode(hgs,'haptic_interact',...
             'vo_and_frame_list',{haptic_obj.name,jtobjName},...
             'end_effector_tx',endEffectorTransform...
             );
    end

%--------------------------------------------------------------------------
% internal function to collect robot and camera position
%--------------------------------------------------------------------------
    function [cameraPos,robotPos,measuredForce] = collectDataPoint(idx,forceIndicator,...
            patchHandle,eeDisplay,cubeCenter,skipForceTests)
        
        % Show user which face to hit
        flashToggle = true;
        updateMainButtonInfo(guiHandles,'text',...
            'Please Push against the haptic wall shown');
        processedForces = zeros(6,1);
        
        % take 20 samples and compute the mean
        robPosList = zeros(NUM_OF_SAMPLES_PER_READING,3);
        camPosList = zeros(NUM_OF_SAMPLES_PER_READING,3);

        numOfPoints = 1;
        
        while ~terminate_loops
            % Terminates loop if there is a CRISIS error
            if ((hgs.ce_error_code(1)~=0)||(hgs.ce_error_code(2)~=0)||(hgs.ce_error_code(3)~=0))
                terminate_loops = true;
            end
            
            if ~skipForceTests
                hapticForces = -hgs.haptic_interact.forces(1:3);
                currentForce = norm(hapticForces);
            else
                currentForce = 0;
            end
            currentRobPos = getTipPosition;
            relativeTipPosition = currentRobPos-cubeCenter;

            % update the tip location
            set(eeDisplay,...
                'XData',relativeTipPosition(1),...
                'YData',relativeTipPosition(2),...
                'ZData',relativeTipPosition(3))

            % Check the direction of the force
            % if there is a significant component other than in direction
            % desired complain
            % rearrange forces to include negative values etc in
            % directions that would match the patch index
            if ~skipForceTests
                for j=1:3
                    if hapticForces(j)<0
                        processedForces(2*j) = 0;
                        processedForces(2*j-1) = abs(hapticForces(j));
                    else
                        processedForces(2*j-1) = 0;
                        processedForces(2*j) = abs(hapticForces(j));
                    end
                end
                [maxForce,forceDir] = max(processedForces);

                % scale data because data as markers are at 70-80 %
                set(forceIndicator,'YData',...
                    [0 0 processedForces(idx)/DESIRED_FORCE*0.75 ...
                    processedForces(idx)/DESIRED_FORCE*0.75]);
            end
            
            % get data from camera
            camReply = bx(ndi);
            if ~skipForceTests && (forceDir~=idx || maxForce<1)
                mesgText = 'Please Push against the haptic wall shown';
                forceIndicatorColor = 'red';
                % flash the desired direction
                flashToggle = flashToggle+1;
                if flashToggle>3
                    patchColor = defaultColor/2;
                    if flashToggle>6
                        flashToggle = 0;
                    end
                else
                    patchColor = defaultColor;
                end
            elseif strcmpi(camReply.status,'MISSING')
                mesgText = 'TRACKER NOT VISIBLE';
                forceIndicatorColor = 'red';
                patchColor = 'blue';   
            elseif ~skipForceTests && (processedForces(idx)-DESIRED_FORCE)/DESIRED_FORCE*0.75>.05
                mesgText = 'Too Much Force Applied';
                forceIndicatorColor = 'red';
                patchColor = 'blue';
            elseif ~skipForceTests && (processedForces(idx)-DESIRED_FORCE)/DESIRED_FORCE*0.75<-.05
                mesgText = 'Apply More Force';
                forceIndicatorColor = 'red';
                patchColor = 'blue';
            else
                mesgText = 'Collecting Data';
                forceIndicatorColor = 'green';
                patchColor = 'blue';
                currentCamPos = camReply.position;

                if numOfPoints <= NUM_OF_SAMPLES_PER_READING
                    robPosList(numOfPoints,1:3) = currentRobPos;
                    camPosList(numOfPoints,1:3) = currentCamPos;
                    forceList(numOfPoints,1) = currentForce;
                    numOfPoints = numOfPoints+1;
                else
                    mesgText = 'Waiting for data to settle';
                    % keep a ring buffer
                    robPosList = [robPosList(2:end,:);currentRobPos];
                    camPosList = [camPosList(2:end,:);currentCamPos];
                    forceList =  [forceList(2:end,1);currentForce];

                    % check if the camera and robot are stable if so
                    % average and return immediatelys
                    if all(std(camPosList)<MAX_SAMPLE_DEV_CAMERA) ...
                            && all(std(robPosList)< MAX_SAMPLE_DEV_ROBOT) ...
                            && all(std(forceList)< MAX_SAMPLE_DEV_FORCE)
                        cameraPos = mean(camPosList);
                        robotPos = mean(robPosList);
                        measuredForce = mean(forceList);
                        sound(tinybeep);
                        return;
                    end
                end
            end
            
            % update the display
            if ~skipForceTests
                set(patchHandle(idx),'FaceColor',patchColor);
                set(forceIndicator,'FaceColor',forceIndicatorColor);
            end
            
            pause(0.01);
            updateMainButtonInfo(guiHandles,mesgText);

        end
        % if i get here there was a request to terminate the function
        % return with error
        if hgs.ce_error_code(1)~=0
            presentMakoResults(guiHandles,'FAILURE', hgs.ce_error_msg(1));
            log_results(hgs, guiHandles.scriptName,'FAIL', hgs.ce_error_msg(1));
        elseif hgs.ce_error_code(2)~=0
            presentMakoResults(guiHandles,'FAILURE', hgs.ce_error_msg(2));
            log_results(hgs, guiHandles.scriptName,'FAIL', hgs.ce_error_msg(2));
        elseif hgs.ce_error_code(3)~=0
            presentMakoResults(guiHandles,'FAILURE', hgs.ce_error_msg(3));
            log_results(hgs, guiHandles.scriptName,'FAIL', hgs.ce_error_msg(3));
        end

    end

%--------------------------------------------------------------------------
% internal function to present Results
%--------------------------------------------------------------------------
    function presentComplianceResults(measuredCompliance)

        % clean up the uipanel
        delete(get(guiHandles.uiPanel,'children'));

        % Check each parameter
        resString = {};
        warningFound = false;
        errorFound = false;
        
        for i=1:6
            if measuredCompliance(i)>COMPLIANCE_LIMIT
                errorFound = true;
                resColor = 'red';
                resString{end+1} = sprintf('%s = %2.3f mm/N (lim %2.3f)',...
                    convertIndexToDirString(i),measuredCompliance(i)*1000,...
                    COMPLIANCE_LIMIT*1000); %#ok<AGROW>
            elseif measuredCompliance(i)>COMPLIANCE_LIMIT*COMPLIANCE_WARN_RATIO
                warningFound = true;
                resString{end+1} = sprintf('%s = %2.3f mm/N (lim %2.3f)',...
                    convertIndexToDirString(i),measuredCompliance(i)*1000,...
                    COMPLIANCE_LIMIT*1000); %#ok<AGROW>
                resColor = 'yellow';
            else
                resColor = 'green';
            end

            % display the results and color code
            uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'Units','Normalized',...
                'FontUnits','normalized',...
                'HorizontalAlignment','left',...
                'FontSize',0.8,...
                'BackgroundColor',resColor,...
                'String',sprintf('Compliance (%s) = %3.4f mm/N',...
                    convertIndexToDirString(i),...
                    measuredCompliance(i)*1000),...
                'Position',[0.1 0.8-0.1*i 0.8 0.08]);

        end
        
        results_log.measuredCompliance = measuredCompliance;
        results_log.complianceLimit = COMPLIANCE_LIMIT;
        
        % present the results
        if errorFound
            presentMakoResults(guiHandles,'FAILURE',resString);
            log_results(hgs,guiHandles.scriptName,'FAIL','Test failed',results_log);
        elseif warningFound
            presentMakoResults(guiHandles,'WARNING',resString)
            log_results(hgs,guiHandles.scriptName,'WARNING','Test passed with warning',results_log);
        else
            presentMakoResults(guiHandles,'SUCCESS');
            log_results(hgs,guiHandles.scriptName,'PASS','Test passed',results_log);
        end
    end

%--------------------------------------------------------------------------
% internal function to convert index to direction
%--------------------------------------------------------------------------
    function dirString = convertIndexToDirString(idx)
        switch(idx)
            case 1
                dirString = 'Positive X';
            case 2
                dirString = 'Negative X';
            case 3
                dirString = 'Positive Y';
            case 4
                dirString = 'Negative Y';
            case 5
                dirString = 'Positive Z';
            case 6
                dirString = 'Negative Z';
        end
    end

%--------------------------------------------------------------------------
% internal function to get tip position from robot
%--------------------------------------------------------------------------
    function tipPosition = getTipPosition
        tipTransform = reshape(hgs.flange_tx,4,4)' * endEffectorTransform;
        tipPosition = tipTransform(1:3,4)';
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
            % cleanup
            reset(hgs);
        catch
        end
        log_message(hgs,'Optical Compliance Check Closed');
        closereq
    end

end

% --------- END OF FILE ----------
