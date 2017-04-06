function set (galilObj, prop, val)

% SET is used to set a property or value within a GALIL 
% controller from MATLAB.
% 
% Syntax:
%     set(galil_mc, prop, val)
%     galil_mc is a GALIL controller object
%     prop is any string corresponding to the GALIL commands
%     val is the desired value to be set to the property
%     Example: 
%       set(Motor1, 'SPEED', 50000)
%       Sets Motor1 variable SPEED to 50000.
%     

% $Author: dberman $
% $Revision: 2272 $
% $Date: 2014-11-21 12:20:14 -0400 (Wed, 12 Nov 2014) $
% Copyright: Stryker Mako (2014)
%
%%    

if ~ischar(prop)
    disp('Property Must Be A String')
    return
end

galilProp = {'AC' 'DC' 'DP' 'ER' 'SP' 'TL' 'PA' 'VA' 'VD' 'AG' 'KD' 'KP' 'KI'};

if ismember(prop, galilProp)
    comm(galilObj,[prop ' ' num2str(val)]);
else
    
    comm(galilObj,[prop ' = ' num2str(val)]);    
end