function  Propagate0(hgs,joints)
% Propagate0, Excites oscillatory vibrations on specified JOINTS in effort
% to propagate transmission cable tension throught the active range of the
% cable. Propagation parameters are pre-specified below
%
%   Syntax:
%       Propagate0(hgs,joints,proptime)
%   
%   Required Inputs
%       hgs - Target HGS Robot
%       joints - Joints to be propagated. May range in quantity
%                from 1 to 6 joints
%       proptime - Propagation time in seconds
% 
% $Author: jscrivens $
% $Revision: 0001 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%


%% PROPAGATION PARAMETERS

sim.vibratejoints(1:hgs.WAM_DOF)  =0;

gf=[.10 .20 .10 .20 .20  .20]; %Standard gross_freqH values
vf=[ 60  60  60  60  60  60]; %Standard vib_freqH values
va=[.002 .00075 .00075 .005 .007 .007]; %Standard vib_amp values
tg=[1.0 1.0 1.0 1.0 1.0 1.0]; %Standard Torque Gain values

% Establish joint "ON" vibration parameters
sim.gross_freqH=gf(1:hgs.WAM_DOF);
sim.vib_freqH=vf(1:hgs.WAM_DOF);
sim.vib_amp=va(1:hgs.WAM_DOF);
sim.torque_gain=tg(1:hgs.WAM_DOF);
sim.rangelim=.9;

% Establish joint "OFF" vibration parameters
sim.gf(1:hgs.WAM_DOF)	=0.00000001;
sim.vf(1:hgs.WAM_DOF)	=0.00000001;
sim.va(1:hgs.WAM_DOF)	=0.00000001;
sim.tg(1:hgs.WAM_DOF)	=1.0;

sim.vibratejoints(1:hgs.WAM_DOF)=0;
sim.onoff=0;

%% Acquire and Finesse limits and ranges from robot
limits.pos=hgs.JOINT_ANGLE_MAX;
limits.neg=hgs.JOINT_ANGLE_MIN;
limits.cen=(limits.pos+limits.neg)/2;
limits.range=(limits.pos-limits.neg)/2;

% Modify joint 3 range to +-90°
  % Required to avoid contact between the J6 arm and th erobot base
sim.centerpos=limits.cen;
sim.fullrange=limits.range;

curpos=hgs.joint_angles;
if curpos(2) < -1.1

    if limits.pos(3) > pi/2
        limits.pos(3)=pi/2;
    end
    if limits.neg(3) < -pi/2
        limits.neg(3)=-pi/2;
    end
    sim.centerpos(3)=(limits.pos(3)+limits.neg(3))/2;
    sim.fullrange(3)=(limits.pos(3)-limits.neg(3))/2;
end

%% Run the Propagation
START;          % Start Propagation

%% Embedded Functions
function START
    % Initialize Run variables
    run=RunVariables;
    
    %For a smooth start moeve to an end of the ronge of motion for each joint
    target =run.pospos;
    direction=sign(hgs.joint_angles-sim.centerpos);
    
    for x=1:length(run.joints)
        if direction(run.joints(x))==-1
            target(run.joints(x))=run.negpos(run.joints(x));
        end
    end
    mode(hgs,'zerogravity','ia_hold_enable',1);
    pause(0.5);
    go_to_position(hgs,target,.5);
    pause(0.5);
    
    % Begin Propagation
    mode(hgs,'vibrate_move',...
        'pos_limits',run.pospos, 'neg_limits',run.negpos,...
        'gross_freqH',run.gf,'vib_freqH',run.vf,...
        'vib_amp', run.va,'torque_gain',run.tg,...
        'joint_index',run.joints(1));
    
end %end of START

function run=RunVariables

    % Specify joints under propagation
    sim.vibratejoints(joints)=1;
    
    % Initialize all joints to "OFF" (No Vibration)
    run.gf=sim.gf;
    run.vf=sim.vf;
    run.va=sim.va;
    run.tg=sim.tg;
    
    cenpos=hgs.joint_angles;
    run.pospos=cenpos+.005;
    run.negpos=cenpos-.005;
    
    sim.range=sim.fullrange*sim.rangelim;
    sim.pospos=sim.centerpos+sim.range;
    sim.negpos=sim.centerpos-sim.range;
    
    % Initialize variables for joints under propagation
    run.joints=[];
    y=0;
    for x=1:hgs.WAM_DOF
        if sim.vibratejoints(x)==1
            y=y+1;
            run.pospos(x)   =sim.pospos(x);
            run.negpos(x)   =sim.negpos(x);
            run.gf(x)       =sim.gross_freqH(x);
            run.vf(x)       =sim.vib_freqH(x);
            run.va(x)       =sim.vib_amp(x);
            run.tg(x)       =sim.torque_gain(x);
            run.joints(y)   =x;
        end
    end
    
end %end of RunVariables

end
% End of File