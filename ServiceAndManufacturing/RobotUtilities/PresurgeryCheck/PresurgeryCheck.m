function PresurgeryCheck(hgs,varargin)
%PreSurgeryCheck GUI to automate the pre surgery checks
%
% Syntax:
%   PreSurgeryCheck(hgs)
%       Start the GUI to do presurgery check.
%
% Description
%   This script will automate the presurgery checks
%

% $Author: dmoses $
% $Revision: 1706 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp 2007

defaultRobotConnection = false;

% Checks for arguments if any.  If none connect to the default robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% List of presurgery test scripts
presurgeryTestStructFieldNames={'Name','Function','InputArgs','Order','Prereq','Results','Followup','DefaultCheck','DebugHelp','timeDelay','ButtonClicks','Instruction'};

% Order must be in sequencial
PresurgeryTestStructParams={
    'Arm Status Check',        'ArmStatusCheck',        hgs, 1, [],      0, [],    true,  '',[1,1], 1, ''; ...
    'Home Robotic Arm',        'home_hgs',              hgs, 2, [1],     0, [],    true,  '',[2,3], 1, ' Prepare To Support Robotic Arm.'; ...
     'Combined Accuracy Check', 'combinedAccuracyCheck', hgs, 3, [1,2],   0, [],    true,  '',[2,5], 2, ' Take Robotic Arm to Surgical Position';...
     'Brake Check',             'brake_check',           hgs, 4, [1,2],   0, [],    true,  '',[2,3], 1, ' Remove Socket Array'; ...
     'Check Angle Discrepancy', 'CheckAngleDiscrepancy', hgs, 5, [1,2],   0, [],    true,  '',[1,1], 1, '';...
    }; %#ok<NBRAK>

% get warning gif file
warnImageFileName=fullfile('images','warning.png');
warningIconData=imread(warnImageFileName,'backgroundcolor',[0 1 0]);


% Convert the test list to a managable struct
presurgeryTestStruct = cell2struct(PresurgeryTestStructParams,presurgeryTestStructFieldNames,2);
presurgeryCheckCell = struct2cell(presurgeryTestStruct)';

numberOfTests=length(presurgeryTestStruct);


% setup the basic GUI
guiHandles = generateMakoGui('Presurgery Checks',[],hgs);
updateMainButtonInfo(guiHandles,'pushbutton',...
    'Click Here to Start Presurgery Checks',...
    @startPresurgeryTest);
set(guiHandles.figure,'CloseRequestFcn',@abortProcedure);


yHeightTotal=0.85;
ySpacing=0.05;
yHeight=yHeightTotal/numberOfTests-ySpacing;
cbTestHandles=[];
for i=1:numberOfTests %#ok<FXUP>
    position=[0.05,yHeightTotal-((i-1)*(yHeight+ySpacing)+ySpacing),0.85,yHeight];
    
    cbTestHandles(i)=...
        uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        'HorizontalAlignment','left',...
        'fontunits','normalized',...
        'fontSize',0.6,...
        'Units','normalized',...
        'BackgroundColor',[0.7 0.7 0.7],...
        'Enable','off',...
        'String',sprintf('          %s',presurgeryTestStruct(i).Name),...
        'Position',position);
    position=[0.05,yHeightTotal-((i-1)*(yHeight+ySpacing)+ySpacing),0.05,yHeight];
    
    warningHandles(i)=...
        uicontrol(guiHandles.uiPanel,...
        'Style','pushbutton',...
        'HorizontalAlignment','left',......
        'Units','normalized',...
        'Enable','inactive',...
        'Visible','off',...
        'Position',position,...
        'CData',warningIconData);
end
drawnow

