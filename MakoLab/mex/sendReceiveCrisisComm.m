%SENDRECEIVECRISISCOMM Send command to CRISIS and receive the reply
%
% Syntax:  
%   sendReceiveCrisisComm(socketId,crisisCommand)
%       send the crisisCommand on the socketId and receive the 
%       response.  crisisCommand must be in the CRISIS COMMAND FORMAT
%       described in the CRISIS_API_README
%       The received reponse is in the CRISIS REPLY FORMAT also described
%       in the CRISIS_API_README
%
% See also: 
%    matlabtoCrisisComm, parseCrisisReply

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 


% --------- END OF FILE ----------