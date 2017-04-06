function reset( cameraObj )
%RESET Perform a hard reset of the ndi_camera
%
% Syntax:
%   reset(ndi)
%       Reset the ndi camera.  This is valid only for cameras directly connected
%       to the host computer
%
% See also:
%   ndi_camera, ndi_camera/init, ndi_camera/init_tool
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

switch (cameraObj.connection_type)
    case 0
        % this is a connection through CRISIS
        % do nothing

    case 1
        % this is direct connection through the serial port.

        % Initially lower the baud rate, as this will be what the camera will
        % use once it is reset
        set(cameraObj.port,'baud',9600);
        
        % use simple serial communication
        serialbreak(cameraObj.port);
        fgets(cameraObj.port);

        if strcmp(cameraObj.type,'Spectra')
            % Now adjust the serial communication rate.  For now I assume Spectra
            % For spectra the baud must be set to 19200 (refer to spectra documenation,
            % 19200 is mapped to 1.2 Mbps.
            fwrite(cameraObj.port,sprintf('COMM 70000\r'));
            fgets(cameraObj.port);

            % Now change the local baud rate to match
            set(cameraObj.port,'baud',19200);
        else
            fwrite(cameraObj.port,sprintf('COMM 50000\r'));
            fgets(cameraObj.port);

            % Now change the local baud rate to match
            set(cameraObj.port,'baud',115200);
        end
end


%---- END OF FILE -----
