function ForceTransparency(varargin)
%
% FORCETRANSPARENCY checks the system level force transparency of the robot
%
% Syntax:
%   ForceTransparency
%       Performs Force Transparency test on the default robot
%   ForceTransparency(hgs)
%       Performs Force Transparency on the specified hgs robot
%
% Test Description:
%   The test uses a forc guage mounted on a slide to apply foce on
%   the robot end effector. A haptic wall is created normal to the
%   axis of the force guage. The robot end effector and the froce
%   guage mates at the haptic wall. The slide (on which the force guage is
%   mounted is advanced to make the end effector penetrate the haptics
%   wall, hence creating a haptic force. The force reading on the force
%   guage is compared agains the the predicted haptics force to estimate
%   force transparency.
%
% Pass Criteria:
% The pass limit is set at 85% transparency. A warning limit is set at 80%
% transparency.

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007
%%
if(nargin == 0)
    % If no arguments are specified create a connection to the default
    % hgs_robot
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
else
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
        end
    end
end

if ~(isa(hgs,'hgs_robot'))
    error('input should be an hgs robot object')
end
log_message(hgs,'Force Transparency Script Started');

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

% generate mako gui
guiHandles = generateMakoGui('Force Transparency Test',[],hgs,1);

% generate results data file name, and safe data file
dataFileName=['ForceTransparency-System',...
    hgs.name,'-',...
    datestr(now,'yyyy-mm-dd-HH-MM')];
fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);

% clsoe request function, used to close diff functions when cancel button
% is pressed from the GUI
set(guiHandles.figure,...
    'CloseRequestFcn',@closeRequestFunction...
    );

% frame file
referenceframe_file = fullfile(guiHandles.reportsDir,'frame.mat');

% Put robot in zerogravity
mode(hgs,'zerogravity','ia_hold_enable',0);

% Limits
THRESHOLD = 85; % percentage transparecny for success
WARNING = 80; % percentage transparecny for warning
UPPERLIMIT = 110; % perentage. Transparency cannot be more than 110%

% robot configuration, lefty or righty. Initiated to 'righty'
configuration = 'RIGHTY';

global done
global frame
stiffness = 15000; %N/m
z_depth = []; % depth of haptic boundary in z-direction

% compute TCP
set(guiHandles.mainButtonInfo,...
    'String','Find Tool Cetner Point (TCP) First')
feval(@computeTCP,hgs)
uiwait();

% enter axis. This is for display purpose only. The axis will be displayed
% in the results screen
set(guiHandles.mainButtonInfo,...
    'String','Now Select Axis')
axis = questdlg('Select Axis',...
    'Select Axis','Vertical','Horizontal','Other','Other');
% if empty stop
if isempty(axis)
    close(guiHandles.figure);
    return
end

if strcmp(axis,'Other')
    axis = inputdlg('Enter Axis');
end

set(guiHandles.mainButtonInfo,...
    'String','Click here to teach Reference Frame')

% create the haptics reference frame
feval(@createReference)

%% function to create the haptics reference frame
    function createReference(hObject,eventData)
        feval(@createReferenceFrame,hgs,guiHandles.reportsDir)
        % wait till the create reference frame window is closed
        uiwait()
        if (exist(referenceframe_file,'file') == 2)
            frame = load(referenceframe_file);
            set(guiHandles.mainButtonInfo,...
                'String','Place the EE ball in the Foce Guage Socket',...
                'Callback',@apply_foce)
        else
            warndlg(...
                {'Reference frame file does not exist(frame.mat)';...
                'Use main button to create reference'})
            set(guiHandles.mainButtonInfo,...
                'String','Click here to create reference frame',...
                'Callback',{@createReference,hgs,guiHandles.reportsDir})
        end
    end

%% GUI
common_properties = struct(...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'FontSize',0.3);

text0 = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.05,0.65,0.45,0.2],...
    'FontSize',0.3,...
    'String','Haptic Force (N):');

text1 = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.5,0.65,0.3,0.2],...
    'FontSize',0.32,...
    'String','0');

h_haptic = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.05,0.5,0.25,0.12],...
    'String','Force, Robot (N)');

h_forceguage = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.05,0.35,0.25,0.12],...
    'String','Force, Gauge (N)');

h_transparency = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.05,0.2,0.25,0.12],...
    'String','Transparency (%)');

h_haptic_pos = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.3,0.5,0.25,0.12],...
    'String','0');

h_guage_pos = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.3,0.35,0.25,0.12],...
    'String','0');

h_transparency_pos = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.3,0.2,0.25,0.12],...
    'String','0');
%%%
h_haptic_neg = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.6,0.5,0.25,0.12],...
    'String','0');

h_guage_neg = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.6,0.35,0.25,0.12],...
    'String','0');

h_transparency_neg = uicontrol(guiHandles.uiPanel,...
    common_properties,...
    'Position',[0.6,0.2,0.25,0.12],...
    'String','0');

% recompute TCP
hrecomputeTCP = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.78,0.05,0.2,0.06],...
    'FontSize',0.4,...
    'String','recompute TCP',...
    'Callback',{@computeTCP,hgs});

