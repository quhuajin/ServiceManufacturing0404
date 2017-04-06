function cameraObj = ndi_camera(portHandle)
%NDI_CAMERA Constructor for NDI Camera object (direct connection or through hgs)
%
% Syntax:
%   ndi_camera(portHandle)
%       creates a ndi camera object that can be used for communication with
%       the camera connected to the hgs_robot object specified by the
%       argument portHandle.  Additionally the portHandle could be a serial port
%       or a virtual serial port to communicate with a camera directly connected
%       to the host computer
%
% Examles:
%   To connect to a camera through a hgs_robot, where hgs is the robot object
%       ndi_camera(hgs);
%   To connect to a camera on the local machine on COM2
%       ndi_camera('COM2');
%
% See also:
%   hgs_robot, ndi_camera/comm, ndi_camera/setmode
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% Now determine if this is a hgs_robot
if (isa(portHandle,'hgs_robot'))

    % check if the camera is connected to the hgs robot
    if (~parseCrisisReply(crisisComm(portHandle,'is_camera_connected'),1))
        error('No camera connected to hgs (%s)',portHandle.host);
    end

    % Populate the robot object
    cameraObj.type = portHandle.TRACKING_SYSTEM;
    cameraObj.host = portHandle.host;
    cameraObj.port = portHandle;
    cameraObj.connection_type = 0;
    
elseif (~isempty(strfind(upper(portHandle),'COM')))
    % check if this is a local serial port on a windows system
    cameraObj.type = {'Local Camera'};
    cameraObj.host = 'Local Computer';

    cameraObj.connection_type = 1;

    % now open the port and try to establish the connection

    % Check if there is an open serial port with the connection already open
    % Only one serial port can be opened at a time so the return value is
    % assumed never to be an array
    portId = instrfind('port',upper(portHandle),'status','open');
    
    if isempty(portId)
        % This is a spectra specific code.  For polaris this will have to be tweaked
        % to change the comm settings on the camera as well.
        % the terminator is set to CR (ascii 13)
        portId = serial(portHandle,'terminator',13);
        fopen(portId);
    end
    % send a serial break to reset the camera
    serialbreak(portId);
        
    % force local baud to 9600
    set(portId,'baud',9600);

    % read to flush out the port
    fgets(portId);
  
    % try to find the type of camera and update the variable.
    fwrite(portId,sprintf('VER 4\r'));
    versionInfo = fgets(portId);

    % Check for the word spectra in the version information
    % default to polaris
    if (~isempty(strfind(versionInfo,'Spectra')))
        cameraObj.type = {'Spectra'};
        % For spectra the baud must be set to 19200 (refer to spectra documenation,
        % 19200 is mapped to 1.2 Mbps.
        fwrite(portId,sprintf('COMM 70000\r'));
        fgets(portId);
        % Now change the local baud rate to match
        set(portId,'baud',19200);
    else
        cameraObj.type = {'Polaris'};
        % Boost the comm rate to the max possible for the serial port
        fwrite(portId,sprintf('COMM 50000\r'));
        fgets(portId);
        % Now change the local baud rate to match
        set(portId,'baud',115200);
    end


    % Save port handle for later use
    cameraObj.port = portId;

   
else
    error('argument should be a valid hgs_object or Serial port');
end

% return the object
cameraObj = class(cameraObj,'ndi_camera');


%---- END OF FILE -----