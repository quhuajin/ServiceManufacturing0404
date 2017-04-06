%MAKOLABDEMO Simple Demo showing the use of the MakoLab package
%
% Description:
%   MakoLab is a package developed at Mako for interfacing with the CRISIS
%   software package.  This demo demonstrates the use and capabilities of
%   Makolab.
%
% Syntax:
%   makolabdemo
%     run the demo using default options.  User will be prompted when required
%   makolabdemo 
%
% See also: 
%    MakoLab/Readme, MakoLab, CRISIS

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp 2007

%% 
% Options to set before publishing the demo.  

% Before using the matlab publish command set the interactive option to false
% this will prevent the need for the user to hit key to continue,  When 
% publishing it is assumed that there is a CRISIS system available and the
% TARGET_HGS_ARM environment variable is setup to point to that machine.
interactive=true;


%% Connecting to the HGS Robot 
% Connect to a specific computer running CRISIS by specifying the hostname or ip
% address of that computer.

userPrompt = sprintf('Enter Hostname to connect for Demo (%s):',...
    getenv('TARGET_HGS_ARM'));
newhostname ='';
try
    if interactive
        newhostname = input(userPrompt,'s');
    end
catch
end
if (isempty(newhostname))
    HOSTNAME = getenv('TARGET_HGS_ARM');
else
    HOSTNAME = newhostname;
end
hgs = hgs_robot(HOSTNAME)

% connection can be closed by
close(hgs)

% connection can always be reestablished by.  Only one connection is allowed at
% a time.
hgs = hgs_robot(HOSTNAME)

% If the connection is lost (either by a CRISIS restart or by any other socket
% failure) the connection can be reestablished by using 

reconnect(hgs)

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end

%% Accessing variables
% Access any of the read/write variables from CRISIS
get(hgs,'time');
% or
hgs.time

% One can also access multiple read/write variable simultaneously
[t, je_angles, motor_torques] = get(hgs, 'time', 'joint_angles', 'motor_torques');

% configuration variables can be accessed by
robotNameTemp = hgs.ROBOT_NAME

% configuartion variables can be updated by
hgs.ROBOT_NAME = 'NameSetByMatlabDemo'

% read back the configuration variable
hgs.ROBOT_NAME

% sending raw CRISIS API commands.  for a complete list of commands refer to 
% documentation on comm or the CRISIS_API_README.txt file
comm(hgs,'version_info');

% data is often returned as data pairs.  Data of this nature can be directly
% parsed into structures as shown below
commDataPair(hgs,'get_state');
% to get robot state at last error: 
commDataPair(hgs,'get_state_at_last_error')

% To capture data from the hgs_robot connected and save into the matlab
% workspace the collect function can be used.  This will allow the user to
% quickly capture all or the specified variables from the hgs_robot
loggedJointAngles = collect(hgs,'joint_angles');

% variables can be quickly plotted using.  This is a live plot of the variable 
% specified 
plotHandle = plot(hgs,'joint_angles');

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end

%% 
% Clean up previous section
try
    close(plotHandle);
catch
end
hgs.ROBOT_NAME = robotNameTemp;

%% Homing the Robot
% Homing is a procedure that must be perfromed to initialize the hgs_robot.
% This is required only once per robot system power up or a complete crisis
% driver restart.  

% To query if the homing is done on the robot or not use the home method
home(hgs);

% to perfrom the homing use the home hgs function
home_hgs(hgs);

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end

%% 
try
    close(gcf)
catch
end

%% Setting and Getting Robot mode
% Modes are also refered to as control_modules in CRISIS.
% At a time only one mode can be executed.
% Following robot3.0 package design only one module of a particular mode can be
% created and started.  the mode will automatically be started when the mode is
% initialized.

% list available modes
mode(hgs,'?')

% Get help, input variables etc on a particular mode (e.g. zerogravity)
mode(hgs,'zerogravity','?')

% pass arguments and change the system to a particular mode
mode(hgs,'example',...
    'required_input_1',[1 2 3 4 5],...
    'required_input_2',4,...
    'optional_input_1',[9 8 7 6]...
    );

% to stop a mode
stop(hgs)

% to get the local variables of mode use the . notation
% to list all available local variables
hgs.example() 
% or
hgs.example

% to get the value of specific local variables
hgs.example.local_variable_1

% to view all the input variables for a mode use the following 
% please not the subfield inputs.
hgs.example.inputs

% to update tunable variables use the set command
set(hgs,'example','required_input_1',[5 4 3 2 1]);

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end

%% HGS_HAPTIC CLASS
%Create a new haptic object in hgs_robot
%a virtual sphere
sphere_test=hgs_haptic(hgs,'Sph___test','radius',1.0,'center',hgs.flange_pos)
%a virtual cube model- ascii
cube_test=hgs_haptic(hgs,'Polygon___cube','cube.stl',...
    'voxGridResolution',[0.001,0.001,0.001],...
    'poly_pose_wrt_ref',hgs.flange_tx,...
    'polyStiffness',[5000,5000,5000],...
    'boundingBoxSize',0.001)
%a virtual femoral model-binary
femoral_test=hgs_haptic(hgs,'Polygon___femoral',...
    'SK-Femoral_SZ_5_6mm-Haptic.STL',...
    'voxGridResolution',[0.001,0.001,0.001],...
    'poly_pose_wrt_ref',hgs.flange_tx,...
    'polyStiffness',[5000,5000,5000],...
    'boundingBoxSize',0.001)

%query the haptic object using one of the following three methods 
%method 1
[localvars,inputvars]=get(sphere_test)
%or
%method 2, only local variables
localvars=sphere_test()
%or
%method 3,only local variables
localvars=sphere_test(:)


%start the haptic interact module, only one module active at a time
mode(hgs,'haptic_interact','vo_and_frame_list',sphere_test.name);
%or
mode(hgs,'haptic_interact','vo_and_frame_list',cube_test.name);
%or
mode(hgs,'haptic_interact','vo_and_frame_list',femoral_test.name);

%Delete a haptic object in hgs_robot
delete(sphere_test);

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end

%% TRACKING SYSTEM

%% Connecting to the tracking system on the hgs system
% Currently only the ndi tracking systems are supported.  Be sure an ndi camera
% is connected to the robot specified by hgs
ndi = ndi_camera(hgs)

% To connect to a camera connected directly to the matlab computer specify
% the com port for the connection
ndi_local = ndi_camera('com1');

%% Using the ndi tracking system
% Follow the steps below to initialize and get the position of an ndi tool
init(ndi);
init_tool(ndi,'0150PRB00003.rom');
setmode(ndi,'Tracking');
tx(ndi)

% Pause for user to continue
if interactive
    input 'Please press any key to continue'
end
%% Graphically display the tracked tools using
plot(ndi); 

%% Getting Help in MakoLab
% Global in makolab is available by typing
doc makolab

% or
help makolab;

% Pause for user to continue
if (interactive)
    input 'Please press any key to continue'
end
