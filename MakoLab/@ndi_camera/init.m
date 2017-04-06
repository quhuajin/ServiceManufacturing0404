function reply = init(ndi)
%INIT Initialize the ndi camera system
%
% Syntax:
%   init_tool(ndi,filename)
%       This command clears all the loaded tools on the camera.  and performs
%       intialization of the ndi camera.  The function returns OKAY if 
%       if successful.  The function will report the appropriate error if any of 
%       the initialization commands are not successful.
%
% Notes:
%   This function will makes the following NDI API calls
%       INIT
%       IRATE
%
% See also:
%   ndi_camera, ndi_camera/setmode, ndi_camera/comm, ndi_camera/init_tool
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

%initialize the camera
comm(ndi,'INIT ');

%setup the camera for the maximum IR rate
reply = char(comm(ndi,'IRATE 2'));

% send reply to user
reply = reply(1:end-5);


%---- END OF FILE -----