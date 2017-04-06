function status = robotFrontPanelEnable(hgs,guiHandles)
% robotFrontPanelEnable helper function to guide user to enable the robot
%
% Syntax:
%    status = robotFrontPanelEnable(hgs,guiHandles)
%       This function will guide the user to use the robot front panel on
%       the connected robot.  Return value status will be true of the robot
%       was successfully enabled.  0 otherwise
%
% Notes:
%    This function is valid only for GUI created with the generateMakoGui
%    function.
%    Please refer to
%    http://twiki.makosurgical.com/view/Robot/HgsServiceAndManufacturingGUITemplate
%    for description on the GUI concept.
%
% See Also:
%    presentMakoResults, generateMakoGui, resetMakoGui,
%    updateMainButtonInfo

% $Author: rzhou $
% $Revision: 2607 $
% $Date: 2012-05-30 16:50:51 -0400 (Wed, 30 May 2012) $
% Copyright: MAKO Surgical corp (2008)

% For safety reasons stop all modes of the robot.  the mode will be
% restarted upon completion of the enable process.  get current mode and
% save it for future use
try
    currentRobotMode = mode(hgs);
    currentButtonState = get(guiHandles.mainButtonInfo);

    % Check if the estop is pressed in and if the green led is off

    % start a clock to allow for flashing
    buttonColor = 'white';
    hardwareResetDone = false;

    while 1
        % read all variables once
        hgsVar = get(hgs);
        % EStop is the only recoverable error  any other error
        if ~hgsVar.estop_status
            % update the button text
            updateMainButtonInfo(guiHandles,'text','Release the EStop');
            % flash the button red
            if strcmp(buttonColor,'white')
                buttonColor = 'red';
            else
                buttonColor = 'white';
            end
            set(guiHandles.mainButtonInfo,...
                'BackgroundColor',buttonColor);
            hardwareResetDone = true;
        elseif hgsVar.arm_status==0
            % The estop is released.  there should be no errors

            % ask user to press and hold the enable button on the robot
            % check if green led stays on for
            updateMainButtonInfo(guiHandles,'text',...
                'Press and hold Flashing Green Button on Robotic Arm');
            % flash the button green
            if strcmp(buttonColor,'white')
                buttonColor = 'green';
            else
                buttonColor = 'white';
            end

            set(guiHandles.mainButtonInfo,...
                'BackgroundColor',buttonColor);

        elseif hgsVar.arm_status == -1
            % there is some other error  (Ask user to press Estop to clear
            % errors
            if ~hardwareResetDone
                updateMainButtonInfo(guiHandles,'text',...
                    'Press the ESTOP to reset faults');
                set(guiHandles.mainButtonInfo,...
                    'BackgroundColor','yellow');
            else
                status = false;
                break;
            end
        elseif hgsVar.arm_status == 1
            % Arm enabled successfully exit
            status = true;
            break;
        end

        pause(0.2);
        drawnow;
    end

    if status
        % everything is good restore the button
        set(guiHandles.mainButtonInfo,...
            'Style',currentButtonState.Style,...
            'String',currentButtonState.String,...
            'BackgroundColor',currentButtonState.BackgroundColor);
        if ~strcmp(currentRobotMode,'NONE')
            mode(hgs,currentRobotMode);
        end
    else
        presentMakoResults(guiHandles,'FAILURE',...
            {'Unable to enable Robotic Arm',...
            sprintf('%s (J%d)',hgsVar.ce_error_msg{1},hgsVar.error_axis+1)});
    end


catch
    return;
end
end


% --------- END OF FILE ----------