function guiHandles = home_hgs(hgs,grav)
%HOME_HGS Gui to help perfrom the homing procedure on the Hgs Robot.
%
% Syntax:
%   HOME_HGS(hgs)
%       Starts the homing GUI for performing homing on the hgs robot defined by
%       the argument hgs.  When the homing is completed, if successful the arm 
%       will be put in gravity mode.  If not the arm mode will not change 
%
%   HOME_HGS(hgs,grav)
%       Specifying the grav argument as the string 'no_grav' or logic false
%       will not put the arm in zerogravity even upon successful completion 
%       of the homing procedure
%
%   figHandle = home_hgs(hgs)
%       if the figure handle argument is specified the figure handle will
%       be returned to the calling function
%
% Notes:
%   The hgs_robot method home queries the hgs_robot to see if the homing is
%   performed or not
%   Homing is a necessary step in the intialization of the hgs robot.  This
%   establishes the absolute position of the robot using index markers.  Homing
%   is required only once per power up.
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home
%

%
% $Author: dmoses $
% $Revision: 3739 $
% $Date: 2015-01-16 17:38:50 -0500 (Fri, 16 Jan 2015) $
% Copyright: MAKO Surgical corp (2008)
%

%% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: home_hgs argument must be an hgs_robot object');
end

switch nargin
    case 1
        grav = true;
    case 2
        if islogical(grav)
            % do nothing just use the grav logical value
        elseif (strcmpi(grav,'no_grav'))
            % change to logical false
            grav = false;
        else
            error(['Invalid parameter for argument grav.  Should be ',...
                'logical (true/false) or the string ''no_grav''']);
        end
    otherwise
        error('Incompatible number of arguments for home_hgs');
end

% Setup Script Identifiers for generic GUI
scriptName = 'Homing';
guiHandles = generateMakoGui(scriptName,[],hgs);

userDataStruct.results=-1;
set(guiHandles.figure,'UserData',...
    userDataStruct);

% Setup the main function
set(guiHandles.mainButtonInfo,'CallBack',@homingProcedure);

% Initial values for homing
homingAbort = false;

% setup the cancel button
set(guiHandles.figure,'CloseRequestFcn',@cancelHoming);

%  Homing Specific GUI

meDof = hgs.ME_DOF;
jeDof = hgs.JE_DOF;

% Setup boundries for homing boxes
xMin = 0.1;
xRange = 0.8;
yMin = 0.2;
yRange = 0.20;
spacing = 0.02;

dof = max([meDof,jeDof]);

commonBoxProperties = struct(...
    'Style','edit',...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'background','white',...
    'SelectionHighlight','off',...
    'Enable','Inactive');

for i=1:meDof
    boxPosition = [xMin+(xRange+spacing)*(i-1)/dof,...
        yMin+spacing,...
        xRange/dof-spacing,...
        yRange];
    meBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'Position',boxPosition,...
        'String',sprintf('M%d',i)); %#ok<AGROW>
end

% Use same button construct except move the whole thing
% up in the ui
yMin = 0.6;
for i=1:jeDof
    boxPosition = [xMin+(xRange+spacing)*(i-1)/dof,...
        yMin+spacing,...
        xRange/dof-spacing,...
        yRange];
    jeBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'Position',boxPosition,...
        'String',sprintf('J%d',i)); %#ok<AGROW>
end


