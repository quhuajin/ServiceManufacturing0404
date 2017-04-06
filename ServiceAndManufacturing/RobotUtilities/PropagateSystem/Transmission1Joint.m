function [phase_lag amp_ratio transmissiondata]=Transmission1Joint(hgs,varargin)

% Transmission Check of a Single Joint on the Hgs Robot, without GUI.
%
% Syntax:
%   Transmission1Joint(hgs,'joint',joint,'collect')
%       Starts the transmission check of a single joint 
%       on the hgs robot as defined by the argument hgs.
% 
% Required variables:
%       hgs   - hgs_robot
%       joint - joint to be tested  (default = 1)
%       freq  - vibration frequency (optional)
%       amp   - vibration amplitude (optional)

% Notes:
%   the transmission check procedure oscillates the motor of each joint
%   while measuring both motor and joint angles. It then calculates the
%   phase lag between the motor and joint angles. The measured phase lag is
%   the result of compliance in the drive transmission system. Excessive
%   phase lag above the established limit is a potential indication of 
%   reduced cable tension.
%
% See also:
%   hgs_robot
%
%
% $Author: jscrivens $
% $Revision: 0000 $
% $Date: 2010-07-06 14:05:39 -0400 (Tue, 06 Jul 2010) $
% Copyright: MAKO Surgical corp (2008)
%

%% Transmission test parameters

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

%set proper test parameters based on hardware version
%overridden if specified as input argument
  version = hgs.ARM_HARDWARE_VERSION;
  
  switch int32(version * 10 + 0.05)
      case 20 % 2.0
          ON.vib_freqH=[10    12   10   13   30   30]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .005]; % vib_amp
      case 21 % 2.1
          ON.vib_freqH=[10    12   10   13   30   30]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .005]; % vib_amp
      case 22 % 2.2
          
          ON.vib_freqH=[10    12   10   13   30   55]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .05]; % vib_amp
      case 23 % 2.3
          
          ON.vib_freqH=[10    12   10   13   30   55]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .05]; % vib_amp
      case 30 % 3.0
          
          ON.vib_freqH=[10    12   10   13   30   55]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .05]; % vib_amp
      case 31 % 3.1
          
          ON.vib_freqH=[10    12   10   13   30   55]; % vib_freqH
          ON.vib_amp=  [.002 .002 .002 .005 .005 .05]; % vib_amp
      otherwise
          error('Unsupported Robot version: V%2.1f',version);
  end

collect_data=0;
joint=1;
out=[];
if nargin>1
    for n=1:length(varargin)
        if strcmpi(varargin{n},'collect')
            collect_data=1;
        end
        if strcmpi(varargin{n},'joint')
            joint=varargin{n+1};
        end
        if strcmpi(varargin{n},'freq')
            ON.vib_freqH(joint)=varargin{n+1};
        end
        if strcmpi(varargin{n},'amp')
            ON.vib_amp(joint)=varargin{n+1};
        end
    end
end

%% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: home_hgs argument must be an hgs_robot object');
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

%% Setup Script Identifiers for generic GUI
% % % scriptName = 'Transmission1Joint';
% Setup close test variable
close_test=false;

%% TEST PARAMETERS

dof = hgs.WAM_DOF;

off.gross_freqH(1:dof)  =0.001;
off.vib_freqH(1:dof)    =0.00001;
off.vib_amp(1:dof)      =0.000001;
off.torque_gain(1:dof)  =1.0;

ON.gross_freqH=[1 1 1 1 1 1]*.001; %gross_freqH
ON.torque_gain= [1 1 1 1 1 1]; % torque_gain

testpositions=[ 0 -pi/2 0 pi*.8 0 0;...
                0 -pi*.45 0 pi*.45 0 0;...
                0 -pi/2 0 pi/2 0 0;...
                0 -pi/2 pi/2 pi/2 0 0;...
                0 -pi/2 0 pi/2 0 0;...
                0 -pi/2 pi/2 pi/2 0 0];
           
try
TRANSMISSION_TEST;
catch
    return
end
%% More startup variables
%--------------------------------------------------------------------------
% Primary Transmission check function. Executes on Start Test button press 
%--------------------------------------------------------------------------
    function TRANSMISSION_TEST(varargin)

            try
                if ~close_test
                    target=testpositions(joint,:);
                    go_to_position(hgs,target,.5)

                    run=SetVariables(off, ON, joint);
                    out=[];
                    out=RunTransmissionCheck(hgs,run,collect_data);

                    transdat=CALCULATE_PHASE(hgs,run);
                    transmissiondata=transdat;
                    transmissiondata.joint=joint;
                    transmissiondata.out=out;
                end
            catch
                return
            end

        % check if this was a forced exit from the loop.
        % if so exit immediately
        if close_test
            return;
        end

        try
            phase_lag=transmissiondata.phase_lag;
            amp_ratio=transmissiondata.amplitude_ratio;
        catch
            return
        end

        % return to rest position
        target=testpositions(1,:);
        go_to_position(hgs,target,.5);
        mode(hgs,'zerogravity','ia_hold_enable',1);

    end
