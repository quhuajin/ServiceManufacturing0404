function homingStatus = homingDone(hgs)
%homingDone Query if the hgs_robot is homed
%
% Syntax:
%   homingDone(hgs)
%       Queries the homing status of the hgs_robot.  This will return 
%       logical true if homing is done and false otherwise.
%
% Notes:
%   Homing is a necessary step in the intialization of the hgs robot.  This
%   establishes the absolute position of the robot using index markers.  Homing
%   is required only once per power up.
%
% See also:
%   hgs_robot, hgs_robot/crisisComm, home_hgs
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (creation date)
%

homingStatus = get(hgs,'homing_done');


% --------- END OF FILE ----------