function [crisisReply] = commDataPair(hgs,crisisCommand,varargin)
%COMM Send command to crisis and parse the elements of the reply as a DataPair
%
% Syntax:  
%   crisisReply = commDataPair(hgs,crisisCommand,...)
%       send the crisisCommand to the hgs_robot identified by the object
%       hgs.  list the arguments required by crisisCommand following the
%       crisisCommand argument.  The reply is parsed as data pairs and returned
%       as a structure
%
% Notes:
%   crisisCommand is expected to be a single string.  Arguments can be
%   of any datatype.  must be vectors or 2D matrices.  strings
%   must be represented as cells
%
% See also: 
%    crisisComm, sendReceiveCrisisComm, parseCrisisReply, hgs_robot/comm

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% get the raw socket id
hgsSock = feval(hgs.sockFcn);

% format the arguments into crisis format
crisisCommandBinary = matlabtoCrisisComm(crisisCommand,varargin{:});

% send and receive the reply.  Dont do any parsing
crisisReplyBinary = sendReceiveCrisisComm(hgsSock,crisisCommandBinary);

% parse the first argument
crisisReply = parseCrisisReply(crisisReplyBinary,'-DataPair');


% --------- END OF FILE ----------