function CutterTest(hgs)
% CUTTERTEST Gui to help to check cutter control on the HgsRobot.
%
% Syntax:
%   CutterTest(hgs)
%       Starts the cutter test gui to change cutter state on the hgs robot
%       defined by the argument hgs.
%
% Notes:
%
% See also:
%   hgs_robot
%

%
% $Author: rzhou $
% $Revision: 1998 $
% $Date: 2009-12-21 11:42:35 -0500 (Mon, 21 Dec 2009) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
    defaultRobotConnection = true;
end


% Read to clear any leftover warning.
hgs.ce_error_msg(1);

% placeholder for voyager hgs
hgs_voy = [];


% define cutters
cutterTestFieldNames={'Name','Function','InputArgs','Order','Prereq','Results','Followup','DefaultCheck','DebugHelp','timeDelay','ButtonClicks','Instruction'};

% define different cutters according to the
rioHardwareVersion = hgs.ARM_HARDWARE_VERSION;
switch (int32(rioHardwareVersion * 10 + 0.05))
    case 20  % 2.0
        cutterList={
            'Anspach Burr', 'BurrStatusCheck', hgs, 1, [], 0, [], '', true, [1,1], 3, 'Start Burr Status Check.';...
            };
        Cutter = 'Anspach Burr';
    case {21,22} % 2.1 or 2.2
        cutterList={
            'Anspach', 'BurrStatusCheck',      hgs, 1, [], 0, [], true, '', [1,1,1], 3, 'Start Burr Status Check.'; ...
            'MicroAire',    'MicroAireStatusCheck', hgs, 2, [], 0, [], true, '', [1,1], 1, 'Start MicroAire Status Check.';...
            };
        Cutter = 'Anspach Burr';
    case {23,30} % 2.3 or 3.0
        cutterList={
            'Anspach Burr', 'BurrStatusCheck', hgs, 1, [], 0, [], true, '', [1,1,1], 3, 'Start Burr Status Check.'; ...
            'MICS',         'MICSStatusCheck', hgs_voy, 2, [], 0, [], true, '', [1,1], 2, 'Start MICS Status Check.'; ... 
            };
        Cutter = 'Anspach Burr and MICS';
    case {31} %3.1
         cutterList={
            'MICS',         'MICSStatusCheck', hgs_voy, 1, [], 0, [], true, '', [1,1], 2, 'Start MICS Status Check.';...
            };
        Cutter = 'MICS';
    otherwise
        % Generate the gui
        guiHandles = generateMakoGui(gravity_data.mbDisplayText,[],hgs);
        presentMakoResults(guiHandles,'FAILURE',...
            sprintf('Unsupported Robot version: V%2.1f',rioHardwareVersion));
        log_results(hgs,'Cutter Test','FAIL',...
            sprintf('Unsupported Robot version: V%2.1f',rioHardwareVersion));
        return;
        
end

% get warning gif file
warnImageFileName=fullfile('images','warning.png');
warningIconData=imread(warnImageFileName,'backgroundcolor',[0 1 0]);


cutterTestStruct=cell2struct(cutterList,cutterTestFieldNames,2);
cutterTestCell = struct2cell(cutterTestStruct)';

numberOfTests = length(cutterTestStruct);


% setup the basic GUI
guiHandles = generateMakoGui('Cutter Test',[],hgs);


%check homing is done
if(~hgs.homing_done)
    presentMakoResults(guiHandles,'FAILURE',...
        'Homing not done');
    log_results(hgs,'Cutter Test','FAIL',...
        sprintf('Cutter Check failed (homing not done) '));
    return
end



% Setup the main function
updateMainButtonInfo(guiHandles,'pushbutton',...
    'Click Here to Start Cutter Test',...
    @cutter_test_start);

%override the default close callback for clean exit.
set(guiHandles.figure,'CloseRequestFcn',@cutter_test_close);


