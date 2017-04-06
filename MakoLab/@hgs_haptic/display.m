function display(hgs_haptic)
%DISPLAY Overloaded method to Display the value of a hgs robot object
%
% Syntax:  
%   DISPLAY(haptic)
%      displays the identifying elements of the hgs_haptic object <haptic>.
%      This includes the object's name, type and the host 
%      hgs_robot object name. 
% 
% See Also:
%   hgs_haptic/subsref
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

display(sprintf('Haptic.name: %s',hgs_haptic.name));
display(sprintf('Haptic.type: %s',hgs_haptic.type));
display(sprintf('Hgs.name: %s',hgs_haptic.hgsRobot.name));



% --------- END OF FILE ----------