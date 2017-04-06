function response = load_arm_software_direct(host,fullFileName)
%LOAD_ARM_SOFTWARE start a specific version of CRISIS
%
% Syntax:  
%    LOAD_ARM_SOFTWARE(host,fullFileName)
%       the file name is assumed to be the installation file that will be
%       executed on the remote machine
%
% See also: 
%    hgs_robot, hgs_robot/reconnect

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

response = '';

% connect to the Robot (only HGS server) 
hgsSock = connectRobot(host);

% send the installation file

% Read the raw file.  All files will be treated as raw binaries
fid = fopen(fullFileName);
fileContents = fread(fid,'*uint8');
fclose(fid);

hgsCommand = matlabtoCrisisComm('load_arm_software',fileContents);
sendReceiveCrisisComm(hgsSock,hgsCommand);

% wait about 15 seconds to allow restart
% parse the data
totalWaitTime = 15; %sec
updateRate = 0.05; %secs per update
h = waitbar(0,'Installing CRISIS. Please Wait...', ...
            'Name', 'Installing CRISIS', ...
            'visible', 'off');
movegui(h,'north');
set(h,'visible', 'on');
for i=0:updateRate:totalWaitTime
    waitbar(i/totalWaitTime,h,...
        sprintf('Installing CRISIS. Please Wait... (%2.2f sec)',totalWaitTime-i));
    pause(updateRate);
    drawnow;
end
close(h);


% close the connection
closeCrisisConnection(host,hgsSock);



function hgsSock = connectRobot(host)

%defines
MIN_PORT_NUMBER = 7101;
MAX_PORT_NUMBER = 7110;


% if the host is specified do a quick sanity check to see if the target is
% reachable
if nargin == 0
    host = getenv('ROBOT_HOST');
    if isempty(host)
        error('Robot host not specified...ROBOT_HOST enviroment variable not set');
    end
end

if ispc
    pingCommand = 'ping -w 1000 -n 1 ';
    clientName = getenv('COMPUTERNAME');
    userName = getenv('USERNAME');
else
    pingCommand = 'ping -w 1 -c 1 ';
    [outNULL,clientName] = system('hostname');
    % remove lineterminators if any
    clientName = regexprep(clientName,'\n','');
    [outNULL,userName] = system('whoami');
    userName = regexprep(userName,'\n','');
end

clientString = sprintf('%s@%s',userName,clientName);

% ping the robot for a quick check
[pingFailure,pingReply] = system([pingCommand,host]); %#ok<NASGU>
if pingFailure
    error('Target (%s) not reachable...network error',host);
end

% connect a robot
portlist = MIN_PORT_NUMBER:MAX_PORT_NUMBER;
hgsSock = '';

for port=portlist
    try
        hgsConnection = openCrisisConnection(host,port);
        if iscell(hgsConnection)
            
            %extract socket information for ping
            hgsSock = cell2mat(hgsConnection(3));
            % Assume connection was bogus, close and retry the connection
            closeCrisisConnection(host,hgsSock);
            hgsConnection = openCrisisConnection(host,port);
            hgsSock = cell2mat(hgsConnection(3));
            
            % log the client name
            hgsCommand = matlabtoCrisisComm('log_message','MESSAGE',...
                sprintf('Client computer name %s',clientString));
            sendReceiveCrisisComm(hgsSock,hgsCommand);
                       
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




% --------- END OF FILE ----------