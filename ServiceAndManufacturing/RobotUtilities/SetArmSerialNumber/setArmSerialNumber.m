function setArmSerialNumber(hgs)

% setArmSerialNumber Gui to help set the TGS arm serial number
%
% Syntax:
%   setArmSerialNumber(hgs)
%       This function will allow the user to set the serial number of the
%       connected robot computer specified by the argument "hgs" 
%
% Notes:
%   The script will check to make sure that the serial number is in the
%   format ROBXXX.  To ignore this check the user can select the ignore
%   format check option in the GUI
%
% See Also:
%   hgs_robot, hgs_robot/display
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

%Supported Hardware version list
SupportedHardwareVersion={'3.0','2.2','2.0'};
SupportedHardwareVersion_dbl = [30 22 20];

ignoreParam.RIO2_2to3_0 = {...
    'ARM_HARDWARE_VERSION',...
    'ARM_SERIAL_NUMBER', ...
    'COMM_WATCHDOG_TIMEOUT', ...
    'JOINT_VELOCITY_LIMIT', ...
    'JOINT_ANGLE_MAX', ...
    'JOINT_ANGLE_MIN', ...
    'IRRIGATION_CONTROL_BIT', ...
    'MICS_ENABLE_BIT', ...
    'MICS_RESET_BIT', ...
    'MICS_STATUS_BIT', ...
    'GRAV_COMP_CONSTANTS_MICS', ...
    'GRAV_COMP_CONSTANTS_KNEE'};
ignoreParam.RIO3_0to2_2 = ignoreParam.RIO2_2to3_0;
    
ignoreParam.RIO2_0to3_0 = {...
    'ARM_HARDWARE_VERSION', ...
    'ARM_SERIAL_NUMBER', ...
    'COMM_WATCHDOG_TIMEOUT', ...
    'JE_COUNTS_PER_REVOLUTION', ...
    'JOINT_ANGLE_CONSISTANCY_THRESHOLD', ...
    'JOINT_VELOCITY_LIMIT', ...
    'MOTOR_TQ_CONT_LIMIT', ...
    'MOTOR_TQ_LIMIT', ...
    'MOTOR_TQ_PER_AMP', ...
    'NUM_POLE_PAIRS', ...
    'SAFETY_MOTOR_CURRENT_ERROR_THRESHOLD', ...
    'JOINT_ANGLE_MAX', ...
    'JOINT_ANGLE_MIN', ...
    'RESMGR_FREQ', ...
    'TRIGGER_STATUS_BIT', ...
    'IRRIGATION_CONTROL_BIT', ...
    'MICS_ENABLE_BIT', ...
    'MICS_RESET_BIT', ...
    'MICS_STATUS_BIT', ...
    'VELOCITY_TYPE', ...
    'GRAV_COMP_CONSTANTS_HIP', ...
    'GRAV_COMP_CONSTANTS_MICS', ...
    'GRAV_COMP_CONSTANTS_KNEE'};
ignoreParam.RIO3_0to2_0 = ignoreParam.RIO2_0to3_0;

ignoreParam.RIO2_0to2_2 = {...
    'ARM_HARDWARE_VERSION', ...
    'ARM_SERIAL_NUMBER', ...
    'JE_COUNTS_PER_REVOLUTION', ...
    'JOINT_ANGLE_CONSISTANCY_THRESHOLD', ...
    'MOTOR_TQ_CONT_LIMIT', ...
    'MOTOR_TQ_LIMIT', ...
    'MOTOR_TQ_PER_AMP', ...
    'NUM_POLE_PAIRS', ...
    'SAFETY_MOTOR_CURRENT_ERROR_THRESHOLD', ...
    'JOINT_ANGLE_MAX', ...
    'JOINT_ANGLE_MIN', ...
    'RESMGR_FREQ', ...
    'TRIGGER_STATUS_BIT', ...
    'VELOCITY_TYPE', ...
    'GRAV_COMP_CONSTANTS_HIP', ...
    'MEM_CHECK'};
ignoreParam.RIO2_2to2_0 = ignoreParam.RIO2_0to2_2;

