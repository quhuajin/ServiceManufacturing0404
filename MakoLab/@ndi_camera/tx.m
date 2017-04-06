function toolData=tx(ndi)
%TX Send the tx command to the ndi camera and parse the reply
%
% Syntax:
%  TX(ndi)
%   Sends the TX 0801 command to the camera and parse the reply into an array of 
%   structures.  Each element corresponds to a tool.
%   The structure has the following fields
%       status
%       quaternion
%       position
%       error
%       errorMsg
%       transform
%
% Notes:
%   If the tool is missing, the transform is invalid. The quaternion is
%   translated to transforms using the q2tr function in the robot package by
%   Peter Corke
%
% See also:
%   ndi_camera, ndi_camera/setmode, robot/quaternion, ndi_camera/bx
% 

% 
% $Author: dmoses $
% $Revision: 3336 $
% $Date: 2013-12-09 23:11:25 -0500 (Mon, 09 Dec 2013) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% send the command to the camera and wait for the response
camReply = char(comm(ndi,'TX 0801'));

% extract the number of handles
numHandles = str2double(camReply(1:2));

if numHandles == 0
    warning('No Tools Loaded');
end

idx = 3;
for i=1:numHandles
    toolHandle = str2double(camReply(idx:(idx+1)));
    % check if the tool is missing or visible
    if strcmp('MISSING',camReply(idx+2:idx+8))
        toolData(toolHandle).status = 'MISSING';
        toolData(toolHandle).quaternion = [0 0 0 0];
        toolData(toolHandle).position = [0 0 0];
        toolData(toolHandle).error = 0;
        toolData(toolHandle).errorMsg = 'NO_ERROR';
        toolData(toolHandle).transform = zeros(4,4);
        idx = idx+26;
    elseif strcmp('DISABLED',camReply(idx+2:idx+9))
        toolData(toolHandle).status = 'DISABLED';
        toolData(toolHandle).quaternion = [0 0 0 0];
        toolData(toolHandle).position = [0 0 0];
        toolData(toolHandle).error = 0;
        toolData(toolHandle).errorMsg = 'NO_ERROR';
        toolData(toolHandle).transform = zeros(4,4);
        idx = idx+11;
    else
        toolData(toolHandle).status = 'VISIBLE';
        q1=str2double(sprintf('%s.%s',camReply(idx+2:idx+3),...
            camReply(idx+4:idx+7)));
        q2=str2double(sprintf('%s.%s',camReply(idx+8:idx+9),...
            camReply(idx+10:idx+13)));
        q3=str2double(sprintf('%s.%s',camReply(idx+14:idx+15),...
            camReply(idx+16:idx+19)));
        q4=str2double(sprintf('%s.%s',camReply(idx+20:idx+21),...
            camReply(idx+22:idx+25)));

        x=str2double(sprintf('%s.%s',camReply(idx+26:idx+30),...
            camReply(idx+31:idx+32)))*0.001;
        y=str2double(sprintf('%s.%s',camReply(idx+33:idx+37),...
            camReply(idx+38:idx+39)))*0.001;
        z=str2double(sprintf('%s.%s',camReply(idx+40:idx+44),...
            camReply(idx+45:idx+46)))*0.001;
        
        error = str2double(sprintf('%s.%s',camReply(idx+47:idx+48),...
            camReply(idx+49:idx+53)));
        
        % Parse the error bit
        errorBits = hex2dec(camReply(idx+59));
        if bitget(errorBits,4)
            toolData(toolHandle).errorMsg = 'PartiallyOutOfVolume';
        elseif bitget(errorBits,3)
            toolData(toolHandle).errorMsg = 'OutOfVolume';
        else
            toolData(toolHandle).errorMsg = 'NO_ERROR';
        end
        
        % prepare the response
        toolData(toolHandle).quaternion = [q1 q2 q3 q4];
        toolData(toolHandle).position = [x y z];
        toolData(toolHandle).error = error;
        toolData(toolHandle).transform = q2tr(...
            toolData(toolHandle).quaternion);
        toolData(toolHandle).transform(1:3,4)=[x y z]';
        idx = idx+53+16+1;
    end
end

%Q2TR	Convert unit-quaternion to homogeneous transform
%
%	T = q2tr(Q)
%
%	Return the rotational homogeneous transform corresponding to the unit
%	quaternion Q.
%
%	See also: TR2Q, Robot package

%	Copyright (C) 1993 Peter Corke
function t = q2tr(q)

q = double(q);
s = q(1);
x = q(2);
y = q(3);
z = q(4);

r = [	1-2*(y^2+z^2)	2*(x*y-s*z)	2*(x*z+s*y)
    2*(x*y+s*z)	1-2*(x^2+z^2)	2*(y*z-s*x)
    2*(x*z-s*y)	2*(y*z+s*x)	1-2*(x^2+y^2)	];
t = eye(4,4);
t(1:3,1:3) = r;
t(4,4) = 1;


%---- END OF FILE -----