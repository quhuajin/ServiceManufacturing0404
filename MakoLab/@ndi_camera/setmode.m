function returnValue = setmode(ndi,modeName)
%SETMODE Set the mode of the camera
%
% Syntax:
%  SETMODE(ndi, modeName)
%   Sets the mode of the NDI camera.  The NDI camera supports the following
%   modes.  If successful the function will return 'OKAY' if not it will return
%   the error message
%       Setup
%       Tracking
%       Diagnostic
%
% See also:
%   ndi_camera, ndi_camera/track
% 

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% I could not find a way to query the mode of the camera, so this TSTOP and
% DSTOP to figure out the mode.

% check if the mode is supported
switch(upper(modeName))
    case 'SETUP'
        % try sending the TSTOP and DSTOP
        checkModeError(ndi,'TSTOP ');
        checkModeError(ndi,'DSTOP ');
        returnValue = 'OKAY';

    case 'TRACKING'
        % try sending the DSTOP and then TSTART
        checkModeError(ndi,'DSTOP ');
        checkModeError(ndi,'TSTART ');
        returnValue = 'OKAY';

    case 'DIAGNOSTIC'
        % try sending the TSTOP and then DSTART
        checkModeError(ndi,'TSTOP ');
        checkModeError(ndi,'DSTART ');
        returnValue = 'OKAY';
    otherwise
        error(['Unsupported NDI camera mode, supported modes SETUP, '...
            'TRACKING and DIAGNOSTIC']);
end
end

% Internal function to check for invalid mode error. (error0c). If any other
% error is received, display error. if not mask the error

function checkModeError(ndi,checkModeErrorand)
try
    comm(ndi,checkModeErrorand);
catch
    err = lasterror;
    if (isempty(strfind(err.message,'ERROR0C')))
        error(err.message);
    end
end
end


%---- END OF FILE -----