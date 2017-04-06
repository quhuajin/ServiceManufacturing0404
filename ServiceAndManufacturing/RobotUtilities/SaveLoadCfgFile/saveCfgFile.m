function saveCfgFile(varargin)
% saveCfgFile script to save the CRISIS config file
%
% Syntax:
%   saveCfgFile
%       Starts up the GUI to allow the user to save the config file from the 
%       default robot location
%
% Notes:
%   Prompts user to enter a name for the file 
%   Writes the file to the local machine reports directory
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

guiHandles = generateMakoGui('Save config file',...
    [],targetName);
updateMainButtonInfo(guiHandles,@restoreConfigurationFileDefaults)
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
            'ALL configuration parameters to default values',...
            'all current configuration settings will be lost',...
            '','ARE YOU SURE YOU WANT TO PROCEED?'},...
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
            updateMainButtonInfo(guiHandles,'text','Checking connection...please wait');
            cd(ftpId,CONFIGURATION_FILES_DIR);
            % Backup the current configuration file
            updateMainButtonInfo(guiHandles,'text','Provide file save name');
            pasv(ftpId);
            mget(ftpId,'hgs_arm.cfg');
            
            % get filename prefix from user
            inp = cell2mat(inputdlg('Enter Save Prefix (12 max, alphanumeric)','Name',1,...
                {'backup'}));
            TF = isempty(inp);
            if TF == 1;
                close(ftpId);
                stop(hgs);
            end;
            len = length(inp);
            maxChars = 12;
            s = min(maxChars,len);
            string = inp(1:s);
            backupFileName = sprintf('%s-%s.hgs_arm.cfg',...
                string,datestr(now,'YYYY-mm-DD-HH-MM-SS'));
            ffn = fullfile(guiHandles.reportsDir,backupFileName);
            
            % copy the file to local
            movefile(CFG_FILENAME,ffn,'f');
            
            % we are done close the connection
            close(ftpId);
            
            presentMakoResults(guiHandles,'Success',...
                sprintf('Config File saved as (%s)',backupFileName));
            
        catch
            close(ftpId);
            
            missFile =  sprintf('Undefined function or method ''message'' for input arguments of type ''char''');
            if TF == 1;
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('User Canceled Script (%s)', 'Unable to Save Config'));
            elseif(strncmp(sprintf(lasterr),missFile,length(missFile)))
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unable to Save Config (%s)','File not found, check permissions'));
                
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unable to Save Config (%s)',lasterr));
            end
        end
    end
end


% --------- END OF FILE ----------
