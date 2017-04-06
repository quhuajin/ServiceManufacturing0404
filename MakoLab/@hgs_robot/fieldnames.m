function out = fieldnames(hgs, flag)
%FIELDNAMES overloading method for accessing hgs_robot fields
%
% Syntax:
%   FIELDNAMES(hgs)
%   FIELDNAMES(hgs,'-full')
%       returns all the user accessible fields in the hgs_robot object, hgs
%   FIELDNAMES(hgs,'-rw')
%       returns the list of realtime read/write data accessible on the
%       hgs_robot object.  these fields are treated as READ ONLY
%   FIELDNAMES(hgs,'-config')
%       returns configuration data accessible to the user.  These fields
%       have READ WRITE access
%   FIELDNAMES(hgs,'-modes')
%       returns modes (or mode fields) supported.  these fields have READ
%       ONLY access.
%   FIELDNAMES(hgs,'-predefined')
%       returns predefined fields in the hgs_robot.  these fields have READ
%       ONLY access.  These fields are not queried from the hgs_robot.
%   
% Notes:
%   As per crisis convension, variables in all caps 
%   (e.g. ARM_SERIAL_NUMBER) are configuration parameters
%   
%   Predefined variables are 'host','port','sock'
%
% See also: 
%    hgs_robot, hgs_robot/get, hgs_robot/subsref
 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

constantFields = {'name';'host';'port';'sock'};

% check if the accessed data is part of the user accessible data
if (nargin==1)
    flag = '-full';
end

switch flag
    case {'{}','-full'}
        out = [fieldnames(hgs.data);fieldnames(hgs.cfg);...
            fieldnames(hgs.modes);constantFields];
    case '-rw'
        out = fieldnames(hgs.data);
    case '-modes'
        out = fieldnames(hgs.modes);
    case '-config'
        out = fieldnames(hgs.cfg);
    case '-predefined'
        out = constantFields;
    otherwise
        error('Invalid option (%s), (-full, -config, -rw, -predefined)',...
            flag);
end


% --------- END OF FILE ----------