function reply = stop(hgs)
%STOP stop any mode currently executing on the hgs_robot
%
% Syntax:
%   stop(hgs)
%       stops the execution of any mode executing on the hgs_robot specified by
%       hgs argument.
%
% Notes:
%   modes are also refered to as control_modules in crisis documentation
%
% See also:
%   hgs_robot, hgs_robot/mode
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (creation date)
%

reply = char(comm(hgs,'stop_module'));
return;


% --------- END OF FILE ----------