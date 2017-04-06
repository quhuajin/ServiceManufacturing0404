function phasing_check(hgs)
%PHASING_CHECK Gui to help perfrom motor phasing check
%
% Syntax:
%   PHASING_CHECK(hgs)
%       This script verifies motor phasing by comparing electrical phase
%       angle of each motor against the theoretical value of phase angle
%       at each hall transition.
%
%
% Notes:
%   This script requires the hgs_robot to see if the homing is
%   performed or not. The script can only be used with robots equipped
%   with  2.x Mako CPCI motor controller hardware. The data should be
%   collected at very slow velocity to obtain reliable results.
%
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home_hgs,
%   phase_hgs
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot

%  At 18 degrees phase error we have approximately
%  5% torque efficiency reduction
%  At 25 degrees we have 10%  torque efficiency reduction
ALLOWABLE_PHASE_ERROR = 18; %in degrees
ALLOWABLE_PHASE_ERROR_SHIFT = 4; % in degrees

if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

samplePeriodTooLarge = false;
% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: phasing_check argument must be an hgs_robot object');
end
checkPassed = true;

try
    previousPhaseError = hgs.PHASE_ANGLE_ERROR;
catch
    uiwait(msgbox({'No entry found for PHASE_ANGLE_ERROR', ...
        'in configuration file.','Cannot run Phase check.'}, ...
        'Phase Check','warn'));
    return;
end



% Setup Script Identifiers for generic GUI with extra panel
scriptName = 'Phase Check';
guiHandles = generateMakoGui(scriptName,[],hgs);
log_message(hgs,'Motor Phase Check Started');
try
    %figure/GUI fullscreen figures, use simple java to maximize the window
    set(get(guiHandles.figure,'JavaFrame'),'Maximized',true);

    set(guiHandles.figure,...
        'CloseRequestFcn',@closeCallBackFcn);
    % Setup the main function
    set(guiHandles.mainButtonInfo,'CallBack', ...
        @phasecheckProcedure)
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@phasecheck_close);

    %set degree of freemdom parameters
    dof = hgs.ME_DOF;

    %initialize the phasing error to false
    isProcedureCanceled=false;
    % Setup boundaries for phasing  boxes
    xMin = 0.05;
    xRange = 0.9;
    yMin = 0.45;
    yRange = 0.15;
    spacing = 0.05;

    %define the common properties for all uicontrol
    commonBoxProperties = struct(...
        'Units','Normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'SelectionHighlight','off',...
        'Enable','Inactive');

    %add pushbuttons to show phasing stauts
    for j=1:dof %#ok<FXUP>
        boxPosition = [xMin+(xRange+spacing)*(j-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        motorBox(j) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','pushbutton',...
            'Position',boxPosition,...
            'FontSize',0.3,...
            'String',sprintf('M%d',j)); %#ok<AGROW>
        bwText(j) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','text',...
            'Position',boxPosition+[0 -0.15 0 0],...
            'FontSize',0.25,...
            'visible', 'off',...
            'String',sprintf('%d',0)); %#ok<AGROW>
    end

    %setup mainbutton and display message
    tmpStr = sprintf('Click here to start Phasing Check');
    updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
    set(guiHandles.mainButtonInfo,'FontSize',0.3);

catch
    %phase error handling
    phasing_check_error();
end

