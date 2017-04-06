function delete(haptic)
%DELETE delete a Hgs Haptic object
%
% Syntax:
%
%   Delete(hapticObj)
%    Delete a haptic object <hapticObj> 
%
% Notes:
%
%   
% See also:
%   hgs_haptic/hgs_haptic,hgs_robot/hgs_robot,hgs_robot/status
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%
%

if (nargin ~=1||(~isa(haptic,'hgs_haptic')))
    help('hgs_haptic/delete');
else
    comm(haptic.hgsRobot,'delete_haptic_object',haptic.name);
end

end




% --------- END OF FILE ----------