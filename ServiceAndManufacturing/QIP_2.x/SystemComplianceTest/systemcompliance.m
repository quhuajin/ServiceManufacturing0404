function guiHandles = systemcompliance(varargin)
%
% SYSTEMCOMPLIANCE check the system level compliance of hgs robot by
% comparing the deflection under force measured by the robot against a
% microscribe (a portable CMM device)
%
% Syntax:
%   systemcompliance(hgs)
%       argument hgs specifies the hgs_robot to be used
%
% Requirements:
%   A microscribe should be connected to the test computer.
%
% Test Description:
%   The robot is put in the 'hold position mode' with the Calibration End
%   Effector on. A microscribe (with special magnetic socket) is connected
%   to the Ball A of the end effector. A predetermined amount of force
%   (30N) is applied in the +X, -X, +Y, -Y (on Ball B) and -Z and +Z (on
%   Ball A, to deflect J6). In each direction, the deflection measured by
%   the robot and the microscribe is captured. The difference in the
%   deflection is the compliance in the particular direction.
%
% Pass Criteria:
%   The compliance in individual direction should be less than the
%   COMPLIANCE LIMIT set by the System Requirement, which is 0.035mm/N.
%   At 20N, this translates to 0.70mm. A warning limit is set at 0.6mm.

% $Author: adanilchenko $
% $Revision: 4155 $
% $Date: 2017-02-08 16:54:08 -0500 (Wed, 08 Feb 2017) $
% Copyright: MAKO Surgical corp 2008

%% set up variables
hgs = '';
pose.robot1 = [];
pose.scribe1 = [];
pose.robot2 = [];
pose.scribe2 = [];
done = false;
isCancelled = false;
test_begin = false;

settledown_time = 6;
%% result structure
result.measurements = [];
result.passfail_compliance = 'PASS';
result.passfail_hysteresis = 'PASS';

% flags 
count = 0; 
side = 'Righty'; %default side

%% limits
% stiffness requirement is 0.035mm/N
% allowable deflection for 20N force = 0.035*20 = 0.70 mm
COMPLIANCE_LIMIT = 0.56; %mm (80% of pass)
HYSTERESIS_LIMIT = 0.56; %mm
COMPLIANCE_WARNING = 0.70; %mm
HYSTERESIS_WARNING = 0.70; %mm
compliance = 0;
hysteresis = 0;
%%
if(nargin == 0)
    % If no arguments are specified create a connection to the default
    % hgs_robot
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles = '';
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

% activate micro scribe
hwait = waitbar(0,'Connecting to Microscribe. Please Wait...');
msArm = mscribe();
if isa(msArm,'mscribe')
    waitbar(1,hwait, 'Microscribe Connected.');
    pause(.1)
    close(hwait);
else
    error('Error Connecting To MicroScribe or Loading Library')
    guiHandles = '';
    return   
end
    
% generate GUI
scriptName = 'System Compliance Test';
guiHandles = generateMakoGui(scriptName,[],hgs,1);
log_message(hgs,'System Complaice Script Started');
% Check if Homing is complete
robotFrontPanelEnable(hgs,guiHandles);
if ~homingDone(hgs)
    presentMakoResults(guiHandles,'FAILURE','Homing Not Done');
    log_results(hgs,guiHandles.scriptName,'ERROR',...
        'System Compliance Failed (Homing not done)');
    return;
end
        
%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

set(guiHandles.mainButtonInfo,...
    'Callback',@beginComplianceTest);

% generate results data file name, and safe data file
dataFileName=['Compliance-System',...
    hgs.name,'-',...
    datestr(now,'yyyy-mm-dd-HH-MM')];
fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);

% clsoe request function, used to close diff functions when cancel button
% is pressed from the GUI
set(guiHandles.figure,...
    'CloseRequestFcn',@closeFigure...
    );
%% GUI Set up
hZeroG = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.84,0.02,0.16,0.06],...
    'FontSize',0.5,...
    'String','Zero G',...
    'Callback',@ZeroG);

    function ZeroG(hObject, eventdata)
        mode(hgs,'zerogravity','ia_hold_enable',0);
    end

hHoldPos = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.84,0.1,0.16,0.06],...
    'FontSize',0.5,...
    'String','Hold Pos',...
    'Callback',@holdPos);

    function holdPos(hObject, eventdata)
        mode(hgs,'hold_position');
    end