%% Homing Procedure
    function homingProcedure(varargin)
        
        % log the start of the procedure
        log_message(hgs,'Homing procedure started');
        
        % Check if the robot is enabled if not go into the enable
        % procedure, exit cleanly if cancel button is pressed during the
        % procedure.
        try
            if hgs.arm_status ~= 1
                if ~robotFrontPanelEnable(hgs,guiHandles)
                    % log the failure of the procedure
                    log_message(hgs,'Homing procedure failed to enable robotic arm.','ERROR');
                    return;
                end
            end
        catch
             return;
        end

        % if homing is already done
        % just mention it and exit
        try
            if homingDone(hgs) && (hgs.ARM_HARDWARE_VERSION>=2.0)
                presentMakoResults(guiHandles,'SUCCESS','Homing already done');
                log_results(hgs,'Home Robotic Arm','PASS','Homing already done');
            
                % homing was successful, change to zerogravity mode
                if (grav)
                    mode(hgs,'zerogravity');
                end
                %fill in user data
                userDataStruct.results=1;
                set(guiHandles.figure,'UserData',...
                    userDataStruct);
                return
            end
        catch
            return;
        end
       
        % Advice user to move one axis at a time
        currentAxis = 1;
        homingInProgress = true;
        errorMessage = '';
        
        % try catch this section incase cancel button is pressed
        try
            cautionTitle = uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'String','CAUTION',...
                'fontUnits','normalized',...
                'fontSize',0.8,...
                'Units','normalized',...
                'background','yellow',...
                'Position',[0.1 0.75 0.8 0.2]);
            cautionHandle = uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'fontUnits','normalized',...
                'fontSize',0.1,...
                'Units','normalized',...
                'background','white',...
                'Position',[0.1 0.05 0.8 0.7]);
            for countDown=5:-1:1
                if hgs.arm_status==1
                    updateMainButtonInfo(guiHandles,'text',...
                        sprintf('Releasing brakes in %d sec',countDown));
                    set(cautionHandle,...
                        'String',sprintf(['\n\nArm Already Enabled\n\n',...
                        'Please SUPPORT ARM as brakes release (%d)'],countDown));
                    drawnow;
                    pause(1);
                else
                    break;
                end
            end
            delete(cautionHandle);
            delete(cautionTitle);
            updateMainButtonInfo(guiHandles,'text','Please exercise Joint 1');
        catch
            return;
        end
        
        % if cancel button was pressed return immediately
        if homingAbort
            return;
        end
        
        %start homing module
        homingModule = char(hgs.HOMING_MODULE_NAME);
        mode(hgs,homingModule);

        while (homingInProgress && ~homingAbort)
            
            % Read it first.  This way even if homing progress
            % is done there will still be atleast one update to ensure that the
            % ui updates properly
            if (hgs.(homingModule).homing_progress>=1)
                homingInProgress = false;
            end
            jtIndexStatus = hgs.(homingModule).jt_index_found;
            mtIndexStatus = hgs.(homingModule).mt_index_found;
            for j=1:jeDof
                if (jtIndexStatus(j))
                    set(jeBox(j),'BackgroundColor','green');
                end
            end
            for j=1:meDof
                if (mtIndexStatus(j))
                    set(meBox(j),'BackgroundColor','green');
                end
            end

            % check if an axis is complete update instructions to go to the
            % next axis
            if ((homingInProgress) && (jtIndexStatus(currentAxis))...
                    && (mtIndexStatus(currentAxis)))
                currentAxis = currentAxis+1;
                updateMainButtonInfo(guiHandles,'text',...
                    sprintf('Please exercise Joint %d',currentAxis));
            end
        
            % check to make sure the module is still running
            if ~strcmp(mode(hgs),homingModule)
                % find out why the module stopped
                errorMessage = sprintf('Mode Stopped: %s',...
                    cell2mat(hgs.(homingModule).mode_error));
                break;
            end
            
            % refresh the screen
            drawnow;
            pause(0.01);
        end

        % if homing abort got called (exit elegantly)
        if homingAbort
            return;
        end
        
        % Present the results
        if ~homingDone(hgs)
            returnMessage = sprintf('Error homing joint %d',...
                hgs.(homingModule).homing_error+1);
            presentMakoResults(guiHandles,'FAILURE',{returnMessage,errorMessage});
            log_results(hgs,'Home Robotic Arm','FAIL',['Homing failed (',errorMessage,')']);
        else
            % homing was successful, change to zerogravity mode
            if (grav)
                mode(hgs,'zerogravity');
            end
            presentMakoResults(guiHandles,'SUCCESS');
            log_results(hgs,'Home Robotic Arm','PASS','Homing successful');
            %fill in user data
            userDataStruct.results=1;
            set(guiHandles.figure,'UserData',...
                userDataStruct);
        end
    end

%--------------------------------------------------------------------------
% Internal function to be able to handle cancelling the script prematurely
%--------------------------------------------------------------------------
    function cancelHoming(varargin)
        
        if ~homingDone(hgs)
            % stop the robot if homing has not yet been done
            stop(hgs);
        else
            % homing was done, change to zerogravity mode
            if(grav)
                mode(hgs,'zerogravity');
            end
        end
        
        homingAbort = true;
        log_message(hgs,'Homing script closed');
        closereq;
    end

end


% --------- END OF FILE ----------
