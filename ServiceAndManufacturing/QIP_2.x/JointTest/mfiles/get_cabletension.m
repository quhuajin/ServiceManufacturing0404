
function motor_movement = get_cabletension(direction,galilObj,joint,torque,basedir)
%
% GET_CABLETENSION, measure the cable tension at the joint level
% 
% motor_movement = get_cabletension(direction,joint,torque), measures the
% cable tension in terms of the extra motion seen by the motor when the
% cables are loaded at the bumpstop with torque specified by the input
% variable 'torque'. Input variable 'direction' specifies the direction
% (can be 1 or -1) and the variable 'torque' specified the torque with
% which the tension is measure (can be 0 to 9.9)

% $Author: dmoses $
% $Revision: 3679 $
% $Date: 2014-12-15 18:25:21 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp 2007

%%
% Get the current torque limit on the controller
TLmt = get(galilObj,'TLA');
% Now reset the torque limit to the torque at which tension is measured
set(galilObj,'TL', torque); 

% load joint and motor configuration data
[MOTORDATA, JOINTDATA]= ReadJointConfiguration();

cpr_joint = JOINTDATA.CPR(joint);
cpr_motor = MOTORDATA.CPR(joint);
gratio = JOINTDATA.GRATIO(joint);

% go to bumpstop. Get jogspeed from configuration file 
disp('moving to bump stop')
speed = JOINTDATA.JOGSPEED(joint);
goto_bs_vel(galilObj,direction*speed,basedir);

% measure cable tension
disp('measuring cable tesnion')
downloadfile(galilObj,fullfile(basedir,'dmcfiles','get_cabletension.dmc'));
set(galilObj,'DIR', direction);
set(galilObj,'OFFSET', torque);
set(galilObj,'DONE',0);
comm(galilObj,'XQ');

STATUS = 0;
while(STATUS == 0)
    pause(0.5);
    STATUS = get(galilObj,'DONE');
end

J1 = get(galilObj,'J_pos1');
J2 = get(galilObj,'J_pos2');
M1 = get(galilObj,'M_pos1');
M2 = get(galilObj,'M_pos2');

delJ = J2-J1;
delM = M2-M1;

% Calculate the effective gear ratio
effectiveratio = gratio*cpr_motor/cpr_joint;

delta = delM - effectiveratio*delJ; %per revolution
motor_movement = delta*360/cpr_motor; %degrees

%Before anything else, restore the original torquw limit 
set(galilObj,'TL',TLmt);
pause(0.1)

end

%------------- END OF FILE ----------------