ignoreParam.RIO2_3to3_0 = {... % used going from CRISIS 2.13 (2.3) fresh install to RIO 3.0
    'ARM_HARDWARE_VERSION', ...
    'ARM_SERIAL_NUMBER', ...
    'IRRIGATION_CONTROL_BIT', ...
    'JOINT_ANGLE_MIN', ...
    'JOINT_ANGLE_MAX', ...
    'MOTOR_TQ_LIMIT', ...
    'MICS_ENABLE_BIT', ...
    'MICS_RESET_BIT', ...
    'MICS_STATUS_BIT', ...
    'RESMGR_FREQ', ...
    'TRIGGER_STATUS_BIT'};

ignoreParam.RIO2_0to2_0 = {'ARM_HARDWARE_VERSION' 'ARM_SERIAL_NUMBER'};
ignoreParam.RIO2_2to2_2 = {'ARM_HARDWARE_VERSION' 'ARM_SERIAL_NUMBER'};
ignoreParam.RIO3_0to3_0 = {'ARM_HARDWARE_VERSION' 'ARM_SERIAL_NUMBER'};
ignoreParamList = '';

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% Check if the specified argument is a hgs_robot
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end
targetName = hgs.host;

% Generate the gui
guiHandles = generateMakoGui('Set Serial Number and Arm Hardware Version',[],hgs);
log_message(hgs,'Set Serial Number Script Started');

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@updateSerialNumberGui);

% common properties for gui elements
commonProperties = struct(...
    'Units','Normalized',...
    'HorizontalAlignment','left',...
    'FontUnits','normalized',...
    'FontName','fixedwidth'...
    );
set(guiHandles.figure,...
    'CloseRequestFcn',@closeFigure...
    );
formatChecking = true;
userIntent = false;

% FTP variables
CONFIGURATION_FILES_DIR = '/CRISIS/bin/configuration_files';
CFG_FILENAME = 'hgs_arm.cfg';
DEFAULT_CFG_FILENAME = 'hgs_arm.cfg.default';

currentHardwareVersion = hgs.ARM_HARDWARE_VERSION;
desiredHardwareVersion = '';
serialNumberString = '';
popParams = true;

%--------------------------------------------------------------------------
% update status if format checking should be done or not
%--------------------------------------------------------------------------
    function updateFormatCheck(objHandle,varargin)
        if get(objHandle,'Value')
            formatChecking = true;
        else
            formatChecking = false;
        end
       
        % put focus back at text box
        uicontrol(guiHandles.snTextBox);
    end

%--------------------------------------------------------------------------
% Internal function to update the serial number of the unit
%--------------------------------------------------------------------------
    function updateSerialNumberGui(varargin)
        
        % Update the dialog text
        updateMainButtonInfo(guiHandles, ...
            'Click Here To Set Serial Number and Hardware Version');
        
        %serial number UIs
        guiHandles.snText = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','text',...
            'FontSize',0.4,...
            'Position',[0.1 0.7 0.4 0.2],...
            'String','Serial Number (ROBXXX)'...
            );
        guiHandles.snTextBox = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','edit',...
            'Background','white',...
            'FontSize',0.4,...
            'Position',[0.5 0.75 0.4 0.2],...
            'String','ROB'...
            );
       guiHandles.snDisplay = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','text',...
            'Background','white',...
            'FontSize',0.7,...
            'Position',[0.1 0.67 0.8 0.075],...
            'String',sprintf('Current Arm Serial Number: %s',...
                char(hgs.ARM_SERIAL_NUMBER)));
        
        %hardware version ui
        guiHandles.hvText = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','text',...
            'FontSize',0.4,...
            'Position',[0.1 0.4 0.4 0.2],...
            'String',{'Arm Hardware'; 'Version (X.X)'}...
            );
        guiHandles.hvListBox = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','listbox',...
            'Background','white',...
            'FontSize',0.3,...
            'String',SupportedHardwareVersion,...
            'Position',[0.5 0.35 0.4 0.3]...
            );
        guiHandles.hvDisplay = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','text',...
            'Background','white',...
            'FontSize',0.7,...
            'Position',[0.1 0.25 0.8 0.075],...
            'String',sprintf('Current Arm Hardware Version: %.1f',...
                hgs.ARM_HARDWARE_VERSION));  
            
            
        guiHandles.snFormatCheck = uicontrol(guiHandles.uiPanel,...
               commonProperties,...
               'Style','checkbox',...
               'Background','white',...
               'FontSize',0.7,...
               'Position',[0.1 0.15 0.8 0.075],...
               'Value',1,...
               'String','Check Format',...
               'Callback',@updateFormatCheck);
        
        
        guiHandles.snPopParam = uicontrol(guiHandles.uiPanel,...
            commonProperties,...
            'Style','checkbox',...
            'Background','white',...
            'FontSize',0.7,...
            'Position',[0.1 0.05 0.8 0.075],...
            'Value',1,...
            'String','Populate Config Parameters (requires additional reboot)');
        
        uicontrol(guiHandles.snTextBox);

        set(guiHandles.mainButtonInfo,'Callback',@confirmIntent);
        
    end

