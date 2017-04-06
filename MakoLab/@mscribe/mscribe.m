function mscribe_obj = mscribe()

%MSCRIBE loads the microscribe dll into work space, connect to the
%microscribe attached to the serial port, and initialized the device
%
% Syntax:
%     mScribe_obj = mscribe()
%       Connects to the micro scribe connected to the serial port and 
%       initialize it.    
%
% Notes:
% 1. The dll files should be in the matlab exection path and project file. 
% 2. Get the dll files from the microscribe SDK CD
%
% See also:
%   disconnect, GetPose, Sample, AccuracyCheck

%
% $Author: dberman $
% $Revision: 3674 $
% $Date: 2014-12-15 16:41:28 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp (2008)
%

%%
dllname = 'armdll64';
% load microscribe library into the matlab workspace. 
% Before loading check if the library is already loaded. 
% NOTE: The dll and the header files are available in the extern folder in MakoLab

mscribe_obj = [];
if(libisloaded(dllname)~=1)
     try
        disp('Loading Library');
        [notfound,warnings] = loadlibrary([dllname '.dll'],@mscribe64proto);
               pause(.1);
        if isempty(notfound)
            disp('Library Loaded!')
        else
            disp('Library Not Found!');
            return
        end
        
     catch
         disp('Error while loading library');
         return
     end
else
    disp('MicroScribe library already loaded');
end



% Check if arm already connected. 
if calllib(dllname,'ArmConnect',0,0) == -1
    disp('MicroScribe already connected')
    return
end

%To view all the API functions in the dll, uncomment the line below
% libfunctions armdll64 -full
%libfunctionsview armdll64

% The ArmStart function prepares the API for operation. Internally, it
% spawns a read thread used to retireve data from the device.
% [int32, HWND__Ptr] ArmStart(HWND__Ptr)
disp('Starting Arm');
try
    vp = libpointer('HWND__Ptr');
    [status HW_ptr] = calllib(dllname,'ArmStart',vp);
    pause(.1)
    if status == 0
        disp(['ArmStart successful! Status: ' num2str(status)])
    end
    
catch
    unloadlibrary(dllname)
    disp('ArmStart Failed. Library unloaded');
    return
end


% ArmConnect detects and etablishes a connection to a MicroScribe
% int32 ArmConnect(int32 port, int32 baud)
% if called with port=0 and baud=0, scan all available serial (COM) ports
% and try to connect at 115200bauds; else, scan desired serial port at
% desired baud rate.
disp('Connecting to arm.');
try
    status = calllib(dllname,'ArmConnect',0,0);
    if status == 0
        disp(['ArmConnect successful! Status: ' num2str(status)])
    else
        disp(['Error ' num2str(status) ' Connecting to Arm.'])
    end
catch
    disp('Error connecting to arm. Unloading library')
    unloadlibrary(dllname)
    return
end
    
% Determine port, baud rate, connection basics.
% Determine mScribe basics.
cstring = '';
% [int32, cstring] ArmGetModelName(cstring, uint32)
[status, mscribe_obj.ModelName] = calllib(dllname,'ArmGetModelName',cstring,40);
pause(.1)

%[int32, cstring] ArmGetSerialNumber(cstring, uint32)
[status, mscribe_obj.SerialNumber] = calllib(dllname,'ArmGetSerialNumber',cstring,40);
disp(['MicroScribe Serial Number: ' num2str(mscribe_obj.SerialNumber)]);
pause(.1)

%[int32, cstring, cstring] ArmGetVersion(cstring, cstring, uint32)
[status, mscribe_obj.Version] = calllib(dllname,'ArmGetVersion',cstring, cstring,40);
pause(.1)

% The ArmSetUpdate function determines the scope of the kinematics calculations performed
% by the API when it receives data from the MicroScribe. Internally, each time the API
% receives new data from the device, it will update the appropriate arm_rec fields required
% for the specified update type.
% int32 ArmSetUpdate(int32)
%#define ARM_3DOF			0x0001		// only arm_rec.stylus_tip fields
%#define ARM_6DOF			0x0002		// Both arm_rec.stylus_tip,arm_rec.stylus_dir
status=calllib(dllname,'ArmSetUpdate',2);
pause(.1)

% The ArmSetLengthUnits function is used to specify the desired distance measurement
% units to be returned by the ArmGetTipPosition function.
% The default length unit is inches.
% ArmSetLengthUnits(int32)
% #define ARM_INCHES			1
% #define ARM_MM				2
% #define ARM_DEGREES			1
% #define ARM_RADIANS			2
calllib(dllname,'ArmSetLengthUnits',2);
pause(.1)

% set microsribe tip to Tip 1
[status]= calllib('armdll64','ArmSetTipProfile',1);
pause(0.1);

try
    mscribe_obj = class(mscribe_obj, 'mscribe');
catch
    disconnect(mscribe_obj);
    pause(.1)
    disp('Failed creating mscribe class object')
    return
end

%------------- END OF FILE ------------
