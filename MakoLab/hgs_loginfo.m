function guiHandles = hgs_loginfo(hgs)
%HGS_LOGINFO Gui to help to collect and sort the log information on CRISIS
%
% Syntax:
%   hgs_loginfo(hgs)
%       Starts the log information collecting and sorting on the hgs robot
%       defined by the argument hgs.
%   hgs_loginfo(hostname)
%       If the hostname is directly specified the log info is started up in
%       the ftp mode.  This will not require any connection to CRISIS.
%       hence this is useful if CRISIS is not running or if there is a
%       client already connected to CRISIS
%   hgs_loginfo
%       If no arguments are specified this is an offline mode.  This can be
%       used to load downloaded log files on the local computer
%
% Notes:
%   The hgs_loginfo method gets log files from a hgs robot and sorts all
%   the log information, dislpay the information in a time desending order
%   and display the information in the gui.
%
%   YYYY-MM-DD HH:MM:SS mmm XX  <Log message>
%
%   where
%   XX: two charater abbrieviation of the CRISIS process name
%            CE control_exce
%            CF crisis_cfg_resmgr,
%            CM crisis_manager,
%            HS HgsServer
%            PR peripheral_resmgr
%            TR tracker_resmgr,
%            WR wam_resmgr
%            CL crisis log resource manager
%
% Example Messages:
%
% 2008-05-15 13:24:00  CE     Control module zerogravity (id=7) started
% 2008-05-15 13:24:00  CE     Control module zerogravity (id=7) initialized
% 2008-05-15 13:23:41  WR  >>>MOTOR_TORQUE_LIMIT_ERROR (J3)
% 2008-05-15 13:23:41  WR  >>>WARNING_TORQUE_LIMIT (J3)
% 2008-05-15 13:23:41  CE     Control module hold_position (id=0) deleted
% 2008-05-15 13:23:41  CE     Control module hold_position (id=6) started
%
% See also:
%   hgs_robot
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% CRISIS specific setup
defaultLogFileList={...
    'LOGFILE'};

DEFAULT_SERVICE_IP_TARGET='172.16.16.100';
DEFAULT_VOYAGER_IP_TARGET='10.1.1.178';

crisisLogFileList = defaultLogFileList;
FTP_USERNAME = 'service';
FTP_PASSWORD = '18thSeA';

crisisLogDir='/var/log/';

ERROR_FIELD_KEYWORD = '   ERROR   ';
LOG_FIELD_KEYWORD   = '   LOG-1   ';
WARN_FIELD_KEYWORD  = '   WARNG   ';

LOG_FONT = 'style="FONT-FAMILY: monospaced';
ERROR_FONT = 'style="FONT-FAMILY: monospaced ; BACKGROUND-COLOR: red';
WARNING_FONT = 'style="FONT-FAMILY: monospaced ; BACKGROUND-COLOR: yellow';

% Generic GUI for Service Scripts
if (nargin==0)
    if isempty(getenv('ROBOT_HOST'))
        if ispc
            setenv('ROBOT_HOST',DEFAULT_SERVICE_IP_TARGET);
	else
	    setenv('ROBOT_HOST',DEFAULT_VOYAGER_IP_TARGET);
	end
    end

    try
    hgs = hgs_robot;
    catch
    if ispc
	    hgs = DEFAULT_SERVICE_IP_TARGET;
	else
	    hgs = DEFAULT_VOYAGER_IP_TARGET;
	end
    end
end
guiHandles = generateMakoGui('Log Info',[],hgs);

% Setup the main function
set(guiHandles.mainButtonInfo,...
    'String', 'Refresh Log information',...
    'CallBack',@load_loginfo);

% Change the default figure size
drawnow;

commonProperties = struct(...
    'Units','Normalized',...
    'HorizontalAlignment','left',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'FontName','fixedwidth'...
    );

%create the edit text to hold all the log information
handle_loginfo = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Style','listbox',...
    'FontUnits','points',...
    'FontSize',8,...
    'Position',[0 0 1 0.94],...
    'Min',0,...
    'Max',10 ...
    );

