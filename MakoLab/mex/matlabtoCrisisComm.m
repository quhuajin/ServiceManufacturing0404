%MATLABTOCRISISCOMM convert Matlab format arguments to Crisis API format
%
% Syntax:  
%   crisisCommBinary = matlabtoCrisisComm(crisisCommand,...)
%       This function converts data from matlab format to the Crisis 
%       Command format as described in the CRISIS_API readme document
%       in CRISIS.   Any number of arguments can be passed to the
%       command.  Argument crisisCommand MUST be a string
%
% Notes:
%   if all elements of a vector of type double can be converted to int
%   without change in value.  (e.g. [1.0 2.0 3.0]) the vector will be 
%   treated as an int
%
% Examples:
%   crisisCommand = matlabtoCrisisComm('get_status')
%   crisisCommand = matlabtoCrisisComm('init_module','go_to_position',...
%       'target_position',[1.1 2.2 3.3 4.4 5.5])
%
% See also: 
%    parseCrisisReply, sendReceiveCrisisComm

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 


% --------- END OF FILE ----------