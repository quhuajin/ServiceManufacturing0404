function phase_hgs(hgs)
% PHASE_HGS Gui to help perform the phasing procedure on the Hgs Robot.
%
% Syntax:
%   PHASE_HGS(hgs)
%       Starts the phasing GUI for performing phasing on the hgs robot defined by
%       the argument hgs.
%
% Notes:
%   Phasing is only required when the relative position between motor shaft
%   and encoder is unknown or changed. Unlike homing, phasing is not necessary
%   for every power up.
%   Added check for joint angles within recommended range for phasing
%   (stages 1 & 2)
%
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home_hgs,
%   hgs_robot/phase_hgs_dev
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%



try
    
    % If no arguments are specified create a connection to the default
    % hgs_robot
    if nargin<1
        hgs = connectRobotGui;
        if isempty(hgs)
            return;
        end
    end
    
    % Checks for arguments if any
    if (~isa(hgs,'hgs_robot'))
        error('Invalid argument: phase_hgs argument must be an hgs_robot object');
    end
    
    log_message(hgs,'Phasing Procedure Started');
    
    % define Robot range of motion based on angle limit values
    % from the configuration file
    RANGE_OF_MOTION = hgs.JOINT_ANGLE_MAX - hgs.JOINT_ANGLE_MIN;
    % use 90% of range of motion
    RANGE_OF_MOTION = RANGE_OF_MOTION * 0.9;
    
    % Setup Script Identifiers for generic GUI with extra panel
    scriptName = 'Phasing';
    guiHandles = generateMakoGui(scriptName,[],hgs,1);
    
    %figure/GUI fullscreen figures, use simple java to maximize the window
    set(get(guiHandles.figure,'JavaFrame'),'Maximized',true);
    
    % Setup the main function
    set(guiHandles.mainButtonInfo,'CallBack', ...
        @checkHoming)
    
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@phase_hgs_close);
    
    %set degree of freemdom parameters
    meDof = hgs.ME_DOF;
    jeDof = hgs.JE_DOF;
    
    %initialize the phasing error to false
    isPhasingCanceled=false;
    
    phaseProg1 = 1;
    phaseProg2 = 1;
    
    % establish min and max angles allowed for the phasing
    % calibration rangles
    calmin = hgs.JOINT_ANGLE_MIN*180/pi();
    calmax = hgs.JOINT_ANGLE_MAX*180/pi();
    
    % actual ranges may be slightly larger so adjust the ranges
    ran = 1.1*abs(calmin-calmax);
    absmin = calmax-ran;
    absmax = calmin+ran;
    
    % range in which we are confident joints are NOT on bump stops
    tolmin = absmin + 0.3*ran;
    tolmax = absmin + 0.7*ran;
    
    % range for J2 to be closed during step 1
    minCloseJ2 = absmin(2) + 0.76*ran(2);
    maxCloseJ2 = absmin(2) + 0.9*ran(2);
    
    % range for J2 to be closed during step 1
    minCloseJ3 = absmin(3) + 0.45*ran(3);
    maxCloseJ3 = absmin(3) + 0.65*ran(3);
    
    % range for J4 to be closed during step 1
    minCloseJ4 = absmin(4) + 0.8*ran(4);
    maxCloseJ4 = absmax(4);
    
    % for 1st phasing restrict J4 to be nearly closed - restrict J1 to be off bump
    % stop, J2 to be lifted, J3 to be near the middle of its range
    allowed_min_first = [tolmin(1) minCloseJ2 minCloseJ3 minCloseJ4 absmin(5) absmin(6)];
    allowed_max_first = [tolmax(1) maxCloseJ2 maxCloseJ3 maxCloseJ4 absmax(5) absmax(6)];
    
    % range for J2 to be open during step 2
    minOpenJ2 = absmin(2);
    maxOpenJ2 = absmin(2) + 0.3*ran(2);
    
    % range for J4 to be open during step 2
    minOpenJ4 = absmin(4) + 0.6*ran(4);
    maxOpenJ4 = absmin(4) + 0.75*ran(4);
    
    % for 2nd phasing require J2 to be lowered, J4 to be opened, J3 to be in the middle of the range,
    % J5 and J6 to be off the bump stops
    allowed_min_second = [tolmin(1) minOpenJ2 minCloseJ3 minOpenJ4 tolmin(5) tolmin(6)];
    allowed_max_second = [tolmax(1) maxOpenJ2 maxCloseJ3 maxOpenJ4 tolmax(5) tolmax(6)];
    
    % Setup boundaries for phasing  boxes
    xMin = 0.05;
    xRange = 0.9;
    yMin = 0.25;
    yRange = 0.15;
    spacing = 0.02;
    
    dof = max([meDof,jeDof]);
    
    % set extra panel to be visible
    set(guiHandles.extraPanel, ...
        'Visible','on');
    
    %define the common properties for all uicontrol
    commonBoxProperties = struct(...
        'Units','Normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'SelectionHighlight','off',...
        'Enable','Inactive');
    
    % Add axis for EE image
    imageHndl = axes('parent', guiHandles.extraPanel, ...
        'XGrid','off','YGrid','off','box','off','visible','off');
    
    poseImage1 = imread(fullfile('images_phase_hgs', ...
        'phasing_pose_1-3.jpg' ));
    
    poseImage2 = imread(fullfile('images_phase_hgs', ...
        'phasing_pose_4-6.jpg' ));
    
    set(imageHndl, 'NextPlot', 'replace');
    image(poseImage1,'parent', imageHndl);
    axis (imageHndl, 'off')
    axis (imageHndl, 'image')
    
    %add pushbuttons to show phasing status
    for indx=1:meDof
        boxPosition = [xMin+(xRange+spacing)*(indx-1)/dof,...
            yMin+spacing,...
            xRange/dof-spacing,...
            yRange];
        meBox(indx) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','pushbutton',...
            'Position',boxPosition,...
            'FontSize',0.3,...
            'String',sprintf('M%d',indx)); %#ok<AGROW>
        
        % generate a region to plot
        dispAxis1(indx) = axes(...
            'Parent',guiHandles.uiPanel,...
            'Color','white',...
            'Position',boxPosition+[0 -.15 0 -.05],...
            'XLim',[0 1],...
            'YLim',[0 1],...
            'Box','on',...
            'ytick',[],...
            'xtick',[] );
        
        % Generate the required patches for joint in range status
        progressBar(indx) = patch(...
            'Parent',dispAxis1(indx),...
            'XData',[0 0 0 0],...
            'YData',[0 0 1 1],...
            'FaceColor','green'...
            );     %#ok<AGROW>
        
        % generate lines that show the idea position of each joint
        currentPositionLine(indx) = line([0 0],[0 0],...
            'linewidth',3,...
            'parent',dispAxis1(indx));
        
    end
    
    %add the parameters for phasing
    yMin=0.8;
    
    for indx=1:meDof
        boxPosition = [xMin+(xRange+spacing)*(indx-1)/dof,...
            yMin+spacing,...
            xRange/dof-spacing,...
            0.1];
        tbPhasingParams(indx) = uicontrol(guiHandles.uiPanel,...
            'Style','edit',...
            commonBoxProperties,...
            'Enable','on',...
            'String','5,2,0',...
            'FontSize',0.35,...
            'Position',boxPosition); %#ok<AGROW>
    end
    
    %don't allow editing phasing settings.
    set(tbPhasingParams, 'Enable', 'off');
    
    if(meDof==6)
        set(tbPhasingParams(1),'String','4,2,0');
        set(tbPhasingParams(2),'String','12,2,4');
        set(tbPhasingParams(3),'String','10,0.5,1');
        set(tbPhasingParams(4),'String','8,2,1');
        set(tbPhasingParams(6),'String','8,2,1');
    end
    
    %add the text for the phasing parameters
    yMin=0.92;
    boxPosition = [xMin,...
        yMin,...
        xRange,...
        0.08];
    
    uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        commonBoxProperties,...
        'HorizontalAlignment','left',...
        'FontSize',0.4,...
        'String','[Maximum current, Duration, Initial current]',...
        'Position',boxPosition);
    tmpStr={'Move Robot to position shown in Picture.', ...
        'There should be about 10 degrees distance',...
        'from Elbow (J2) to joint stop.', ...
        'If needed, press E-Stop then push', ...
        'Brake Release button to move the robot.'};
    
    %add the text for Instruction
    tbInstruction = uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        commonBoxProperties,...
        'HorizontalAlignment','left',...
        'FontSize',0.15,...
        'String',tmpStr,...
        'Position',[0.1,0.5,0.9,0.3]);
    
    %setup mainbutton and display message
    tmpStr = sprintf('Click here to start phasing Motors 1, 2, and 3');
    updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
    set(guiHandles.mainButtonInfo,'FontSize',0.3);
    
    
    %set local motor torque limits and torque constant variables
    torque_limit = hgs.MOTOR_TQ_LIMIT;
    torque_constant = hgs.MOTOR_TQ_PER_AMP;
    
    phasingStartMotor = 1;
    phasingEndMotor = min(3, meDof);
    max_current=0;
    duration=0;
    init_current=0;
