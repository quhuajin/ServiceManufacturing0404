%PARSECRISISREPLY Parse the reply received from CRISIS
%
% Syntax:  
%   parseCrisisReply(crisisReply,paramIndex)
%       This function parses the crisisReply from the CRISIS_REPLY_FORMAT
%       to extract the paramIndex element into matlab data format. 
%       argument paramIndex must be a single int.
%   parseCrisisReply(crisisReply,'-DataPair')
%       This case assumes the crisisReply is represented as data pairs
%       data pairs are variable/param names followed by the value.  Data
%       pairs will automatically genereate a structure using the variable
%       names as the fieldnames
%   parseCrisisReply(crisisReply,'-DataPairRaw')
%       By default all the the integers will be automatically converted to 
%       doubles.  (Matlab treats all numbers as doubles by default).  Specifying
%       the -DataPairRaw flag, will maintain the original datatype if needed.
%
% See also: 
%    matlabtoCrisisComm, sendReceiveCrisisComm

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 


% --------- END OF FILE ----------
