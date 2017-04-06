function retData=log_message(hgs,messageText,messageType)
%LOG_MESSAGE send a log entry to be logged in the CRISIS log files
%
% Syntax:  
%   log_message(hgs,messageText)
%       This will  add the messageText to the CRISIS HgsServer Logs, by
%       default the log message is considered of type message
%   log_message(hgs,messageText,messageType)
%       the messageType can be used to mark errors etc.  Valid message
%       types are 
%           ERROR    - Message denotes an error
%           WARNING  - Message denotes a warning
%           MESSAGE  - Message is just for information
%           TSYNC    - Message argument will be used for time sync
%
% See also: 
%    hgs_robot, hgs_loginfo

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
%

% check the arguments
if nargin==2
    if (strncmp(messageText,'TSYNC',5))
        comm(hgs,'log_message','TSYNC',...
            sprintf('TIME SYNC %s',datestr(now,'yyyy-mm-dd HH:MM:SS')));
        retData.success=1;
        retData.msg='Success';
        return;
    else
        messageType='MESSAGE';
    end
end

%initialize results data
retData=[];

try
    switch messageType
        case 'MESSAGE'
            comm(hgs,'log_message','MESSAGE',messageText);
        case 'ERROR'
            comm(hgs,'log_message','ERROR',messageText);
        case 'WARNING'
            comm(hgs,'log_message','WARNING',messageText);
        otherwise
            error('Unsupported log message type');
    end
catch
    retData.success=0;
    retData.msg=lasterr;
    return;
end

% log message is succesful
retData.success=1;
retData.msg='Success';

return


% --------- END OF FILE ----------