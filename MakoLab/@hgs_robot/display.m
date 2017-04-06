function display(hgs)
%DISPLAY Overloaded method to Display the value of a hgs robot object
%
% Syntax:  
%   DISPLAY(hgs)
%       displays the identifying elements of the hgs_robot object.  This
%       includes the name of the host, the connected port and the socket id
%       being used
% 
% See Also:
%   hgs_robot/subsasgn, hgs_robot/subsref
%

% 
% $Author: rzhou $
% $Revision: 2609 $
% $Date: 2012-05-30 17:02:58 -0400 (Wed, 30 May 2012) $ 
% Copyright: MAKO Surgical corp (2007)
% 
[~,hgsPort] = feval(hgs.sockFcn);
disp(' ')
disp(sprintf('%s.name    : %s',inputname(1),hgs.name)); %#ok<*DSPS>
disp(sprintf('%s.host    : %s',inputname(1),hgs.host))
disp(sprintf('%s.version : %s',inputname(1),hgs.version));
% send a test command to establish if the socket is still connected
try
    comm(hgs,'test_command',1);
    disp(sprintf('%s.port    : connected (%d)',inputname(1),hgsPort));
catch %#ok<CTCH>
    disp(sprintf('%s.port    : disconnected',inputname(1)));
end
disp(' ')


% --------- END OF FILE ----------