function toolData=bx(ndi)
%BX Send the BX command to the ndi camera and parse the reply
%
% Syntax:
%  BX(ndi)
%   Sends the BX 0801 command to the camera and parse the reply into an array of 
%   structures.  Each element corresponds to a tool.
%   The structure has the following fields
%       status
%       quaternion
%       position
%       error
%       transform
%
% Notes:
%   If the tool is missing, the transform is invalid. The quaternion is
%   translated to transforms using the q2tr function in the robot package by
%   Peter Corke
%
% See also:
%   ndi_camera, ndi_camera/setmode, ndi_camera/tx
% 

% 
% $Author: dmoses $
% $Revision: 3330 $
% $Date: 2013-11-27 17:06:56 -0500 (Wed, 27 Nov 2013) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% send the command to the camera and wait for the response
camReply = comm(ndi,'BX 0801',1,true);
camReply = uint8(camReply);
% extract the number of handles
numHandles = camReply(7);

if numHandles == 0
    warning('No Tools Loaded');
end

idx = 8;
for i=1:numHandles
    toolHandle = camReply(idx);
    % check if the tool is missing or visible
    switch camReply(idx+1)
        case 2
            toolData(toolHandle).status = 'MISSING';
            toolData(toolHandle).quaternion = [0 0 0 0];
            toolData(toolHandle).position = [0 0 0];
            toolData(toolHandle).error = 0;
            toolData(toolHandle).errorMsg = 'NO_ERROR';
            toolData(toolHandle).transform = zeros(4,4);
            idx = idx+10;
        case 4
            toolData(toolHandle).status = 'DISABLED';
            toolData(toolHandle).quaternion = [0 0 0 0];
            toolData(toolHandle).position = [0 0 0];
            toolData(toolHandle).error = 0;
            toolData(toolHandle).errorMsg = 'NO_ERROR';
            toolData(toolHandle).transform = zeros(4,4);
            idx = idx+2;
        case 1
            toolData(toolHandle).status = 'VISIBLE';
            q1=convertBytesToFloat(camReply(idx+2:idx+5));
            q2=convertBytesToFloat(camReply(idx+6:idx+9));
            q3=convertBytesToFloat(camReply(idx+10:idx+13));
            q4=convertBytesToFloat(camReply(idx+14:idx+17));
            

            x=convertBytesToFloat(camReply(idx+18:idx+21))*0.001;
            y=convertBytesToFloat(camReply(idx+22:idx+25))*0.001;
            z=convertBytesToFloat(camReply(idx+26:idx+29))*0.001;

            error = convertBytesToFloat(camReply(idx+30:idx+33));

            % error message for partially tracked tools
            errorBits = camReply(idx+34);
            if bitget(errorBits,8)
                toolData(toolHandle).errorMsg = 'PartiallyOutOfVolume';
            elseif bitget(errorBits,7)
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
            idx = idx+42;
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