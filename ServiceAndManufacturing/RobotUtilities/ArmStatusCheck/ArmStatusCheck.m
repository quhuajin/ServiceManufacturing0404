function guiHandles=ArmStatusCheck(hgs,varargin)
%ArmStatusCheck Simple GUI to check the basic status of the arm
%
% Syntax:
%   ArmStatusCheck(hgs)
%       Start the GUI to check the basics setup of the arm
%
% Test Description:
%   Currently this check tests for the following items
%       * No Arm Errors
%       * No Peripheral Device Errors
%       * No Camera Errors
%       * UPS Level Check
% For RIO 3.1, anspach is removed, so there is no ansapch status check 
%

% $Author: hqu $
% $Revision: 4159 $
% $Date: 2017-03-31 15:28:51 -0400 (Fri, 31 Mar 2017) $
% $Modified by: HQU  Date: 2017-01-13 16:28 $
% Copyright: MAKO Surgical corp 2007


% Checks for arguments if any.  If none connect to the default robot
defaultRobotConnection = false;

if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles='';
        return;
    end
    
    % maintain a flag to establish that this connection was done by this
    % script
    defaultRobotConnection = true;
end

guiHandles = generateMakoGui('Arm Status Check',[],hgs);
updateMainButtonInfo(guiHandles,'pushbutton',@startStatusUpdate);
set(guiHandles.figure,'CloseRequestFcn',@abortProcedure);

userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

%set up display text location
commonTextProperties =struct(...
    'Style','text',...
    'Units','normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.8,...
    'HorizontalAlignment','left');

% setup test termination conditions
terminate_loops = false;
UPS_CHARGE_WARNING_LEVEL = 85; % percetage charge
NUM_OF_REQUIRED_ERROR_FREE_CYCLES = 15; % number of consecutive cycles without error
errorFound = false;
warningFound = false;
camera_connection_successful = false;


% keep space for the results
results = '';

%Get arm hardware version. If it's a RIO 3.1 system, anspach is removed. 
rioHardwareVersion = hgs.ARM_HARDWARE_VERSION;
IsRIO3_1System=0; % Default is not a Rio 3.1 system. 


