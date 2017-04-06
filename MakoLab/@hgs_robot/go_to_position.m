function final_error = go_to_position(hgs,target_position,max_velocity,initial_torque)
%go_to_position Move the robot to the desired joint angles
%
% Syntax:  
%   go_to_position(hgs,target_position)
%       Move the robot specified by arguement hgs to the target_position.
%       Argument target position is in joint angles
%
%   final_error = go_to_position(hgs,target_position)
%       output final_error can be used to determine the final joint
%       position vs the desired target position
%
%   go_to_position(hgs,target_position,max_velocity)
%       Move the robot to specified target with a max joint velocity as
%       specified.  All axis velocity will be scaled.  If this argument
%       is not specified the default velocity in CRISIS is used
%
%   go_to_position(hgs,target_position,max_velocity,initial_torque)
%       Argument initial_torques can be used to specify an intial value.  If
%       not specified by default the values used will be zeros.  This
%       feature is particularly useful when the target position is under
%       load
%

%
% Notes:
%   This function uses the go_to_position control module on CRISIS.  It is
%   VERY VERY important to remember that this function will complete when
%   the generated trajectory completes.  This does not gaurantee if the
%   correct target was reached by the robot.  Also the gains used are the
%   default gains in the configuration file.  These must be edited
%   beforehand if needed
%
%   There is a 1/4 sec delay after the target is reached to allow the
%   integral term to settle
%
% See also: 
%    hgs_robot/mode

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

switch nargin
    case 2
        % put the robot in go_to_position mode, with the given target
        mode(hgs,'go_to_position','target_position',target_position);
    case 3
        % put the robot in go_to_position mode, with the given target
        mode(hgs,'go_to_position','target_position',target_position,...
            'max_velocity',max_velocity);  
    case 4
        % put the robot in go_to_position mode, with the given target
        mode(hgs,'go_to_position','target_position',target_position,...
            'initial_torque',initial_torque,...
            'max_velocity',max_velocity);
    otherwise
        error('Unsupported number of input parameters');
end

% predict time required to reach target
modId = feval(hgs.ctrlModStatusFcn,'go_to_position');

trajectory_complete = false;
while ~trajectory_complete
    % get data from module
    goToPosState = commDataPair(hgs,'get_local_state',modId);
    trajectory_complete = goToPosState.traj_status;
    
    % check if the mode is still executing
    if comm(hgs,'get_current_module')~=modId
        error('Module error/stopped before reaching target');
    end
    
    % also check for estop press
    if ~get(hgs,'estop_status')
        stop(hgs);
        error('EStop pressed during motion');
    end
    
    % wait to allow interaction by user on GUI etc
    pause(0.05);
    
end

% wait another 1/4 sec to let the integral term complete (this is not
% required but shouldnt matter too much)  Might be nicer to look at the
% integral and wait for that to settle
pause(0.25);

% finally check for the error in the absolute position
if nargout==1
    final_error = target_position - get(hgs,'joint_angles');
end


% --------- END OF FILE ----------