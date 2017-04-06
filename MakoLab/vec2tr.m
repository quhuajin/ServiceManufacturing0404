function transform = vec2tr(vector,check)
%VEC2TR convert a 16x1 vector to a 4x4 homogenous transform
%
% Syntax:  
%   vec2tr(vector)
%       this converts the vector to a 4x4 homogenous transform
%   vec2tr(vector,check)
%       setting the check to true will enable checking the transform to
%       make sure it is a valid homogenous transform before converting
%

% $Author: rzhou $
% $Revision: 2116 $
% $Date: 2010-02-11 15:15:37 -0500 (Thu, 11 Feb 2010) $
% Copyright: MAKO Surgical corp 2007

transform = reshape(vector,4,4)';

if nargin==2 && check
    if (det(transform(1:3,1:3))-1)>1e-6
        transform=-1;
    elseif (transform(4,1:4)~=[0 0 0 1])
        transform=-1;
    end
end
        

%------------- END OF FILE ----------------