%--------------------------------------------------------------------------
% internal function: Manin function for phasing
%--------------------------------------------------------------------------
    function phasecheckProcedure(varargin)
        try
            %guide user to enable arm
            robotFrontPanelEnable(hgs,guiHandles);
            pause(.1);
            mode(hgs,'zerogravity','ia_hold_enable',0);
            updateMainButtonInfo(guiHandles,'text',...
                'Arm is moving to start position');
            start_pos =  [0.03   -1.1    0.1    2.7  3.6 0.5];
            go_to_position(hgs,start_pos,0.15);
            end_pose = [0.7678   -1.625   -0.58    2.1  3.6 0.5];
            mode(hgs,'go_to_position', 'target_position', end_pose, ...
                'max_velocity',0.03);
            updateMainButtonInfo(guiHandles,'text',...
                'Arm is moving to target position ...');
            pause(2);
            updateMainButtonInfo(guiHandles,'text',...
                'Collecting data please wait ...');
            [dt1.time, dt1.hall_states, dt1.phase_angle] = ...
                collect(hgs,22,.002, 'time', 'hall_states', 'phase_angle');

            if isProcedureCanceled
                return;
            end

            phaseErrorReturn = calculatePhaseError(dt1,1:4);
            phaseError(1:4) = phaseErrorReturn(1:4);

            % Collect data for wrist
            end_pose = [0.7678   -1.625   -0.58    2.1  2.3 -0.2];
            mode(hgs,'go_to_position', 'target_position', end_pose, ...
                'max_velocity',0.07);
            updateMainButtonInfo(guiHandles,'text',...
                'Arm is moving to target position ...');
            pause(2);
            updateMainButtonInfo(guiHandles,'text',...
                'Collecting data please wait ...');
            [dt2.time, dt2.hall_states, dt2.phase_angle] = ...
                collect(hgs,17,.002, 'time', 'hall_states', 'phase_angle');
            if isProcedureCanceled
                return;
            end


            % process wrist data
            phaseErrorReturn = calculatePhaseError(dt2,5:6);
            phaseError(5:6) = phaseErrorReturn(5:6);

            if isProcedureCanceled
                return;
            end

            updateMainButtonInfo(guiHandles,'text',...
                'Analysing Data');
            %return if cancel is pressed
            mode(hgs,'zerogravity','ia_hold_enable',0);

            fileName =[sprintf('PhaseCheckData-%s-',hgs.name),...
                datestr(now,'yyyy-mm-dd-HH-MM')];
            fullFileName=fullfile(guiHandles.reportsDir,fileName);
            save(fullFileName, 'dt1','dt2', 'phaseError');
            if isProcedureCanceled
                return;
            end
            errMsg = [];
            ln = 1;
            checkPassed = true(1,dof);
            for mtr=1:6
                if phaseError(mtr) > ALLOWABLE_PHASE_ERROR
                    errMsg{ln} = sprintf(['J%d Phase error = %3.1f deg (limit ' ...
                        '%2.1f deg)'], mtr,  phaseError(mtr), ...
                        ALLOWABLE_PHASE_ERROR); %#ok<AGROW>
                    ln = ln + 1;
                    checkPassed(mtr) = false;
                end
                phaseErrorChange(mtr) =  abs(phaseError(mtr) -  previousPhaseError(mtr)); %#ok<AGROW>
                if (previousPhaseError(mtr)>0  && ...
                        phaseErrorChange(mtr) > ALLOWABLE_PHASE_ERROR_SHIFT)
                    errMsg{ln} = sprintf(['J%d phase error change = %2.1f deg (limit ' ...
                        '%2.1f deg)'], mtr,  phaseErrorChange(mtr), ...
                        ALLOWABLE_PHASE_ERROR_SHIFT); %#ok<AGROW>
                    ln = ln + 1;
                    checkPassed(mtr) = false;
                end
                if checkPassed(mtr) == true
                    set(motorBox(mtr),'BackgroundColor','green');
                else
                    set(motorBox(mtr),'BackgroundColor','red');
                end
            end
            
            Results.phaseError = phaseError;
            Results.ALLOWABLE_PHASE_ERROR = ALLOWABLE_PHASE_ERROR;
            Results.phaseErrorChange = phaseErrorChange;
            Results.ALLOWABLE_PHASE_ERROR_SHIFT = ALLOWABLE_PHASE_ERROR_SHIFT;
            if all(checkPassed == true)
                %update only if we pass all checks
                if samplePeriodTooLarge == true
                     presentMakoResults(guiHandles,'WARNING',...
                    {'All motor phase angles within limits, however', ...
                     ['a timing issue was detected during data ' ...
                      'collection.'], 'Please rerun the phase check.'});
                  log_results(hgs,'MotorPhaseCheck','WARNING', 'Test passed with timing warning', Results)

                else
                    hgs.PHASE_ANGLE_ERROR =   phaseError;
                    presentMakoResults(guiHandles,'SUCCESS',...
                        'All motor phase angles within limits');
                    log_results(hgs,'MotorPhaseCheck','PASS', 'Test passed', Results)
                                    
                end
            else
                if samplePeriodTooLarge == true
                    errMsg{ln} = sprintf(['A timing issue was detected ' ...
                                        'that may affect results.']);
                    errMsg{ln+1} = sprintf('Please rerun the phase check.');
                end
                presentMakoResults(guiHandles,'FAILURE',errMsg);
                log_results(hgs,'MotorPhaseCheck','FAIL', 'Test failed with timing issue', Results)
            end
        catch
            %phase error handling
            phasing_check_error();
        end
    end

