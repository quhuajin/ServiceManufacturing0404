% HASSTEST performs HASS (Highly Accelerated Stress Screening) on hgs
% robot.
%
% Syntax:
%   HASStest(), performs hass on default hgs robot
%   HASStest(robot), performs hass on the robot specified robot
%
% Test Description:
% HASS test consists of repeated cycles on excitation and evaluation. The
% purpose of the excitation is to simulate the operating condition of the
% robot.
%
% Excite the robot by performing
%    1. vibrating in the rang of motion, and
%    2. brake cycling
%
% After excitation, health of the robot is evaluated by performing the
% following checks
%    1. Tension Check
%    2. Brake Check
%    3. Friction Check

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

function guiHandles=HASSTest(hgs,varargin)
% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

if (~isa(hgs,'hgs_robot'))
    hgs = hgs_robot;
end

%define default number of cycles
no_of_cycles = 25;

log_message(hgs,'HASS Script Started');

mainButtonStartText='Click Here To Start HASS Cycle';

if nargin==2
    if(strcmp(varargin{1},'FieldService'))
        no_of_cycles = 8; %8
        mainButtonStartText='Click Here To Start Field HASS Cycle';
    end
end
isTestCanceled = false;
% generate mako gui
guiHandles = generateMakoGui('HASS Test',[],hgs,1);

set(guiHandles.figure,...
    'CloseRequestFcn',@closeFigure);

if ~homingDone(hgs)
    presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
    log_results(hgs,guiHandles.scriptName,'ERROR','HASS Test failed (Homing not done)');
    return;
end

robotFrontPanelEnable(hgs,guiHandles);

% before starting hass, stop(hgs) to clear out all existing modules
stop(hgs);
pause(0.1);
mode(hgs,'zerogravity');

% flags
count = 0;
global stop_on_error;
stop_on_error = false;
pass_test = false;
pass_hass = true;

% do tests. Perform the following test
do_vibrate = true;
do_brakecycle = true;
do_tensioncheck = true;
do_brakecheck = true;
do_frictioncheck = true;

% result structure definition
hass_result=[];
hass_result.tension={};
hass_result.brakecheck=[];
hass_result.friction = {};
hass_result.testfailed = {};

accuracyFailureInCycles = '';
frictionFailureInCycles = '';
brakeFailureInCycles = '';
tensionFailureInCycles = '';

% variables to be plotted
phase_lag = []; % tension check
friction_normalized = []; % friction check
maxBrakeTorque = []; % brake check
maxReleaseTorque = [];
% robot vibrate parameters
duration_vibrate = 60; %60 seconds
scaledown = 5; %5 times less intense than the reliability HASS test level
% joint limits. J3 is clamped at +/- 90 deg inside the vibrate function

limits.pos = hgs.JOINT_ANGLE_MAX;
limits.neg = hgs.JOINT_ANGLE_MIN;

limits.cen = (limits.pos + limits.neg) / 2;
limits.range = (limits.pos - limits.neg) / 2;
% this factor ensures that range of motion
% for joint exercise remains unchanged.
fct = [0.46, 0.78, 0.89, 0.71, 0.85, 0.81];
limits.pos = limits.cen + limits.range .* fct;
limits.neg = limits.cen - limits.range .* fct;
% recalculate limit.range because the limit correction
% factor changes the positive and negative joint
% position limits
limits.range = (limits.pos - limits.neg) / 2;

% brake cycling
pose_brakecycling = [0,-pi/2,0,pi/2,0,0]; %rads
no_of_brakecycles = 24; %24

% start in default pause state
hass_pause = true;

% now set up main button for hass
set(guiHandles.mainButtonInfo,...
    'String',mainButtonStartText,...
    'Callback',@hass)

% generate results data file name, and safe data file
dataFileName=['HASS-DATA-',...
    hgs.name,'-',...
    datestr(now,'yyyy-mm-dd-HH-MM')];
fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);
save (fullDataFileName, 'hass_result');

% A log file is used to create Hass error log
logFileName=['HASS-ERROR-LOG-',...
    hgs.name,'-',...
    datestr(now,'yyyy-mm-dd-HH-MM'),'.txt'];
fullLogFileName = fullfile(guiHandles.reportsDir,logFileName);

% Pause between tests variables
updateRate = .5;
waitTime = 3;
                
%% set up GUI

%%display for results, status etc
text1 = uicontrol(guiHandles.uiPanel,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.2,0.5,0.6,0.3],...
    'FontSize',0.4,...
    'String',sprintf('%d HASS Cycles to Run',no_of_cycles));

text2 = uicontrol(guiHandles.uiPanel,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.2,0.3,0.6,0.2],...
    'FontSize',0.4,...
    'String','Robot HASS Test');

% Plots
% handle for plot1
plothandle1 = axes(...
    'parent',guiHandles.extraPanel,...
    'Position',[0.1 0.025 0.8 0.17]);
grid(plothandle1,'on');
title(plothandle1,'Joint Friction')
ylabel(plothandle1,'Friction,Nm');
xlabel(plothandle1,'Cycle');

%handle for plot 2
plothandle2 = axes(...
    'parent',guiHandles.extraPanel,...
    'Position',[0.1 0.8 0.8 0.17]);
grid(plothandle2,'on');
title(plothandle2,'Cable Tension');
ylabel(plothandle2,'Phase Lag, deg');
% xlabel(plothandle2,'Cycle');

%handle for plot 3
plothandle3 = axes(...
    'parent',guiHandles.extraPanel,...
    'Position',[0.1 0.525 0.8 0.17]);
grid(plothandle3,'on');
title(plothandle3,'Brake Test');
ylabel(plothandle3,'Brake Data');
% xlabel(plothandle3,'Cycle');

% handle for plot4
plothandle4 = axes(...
    'parent',guiHandles.extraPanel,...
    'Position',[0.1 0.275 0.8 0.17]);
grid(plothandle4,'on');
title(plothandle4,'Brake Release Test')
ylabel(plothandle4,'Brake Data');

%% pause function
    function pauseHASS(hObject,eventdata) %#ok<INUSD>
        % set hass_pause flag to true
        hass_pause = true;
        % put robot in zerogravity
        mode(hgs,'zerogravity','ia_hold_enable',0);
        
        set(guiHandles.figure, 'HandleVisibility', 'off');
        close all;
        set(guiHandles.figure, 'HandleVisibility', 'on');
        
        try
            % hold execution in a while loop till resume hass is invoked
            while hass_pause
                set(guiHandles.mainButtonInfo,...
                    'String','Test Paused. Click here to Resume HASS',...
                    'BackgroundColor', [1 .45 .06],...
                    'Callback',@resumeHASS)
                
                pause(0.5);
            end
        catch
            %ignore error if test was canceled
            if isTestCanceled
                return;
            else
                rethrow(lasterror);
            end
        end
    end

%% resume function
    function resumeHASS(hObject,eventdata) %#ok<INUSD>
        hass_pause = false;
        set(guiHandles.mainButtonInfo,'Callback',@pauseHASS)
        pause(0.1);  
    end

