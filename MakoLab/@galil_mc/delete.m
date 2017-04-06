function delete(galilObj)

% DELETE Destructor used to disconnect from a GALIL controller object and clear the object.
% If the controller is not disconnected after use, MATLAB does not release 
% the handle to COM1 serial port. Use this command to release the serial port.
%
% Syntax:
%     delete(galilObj)

% $Author: dberman $
% $Revision: 3604 $
% $Date: 2014-11-13 14:18:38 -0500 (Thu, 13 Nov 2014) $
% Copyright: MAKO Surgical corp (2008)
%
%%

galilObj.galctrl.delete();


end