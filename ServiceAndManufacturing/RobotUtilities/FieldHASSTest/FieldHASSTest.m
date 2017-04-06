function FieldHASSTest(hgs)
% HASS test wrapper function to perform field friendly HASS
%
% Syntax:  
%   FieldHASSTest(hgs)
%       Starts up the GUI for helping the user perform HASS
%
% Notes:
%   The function is implemented QIP2_x/HASS/HASSTest.m
%   
% See also: 
%    hgs_robot, QIP2_x/HASS/HASSTest.m

% 
% $Author: rzhou $
% $Revision: 1733 $
% $Date: 2009-05-26 16:50:55 -0400 (Tue, 26 May 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% If no arguments are specified create a connection to the default hgs_robot
% The hgs is created here to call HASSTest properly with FieldService argument.  
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% call the HASS Test function
guiHandles = HASSTest(hgs,'FieldService');

% check if the figure is still open.  block if this is the case
while any(allchild(0)==guiHandles.figure)
    pause(0.2);
end

% There is no close(hgs) because HASSTest closes hgs upon exit/cancel.

end

% --------- END OF FILE ----------
