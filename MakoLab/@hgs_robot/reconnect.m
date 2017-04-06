function out = reconnect(hgs)
%RECONNECT re-establish connection to the hgs robot
%
% Syntax:  
%   reconnect(hgs)
%       This will attempt to reconnect the connection to a previouly connected
%       hgs robot.  
%   hgs = reconnect(hgs)
%       return value if specified is the updated hgs_robot object
%
% Notes:
%   The connection to a hgs robot might be lost or the hgs robot might have
%   restarted.  In either case a reconnection is required.
%
% See also: 
%    hgs_robot, hgs_robot/close

% 
% $Author: jforsyth $
% $Revision: 2760 $
% $Date: 2012-10-26 12:49:20 -0400 (Fri, 26 Oct 2012) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% close currently existing connections
hgsSock = feval(hgs.sockFcn);

closeCrisisConnection(hgs.host,hgsSock); 

%defines
portlist = 7101:7110;

if ispc
    pingCommand = 'ping -w 1000 -n 1 ';
else
    pingCommand = 'ping -w 1 -c 1 ';
end

% ping the robot for a quick check
[pingFailure,pingReply] = system([pingCommand,hgs.host]); %#ok<NASGU>
if pingFailure
    error('Target (%s) not reachable...network error',host);
end

% connect a robot
for port=portlist
    try
        hgsConnection = openCrisisConnection(hgs.host,port);
        if iscell(hgsConnection)
            
            %extract socket information for ping
            hgsSock = cell2mat(hgsConnection(3));
            
            % check if the connection is valid by sending in a ping.  If
            % the connection was restored from a file this maynot be valid
            try
                hgsCommand = matlabtoCrisisComm('ping_control_exec');
                parseCrisisReply(sendReceiveCrisisComm(hgsSock,hgsCommand),1);
            catch %#ok<*CTCH>
                % if the connection was bogus, close and retry the connection
                closeCrisisConnection(hgs.host,hgsSock);
                hgsConnection = openCrisisConnection(host,port);
            end
            
            break;
        end
    catch
        % check if all the ports have been checked.  if this is the last
        % port...assume the connection has failed
        if port==portlist(end)
            error('Unable to open connection to Arm Software');
        end
    end
end

hgsPort = cell2mat(hgsConnection(2));
hgsSock = cell2mat(hgsConnection(3));

feval(hgs.sockFcn,hgsSock,hgsPort);

% send a quick ping to make sure the connection is valid
try
    comm(hgs,'ping_control_exec');
catch
    rethrow(lasterror); %#ok<LERR>
end

if nargout==1
    out = hgs;
end

return


% --------- END OF FILE ----------