yHeightTotal=0.85-.5;
ySpacing=0.05;
yHeight=yHeightTotal/numberOfTests-ySpacing;
cbTestHandles=[];
for i=1:numberOfTests %#ok<FXUP>
    position=[0.05,yHeightTotal-((i-1)*(yHeight+ySpacing)+ySpacing),0.85,yHeight/2];
    
    cbTestHandles(i)=...
        uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        'HorizontalAlignment','left',...
        'fontunits','normalized',...
        'fontSize',0.6,...
        'Units','normalized',...
        'BackgroundColor',[0.7 0.7 0.7],...
        'Enable','off',...
        'String',sprintf('          %s (%s)',cutterTestStruct(i).Name,cutterTestStruct(i).Function),...
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

position=[0.05,yHeightTotal-((i-1)*(yHeight+ySpacing)+ySpacing),0.85,yHeight/2];
TipHandles=...
        uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        'HorizontalAlignment','left',...
        'fontunits','normalized',...
        'fontSize',0.35,...
        'Units','normalized',...
        'BackgroundColor',[0.0 0.5 0.5],...
        'String',sprintf('%s%s%s',...
        'NOTE: Make Sure to Check Irrigation Pump is rotating while ',Cutter,' is running.'),...
        'Position',position+[0 0.4 0.0 0.0]);
    
 drawnow;

%% --------------------------------------------------------------------------
% internal function for the top level execution of arm software reset
%--------------------------------------------------------------------------
    function cutter_test_start(varargin)
        try
            % add a log entry to the log file
            log_message(hgs,'Cutter Test started');
            
            %initialization
            failedTestCount=0;
            cutterTestSuccessful=true;
            cutterCheckWarning=false;

            %execute presurgery test precedure
            selectedTestStruct=cutterTestStruct;
            numberOfSelectedTests=length(selectedTestStruct);
            
            % create a structure to store the results
            % remove spaces from names to make it valid field names
            for i=1:numberOfSelectedTests
                tempFieldNames = cutterTestCell{i};
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
                
%                 %call the function
                if strcmpi(cutterTestStruct(selectedTestStruct(i).Order).Name,'MICS')
                    setup_network('STATIC_VOYAGER');
                    wb_close = waitbar(0,'Updating IP address to static voyager 10.1.1.150. Please wait...');
                    for iwait_close = 1:50
                        pause(.1);
                        waitbar(iwait_close/50,wb_close,'Updating IP address to static voyager 10.1.1.150. Please wait...');
                    end
                    close(wb_close);
                    
                    hgs_voy = hgs_robot('10.1.1.178');
                    selectedTestStruct(i).InputArgs = hgs_voy;
                end
                
                % CALLS THE FUNCTION!!
                [cutterTestStruct(selectedTestStruct(i).Order).Results,cutterTestMsg{i}]= ...
                    CutterTestFunctionCall(selectedTestStruct(i));
                
                reconnect(hgs);
                
                % If there is failed check, stop immediately and call the
                % followup checks if any
                if (cutterTestStruct(selectedTestStruct(i).Order).Results==-1)
                    
                    %check failed
                    set(cbTestHandles(i),'BackgroundColor','r')
                    
                    %fill in the failed check struct
                    failedTestCount=failedTestCount+1;
                    failedCheckStruct(failedTestCount)=cutterTestStruct(selectedTestStruct(i).Order);
                    
                    % update result
                    cutterTestSuccessful=false;
                    resultsValue{i} = 'FAIL'; 
                    
                    %update tooltip
                    set(cbTestHandles(i),'TooltipString',cutterTestMsg{i});
                    
                elseif cutterTestStruct(selectedTestStruct(i).Order).Results==1
                    %check is good
                    set(cbTestHandles(i),'BackgroundColor','g');
                    resultsValue{i} = 'PASS'; 
                    
                elseif cutterTestStruct(selectedTestStruct(i).Order).Results==2
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
                    cutterCheckWarning=true;
                else %user cancel
                    set(cbTestHandles(i),'Value',0);
                end
                set(cbTestHandles(i),'TooltipString',cutterTestMsg{i});
            end
            
            resultsStruct = cell2struct(resultsValue,resultsFieldNames,2);
            set(TipHandles,'Visible','OFF');
            log_msg = '';
            for k = 1 : length(cutterTestMsg)
                if k == 1
                    log_msg = [cutterTestMsg{k}];
                else
                    log_msg = [log_msg '; ' cutterTestMsg{k}];
                end
            end
            % check test result
            if cutterTestSuccessful
                if(cutterCheckWarning)
                    presentMakoResults(guiHandles,'WARNING',log_msg);
                    % add a log entry to the log file
                    log_results(hgs,'Cutter Test','WARNING',...
                        log_msg,...
                        resultsStruct);
                else
                    presentMakoResults(guiHandles,'SUCCESS');
                    % add a log entry to the log file
                    log_results(hgs,'Cutter Test','PASS',...
                        'Cutter Test passed',...
                        resultsStruct);
                end
            else
                presentMakoResults(guiHandles,'FAILURE',log_msg);
                % add a log entry to the log file
                log_results(hgs,'Cutter Test','FAIL',...
                    log_msg,...
                    resultsStruct);
            end
            
        catch
            try
                presentMakoResults(guiHandles,'FAILURE',...
                    lasterr);
                log_results(hgs,'Cutter Test','FAIL',lasterr);
                
                if strcmpi(cutterTestStruct(selectedTestStruct(i).Order).name,'MICS')
                    setup_network('STATIC');
                    wb_close = waitbar(0,'Updating IP address to static 172.16.16.150. Please wait...');
                    for iwait_close = 1:50
                        pause(.1);
                        waitbar(iwait_close/50,wb_close,'Updating IP address to static 172.16.16.150. Please wait...');
                    end
                    close(wb_close);
                end
            catch
                %do nothing
            end
            
        end
    end






