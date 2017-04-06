function retMsg=time_sync(hgs)
%TIME_SYNC send a clock entry for CRISIS to log to help sync clock later
%
% Syntax:  
%   time_sync(hgs)
%       This will add the current time to the CRISIS logs.  the reply will
%       be CRISIS clock
%
% See also: 
%    hgs_robot, log_message

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
%

% check the arguments
retMsg = comm(hgs,'time_sync',randi(1e8),...
            sprintf('%s',datestr(now,'yyyy-mm-dd HH:MM:SS  FFF')));

return


% --------- END OF FILE ----------