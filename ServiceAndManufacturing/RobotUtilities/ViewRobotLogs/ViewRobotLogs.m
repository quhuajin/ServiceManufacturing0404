function ViewRobotLogs
% ViewRobotLogs wrapper function to view log files on the robot
%
% Syntax:  
%   ViewRobotLogs(hgs)
%       Starts up the GUI to allow the user to view logs on the robot
%
% Notes:
%   The function is implemented in the MakoLab project.  This script is
%   heavily used in makolab and hence is maintained there.
%   
% See also: 
%    hgs_loginfo

% 
% $Author: dmoses $
% $Revision: 1706 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

hgs_loginfo;

% --------- END OF FILE ----------