% add a selection window to specify how to connect
handle_online = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Style','popupmenu',...
    'Position',[0.01 0.95 0.15 0.04],...
    'Value',3,...
    'Callback',@selectMode,...
    'String',{'Offline mode','FTP mode','Online mode'}...
    );

handle_sel = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Style','pushbutton',...
    'FontUnits','normalized',...
    'String','Select Files',...
    'Callback',@selectFiles,...
    'enable','off',...
    'Visible','off',...
    'Position',[0.2 0.95 0.2 0.04]...
    );

handle_save = uicontrol(guiHandles.uiPanel,...
    commonProperties,...
    'Style','pushbutton',...
    'FontUnits','normalized',...
    'String','Save',...
    'Callback',@saveFiles,...
    'enable','off',...
    'Visible','off',...
    'Position',[0.425 0.95 0.15 0.04]...
    );

drawnow;

% Automatically load the log file Check if this is a real robot.  If so
% use the direct connection...if not try the ftp connection.  If the ftp
% connection fails then do nothing.  The user may want to use the viewer to
% open a log file

if isa(hgs,'hgs_robot')
    targetHostname = hgs.host;
    load_loginfo_online;
elseif (strcmp(hgs,'Offline'))
    targetHostname = '';
    set(handle_online,...
        'Value',1,...
        'String',{'Offline mode'}...
        );
else
    % check if the target machine is reachable via ftp
    try
        targetHostname = hgs;
        % make sure target hostname is reachable
        if ispc
            pingCommand = 'ping -n 1 -w 1000 ';
        else
            pingCommand = 'ping -c 1 -w 1 ';
        end
        
        % ping the robot for a quick check
        [pingFailure,pingReply] = system([pingCommand,targetHostname]); %#ok<NASGU>
        
        if pingFailure
            error('Target (%s) not reachable...network error',targetHostname);
        end
        
        set(handle_loginfo,...
            'String','Loading...',...
            'FontSize',20)
        drawnow;
        load_loginfo_ftp;
        set(handle_online,...
            'Value',2,...
            'String',{'Offline Mode','FTP mode'}...
            );
    catch
        set(handle_loginfo,...
            'FontSize',20,...
            'String',...
            {sprintf('-- TARGET (%s) NOT REACHABLE',targetHostname),...
            '--- Using offline Mode ---',...
            'Click above to Select file to view'});
        targetHostname = '';
        set(handle_online,...
            'Value',1,...
            'String',{'Offline mode'}...
            );
    end
end

%--------------------------------------------------------------------------
%--------------  Internal function callback for mode select button --------
%--------------------------------------------------------------------------
     function selectMode(hObject,varargin)
%         % If this is an offline mode turn off the select files button
      switch get(hObject,'Value')
            case 1
            set(handle_sel,'enable','off');
            set(handle_save,'enable','off');
            set(handle_sel,'Visible','off');
            set(handle_save,'Visible','off');
            case 2
            set(handle_sel,'Visible','on');
            set(handle_save,'Visible','on');
            case 3
            set(handle_sel,'enable','off');
            set(handle_save,'enable','off');
            set(handle_sel,'Visible','off');
            set(handle_save,'Visible','off');
      end
        load_loginfo;
    end

%--------------------------------------------------------------------------
%--------------  Internal function callback for file select button --------
%--------------------------------------------------------------------------
    function selectFiles(hObject,varargin)
        % Assume this function is never used in offline mode
        % this is for selecting files on the remote computer
        set(handle_loginfo,...
            'String','Loading file list...',...
            'FontSize',20,...
            'Value',1);
        updateMainButtonInfo(guiHandles,...
            'text','Please select files from list below');
        % for now ftp is the only way to get the file list
        if ispc
	    ftpid = ftp2(targetHostname,FTP_USERNAME,FTP_PASSWORD);
	else
	    ftpid = ftp(targetHostname,FTP_USERNAME,FTP_PASSWORD);
	end

        cd(ftpid,crisisLogDir);
        remoteCompleteFileList = dir(ftpid,'*.log');
        remoteFileList{1} = '<html><b>LATEST LOG FILE</b></html>';
        for i=1:length(remoteCompleteFileList)
            remoteFileList{i+1} = remoteCompleteFileList(i).name; %#ok<AGROW>
        end
        close(ftpid);
        
        % Start with default setting
        set(handle_loginfo,...
            'String',remoteFileList,...
            'fontsize',10,...
            'Value',1);
        set(hObject,...
            'String','Selection Done',...
            'Callback',@updateCrisisLogList);
    end

