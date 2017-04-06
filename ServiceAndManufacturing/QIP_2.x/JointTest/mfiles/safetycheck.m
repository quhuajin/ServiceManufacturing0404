function handleReturn = safetycheck(galilObj,joint,MOTORDATA,JOINTDATA)

global safety
safety = true;

if (nargin ~=1)
    error('specify joint')
end
if nargin > 6 || nargin < 1 || isinteger(joint)
    error('joint description wrong. Should be an integere between 1 and 6')
end

% Create a timer
safetyTimer = timer(...
    'TimerFcn',@check,...
    'Period',1.0,...
    'ObjectVisibility','off',...
    'BusyMode','drop',...
    'ExecutionMode','fixedSpacing'...
    );

start(safetyTimer)

if (nargout~=0)
    handleReturn.timer = safetyTimer;
end

    function check(varargin)

        % turn off timer if safety is false
        if safety == false
            stop(safetyTimer)
            delete(safetyTimer)
            return
        end

        gratio = JOINTDATA.GRATIO(joint);
        cpr_motor = MOTORDATA.CPR(joint);
        cpr_joint = JOINTDATA.CPR(joint);
        % Calculate the effective gear ratio
        effective_gratio = gratio*cpr_motor/cpr_joint;

        [posmotor,posjoint] = strtok(get(galilObj, 'TP'));
        posmotor = str2double(posmotor);
        posjoint = str2double(strtok(posjoint));
        jointangle_err = posmotor-effective_gratio*posjoint;
        handleReturn.jointerror = jointangle_err*360/cpr_motor;
        handleReturn.units = 'motor degree';

        if((abs(handleReturn.jointerror)) > 45)
            comm(galilObj, 'AB');
            comm(galilObj, 'ST');
            comm(galilObj, 'MO');
            set(galilObj, 'TL', 0);
            set(galilObj, 'KP', 0);
            set(galilObj, 'KD', 0);
            set(galilObj, 'KI', 0);
            pause(0.2)
            safety = false;
            errordlg({'Joint Angle Discrepancy Detected';...
                ['Joint error ',num2str(handleReturn.jointerror), ' degrees'];...
                'Motor Turned off for safety'},...
                'Joint Error')
            return
        end

    end
end