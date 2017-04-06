function find_homing_constants(hgs)
%FIND_HOME_CONSTANTS Gui to help to find homing constants of the hgs robot.
%
% Syntax:
%   find_home_constants(hgs)
%       Starts the find homing constants for the hgs robot
%
% Notes:
%   This script only find the homing constants of joint 5.
%
% See also:
%   hgs_robot
%
%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

%% Setup Script Identifiers for generic GUI
scriptName = 'Find Homing Constants';
try
    % If no arguments are specified create a connection to the default
    % hgs_robot
    if nargin<1
        hgs = connectRobotGui;
        if isempty(hgs)
            return;
        end
    end
    
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');
    
    %% Generic GUI for Service Scripts
    guiHandles = generateMakoGui(scriptName,[],hgs);
    log_message(hgs,'Find Homing Constants Started');
    
    % Setup the main function
    set(guiHandles.mainButtonInfo,'CallBack',@find_homing_constants_callback);
    
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@find_homing_constants_close);
    
    %define joint 5 physical range of motion
    RANGE_OF_MOTION=hgs.JOINT_ANGLE_MAX - hgs.JOINT_ANGLE_MIN;
    RANGE_OF_MOTION_LIMIT=[2,2,2,4,4,4]/180*pi;
    OFFSET_KINEMATIC_ZERO=-1*hgs.JOINT_ANGLE_MIN;
    OFFSET_KINEMATIC_ZERO(4) = hgs.JOINT_ANGLE_MAX(4);
    %set proper KZ for 2.1 robot
    version = hgs.ARM_HARDWARE_VERSION;
 
    switch int32(version * 10 + 0.05)
        case 20 % 2.0
            % do nothing
        case 21 % 2.1
            OFFSET_KINEMATIC_ZERO(6) = hgs.JOINT_ANGLE_MAX(6);
        case 22 % 2.2
            OFFSET_KINEMATIC_ZERO(6) = hgs.JOINT_ANGLE_MAX(6);
        case 23 % 2.3
            OFFSET_KINEMATIC_ZERO(6) = hgs.JOINT_ANGLE_MAX(6);
        case 30 % 3.0
            OFFSET_KINEMATIC_ZERO(6) = hgs.JOINT_ANGLE_MAX(6);
        case 31 % 3.1
            OFFSET_KINEMATIC_ZERO(6) = hgs.JOINT_ANGLE_MAX(6);
        otherwise
            % Generate the gui
            presentMakoResults(guiHandles,'FAILURE',...
                sprintf('Unsupported Robot version: V%2.1f',version));
            log_results(hgs,guiHandles.scriptName,'FAIL',sprintf('Unsupported Robot version: V%2.1f',version));
            return;
    end
    
    %% set addttional GUI
    dof=hgs.WAM_DOF;
    
    xMin = 0.02;
    xRange = 0.95;
    yRange = 0.1;
    spacing = 0.005;
    %%set up display text location
    commonTextProperties =struct(...
        'Style','text',...
        'Units','normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'FontSize',0.6,...
        'HorizontalAlignment','Left',...
        'backgroundColor',[0.7,0.7,0.7]);
    
    %%set up display text location
    commonEditProperties =struct(...
        'Style','edit',...
        'Units','normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'FontSize',0.3,...
        'Enable','inactive',...
        'String','---',...
        'HorizontalAlignment','Left');
    %add text
    yMin=0.75;
    for i=1:dof
        position = [xMin+(xRange+spacing)*(i-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        uicontrol(guiHandles.uiPanel,...
            commonTextProperties,...
            'Position',[xMin yMin xRange yRange],...
            'HorizontalAlignment','Center',...
            'FontSize',0.8,...
            'String',sprintf('J%d',i),...
            'Position',position...
            );
    end
    %add edit
    yMin=0.60;
    yRange=0.1;
    for i=1:dof %#ok<FXUP>
        position = [xMin+(xRange+spacing)*(i-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        homingConstantsEdit(i) = uicontrol(guiHandles.uiPanel,...
            commonEditProperties,...
            'Position',position...
            ); %#ok<AGROW>
    end
    
    %region plots to indidate the progress
    yMin=0.2;
    yRange=0.3;
    basePatch=zeros(dof,1);
    regionCoveredPatch=zeros(dof,1);
    dispAxis=zeros(dof,1);
    
    for i=1:dof
        % generate a region to plot
        position = [xMin+(xRange+spacing)*(i-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        dispAxis(i) = axes(...
            'Parent',guiHandles.uiPanel,...
            'XLim',[-1.2 1.2],...
            'YLim',[-1.2 1.2],...
            'Box','off',...
            'ytick',[],...
            'xtick',[],...
            'Position',position,...
            'Visible','off');
    end
    %initialization
    isFindHomingConstantsCanceled=false;
    jointStopEncoder=zeros(dof,2);
    jointStopAngle=zeros(dof,2);
    setHomingConstantsSucceed=zeros(1,dof);
    homeConstantsOffset=zeros(1,dof);
    homeConstants=zeros(1,dof);
    homeConstantErrorMsg=[];
    jointCalculatedRangeOfMotion=zeros(1,dof);
    homeConstantErrorMsg='';
catch
    isFindHomingConstantsCanceled=false;
    findHomingconstantsErrorHandling();
end


%%
%find homing constants callback
    function find_homing_constants_callback(varargin)
        ii=0;
        updateConstant=zeros(dof,1);
        try
            
            % Check if the arm version number matches if not error immediately
            if hgs.ARM_HARDWARE_VERSION<2.0
                presentMakoResults(guiHandles,'FAILURE',...
                    sprintf('Unsupported Robot version %2.2f',hgs.ARM_HARDWARE_VERSION));
            end
            %get into the routine where user has to press the
            %flashing green button
            robotFrontPanelEnable(hgs,guiHandles);
            
            %put the arm in zero gravity, notice this is using the nominal
            %gravity constants and homing constants.
            updateMainButtonInfo(guiHandles,'text',...
                {'Move robot arm to reach all joint stops'});
            pause(1);
            mode(hgs,'zerogravity','ia_hold_enable',0);
            
            %intialize the encoder and joint value
            jointStopEncoder(:,1)=hgs.joint_encoder;
            jointStopEncoder(:,2)=jointStopEncoder(:,1);
            jointStopAngle(:,1)=hgs.joint_angles;
            jointStopAngle(:,2)=jointStopAngle(:,1);
            
            % Generate the require patches
            for j=1:dof
                basePatch(j) = patch(0,0,'white','parent',dispAxis(j));
                regionCoveredPatch(j) = patch(0,0,'green','parent',dispAxis(j));
                % set axis aspect ratio so that pie plot is always circular
                axis(dispAxis(j),'equal');
                %draw the patch
                [x,y] = generateArcPoints(0,RANGE_OF_MOTION(j));
                set(basePatch(j),'XData',x,'YData',y);
            end
            
            jointCountPerRev=hgs.JE_COUNTS_PER_REVOLUTION;
            
            while(~isFindHomingConstantsCanceled)
                
                tempJointEncoder=hgs.joint_encoder;
                tempJointAngle=hgs.joint_angles;
                jointEncoderAtLastIndex=hgs.je_at_last_index;
                
                for j=1:dof
                    if(tempJointEncoder(j)>jointStopEncoder(j,1))
                        %Move Joint to the first joint stop
                        jointStopEncoder(j,1)=tempJointEncoder(j);
                        jointStopAngle(j,1)=tempJointAngle(j);
                    end
                    
                    %Move Joint to another joint stop
                    if(tempJointEncoder(j)<=jointStopEncoder(j,2))
                        jointStopEncoder(j,2)=tempJointEncoder(j);
                        jointStopAngle(j,2)=tempJointAngle(j);
                    end
                    
                    %compute and verify the range of motion
                    jointCalculatedRangeOfMotion(j)=abs(jointStopAngle(j,2)-jointStopAngle(j,1));
                    
                    % Reset the plots
                    [x,y] = generateArcPoints(0,jointCalculatedRangeOfMotion(j));
                    set(regionCoveredPatch(j),'XData',x,'YData',y);
                    
                    %compute kinematics zeros if ROM is within the limit
                    if(abs(jointCalculatedRangeOfMotion(j)-RANGE_OF_MOTION(j))<...
                            RANGE_OF_MOTION_LIMIT(j))
                        updateConstant(j)=1;
                    end
                    
                    if(updateConstant(j))
                        homeConstantsOffset(j)=jointStopEncoder(j,2)+...
                            int32(OFFSET_KINEMATIC_ZERO(j)/2/...
                            pi*abs(jointCountPerRev(j)));
                        homeConstants(j)=-jointEncoderAtLastIndex(j)+...
                            homeConstantsOffset(j);
                        %update GUI
                        set(homingConstantsEdit(j),'String',sprintf('%d',homeConstants(j)),...
                            'BackgroundColor','g');
                        
                        %give some time for last joint to reach end stop
                        if(sum(setHomingConstantsSucceed)==dof-1 && setHomingConstantsSucceed(j)==false)
                            ii=ii+1;
                            if ii>100
                                setHomingConstantsSucceed(j)=true;
                            end
                        else
                            setHomingConstantsSucceed(j)=true;
                        end
                    end
                    
                    
                    %update patch color
                    if(setHomingConstantsSucceed(j))
                        set(regionCoveredPatch(j),'facecolor','g');
                    else
                        set(regionCoveredPatch(j),'facecolor','y');
                    end
                end
                pause(0.01);
                %check if there is an error
                if hgs.ce_error_code(1)>0
                    stateAtLastError=commDataPair(hgs,'get_state_at_last_error');
                    homeConstantErrorMsg=sprintf('%s(J%d)',...
                        stateAtLastError.error_msg{1},stateAtLastError.error_axis+1);
                    break;
                end
                %set complete flag and exit
                if setHomingConstantsSucceed
                    break;
                end
            end
            
        catch
            findHomingconstantsErrorHandling();
        end
        
        %check and report result,
        if(~isFindHomingConstantsCanceled)
            if(setHomingConstantsSucceed)
                for j=1:5
                    displayText=sprintf('%s %d %s','Brakes engage in ',5-j,' seconds');
                    updateMainButtonInfo(guiHandles,'text',...
                        {'Move Robot Arm To Home Position',displayText});
                    pause(1);
                end
                %save the data no matter pass or fail
                fileName =[sprintf('homing-constants-%s-',hgs.name),...
                    datestr(now,'yyyy-mm-dd-HH-MM')];
                myDataFileName=fullfile(guiHandles.reportsDir,fileName);
                
                save(myDataFileName, 'homeConstants' ,'jointStopAngle','jointStopEncoder');
                
                % create structure for logging
                Results.homeConstants = homeConstants;
                
                %update homing constants
                hgs.JE_OFFSET_AT_INDEX = homeConstants;
                %restart crisis to update the constants
                stop(hgs);
                pause(1);
                restartCRISIS(hgs);
                pause(3);
                mode(hgs,'zerogravity','ia_hold_enable',0);
                presentMakoResults(guiHandles,'SUCCESS',...
                    {'Homing Constants updated successfully','Hold ENABLE button to enable robot arm'});
                log_results(hgs, guiHandles.scriptName, 'PASS', 'The script passed',Results);
            else
                presentMakoResults(guiHandles,'FAILURE',...
                    homeConstantErrorMsg);
                Results.homeConstantErrorMsg = homeConstantErrorMsg;
                log_results(hgs, guiHandles.scriptName, 'FAIL', 'The script failed',Results);
            end
        end
    end
%--------------------------------------------------------------------------
% internal function to generate the patch points for an arc
%--------------------------------------------------------------------------
    function [arcXpts, arcYpts] = generateArcPoints(minAng,maxAng)
        resAng = (maxAng-minAng)/100;
        t = minAng:resAng:maxAng;
        % generate the arc and stick a (0,0) at the end to make it join at the
        % center of the circle
        arcXpts = [sin(t) 0];
        arcYpts = [cos(t) 0];
    end
%--------------------------------------------------------------------------
%   Internal function to close the figures when cancel button is pressed
%--------------------------------------------------------------------------
    function find_homing_constants_close(varargin)
        log_message(hgs,'Find Homing Constants script closed');
        %set cancel flag
        isFindHomingConstantsCanceled=true;
        %close all figures
        closereq;
    end
%--------------------------------------------------------------------------
%Internal function to represent catch error message
%--------------------------------------------------------------------------
    function findHomingconstantsErrorHandling()
        %an error occured, get error message and set fail flag
        homeConstantError=lasterror;
        homeConstantErrorMsg=homeConstantError.message;
        if(~isFindHomingConstantsCanceled)
            presentMakoResults(guiHandles,'FAILURE',...
                homeConstantErrorMsg);
        end
    end
end



% --------- END OF FILE ----------
