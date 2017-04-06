function saveLoadCfgFile(varargin)
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
% $Revision: 1759 $
% $Date: 2009-05-30 14:01:33 -0400 (Sat, 30 May 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% spaces added for centerning text
% 
s= menu('Choose File Operation',...
    'Save Config File',...
    'Load Config File',...
    'Restore Default Config File',...
    '-------- Cancel ---------');

if(s==1)
    saveCfgFile();
elseif(s==2)
    loadCfgFile();
elseif(s==3)
    restoreCfgFileDefaults();
else
    % display warning
end

end

% --------- END OF FILE ----------