catch
    %phase error handling
    phase_hgs_error();
end



%--------------------------------------------------------------------------
% internal function: Manin function for phasing
%--------------------------------------------------------------------------
    function phasingProcedure(varargin)
        
        try
            
            % check if any joint angles are out of range for the first
            % phasing procedure
            outRange = checkAngles(hgs,allowed_min_first,allowed_max_first);
            
            % if some are out of range, display a message with the joints
            % of error to the mainbutton
            if(~isempty(outRange))
                strRan = 'Joints ';
                for i = 1:length(outRange)
                    strRan = horzcat(strRan,num2str(outRange(i)),' ');
                end
                
                proceed=questdlg(...
                    [horzcat(strRan,'close to bumpstop, proceed?')],'Yes','No');
                switch(proceed)
                    case 'No'
                        %prompt readjust
                        
                        strRan = horzcat(strRan,'out of range, adjust as shown');
                        tmpStr = sprintf(strRan);
                        
                        updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
                        set(guiHandles.mainButtonInfo,'FontSize',0.3);
                        set(guiHandles.mainButtonInfo,'BackgroundColor','yellow');
                        return; % recheck limits
                        
                    case 'Yes'
                        %continue/phase
                        
                    case 'Cancel'
                        %continue/test canceled
                        phase_hgs_close;
                end
                
                
            end
            
            %guide user to enable arm
            robotFrontPanelEnable(hgs,guiHandles);
            
            %start the phasing loop
            for j = phasingStartMotor: phasingEndMotor
                
                if  (setAndVerifyPhasingParam(j))
                    
                    % try multiple times in case phasing error safety
                    % check was triggered. (restarting the mode would
                    % reset the error and the error shouldn't reappear
                    % because in phasing mode no phasing error will be
                    % issued).
                    for trialNum=1:3
                        modeResult = mode(hgs,'phasing',...
                            'motor_current_max', max_current,...
                            'phasing_duration', duration,...
                            'motor_number', j-1,...
                            'motor_current_initial', init_current);
                        if strcmp(modeResult, 'phasing')
                            %update the main button display
                            tmpStr = sprintf('Phasing Motor %d in progress ...', j);
                            updateMainButtonInfo(guiHandles,'text', tmpStr);
                            break;
                        end
                    end
                    
                    %Wait until phasing is done or canceled
                    while(1)
                        %check if phasing is canceled
                        if(isPhasingCanceled)
                            stop(hgs);
                            return;
                        end
                        hgsMode=mode(hgs);
                        %check if phasing is done
                        if(hgs.phasing.phasing_done(j))
                            break;
                        end
                        
                        %check if the phasing module stopped
                        if(~strcmp(hgsMode,'phasing'))
                            error('Phasing:ModuleError',...
                                'Phasing module error: %s',...
                                cell2mat(hgs.ce_error_msg(1)));
                        end
                        pause(0.1);
                    end
                    %check the error bit and update the respective button color
                    if(hgs.phasing.phasing_error(j)==0)
                        set(meBox(j),'BackgroundColor','white');
                        hgs.PHASING_INFORMATION(j) = ...
                            hgs.phasing_info_auto_phase(j);
                        hgs.PHASE_ANGLE_ERROR(j) = -1.0;
                        %phasing for the specific motor is done, stop the phasing module.
                        stop(hgs);
                    else
                        %if one motor failed, simply stop and return
                        set(meBox(j),'BackgroundColor','red');
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Motor %d phasing error',j));
                        log_message(hgs,['FAILURE ',sprintf('Motor %d phasing error',j)]);
                        stop(hgs);
                        return;
                    end
                else
                    %failed to set phasing parameter. A message box should
                    %have been appeared with appropriate message.
                    closereq;
                    return;
                end
            end
            
            
            %if we reach here then phasing for the requested number of motors
            %was finished without any error. Set the required parameter for the
            %next function call, if any.
            phaseProg1 = 0;
            
            if (phasingEndMotor < meDof)
                phasingStartMotor = phasingEndMotor + 1;
                phasingEndMotor = meDof;
                image(poseImage2,'parent', imageHndl);
                axis (imageHndl, 'off')
                axis (imageHndl, 'image')
                tmpStr = ['Adjust robot Position, then Click here to continue' ...
                    'phasing'];
                updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
                set(guiHandles.mainButtonInfo,'FontSize',0.3);
                tmpStr={...
                    'Press E-stop, then use Brake Release button to', ...
                    'move robot to position shown in Picture.',...
                    'Afterwards, re-enable robot.'  };
                set(tbInstruction, 'String',tmpStr);
                %set(guiHandles.mainButtonInfo,'CallBack',@displayJ4);
                %tmpStr = 'Click to start phasing Motors 4, 5, and 6';
                %updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
                displayJ4;
                return;
            else
                %phasing is complete all hall states are as expected
                %prompt user to perform verification
                set(guiHandles.mainButtonInfo,'CallBack',@phasingVerificationProcedure);
                tmpStr = 'Hold Robot Arm, Click here to start phasing verification';
                updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
                return;
            end
        catch it
            %update error joint button first
            if(~isPhasingCanceled)
                set(meBox(j),'BackgroundColor','red');
            end
            %phase error handling
            phase_hgs_error();
            
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function: Second function for phasing
%--------------------------------------------------------------------------
    function phasingProcedure2(varargin)
        
        try
            
            % check if any joint angles are out of range for the second
            % phasing procedure
            outRange = checkAngles(hgs,allowed_min_second,allowed_max_second);
            
            % if some are out of range, display a message with the joints
            % of error to the mainbutton
            if(~isempty(outRange))
                strRan = 'Joints ';
                for i = 1:length(outRange)
                    strRan = horzcat(strRan,num2str(outRange(i)),' ');
                end
                
                proceed=questdlg(...
                    [horzcat(strRan,'close to bumpstop, proceed?')],'Yes','No');
                switch(proceed)
                    case 'No'
                        %prompt readjust
                        
                        strRan = horzcat(strRan,'out of range, adjust as shown');
                        tmpStr = sprintf(strRan);
                        
                        updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
                        set(guiHandles.mainButtonInfo,'FontSize',0.3);
                        set(guiHandles.mainButtonInfo,'BackgroundColor','yellow');
                        return; % recheck limits
                        
                    case 'Yes'
                        %continue/phase
                        
                    case 'Cancel'
                        %continue/test canceled
                        phase_hgs_close;
                end
                
            end
            
            %guide user to enable arm
            robotFrontPanelEnable(hgs,guiHandles);
            
            %start the phasing loop
            for j = phasingStartMotor: phasingEndMotor
                
                if  (setAndVerifyPhasingParam(j))
                    
                    % try multiple times in case phasing error safety
                    % check was triggered. (restarting the mode would
                    % reset the error and the error shouldn't reappear
                    % because in phasing mode no phasing error will be
                    % issued).
                    for trialNum=1:3
                        modeResult = mode(hgs,'phasing',...
                            'motor_current_max', max_current,...
                            'phasing_duration', duration,...
                            'motor_number', j-1,...
                            'motor_current_initial', init_current);
                        if strcmp(modeResult, 'phasing')
                            %update the main button display
                            tmpStr = sprintf('Phasing Motor %d in progress ...', j);
                            updateMainButtonInfo(guiHandles,'text', tmpStr);
                            break;
                        end
                    end
                    
                    %Wait until phasing is done or canceled
                    while(1)
                        %check if phasing is canceled
                        if(isPhasingCanceled)
                            stop(hgs);
                            return;
                        end
                        hgsMode=mode(hgs);
                        %check if phasing is done
                        if(hgs.phasing.phasing_done(j))
                            break;
                        end
                        
                        %check if the phasing module stopped
                        if(~strcmp(hgsMode,'phasing'))
                            error('Phasing:ModuleError',...
                                'Phasing module error: %s',...
                                cell2mat(hgs.ce_error_msg(1)));
                        end
                        pause(0.1);
                    end
                    %check the error bit and update the respective button color
                    if(hgs.phasing.phasing_error(j)==0)
                        set(meBox(j),'BackgroundColor','white');
                        hgs.PHASING_INFORMATION(j) = ...
                            hgs.phasing_info_auto_phase(j);
                        hgs.PHASE_ANGLE_ERROR(j) = -1.0;
                        %phasing for the specific motor is done, stop the phasing module.
                        stop(hgs);
                    else
                        %if one motor failed, simply stop and return
                        set(meBox(j),'BackgroundColor','red');
                        presentMakoResults(guiHandles,'FAILURE',...
                            sprintf('Motor %d phasing error',j));
                        log_message(hgs,['FAILURE ',sprintf('Motor %d phasing error',j)]);
                        stop(hgs);
                        return;
                    end
                else
                    %failed to set phasing parameter. A message box should
                    %have been appeared with appropriate message.
                    closereq;
                    return;
                end
            end
            
            %phasing is complete all hall states are as expected
            %prompt user to perform verification
            phaseProg2 = 0;
            set(guiHandles.mainButtonInfo,'CallBack',@phasingVerificationProcedure);
            tmpStr = 'Hold Robot Arm, Click here to start phasing verification';
            updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
            return;
            
        catch
            %update error joint button first
            if(~isPhasingCanceled)
                set(meBox(j),'BackgroundColor','red');
            end
            %phase error handling
            phase_hgs_error();
            
            return;
        end
    end
