function guiHandles = MicroAireStatusCheck(hgs,varargin)
% CUTTER_TEST Gui to help to check cutter control on the HgsRobot.
%
% Syntax:
%   cutter_test(hgs)
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
end

% Check client based on server ip.
clientType = 'VOYAGER';
if(~strcmp(hgs.host,'172.16.16.178'))
    clientType = 'SERVICE';
end
%init a mics object to null
mics = [];

% Read to clear any leftover warning.
hgs.ce_error_msg(1);

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% define cutters
cutterListFieldNames={'Name','Cutter','HasHandControl','HasFootControl','HasDripControl','NeedReset','TestResult','EEType','ClientType'};

cutterList={'MicroAire Status Check', 'MicroAire', 1, 0, 0, 0, 0, 2, 0;};
 
cutterListStruct=cell2struct(cutterList,cutterListFieldNames,2);



%% Generic GUI for Service Scripts
guiHandles = generateMakoGui(cutterListStruct.Name,[],hgs);

% Setup the main function
set(guiHandles.mainButtonInfo,'CallBack',@cutter_test_start);

%override the default close callback for clean exit.
set(guiHandles.figure,'closeRequestFcn',@MicroAireCheck_close);

% Setup userdata structure to pass data between guis if need be
userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

%initialize variables
isCutterTestCanceled=false;
timerObj=timer;
numberOfCutters=length(cutterListStruct);
cutterTestSucceed=zeros(1,numberOfCutters);
cutter_skipped = 2;

%common properties

commonProperties =struct(...
    'Style','text',...
    'Units','Normalized',...
    'FontUnits','normalized',...
    'FontSize',0.25,...
    'FontWeight','bold',...
    'FontName','FixedWidth',...
    'HorizontalAlignment','left',...
    'Enable','Inactive');

%two push buttons for cutter disable test,
%first one is hand control, second one is foot control
xMin = 0.05;
xRange = 0.9;
yMin = 0.7;
yRange = 0.2;
spacing=0.02;

columns=2;

for i=1:columns
    boxPosition = [xMin+(xRange+spacing)*(i-1)/columns,...
        yMin,...
        xRange/columns-spacing,...
        yRange];
    disablePushButton(i) = uicontrol(guiHandles.uiPanel,...
        commonProperties,...
        'Position',boxPosition,...
        'Visible','OFF'...
        ); %#ok<AGROW>
end

%two push buttons for cutter enable test
%first one is hand control, second one is foot control
yMin = 0.4;
for i=1:columns
    boxPosition = [xMin+(xRange+spacing)*(i-1)/columns,...
        yMin,...
        xRange/columns-spacing,...
        yRange];
    enablePushButton(i) = uicontrol(guiHandles.uiPanel,...
        commonProperties,...
        'Position',boxPosition,...
        'Visible','OFF'...
        ); %#ok<AGROW>
end

%two push buttons for drip status when cutter is enabled
%first one is hand control, second one is foot control
yMin = 0.1;

for i=1:columns
    boxPosition = [xMin+(xRange+spacing)*(i-1)/columns,...
        yMin,...
        xRange/columns-spacing,...
        yRange];
    dripPushButton(i) = uicontrol(guiHandles.uiPanel,...
        commonProperties,...
        'Position',boxPosition,...
        'Visible','OFF'...
        ); %#ok<AGROW>
end

% push buttons for cutter results
yMin = 0.4;
for i=1:columns %#ok<*FXUP>
    boxPosition = [xMin+(xRange+spacing)*(i-1)/columns,...
        yMin,...
        xRange/columns-spacing,...
        yRange];
    resultPushButton(i) = uicontrol(guiHandles.uiPanel,...
        commonProperties,...
        'Position',boxPosition,...
        'Visible','OFF'...
        ); %#ok<AGROW>
end

