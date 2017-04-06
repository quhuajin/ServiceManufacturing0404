function out = controlModuleList(hgs)
%CONTROLMODULELIST get the list of control modules and their status
%
% Syntax:  
%   ctrlModList = controlModuleList(hgs)
%       get the list of control modules created.  The return value is a
%       structure with the following elements
%           name
%           status
%           id
%   
% Notes:
%   If there are no modules initialize the command returns nothing
%
% See also: 
%    hgs_robot/mode

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% Send the get status command and get back the control modules
modListText = status(hgs);

% check if this is no modules initialized
if (strcmp(modListText,'no_control_modules'))
    out='';
    return;
end

% parse each string for module name status and id
for i=1:length(modListText)
    [out(i).name,out(i).status,out(i).id]=strread(char(modListText(i)),...
        '%s%s%d',...
        'delimiter',' ');
end


% --------- END OF FILE ----------