function reset(hgs)
%RESET clear all currently initialized modules, haptic objects and ref frames on the robot
%
% Syntax:  
%   reset(hgs)
%       Clear all haptic objects and reference frames and control modules
%       currently initialized on CRISIS.  
%       This function also forces the hgs robot to go to zerogravity mode. 
%       If homing is not done the robot will be put in a locked state
%
% Notes:
%       once this function is called, all previously created hgs_haptic
%       objects will be invalid. 
%
% See also: 
%    hgs_robot/mode, hgs_haptic, hgs_robot/ref_frame_documentation

% 
% $Author: dmoses $
% $Revision: 3606 $
% $Date: 2014-11-17 12:22:05 -0500 (Mon, 17 Nov 2014) $ 
% Copyright: MAKO Surgical corp (2007)
% 

[ cm, ho, rf] = status(hgs);

% Firstly put the robot in zerogravity mode or locked state depending on
% homing status
if homingDone(hgs)
    mode(hgs,'zerogravity');
else
    stop(hgs);
end

% Now get a list of all previously created control modules and delete
% every module execept the zerogravity module
% Get a list of all the existing control modules
ctrlModStatus = controlModuleList(hgs);

% Deleted all the other 
for i=1:length(ctrlModStatus)
    if ~strcmp(ctrlModStatus(i).name,'zerogravity')
        comm(hgs,'delete_module',ctrlModStatus(i).id);
    end
end

% Force the hgs_robot object to update internal ids
% update the ctrlModuleStatus variable
ctrlModeStatus = status(hgs);
feval(hgs.ctrlModStatusFcn,ctrlModeStatus,'refresh')

% check if there are any haptic objects, clear the haptic interact module
if ~strcmp(ho,'no_haptic_objects')
    for i=1:length(ho)
        comm(hgs,'delete_haptic_object',ho{i});
    end
end

% Also check for reference frames
if ~strcmp(rf,'no_ref_frames')
    for i=1:length(rf)
        % Auto reference frames are reserved for internal use by CRISIS and
        % cannot be deleted by the client so skip these
        if ~strncmp(rf{i},'auto_',5)
            comm(hgs,'delete_ref_frame',rf{i});
        end
    end
end


% --------- END OF FILE ----------
