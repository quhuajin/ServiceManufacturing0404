function [done,posA] = home_motor_jt(galilObj,joint,basedir,MOTORDATA,JOINTDATA)
% HOME_MOTOR_JT, is used to home the motor during the sjoint testing (JT). The
% function first takes the joint to the bump stop, and then exectute homing
% routing to find the index on motor encoder.

% go to bump stop
goto_bs_vel(galilObj,-JOINTDATA.JOGSPEED(joint),basedir);
% get the homing speed
jogspeed = MOTORDATA.HOMING_SPEED(joint);
% home motor
disp('HOMING...')


comm(galilObj, 'SHA'); %Set axisA to servo mode
set(galilObj, 'JGA', jogspeed);   %Define jog speed for homing
comm(galilObj, 'FIA'); %Use GALIL Find Inxed command to find the index on motor encoder
comm(galilObj, 'BGA'); %begin motion on AxisA
% comm('AMA'); %aftermotion trippoint (DO NOT USE trip points
% while commanding controller from PC. Trippoints hangs communication
% between controller and PC temporarily)
count = 0;
while (count < 200)
    pause(.05)
    posA = get(galilObj, 'TPA');
    if (abs(posA) < 10) %10 encoder counts, to account for noise etc
        done = 1;
        return
    end
    count = count + 1;
end
comm(galilObj, 'AB'); %Abort motion 
comm(galilObj, 'MO'); %turn motor off
%clear memory
comm(galilObj,'DA *,*[]');
disp('homing not done')
done = 0;


pause(0.05)
% turn off motor after homing
comm(galilObj,'MO');
end