function close(hgs)
%CLOSE close the TCP socket based connection 
%
% Syntax:  
%   CLOSE(hgs)
%       close the connection identified by the argument hgs,  where hgs is
%       an object of type hgs_robot
%
% Notes:
%   
%
% See also: 
%    hgs_robot, closeCrisisConnection

% 
% $Author: jforsyth $
% $Revision: 2760 $
% $Date: 2012-10-26 12:49:20 -0400 (Fri, 26 Oct 2012) $ 
% Copyright: MAKO Surgical corp (2007)
% 

hgsSock = feval(hgs.sockFcn);

closeCrisisConnection(hgs.host,hgsSock); 	


% --------- END OF FILE ----------
