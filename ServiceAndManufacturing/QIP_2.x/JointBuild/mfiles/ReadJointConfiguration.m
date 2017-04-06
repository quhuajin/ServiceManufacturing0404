%% Read Configuration File Function
function [MOTOR, JOINT]= ReadJointConfiguration()
% Set motor configuration data and return data in a structure variable
%
% Syntax: [MOTOR,JOINT]= ReadMotorConfiguration()
%            MOTOR: output data structure for motor configuration
%            JOINT: output data structure for joint configuration
%            
% Friction, Drag, Drag Variance, and Transmission limits have been updated 
%       in accordance to ES-ROB-0073, ES-ROB-0095, and ES-ROB-0096
% These values are for RIO 2.2 and 3.0 ONLY

% $Author: rzhou $
% $Revision: 2607 $
% $Date: 2012-05-30 16:50:51 -0400 (Wed, 30 May 2012) $
% Copyright: MAKO Surgical corp 2007

%% Set Motor Parameters (MKS SSR Doc 472757)

% define CPR count and delta
MOTOR.CPR =       [65536  65536  65536  65536  32768  32768];
MOTOR.CPR_DELTA = [   10     10     10     10     10     10];

% define parameter for Hall State Check
MOTOR.CORRECT_HALL_SET = [1 5 4 6 2 3];
MOTOR.HALL_ANGLE_ERROR = 15; %phase error at zero phase is 10 degree from manufacture spec,and system level limit is 25 degree

% define motor Kt
MOTOR.Kt =  [0.679000    0.523000    0.523000    0.305000    0.360000    0.156000];

% define motor friction and drag limits
MOTOR.FRICTION_LIMIT = [0.152000    0.212000    0.203000    nan    0.0606   0.0379];
MOTOR.DRAG_LIMIT =     [0.141000    0.214000    0.1365000   nan    0.0508   0.0209];

% define motor homing speeds
MOTOR.HOMING_SPEED=   [50000       50000       50000       50000  50000    50000];

%% Set Joint Parameters (MKS SSR Doc 472486)

% friction test positions
JOINT.FRICTION_MEASURE_POSE{1} = [104.5    14.5  -75.5];
JOINT.FRICTION_MEASURE_POSE{2} = [    6       0     -6];
JOINT.FRICTION_MEASURE_POSE{3} = [ 80.5    20.5  -39.5];
JOINT.FRICTION_MEASURE_POSE{4} = [   15       0    -15];
JOINT.FRICTION_MEASURE_POSE{5} = [   15       0    -15];
JOINT.FRICTION_MEASURE_POSE{6} = [   30      60     90];

% define parameters for hall sensor check 
JOINT.HALL_MOTOR_POLE = [12 12 12 12 12 12];

% gear ratio
JOINT.GRATIO = [15.02256 -15.44931  -12.99151 21.84332  -4.58378  7.50414];       

% transmission ratio limit
JOINT.TRATIO_TRANSMISSION_RATIO_LIMIT = [ 0.001583	0.001044	0.001816	0.001062	0.003382	0.002479 ];
JOINT.TRATIO_FIT_ERROR_LIMIT = [0.05   0.05   0.05   0.05   0.05   0.05]; %consistent with CRISIS joint angle discrepancy check.

% transmission
JOINT.TRANSMISSION_FREQ =     [ 20   15   50   40    60   40];
JOINT.TRANSMISSION_AMP =      [500  300  300  300  1000  700];
JOINT.TRANSMISSION_NOMINAL =  [3.7  2.5  1.6  1.7  1.6  1.0]*pi/180;
JOINT.TRANSMISSION_WARNING =  [5.1  3.2  2.3  2.0  2.5  1.3]*pi/180;
JOINT.TRANSMISSION_LIMIT =    [5.9  3.7  2.5  2.1  2.9  1.6]*pi/180;

% Friction and Drag
JOINT.FRICTION_LIMIT =      [0.2180  0.207  0.215  0.0990  0.1611  0.1607];
JOINT.DRAG_LIMIT =          [0.2290  0.177  0.163  0.0813  0.1528  0.1089];
JOINT.DRAG_VARIANCE_LIMIT = [0.0361  0.162  0.115  0.0382  0.0216  0.0171];