%%
%start cutter test call back
    function cutter_test_start(varargin)
        %init failure and skip message
        failureMsg = [];
        skipMsg = [];

        try
            %check if cutter is configured
            peripheralData=commDataPair(hgs,'get_peripheral_state');
            
            if(~peripheralData.cutter_configured)
                presentMakoResults(guiHandles,'FAILURE','Cutter is not configured');
                return;
            end
            
            %Create a timer object to avoid watchdog error
            timerObj=timer('Period',0.05,'TimerFcn',@watchdogKeepAliveFcn,...
                'ExecutionMode','fixedRate');
            start(timerObj);

            %get into the routine where user has to press the
            %flashing green button
            robotFrontPanelEnable(hgs,guiHandles);

            %create ans start a haptic cube
            create_haptic_cube();

            for i=1:numberOfCutters %#ok<FXUP>
                %update script test name and gui buttons
                guiHandles.scpritName=[guiHandles.scriptName,'_',cutterListStruct(i).Name];
                
                for j=1:2
                    set(enablePushButton(j),'Visible','OFF');
                    set(disablePushButton(j),'Visible','OFF');
                    set(dripPushButton(j),'Visible','OFF');
                end
                drawnow;

                if(cutterListStruct(i).NeedReset)
                    %start the cutter test
                    updateMainButtonInfo(guiHandles,'Text',[cutterListStruct(i).Cutter,' power off and back on']);
                    %first test RESET
                    %reset the anspach controller, there is no pass/fail check for
                    %reset, if it fails, the subsequest test will fail.
                    comm(hgs,'burr','POWER_OFF');
                    pause(1);
                    %power on the anspach controller by sending ENABLE command,
                    %this will not enable the cutter, only to turn on the power on
                    %anspach
                    comm(hgs,'burr','DISABLE');
                    pause(5);
                end

                %update the main button
                displayText=sprintf('%s',cutterListStruct(i).Name);
                updateMainButtonInfo(guiHandles,'Text',displayText);
                
                %check type of cutter
                switch cutterListStruct(i).EEType
                    case 1
                        comm(hgs,'set_gravity_constants','KNEE');                        
                    case 2
                        comm(hgs,'burr','DISABLE');
                        comm(hgs,'set_gravity_constants','KNEE');  
                        pause(3);
                    case 3
                        comm(hgs,'burr','DISABLE');
                        comm(hgs,'set_gravity_constants','KNEE');
                        pause(3);
                end              
                %ask user to select cutter test
                testSelected=questdlg(...
                    ['Do you want proceed with ',cutterListStruct(i).Name, '?'],...
                    [cutterListStruct(i).Name],'Yes','No','Yes');
                
                switch(testSelected)
                    case 'No'
                        cutterTestSucceed(i)= cutter_skipped;
                        continue;
                    case 'Yes'
                    case ''
                end            

                % first, disable test
                [cutterTestSucceed(i),failureMsg]=cutter_disable_test(i);

                %lastly,only test cutter enable if disable succeeded.
                if(cutterTestSucceed(i))
                    [cutterTestSucceed(i),failureMsg]=cutter_enable_test(i);
                end

                % save gui before the next cutter tool test
                if(cutterTestSucceed(i))
                    %check if there is warning
                    statusMsg=hgs.ce_error_msg(1);
                    if(strcmp(statusMsg,'WARNING CUTTING SYSTEM STATUS MISMATCH'))
                        failureMsg=statusMsg{1};
                        %save the screenshot first
                        updateMainButtonInfo(guiHandles,...
                            'Text',sprintf('%s Failed<%s>', cutterListStruct(i).Name, failureMsg));
                        set(guiHandles.mainButtonInfo,'BackGroundColor','red');
                        cutterTestSucceed(i)=false;
                    else
                        %save the screenshot first
                        updateMainButtonInfo(guiHandles,...
                            'Text',sprintf('%s Suceeded', cutterListStruct(i).Name));
                        set(guiHandles.mainButtonInfo,'BackGroundColor','green');
                    end
                else
                    %save the screenshot first
                    updateMainButtonInfo(guiHandles,...
                        'Text',sprintf('%s Failed <%s>',cutterListStruct(i).Name,failureMsg));
                    set(guiHandles.mainButtonInfo,'BackGroundColor','red');
                end
                
                % save screen shot
                pause(1);
                feval(guiHandles.takeSnapShot,[ cutterListStruct(i).Name, ' Test']);
                
            end
        catch ME
            %error occured and cutter state check failed
            failureMsg = ME.message;
            if(~isCutterTestCanceled)
                updateMainButtonInfo(guiHandles,'Text',{failureMsg,cutterListStruct(i).Name});

            else
                closereq;
            end
            cutterTestSucceed(i)=false;
        end


        %turn watchdog off and stop the timer
        comm(hgs,'watchdog','OFF');
        stop_clear_timer(timerObj);
        %delete mics object
        if(isa(mics,'mako_mics'))
            delete(mics);
        end

        %check and present result
        if(~isCutterTestCanceled)
            %hide unwanted buttons
            for j=1:2
                    set(enablePushButton(j),'Visible','OFF');
                    set(disablePushButton(j),'Visible','OFF');
                    set(dripPushButton(j),'Visible','OFF');
            end
            %update individual cutter fail/pass/skip result first
            for j=1:numberOfCutters
                switch(cutterTestSucceed(j))
                    case true
                        set(resultPushButton(j),'Visible','ON',...
                            'String',[cutterListStruct(j).Name,'  Successful'],...
                            'BackgroundColor','green');
                    case cutter_skipped
                        skipMsg = [skipMsg cutterListStruct(j).Name '  Skipped. '];
                        set(resultPushButton(j),'Visible','ON',...
                            'String',[cutterListStruct(j).Name '  Skipped'],...
                            'BackgroundColor','red');
                        
                    case false
                        %                         failureMsg = [failureMsg cutterListStruct(j).Name '  Failed. '];
                        set(resultPushButton(j),'visible','ON',...
                            'String',[cutterListStruct(j).Name,'  Failed'],...
                            'BackgroundColor','red');
                end
            end
            drawnow;                
            
            if min(rem(cutterTestSucceed,2)) == 1
                userDataStruct.results=1
                presentMakoResults(guiHandles,'SUCCESS');
            else
                userDataStruct.results=-1;
                presentMakoResults(guiHandles,'FAILURE',{failureMsg; skipMsg});
            end
            try
                set(guiHandles.figure,'UserData',userDataStruct);
            catch
            end
        end

        %change to default gravity constants
        if(strcmp(clientType,'SERVICE'))
            %change to calibration EE gravity constants
            comm(hgs,'set_gravity_constants','KNEE');            
            %set to zerogravity mode
            reset(hgs);
        else
            %change to zerogravity with hold
            mode(hgs,'zerogravity');
        end

    end

