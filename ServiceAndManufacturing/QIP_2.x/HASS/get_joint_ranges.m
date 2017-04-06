function limits=get_joint_ranges(hgs)
% This function will collect the extreme ranges of motion for each joint
% It requires the user to exercise the joints and ensure that each 
%   positive and negative joint limit is reached

preptime=5; %user has 5 seconds to begin exercising joints
collecttime=40; %user has 5 seconds to exercise joints
pausetime=2; %pause time between operations
dof=hgs.WAM_DOF;

currang=hgs.joint_angles;
poslim=currang;
neglim=currang;
% poslim=zeros(1,6);
% neglim=zeros(1,6);


%% pre exercise timer
% Visualized timer that gives the user a time to get from the
% computer and begin exercising the joints

prepped=0;
h = waitbar(0,['Prepare to exercise joints']);
starttime=clock;

while prepped<1
    prepped=etime(clock,starttime)/preptime;
    waitbar(prepped,h)
end

%% Exercise timer
% Visualizes time remaining for joint exercise

collected=0;
waitbar(0,h,'Collecting Limits');
starttime=clock;

mode(hgs,'zerogravity','ia_hold_enable',0);

while collected<1
    collected=etime(clock,starttime)/collecttime;
    waitbar(collected,h)
    collect_limits
end

mode(hgs,'hold_position');

%% Calculate center position

cenpos=(poslim+neglim)/2;

starttime=clock;

waitbar(0,h,'preparing to move to Center position');

paused=0;
while paused<1
    paused=etime(clock,starttime)/pausetime;
    waitbar(paused,h)
end


%% Goto center position
mode(hgs,'go_to_position','target_position',cenpos,'max_velocity',.2);

waitbar(1,h,'Moving to Center Position');

starttime=clock;
%traj_status is 0 while moving
while (~hgs.go_to_position.traj_status)
    pause(0.01);
    if etime(clock,starttime)> 30
        stop(hgs)
        waitbar(1,h,'Move to Center position time out error'); 
    end
end

waitbar(1,h,'ALL DONE!');
pause(0.01);
stop(hgs);

%% Compile all variables and close

limits.pos=poslim;
limits.neg=neglim;
limits.cen=cenpos;
limits.range=(poslim-neglim)/2;

disp(limits);

pause(3.0);
close(h)

%% Collection
function collect_limits
% Actual data collection function
% Gets current joint angles and updates the + and - limits
currang=hgs.joint_angles;
for x=1:dof
    if currang(x)>poslim(x)
        poslim(x)=currang(x);
    end
    
    if currang(x)<neglim(x)
        neglim(x)=currang(x);
    end
end

end
end
