function jointpos = goto_jointpos(galilObj,joint,desired_jointpos,basedir,MOTORDATA,JOINTDATA)

% goto_jointpos(joint,desired_jointpos)
% go to a position in joint space. 
% position specified in DEGREES


if (joint < 1); error('Joint should is a number between 1 and 6'); end
if (joint > 6); error('Joint should is a number between 1 and 6'); end

gratio = JOINTDATA.GRATIO(joint);
cpr_motor = MOTORDATA.CPR(joint);
cpr_joint = JOINTDATA.CPR(joint);


currentjointpos = get(galilObj, 'TPB')*360/cpr_joint;
gotopos = desired_jointpos-currentjointpos;
pos_motor = gotopos*gratio/360;
pos_motor = pos_motor*cpr_motor;
downloadfile(galilObj, fullfile(basedir,'dmcfiles','goto_rel.dmc'));
pause(0.1);
set(galilObj, 'POSITION', pos_motor);
set(galilObj, 'SP', JOINTDATA.JOGSPEED(joint));
pause(0.01);
comm(galilObj, 'XQ');
pause(0.01);
STATUS = 0;
while(STATUS == 0)
    pause(0.5);
    STATUS = get(galilObj, 'DONE');
end
pause(0.1)
jointpos = get(galilObj, 'TPB')*360/cpr_joint;

%now turnoff the motor
comm(galilObj, 'AB');
comm(galilObj, 'MO');
end