end


%%%%%%%%%% THE FOLLOWING ARE NOT NESTED FUNCTIONS %%%%%%%%
%% Calculate Phase
%--------------------------------------------------------------------------
% internal function to evaluate module data and calculate joint phase lag
%--------------------------------------------------------------------------
function transmissiondata=CALCULATE_PHASE(hgs,run)

transmissiondata.measured_joint =run.joint;
transmissiondata.frequency      =run.vib_freqH(run.joint);
transmissiondata.amplitude      =run.vib_amp(run.joint);

transmissiondata.motor_joint_error  =hgs.joint_angle_error(run.joint);
transmissiondata.c_je_joint_angles  =hgs.vibrate_move.log_je_joint_angles(1:hgs.vibrate_move.log_index);
transmissiondata.c_me_joint_angles  =hgs.vibrate_move.log_me_joint_angles(1:hgs.vibrate_move.log_index);
 
t=(0:(hgs.vibrate_move.log_index-1))/2000;
Fs = 2000;
npts = length(t);

x=transmissiondata.c_je_joint_angles;
y=transmissiondata.c_me_joint_angles;

% remove bias
x = x - mean(x);
y = y - mean(y);

% take the FFT
X=fft(x);
Y=fft(y);

% Calculate the numberof unique points
NumUniquePts = ceil((npts+1)/2);
f = (0:NumUniquePts-1)*Fs/npts;

% Evaluate unique points only
XX=X(1:NumUniquePts);
YY=Y(1:NumUniquePts);
%ignore data below 4hz
XX(1:10)=0; 
YY(1:10)=0;

% Determine the max value and max point.
% This is where the sinusoidal
% is located. See Figure 2.
[mag_x idx_x] = max(abs(XX));
[mag_y idx_y] = max(abs(YY));
% Use the index at the frequency of 
% maximum MOTOR excitation 
idx  = idx_y;
% determine the phase difference
% at the maximum point.
px = angle(X(idx));
py = angle(Y(idx));
phase_lag = py - px;

% Wrap-around correction
% produces phase lag above -180°
if phase_lag <(-pi)
    phase_lag = phase_lag + 2*pi;
end

% determine the amplitude scaling
amplitude_ratio = mag_y/mag_x;

transmissiondata.test_time=clock;
transmissiondata.phase_lag=phase_lag;
transmissiondata.amplitude_ratio=amplitude_ratio;
transmissiondata.frequency_excite=run.vib_freqH;
transmissiondata.frequency_j=f(idx_x);
transmissiondata.frequency_m=f(idx_y);
transmissiondata.passfail='';

end

%% RunTransmissionCheck
%--------------------------------------------------------------------------
% internal function run the vibrate_move module for a joint test
%--------------------------------------------------------------------------
function out=RunTransmissionCheck(hgs,run,collect_data)
    
    cenpos=hgs.me_joint_angles; %use me_joint_angles, because
                                %vibrate_move operates on me_joint_angles
                                %for feedback
    pospos=cenpos+.002;
    negpos=cenpos-.002;
    
    mode(hgs,'vibrate_move',...
        'pos_limits',pospos, 'neg_limits',negpos,...
        'gross_freqH',run.gross_freqH,'vib_freqH',run.vib_freqH,...
        'vib_amp', run.vib_amp,'torque_gain',run.torque_gain,...
        'joint_index',run.joint);

    tt=4;
    out=[];
    if collect_data        
        [joints motors currents cotime]=collect(hgs,tt,...
            'je_joint_angles','me_joint_angles','motor_currents','time');
        out.joints=joints;
        out.motors=motors;
        out.currents=currents;
        out.time=cotime-cotime(1);
    else
        pause(tt);
    end

    mode(hgs,'hold_position');
    
end

%% Set Variables function
%--------------------------------------------------------------------------
% internal function to set the vibrate_move variables for a joint test
%--------------------------------------------------------------------------
function run=SetVariables(off, ON, runjoint)
run.gross_freqH	=off.gross_freqH;
run.vib_freqH	=off.vib_freqH;
run.vib_amp     =off.vib_amp;
run.torque_gain	=off.torque_gain;

run.gross_freqH(runjoint)	=ON.gross_freqH(runjoint);
run.vib_freqH(runjoint)     =ON.vib_freqH(runjoint);
run.vib_amp(runjoint)       =ON.vib_amp(runjoint);
run.torque_gain(runjoint)   =ON.torque_gain(runjoint);

run.joint=runjoint;
end

% --------- END OF FILE ----------
