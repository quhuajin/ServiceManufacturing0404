function hgs = subsasgn(hgs, field, value)
%SUBSASGN overloading method for editing hgs_robot configuration variables
%
% Notes:
%   This method will check if the fields are part of configuration
%   variables.  Only configuration variables can be edited.
%   method will return error if an attempt to edit a read/write variable is
%   made
%
%   As per crisis convension, variables in all caps 
%   (e.g. DEFAULT_CONTROLLER) are configuration parameters
%
% See also: 
%    hgs_robot, hgs_robot/fieldnames, hgs_robot/get, hgs_robot/subsref
 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

if (length(field)>2)
    error('Only single referncing supported');
elseif (length(field)==2)
    % get the complete vector
    tempValue = subsref(hgs,field(1));

    % replace the specified indices
    tempValue(cell2mat(field(2).subs)) = value;
    subsasgn(hgs,field(1),tempValue);
else
    % check if this is a configuration variable
    if (~isfield(hgs.cfg,field.subs))
        error('field %s is not editable',field.subs);
        return;
    end

    % send command to CRISIS to update the configuration file
    comm(hgs,'set_cfg_param',field.subs,value);
    
    % ARM SERIAL NUMBER is a special field.  If this
    % field is updated update the name of the hgs_robot
    if (strcmp(field.subs,'ARM_SERIAL_NUMBER'))
        hgs.name = char(value);
    end
end




% --------- END OF FILE ----------