%%
    function apply_foce(hObeject,eventData)
        global haptic_state;

        % POSITIVE DIRECTION
        set(guiHandles.mainButtonInfo,...
            'String','Apply 20N force in +Ve direction. Click when Done',...
            'Callback',@check_done)

        % Apply 20N force in the positive direction using the force gage
        % slider on the system test fixture
        force_guage_pos = 20; %20N

        % now determine the haptic force applied by the robot
        z_depth = [0 0.2];
        feval(@create_haptic_wall,z_depth);
        pause(0.1)
        done = 0;
        force_haptic_pos = 0;
        while ~done
            pause(0.1);
            for n = 1:6
                state = get(haptic_state);
                f(n,:) = state.forceLocal*stiffness;
                motor_curr_positive(n,:) = hgs.motor_currents;
                commanded_curr_positive(n,:) = hgs.commanded_currents;
                pause(0.1);
                set(text1,'String',num2str(f(n,3)));
            end
            
            % the motor current and the commanded current value is saved
            % for reference and troubleshooting.
            motor_curr_positive = mean(motor_curr_positive);
            commanded_curr_positive = mean(commanded_curr_positive);
            f = mean(f);
            force_haptic_pos = f(3);
            % resultant force in the orthogonal direction
            fortho = norm([f(1),f(2)]);
            if fortho < 1.0 % less than 1 Newton force (this is 5% of the 20N force applied)
                % display z direction haptic force
                set(h_haptic_pos,'String',num2str(force_haptic_pos));
                % determing the robot configuration (lefty or righty)
                joint_angles= get(hgs, 'joint_angles');
                if joint_angles(3) > 0
                    configuration = 'LEFTY';
                end
            else
                hwarn = warndlg({'Force sensed in X and Y direction',...
                    ['Resultant force in XY: ',num2str(fortho),' N'],...
                    'Reteach Reference Frame!'});
                uiwait(hwarn);
                close(guiHandles.figure)
                return
            end
        end

        set(h_guage_pos,...
            'String',num2str(force_guage_pos))

        transparency_pos = abs(force_guage_pos/force_haptic_pos);

        set(h_transparency_pos,...
            'String',num2str(transparency_pos*100))

        %NEGATIVE DIRECTION
        set(guiHandles.mainButtonInfo,...
            'String','Now Apply 20N force in -Ve direction. Click when Done',...
            'Callback',@check_done)

        % Apply 20N force in the negaitve direction using the force gage
        % slider on the system test fixture
        force_guage_neg = 20; %20N

        % now determine the haptic force applied by the robot
        z_depth = [0.0 -0.2];
        feval(@create_haptic_wall,z_depth);
        pause(0.1)
        done = 0;
        force_haptic_neg = 0;
        while ~done
            pause(0.1);
            for n = 1:6
                state = get(haptic_state);
                f(n,:) = state.forceLocal*stiffness;
                motor_curr_negative(n,:) = hgs.motor_currents;
                commanded_curr_negative(n,:) = hgs.commanded_currents;
                pause(0.1);
                set(text1,'String',num2str(f(n,3)));
            end
            
            % the motor current and the commanded current value is saved
            % for reference and troubleshooting.
            motor_curr_negative = mean(motor_curr_negative);
            commanded_curr_negative = mean(commanded_curr_negative);
            
            f = mean(f);
            force_haptic_neg = f(3);
            set(h_haptic_neg,'String',num2str(force_haptic_neg));

            % resultant force in the orthogonal direction
            fortho = norm([f(1),f(2)]);
            if fortho < 1.0 % less than 1 Newton force
                set(h_haptic_pos,'String',num2str(force_haptic_pos));
            else
                hwarn = warndlg({'Force sensed in X and Y direction',...
                    ['Resultant force in XY: ',num2str(fortho),' N'],...
                    'Reteach Reference Frame!'});
                uiwait(hwarn);
                close(guiHandles.figure)
                return
            end
        end

        set(h_guage_neg,...
            'String',num2str(force_guage_neg))

        transparency_neg = abs(force_guage_neg/force_haptic_neg);

        set(h_transparency_neg,...
            'String',num2str(transparency_neg*100))

        % done, now go to zerogravity
        mode(hgs,'zerogravity','ia_hold_enable',0)

        % save resutls before we call it a day
        save(fullDataFileName,...
            'force_haptic_pos',...
            'force_guage_pos',...
            'transparency_pos',...
            'motor_curr_positive',...
            'commanded_curr_positive',...
            'force_haptic_neg',...
            'force_guage_neg',...
            'transparency_neg',...
            'motor_curr_negative');

        set(text0,'String','Force Transparency');
        set(text1,'String',[axis, ' Axis']);

        % check if transparency is greater than 100%. This happens
        % sometimes if the gravity is over compensated.
        % If transparency is less than 100%, check if it within the limits.
        
        LogResults.TransparencyUpperLimit = UPPERLIMIT;
        LogResults.TransparencyLowerLimit = WARNING;
        if ~isfield(LogResults,'TransparencyPositive')
            LogResults.TransparencyPositive = [];
        end
        LogResults.TransparencyPositive = [LogResults.TransparencyPositive...
            transparency_pos*100];
        if ~isfield(LogResults,'TransparencyNegative')
            LogResults.TransparencyNegative = [];
        end
        LogResults.TransparencyNegative = [LogResults.TransparencyNegative...
            transparency_neg*100];

        if abs(transparency_pos*100) > UPPERLIMIT || abs(transparency_neg*100) > UPPERLIMIT
            presentMakoResults(guiHandles,'FAILURE',...
                {['Robot Configuration ',configuration],...
                 ['Transparency cannot be greater than ',num2str(UPPERLIMIT)],...
                 'Check Gravity Comp',...
                ['Transparency Positive: ',num2str(transparency_pos*100)],...
                ['Transparency Negative: ',num2str(transparency_neg*100)]})
            log_results(hgs,guiHandles.scriptName,'FAIL',...
                'Force Transparency Test Failed',LogResults);
        else

            if abs(transparency_pos*100) > THRESHOLD && abs(transparency_neg*100) > THRESHOLD
                presentMakoResults(...
                    guiHandles,'SUCCESS',...
                    ['Robot Configuration ',configuration])
                log_results(hgs,guiHandles.scriptName,'PASS',...
                    'Force Transparency Test was Successful',LogResults);
            elseif abs(transparency_pos*100) > WARNING && abs(transparency_neg*100) > WARNING
                presentMakoResults(...
                    guiHandles,'WARNING',...
                    {['Robot Configuration ',configuration],...
                    ['Transparency Positive: ',sprintf('%4.2f%%', transparency_pos*100)],...
                    ['Transparency Negative: ', sprintf('%4.2f%%', transparency_neg*100)],...`
                    ['LIMIT ',num2str(THRESHOLD),'%']})
                log_results(hgs,guiHandles.scriptName,'WARNING',...
                    'Force Transparency Test passed with a warning',...
                    LogResults);
            else
                presentMakoResults(...
                    guiHandles,'FAILURE',...
                    {['Robot Configuration ',configuration],...
                    ['Transparency Positive: ',sprintf('%4.2f%%', transparency_pos*100)],...
                    ['Transparency Negative: ', sprintf('%4.2f%%', transparency_neg*100)],...
                    ['LIMIT ',num2str(WARNING),'%']})
                log_results(hgs,guiHandles.scriptName,'FAIL','Force Transparency Test Failed',...
                    LogResults);
            end
        end
    end
%% Main Function
    function create_haptic_wall(hObject,eventData)
        % Delete previous haptic ic objects and reference frames
        reset(hgs);

        % Define X and Y haptics bounds
        % Format: vertices = [x1 x2 x3 x4 x1 y1 y2 y3 y4 y1]
        x = 0.1;
        y = 0.1;
        vertices = [-x, x, x, -x, -x, -y, -y, y, y, -y];
        numVerts = length(vertices)/2;

        % haptic refernce frame,
        T = eye(4);
        T(1:3,1:3) = frame.frame;
        T(1:3,4) = frame.p_origin;
        objwrtref = T;
        objwrtref = objwrtref';

        % tool transform
        ee_tx = eye(4);
        ee_tx(1:3,4) = hgs.EE_ORIGIN';
        ee_tx = ee_tx';

        % rotation
        flateye = eye(4);

        objName = ['extruded_2Dpoly___',num2str(rand())];
        global haptic_state;
        haptic_state = hgs_haptic(hgs,objName,...
            'verts',vertices,...
            'numVerts',numVerts,...
            'stiffness',stiffness,...
            'damping',20.0,...
            'haptic_wrt_implant',flateye(:),...
            'obj_wrt_ref',objwrtref(:),...
            'forceMax',80,...
            'torqueMax',4,...
            'constrPlaneGain',42,...
            'start_end_cap',z_depth,...
            'constrPlaneNormal',[0.0 0.0 0.1],...
            'planarConstrEnable',0,...
            'safetyConstrEnable',0,...
            'safetyPlaneNormal',[0.0 0.0 1.0],...
            'safetyConstrDir',1,...
            'planarConstrDir',1 ...
            );

        jtobjName = ['JtDamp___',num2str(rand())];
        hgs_haptic(hgs,jtobjName,...
            'Kd',[0.2 0 0 0.0 0.0 0.05]...
            )

        mode(hgs,'haptic_interact',...
            'vo_and_frame_list',{objName,jtobjName},...
            'end_effector_tx',ee_tx(:)...
            );

    end

    function check_done(hObject,eventData)
        done = 1;
    end
%% Close request function
    function closeRequestFunction(varargin)
        log_message(hgs,'Force Transparency Script Closed');
        % Put robot in zeroG mode
        mode(hgs,'zerogravity','ia_hold_enable',0);
        % close figure by calling closerequest function
        closereq
    end
end

%------------- END OF FILE ----------------
