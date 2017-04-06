function reply = comm(cameraObj,command,repeatCount,binaryData)
%COMM Send a command to the ndi camera and return the reply
%
% Syntax:
%   comm(ndi,command)
%       This sends the command to the camera defined by the ndi parameter.
%       and returned value from the camera is returned.
%   
% Notes:
%   The required '\r' as per the NDI API is automatically appended.  if a
%   '\r' is part of the command '\r' will not be appended to avoid
%   duplicate.
%
%   Refer to the NDI API Documentation for supported commands
%
% Examples
%   >> comm(ndi,'BEEP 3')
%   1D45
%
% See also:
%   ndi_camera
% 

% 
% $Author: dmoses $
% $Revision: 3331 $
% $Date: 2013-11-27 17:15:50 -0500 (Wed, 27 Nov 2013) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% check if '\r' needs to be added to the command
if ((length(command)<1) || (~strcmp(command(end-1:end),'\r')))
    command = sprintf('%s\r',command);
else
    command = sprintf('%s\r',command(1:end-2));
end

if nargin<3
    repeatCount=1;
    binaryData=false;
elseif nargin<4
    binaryData=false;
end


% send the command to the camera and check for the 
% response.
switch (cameraObj.connection_type)
    case 0
        % this is a connection through CRISIS
        reply = parseCrisisReply(crisisComm(cameraObj.port,'camera_comm',...
            command,repeatCount),1);
    case 1
        if binaryData
            % this is direct connection through the serial port.
            % use simple serial communication
            fwrite(cameraObj.port,command);
            pause(.1);
            reply = fread(cameraObj.port,cameraObj.port.BytesAvailable,'uint8');
        else
            fwrite(cameraObj.port,command);
            reply = fgets(cameraObj.port);
        end
end

% check if this is an error.  if so translate automatically
% ignore the CRC code
if (strmatch('ERROR',reply))
    error(translateCameraError(char(reply(1:7))));
end


%---- END OF FILE -----