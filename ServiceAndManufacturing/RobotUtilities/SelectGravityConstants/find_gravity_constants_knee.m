function find_gravity_constants_knee(hgs)
% FIND_GRAVITY_CONSTANTS_KNEE Function to find the gravity constants for the robot
% with knee EE
% Syntax:
%   find_gravity_constants_knee(hgs)
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
%define path for data file
MCR_DIR = 'RobotUtilitiesBin\SelectGravityConstants_mcr\SelectGravityConstants';
if exist(MCR_DIR,'dir')
    basedir = MCR_DIR;
else
    basedir = '.';
end
%define constants
NOMINAL_GRAV_CONSTANTS.V2_0 = [ -9.0, -17.5, 12.5, -1.8, 36.0,  2.0, -0.2, -0.130 ];
MAX_ALLOWED_DEVIATION.V2_0 =  [  3.0,   5.0,  4.0,  2.0, 10.0,  10.0,  3.0,  1.50  ];

jntGravityLimits=load(fullfile(basedir,'gravityTorqueLimitsKnee.mat'));

NOMINAL_GRAV_CONSTANTS.V2_1 = [ -10.3  -15.9   13.4   -2.1   37.5  3.3   -0.4  -0.1 ];
MAX_ALLOWED_DEVIATION.V2_1 =  [  0.9    1.3    1.4     0.4    4.2  15.7   0.1   0.2  ];

NOMINAL_GRAV_CONSTANTS.V2_2 = [ -10.96 -17.57  13.41  -1.57  38.15 0.89  -0.37 -0.1 ];
MAX_ALLOWED_DEVIATION.V2_2 =  [  0.9    1.3    1.4     0.4    4.2  15.7   0.1   0.2  ];

NOMINAL_GRAV_CONSTANTS.V2_3 = [ -10.3  -15.9   13.4   -2.1   37.5  3.3   -0.4  -0.1 ];
MAX_ALLOWED_DEVIATION.V2_3 =  [  0.9    1.3    1.4     0.4    4.2  15.7   0.1   0.2  ];

NOMINAL_GRAV_CONSTANTS.V3_0 = [ -10.96 -17.57  13.41  -1.57  38.15 0.89  -0.37 -0.1 ];
MAX_ALLOWED_DEVIATION.V3_0 =  [  0.9    1.3    1.4     0.4    4.2  15.7   0.1   0.2  ];

GRAVITY_TORQUE_LIMITS=jntGravityLimits.jntGravityTorqueLimits;

gravity_data.NOMINAL_GRAV_CONSTANTS = [];
gravity_data.MAX_ALLOWED_DEVIATION =  [];

gravity_data.computedGravityConstants=[];
gravity_data.ee_type='KNEE';

% set warinig ratio
gravity_data.DEVIATION_WARNING_RATIO = ones(1,8)*0.5;  % 50% of deviation is warning

% Setup all the constants needed for the test
gravity_data.NUMBER_OF_INTERMEDIATE_POSITIONS=10;

% save the current constants and weights
gravity_data.TESTING_GRAV_COMP_CONSTANTS = zeros(1,8);
gravity_data.TESTING_GRAV_COMP_WEIGHTS = ones(1,6);

%fjunction handles
gravity_data.setGravityConstants=@setGravityConstantsProcedure;
gravity_data.setGravityMode=@setGravityModeProcedure;
gravity_data.getEEImageData=@getKneeEEImageData;
gravity_data.mbDisplayText='Find Gravity Constant With CalEE';


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

% Check if the arm version number matches if not error immediately
gravity_data.arm_hardware_version=hgs.ARM_HARDWARE_VERSION;

switch int32(gravity_data.arm_hardware_version * 10 + 0.05)
    case 20 % 2.0
        gravity_data.NOMINAL_GRAV_CONSTANTS=NOMINAL_GRAV_CONSTANTS.V2_0;
        gravity_data.MAX_ALLOWED_DEVIATION=MAX_ALLOWED_DEVIATION.V2_0;
        gravity_data.GRAV_TORQUE_LIMITS=[];
    case 21 % 2.1
        gravity_data.NOMINAL_GRAV_CONSTANTS=NOMINAL_GRAV_CONSTANTS.V2_1;
        gravity_data.MAX_ALLOWED_DEVIATION=MAX_ALLOWED_DEVIATION.V2_1;
        gravity_data.GRAV_TORQUE_LIMITS=GRAVITY_TORQUE_LIMITS;
        gravity_data.DEVIATION_WARNING_RATIO = ones(1,hgs.WAM_DOF)*0.95;
    case 22 % 2.2
        gravity_data.NOMINAL_GRAV_CONSTANTS=NOMINAL_GRAV_CONSTANTS.V2_2;
        gravity_data.MAX_ALLOWED_DEVIATION=MAX_ALLOWED_DEVIATION.V2_2;
        gravity_data.GRAV_TORQUE_LIMITS=GRAVITY_TORQUE_LIMITS;
        gravity_data.DEVIATION_WARNING_RATIO = ones(1,hgs.WAM_DOF)*0.95;
    case 23 % 2.3
        gravity_data.NOMINAL_GRAV_CONSTANTS=NOMINAL_GRAV_CONSTANTS.V2_3;
        gravity_data.MAX_ALLOWED_DEVIATION=MAX_ALLOWED_DEVIATION.V2_3;
        gravity_data.GRAV_TORQUE_LIMITS=GRAVITY_TORQUE_LIMITS;
        gravity_data.DEVIATION_WARNING_RATIO = ones(1,hgs.WAM_DOF)*0.95;
    case 30 % 3.0
        gravity_data.NOMINAL_GRAV_CONSTANTS=NOMINAL_GRAV_CONSTANTS.V3_0;
        gravity_data.MAX_ALLOWED_DEVIATION=MAX_ALLOWED_DEVIATION.V3_0;
        gravity_data.GRAV_TORQUE_LIMITS=GRAVITY_TORQUE_LIMITS;
        gravity_data.DEVIATION_WARNING_RATIO = ones(1,hgs.WAM_DOF)*0.95;
    otherwise
        % Generate the gui
        guiHandles = generateMakoGui(gravity_data.mbDisplayText,[],hgs);
        presentMakoResults(guiHandles,'FAILURE',...
            sprintf('Unsupported Robot version: V%2.1f',gravity_data.arm_hardware_version));
        return;
end

%set the gravity constants to knee ee
setGravityModeProcedure();

%start the find gravity procedure
find_gravity_constants(hgs,gravity_data);

%--------------------------------------------------------------------------
% internal function to set gravity constants
%--------------------------------------------------------------------------
    function setGravityConstantsProcedure(grav_consts)
        hgs.GRAV_COMP_CONSTANTS=grav_consts;
    end

%--------------------------------------------------------------------------
% internal function to set gravity mode
%--------------------------------------------------------------------------
    function setGravityModeProcedure(varargin)
        comm(hgs,'set_gravity_constants','KNEE');
    end
%--------------------------------------------------------------------------
% internal function to get jpeg image data
%--------------------------------------------------------------------------
    function kneeEEJpegData=getKneeEEImageData(varargin)
        kneeEEJpegData=imread('Knee_EE.jpg');
    end

end

% --------- END OF FILE ----------