%%
%Function to test cutter when it is disabled, on failure, the test will quit
%and error will be retruned, cutter and drip are checked together.
    function [disableTestPass,failureMsg]=cutter_disable_test(cutterNo)

        %initilalize the test result
        disableTestPass=false;
        failureMsg='';

        %disable the cutter, such that cutter can not be turned on
        comm(hgs,'burr','DISABLE');
        comm(hgs,'watchdog','OFF');
        
        %update the main button
        updateMainButtonInfo(guiHandles,'Text',[cutterListStruct(cutterNo).Cutter,' is DISABLED']);
        
        % Ask user to perform action
        if((cutterListStruct(cutterNo).ClientType == 1) && strcmp(cutterListStruct(cutterNo).Name,'MICS'))
                
            % Ask user to perform action
            updateMainButtonInfo(guiHandles,'text',...
                {'Holding down hand switch for about 10 seconds, data collecting...'});
            drawnow;
            %create a mics object
            mics = mako_mics();
            mics.number_of_samples = 500; % which takes about 10 seconds
            mics_data = mics.stream_data;
            motor_current = mics_data(:,1);
            bus_voltage = mics_data(:,2);
            speed = mics_data(:,3); %#ok<NASGU>
            speedCmd = mics_data(:,4); 
            temperature = mics_data(:,5);
            irrigation_voltage = mics_data(:,6);
            %clear the mics object
            delete(mics);
            mics =[];
            %check for potential errors,
            if(motor_current > 0.2)
                disableTestPass = false;
                failureMsg = sprintf('MICS disable test failed, motor current: %f.',max(motor_current));
                return;
            end
            
            if(mean(bus_voltage) < 40)
                disableTestPass = false;
                failureMsg = sprintf('MICS disable test failed, bus voltage: %f.',mean(bus_voltage));
                return;
            end
            
            if(irrigation_voltage > 0.5)
                disableTestPass = false;
                failureMsg = sprintf('MICS disable test failed, irrigation voltage: %f.',max(irrigation_voltage));
                return;
            end
            
            if(speed > 0)
                disableTestPass = false;
                failureMsg = sprintf('MICS disable test failed, commanded speed: %f.',max(speedCmd));
                return;
            end
            
            if(abs(28 - mean(temperature)) > 5)
                disableTestPass = false;
                failureMsg = sprintf('MICS disable test failed, mean temperature: %f.',mean(temperature));
                return;
            end
            
            %at this point, test is successful
            disableTestPass = true;
            
        else
            
            if(cutterListStruct(cutterNo).HasHandControl)
                %verify if cutter can be turned on, drip is not checked
                %use hand switch
                %change to hand control
                if(strcmp(cutterListStruct(cutterNo).Name,'Anspach Burr'))
                    comm(hgs,'peripheral_comm',peripheral_hand);
                end
                
                % Ask user to perform action
                updateMainButtonInfo(guiHandles,'text',...
                    {'Holding down hand switch',['Check if ',cutterListStruct(cutterNo).Cutter,' motor is turning?']});
                cutterTurning=questdlg(...
                    ['Holding down hand switch, is ',cutterListStruct(cutterNo).Cutter, ' motor turning?'],...
                    [cutterListStruct(cutterNo).Name],'Yes','No','No');
                
                switch(cutterTurning)
                    case 'No'
                        %pass
                        set(disablePushButton(1),'String',...
                            'Hand: cutter DISABLED, motor OFF.',...
                            'Visible','ON',...
                            'BackgroundColor','Green');
                    case 'Yes'
                        %fail
                        failureMsg=sprintf(...
                            '%s','Hand: cutter DISABLED, motor ON.');
                        set(disablePushButton(1),...
                            'String',failureMsg,...
                            'Visible','ON',...
                            'BackgroundColor','Red');
                        return;
                    case ''
                        failureMsg=sprintf(...
                            '%s','checkcanceled');
                        return;
                end
            end
            
            if(cutterListStruct(cutterNo).HasFootControl)
                %use foot switch
                %change to foot control
                if(strcmp(cutterListStruct(cutterNo).Name,'Anspach Burr'))
                    comm(hgs,'peripheral_comm',peripheral_foot);
                end
                
                % Ask user to perform action
                updateMainButtonInfo(guiHandles,'text',...
                    {'Stepping down foot switch',['Check if ',cutterListStruct(cutterNo).Cutter,' motor is turning?']});
                cutterTurning=questdlg(...
                    ['Stepping down foot switch, is ',cutterListStruct(cutterNo).Cutter,' motor turning?'],...
                    [cutterListStruct(cutterNo).Name],'Yes','No','No');
                switch(cutterTurning)
                    case 'No'
                        %pass
                        set(disablePushButton(2),'String',...
                            'Foot: cutter DISABLED, motor OFF.',...
                            'Visible','ON',...
                            'BackgroundColor','Green');
                        disableTestPass=true;
                    case 'Yes'
                        %fail
                        failureMsg=sprintf(...
                            '%s','Foot: cutter DISABLED, motor ON.');
                        set(disablePushButton(2),...
                            'String',failureMsg,...
                            'Visible','ON',...
                            'BackgroundColor','Red');
                        return;
                    case ''
                        failureMsg=sprintf(...
                            '%s','check canceled');
                        return;
                end
            else
                disableTestPass=true;
            end
        end
    end