%--------------------------------------------------------------------------
% internal function for the top level execution of the arm status check
%--------------------------------------------------------------------------
    function startStatusUpdate(varargin)
        
        % add a log entry to the log file
        log_message(hgs,'Arm Status Check started');
        
        updateMainButtonInfo(guiHandles,'Pushbutton',...
            'Click Here to Accept Arm Status',@acceptResults);
        
        if (hgs.ARM_HARDWARE_VERSION<2)
	    failureText = sprintf('Unsupported Arm Hardware version (%s)',...
                char(hgs.ARM_HARDWARE_VERSION));
            presentMakoResults(guiHandles,'FAILURE',failureText);
	    log_results(hgs,'Arm Status Check','FAIL',failureText);
            return;
        end
        
        
        % generate the gui depending on RIO version. For RIO 3.1, no
        % anspach check 
         switch (int32(rioHardwareVersion * 10 + 0.05))
           case {20, 21, 22, 23,30} % 2.0--3.0
            errorType = {...
                'Arm',...
                'Anspach',...
                'UPS',...
                'UPS Charge Level',...
                'Camera Connection'};
            case {31} %3.1 
                IsRIO3_1System=1; %Update IsRIO3_1System to be true for RIO 3.1 system 
                errorType = {...
                'Arm',...
                'UPS',...
                'UPS Charge Level',...
                'Camera Connection'};
        end
        for i=1:(length(errorType))
            uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.1 0.9-0.1*i 0.3 0.07],...
                'String',errorType{i});
            errorHandle(i) = uicontrol(guiHandles.uiPanel,...
                commonTextProperties,...
                'Position',[0.4 0.9-0.1*i 0.5 0.07]); %#ok<AGROW>
        end
        
        errorFreeCycles = 0;
         try
            while ~terminate_loops
                errorFound = false;
                warningFound = false;

                % Collect all the required Data
                robotData = hgs(:);
                
                for i=1:(3-IsRIO3_1System)
                    if robotData.ce_error_code(i)==0
                       colorCode = 'green';
                       msg = 'OK';
                    elseif robotData.ce_error_code(i)<0
                        warningFound = true;
                        colorCode = 'yellow';
                        msg = robotData.ce_error_msg{i};
                    else
                        errorFound = true;
                        colorCode = 'red';
                        msg = robotData.ce_error_msg{i};
                    end
		    
		    if i==1
		    	results.RobotStatus = msg;
		    elseif i==2
		    	results.CameraStatus = msg;
		    elseif (i==3)
                results.PeripheralStatus = msg;
		    end

                    set(errorHandle(i),...
                        'BackgroundColor',colorCode,...
                        'String',msg);
                end
                
                % Check ups level and peripheral configuration status
                try 
                    peripheralData = commDataPair(hgs,'get_peripheral_state');
                    if(strcmp(hgs.PERIPHERAL_SYSTEM,'pcm_anspach')==1)
                    	results.ups_level = peripheralData.ups_level;
                        if (peripheralData.ups_level < UPS_CHARGE_WARNING_LEVEL) % ups charge level
                            warningFound = true;
                            set(errorHandle(4-IsRIO3_1System),...
                                'BackgroundColor','yellow',...
                                'String',sprintf('%d %%',peripheralData.ups_level));
                        else
                            set(errorHandle(4-IsRIO3_1System),...
                                'BackgroundColor','green',...
                                'String',sprintf('%d %%',peripheralData.ups_level));
                        end   % end ups charge level 
                    else
                        if(peripheralData.ups_configured)  % if ups configurated 
                    	    results.ups_level = peripheralData.ups_battery_level;
                            if (peripheralData.ups_battery_level < UPS_CHARGE_WARNING_LEVEL) %ups charge level
                                warningFound = true;
                                set(errorHandle(4-IsRIO3_1System),...
                                    'BackgroundColor','yellow',...
                                    'String',sprintf('%d %%',peripheralData.ups_battery_level));
                            else
                                set(errorHandle(4-IsRIO3_1System),...
                                    'BackgroundColor','green',...
                                    'String',sprintf('%d %%',peripheralData.ups_battery_level));
                            end %ups charge level
                        else %end ups configurated 
                            % if error occurs, report a 0 percent battery level.
                            errorFound=true;
                            set(errorHandle(3-IsRIO3_1System),...
                                'BackgroundColor','yellow',...
                                'String','Not Configured');
                            set(errorHandle(4-IsRIO3_1System),...
                                'BackgroundColor','yellow',...
                                'String','0%');
                        end
                        if((~peripheralData.cutter_configured)&&(IsRIO3_1System==0))
                            errorFound = true;
                            colorCode = 'yellow';
                            set(errorHandle(2),...
                                'BackgroundColor',colorCode,...
                                'String','Not Configured');
                        end
                    end
                catch
                    % if error occurs, report a invalid percent battery level.
                    errorFound=true;
                    set(errorHandle(4-IsRIO3_1System),...
                        'BackgroundColor','yellow',...
                        'String','--');
                end
                
                % Check the camera connection
                try
                    % if the camera is not connected already try to connect
                    if ~camera_connection_successful
                        ndi=ndi_camera(hgs);
                        setmode(ndi,'SETUP');
                        % get serialnumber and other information of the
                        % camera connected
                        
                        % remove standard text
                        cameraVersionText = regexprep(regexprep(...
                            regexprep(char(comm(ndi,'VER 4')),...
                            'Polaris Spectra Control Firmware\n',''),...
                            '\(C\) Northern Digital Inc.\n',''),...
                            '\n',' | ');
                        cameraVersionText = cameraVersionText(1:end-7);
                       	results.cameraInfo = cameraVersionText; 
                        
                        % check for bump sensor tripping
                        parsedCells = regexp(char(comm(ndi,'GET P*')),...
                            '^.*Bump Detected.*$','match','dotexceptnewline',...
                            'lineanchors');
                        bumpDetected = sscanf(char(parsedCells),...
                            'Info.Status.Bump Detected=%d');
                        if bumpDetected
                            errorFound = true;
                            set(errorHandle(5-IsRIO3_1System),...
                                'BackgroundColor','red',...
                                'String','Camera Bumped');
			    results.cameraBumpSensor = 'TRIPPED';
                        else
			    results.cameraBumpSensor = 'OK';
                        end
                        
                        % mark successful connection
                        camera_connection_successful = true;
                    end
                    
                    %send command to update connection status
                    setmode(ndi,'SETUP');
                    
                    if (comm(hgs,'is_camera_connected') < 1)
                        errorFound = true;
                        results.cameraConnected = 'no';
			set(errorHandle(5-IsRIO3_1System),...
                            'BackgroundColor','red',...
                            'String','Not Connected');
                    else
                        results.cameraConnected = 'yes';
                        set(errorHandle(5-IsRIO3_1System),...
                            'BackgroundColor','green',...
                            'String','Connected');
                    end
                catch
                    errorFound = true;
                    results.cameraConnected = 'no';
                    set(errorHandle(5-IsRIO3_1System),...
                        'BackgroundColor','red',...
                        'String','Not Connected');
                end

                % Increment number of error free cycles
                if errorFound || warningFound
                    errorFreeCycles = 0;
                else
                    errorFreeCycles = errorFreeCycles +1;
                    if errorFreeCycles >= NUM_OF_REQUIRED_ERROR_FREE_CYCLES
                        presentMakoResults(guiHandles,'SUCCESS');
                        log_results(hgs,'Arm Status Check','PASS','Arm Status Check successful',results);
                        userDataStruct.results=1;
                        set(guiHandles.figure,'UserData',...
                            userDataStruct);
                        return;
                    end
                end

                pause(0.25);
                drawnow;
            end
        catch
            if ~terminate_loops
                presentMakoResults(guiHandles,'FAILURE',...
                    {'Arm Status Error',lasterr});
                log_results(hgs,'Arm Status Check','FAIL',sprintf('Arm Status Check errors %s',lasterr),results);
            end
        end
    end