%--------------------------------------------------------------------------
%-----------  Internal function to update the list of files to get --------
%--------------------------------------------------------------------------
    function updateCrisisLogList(hObject,varargin)
        selectionList = get(handle_loginfo,'Value');
        fileNameList = get(handle_loginfo,'String');
        if (selectionList==1)
            crisisLogFileList = defaultLogFileList;
        else
            crisisLogFileList = [];
            listOffset=0;
            if length(selectionList)>30
                errordlg('Too Many files selected');
            else
                for i=1:length(selectionList)
                    if selectionList(i)==1
                        crisisLogFileList = defaultLogFileList;
                        listOffset = length(defaultLogFileList)-1;
                    else
                        crisisLogFileList{listOffset+i} = fileNameList{selectionList(i)};
                    end
                end
            end
        end
        
        set(hObject,...
            'String','Select Files',...
            'Callback',@selectFiles);
        updateMainButtonInfo(guiHandles,...
            'pushbutton','Refresh Log information');
        
        % selection is complete refresh the logs right away
        load_loginfo;
    end

%--------------------------------------------------------------------------
%----------------- Internal function function to get log file data --------
%--------------------------------------------------------------------------
    function load_loginfo(varargin)
        % disable the save and select buttons
	set(handle_save,'enable','off');
	set(handle_sel,'enable','off');

        updateMainButtonInfo(guiHandles,'text','Getting logs...');
        switch get(handle_online,'Value')
            case 1
                try
                    close(hgs);
                catch
                end
                load_loginfo_offline;
            case 2
                try
                    close(hgs);
                catch
                end
                load_loginfo_ftp;
            case 3
                hgs = hgs_robot;
                load_loginfo_online;
        end
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Refresh Log information');
        % reenable the save and select buttons
	%set(handle_save,'enable','on');
	%set(handle_sel,'enable','on');
    end

%--------------------------------------------------------------------------
%----------------------------- Internal function  -------------------------
%----------------to get log file contents through the hgs_robot    --------
%--------------------------------------------------------------------------

    function load_loginfo_online(varargin)
        if strncmp(crisisLogFileList,'LOGFILE',7)
            logFileData = get_file(hgs,'LOGFILE');
        else
            logFileData = '';
            for i=1:length(crisisLogFileList)
                logFileData = [logFileData,...
                    get_file(hgs,[crisisLogDir,'/',crisisLogFileList{i}])]; %#ok<AGROW>
            end
        end
        % now parse the data
        displayCells(regexp(logFileData,'\n','split'));
        drawnow;
    end