hUndo = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.84,0.18,0.16,0.06],...
    'FontSize',0.5,...
    'String','Un-do',...
    'Callback',@undo);

commonTextProperties = struct(...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'FontWeight','normal');

COMPLIANCE = 1;
HYSTERESIS = 2;
for n = 1:2
    if n == COMPLIANCE
        disp_offset = 0;
    end
    if n == HYSTERESIS
        disp_offset = 0.45;
    end
    hCompliance = uicontrol(guiHandles.uiPanel,...
        commonTextProperties,...
        'Position',[0.38,0.84-disp_offset,0.4,0.1],...
        'String','Compliance (mm)');
    width = 0.2;
    height = 0.06;
    for row = 1:3
        for column = 1:4
            x = 0.15 + (width*0.8)*(column -1);
            y = (0.85-disp_offset) - (height*1.05)*row;
            if n == COMPLIANCE
                text_compliance(row,column) = uicontrol(guiHandles.uiPanel,...
                    commonTextProperties,...
                    'Position',[x,y,width,height],...
                    'String','+0.000');
            end
            if n == HYSTERESIS
                text_hysteresis(row,column) = uicontrol(guiHandles.uiPanel,...
                    commonTextProperties,...
                    'Position',[x,y,width,height],...
                    'String','+0.000');
            end
        end
    end
    if n == 2
        set(hCompliance,'String','Hysteresis (mm)');
    end
end

% populate text box, compliance
set(text_compliance(1,1),'String','');
set(text_compliance(1,2),'String','X');
set(text_compliance(1,3),'String','Y');
set(text_compliance(1,4),'String','Z');

set(text_compliance(2,1),'String','Pos (+)');
set(text_compliance(3,1),'String','Neg (-)');

% populate text box, hysteresis
set(text_hysteresis(1,1),'String','');
set(text_hysteresis(1,2),'String','X');
set(text_hysteresis(1,3),'String','Y');
set(text_hysteresis(1,4),'String','Z');

set(text_hysteresis(2,1),'String','Pos (+)');
set(text_hysteresis(3,1),'String','Neg (-)');

try
    while (~isCancelled && ~test_begin)
        if(hgs.joint_angles(3) > 0)
            side = 'Lefty';
        else
            side = 'Righty';
        end
        
        set(guiHandles.mainButtonInfo,...
            'string',['Click Here To Start System Compliance Test Procedure (' side ')']);
        text_comp_side = uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.04,0.7-0,0.12,0.06],...
            'String',side);
        text_hist_side = uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[0.04,0.7-.45,0.12,0.06],...
            'String',side);
        pause(2);
    end
catch
    % check if this was a cancel press
    if isCancelled
        return;
    else
        presentMakoResults(guiHandles,'FAILURE', ...
            {['Side: ' side]; ...
            [lasterr]}); %#ok<*LERR>
        log_results(hgs,guiHandles.scriptName,'ERROR',['System Compliance ' side ' failed ( ' lasterr,')']);
        return;
    end
end

%% begin compliance test
    function beginComplianceTest(hObject,eventdata)
        test_begin = true;
        % before using the microscribe for measurement, perform a pivot
        % check to make sure that the scribe accuarcy is good.
        h = pivotCheck(msArm);
        % close the pivot check window after 10 measurements
        result_pivot = get(h,'UserData');
        while(result_pivot.count <10)
            try
                % get pivot measurement
                result_pivot = get(h,'UserData');
            catch
                % if the pivot check window was closed before 10
                % measurement, set rms to zero and number of measurements
                % greater than 10
                result_pivot.rms = 0;
                result_pivot.count = 11;
                clear h
            end
            pause(0.2)
        end
        % close the pivot check window
        if exist('h','var')
            close(h)
            clear h
        end

        % check if the scribe is any good. If not, display error!
        % the limit is 0.2mm, rms
        if(result_pivot.rms > 0.2)
            % if bad, prompt for another pivot check
            set(guiHandles.mainButtonInfo,...
                'String',['Scribe no good. RMS: ',num2str(result_pivot.rms),...
                '. Try pivot check again'],...
                'BackgroundColor','red')
        else
            % if good, proceed to main
            set(guiHandles.mainButtonInfo,...
                'String',['Click to begin ' side ' data collection'],...
                'Callback',@main,...
                'BackgroundColor',[212/255,202/255,200/255])
        end
    end

    mode(hgs,'hold_position');