%--------------------------------------------------------------------------
% internal function to accept results as it is
%--------------------------------------------------------------------------
    function acceptResults(varargin)

        % stop the loop
        terminate_loops = true;
        pause(0.1);
        if errorFound
            presentMakoResults(guiHandles,'FAILURE',...
                {'Arm Status Accepted','Errors Found'});
            log_results(hgs,'Arm Status Check','FAIL',...
            	'Arm Status Check errors manually accepted',results)
            userDataStruct.results=-1;
        elseif warningFound
            presentMakoResults(guiHandles,'WARNING',...
                {'Arm Status Accepted','Warnings exist'});
            log_results(hgs,'Arm Status Check','WARNING',...
            	'Arm Status Check warnings manually accepted',results);
            userDataStruct.results=2;
        else
            presentMakoResults(guiHandles,'WARNING',...
                {'Arm Status Manually Accepted'});
            log_results(hgs,'Arm Status Check','WARNING',...
            	'Arm Status Check manually accepted',results);
            userDataStruct.results=2;
        end
        try
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        catch
            return;
        end
    end

%--------------------------------------------------------------------------
% internal function to cancel the procedure
%--------------------------------------------------------------------------
    function abortProcedure(varargin)
        terminate_loops = true;
        pause(0.3);
        
        % close the connection if it was established by this script
        if defaultRobotConnection
            log_message(hgs,'Arm Status Check script closed');
            close(hgs);
        end
        closereq;
    end
end


%------------- END OF FILE ----------------
