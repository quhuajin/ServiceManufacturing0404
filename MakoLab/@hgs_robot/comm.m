function [crisisReply, varargout] = comm(hgs,crisisCommand,varargin)
%COMM Send command to crisis and parse the elements of the reply
%
% Syntax:  
%   crisisReply = comm(hgs,crisisCommand,...)
%       send the crisisCommand to the hgs_robot identified by the object
%       hgs.  list the arguments required by crisisCommand following the
%       crisisCommand argument.  The reply is parsed and only the first element
%       is returned.
%   crisisReply = crisisComm(hgs)
%       if the crisisCommand argument is not specified the function will
%       return the list of commands supported by hgs.  This will be in 
%       readable text format
%   [reply1 reply2 ...] = crisisComm(hgs,crisisCommand)
%       This will parse the multiple elements in the reply from CRISIS.  if the
%       reply doesnt have the desired number of outputs, the parser will
%       generate an error.
%
% Notes:
%   crisisCommand is expected to be a single string.  Arguments can be
%   of any datatype.  must be vectors.  matrices not supported.  strings
%   must be represented as cells
%
% See also: 
%    crisisComm, sendReceiveCrisisComm, parseCrisisReply, hgs_robot/commDataPair

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% if there are no inputs just display the list of valid commands
if (nargin==1)
    crisisCommand = 'get_command_list';
end

% get the raw socket id
hgsSock = feval(hgs.sockFcn);

% format the arguments into crisis format
crisisCommandBinary = matlabtoCrisisComm(crisisCommand,varargin{:});

% send and receive the reply.  Dont do any parsing
crisisReplyBinary = sendReceiveCrisisComm(hgsSock,crisisCommandBinary);

% parse the first argument
crisisReply = parseCrisisReply(crisisReplyBinary,1);

% if there are additional elements requested parse them as well
for i=2:nargout
    varargout(i-1) = parseCrisisReply(crisisReplyBinary,i);
end

% convert command list to readable text
if (nargin==1)
    crisisReply = cell2mat(crisisReply);
end


% --------- END OF FILE ----------