% CPR
JOINT.CPR =    [927587    655360    655360    327680    327680    327680];

JOINT.JOGSPEED =        [100000      100000      100000      100000       75000       60000];
JOINT.HOMESPEED =       [ 25000       18000       25000       30000       10000       20000];
JOINT.DRAGSTART =       [     0          15           0          30           0           0];
JOINT.DRAG_SAMPLESIZE = [    50          40          50          40          50          50];
JOINT.DRAG_SAMPLERATE = [     7           5           7           7           7           7];

% define parameters for the Brake Test
JOINT.BRAKE_HOLDING_TQ_LIMIT =                [33.0  59.0  56.0  27.0   6.0   5.6]; % Nm
JOINT.BRAKE_TEST_POSE =                       [   0     0     0     0     0     0];   % in radian
JOINT.BRAKE_TQ_TEST_LIMIT_RATIO =             [ 1.1   1.1  1.05   1.1   1.1   1.1];
JOINT.BRAKE_HOLD_MOTION_DETECTION_THRESHOLD = [0.02  0.05  0.03  0.02  0.02  0.02]; %rad

% define parameters for the Transmission Ratio test
JOINT.TRATIO_RANGE_TOLERANCE = [5  3  5  5  5  5]/180*pi; % radians

% define parameters for the HASS test
JOINT.HASS_STEPSIZE{1} = [49152   3275  1000  3000];
JOINT.HASS_STEPSIZE{2} = [ 4068   4500  1000      ];
JOINT.HASS_STEPSIZE{3} = [ 3275   4915  1000      ];
JOINT.HASS_STEPSIZE{4} = [ 9094   9830  1000      ];
JOINT.HASS_STEPSIZE{5} = [ 8000  49152  1000      ];
JOINT.HASS_STEPSIZE{6} = [ 5000  10000  1000      ];

JOINT.HASS_COUNT{1} = [22   100    800  1500];
JOINT.HASS_COUNT{2} = [180  250  1000       ];
JOINT.HASS_COUNT{3} = [180  250  1000       ];
JOINT.HASS_COUNT{4} = [180  180  1000       ];
JOINT.HASS_COUNT{5} = [180   33  1000       ];
JOINT.HASS_COUNT{6} = [180  100  1000       ];

JOINT.HASS_SPEED{1} = [10000000  10000000  10000000  10000000];
JOINT.HASS_SPEED{2} = [10000000  10000000  10000000          ];
JOINT.HASS_SPEED{3} = [10000000  10000000  10000000          ];
JOINT.HASS_SPEED{4} = [1000000    1000000   1000000          ];
JOINT.HASS_SPEED{5} = [10000000  10000000  10000000          ];
JOINT.HASS_SPEED{6} = [10000000  10000000  10000000          ];

JOINT.HASS_WAIT{1} = [100   10  10 0];
JOINT.HASS_WAIT{2} = [ 10    0   0  ];
JOINT.HASS_WAIT{3} = [ 10    0   0  ];
JOINT.HASS_WAIT{4} = [ 10    0   0  ];
JOINT.HASS_WAIT{5} = [  0   10   0  ];
JOINT.HASS_WAIT{6} = [100  100  10  ];

JOINT.GALIL_TORQUELIMIT =  [    9     6      9     9     9     9];
JOINT.HASSTEST_POSE =      [14.50  0.00  20.50  0.00  0.00  0.00];

JOINT.TRANSMISSION_POSE =     [0  0  0  0  0  0];
JOINT.TRANSMISSION_DURATION = [4  4  4  4  4  4];

% define propogate parameters
JOINT.PROPAGATE_FREQO = [40 40 40 40 40 40];
JOINT.PROPAGATE_AMPO =  [700 500 500 700 700 700];
JOINT.PROPAGATE_GRCYCLS = [3 3 3 3 3 3];
JOINT.PROPAGATE_GROPER =  [25 15 25 20 20 20];
JOINT.PROPAGATE_STEPS =   [200 100 200 150 150 150];
JOINT.PROPAGATE_BIGTURNS = [3 3 3 3 3 3];


