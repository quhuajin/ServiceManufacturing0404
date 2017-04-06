% home motor, during motor testing

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

function [done, posA] = homemotor (galilObj, jogspeed)
    comm(galilObj,'SHA'); %Set axisA to servo mode
    set(galilObj,'JGA',jogspeed);   %Define jog speed for homing
    comm(galilObj,'FIA'); %Use GALIL Find Inxed command to find the index on motor encoder
    comm(galilObj,'BGA'); %begin motion on AxisA
    % comm('AMA'); %aftermotion trippoint (DO NOT USE trip points
    % while commanding controller from PC. Trippoints hangs communication
    % between controller and PC temporarily)
    count = 0;
    while (count < 200)
        pause(.05)
        posA = get(galilObj,'TPA');
        if (abs(posA) < 10) %10 encoder counts, to account for noise
            done = 1;
            return
        end
        count = count + 1;
    end
    comm(galilObj,'AB'); %Abort motion 
    comm(galilObj,'MO'); % turn motor off
    %clear memory
    comm(galilObj,'DA *,*[]');
    
    disp('homing not done')
    done = 0;
end
%------------- END OF FILE ----------------