%% --------------------------------------------------------------------------
% internal function to check arm status
%--------------------------------------------------------------------------
    function [results,msg]=CutterTestFunctionCall(testStruct,varargin)
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
                    if ~isempty(tempMsg{ii})
                        if ii ==1 && length(tempMsg)>1
                            msg = sprintf('%s::',tempMsg{ii});
                        elseif ii <= 2
                            msg=sprintf('%s %s',msg,tempMsg{ii});
                        else
                            msg=sprintf('%s, %s',msg,tempMsg{ii});
                        end
                    end
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


%% --------------------------------------------------------------------------
% internal function to perform irrigation check
%--------------------------------------------------------------------------
    function guiHandles=IrrigationCheck(hgs,varargin)
        
        log_message(hgs,sprintf(['Irrigation Check Started ']));
        
        
        comm(hgs,'peripheral_comm',peripheral_drip_switch);
                            
                            % Ask user to perform action
                            dripTurning=questdlg(...
                                'While holding down on the burr hand switch, is drip motor turning?',...
                                'Drip Test','Yes','No','Yes');
                            switch(dripTurning)
                                case 'Yes'
                                    %pass
                                    set(dripPushButton(1),'String',...
                                        'Hand: cutter ON, drip ON.',...
                                        'Visible','ON',...
                                        'BackgroundColor','Green');
                                    enableTestPass=true;
                                case 'No'
                                    %fail
                                    failureMsg=sprintf('%s','Hand: cutter ON, drip OFF.');
                                    set(dripPushButton(1),'String',...
                                        failureMsg,...
                                        'Visible','ON',...
                                        'BackgroundColor','Red');
                                    enableTestPass=false;
                                    return;
                            end
    end
        
        
        

%% --------------------------------------------------------------------------
% internal function to cancel the procedure
%--------------------------------------------------------------------------
    function cutter_test_close(varargin)
        
        if strcmp(hgs.host(1:end-4), '10.1.1')
            setup_network('STATIC');
            wb_close = waitbar(0,'Updating IP address to static 172.16.16.150. Please wait...');
            for iwait_close = 1:50
                pause(.1);
                waitbar(iwait_close/50,wb_close,'Updating IP address to static 172.16.16.150. Please wait...');
            end
            close(wb_close);
        end
        log_message(hgs,'Cutter Test script closed');
        % close the connection if it was established by this script
        if defaultRobotConnection
            close(hgs);
        end
        
        
        closereq;
    end
end

%------------- END OF FILE ----------------