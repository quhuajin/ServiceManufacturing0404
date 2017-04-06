%OPENCRISISCONNECTION Open a socket based TCP connection to CRISIS
%
% Syntax: 
%   socketId = openCrisisConnection
%   socketId = openCrisisConnection(hostName)
%   socketId = openCrisisConnection(hostName,portNumber)
%       argument hostname and portNumber specify the host and the port to
%       attempt connection to.  By default the hostname is set by the
%       environment variable TARGET_HGS_ARM and the port is in the range
%       7101-7110
%
% Notes:
%   Use the hgs_robot constructor, instead of directly accessing this 
%   function.  
%
% See also: 
%    hgs_robot

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 


% --------- END OF FILE ----------