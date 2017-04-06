function hgs = hgs_robot(host, port)
%HGS_ROBOT Constructor for Hgs Robot object
%
% Syntax:
%   HGS_ROBOT
%       creates a hgs robot object connected to the robot defined by
%       the environment variable TARGET_HGS_ARM.  The function will
%       search all sockets from 7101 to 7110 to find the port on which
%       the Crisis HgsServer is listening.
%   HGS_ROBOT(targetRobotName)
%       argument targetRobotName specfies the name of the target robot to
%       connect to.  As before all sockets in range will be searched.  the
%       targetRobotName must be resovled by the hostname.  It is acceptable
%       to use IP address in the format (e.g. 192.168.0.1)
%   HGS_ROBOT(targetRobotName,socketPort)
%       socketPort explicitly specifies which socket port to use
%
% Notes:
%   If the desired targetRobot already has a connection (in the current)
%   MATLAB session.  The connected robot id will be returned.
%
% See also:
%   hgs_robot/get, hgs_robot/crisisComm, openCrisisConnection
%

%
% $Author: jforsyth $
% $Revision: 2846 $
% $Date: 2013-03-15 13:21:11 -0400 (Fri, 15 Mar 2013) $
% Copyright: MAKO Surgical corp (2007)
%

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
if nargin == 2,
    portlist = port;
elseif nargin == 1
    portlist = MIN_PORT_NUMBER:MAX_PORT_NUMBER;
elseif nargin == 0
    portlist = MIN_PORT_NUMBER:MAX_PORT_NUMBER;
else
    error('MakoLab:hgs_robot: unknown input');
end

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
            
             
            % check if the connection is valid by sending in a ping.  If
            % the connection was restored from a file this maynot be valid
            try
                hgsCommand = matlabtoCrisisComm('ping_control_exec');
                parseCrisisReply(sendReceiveCrisisComm(hgsSock,hgsCommand),1);
            catch %#ok<*CTCH>
                % if the connection was bogus, close and retry the connection
                closeCrisisConnection(host,hgsSock);
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

hgsHost = cell2mat(hgsConnection(1));
hgsPort = cell2mat(hgsConnection(2));
hgsSock = cell2mat(hgsConnection(3));

if isempty(hgsSock)
    error('MakoLab:hgs_robot: No connection');
else
    try
        % connection was successful
        
        % check if rest of CRISIS is alive by sending a ping to the
        % control executive
        hgsCommand = matlabtoCrisisComm('ping_control_exec');
        parseCrisisReply(sendReceiveCrisisComm(hgsSock,hgsCommand),1);

        % also read the configuration parameters
        hgsCommand = matlabtoCrisisComm('get_cfg_params');
        hgsReply.cfg = parseCrisisReply(sendReceiveCrisisComm(...
            hgsSock,hgsCommand),...
            '-DataPair');

        % get the read and write data as well
        hgsCommand = matlabtoCrisisComm('get_state');
        hgsReply.data = parseCrisisReply(sendReceiveCrisisComm(...
            hgsSock,hgsCommand),...
            '-DataPair');

        % check if this is no modules initialized
        hgsCommand = matlabtoCrisisComm('get_module_info');
        modListText = parseCrisisReply(sendReceiveCrisisComm(...
            hgsSock,hgsCommand),1);

        modListArray = strread(char(modListText),'%s'); %#ok<REMFF1>

        % Assign data to maintain mode data
        modeData = [];

        % parse each string for module name status and id
        for i=1:length(modListArray)
            % Create a sub array with variables for each type of control module
            % supported
            modeData.(modListArray{i}).id = -1;
            hgsReply.modes.(modListArray{i}) = modListArray{i};
        end

        % Query status and fill up the ids with variables if possible
        hgsCommand = matlabtoCrisisComm('get_status');
        modListText = parseCrisisReply(sendReceiveCrisisComm(...
            hgsSock,hgsCommand),1);

        hgsReply.ctrlModStatusFcn = @statusFcn;
        statusFcn(modListText);

        % Get the version number
        hgsCommand = matlabtoCrisisComm('version_info');
        versionInfo = parseCrisisReply(sendReceiveCrisisComm(...
            hgsSock,hgsCommand),1);
        
        % log the client name
        hgsCommand = matlabtoCrisisComm('log_message','MESSAGE',...
            sprintf('Client computer name %s',clientString));
        sendReceiveCrisisComm(hgsSock,hgsCommand);
        
        % Save the socket information
        hgsReply.sockFcn = @sockFcn;
        internalHgsSock = [];
        internalHgsPort = [];
        sockFcn(hgsSock,hgsPort);

        % prepare the user display data
        hgsReply.host = hgsHost;
        hgsReply.name = char(hgsReply.cfg.ARM_SERIAL_NUMBER);
        hgsReply.version = char(versionInfo);
        
        hgs = class(hgsReply, 'hgs_robot');
    catch
        % some error has occured close the connection
        % and display the error
        closeCrisisConnection(host,hgsSock);
        rethrow(lasterror); %#ok<*LERR>
    end
end

% Create a local internal function to maintain the socket id.  This will allow
% for seamless reconnects through functions and global namespaces
    function [hgsSock, hgsPort] = sockFcn(updatedHgsSock,updatedHgsPort)
        if nargin==2
            internalHgsSock = updatedHgsSock;
            internalHgsPort = updatedHgsPort;
        end

        if nargout==1
            hgsSock = internalHgsSock;
        elseif nargout==2
            hgsSock = internalHgsSock;
            hgsPort = internalHgsPort;
        end
    end

% Create a local Internal function to maintain and update the control module
% data
    function id = statusFcn(modListText,refreshRequest)
        % if there is an output requested. this is a request for
        % a control module id
        if nargout==1
            id = modeData.(modListText).id;
            return
        end
        
        % check if this is a request to refresh all control module ids
        % if so clear all the control module ids and update based on the
        % provided string
        if (nargin==2) && strcmp(refreshRequest,'refresh')
            controlModuleList = fields(modeData);
            for j=1:length(controlModuleList)
                modeData.(controlModuleList{j}).id = -1;
            end
        end
           
        % check if this is no modules initialized
        if (~strcmp(modListText,'no_control_modules'))
            % parse each string for module name status and id
            for j=1:length(modListText)
                [modName,outNULL,modId]=strread(char(modListText(j)),...
                    '%s%s%d',...
                    'delimiter',' '); %#ok<REMFF1>
                modeData.(modName{1}).id = modId;
            end
        end
    end
end


% --------- END OF FILE ----------
