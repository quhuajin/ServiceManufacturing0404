function response = comm(galilObj, cmd)

% COMM is used to send a command (two letter optocode)to the GALIL 
% controller from MATLAB. The return variable is a double.
% 
% Syntax:
%     response = comm(galil_mc, command)
%     cmd is any string corresponding to the GALIL commands
%     Example: 
%       comm(motor1,'AB');
%       Abort motion. 
%     

% $Author: dberman $
% $Revision: 3604 $
% $Date: 2014-11-13 14:18:38 -0500 (Thu, 13 Nov 2014) $
% Copyright: MAKO Surgical corp (2008)
%
%%    
response = galilObj.galctrl.command(cmd);

end