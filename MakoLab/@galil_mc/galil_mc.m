function galilObj = galil_mc(address)

% GALIL_MC Constructor for GALIL motor controller object.
% Loads the DMC32.dll library into MATLAB, and establishes 
% connection between the MATLAB environment and GALIL controller
%
% Syntax:
%     galilObj = galil_mc(address)
%     The function returns galilObj which is a galil motor controller object.

% $Author: dberman $
% $Revision: 3604 $
% $Date: 2014-11-13 14:18:38 -0500 (Thu, 13 Nov 2014) $
% Copyright: MAKO Surgical corp (2008)


try
%Set the galilObj to the GalilTools COM wrapper
galctrl = actxserver('galil');
% Populate galil object
galctrl.address = address;

galilStruct.galctrl = galctrl;

catch
error('ERROR: Could not connect to controller.');
end




% return the object
galilObj = class(galilStruct,'galil_mc');


%---- END OF FILE -----
