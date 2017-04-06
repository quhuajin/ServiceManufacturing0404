function FootSwitchTest(hgs)
% Script to test Foot Pedal Interface
%
% Syntax:
%    FootSwitchTest
%
% Notes:
%  prompts the user for the appropriate behavior of the foot pedal
%
%
%
% $Author: gjeanmarie $
% $Revision: 4318 $
% $Date: 2015-10-26 17:13:33 -0400 (Mon, 26 Oct 2015) $
% Copyright: MAKO Surgical corp (2013)
%

% If no argument is specified connect to the default robot
% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
    defaultRobotConnection = true;
end


testIndex = 0;
if nargin>1
    testIndex = index-1;
end

global numberToPress; %Times need to press the trigger 
global numberToRelease; %Times need to release the trigger 
global numberPressed; %Times already pressed 
global numberRleased; %Times already released 
numberToPress=10;
numberToRelease=10;
numberPressed=0;
numberRleased=0;


% Setup Script Identifiers for generic GUI
guiHandles = generateMakoGui('Foot Pedal Test','$Revision: 4318 $',hgs,true);

% Setup the main function
set(guiHandles.mainButtonInfo,'CallBack',@updateProcedureCallback);
set(guiHandles.figure,'CloseRequestFcn',@closeCallBackFcn);


% Thresholds
% GRAV_MODE_MOTION_LIMIT = 0.05; %m

% get arm hardware version
armHardwareVersion=hgs.ARM_HARDWARE_VERSION;

% Setup Test paramters.  These are a structure in the format
testParamFields = {'TestName','TestFunction'};


switch int32(armHardwareVersion * 10 + 0.05)
    case 20 % 2.0 RIO
        testParams = {...
            'Footpedal Check',@FootpedalCheck;...
            
            };
    case 21% 2.1 RIO
         testParams = {...
            'Footpedal Check',@FootpedalCheck;...
            
            };

    case 22 % 2.2 RIO
        testParams = {...
            'Footpedal Check',@FootpedalCheck;...

            };
    
    case 23 % 2.3 RIO
        testParams = {...
            'Footpedal Check',@FootpedalCheck;...

            };
        
%         add support for 3.0 hardware
   
    case 30 % 3.0 RIO
        testParams = {...
            'Footpedal Check',@FootpedalCheck;...

            };
    
    case 31 % 3.1 RIO
        testParams = {...
            'Footpedal Check',@FootpedalCheck;...

            };
        
        % Notify the user if hardware is not supported       
    otherwise
        presentMakoResults(guiHandles, 'FAILURE',...
        sprintf('Unsupported Robot version'));
    log_results(hgs,'Foot Pedal Test','FAILURE','Unsupported Hardware version');
    return;
end

testParamStruct = cell2struct(testParams,testParamFields,2);

% log message for scripts failure & warning
FailureText = 'Test Failed';
WarningText = 'Test warning';


% Generate the GUI
% Automatically setup the list to be tested.  Stack them in
% 3 columns

% determine number of columns and appropriate spacing for them
numRows = 16;

for i=1:length(testParamStruct) %#ok<FXUP>
    cellLocation = [mod(i-1,numRows),floor((i-1)/numRows)];
    boxPos = [0.05+0.5*cellLocation(2),...
        .01+0.05*(numRows-cellLocation(1)),0.4,0.04];

    testParamStruct(i).textHandle = uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        'String',testParamStruct(i).TestName,...
        'Units','normalized',...
        'Background','white',...
        'HorizontalAlignment','left',...
        'FontUnits','normalized',...
        'FontSize',0.5,...
        'Position',boxPos...
        ); 

    % preset the result to test not performed
    testParamStruct(i).results = -1;
    testParamStruct(i).testComplete = false;
end

% display CRISIS version number
uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        'String',sprintf('Arm Software version: %s',cell2mat(comm(hgs,'version_info'))),...
        'Units','normalized',...
        'Background',[.6 .6 .6],...
        'HorizontalAlignment','center',...
        'FontUnits','normalized',...
        'FontSize',0.5,...
        'Position',[ .05 .875 .9 .075]...
        ); 


%--------------------------------------------------------------------------
% Internal function to start test
%--------------------------------------------------------------------------
    function updateProcedureCallback(varargin)
        % preparre to start test
        updateMainButtonInfo(guiHandles,'pushbutton',...
            sprintf('Click to start %s test',testParamStruct(testIndex+1).TestName),...
            @ArmSoftwareTestProcedure);
        log_message(hgs,'Foot Pedal Test Started');
    end
