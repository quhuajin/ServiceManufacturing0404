function loadCfgFile(hgs)
% loadCfgFile script to load a user provided config file
%
% Syntax:
%   loadCfgFile
%       Starts up the GUI to allow the user to load a configuration file to the 
%       default robot location
%
% Notes:
%   Prompts user to select a config file of type *.cfg from local machine 
%   Overwrites the /CRISIS/bin/configuration_files/hgs_arm.cfg with this
%   file
%
% See also:
%    hgs_robot/subref

%
% $Author: jforsyth $
% $Revision: 3016 $
% $Date: 2013-06-27 10:38:03 -0400 (Thu, 27 Jun 2013) $
% Copyright: MAKO Surgical corp (2007)
%


if nargin<1
    targetName = getenv('ROBOT_HOST');
else
    targetName = hgs.host;
end

CONFIGURATION_FILES_DIR = '/CRISIS/bin/configuration_files';
CFG_FILENAME = 'hgs_arm.cfg';
DEFAULT_CFG_FILENAME = 'hgs_arm.cfg.default';

guiHandles = generateMakoGui('Load config file',...
    [],targetName);
updateMainButtonInfo(guiHandles,@confirmUserIntent)
confirmCheckBox ='';

%--------------------------------------------------------------------------
% Function to generate warning message to confirm user intent
%--------------------------------------------------------------------------
    function confirmUserIntent(varargin)
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Acknowledge message below, click to continue',...
            @restoreConfigurationFileDefaults);
        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'String','CAUTION',...
            'fontUnits','normalized',...
            'fontSize',0.8,...
            'Units','normalized',...
            'background','yellow',...
            'Position',[0.1 0.75 0.8 0.2]);
        uicontrol(guiHandles.uiPanel,...
            'Style','text',...
            'String',{'This procedure will restore',...
            'ALL configuration parameters from user provided cfg file',...
            'overwriting the file in default location: ',...
            fullfile(CONFIGURATION_FILES_DIR,CFG_FILENAME),...
            'all current configuration settings will be lost',...
            'ARE YOU SURE YOU WANT TO PROCEED?'},...
            'fontUnits','normalized',...
            'fontSize',0.1,...
            'Units','normalized',...
            'background','white',...
            'Position',[0.1 0.05 0.8 0.7]);
        confirmCheckBox = uicontrol(guiHandles.uiPanel,...
            'Style','checkbox',...
            'String','Check here to confirm',...
            'fontUnits','normalized',...
            'fontSize',0.2,...
            'Units','normalized',...
            'background','white',...
            'HorizontalAlignment','right',...
            'Position',[0.4 0.05 0.3 0.2],...
            'Value',0);
    end

%--------------------------------------------------------------------------
% Main function for restoring the configuration file defaults
%--------------------------------------------------------------------------
    function restoreConfigurationFileDefaults(varargin)
        
        set(confirmCheckBox,'Enable','off');
        
        % Check if the user has aggreed by clicking the checkbox
        if ~get(confirmCheckBox,'value')
            presentMakoResults(guiHandles,'FAILURE',...
                'Caution Message not acknowledged');
            return;
        end
        
        % Start the procedure now
        updateMainButtonInfo(guiHandles,'text','Connecting to Robot');
        try
            % use ftp to restore the configuration file
            ftpId = ftp(targetName,'service','18thSeA');
        catch
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Unable to Connect (%s)',lasterr));
            return;
        end
        
        try
            % display information
            updateMainButtonInfo(guiHandles,'text','Checking connection...please wait');
            cd(ftpId,CONFIGURATION_FILES_DIR);
            
            % Backup the current configuration file
            updateMainButtonInfo(guiHandles,'text','Please provide configuration file');
            pasv(ftpId);
            
            % find config backup file
            [f,p] = uigetfile({'*.cfg','config files'});
            if f==0
                return;
            else
                ffn = fullfile(p,f);
            end
        
            % copy to hgs_arm.cfg local
            hffn = fullfile(p,CFG_FILENAME);
            copyfile(ffn,hffn);
            
            % ftp write
            mput(ftpId,hffn);
            
            % rm hgs_arm.cfg local
            delete(hffn);
            
            % we are done close the connection
            close(ftpId);
            
            
             % try to get changes to take effect by restarting CRISIS
            try 
                hgs = hgs_robot;
                restartCRISIS(hgs);
                presentMakoResults(guiHandles,'Success',...
                    'Configuration File Successfully restored to Default Values');
            catch
                presentMakoResults(guiHandles,'Success',...
                {sprintf('Config File loaded from (%s)',ffn), ...
                'Reboot for changes to take effect.'});
            end

            
        catch
            close(ftpId);
            missFile =  sprintf('Undefined function or method ''message'' for input arguments of type ''char''');
            if(strncmp(sprintf(lasterr),missFile,length(missFile)))
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unable to Load Config (%s)','File not found'));
                
            else
                            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Unable to Load Config (%s)',lasterr));
            end

        end
        
    end
end


% --------- END OF FILE ----------
