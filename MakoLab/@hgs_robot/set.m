function hgs=set(hgs,varargin)   
%SET overloading method for updateing hgs_robot elements 
%
% Syntax:  
%   hgs = SET(hgs,varName,value)
%       Update elements in the hgs_robot object (hgs).  returns the newly 
%       updated object.
%   SET(hgs,varName,value)
%       Even if the updated object is not saved, the value gets updated on
%       CRISIS so the next time the value is queried the latest value will
%       be returned
%   SET(hgs,modeName,tunableVarName,value,...)
%       Adjust the tunable variables of a mode.  variables should be represented
%       as variable pairs, name and value
%
% Notes
%   Currently only configuration parameters can be updated.
%
% See also: 
%    hgs_robot, hgs_robot/subsasgn, hgs_robot/get, hgs_robot/fieldnames
%    hgs_robot/mode

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% If there are only 3 arguments assume this is a configuration parameter
if (nargin==3)
    % extract the inputs
    varName = varargin{1};
    value = varargin{2};

    % check if this is a configuration variable
    if (~isfield(hgs.cfg,varName))
        error('Variable %s is not editable',varName);
        return;
    end

    % get the raw socket id
    hgsSock = feval(hgs.sockFcn);

    % send command to CRISIS to update the configuration file
    comm(hgs,'set_cfg_param',varName,value);
    
    % ARM SERIAL NUMBER is a special field.  If this
    % field is updated update the name of the hgs_robot
    if (strcmp(varName,'ARM_SERIAL_NUMBER'))
        hgs.name = char(value);
    end

else
    modeName = varargin{1};
    modeValid = false;
    ctrlModStatus = controlModuleList(hgs);
    
    % check if this is a mode parameter
    for i=1:length(ctrlModStatus)
        if strcmp(ctrlModStatus(i).name,modeName)
            comm(hgs,'edit_module_inputs',ctrlModStatus(i).id,...
                varargin{2:end});
            modeValid = true;
            break;
        end
    end
    if ~modeValid
        error('Invalid mode name %s',modeName);
    end
end

% --------- END OF FILE ----------