%--------------------------------------------------------------------------
%--------- Internal function to get log file contents using ftp    --------
%--------------------------------------------------------------------------
    function load_loginfo_ftp()
        % get the log file data from CRISIS
        if ispc
	    ftpid = ftp2(targetHostname,'service','18thSeA');
	else
	    ftpid = ftp(targetHostname,'service','18thSeA');
	end

        cd(ftpid,crisisLogDir);
        
        % check if the request is for the latest log file
        if strcmp(crisisLogFileList,'LOGFILE')
            remoteCompleteFileList = dir(ftpid,'crisis_log_*.log');
            % pick the lastest file
            crisisLogFileList{1} = remoteCompleteFileList(end).name;
        end
        
        logFileData = '';
        for i=1:length(crisisLogFileList)
            localFileName = fullfile(tempdir,crisisLogFileList{i});
            if exist(localFileName,'file')
                delete(localFileName);
            end
            mget(ftpid,crisisLogFileList{i},tempdir);
            % now parse the data
            fid = fopen(localFileName);
            logFileData = [logFileData,...
                fread(fid,1024*1024*1024)'];
            fclose(fid);
            delete(localFileName);
        end
        
        close(ftpid);
        
        % display the text
        displayCells(regexp(logFileData,'\n','split'));
        drawnow;
        % enable the save and select buttons
	set(handle_save,'enable','on');
	set(handle_sel,'enable','on');
    end

%--------------------------------------------------------------------------
%----------------- Internal function get offline file contents    ---------
%--------------------------------------------------------------------------
    function load_loginfo_offline()
        
        % Get user to select the files
        [logfileNames, pathname] = uigetfile( ...
            {'*.log','log-files (*.log)'},...
            'select log files',...
            'MultiSelect', 'on');
        
        if ~iscell(logfileNames)
            % check if user pressed cancel
            if ~logfileNames
                % do nothing return immediately
                return;
            end
            % if not convert to cell so it can be handled in a consistent
            % way in the following code
            logfileNames = {logfileNames};
        end
        
        % Start reading the files
        logFileData = '';
        for i=1:length(logfileNames)
            localFileName = fullfile(pathname,logfileNames{i});
            % now parse the data
            fid = fopen(localFileName);
            logFileData = [logFileData,fread(fid,inf,'*char')']; %#ok<AGROW>
            fclose(fid);
        end
        
        % display the text
        displayCells(regexp(logFileData,'\n','split'));
        drawnow;
    end

%--------------------------------------------------------------------------
%------------ Internal function to prepare the data for display    --------
%--------------------------------------------------------------------------
    function displayCells(parsedCells)
        % remove the last line since it seems to have null space after the
        % regexp
        set(handle_loginfo,...
            'String',regexprep(regexprep(regexprep(parsedCells(1:end-1),...
            sprintf('[^\n]*%s[^\n]*',LOG_FIELD_KEYWORD),...
            sprintf('<html><PRE><FONT %s">$0</FONT></PRE></html>',LOG_FONT)),...
            sprintf('[^\n]*%s[^\n]*',ERROR_FIELD_KEYWORD),...
            sprintf('<html><PRE><FONT %s">$0</FONT></PRE></html>',ERROR_FONT)),...
            sprintf('[^\n]*%s[^\n]*',WARN_FIELD_KEYWORD),...
            sprintf('<html><PRE><FONT %s">$0</FONT></PRE></html>',WARNING_FONT)),...
            'FontSize',9,...
            'Value',length(parsedCells)-1);
    end

%--------------------------------------------------------------------------
%--------- Internal function to get and save files (always use ftp) -------
%--------------------------------------------------------------------------
    function saveFiles(hobject,varargin)
        
        % update the buttons
        set(hobject,'enable','off');
        updateMainButtonInfo(guiHandles,'text',...
            'Retrieving and Saving Log files...');
        
        % get the log file data from CRISIS
        if ispc
	    ftpid = ftp2(targetHostname,FTP_USERNAME,FTP_PASSWORD);
	else
	    ftpid = ftp(targetHostname,FTP_USERNAME,FTP_PASSWORD);
	end

        cd(ftpid,crisisLogDir);
        
        % check if the request is for the latest log file
        if strcmp(crisisLogFileList,'LOGFILE')
            remoteCompleteFileList = dir(ftpid,'crisis_log_*.log');
            % pick the lastest file
            crisisLogFileList{1} = remoteCompleteFileList(end).name;
        else 
            for i=1:length(crisisLogFileList)
                localFileName = fullfile(tempdir,crisisLogFileList{i});
                if exist(localFileName,'file')
                    delete(localFileName);
                end
                mget(ftpid,crisisLogFileList{i},tempdir);
                
                %
                [fldr,fname,fext] = fileparts(crisisLogFileList{i});
                localFileCopy = [fname datestr(now,'-yyyy-mm-dd-HH-MM-SS') fext];
                
                % now copy and save the data
                copyfile(localFileName,...
                    fullfile(guiHandles.reportsDir,localFileCopy));
                
                delete(localFileName);
                
            end
        end
        close(ftpid);
        updateMainButtonInfo(guiHandles,'text',...
            'Log Files Successfully Saved in Reports Directory');
        pause(1.0);
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Refresh Log information');
        set(hobject,'enable','on');
      
    end

end


% --------- END OF FILE ----------
