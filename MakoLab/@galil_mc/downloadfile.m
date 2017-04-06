function downloadfile (galilObj,filename)

% DOWNLOADFILE is used to download a ".DMC" file to the controller.
% 
% Syntax:
%     downloadfile(galil_mc,filename)
%     galil_mc is a GALIL controller object
%     filename is the string corresponding to the file name (including '.dmc')
%     extension. 
%     Example:
%         downloadfile(galil_mc,'homing.dmc')
         
% $Author: dberman $
% $Revision: 3604 $
% $Date: 2014-11-13 14:18:38 -0500 (Thu, 13 Nov 2014) $
% Copyright: MAKO Surgical corp (2008)
%
%%
galilObj.galctrl.programDownloadFile(filename);
end