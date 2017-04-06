function haptic = subsasgn(haptic, field, value)
%SUBSASGN overloading method for editing hgs_haptic object name
%
% Notes:
%   This method only supports change of the haptic object name, this is to
%   make it possible to delete a haptic object without creating new haptic
%   object,instead, only changing the name of an existing haptic object.
%
%
% See also: 
%    hgs_haptic, hgs_haptic/get, hgs_haptic/subsref
 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

if (length(field)~=1)
    error('Only single referncing supported');
else
    % name is a special field of the haptic object.
    if (strcmp(field.subs,'name'))
        haptic.name = char(value);
    end
end



% --------- END OF FILE ----------