%--------------------------------------------------------------------------
% internal function: For verifying and setting  motor phasing parameters
%--------------------------------------------------------------------------

    function [] = phasingVerificationProcedure(varargin)
        
        isPhasingCanceled = false;
        %add the text for Instruction
        set(guiHandles.extraPanel,'visible','off');
        delete(get(guiHandles.uiPanel,'children'));
        resetMakoGui(guiHandles);
        % generate a region to plot
        dispAxis = axes(...
            'Parent',guiHandles.uiPanel,...
            'Color','white',...
            'Position',[0.2 0.45 0.6 0.3],...
            'XLim',[0 1],...
            'YLim',[0 1],...
            'Box','on',...
            'ytick',[],...
            'xtick',[] );
        
        % Generate the require patches
        progressBar = patch(...
            'Parent',dispAxis,...
            'XData',[0 0 0 0],...
            'YData',[0 0 1 1],...
            'FaceColor','green'...
            );     %#ok<AGROW>
        
        tmpStr = sprintf('Joint %d', 1);
        txtHndl =text('position', [0.45, 0.5 0 ], ...
            'string', tmpStr, ...
            'Parent',  dispAxis,...
            'FontSize', 30);
        
        %set gravity constants to Knee EE
        comm(hgs,'set_gravity_constants','KNEE');
        
        % Put the robot in gravity mode
        mode(hgs,'zerogravity','ia_hold_enable',0);
        
        % Handle one axis at a time
        for i=1:hgs.WAM_DOF %#ok<FXUP>
            updateMainButtonInfo(guiHandles,'text',...
                sprintf(['Please move Joint %d through ' ...
                'Range of Motion'],i));
            minAngle =  hgs.joint_angles(i);
            maxAngle =  hgs.joint_angles(i);
            % Start processing the data
            while(~isPhasingCanceled)
                try
                    if hgs.arm_status ~= 1
                        if ~robotFrontPanelEnable(hgs,guiHandles)
                            return;
                        end
                    end
                catch
                    %something is wrong, break the while loop
                    break;
                end
                % query robot for current angles
                minAngle = min(minAngle, ...
                    hgs.joint_angles(i));
                maxAngle = max(maxAngle, ...
                    hgs.joint_angles(i));
                
                computedROM = maxAngle - minAngle;
                ratio = min(1, computedROM / RANGE_OF_MOTION(i));
                
                set(progressBar,...
                    'XData',[0 ratio ratio 0]);
                tmpStr = sprintf('Joint %d', i);
                set(txtHndl, 'string', tmpStr);
                drawnow;
                % Check if the desired range has been achieved
                if ratio >= 1
                    break;
                end
                errorString = cell2mat(hgs.ce_error_msg(1));
                % If there is any error (ignoring warnings) we can't
                % continue with phasing verification, generate error
                % stop
                if  ~strcmp(errorString,'NO_ERROR') && ...
                        isempty(findstr(errorString,'WARNING'))
                    stateAtErr = commDataPair(hgs,'get_state_at_last_error');
                    tempStr{1} = sprintf('Verification Failed'); %#ok<AGROW>
                    tempStr{2} = sprintf('%s',cell2mat(stateAtErr.error_msg)); %#ok<AGROW>
                    if stateAtErr.error_axis ~= -1
                        tempStr{3} = ['at Joint ', ...
                            num2str(stateAtErr.error_axis+1)]; %#ok<AGROW>
                    end
                    tempStr{end+1} = 'Please Redo Phasing'; %#ok<AGROW>
                    delete(get(guiHandles.uiPanel,'children'));
                    presentMakoResults(guiHandles,'FAILURE',...
                        tempStr);
                    log_message(hgs,['FAILURE ',tempStr]);
                    stop(hgs)
                    return;
                end
            end
            if (isPhasingCanceled)
                return;
            end
        end
        delete(get(guiHandles.uiPanel,'children'));
        %All joints are moved do a final check for error.
        errorString = cell2mat(hgs.ce_error_msg(1));
        if  ~strcmp(errorString,'NO_ERROR') && ...
                isempty(findstr(errorString,'WARNING'))
            
            stateAtErr = commDataPair(hgs,'get_state_at_last_error');
            tempStr{1} = sprintf('Verification Failed');
            tempStr{2} = sprintf('%s',cell2mat(stateAtErr.error_msg));
            
            if stateAtErr.error_axis ~= -1
                tempStr{3} = ['at Joint ', ...
                    num2str(stateAtErr.error_axis+1)];
            end
            tempStr{end+1} = 'Please Redo Phasing';
            presentMakoResults(guiHandles,'FAILURE',tempStr);
            log_message(hgs,['FAILURE ',tempStr]);
            stop(hgs);
        else
            presentMakoResults(guiHandles,'SUCCESS');
            log_message(hgs,'Phasing successful');
        end
    end
