function  out = mode(hgs,modeName,varargin)
%MODE get/set/control modes of the hgs_robot
%
% Syntax:  
%   MODE(hgs)
%       this returns the current executing mode on crisis.  If there are no
%       modes executing in CRISIS the return value will be NONE
%   MODE(hgs,modeName,argName,argValue,...)
%       this method creates a control module on CRISIS and attempts to start the
%       control module.
%   MODE(hgs,'stop')
%       Stop the mode currently executing.  Preferable to use the stop method
%       instead of this option.
%   MODE(hgs,'?')
%       this displays all the supported modes in crisis
%   MODE(hgs,modeName,'?')
%       this displays the help information of the specific
%       mode specified by the modeName argument
%
% Notes:
%   Modes are refered to as control modules in CRISIS.  
%   
% See also: 
%    hgs_robot, home_hgs, hgs_robot/stop

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% check the inputs.  

% if this is a query for current mode query hgs and reply immediately
if (nargin==1)
    % query for which control module is executing
    currentControlModule = parseCrisisReply(crisisComm(hgs,...
                                'get_current_module'),1);
    % if no modoule is executing reply immeditely
    if (currentControlModule == -1)
        out = 'NONE';
        return;
    end
    
    % Get a list of all the existing control modules
    ctrlModStatus = controlModuleList(hgs);

    % Deleted all the other
    for i=1:length(ctrlModStatus)
        if ctrlModStatus(i).id == currentControlModule
            out = cell2mat(ctrlModStatus(i).name);
            return;
        end
    end
end     

% check if this is a request for help
if ((nargin==2)&&(strcmp(modeName,'?')))
    crisisReply = parseCrisisReply(crisisComm(hgs,'get_module_info'),1);
    out = cell2mat(crisisReply);
    return;
end

% if this is help on a particular mode, display help for that mode
if ((nargin==3)&&(strcmp(varargin{1},'?')))
    crisisReply = parseCrisisReply(crisisComm(hgs,'get_module_info',...
        modeName),1);
    out = cell2mat(crisisReply);
    return;
end

% check if this is a request to stop module if so  stop the module
% currently executing
if ((nargin==2)&&(strcmp(modeName,'stop')))
    crisisReply = parseCrisisReply(crisisComm(hgs,'stop_module'),1);
    out = cell2mat(crisisReply);
    return;
end   

% Get a list of all the existing control modules
ctrlModStatus = controlModuleList(hgs);

%if i got here this is assumed to be a request to create a new control
%module
modeId = comm(hgs,'init_module',modeName,varargin{:});

% Start the module
comm(hgs,'start_module',modeId);

% Deleted all the other 
for i=1:length(ctrlModStatus)
    if strcmp(ctrlModStatus(i).name,modeName)
        comm(hgs,'delete_module',ctrlModStatus(i).id);
    end
end

% update the ctrlModuleStatus variable
ctrlModeStatus = status(hgs);
feval(hgs.ctrlModStatusFcn,ctrlModeStatus)
% return the module name as the current module name
out = mode(hgs);
end


% --------- END OF FILE ----------