%--------------------------------------------------------------------------
% internal function for the top level execution of arm software reset
%--------------------------------------------------------------------------
    function startPresurgeryTest(varargin)
        try
            % add a log entry to the log file
            log_message(hgs,'Pre Surgery Check started');
            
            %initialization
            failedCheckCount=0;
            presurgeryTestSuccessful=true;
            presurgeryCheckWarning=false;

            %execute presurgery test precedure
            selectedTestStruct=presurgeryTestStruct;
            numberOfSelectedTests=length(selectedTestStruct);
            
            % create a structure to store the results
            % remove spaces from names to make it valid field names
            for i=1:numberOfSelectedTests
                tempFieldNames = presurgeryCheckCell{i};
                resultsFieldNames{i} = tempFieldNames(tempFieldNames~=' ');
                resultsValue{i} = 'Not Performed';
            end
            
            for i=1:numberOfSelectedTests %#ok<FXUP>
                
                %show the next test to be run
                set(cbTestHandles(i),'Enable','on');
                % count down display
                timeDelayBetweenCheck=selectedTestStruct(i).timeDelay(1);
                for ii=1:timeDelayBetweenCheck
                    displayText=sprintf('%s starts in %d seconds...%s',...
                        selectedTestStruct(i).Name,timeDelayBetweenCheck-ii+1);
                    updateMainButtonInfo(guiHandles,'text',displayText);
                    pause(1);
                end
                
                %call the function
                [presurgeryTestStruct(selectedTestStruct(i).Order).Results,presurgeryMsg]= ...
                    PreSurgeryFunctionCall(selectedTestStruct(i));
                
                % If there is failed check, stop immediately and call the
                % followup checks if any
                if (presurgeryTestStruct(selectedTestStruct(i).Order).Results==-1)
                    
                    %check failed
                    set(cbTestHandles(i),'BackgroundColor','r')
                    
                    %fill in the failed check struct
                    failedCheckCount=failedCheckCount+1;
                    failedCheckStruct(failedCheckCount)=presurgeryTestStruct(selectedTestStruct(i).Order);
                    
                    % update result
                    presurgeryTestSuccessful=false;
                    resultsValue{i} = 'FAIL'; 
                    
                    %update tooltip
                    set(cbTestHandles(i),'TooltipString',presurgeryMsg);
                    
                    break;
                elseif presurgeryTestStruct(selectedTestStruct(i).Order).Results==1
                    %check is good
                    set(cbTestHandles(i),'BackgroundColor','g');
                    resultsValue{i} = 'PASS'; 
                    
                elseif presurgeryTestStruct(selectedTestStruct(i).Order).Results==2
                    %check is good
                    set(cbTestHandles(i),'BackgroundColor','g');
                    set(warningHandles(i),'Visible','on');
                    drawnow;
                    %set warning button to borderless
                    jObj = findjobj(warningHandles(i));
                    
                    % java obj may contain muliple objects, find with Border field
                    for ii = 1:length(jObj)
                        if(sum(strcmp('Border',fieldnames(jObj(ii)))))
                            jHandle=java(jObj(ii));
                            set(jHandle,'Border',[]);
                        end
                    end
                    resultsValue{i} = 'WARNING'; 
                    presurgeryCheckWarning=true;
                else %user cancel
                    set(cbTestHandles(i),'Value',0);
                end
                set(cbTestHandles(i),'TooltipString',presurgeryMsg);
            end
            
            resultsStruct = cell2struct(resultsValue,resultsFieldNames,2);
            
            % check test result
            if presurgeryTestSuccessful
                if(presurgeryCheckWarning)
                    presentMakoResults(guiHandles,'WARNING','Please see tests below for details');
                    % add a log entry to the log file
                    log_results(hgs,'Pre Surgery Check','WARNING',...
                        'Presurgery Check Warning, check individual test for details',...
                        resultsStruct);
                else
                    presentMakoResults(guiHandles,'SUCCESS');
                    % add a log entry to the log file
                    log_results(hgs,'Pre Surgery Check','PASS',...
                        'Presurgery Check passed',...
                        resultsStruct);
                end
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    {failedCheckStruct(:).Name,failedCheckStruct(:).DebugHelp});
                % add a log entry to the log file
                log_results(hgs,'Pre Surgery Check','FAIL',...
                    'Presurgery Check failure',...
                    resultsStruct);
            end
            
        catch
            try
                presentMakoResults(guiHandles,'FAILURE',...
                    lasterr);
                log_results(hgs,'Pre Surgery Check','FAIL',...
                    'Presurgery Check failure',...
                    lasterr);
            catch
                %do nothing
            end
            
        end
    end


%--------------------------------------------------------------------------
% internal function to check arm stutus
%--------------------------------------------------------------------------
    function [results,msg]=PreSurgeryFunctionCall(testStruct,varargin)
        try
            fName=testStruct.Function;
            fHandle=str2func(fName);
            myHandle=fHandle(testStruct.InputArgs);
            numberOfClicks=testStruct.ButtonClicks;
            timeDelayBetweenButtonClick=testStruct.timeDelay(2);
            
            for ii=1:numberOfClicks
                for iii=1:timeDelayBetweenButtonClick
                    myDisplayText=sprintf('%s starts in %d seconds...%s',...
                        testStruct.Name,timeDelayBetweenButtonClick+1-iii,...
                        testStruct.Instruction);
                    updateMainButtonInfo(myHandle,'Text',myDisplayText);
                    pause(1);
                end
                
                feval(get(myHandle.mainButtonInfo,'Callback'));
            end
            %get result
            guiData=get(myHandle.figure,'UserData');
            results=guiData.results;
            tempMsg=get(myHandle.mainButtonInfo,'String');
            msg='';
            if iscell(tempMsg)
                for ii=1:length(tempMsg)
                    msg=sprintf('%s %s',msg,tempMsg{ii});
                end
            else
                msg=tempMsg;
            end
            %take snap shot and close
            feval(myHandle.takeSnapShot);
            close(myHandle.figure);
        catch
            try
                results=-1;
                msg=lasterr;
                %try again take snap shot and close
                feval(myHandle.takeSnapShot);
                close(myHandle.figure);
            catch
                %do nothing
            end
        end
    end


%--------------------------------------------------------------------------
% internal function to cancel the procedure
%--------------------------------------------------------------------------
    function abortProcedure(varargin)
        
        % close the connection if it was established by this script
        if defaultRobotConnection
            log_message(hgs,'Pre Surgery Check script closed');
            close(hgs);
        end
        closereq;
    end
end

%------------- END OF FILE ----------------
