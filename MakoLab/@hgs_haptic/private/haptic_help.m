function paramStr=haptic_help(obj,name,varargin)
%HAPTIC_HELP display help infomation for a specific Hgs Haptic object <obj>
% with type <type>
%
% Syntax:
%   HAPTIC_HELP(obj,type,varargin)
%    Display the help information based on the input argument number and
%    type.
%
% Notes:
%
% See also:
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%
%

if nargin == 1
    display('Input argument #2 is missing or incorrect, which should be');
    display('an existing haptic object name.The haptic object');
    display('name should use the following naming convention:')
    display('<haptictype>___<hapticobjectname>')
    display(' ');
    %query existing haptic objects
    [cm,ho] = status(obj);    
    display('Existing haptic objects:');
    nHapticObj=length(ho);
    for i=1:nHapticObj        
        display(ho(i));
    end
    %query supported haptic object types
    myStr=strcat(char(parseCrisisReply(crisisComm(obj,...
        'get_haptic_object_info'),1)));
    myType=regexp(myStr,'\n','split');
    display('Supported haptic object types:')
    
    myLength=length(myType);
    for i=1:5:myLength %display 5 types in one row
        if(i+5>=myLength)
            disp(myType(i:myLength));
        else
            disp(myType(i:i+4));
        end
    end

elseif nargin == 2    
    %query the existing haptic object infomation
    type = cell2mat(regexp(name, '(?i)\w*(?=___)',...
                    'match'));
    myStr=strcat(char(parseCrisisReply(crisisComm(obj,...
        'get_haptic_object_info',type),1)));
    paramStr=regexp(myStr,'\n','split');
end
end




% --------- END OF FILE ----------