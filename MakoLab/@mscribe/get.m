function [output, status] = get(mscribe_obj,option)
%GET gives the microscribe tool pose and other microscribe information

% Syntax:
%   get(mscribe_obj, 'option')
%       Returns output based on 'option'
%       'position' gives the the 3x1 position vector of the tool tip
%       'orientation' gives the 3x3 rotational matrix of the tool
%       'orientation_unitvec' gives the 3x3 rotational matrix of the tool as unit vector
%       'modelname' gives the model name of the connected microscribe
%       'numdof' gives the number of degrees of freedom of the connected microscribe
%       'productname' gives the product name of the connected microscribe
%       'serialnumber' gives the serial number of the connected microscribe
%       'position' gives the x,y,z postion of the tip
%       'transform' gives the full tip transform (position and rotation) 4x4 matrix
%       'version' gives the firmware version of the connected microscribe


% Note:
%   This function uses some sub functions adapted from Peter Corkes
%   robotics Tool Box as indicated in the internal function documentation.

% $Author: dberman $
% $Revision: 3674 $
% $Date: 2014-12-15 16:41:28 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp (2008)
%
status = [];
output = [];

% try
%     status = calllib('armdll64','ArmConnect',0,0);
%     pause(.2)
% catch
%     disp('Error connecting to arm for pose capture')
%     status = [-1];
%     output = [-1];
%     return
% end

% Update arm to send data not needed, works without it
% status = calllib('armdll64','ArmConnect',0,0);
% status = calllib('armdll64','ArmSetUpdate',2);

switch lower(option)

    case 'modelname'
        %[int32, cstring] ArmGetModelName(cstring, uint32)
        [output] = mscribe_obj.ModelName;
        
    case 'version'
        [output] = mscribe_obj.Version;
   
    case 'serialnumber'
        %[int32, cstring] ArmGetSerialNumber(cstring, uint32)
        [output] = mscribe_obj.SerialNumber;

    case 'orientation'
        %[int32, angle_3DPtr] ArmGetTipOrientation(angle_3DPtr)
        ang.x = single(0);
        ang.y = single(0);
        ang.z = single(0);
        angPtr = libstruct('angle_3D',ang);
        [status, output] = calllib('armdll64','ArmGetTipOrientation',angPtr);
        if status == 0
            output = [output.x output.y output.z];
        else
            return
        end
    
    case 'orientation_unitvec'
        %[int32, angle_3DPtr] ArmGetTipOrientationUnitVector(angle_3DPtr)
        ang.x = single(0);
        ang.y = single(0);
        ang.z = single(0);
        angPtr = libstruct('angle_3D',ang);
        [status, output] = calllib('armdll64','ArmGetTipOrientationUnitVector',angPtr);
    
    case 'position'
        %[int32, length_3DPtr] ArmGetTipPosition(length_3DPtr)
        pos.x = single(0);
        pos.y = single(0);
        pos.z = single(0);
        posPtr=libpointer('length_3DPtr',pos);
        status = 1; counter = 0;
        while status ~=0 || counter > 30
            [status, output] = calllib('armdll64','ArmGetTipPosition',posPtr);
            counter = counter + 1;%fprintf('Status not 0, status is %d',status);
        end
        fprintf('Took %d trials to get data.\n',counter);
        output = [output.x output.y output.z];
    
    case 'transform'
        %get tiporientation
        [rpy, status] = get(mscribe_obj,'orientation');
        %get tipposition
        [pos, status] = get(mscribe_obj,'position');
        output = rpy2tr(rpy(3),rpy(2),rpy(1));
        output(1:3,4) = pos';
    
    case 'status'
        % get status
        % [int32, device_statusPtr] ArmGetDeviceStatus(device_statusPtr)
        device_statusPtr = libpointer('device_statusPtr');
        [status, output] = calllib('armdll64','ArmGetDeviceStatus',device_statusPtr);
        
    otherwise
        disp('error.')
        status = -1;
        output = 'ERROR';
end

end



%% The following functions are adapted from Peter Corkes' robotics toolbox

%RPY2TR Roll/pitch/yaw to homogenous transform
% 	TR = RPY2TR([R P Y])
%	TR = RPY2TR(R,P,Y)
%
% Returns a homogeneous tranformation for the specified roll/pitch/yaw angles.
% These correspond to rotations about the Z, Y, X axes respectively.

function r = rpy2tr(roll, pitch, yaw)
        if length(roll) == 3,
                r = rotz(roll(1)) * roty(roll(2)) * rotx(roll(3));
        else
                r = rotz(roll) * roty(pitch) * rotx(yaw);
        end
end

%ROTX Rotation about X axis
%	TR = ROTX(theta)
% Returns a homogeneous transformation representing a rotation of theta 
% about the X axis.

function r = rotx(t)
	ct = cos(t);
	st = sin(t);
	r =    [1	0	0	0
		0	ct	-st	0
		0	st	ct	0
		0	0	0	1];
end

%ROTY Rotation about Y axis
function r = roty(t)
	ct = cos(t);
	st = sin(t);
	r =    [ct	0	st	0
		0	1	0	0
		-st	0	ct	0
		0	0	0	1];
end    

%ROTZ Rotation about Z axis
function r = rotz(t)
	ct = cos(t);
	st = sin(t);
	r =    [ct	-st	0	0
		st	ct	0	0
		0	0	1	0
		0	0	0	1];
end


%----------- END OF FILE -----------