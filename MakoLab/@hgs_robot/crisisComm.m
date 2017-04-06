function crisisReply = crisisComm(hgs,crisisCommand,varargin)
%CRISISCOMM Send command to crisis and receive the binary reply
%
% Syntax:  
%   crisisReplyBinary = crisisComm(hgs,crisisCommand,...)
%       send the crisisCommand to the hgs_robot identified by the object
%       hgs.  list the arguments required by crisisCommand following the
%       crisisCommand argument.  The reply is the raw binary reply from
%       crisis.  use the parseCrisisComm to extract data
%   crisisReply = crisisComm(hgs)
%       if the crisisCommand argument is not specified the function will
%       return the list of commands supported by hgs.  This will be in 
%       readable text format
%
% Notes:
%   crisisCommand is expected to be a single string.  Arguments can be
%   of any datatype.  must be vectors.  matrices not supported.  strings
%   must be represented as cells
%   For a list of commands supported by crisis use
%       crisisCommand = 'get_command_list'
%
% See also: 
%    hgs_robot/comm, sendReceiveCrisisComm, parseCrisisReply

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

% format the arguments into crisis format
crisisCommandBinary = matlabtoCrisisComm(crisisCommand,varargin{:});

% send and receive the reply.  Dont do any parsing
hgsSock = feval(hgs.sockFcn);
crisisReply = sendReceiveCrisisComm(hgsSock,crisisCommandBinary);

% if this was a request for command list convert to mat format
% for easy reading
if (nargin==1)
    crisisReply = cell2mat(parseCrisisReply(crisisReply,1));
end

end

% --------- END OF FILE ----------