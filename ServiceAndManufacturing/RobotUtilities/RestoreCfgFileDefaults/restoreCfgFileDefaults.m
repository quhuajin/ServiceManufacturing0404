function restoreCfgFileDefaults(hgs)
% restoreCfgFileDefaults script to restore the configuration file to factory default
%
% Syntax:
%   restoreCfgFileDefaults
%       Starts up the GUI to allow the user to restore the configuration
%       file to factory default values
%
% Notes:
%   CRISIS version 2.0.6 beta onwards a default of the configuration file
%   in the configuration files directory.  This script will copy this
%   defaults to the configuration file
%
% See also:
%    hgs_robot/subref

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
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

guiHandles = generateMakoGui('Restore Configuration file Defaults',...
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
            updateMainButtonInfo(guiHandles,'text','Backing up configuration file');            
            pasv(ftpId);
            mget(ftpId,'hgs_arm.cfg');
            backupFileName = sprintf('backup-%s.hgs_arm.cfg',...
                datestr(now,'YYYY-mm-DD-HH-MM-SS'));
            movefile(CFG_FILENAME,fullfile(guiHandles.reportsDir,backupFileName),'f');

            updateMainButtonInfo(guiHandles,'text','Setting defaults');
            % Now copy the default file over
            mget(ftpId,DEFAULT_CFG_FILENAME);
            movefile(DEFAULT_CFG_FILENAME,CFG_FILENAME,'f');
            mput(ftpId,CFG_FILENAME);

            % we are done close the connection
            close(ftpId);

            % cleanup
            delete(CFG_FILENAME);

            % try to get changes to take effect by restarting CRISIS
            try 
                hgs = hgs_robot;
                restartCRISIS(hgs);
                presentMakoResults(guiHandles,'Success',...
                    'Configuration File Successfully restored to Default Values');
            catch
                presentMakoResults(guiHandles,'Success',...
                    {'Configuration File Successfully restored to Default Values',...
                    '','Reboot for changes to take effect'});
            end
            

        catch
            close(ftpId);
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Unable to Restore Constants (%s)',lasterr));
        end

    end
end


% --------- END OF FILE ----------
