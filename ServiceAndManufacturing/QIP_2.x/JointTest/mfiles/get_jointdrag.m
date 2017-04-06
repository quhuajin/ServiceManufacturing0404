
% GET_JOINTDRAG meausred the joint drag. 

% [drag,vel]=get_jointdrag(direction,joint,no_of_measurements,speed_motor)
% measures the joint drag 
% 'direction' can be 1 (for positive) or -1 (for negative).
% 'joint' specifies the joint on which drag is measured (1 to 6)
% 'no_of_measurement' is the measurement size (sample size for averaging)
% 'speed_motor' is the motor speed at which drag is measured, speed is
% specified in counts per second (for eg, 100000 cps)

% $Author: dmoses $
% $Revision: 3679 $
% $Date: 2014-12-15 18:25:21 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp 2007


function [drag,vel] = get_jointdrag(direction,galilObj,joint,no_of_measurements,speed_motor,...
                                    MOTORDATA,JOINTDATA,basedir)

%get amplifier gain from the galil controller
AG = get(galilObj,'AGX');
%set the corresponding gain
if (AG == 1)
    amp_gain = 0.7; %Nm/Amps
elseif (AG == 2)
    amp_gain = 1.0; %Nm/Amps
else
    set(display2,'String',['Amp gain not set correct. AG = ', num2str(AG)])
    error('Amplifier Gain too low or not set correct')
end

Kt = MOTORDATA.Kt(joint);
rate=JOINTDATA.DRAG_SAMPLERATE(joint);

%download the dcm script to the galil controller
downloadfile(galilObj,fullfile(basedir,'dmcfiles','getJointDrag.dmc'));

% set the jog speed
set(galilObj,'SPEED', direction*speed_motor);
set(galilObj,'SIZE', no_of_measurements);
set(galilObj,'RATE',rate);

pause(0.01)
% execute the dmc script by issuing 'XQ' command
comm(galilObj,'XQ');
%wait for motor to complete motion
pause(7);

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

%now calculate the drag (in Nm) and joint velocity (in rpm)
drag = measurements*amp_gain*Kt/32768*10; %mean of torque measurements, Nm
vel = direction*speed_motor; %average joint velocity, rpm
end

%------------- END OF FILE ----------------