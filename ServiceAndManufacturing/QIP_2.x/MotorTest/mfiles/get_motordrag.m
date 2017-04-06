% measures the motor drag

% $Author: dmoses $
% $Revision: 3679 $
% $Date: 2014-12-15 18:25:21 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp 2007

%%
function drag = get_motordrag(galilObj,direction,speed_motor,basedir)

%download the dcm script to the galil controller
downloadfile(galilObj,fullfile(basedir,'dmcfiles','getMotorDrag.dmc'));

% set the jog speed
set(galilObj,'SPEED', direction*speed_motor);
set(galilObj,'SIZE', 100);
set(galilObj,'RATE', 5);

pause(0.01)
% execute the dmc script by issuing 'XQ' command
comm(galilObj,'XQ');
%wait for motor to complete motion
pause(5);

%by this time, motion should have completed,
%double check.
 spd = get(galilObj,'TVA');
 while(abs(spd) >100)
     pause(1);
     spd = get(galilObj,'TVA');    
 end

%now get the data array
measurements=get(galilObj,'QU DRAG[]');

%set motor off
comm(galilObj,'MO');
%clear memory
comm(galilObj,'DA *,*[]');

%now calculate the drag (in Nm) and joint velocity (in rpm)
drag = measurements/32768*10; %mean of torque measurements, Nm
end

%------------- END OF FILE ----------------