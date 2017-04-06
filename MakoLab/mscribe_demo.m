function mscribe_demo(varargin)
%SAMPLE is a sample micro scribe program. It connects to the micro
%scribe arm, takes some pose measurement and disconnects

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%

%% Connecting to the arm
% connect to the arm and initalize arm
if(nargin == 0)
    msArm = mscribe();
else
    msArm = varargin{1};
end

% take a pose measurement
disp('Pose measurement, full transform')
p_full = get(msArm,'transform')

% get position of the tip
disp('Tool tip position')
p_tip = get(msArm,'position')

% get tool rotation
disp('Tool rotation')
p_rotation = get(msArm,'orientation')

% once the measurements are done. If connection made in script
% Disconnect from the arm
if(nargin == 0)
    disp('Now disconnect from the arm')
    disconnect(msArm);
end

%---------- END OF FILE ---------
