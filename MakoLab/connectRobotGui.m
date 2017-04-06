function hgs = connectRobotGui(targetHost)
% connectRobotGui Connects to the robot specified by the targetHost and raises an error dialog in case of failure
%
% Syntax:
%    hgs = connectRobotGui
%       connect to the default robot specified by the environment variable 
%       $ROBOT_HOST
%
%    hgs = connectRobotGui(targetHost)
%       connect to the robot specified by the targetHost, where targetHost
%       is the host name or the IP address of the robot
%   
% Notes:
%    on failure argument hgs is ''
%
% See Also:
%    hgs_robot

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)

hgs ='';
try
    if nargin==0
        hgs = hgs_robot;
    else
        hgs=hgs_robot(targetHost);
    end
catch
    % there was an error (parse to find out the reason for the error)
    % this is assumed to be the last line in the error message
    errMsg = textscan(lasterr,'%s','Delimiter','\n');
    errMsgDisplay = {'Unable to connect to Robot',cell2mat(errMsg{1}(end))};
    % create a error dialog with the message
    uiwait(errordlg(errMsgDisplay,'Connection Error'));
end

% --------- END OF FILE ----------
