function hapticTemp=create_prototype_haptic_obj(hgs,paramStr,type)
%CREATE_PROTOTYPE_HAPTIC_OBJ create a Hgs Haptic object prototype
%
% Syntax:
%   CREATE_PROTOTYPE_HAPTIC_OBJ(hgs,paramStr,type)
%    Create a struct to hold the parameters for the haptic object of the
%    specific type<type>.
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

hapticTemp.name=sprintf('%s___prototype',type);
hapticTemp.type=type;
hapticTemp.hgsRobot=hgs;
hapticTemp.isHapticObjInRobot=false;
hapticTemp.isChanged=false;

%Create a struct for the haptic object with default values.
i=1;
while(i<=length(paramStr)) 
    if(strcmp(paramStr(i),'REQUIRED INPUTS :'))
        j=1;
        while(~strcmp(paramStr(i+1),''))            
            hapticTemp.inputVars(j)=parse_params(paramStr(i+1),'REQUIRED');
            i=i+1;
            j=j+1;
        end
    elseif(strcmp(paramStr(i),'OPTIONAL INPUTS :'))
        while(~strcmp(paramStr(i+1),''))
            hapticTemp.inputVars(j)=parse_params(paramStr(i+1),'OPTIONAL');
            i=i+1;
            j=j+1;
        end
    elseif(strcmp(paramStr(i),'DERIVED INPUTS :'))
        while(~strcmp(paramStr(i+1),''))
            hapticTemp.inputVars(j)=parse_params(paramStr(i+1),'DERIVED');
            i=i+1;
            j=j+1;
        end
    end
    i=i+1;
end
end


% --------- END OF FILE ----------