%--------------------------------------------------------------------------
% Internal function to check desired modifications and confirm user intent
%--------------------------------------------------------------------------
    function confirmIntent(varargin)
             
        % CHECK FORMATTING
        serialNumberString = get(guiHandles.snTextBox,'String');
        hardwareVersionIndex = get(guiHandles.hvListBox,'Value');
        desiredHardwareVersion = SupportedHardwareVersion{hardwareVersionIndex};
        if get(guiHandles.snPopParam,'Value'); % flag whether to populate parameters or not
            popParams = true;
        else
            popParams = false;
        end
        
        % Check the string format
        if formatChecking
            try
                %check serial number
                serialNumber = strread(serialNumberString,'ROB%s');
                
                if length(char(serialNumber))~=3
                    % raise an error flag so that the catch will catch it
                    error('serial number length');
                end
                
                % check to make sure the value is numeric
                if ~((str2double(serialNumber)>=0)  && str2double(serialNumber)<=999)
                    error('serial number is not a number');
                end
                
            catch
                errordlg(sprintf('Serial Number expect ROBXXX got %s',...
                    serialNumberString),'Format Error');
                return;
            end
        end
               
        % CONFIRM USER INTENT!
        % Freeze Selections
        set(guiHandles.snTextBox,'enable','off')
        set(guiHandles.hvListBox,'enable','off')
        set(guiHandles.snFormatCheck,'enable','off')
        set(guiHandles.snPopParam,'enable','off')
        
        updateMainButtonInfo(guiHandles,'Caution: Confirm User Intent!');
        choice = questdlg({'This procedure will attempt to modify the serial number and/or hardware version of this RIO.', ...
            'In doing so, ALL configuration parameters may be lost and unrecoverable.',...
            'There is no going back.',...
            '','ARE YOU SURE YOU WANT TO PROCEED?'}, ...
            'Confirm Intent', ...
            'Yes, I Understand. Proceed.','No, take me back to safety.','No, take me back to safety.');
        % Handle response
        switch choice
            case 'Yes, I Understand. Proceed.'
                userIntent = true;
                disp('User Intent Confirmed to Proceed.')
                % log to report structure?
                updateMainButtonInfo(guiHandles,'string', ...
                    'User Intent Confirmed. Click to Proceed.');
                set(guiHandles.mainButtonInfo,'Callback',@updateSNandHV);
                
            otherwise
                userIntent = false;
                disp('User Intent Confirmed to Cancel.')
                % unfreeze selections
                set(guiHandles.snTextBox,'enable','on')
                set(guiHandles.hvListBox,'enable','on')
                set(guiHandles.snFormatCheck,'enable','on')
                updateMainButtonInfo(guiHandles, ...
                    'Click Here To Set Serial Number and Hardware Version');
                return
        end
    end
        