%--------------------------------------------------------------------------
% internal function: For verifying and setting  motor phasing parameters
%--------------------------------------------------------------------------
    function out = setAndVerifyPhasingParam(motorIndx)
        %get the phasing parameters
        paraTemp=sscanf(get(tbPhasingParams(motorIndx),'String'),'%f,%f,%f');
        
        %check if correct number of parameters
        if((length(paraTemp)~=3))
            
            updateMainButtonInfo(guiHandles,'pushbutton',...
                'Click here to Start Phasing Procedure');
            
            strTemp = sprintf('Incorrect no. of parameters on motor #%d',...
                motorIndx);
            msgbox( strTemp, 'Phasing Module', 'error' );
            out = false;
            return;
        end
        %check if the parameters are real numbers
        if(~isreal(paraTemp))
            
            updateMainButtonInfo(guiHandles,'pushbutton',...
                'Click here to Start Phasing Procedure');
            
            strTemp = sprintf('Incorrect parameter values for motor #%d',...
                motorIndx);
            msgbox( strTemp, 'Phasing Module', 'error' );
            out = false;
            return;
        end
        
        %now update the parameters array
        phasingParameter(motorIndx,:)=paraTemp;
        
        %check if the intial current command is less then the maximum current
        if(phasingParameter(motorIndx,3)>phasingParameter(motorIndx,1))
            strTemp = sprintf(['Initial current can not be greater than',...
                'the maximum current motor %d'],...
                motorIndx);
            msgbox( strTemp, 'Phasing Module', 'error' );
            out = false;
            return;
        end
        %get the parameters for motor j
        max_current=-abs(phasingParameter(motorIndx,1));
        duration=abs(phasingParameter(motorIndx,2));
        init_current=-abs(phasingParameter(motorIndx,3));
        
        %calculate current limit
        current_limit=torque_limit(motorIndx)/torque_constant(motorIndx);
        
        %saturate the current if commanded current too high
        if (abs(max_current)>current_limit)
            max_current=-abs(current_limit);
            strTemp = sprintf( 'Commanded current too high on motor %d',...
                motorIndx );
            msgbox( strTemp, 'Phasing Module', 'warn');
            out = false;
            return;
        end
        out = true;
        return
    end