%% main HASS function

    function hass(hObject,eventdata) %#ok<INUSD>
        
        try
            erm = []; % init error message to empty
            
            % get into the routine where user has to press the flashing green
            % button
            if ~robotFrontPanelEnable(hgs,guiHandles)
                return;
            end
            
            % TEST PROCS BEGINGS HERE
            % set pause flag to false at the onset of hass
            hass_pause = false;
            
            % and change main button to pause button
            set(guiHandles.mainButtonInfo,...
                'String','Starting HASS...',...
                'BackgroundColor', [1 .45 .06],...
                'enable','off', ...
                'Callback',@pauseHASS)
            
            comm(hgs,'set_gravity_constants','KNEE');
            
            % HASS CYCLES BEGINS HERE %
            while count < no_of_cycles                
                
                if isTestCanceled
                    return;
                end
                count = count+1;
                disp(['run: ',num2str(count)])
                pause(1)
                set(text1,...
                    'String',['Cycle: ',num2str(count),...
                    '/',num2str(no_of_cycles)])
                
                % ROBOT EXCITATION BEGINS HERE %
                % excite the robot by performing
                % 1. vibration in the rang of motion
                % 2. brake cycling
                
                % Vibrate Robot, part of excitation
                if do_vibrate
                    % disable pause button
                    set(guiHandles.mainButtonInfo,'enable','off', ...
                     'String','Cannot Pause HASS During Vibrate Robot')
                    
                    set(text2,'String','Performing robot vibration')
                    pause(3);
                    [handleVibrate, vibErr] = VibrateRobot(hgs,...
                        'limits',limits,...
                        'duration',duration_vibrate,...
                        'scaledown',scaledown); %#ok<NASGU>
                    pause(1);
                    if ~isempty(vibErr)
                        errLog = sprintf(['HASS cycle %d- Vibrate robot stopped in Cycle ' ...
                            '%d CRISIS error: %s'],  count, vibErr);
                        appendToLogFile(fullLogFileName, errLog);
                        % enable button so text is black, not gray which doesn't print
                        set(guiHandles.mainButtonInfo,'enable','on');
                        presentMakoResults(guiHandles,'FAILURE',...
                            vibErr);
                          log_results(hgs,guiHandles.scriptName,'FAIL',...
                              vibErr);
                        return;
                    end
                end
                
                % enable pause button for 3 seconds
                set(guiHandles.mainButtonInfo,'enable','on')
                for t = 0:updateRate:waitTime                
                set(guiHandles.mainButtonInfo,'String',sprintf('Pause HASS (%1.1f seconds left)',waitTime-t))
                pause(updateRate);
                end
                
                % Brake cycling, part of excitation
                if do_brakecycle
                    set(guiHandles.mainButtonInfo,'enable','off', ...
                        'String','Cannot Pause HASS During Brake Cycling')
                 
                    set(text2,'String','Performing Brake Cycling')
                    go_to_position(hgs,pose_brakecycling);
                    pause(3);
                    mode(hgs,'zerogravity','ia_hold_enable',0);
                    for n = 1:no_of_brakecycles
                        if isTestCanceled
                            return;
                        end
                        set(text2,'String',['Performing Brake Cycling (' num2str(n) '/' num2str(no_of_brakecycles) ')'])
                        stop(hgs);
                        pause(0.2);
                        mode(hgs,'zerogravity','ia_hold_enable',0);
                        pause(0.2);
                    end
                    pause(0.5);
                end
                
                % EVALUATION BEGINS HERE %
                % after excitation, health of the robot is evaluated by performing the
                % following checks
                % 1. Tension Check
                % 2. Brake Check
                % 3. Friction Check
                
                % put robot in zero gravity mode
                mode(hgs,'zerogravity','ia_hold_enable',0);
                pause(0.5);   
                
                % enable pause button for 3 seconds
                set(guiHandles.mainButtonInfo,'enable','on')
                for t = 0:updateRate:waitTime
                    set(guiHandles.mainButtonInfo,'String',sprintf('Pause HASS (%1.1f seconds left)',waitTime-t))
                    pause(updateRate);
                end
                
                % Tension Check,
                if do_tensioncheck             
                    set(text2,'String','Performing Tension Check')
                   
                    % disable pause button
                    set(guiHandles.mainButtonInfo,'enable','off', ...
                        'String','Cannot Pause HASS During Tension Check')                 
        
                    [hass_result,pass_test,phase_lag, errLog] = tensioncheck(hgs,...
                        hass_result,...
                        fullDataFileName,...
                        phase_lag,count);
                    
                    if isTestCanceled
                        return;
                    end
                    if pass_test
                        % take a second and move on
                        pause(1);
                    else
                        pass_hass = false;
                        set(text2,'String','Tension Check Failed,.. ;-(')
                    
                        hass_result.testfailed{count}...
                            = {['tension check, ','Cycle ',num2str(count)]};
                        tensionFailureInCycles = strcat(tensionFailureInCycles, ...
                            sprintf(' %d,', count));
                        
                        if ~isempty(errLog)
                            if (strcmp(errLog(end),sprintf('\n'))),
                                errLog(end) = []; %remove newline
                            end
                            errLog = sprintf('HASS cycle %d- Transmission Check Failed: \n%s', ...
                                count, errLog);
                            appendToLogFile(fullLogFileName, errLog);
                        end
                        % stop test if stop on hass flag is on
                        if stop_on_error
                            break;
                        end
                    end
                    % plot tension check result, as a stem plot
                    if size(phase_lag,2)==1
                        plot(plothandle2,ones(size(phase_lag,2),1),phase_lag','-o');
                    else
                        plot(plothandle2,phase_lag','-o');
                    end
                    
                    legend(plothandle2,'J1','J2','J3','J4','J5','J6','Location',[0.025 0.475 0.001 0.001]);
                    grid(plothandle2,'on');
                    title(plothandle2,'Cable Tension');
                    ylabel(plothandle2,'Phase Lag, normalized');
                    xlabel(plothandle2,'Cycle');
                end
                
                % enable pause button for 3 seconds
                set(guiHandles.mainButtonInfo,'enable','on')
                for t = 0:updateRate:waitTime
                    set(guiHandles.mainButtonInfo,'String',sprintf('Pause HASS (%1.1f seconds left)',waitTime-t))
                    pause(updateRate);
                end
                
                % Brake Check,
                if do_brakecheck
                    set(text2,'String','Performing Brake Holding Check')
                    
                   % disable pause button
                    set(guiHandles.mainButtonInfo,'enable','off', ...
                        'String','Cannot Pause HASS During Brake Check')
                    
                    [hass_result,pass_test, errLog] = brakecheck(hgs,...
                        hass_result,...
                        fullDataFileName, count);
                    
                    if isTestCanceled
                        return;
                    end
                    
                    if pass_test
                        % take a breath and move on
                        pause(1);
                    else
                        pass_hass = false;
                        
                        if isTestCanceled
                            return;
                        end
                        set(text2,'String','Brake Holding Check Failed')
                        hass_result.testfailed{count}...
                            = {['brake check, ','Cycle ',num2str(count)]};
                        brakeFailureInCycles = strcat(brakeFailureInCycles, ...
                            sprintf(' %d,', count));
                        
                        % stop test if stop on hass flag is on
                        if stop_on_error
                            break;
                        end
                    end
                    
                    maxPosTorque = hass_result.brakecheck{count}.maxPositiveTorquesApplied;  
                    maxNegTorque = hass_result.brakecheck{count}.maxNegativeTorquesApplied;
                    maxTorque = min([maxPosTorque ; -maxNegTorque]);
                    maxBrakeTorque(count,:) = maxTorque./hass_result.brakecheck{count}.BRAKE_HOLDING_TQ_LIMIT;
                    
                    % plot brake check result, as a stem plot
                    if size(maxBrakeTorque',2)==1
                        plot(plothandle3,ones(size(maxBrakeTorque',2),1),maxBrakeTorque','-o');
                    else
                        plot(plothandle3,maxBrakeTorque,'-o');
                    end

                    grid(plothandle3,'on');
                    title(plothandle3,'Brake Holding Test');
                    ylabel(plothandle3,'Brake Data, normalized');
                    xlabel(plothandle3,'Cycle');
                    
                    maxReleaseTorque(count,:) = hass_result.brakecheck{count}.maxReleaseTq./hass_result.brakecheck{count}.BRAKE_RELEASE_TQ_LIMIT;
                    if size(maxReleaseTorque',2)==1
                        plot(plothandle4,ones(size(maxReleaseTorque',2),1),maxReleaseTorque','-o');
                    else
                        plot(plothandle4,maxReleaseTorque,'-o');
                    end
                    grid(plothandle4,'on');
                    title(plothandle4,'Brake Release Test');
                    ylabel(plothandle4,'Brake Data, normalized');
                    xlabel(plothandle4,'Cycle');
                    
                    if ~isempty(errLog)
                        errLog = sprintf('HASS cycle %d-  Brake Check Failed \n%s', ...
                            count, errLog);
                        appendToLogFile(fullLogFileName, errLog);
                    end
                end
                
                % enable pause button for 3 seconds
                set(guiHandles.mainButtonInfo,'enable','on')
                for t = 0:updateRate:waitTime
                    set(guiHandles.mainButtonInfo,'String',sprintf('Pause HASS (%1.1f seconds left)',waitTime-t))
                    pause(updateRate);
                end
                
                % Friction Check,
                if do_frictioncheck
                    if isTestCanceled
                        return;
                    end

                    set(text2,'String','Performing Friction Check')
                    
                   % disable pause button
                    set(guiHandles.mainButtonInfo,'enable','off', ...
                        'String','Cannot Pause HASS During Friction Check')
                    
                    [hass_result,pass_test,friction_normalized, errLog] =...
                        frictioncheck(hgs,...
                        hass_result,...
                        fullDataFileName,...
                        friction_normalized,count);
                                                                                    
                    if isTestCanceled
                        return;
                    end
                    if pass_test == 1
                        % take a breath and proceed to next function
                        pause(1);
                    else
                        pass_hass = false;
                        set(text2,'String','Friction Check Failed!!!')
                        hass_result.testfailed{count}...
                            = {['friction check, ','Cycle ',num2str(count)]};
                        frictionFailureInCycles = strcat(frictionFailureInCycles, ...
                            sprintf(' %d,', count));
                        
                        % stop test if stop on hass flag is on
                        if stop_on_error
                            break;
                        end
                    end
                    if ~isempty(errLog) && ~pass_test
                        errLog = sprintf('HASS cycle %d-  Friction Check Failed: \n\t%s', ...
                            count, errLog);
                        appendToLogFile(fullLogFileName, errLog);
                    end
                    if pass_test == -1
                        pass_hass = false;
                        resultStr = generateResultString;
                        % enable button so text is black, not gray which doesn't print
                        set(guiHandles.mainButtonInfo,'enable','on');
                        presentMakoResults(guiHandles,'FAILURE',...
                            resultStr);
                        log_results(hgs,guiHandles.scriptName,'FAIL',...
                            resultStr);
                    end
                end
                % plot friction check result, as a stem plot
                if size(friction_normalized,2)==1
                    plot(plothandle1,ones(size(friction_normalized,2),1),friction_normalized','-o');
                else
                    plot(plothandle1,friction_normalized','-o');
                end
                
                grid(plothandle1,'on');
                title(plothandle1,'Joint Friction');
                ylabel(plothandle1,'Friction, normalized');
                xlabel(plothandle1,'Cycle');
                
                % enable pause button for 3 seconds if not done with cycles
                if count ~= no_of_cycles 
                    set(guiHandles.mainButtonInfo,'enable','on')
                    for t = 0:updateRate:waitTime
                        set(guiHandles.mainButtonInfo,'String',sprintf('Pause HASS (%1.1f seconds left)',waitTime-t))
                        pause(updateRate);
                    end
                end
                
            end %end of hass cycle
            
            
        catch
            if isTestCanceled
                return
            else
                pass_hass = false;
                resultStr = generateResultString;
                % enable button so text is black, not gray which doesn't print
                set(guiHandles.mainButtonInfo,'enable','on');
                presentMakoResults(guiHandles,'FAILURE',...
                    resultStr);
                log_results(hgs,guiHandles.scriptName,'FAIL',...
                            resultStr);
            end
        end
        
        % before getting out, save the hass results (this one saves to the
        % current directory)
        save (fullDataFileName, 'hass_result')
        
        % enable button so text is black, not gray which doesn't print
        set(guiHandles.mainButtonInfo,'enable','on');
            
        %remove any previous display Message;
        set(text1,'String','');
        set(text2,'String','');
        % now update display
        if pass_hass == true
            presentMakoResults(guiHandles,'SUCCESS',...
                'HASS Test PASS');
                        log_results(hgs,guiHandles.scriptName,'PASS',...
                            'HASS completed Successfully');
        else
            resultStr = generateResultString;
            presentMakoResults(guiHandles,'FAILURE',...
                resultStr);
            log_results(hgs,guiHandles.scriptName,'FAIL',...
                            resultStr);
        end
        if pass_hass == false && ispc &&  exist(fullLogFileName,'file') == 2
            set(text1, 'String', 'View Error Logs', ...
                'Style','pushbutton', ...
                'CallBack', @openLogFile);
        end
        % before exiting, go to zerogravity mode
        mode(hgs,'zerogravity','ia_hold_enable',0);
        
    end

    function openLogFile(varargin)
        
        if (exist('C:\Program Files\Windows NT\Accessories\wordpad.exe', ...
                'file') == 2)
            system (['"C:\Program Files\Windows NT\Accessories\wordpad.exe" "',...
                fullLogFileName,'"']);
        else
            system (['notepad "', fullLogFileName,'"']);
        end
        
    end

    function str = generateResultString()
        k = 1;
        if count ~= no_of_cycles
            str{k} = sprintf('Hass did not finish all %d cyles \n', ...
                no_of_cycles);
            k = k+1;
        end
        
        if length(tensionFailureInCycles) > 1
            tensionFailureInCycles(end) = []; %remove the comma at the end
            %of string
            str{k} = 'Transmission Check failed in cycle(s):';
            str{k+1} = tensionFailureInCycles;
            k= k+2;
        end
        if length(brakeFailureInCycles) > 1
            brakeFailureInCycles(end) = []; %remove the comma at the end
            %of string
            str{k} = 'Brake Check failed in cycle(s):';
            str{k+1} = brakeFailureInCycles;
            k= k+2;
        end
        if length(accuracyFailureInCycles) > 1
            accuracyFailureInCycles(end) = []; %remove the comma at the end
            %of string
            str{k} = 'Accuracy Check failed in cycle(s):';
            str{k+1} =accuracyFailureInCycles;
            k= k+2;
        end
        if length(frictionFailureInCycles) > 1
            frictionFailureInCycles(end) = []; %remove the comma at the end
            %of string
            str{k} = 'Friction Check failed in cycle(s):';
            str{k+1} = frictionFailureInCycles;
        end
    end

    function closeFigure(varargin)
        log_message(hgs,'HASS Script Closed');
        try
            isTestCanceled = true;
            mode(hgs,'zerogravity');
            close(hgs);
        catch
        end
        % close the window regardless of mode change
        closereq;
        %check if running from matlab environment or deployed to exit
        %properly
        if isdeployed
            disp('HASS is in deploy mode. Closing script.')
            exit;
        end
    end

end
%% END OF MAIN FUNCTION.

%% function to execute tension check
function [hass_result,pass,phase_lag, errStr] = tensioncheck(hgs,...
    hass_result,...
    fullDataFileName,...
    phase_lag,count) %#ok<INUSL>

% stop on error flag
global stop_on_error; %#ok<NUSED>

errStr = '';
% initialize pass flag to false
pass = false;
% call transmission check function
testHandle = TransmissionCheck(hgs);
try
    feval(get(testHandle.mainButtonInfo,'Callback'));
catch
    if ~ishandle(testHandle.figure)
        % test has been canceled exit
        evalin('caller', 'closeFigure');
        return;
    end
end

result_tension = [];

try
    % get results from UserData.
    % the results are set to the user data inside the transmission check function
    result_tension = get(testHandle.figure,'UserData');
    % normalize the phase lag by dividing it by nominal. The normalized value
    % is used for plotting.
catch
    %do nothing right now
end

if ~ishandle(testHandle.figure)
    evalin('caller', 'closeFigure');
    return
end

if ~isempty(result_tension)
    phase_ratio = result_tension{1}.phase_lag./result_tension{1}.phase_limit; %ratio
    for ii=1:length(result_tension{1}.phase_lag)
        if (result_tension{1}.phase_lag(ii) > result_tension{1}.phase_limit(ii))
            errStr = sprintf(['%s\tTransmission Check failed on joint %d: Phaselag %3.1fdeg ' ...
                '(limit %3.1fdeg)\n'], errStr, ii, result_tension{1}.phase_lag(ii)*180/pi, ...
                result_tension{1}.phase_limit(ii)*180/pi);
        end
    end
    
else
    result_tension{1}.result = 'ABORTED';
    dof = hgs.JE_DOF;
    phase_ratio = zeros(dof,1);
    errStr = sprintf('Transmission Check did not complete properly');
end

phase_lag(:,count) = phase_ratio; %ratio

% check for pass/fail
if ~strcmp(result_tension{1}.result,'FAIL')
    % if pass close test window
    if ishandle(testHandle.figure)
        close(testHandle.figure)
    end
    % and set pass flag to true
    pass = true;
else
    % close the figure anyways if
    % the stop_on_error flag is false
    if ~stop_on_error
        if ishandle(testHandle.figure)
            close(testHandle.figure);
        end
    end
end
if strcmp(result_tension{1}.result,'ABORTED')
    pass = false;
    % enable button so text is black, not gray which doesn't print
    set(guiHandles.mainButtonInfo,'enable','on');
    presentMakoResults(guiHandles,'FAILURE',...
        lasterr);
    log_results(hgs,guiHandles.scriptName,'FAIL',lasterr);

end
% save results to the hass_result structure
hass_result.tension{count} = result_tension;
save (fullDataFileName,'hass_result');
end

%% function to execute brake check
function [hass_result,pass, errStr] = brakecheck(hgs,...
    hass_result,...
    fullDataFileName,count)

% stop on error flag
global stop_on_error;

% initialize pass flag to false
pass = false;
% call brake check function
testHandle = brake_check(hgs,'Hass');
feval(get(testHandle.mainButtonInfo,'Callback'))
result_brakecheck = [];
if ~ishandle(testHandle.figure)
    evalin('caller', 'closeFigure');
    errStr = [];
    return;
end

try
    % get results from UserData.
    % the results are set to the user data inside the brake check function
    result_brakecheck = get(testHandle.figure,'UserData');
catch
    %do nothing right now
end

if any(hgs.ce_error_code>0) || result_brakecheck.results == -2
    errStr = lasterr;
    try
        %remove logs
        result_brakecheck = rmfield( result_brakecheck, 'resultString');
        
        % save results to the hass_result structure
        if isempty(hass_result.brakecheck) %first time data is saved to
            %brakecheck structure
            hass_result.brakecheck{count} = result_brakecheck;
        else
            hass_result.brakecheck{count} = result_brakecheck;
        end
    catch
        %do nothing
    end
    
    return;
end
    
if isempty(result_brakecheck)
    errStr = sprintf('\tBrake Check did not complete peoperly\n');
else
    % check for pass/fail
    % Note WARNING is acceptable change '>=' to '>0' if
    % you want to reject warning
    if all(result_brakecheck.posResult >= 0) && ...
            all(result_brakecheck.negResult >= 0) &&...
            all(result_brakecheck.releaseResult >= 0)
        %result_brakecheck is the 1x6 result vector of brake check. 1 is pass
        %and -1 fail. result_brakecheck{3} is positive direction and {4}
        %negative dir.
        
        % if pass close test window
        if ishandle(testHandle.figure)
            close(testHandle.figure);
        end
        % and set pass flag to true
        pass = true;
    else
        % close the figure anyways if
        % the stop_on_error flag is false
        if ~stop_on_error
            if ishandle(testHandle.figure)
                close(testHandle.figure);
            end
        end
    end
    errStr = '';
    %Generate log file error message only if there are brake check
    %errors (i.e. no error log for warnings)
    if result_brakecheck.results == -1
        for ii=1:length(result_brakecheck.resultString)
            errStr = sprintf('%s\t%s\n', errStr, result_brakecheck.resultString{ii});
        end
        if ~isempty(errStr) && strcmp(errStr(end),sprintf('\n'))
            errStr(end) = []; %remove new line at the end
        end
%     elseif result_brakecheck.results == -2
    
    end
    
    %remove logs
    result_brakecheck = rmfield( result_brakecheck, 'resultString');
    
    % save results to the hass_result structure
    if isempty(hass_result.brakecheck) %first time data is saved to
        %brakecheck structure
        hass_result.brakecheck{count} = result_brakecheck;
    else
        hass_result.brakecheck{count} = result_brakecheck;
    end
    save (fullDataFileName, 'hass_result')
end

end

%% function to execute friction check
function [hass_result,pass,friction_normalized, errStr] = frictioncheck(hgs,...
    hass_result,...
    fullDataFileName,...
    friction_normalized,count)

% stop on error flag
global stop_on_error;

% initialize pass flag to false
pass = false;
% call find friction function
testHandle = find_friction_constants(hgs,'test_friction');

feval(get(testHandle.mainButtonInfo,'Callback'))
pause(0.1);
if ~ishandle(testHandle.figure)
    % test has been canceled exit
    evalin('caller', 'closeFigure');
    errStr = [];
    friction_normalized = [];
    return;
end

result_friction = [];
try
    % get results from UserData
    result_friction = get(testHandle.figure,'UserData');
    
catch
    %do nothing right now
end
if result_friction.isPass == -1
    pass = -1;
end
if ~isempty(result_friction)
    errStr = result_friction.error_message;
    % we don't need to log error message so remove it from`
    % structure
    result_friction = rmfield(result_friction,'error_message');
    
    % normalize result by dividing it by the nominal friction
    friction_normalized(:,count) = (result_friction.friction_kinetic./ result_friction.kinetic_friction_limit)';
    if ~ishandle(testHandle.figure)
        evalin('caller', 'closeFigure');
        errStr = '';
        return;
    end
    if result_friction.isPass
        % if pass close test window
        if ishandle(testHandle.figure)
            close(testHandle.figure)
        end
        % and set pass flag to true
        pass = true;
    else
        % close the figure anyways if
        % the stop_on_error flag is false
        if ~stop_on_error
            if ishandle(testHandle.figure)
                close(testHandle.figure)
            end
        end
    end
    % save results to the hass_result structure
    if isempty(hass_result.friction) %first time data is saved to
        %brakecheck structure
        hass_result.friction{count} =  result_friction;
    else
        hass_result.friction{count} =  result_friction;
    end
    save (fullDataFileName, 'hass_result')
    
else
    errStr = sprintf('\tFriction Check did not complete properly\n');
end

end
%%
function appendToLogFile(fileName, logMsg)
[fid, message] = fopen(fileName, 'a');
if fid == -1
    errordlg(sprintf(['Cannot create/open log file %s  \n %s \n Exiting Hass ' ...
        'Test.'], fileName, message),'HASS Test');
    return;
end
fprintf(fid, '%s\n', logMsg);
fclose(fid);
end

%------------- END OF FILE ----------------