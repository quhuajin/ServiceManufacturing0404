function returnValue = restartCRISIS(hgs)

% restartCRISIS helper function to restart CRISIS
%
% Syntax:
%   restartCRISIS(hgs)
%       Restart CRISIS connected via the hgs_object "hgs".  The function
%       will return success (true) or failure (false).
% 
% Notes:
%   The function checks the success or failure by sending a ping to the
%   control executive after the retart.
%
%   This is equvivalent to calling the following on CRISIS
%       >> crisis_manager -r driver -r control_executive
%
%   This does not restart the HgsServer.  So as to keep the connectio
%   alive.
%
% See CRISIS documentation:
%   crisis_manager, CRISIS_API/system_command
%
% See Also:
%   hgs_robot/reset
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%

comm(hgs,'system_command','restart');

% send a ping to check the result
returnValue = comm(hgs,'ping_control_exec');


% --------- END OF FILE ----------