%--------------------------------------------------------------------------
% Internal function to change test
%--------------------------------------------------------------------------
    function ArmSoftwareTestProcedure(varargin)
        testIndex = testIndex+1;
        %     Check if Robot is homed
        if (~hgs.homing_done)
         presentMakoResults(guiHandles, 'FAILURE', ...
            'Homing not done');
        log_message(hgs,sprintf('Foot Pedal Check FAILURE(homing not done)'));
        log_results(hgs,'Foot Pedal Test','FAILURE','Homing not done');
        return;
        end
        
        % change the color of the test running
        set(testParamStruct(testIndex).textHandle,...
            'fontweight','bold')
        % execute the function
        for i=1:3
            try
                if iscell(testParamStruct(testIndex).TestFunction)
                    testParamStruct(testIndex).results = feval(...
                        testParamStruct(testIndex).TestFunction{:});
                else
                    testParamStruct(testIndex).results = feval(...
                        testParamStruct(testIndex).TestFunction);
                end
            catch %#ok<CTCH>
                testParamStruct(testIndex).results = 0;
            end
            
            % break if passed before the end of the loop
            if testParamStruct(testIndex).results == 1
                break;
            else
                if i<3
                    % Retry message
                    if strcmp(questdlg(...
                        'Retry test?','Retry Question',...
                        'Yes','No',...
                        'Yes'),'No')
                        break;
                    end
                end
            end
        end
        testParamStruct(testIndex).testComplete = true;
    
        
        try 
        % check the results
        switch(testParamStruct(testIndex).results)
            case 1
                set(testParamStruct(testIndex).textHandle,...
                    'background','green');
            case -1
                set(testParamStruct(testIndex).textHandle,...
                    'background','yellow');
            otherwise
                set(testParamStruct(testIndex).textHandle,...
                    'background','red');
        end

        % Check if this was the last test.  Analyse results
        if testIndex<length(testParamStruct)
            updateProcedureCallback;
        else
            % Tests are complete analyse results
            if any([testParamStruct(:).results]==0)
                resultString = {};
                for i=1:length(testParamStruct) %#ok<FXUP>
                    % check if all tests were complete
                    if testParamStruct(i).results==0
                        resultString{end+1} = sprintf('%s failure',...
                            testParamStruct(i).TestName); %#ok<AGROW>
                    end
                end
                presentMakoResults(guiHandles,'FAILURE',...
                    resultString);
                log_results(hgs,'Foot Pedal Test','FAILURE',FailureText)

            elseif any([testParamStruct(:).results]<0)
                for i=1:length(testParamStruct) %#ok<FXUP>
                    % check if all tests were complete
                    resultString = {};
                    if ~testParamStruct(i).testComplete
                        resultString{end+1} = sprintf('%s not completed',...
                            testParamStruct(i).TestName); %#ok<AGROW>
                    elseif testParamStruct(i).result<0
                        resultString{end+1} = sprintf('%s completed with warning',...
                            testParamStruct(i).TestName); %#ok<AGROW>
                    end
                end
                presentMakoResults(guiHandles,'WARNING',...
                    resultString);
                log_results(hgs,'Foot Pedal Test','WARNING',WarningText)
            else
                presentMakoResults(guiHandles,'SUCCESS',...
                    '');
               log_results(hgs,'Foot Pedal Test','PASS','Foot Pedal Test Successful'); 
            end
        end
        log_message(hgs,'Foot Pedal Test Closed');
        catch 
            
        end 
        
    end

%--------------------------------------------------------------------------
% Internal function to check communication with Footpedal
%--------------------------------------------------------------------------
    function testResult = FootpedalCheck(varargin)
        % set robot to gravity mode

        % go to gravity mode
        mode(hgs,'zerogravity','ia_hold_enable',1);
        
        % Show a big pedal status
        pedalIndicator = uicontrol(guiHandles.extraPanel,...
            'Style','pushbutton',...
            'enable','off',...
            'Units','normalized',...
            'Position',[0.1 0.5 0.8 0.4],...
            'FontUnits','normalized',...
            'FontSize',0.35);
        
        pedalTestComplete = false;
    
        %------------------------------------------------------------------
        % Nested function to indicate test completion
        %------------------------------------------------------------------
        function FootPedalCheckComplete(varargin)
            pedalTestComplete = true;
            testResult=0;
        end
        
        % tell user to 
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Press and release the footpedal. Click to stop testing',@FootPedalCheckComplete);
        
        while (~pedalTestComplete)
            currentPedalStatus = hgs.footpedal(2);
            if ~currentPedalStatus
                set(pedalIndicator,...
                    'background','green',...
                    'String','Pressed',...
                    'Value',1);
                numberPressed=numberPressed+1;
                
            else
                set(pedalIndicator,...
                    'background',[0.7 0.7 0.7],...
                    'String','Released',...
                    'Value',0);
                numberRleased=numberRleased+1;
            end
            pause(0.01);
            
            if((numberPressed>numberToPress)&&(numberRleased>numberToRelease))
               pedalTestComplete=true;
               testResult=1;
               
            end;
        end
        
        %delete(pedalIndicator);
%         updateMainButtonInfo(guiHandles,'pushbutton',...
%             'Click here to finish pedal test',@FootPedalCheckComplete);
        % ask user to confirm if footpedal behaved as shown
%         if strcmp(questdlg(...
%                 'Did the footpedal behavior match the display',...
%                 'Test Result Question',...
%                 'Yes','No',...
%                 'Yes'),'No')
%             testResult = 0;
%             return
%         end
        
        % If i got here text succeeded 
%         testResult = 1;
    end
%--------------------------------------------------------------------------
% Internal function to close test
%--------------------------------------------------------------------------
    function closeCallBackFcn(varargin)
        return;
    end

end

%
%
% --------- END OF FILE ----------