%% take measurements   
    function main(hObject,eventdata)
        
        textupdate = {'Apply 20 N on Ball B in +X direction. Click when Done';
            'Apply 20 N on Ball B in -X direction. Click when Done';
            'Apply 20 N on Ball B in +Y direction. Click when Done';
            'Apply 20 N on Ball B in -Y direction. Click when Done';
            'Apply 20 N on Ball B in +Z direction. Click when Done';
            'Apply 20 N on Ball B in -Z direction. Click when Done'};

        % status
        done = 0;
        
        % Tool tip definition, Callibration End Effector, Ball A
        balltransform = eye(4);
        balltransform(1:3,4) = hgs.CALIB_BALL_A';

        while count < 6
            count = count + 1;
            % select result display box
            switch count
                case 1
                    dispbox = [2,2];
                case 2
                    dispbox = [3,2];
                case 3
                    dispbox = [2,3];
                case 4
                    dispbox = [3,3];
                case 5
                    dispbox = [2,4];
                case 6
                    dispbox = [3,4];
            end
            
            % measure reference pose
            set(guiHandles.mainButtonInfo,...
                'Callback',@done_measure)
            set(hUndo,'enable','on');
            if count == 1;
                set(guiHandles.mainButtonInfo,...
                    'String','Take initial measurement')
                done = false;
                while ~done
                    pause(0.2)
                    ballposition =  reshape(hgs.flange_tx,4,4)'*balltransform;
                    pose.robot1 = ballposition(1:3,4);
                    [pose.scribe1 status] = get(msArm,'position');
                    pose.scribe1 = pose.scribe1/1000;
                    if status ~=0
                        presentMakoResults(guiHandles,'FAILURE', ...
                            {['Microscibe Communication Faulty. Restart Test']; ...
                            ['Side: ' side]});
                        return;
                    end
                    
                end
            else
                ballposition =  reshape(hgs.flange_tx,4,4)'*balltransform;
                pose.robot1 = ballposition(1:3,4);
                [pose.scribe1 status] = get(msArm,'position');
                pose.scribe1 = pose.scribe1/1000;
                if status ~=0
                    presentMakoResults(guiHandles,'FAILURE',...
                        {['Microscibe Communication Error. Restart Test']; ...
                        ['Side: ' side]});
                    log_results(hgs,guiHandles.scriptName,'ERROR',...
                        ['System Compliance ' side ' failed (Microscibe Communication Error)']);
                    return;
                end
            end
            
            % measure with force applied, for compliance
            done = false;
            set(guiHandles.mainButtonInfo,...
                'String',textupdate{count},...
                'Callback',@done_measure)
            
            %initiate compliance to zero
            compliance = 0;
            while ~done
                if isCancelled
                    return
                end
                pause(0.2)
                ballposition =  reshape(hgs.flange_tx,4,4)'*balltransform;
                pose.robot2 = ballposition(1:3,4);
                [pose.scribe2 status] = get(msArm,'position');
                pose.scribe2 = pose.scribe2/1000;
                if status ~=0
                    presentMakoResults(guiHandles,'FAILURE',...
                        {['Microscibe Communication Error. Restart Test']; ...
                        ['Side: ' side]});
                    log_results(hgs,guiHandles.scriptName,'ERROR',...
                        ['System Compliance ' side ' failed (Microscibe Communication Error)']);
                    return;
                end
                
                robotdelta = norm(pose.robot1-pose.robot2);
                scribedelta = norm(pose.scribe1 - pose.scribe2);
                delta = abs(scribedelta-robotdelta)*1000; %in mm
                
                if abs(delta) > abs(compliance) %peak mode
                    compliance = delta;
                end
                
                if(abs(compliance) < COMPLIANCE_LIMIT)
                    bgColor = 'green';
                elseif(abs(compliance) < COMPLIANCE_WARNING)
                    bgColor = 'yellow';
                    result.passfail_compliance = 'WARNING';
                else
                    bgColor = 'red';
                    result.passfail_compliance = 'FAIL';
                end
                set(text_compliance(dispbox(1),dispbox(2)),...
                    'String',num2str(compliance),...
                    'BackgroundColor',bgColor);
            end
            
            set(hUndo,'enable','off');
            % measure scribe position with force released, for hysterysis
            % wait for 2-3 seconds for settle down (this is the
            % settling time for KI loop on the controller)
            for wait = settledown_time:-1:1
                set(guiHandles.mainButtonInfo,...
                    'String',['Steady... ',num2str(wait)]);
                pause(1)
            end
            
            ballposition =  reshape(hgs.flange_tx,4,4)'*balltransform;
            pose.robot3 = ballposition(1:3,4);
            
            [pose.scribe3 status] = get(msArm,'position');
            pose.scribe3 = pose.scribe3/1000;
            if status ~=0
                presentMakoResults(guiHandles,'FAILURE',...
                    'Microscibe Communication Error. Restart Test');
                log_results(hgs,guiHandles.scriptName,'ERROR',...
                    ['System Compliance ' side ' failed (Microscibe Communication Error)']);
                return;
            end
            
            hysteresis = norm(pose.scribe1 - pose.scribe3)*1000; %in mm
            
            LogResults.ComplianceLimit = COMPLIANCE_WARNING;
            LogResults.ComplianceXYZ(count) = compliance;
            LogResults.HystersisLimit = HYSTERESIS_WARNING;
            LogResults.HysteresisXYZ(count) = hysteresis;
            
            if(abs(hysteresis) < HYSTERESIS_LIMIT)
                bgColor = 'green';
            elseif(abs(hysteresis) < HYSTERESIS_WARNING)
                bgColor = 'yellow';
                result.passfail_hysteresis = 'WARNING';
                
            else
                bgColor = 'red';
                result.passfail_hysteresis = 'FAIL';
                
            end
            set(text_hysteresis(dispbox(1),dispbox(2)),...
                'String',num2str(hysteresis),...
                'BackgroundColor',bgColor);
            
            result.measurements(count).pose=pose;
            save (fullDataFileName, 'result');
        end
        
        % display results
        if any(LogResults.ComplianceXYZ > COMPLIANCE_WARNING) || any(LogResults.HysteresisXYZ > HYSTERESIS_WARNING)
            presentMakoResults(guiHandles,'FAILURE',...
                {['COMPLIANCE FAIL LIMIT (mm) > ',num2str(COMPLIANCE_WARNING)];...
                ['HYSTERESIS FAIL LIMIT (mm) > ',num2str(HYSTERESIS_WARNING)]; ...
                ['Side: ', side]})
            log_results(hgs,guiHandles.scriptName,'ERROR',...
                ['System Compliance ' side ' Failed'],LogResults);
        elseif any(LogResults.ComplianceXYZ > COMPLIANCE_LIMIT) || any(LogResults.HysteresisXYZ > HYSTERESIS_LIMIT)
            presentMakoResults(guiHandles,'WARNING',...
                {['COMPLIANCE WARNING LIMIT (mm) > ',num2str(COMPLIANCE_LIMIT)];...
                ['HYSTERESIS WARNING LIMIT (mm) > ',num2str(HYSTERESIS_LIMIT)]; ...
                ['Side: ', side]})
            log_results(hgs,guiHandles.scriptName,'WARNING',...
                ['System Compliance ' side ' Passed with Warning'],LogResults);
        else
            strcmp(result.passfail_compliance,'PASS')
            presentMakoResults(guiHandles,'SUCCESS', ...
                ['Side: ', side])
            log_results(hgs,guiHandles.scriptName,'PASS',...
                ['System Compliance ' side ' was Successful'],LogResults);
        end
        
    end
%% 
    function done_measure(hObject,eventdata)
        done = 1;
    end

%% undo measurement function
    function undo(hObject, eventdata)
        compliance = 0;
        uicontrol(guiHandles.mainButtonInfo);
    end

%% Close request function
    function closeFigure(varargin)
        isCancelled = true;
        % Disconnect from microscribe
        disconnect(msArm); 
        log_message(hgs,'System Compliance Script Closed');
        % close figure by calling closerequest function
        closereq
    end

end

%------------- END OF FILE ----------------
