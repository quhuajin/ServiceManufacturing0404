function [h, errStr ] = VibrateRobot(varargin)
% VIBRATEROBOT This script uses te vibrate_move module to vibrate the joints of the
% robot throughout their established range of motion
%
% Syntax:
%     [handleVibrate, vibErr] = VibrateRobot(hgs,...
%                    'limits',limits,...
%                    'duration',duration_vibrate,...
%                    'scaledown',scaledown);
% Input:
% hgs: Robot object
% limits: Is a data structure containg positive and negative limits for 
%         joint angles at end stops
% duration: duration in seconds of robot vibration
% scaledown: scaledown value for scaling vibration motion
%    
% Output:
% h: handle to waitbar window
% errStr: If no error happened during execution of the script errStr is
% empty, otherwise it contains the error message.    
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007-2009



%Preliminary non-essential Variables
duration=1;
vibgain=1;
joints=1:6;
rangelim=.8; %percentage of the rage to be excited
scaledown = 5;
errStr = '';
for i=1:length(varargin) %#ok<FXUP>
    if (isa(varargin{i},'hgs_robot'))
        hgs = varargin{i};
    end
    if strcmp(varargin{i},'limits')
        limits = varargin{i+1};
    end
    if strcmp(varargin{i},'duration')
        duration = varargin{i+1};
    end
    if strcmp(varargin{i},'vibgain')
        vibgain = varargin{i+1};
    end
    if strcmp(varargin{i},'joints')
        joints = varargin{i+1};
    end
    if strcmp(varargin{i},'rangelim')
        rangelim = varargin{i+1};
    end
    if strcmp(varargin{i},'scaledown')
        scaledown = varargin{i+1};
    end
end

%% Variables
gf=[.03 .053 .041 .05 .05  .05];   %Standard gross_freqH values
vf=[ 30  30  30  20  20  20];       %Standard vib_freqH values
va=[.01 .007 .007 .015 .02 .02]/scaledown;  %Standard vib_amp values
tg=[1.0 1.0 1.0 1.0 1.0 1.0] * 1.0;       %Standard Torque Gain values

off_gf=0.001;   % Standard variables for OFF joints
off_vf=1.000;   % Standard variables for OFF joints
off_va=0.001;   % Standard variables for OFF joints
off_tg=1.0;     % Standard variables for OFF joints

DOF=hgs.WAM_DOF;

%% Finesse limits and ranges

centerpos=limits.cen;
fullrange=limits.range;

% Modify Joint 3 Range to avoid hitting the body frame
if DOF > 3

    if limits.pos(3) > pi/2
        limits.pos(3)=pi/2/rangelim;
    end
    if limits.neg(3) < -pi/2
        limits.neg(3)=-pi/2/rangelim;
    end
    centerpos(3)=(limits.pos(3)+limits.neg(3))/2;
    fullrange(3)=(limits.pos(3)-limits.neg(3))/2;
end

% Reset All Range Limits
range=fullrange*rangelim;
pospos=centerpos+range;
negpos=centerpos-range;

%% Set RUN Variables

position=hgs.joint_angles;

for x=1:DOF
    if any(x==joints)
        run.pospos(x)   =pospos(x);
        run.negpos(x)   =negpos(x);
        run.gf(x)       =gf(x);
        run.vf(x)       =vf(x);
        run.va(x)       =va(x)*vibgain;
        run.tg(x)       =tg(x);
    else
        run.pospos(x)   =position(x)+.005;
        run.negpos(x)   =position(x)-.005;
        run.gf(x)       =off_gf;
        run.vf(x)       =off_vf;
        run.va(x)       =off_va;
        run.tg(x)       =off_tg;
    end
end
run.joints=joints;
%%  Run Vibration

% uiwait(msgbox(['Push to Start Vibration (vibgain=' num2str(vibgain) ')'],'modal'));
h = waitbar(0.0,'', 'Name', 'Hass Test');
pause(.15);
h = waitbar(0.1,h,'Moving to starting position');

%Go to fixed start position
target_pos=limits.cen; 

go_to_position(hgs,target_pos,0.2);
h = waitbar(1,h);
mode(hgs, 'zerogravity','ia_hold_enable',0);
pause(0.5)
%update centerpos and pospos and negpos based on 
%motor encoder joint angle, because vibrate_move
%uses motor encoder feedback
centerpos = hgs.me_joint_angles;
run.pospos = centerpos+range;
run.negpos = centerpos-range;

% Vibration Cycle
VibCycle

if isempty(errStr)
    % Finish Vibration
    mode(hgs,'zerogravity','ia_hold_enable',0);
    pause(0.5);
    
    % Go to Home(Parent) Position
    go_to_position(hgs,limits.cen,0.2)
else
    return;
end


%% Vibrate
    function VibCycle
        disp(run);
        mode(hgs,'vibrate_move',...
            'pos_limits',run.pospos, 'neg_limits',run.negpos,...
            'gross_freqH',run.gf,'vib_freqH',run.vf,...
            'vib_amp', run.va,'torque_gain',run.tg,...
            'joint_index',run.joints(1));
        disp('Running vibrate_move Module');

        msg=['Running ' num2str(duration) ' sec Vibration'];
        waitbar(0,h,msg);
        starttime=clock;
        elapsed=0;

        % Vibrate for the prescribed time
        while elapsed<1
            elapsed=etime(clock,starttime)/duration;
            waitbar(elapsed,h)
            pause(1);
            if ~strcmp(mode(hgs),'vibrate_move') 
                stateAtLastErr = commDataPair(hgs,'get_state_at_last_error');
                errStr=  cell2mat(stateAtLastErr.error_msg);
                if stateAtLastErr.error_axis ~= -1
                    errStr = sprintf('%s (J%d)', errStr, ...
                                       stateAtLastErr.error_axis+1);
                    close(h);
                    return;
                end
            end
        end
        waitbar(1,h,'Finished Vibration', 'Name', 'Hass Test');
        close(h);
    end
end

