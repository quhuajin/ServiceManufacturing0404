function select_gravity_constants(hgs)
% FIND_GRAVITY_CONSTANTS_KNEE Function to find the gravity constants for the robot
% with knee EE
% Syntax:
%   find_gravity_constants_knee(hgs)
%       Starts up the GUI for helping the user determine the gravity
%       constants for the hgs_robot
%
% Notes:
%   The gravity constants are computed by moving the robot through a number
%   of poses and storing the torques required to hold the torque at that
%   pose.  This is then used to compute the parameters as required by the
%   gravity compensation equation
%
%   This function is hardware specific and is currently implemented only
%   for the 2.X robots
%
% See also:
%    hgs_robot, home_hgs/mode

%
% $Author: dmoses $
% $Revision: 1759 $
% $Date: 2009-05-30 14:01:33 -0400 (Sat, 30 May 2009) $
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

knee = 0;

% spaces added for centerning text
% 
s= menu('Choose End Effector Type',...
    '          CalEE (Anspach)          ',...
    'HIP',...
    'MICS',...
    '-------- Cancel ---------');

if(s==1)
    find_gravity_constants_knee(hgs);
elseif(s==2)
    find_gravity_constants_hip(hgs);
elseif(s==3)
    find_gravity_constants_tka(hgs);
else
    % display warning
end

end

% --------- END OF FILE ----------
