function [cm, ho, rf] = status(hgs)
%STATUS Get the status of the hgs_robot.
%
% Syntax:  
%    [cm, ho, rf] = STATUS(hgs)
%       Query the hgs object for the status.  outputs cm are the control
%       modules, ho are the haptic objects and rf are the reference frames
%    STATUS(hgs)
%       without any return variables specified this method just Displays 
%       the hgs object status
%
% See also: 
%    hgs_robot, hgs_robot/get

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% send the command to crisis
crisisReply = crisisComm(hgs,'get_status');
cm = parseCrisisReply(crisisReply,1);
ho = parseCrisisReply(crisisReply,2);
rf = parseCrisisReply(crisisReply,3);

% if there are no return values assume it is a query to view on screen
% convert output to readable text
if (nargout==0)
    ControlModules = cm(:);
    HapticObjects = ho(:);
    ReferenceFrames = rf(:);
    % display the output
    display(ControlModules);
    display(HapticObjects);
    display(ReferenceFrames);
    
    % hide the output
    clear cm;
end

% --------- END OF FILE ----------