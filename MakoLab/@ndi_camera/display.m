function display(cameraObj)
%DISPLAY Overloaded method to display parameters of the ndi camera
%
% Syntax:  
%   display(ndi)
%   ndi
%       displays the identifying elements of the ndi_camera object.  This
%       includes the name of the host, and the type of camera connected
% 
% See Also:
%   ndi_camera
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

disp(' ')
disp(sprintf('%s.type : %s',inputname(1),cell2mat(cameraObj.type)))
disp(sprintf('%s.host : %s',inputname(1),cameraObj.host))
disp(' ')


% --------- END OF FILE ----------