%--------------------------------------------------------------------------
% internal function: close GUI, overide the default cancel button callback
%--------------------------------------------------------------------------
    function phase_hgs_close(varargin)
        %set phasing cancel flag
        isPhasingCanceled=true;
        log_message(hgs,'Phasing Procedure Closed');
        %close figures
        closereq;
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------
    function phase_hgs_error()
        %Process error and stop hgs
        phasing_error=lasterror;
        try
            phasingErrorMessage=...
                regexp(phasing_error.message,'\n','split');
            presentMakoResults(guiHandles,'FAILURE',...
                phasingErrorMessage{2});
            log_message(hgs,['FAILURE ', phasingErrorMessage{2}]);
            stop(hgs);
        catch
            %can not do anything
        end
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------

    function [outRange] = checkAngles(hgs,allowed_min,allowed_max)
        % return an array of all joints that are out of range
        outRange = [];
        for j = 1:6
            if(hgs.joint_angles(j)*180/pi() < allowed_min(j) || hgs.joint_angles(j)*180/pi() > allowed_max(j))
                outRange = [outRange j];
            end
        end
    end

%--------------------------------------------------------------------------
% internal function: display joint status of all joints in progress bars
%--------------------------------------------------------------------------

    function displayJ2(varargin)
        try
            % set main button to phasing procedure so that phasing may proceed
            set(guiHandles.mainButtonInfo,'CallBack', ...
                @phasingProcedure)
            
            tmpStr = ['Adjust arm as shown, click when complete '];
            updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
            
            % calculate the desired joint angles during phasing
            minRange = (allowed_min_first-absmin)./ran;
            maxRange = (allowed_max_first-absmin)./ran;
            desAngle = (minRange+maxRange)./2;
            
            %while joints are out of range
            while(phaseProg1)
                
                % capture the joint angles
                curAngle = hgs.joint_angles*180/pi();
                % obtain the ratio of the current angle to the joint range
                ratio = min(1,(curAngle - absmin) ./ ran );
                
                % for each joint set its progress bar yellow if out of range
                % green if in range
                % draw a line at the desired position
                for testJoint = 1:dof
                    if(curAngle(testJoint) < allowed_min_first(testJoint))
                        set(progressBar(testJoint),'FaceColor','yellow');
                    elseif(curAngle(testJoint) > allowed_max_first(testJoint))
                        set(progressBar(testJoint),'FaceColor','yellow');
                    else
                        set(progressBar(testJoint),'FaceColor','green');
                    end
                    
                    set(progressBar(testJoint),...
                        'XData',[ratio(testJoint) 0 0 ratio(testJoint)]);
                    
                    set(currentPositionLine(testJoint),'xData',[desAngle(testJoint) desAngle(testJoint)],'yData',[0 1]);
                end
                drawnow
            end
        catch
            %phase error handling
            phase_hgs_error();
        end
    end


