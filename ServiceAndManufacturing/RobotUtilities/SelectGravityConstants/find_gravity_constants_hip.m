function find_gravity_constants_hip(hgs)
% FIND_GRAVITY_CONSTANTS_KNEE Function to find the gravity constants for the robot
% with hip EE
% Syntax:
%   find_gravity_constants_hip(hgs)
%       Starts up the GUI for helping the user determine the gravity
%       constants for the hgs_robot
%
% Notes:
%   The gravity constants are computed by moving the robot through a number
%   of poses and storing the torques required to hold the torque at that
%   pose.  This is then used to compute the parameters as required by the
%   gravity compensation equation
%
%   This function is hardware specific and is currently implemented only
%   for the 2.X robots
%
% See also:
%    hgs_robot, home_hgs/mode

%
% $Author: dmoses $
% $Revision: 1759 $
% $Date: 2009-05-30 14:01:33 -0400 (Sat, 30 May 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% Setup the basic GUI
% Check if the specified argument is a hgs_robot
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end

%define path for data file
MCR_DIR = 'RobotUtilitiesBin\SelectGravityConstants_mcr\SelectGravityConstants';
if exist(MCR_DIR,'dir')
    basedir = MCR_DIR;
else
    basedir = '.';
end

%load limit data file
jntGravityLimits=load(fullfile(basedir,'gravityTorqueLimitsHip.mat'));

%define constants,
gravity_data.GRAV_TORQUE_LIMITS=jntGravityLimits.jntGravityTorqueLimits;
gravity_data.NOMINAL_GRAV_CONSTANTS = [ -11.1700  -19.1648   13.6615   -2.0394   40.1172    5.4586   -1.3410    0.2030 ];
gravity_data.MAX_ALLOWED_DEVIATION =  [ ]; %3-sigma

gravity_data.computedGravityConstants=[];
gravity_data.ee_type='HIP';

% set warinig ratio
gravity_data.DEVIATION_WARNING_RATIO = ones(1,hgs.WAM_DOF)*0.95;

% Setup all the constants needed for the test
gravity_data.NUMBER_OF_INTERMEDIATE_POSITIONS=10;

% save the current constants and weights
gravity_data.TESTING_GRAV_COMP_CONSTANTS = zeros(1,8);
gravity_data.TESTING_GRAV_COMP_WEIGHTS = ones(1,hgs.WAM_DOF);

%fjunction handles
gravity_data.setGravityConstants=@setGravityConstantsProcedure;
gravity_data.setGravityMode=@setGravityModeProcedure;
gravity_data.getEEImageData=@getHipEEImageData;
gravity_data.mbDisplayText='Find Gravity Constant With Hip EE';


% Check if the arm version number matches if not error immediately
gravity_data.arm_hardware_version=hgs.ARM_HARDWARE_VERSION;

if int32(gravity_data.arm_hardware_version * 10 + 0.05)<21 % 2.1
    % Generate the gui
    guiHandles = generateMakoGui(gravity_data.mbDisplayText,[],hgs);
    presentMakoResults(guiHandles,'FAILURE',...
        sprintf('Unsupported Robot version: V%2.1f',hgs.ARM_HARDWARE_VERSION));
    return;
end

%start the find gravity procedure
find_gravity_constants(hgs,gravity_data);

%--------------------------------------------------------------------------
% internal function to set gravity constants 
%--------------------------------------------------------------------------
    function setGravityConstantsProcedure(grav_consts)
        hgs.GRAV_COMP_CONSTANTS_HIP=grav_consts;
    end

%--------------------------------------------------------------------------
% internal function to set gravity mode 
%--------------------------------------------------------------------------
    function setGravityModeProcedure(varargin)
        comm(hgs,'set_gravity_constants','HIP');
    end

%--------------------------------------------------------------------------
% internal function to get jpeg image data
%--------------------------------------------------------------------------
    function hipEEImData=getHipEEImageData(varargin)
       hipEEImData=imread('Hip_EE.jpg');
    end
end

% --------- END OF FILE ----------