%--------------------------------------------------------------------------
% internal function: close GUI, overide the default cancel button callback
%--------------------------------------------------------------------------
    function phasecheck_close(varargin)
        log_message(hgs,'Motor Phase Check Closed');
        %set phasing cancel flag
        isProcedureCanceled=true;
        try
            mode(hgs,'zerogravity','ia_hold_enable',0);
        catch

        end
        %close figures
        closereq;
    end

    function phErr = calculatePhaseError(phData,mtrInput)
        for mtr=mtrInput
            indx = find(diff(phData.hall_states(:,mtr)) ~= 0);
            outp = zeros(length(indx),3);
            for i=1:length(indx)
                %average before and after phase angle reading
                outp(i,1:2) = [phData.hall_states(indx(i)+1,mtr), ...
                    (phData.phase_angle(indx(i)+1,mtr)+ ...
                    phData.phase_angle(indx(i),mtr))*180/2^15];
                %if sampling period at the hall transion was larger
                %than 50 msec generate a warning.
                if diff(phData.time(indx(i):indx(i)+1)) > 0.050
                    samplePeriodTooLarge = true;
                end
                % The relationship between hall states and motor phase
                % angles are as follows:
                % phase angle between 330 and 30 -> hall_state = 5;
                % phase angle between 30 and 90 -> hall_state = 1;
                % phase angle between 90 and 150 -> hall_state = 3;
                % phase angle between 150 and 210 -> hall_state = 2;
                % phase angle between 210 and 270 -> hall_state = 6;
                % phase angle between 270 and 330 -> hall_state = 4;
                % in the following switch statement first column of
                % outp is hall_states and second column is phase angles
                % third column is then the calculated phase angle error
                switch outp(i,1)
                    case 1
                        if phData.hall_states(indx(i),mtr) == 5,
                            outp(i,3) = 30 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 3,
                            outp(i,3) = 90 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    case 2
                        if phData.hall_states(indx(i),mtr) == 3,
                            outp(i,3) = 150 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 6,
                            outp(i,3) = 210 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    case 3
                        if phData.hall_states(indx(i),mtr) == 1,
                            outp(i,3) = 90 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 2,
                            outp(i,3) = 150 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    case 4
                        if phData.hall_states(indx(i),mtr) == 6,
                            outp(i,3) = 270 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 5,
                            outp(i,3) = 330 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    case 5
                        if phData.hall_states(indx(i),mtr) == 4,
                            outp(i,3) = 330 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 1,
                            outp(i,3) = 30 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    case 6
                        if phData.hall_states(indx(i),mtr) == 2,
                            outp(i,3) = 210 - outp(i,2);
                        elseif phData.hall_states(indx(i),mtr) == 4,
                            outp(i,3) = 270 - outp(i,2);
                        else
                            error('wrong seqence');
                        end
                    otherwise
                        error('wrong hall state');
                end
            end
            phErr(mtr) = max(abs(outp(:,3))); %#ok<AGROW>
            if isProcedureCanceled == false
                set( bwText(mtr), 'string', ...
                    sprintf('%3.1f deg', phErr(mtr)), ...
                    'visible', 'on' );
            end
        end
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------
    function  phasing_check_error()
        %Process error and stop hgs
        phasing_check_error=lasterror;
        phasing_checkErrorMessage=...
            regexp(phasing_check_error.message,'\n','split');
        if ~isProcedureCanceled
            presentMakoResults(guiHandles,'FAILURE',...
                phasing_checkErrorMessage{2});
            stop(hgs);
        end
    end
end


% --------- END OF FILE ----------