%--------------------------------------------------------------------------
% internal function: display joint status of all joints in progress bars
%--------------------------------------------------------------------------

    function displayJ4(varargin)
        try
            % set the main button procedure to the second phasing procedure
            set(guiHandles.mainButtonInfo,'CallBack', ...
                @phasingProcedure2)
            
            tmpStr = ['Adjust arm as shown, click when complete '];
            updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
            
            % calc the desired joint angles during phasing
            minRange = (allowed_min_second-absmin)./ran;
            maxRange = (allowed_max_second-absmin)./ran;
            desAngle = (minRange+maxRange)./2;
            
            %while joints are out of range
            while(phaseProg2)
                
                % capture the joint angles
                curAngle = hgs.joint_angles*180/pi();
                % obtain the ratio of the current angle to the joint range
                ratio = min(1,(curAngle - absmin) ./ ran );
                
                % for each joint set its progress bar yellow if out of range
                % green if in range
                % draw a line at the desired position
                for testJoint = 1:dof
                    if(curAngle(testJoint) < allowed_min_second(testJoint))
                        set(progressBar(testJoint),'FaceColor','yellow');
                    elseif(curAngle(testJoint) > allowed_max_second(testJoint))
                        set(progressBar(testJoint),'FaceColor','yellow');
                    else
                        set(progressBar(testJoint),'FaceColor','green');
                    end
                    
                    set(progressBar(testJoint),...
                        'XData',[ratio(testJoint) 0 0 ratio(testJoint)]);
                    
                    set(currentPositionLine(testJoint),'xData',[desAngle(testJoint) desAngle(testJoint)],'yData',[0 1]);
                end
                drawnow
            end
        catch
            %phase error handling
            phase_hgs_error();
        end
    end


%--------------------------------------------------------------------------
% internal function: Homing check
%--------------------------------------------------------------------------
    function checkHoming(varargin)
        
        try
            % check homing is done
            if(~hgs.homing_done)
                presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
                log_message(hgs,'Motor phasing failed (Homing not done)',...
                    'ERROR');
                return;
            else
                displayJ2;
            end
        catch
        end
    end

end


% --------- END OF FILE ----------
