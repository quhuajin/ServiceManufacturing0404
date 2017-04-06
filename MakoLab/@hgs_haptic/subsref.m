function out = subsref(haptic, field)
%SUBSREF overloading method for accessing hgs_haptic elements
%
% Syntax:
%   haptic(:) or haptic()
%       returns a structure with all the input variables from the
%       hgs_haptic object <haptic>
%
%   haptic.name or haptic.type
%       returns the name or type of the haptic object <haptic>
%
% Notes:
%
% See also:
%    hgs_haptic, hgs_haptic/get, hgs_haptic/set

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%
switch length(field)
    case 1
        switch field.type
            case '()'
                if (isempty(field.subs) || strcmp(field.subs{1},':'))
                    out  = get(haptic);
                else
                    error('Unsupported use of method');
                end

            case '.'
                switch field.subs
                    case 'name'
                        out = haptic.name;
                    case 'type'
                        out = haptic.type;
                    case 'hgsRobot'
                        out = haptic.hgsRobot;
                    case 'isHapticObjInRobot'
                        out = haptic.isHapticObjInRobot;
                    case 'isChanged'
                        out = haptic.isChanged;
                    case 'inputVars'
                        out = haptic.inputVars;
                    otherwise
                        error('Invalid field name')
                end
            otherwise
                error('Unsupported index method')
        end
        
end


% --------- END OF FILE ----------