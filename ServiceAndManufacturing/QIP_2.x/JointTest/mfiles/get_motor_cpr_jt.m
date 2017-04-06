function cpr = get_motor_cpr_jt(galilObj,joint,basedir,MOTORDATA,JOINTDATA)
%GET_MOTOR_CPR_JT is used to get the cpr of the motor encoder during the
%joint testing (JT).

% go to bump stop, get jog speed from configuration file
goto_bs_vel(galilObj,-JOINTDATA.JOGSPEED(joint),basedir);

% find motor cpr
latchpos(1:2)=0; %variable for storing latch position
%download dmc file to controller
downloadfile(galilObj,fullfile(basedir,'dmcfiles','get_cpr.dmc')); 
pause(0.1)
% set homing speed. Get the homing speed from configuration file
set(galilObj,'SPEED',MOTORDATA.HOMING_SPEED(joint)*2);
pause(0.1)


for n = 1:2
    % start a counter by using the tic function
    tic
    comm(galilObj,'XQ');
    STATUS = 0;
    while ( STATUS == 0)
        STATUS = get(galilObj,'DONE');
        pause(0.1);
        % if the wait is more than 5 seconds, exit
        if toc > 5
            break
        end 
    end
    latchpos(n) = get(galilObj,'RLA');  %report latch position
    
    %Move away from index for J2 and J3
    if(joint == 2) || (joint == 3)
        set(galilObj,'JG',MOTORDATA.HOMING_SPEED(joint));
        comm(galilObj,'BGA');
        pause(0.5);
        set(galilObj,'JG',0);
        comm(galilObj,'SHA');
    end
    
% now abort script
comm(galilObj,'AB');
% and turn off the motor
comm(galilObj,'MO');

end
cpr = latchpos(2)-latchpos(1);
end