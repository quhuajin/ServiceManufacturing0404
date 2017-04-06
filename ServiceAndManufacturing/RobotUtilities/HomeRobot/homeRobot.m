function homeRobot(hgs)
% homeRobot wrapper function to perform Robot homing
%
% Syntax:  
%   homeRobot(hgs)
%       Starts up the GUI for helping the user perform homing
%
% Notes:
%   The function is implemented in the MakoLab project.  This script is
%   heavily used in makolab and hence is maintained there.
%   
% See also: 
%    hgs_robot, hgs_robot/home_hgs

% 
% $Author: rzhou $
% $Revision: 2117 $
% $Date: 2010-02-11 15:18:50 -0500 (Thu, 11 Feb 2010) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% call the homing function
guiHandles = home_hgs(hgs);

% check if the figure is still open.  block if this is the case
while any(allchild(0)==guiHandles.figure)
    pause(0.2);
end

% close the connection if I get here
close(hgs);

end

% --------- END OF FILE ----------
