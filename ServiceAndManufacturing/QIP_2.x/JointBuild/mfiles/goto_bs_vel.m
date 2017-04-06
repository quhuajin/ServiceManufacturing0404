function varargout= goto_bs_vel(galilObj, vel, basedir)
% GOTO_BS_VEL commands the joint to go to a bump stop with a motor velocity
% specified by the input variable 'vel' (unit is counts per second)

% Get the current torque limit on the controller
TLmt = get(galilObj,'TLA');
% Now reset the torque limit to the torque at which tension is measured
set(galilObj,'TLA', 2);

%download the dcm script to the galil controller
downloadfile(galilObj,fullfile(basedir,'dmcfiles','goto_bs_vel.dmc'));

% If there is output, set up the data logging flag (used in dmc file) 
if nargout==1
    set(galilObj,'LOG',1);   % log data
else 
    set(galilObj,'LOG',0);   % do not log data
end

% set the jog speed
set(galilObj,'JOGSPEED',vel);
pause(0.01)
% execute the dmc script by issuing 'XQ' command
comm(galilObj,'XQ');

% monitor the 'DONE' flag for completion
STATUS = 0;
while(STATUS == 0)
    STATUS = get(galilObj,'DONE');
    pause(0.01);
end

% Retrieve the array data saved in GALIL
if nargout==1
    varargout{1}=get(galilObj,'arrays');
end

% now abort script
comm(galilObj,'AB');
% and turn off the motor
comm(galilObj,'MO');

%Before anything else, restore the original torque limit
set(galilObj,'TL',TLmt);
pause(0.01)

end