%%
%function to test cutter when it is enabled,on failure, the test will quit
%and error will be retruned.
    function [enableTestPass,failureMsg]=cutter_enable_test(cutterNo)
        %initilalize the test result
        enableTestPass=false;
        failureMsg='';
        
        %enable the cutter,such that cutter can be turned on.
        comm(hgs,'watchdog','ON');
        comm(hgs,'burr','ENABLE');


        if(cutterListStruct(cutterNo).HasHandControl)
            %verify using hand switch
            %change to hand control if needed
            if(strcmp(cutterListStruct(cutterNo).Name,'Anspach Burr'))
                comm(hgs,'peripheral_comm',peripheral_hand);
            end

            % Ask user to perform action
            if(strcmp(cutterListStruct(cutterNo).Name,'MICS') && (cutterListStruct(cutterNo).ClientType == 1 ))                
                % Ask user to hold down hand trigger
                for j = 1 : 5
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Holding down hand switch, data collecting start in %d seconds...',5 - j));                    
                    drawnow;
                    pause(1);
                end
                updateMainButtonInfo(guiHandles,'text',...
                    {'Continue holding down hand switch for about 10 seconds, data collecting...'});
                drawnow;
                
                %create a mics object                
                mics = mako_mics();
                
                %collect data
                mics.number_of_samples = 500; % which takes about 10 seconds
                mics_data = mics.stream_data;                
                motor_current = mics_data(:,1);
                bus_voltage = mics_data(:,2);
                speed = mics_data(:,3);
                speedCmd = mics_data(:,4); %#ok<NASGU>
                temperature = mics_data(:,5);
                irrigation_voltage = mics_data(:,6);
                
                %get the fault as well
                faultBuffer = mics.fault;
                
                %clear the object.
                delete(mics);                
                mics = [];
                
                %check for fault
                faultIndices = find(faultBuffer > 0);
                if(~isempty(faultIndices))
                    logIndex = log2(double(faultBuffer(faultIndices(1)))) + 1;
                    failureMsg=sprintf(...
                        'MICS enable test failed <%s>',mics.fault_message{logIndex});
                    enableTestPass=false;
                    return;
                end
                
                %check for potential errors,
                if(mean(motor_current) > 1.0)
                    enableTestPass = false;  
                    failureMsg = sprintf('MICS enable test failed, motor current: %f.',...
                        mean(motor_current));
                    return;
                end
                
                if(mean(bus_voltage) < 40)
                    enableTestPass = false;  
                    failureMsg = sprintf(...
                        'MICS enable test failed, bus voltage: %f.',...
                        mean(bus_voltage));
                    return;
                end
                
                if(abs(mean(irrigation_voltage) - 11) > 3)
                    enableTestPass = false;  
                    failureMsg = sprintf(...
                        'MICS enable test failed, irrigation voltage: %f.',...
                        mean(irrigation_voltage));
                    return;
                end
                
                if(abs(12000 - mean(speed)) > 1000)
                    enableTestPass = false;  
                    failureMsg = sprintf('MICS test failed, mean speed: %f.',mean(speed));
                    return;
                end
                
                if(abs(28 - mean(temperature)) > 5)
                    enableTestPass = false;  
                    failureMsg = sprintf(...
                        'MICS enable test failed, mean temperature: %f.',mean(temperature));
                    return;
                end
                
                %at this point, test is successful              
                enableTestPass = true;               
            else
                updateMainButtonInfo(guiHandles,'text',...
                    {'Holding down hand switch',['Check if ',...
                    cutterListStruct(cutterNo).Cutter,' motor is turning?']});
                
                cutterTurning=questdlg(...
                    ['Holding down hand switch, is ',cutterListStruct(cutterNo).Cutter,' motor turning?'],...
                    [cutterListStruct(cutterNo).Name, ' Test'],'Yes','No','Yes');
                switch(cutterTurning)
                    case 'Yes'
                        set(enablePushButton(1),'String',...
                            'Hand: cutter ENABLED, motor ON.',...
                            'Visible','ON',...
                            'BackgroundColor','Green');
                        
                        if(cutterListStruct(cutterNo).HasDripControl)
                            
                            %check drip motor
                            %turn on the drip
                            if(strcmp(cutterListStruct(cutterNo).Name,'Anspach Burr'))
                                comm(hgs,'peripheral_comm',peripheral_drip_switch);
                            end
                            % Ask user to perform action
                            updateMainButtonInfo(guiHandles,'text',...
                                {'Holding down hand switch','is drip motor turning?'});
                            dripTurning=questdlg(...
                                'Keep holding down hand switch,is drip motor turning?',...
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
                                case ''
                                    failureMsg=sprintf(...
                                        '%s','check canceled');
                                    enableTestPass=false;
                                    return;
                            end
                        else
                            enableTestPass=true;
                        end
                    case 'No'
                        %fail
                        failureMsg=sprintf('%s','Hand: cutter ENABLED, motor OFF.');
                        set(enablePushButton(1),'String',...
                            failureMsg,...
                            'Visible','ON',...
                            'BackgroundColor','Red');
                        enableTestPass=false;
                        return;
                    case ''
                        failureMsg=sprintf(...
                            '%s','check canceled');
                        enableTestPass=false;
                        return;
                end
            end
        end

        if(cutterListStruct(cutterNo).HasFootControl)
            %verify using foot switch
            %change to foot control
            if(cutterListStruct(cutterNo).HasHandControl)
                updateMainButtonInfo(guiHandles,'text',...
                    {'Release the hand switch and hit OK button'});
                questdlg('Release hand switch',...
                    'Release the hand switch and hit OK button','OK','OK');
            end
            if(strcmp(cutterListStruct(cutterNo).Name,'Anspach Burr'))
                comm(hgs,'peripheral_comm',peripheral_foot);
            end

            % Ask user to perform action and respond
            updateMainButtonInfo(guiHandles,'text',...
                {'Stepping down foot switch',['Check if ',cutterListStruct(cutterNo).Cutter,' motor is turning?']});

            cutterTurning=questdlg(...
                ['Stepping down foot switch, is ',cutterListStruct(cutterNo).Cutter,' motor turning?'],...
                [cutterListStruct(cutterNo).Name,'Test'],'Yes','No','Yes');
            switch(cutterTurning)
                case 'Yes'
                    set(enablePushButton(2),'String',...
                        'Foot: cutter ENABLED, motors ON.',...
                        'Visible','ON',...
                        'BackgroundColor','Green');
                    if(cutterListStruct(cutterNo).HasDripControl)

                        %check drip motor
                        % Ask user to perform action
                        updateMainButtonInfo(guiHandles,'text',...
                            {'Keep stepping down foot switch','is drip motor turning?'});

                        dripTurning=questdlg(...
                            'Keep stepping down foot switch,is drip motor turning?',...
                            'Drip Test','Yes','No','Yes');
                        switch(dripTurning)
                            case 'Yes'
                                %pass
                                set(dripPushButton(2),'String',...
                                    'Foot: cutter ON, drip ON.',...
                                    'Visible','ON',...
                                    'BackgroundColor','Green');
                                enableTestPass=true;
                            case 'No'
                                %fail
                                failureMsg=sprintf('%s','Foot: cutter ON, drip OFF.');
                                set(dripPushButton(2),'String',...
                                    failureMsg,...
                                    'Visible','ON',...
                                    'BackgroundColor','Red');
                                enableTestPass=false;
                                return;
                            case ''
                                failureMsg=sprintf(...
                                    '%s','check canceled');
                                return;
                        end
                    else
                        enableTestPass=true;
                    end
                case 'No'
                    %fail
                    failureMsg=sprintf('%s','Foot: cutter ENABLED, cutter motor OFF.');
                    set(enablePushButton(2),'String',...
                        failureMsg,...
                        'Visible','ON',...
                        'BackgroundColor','Red');
                    enableTestPass=false;
                    return;
                case ''
                    failureMsg=sprintf(...
                        '%s','check canceled');
                    return;
            end
        else
            enableTestPass=true;
        end
    end

%--------------------------------------------------------------------------
%   Internal function to keep the watchdog alive
%--------------------------------------------------------------------------
    function watchdogKeepAliveFcn(varargin)
        % do a basic query to keep the watchdog happy
        try
            comm(hgs,'ping_control_exec');
        catch %#ok<CTCH>
            %do nothing
        end
    end
%--------------------------------------------------------------------------
%   Internal function to close the test
%--------------------------------------------------------------------------
    function MicroAireCheck_close(varargin)
        %turn off watchdog
        comm(hgs,'watchdog','OFF');
        %set cutter test cancel flag
        isCutterTestCanceled=true;
        %clear timer
        stop_clear_timer(timerObj);
        %delete mics object if exist
        if(isempty(mics))
            delete(mics);
        end
        %close all figures is cutter test
        closereq;
    end
%--------------------------------------------------------------------------
%   Internal function to stop and clear timer
%--------------------------------------------------------------------------
    function stop_clear_timer(timerObj)
        %stop and delete the time object
        if(isvalid(timerObj))
            %stop the timer object
            stop(timerObj);
            %delete the timer object from memory
            delete(timerObj);
            %clear the timer object from workspace
            clear timerObj;
        end
    end

%--------------------------------------------------------------------------
%   Internal function to create and start a haptic cube
%--------------------------------------------------------------------------
    function create_haptic_cube()
        reset(hgs);
        %big 2D polygon
        vertices = [ -0.12 0.12 0.12 -0.12 -0.12 -0.10 -0.10 0.10 0.10 -0.10 ];

        numVerts = length(vertices)/2;
        flateye = eye(4);
        objName = ['extruded_2Dpoly___',num2str(rand())];
        objwrtref = reshape(hgs.flange_tx,4,4)';
        ee_tx = [1 0 0 .117; 0 1 0 -.120; 0 0 1 0; 0 0 0 1];
        ee_tx(1:3,4) = hgs.CALIB_BALL_A';
        objwrtref = objwrtref*ee_tx;
        objwrtref = objwrtref';


        ee_tx = ee_tx';
        hgs_haptic(hgs,objName,...
            'verts',vertices,...
            'numVerts',numVerts,...
            'stiffness',10000,...
            'damping',20.0,...
            'haptic_wrt_implant',flateye(:),...
            'obj_wrt_ref',objwrtref(:),...
            'forceMax',80,...
            'torqueMax',4,...
            'constrPlaneGain',42,...
            'start_end_cap',[-0.1 0.1],...
            'constrPlaneNormal',[0.0 0.0 0.1],...
            'planarConstrEnable',0,...
            'safetyConstrEnable',0,...
            'safetyPlaneNormal',[0.0 0.0 1.0],...
            'safetyConstrDir',1,...
            'planarConstrDir',1 ...
            );


        mode(hgs,'haptic_interact',...
            'vo_and_frame_list',{objName},...
            'end_effector_tx',ee_tx(:),...
            'burr_prereq_obj_name',objName,...
            'burr_prereq_var_name','hapticMode',...
            'burr_prereq_value',1);
    end
end


% --------- END OF FILE ----------
