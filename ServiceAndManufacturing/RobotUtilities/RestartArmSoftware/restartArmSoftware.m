function restartArmSoftware
%restartArmSoftware GUI to help restart arm software
%
% Syntax:
%   restartArmSoftware(hgs)
%       Start the GUI to check the basics setup of the arm
%
% Description
%   This script will make an attempt possible to restart the arm
%   software (CRISIS)
%

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

% this function works only in unix machines for now.  if we are on a
% windows machine give an error
if ~isunix
    errordlg('This feature is currently supported in unix based systems only');
    return
end

USERNAME='root';
PASSWORD='50%sOlN';
target_robot = getenv('ROBOT_HOST');
cancelButtonPressed = false;

% setup the basic GUI
guiHandles = generateMakoGui('Restart Arm Software',[],target_robot);
log_message(hgs,'Restart Arm Software Script Started');
updateMainButtonInfo(guiHandles,'pushbutton',...
    'Click here to Restart Arm Software',...
    @restart_crisis_telnet);
set(guiHandles.figure,'CloseRequestFcn',@abortProcedure);

%set up display text location
commonTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.8,...
    'HorizontalAlignment','left');

uicontrol(guiHandles.uiPanel,...
    'Style','text',...
    'String','ATTENTION',...
    'fontUnits','normalized',...
    'fontSize',0.8,...
    'Units','normalized',...
    'background','yellow',...
    'Position',[0.05 0.75 0.9 0.2]);
uicontrol(guiHandles.uiPanel,...
    'Style','text',...
    'fontUnits','normalized',...
    'fontSize',0.1,...
    'Units','normalized',...
    'background','white',...
    'String',{'This script will restart the Arm Software',...
        'once initiated this action cannot be cancelled'},...
    'Position',[0.05 0.05 0.9 0.7]);
drawnow

%--------------------------------------------------------------------------
% internal function for the top level execution of arm software reset
%--------------------------------------------------------------------------
    function restart_crisis_telnet(varargin)
        try
            delete(get(guiHandles.uiPanel,'children'));
            updateMainButtonInfo(guiHandles,'text',....
                {'Restarting Arm Software...please wait',...
                'This process takes about 15 secs'});

            if ispc
                pingCommand = 'ping -w 1000 -n 1 ';
            else
                pingCommand = 'ping -w 1 -c 1 ';
            end

            % ping the robot for a quick check
            [pingFailure,pingReply] = system([pingCommand,target_robot]); %#ok<NASGU>
            if pingFailure
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Target (%s) not reachable...network error',target_robot));
                return;
            end
            
            % setup the command to send
            systemCommand = sprintf(['(sleep 1; echo %s; sleep 2; echo %s; sleep 1; '...
                'echo "cd /CRISIS/bin";'...
                'echo "./crisis_manager -r all";sleep 20;'...
                'echo "exit") | telnet %s'],...
                USERNAME,PASSWORD,target_robot);
            
            
            [resultStatus,resultText] = system(systemCommand);
            if ~resultStatus
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Error executing shell command (%s)',resultText));
                return;
            end

            armRestartSuccessful = presentCrisisStatus;

            % declare success if I get here
            if armRestartSuccessful
                presentMakoResults(guiHandles,'SUCCESS');
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    {'All arm software process could not be started',...
                    'See logs for details'});
            end
        catch
            if cancelButtonPressed
                return;
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    lasterr);
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to present CRISIS status
%--------------------------------------------------------------------------
    function allProcessRunning = presentCrisisStatus()

        % Clear the Ui section
        delete(get(guiHandles.uiPanel,'children'));
        
        % update the main button
        updateMainButtonInfo(guiHandles,'text',...
            'Checking Status...Please Wait');

        % check the status
        armStatus = armSoftwareStatus;

        allProcessRunning = true;
        for i=1:length(armStatus)
            uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.1 0.9-0.1*i 0.3 0.07],...
                'String',armStatus(i).processName);

            if ~armStatus(i).Status
                allProcessRunning = false;
                resultColor = 'red';
            else
                resultColor = 'green';
            end

            uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'String',armStatus(i).StatusText,...
                'BackgroundColor',resultColor,...
                'Position',[0.4 0.9-0.1*i 0.5 0.07]);
        end

    end

%--------------------------------------------------------------------------
% internal function to cancel the procedure
%--------------------------------------------------------------------------
    function abortProcedure(varargin)
        cancelButtonPressed = true;
        pause(0.3);
        log_message(hgs,'Restart Arm Software Script Closed');
        closereq;
    end

end

%------------- END OF FILE ----------------