%--------------------------------------------------------------------------
% Internal function to update serial number, crisis, and config file
%--------------------------------------------------------------------------
    function updateSNandHV(varargin)
        updateMainButtonInfo(guiHandles,'string', ...
            'Updating Serial Number and Hardware Version...');
        set(guiHandles.mainButtonInfo,'enable','on');
        drawnow
        
        % Added 2.3 to hardware list due to CRISIS 2.13 fresh install 
        % default config file is to hardware version 2.3
        % Service/Manufacturing needs to update certain values from this
        % 2.13 crisis (2.3 hardware) to 3.0 even though 2.3 is not a
        % commercialized hardware version.
        SupportedHardwareVersion_dbl = [30 23 22 20]; 
        
        % get various formats of current hardware version (cHW)
        % and desired hardware version (dHW)
        cHW = int32(currentHardwareVersion*10 + 0.05);
        dHW = int32(str2double(desiredHardwareVersion) * 10 + 0.05);
        
        cHW_str = num2str(currentHardwareVersion);
        cHW_str(2) = '_';
        if (abs(currentHardwareVersion-3)<.001)
            cHW_str = '3_0';
        end
        if (abs(currentHardwareVersion-2)<.001)
            cHW_str = '2_0';
        end
        dHW_str = desiredHardwareVersion;
        dHW_str(2) = '_';
        
        % If only serial number to change, change it, and skip the rest
        if cHW == dHW
            hgs.ARM_SERIAL_NUMBER = serialNumberString;
            
            if strcmp(hgs.ARM_SERIAL_NUMBER,serialNumberString) && ...
                    (abs(hgs.ARM_HARDWARE_VERSION-str2double(desiredHardwareVersion)) < .0001)
                presentMakoResults(guiHandles,'SUCCESS',...
                    {sprintf('Arm Serial Number updated to %s',serialNumberString)});
                log_results(hgs,guiHandles.scriptName,'PASS', ...
                    sprintf('Arm Serial Number updated to %s',serialNumberString));
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    {sprintf('Arm Serial Number Not Set Properly')});
                log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    sprintf('Arm Serial Number Not Set Properly'));
            end
            
            return
        end
        
        % Get CRISIS image and default config file based on selected hardware version 
        try
            if any(cHW == SupportedHardwareVersion_dbl)
                ignoreParamList = ignoreParam.(['RIO' cHW_str 'to' dHW_str]);
            else
                ignoreParamList = {''};
            end
            
            svc_img = ['Svc-RIO' dHW_str '.img'];
            defaultCfgFile = ['hgs_arm' dHW_str '.cfg.default'];
        catch
            stop(hgs);
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Error Getting Install Names: (%s)',lasterr));
            log_results(hgs,guiHandles.scriptName,'ERROR', ...
                sprintf('Error Getting Install Names: (%s)',lasterr));
            return
        end
                    
        % Save current hgs config parameters (used later to populate)
        hgsOld = hgs{:};      
                      
        % Push selected default config file onto hgs via ftp connection
        updateMainButtonInfo(guiHandles,'text', ...
            'Connecting to Robot Through FTP. Please Wait...');
        try
            
            ftpId = ftp2(targetName,'service','18thSeA');
        catch
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Unable to Connect: (%s)',lasterr));
            log_results(hgs,guiHandles.scriptName,'FAIL', ...
                sprintf('Unable to Connect: (%s)',lasterr));
            return;
        end
        
        % Save current config file to reports folder
        updateMainButtonInfo(guiHandles,'text', ...
            'Saving Current CFG File to Reports Folder. Please Wait...');
        cd(ftpId,CONFIGURATION_FILES_DIR);
        pasv(ftpId);
        mget(ftpId,'hgs_arm.cfg');
        backupFileName = sprintf('backup-%s.hgs_arm.cfg',...
            datestr(now,'YYYY-mm-DD-HH-MM-SS'));
        movefile(CFG_FILENAME,fullfile(guiHandles.reportsDir,backupFileName),'f');

        % Push selected default config file onto HGS
        updateMainButtonInfo(guiHandles,'text', ...
            ['Installing RIO ' desiredHardwareVersion ' Default Config File. Please Wait...']);
        try
            % Copy default config file to hgs as the current cfg file
            cfgFilePath = which(defaultCfgFile);
            ffn = fullfile(cfgFilePath);
            copyfile(ffn,CFG_FILENAME,'f');
            pause(.1)
            mput(ftpId,CFG_FILENAME);
            pause(.1)
            
            % Copy default config file to hgs as the default cfg file
            copyfile(ffn,DEFAULT_CFG_FILENAME,'f');
            pause(.1)
            mput(ftpId,DEFAULT_CFG_FILENAME);
            pause(.1)
            
            % clean up temp files
            delete(CFG_FILENAME);
            delete(DEFAULT_CFG_FILENAME);
        catch
            close(ftpId);
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Error Transfering Config File: (%s)',lasterr));
            log_results(hgs,guiHandles.scriptName,'FAIL', ...
                sprintf('Error Transfering Config File: (%s)',lasterr));
            return;
        end
        
        % Close FTP
        updateMainButtonInfo(guiHandles,'text', ...
            'Closing FTP Connection. Please Wait...');
        close(ftpId);
        
        % Install selected crisis image to HGS using low level loadngo
        updateMainButtonInfo(guiHandles,'text', ...
            ['Installing RIO ' desiredHardwareVersion ' Service CRISIS Software. Please Wait...']);
        close(hgs)
        
        try
            load_arm_software_direct(targetName,svc_img);
        catch
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Error Installing CRISIS: (%s)',lasterr));
            log_results(hgs,guiHandles.scriptName,'FAIL', ...
                sprintf('Error Installing CRISIS: (%s)',lasterr));
            return
        end
        
        updateMainButtonInfo(guiHandles,'text', ...
            'Robot Rebooting. Please Wait...');
        uiwait(msgbox('Please Hard Reboot the RIO and Press OK.', ...
            'Hard Reboot RIO to Continue', 'modal'));
        msg_txt = 'Rebooting RIO. Please Wait...';
        makeWait(50, .1, msg_txt); % wait about 45 seconds (.1 update) to allow restart
        
        try
            hgs = connectRobotGui;
            if isempty(hgs)
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                return
            end
        catch
             presentMakoResults(guiHandles,'FAILURE',...
                 sprintf('Error Reconnecting to Robot: (%s)',lasterr));
             log_results(hgs,guiHandles.scriptName,'FAIL', ...
                 sprintf('Error Reconnecting to Robot: (%s)',lasterr));
            return
        end
        
        % Populate hgs parameters from saved cfg file when flagged, else,
        % update the serial number and hardware version and restart crisis
        if popParams && any(cHW == SupportedHardwareVersion_dbl)
            updateMainButtonInfo(guiHandles,'text', ...
                'Populating common RIO Parameters. Please Wait...');
            
            paramNames = fieldnames(hgs);
            paramNamesOld = fieldnames(hgsOld);
            
            for i=1:length(paramNames)
                updateMainButtonInfo(guiHandles,'text', ...
                    sprintf('Populating common RIO Parameters. Please Wait... (%d/%d)', i, length(paramNames)));
                
                if any(strcmpi(paramNames(i),ignoreParamList))
                    continue
                end
                
                temp = strrep(paramNames{i}, '_', '');
                if all(isstrprop(temp, 'lower'))
                    continue
                end
                
                if any(strcmpi(paramNames(i),paramNamesOld))
                    hgs.(paramNames{i}) = hgsOld.(paramNames{i});
                end
                pause(.05)
            end
            
            desiredHardwareVersion_dbl = str2double(desiredHardwareVersion);
            hgs.ARM_HARDWARE_VERSION=desiredHardwareVersion_dbl;
            
            hgs.ARM_SERIAL_NUMBER = serialNumberString;
            
            % Reboot Rio one more time for changes to take effect
            updateMainButtonInfo(guiHandles,'text', ...
                'Robot Rebooting. Please Wait...');
            uiwait(msgbox('Please Hard Reboot the RIO and Press OK.', ...
                'Hard Reboot RIO to Continue', 'modal'));
            msg_txt = 'Rebooting RIO. Please Wait...';
            makeWait(50, .1, msg_txt); % wait about 45 seconds (.1 update) to allow restart
            
            try
                hgs = connectRobotGui;
                if isempty(hgs)
                    presentMakoResults(guiHandles,'FAILURE',...
                        sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                    log_results(hgs,guiHandles.scriptName,'FAIL', ...
                        sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                    return
                end
            catch
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                log_results(hgs,guiHandles.scriptName,'FAIL', ...
                    sprintf('Error Reconnecting to Robot: (%s)',lasterr));
                return
            end
        else % Only set serial number and hardware version and restart crisis
            
            updateMainButtonInfo(guiHandles,'text', ...
                'Setting Hardware Version. Please Wait...');
            desiredHardwareVersion_dbl = str2double(desiredHardwareVersion);
            hgs.ARM_HARDWARE_VERSION=desiredHardwareVersion_dbl;
            pause(.1)
            updateMainButtonInfo(guiHandles,'text', ...
                'Setting Serial Number. Please Wait...');
            hgs.ARM_SERIAL_NUMBER = serialNumberString;
            pause(.1)
            
            updateMainButtonInfo(guiHandles,'text', ...
                'Restarting CRISIS. Please Wait...');
            txt_msg = 'Restarting CRISIS. Please wait...';
            makeWait(15, .1, txt_msg) 
            restartCRISIS(hgs);
        end
        
        % delete gui elements
        delete(guiHandles.snTextBox);
        delete(guiHandles.snText);
        delete(guiHandles.snDisplay);
        delete(guiHandles.hvListBox);
        delete(guiHandles.hvText);
        delete(guiHandles.hvDisplay);
        delete(guiHandles.snFormatCheck);
        delete(guiHandles.snPopParam);
         
        % check it 
        if strcmp(hgs.ARM_SERIAL_NUMBER,serialNumberString) && ...
                (abs(hgs.ARM_HARDWARE_VERSION-desiredHardwareVersion_dbl) < .0001)
            presentMakoResults(guiHandles,'SUCCESS',...
                {sprintf('Arm Serial Number updated to %s',serialNumberString),...
                sprintf('Arm Hardware Version updated to %.1f',desiredHardwareVersion_dbl)});
            log_results(hgs,guiHandles.scriptName,'SUCCESS', ...
                    sprintf('Serial Number updated to %s. Hardware Version updated to %.1f', ...
                    serialNumberString,desiredHardwareVersion_dbl));
        else
            if ~strcmp(hgs.ARM_SERIAL_NUMBER,serialNumberString)
                failureMsg=sprintf('Serial Number (expected %s got %s)',...
                    serialNumberString,hgs.ARM_SERIAL_NUMBER);
            end
            if hgs.ARM_HARDWARE_VERSION==currentHardwareVersion
                failureMsg=sprintf('Hareware Version (expected %.1f got %.1f)',...
                    desiredHardwareVersion_dbl,hgs.ARM_HRADWARE_VERSION);
            end
            presentMakoResults(guiHandles,'FAILURE',failureMsg);
            log_results(hgs,guiHandles.scriptName,'FAIL', failureMsg);
            return
        end
    end

%--------------------------------------------------------------------------
%   Internal function to close the figure when cancel button is pressed
%--------------------------------------------------------------------------
    function closeFigure(varargin)
        try
            log_message(hgs,'Set Serial Number Script Closed');
            close(hgs); 
            close(ftpId);
        catch
        end
        % close the image
        closereq  
    end

%--------------------------------------------------------------------------
%   Internal function to create waitbar
%--------------------------------------------------------------------------
    function makeWait(totalWaitTime, updateRate, text)      
        h = waitbar(0,text, ...
            'Name', 'Please Wait...', ...
            'visible', 'off');
        movegui(h,'center');
        set(h,'visible', 'on');
        for i=0:updateRate:totalWaitTime
            waitbar(i/totalWaitTime,h,...
                sprintf([text ' (%2.1f seconds left)'],totalWaitTime-i));
            pause(updateRate);
            drawnow;
        end
        close(h);     
    end
end
% --------- END OF FILE ----------