function hapticStruct=create_haptic_struct(hapticPrototype,...
    hapticObjParams,hapticObjName)
%CREATE_HAPTIC_STRUCT create a haptic strycture for Hgs Haptic object
%
% Syntax:
%   CREATE_HAPTIC_STRUCT(hapticPrototype,hapticObjParams,hapticObjName)
%    Create a haptic structure for hgs_haptic object based on the prototype
%    <hapticPrototype>, and the existing haptic object parameter 
%    <hapticObjParams>.     
%       
%
% Notes:
%   use 'methods(haptic)' to find out the public interfaces of the class.
%
% See also:
%   hgs_robot/hgs_robot
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 
% 
hapticPrototype.name=hapticObjName;
myType = cell2mat(regexp(hapticObjName, '(?i)\w*(?=___)','match'));
hapticPrototype.type=myType;   
hapticPrototype.isHapticObjInRobot=true;

myFieldNames=fieldnames(hapticObjParams);
myOut = zeros(1, length(myFieldNames));
for n = 1:length(myOut)
    for m=1:length(hapticPrototype.inputVars)
        if(strcmp(hapticPrototype.inputVars(m).name,myFieldNames(n)))
            myStr=hapticObjParams.(myFieldNames{n});
            switch (hapticPrototype.inputVars(m).type)
                case 'f'
                    hapticPrototype.inputVars(m).value=myStr;
                case 's'
                    if(iscell(myStr))
                        myStr=cell2mat(myStr);
                    end
                    hapticPrototype.inputVars(m).value=myStr;
                case 'd'
                    hapticPrototype.inputVars(m).value=myStr;
                case 'c'
                    hapticPrototype.inputVars(m).value=str2mat(myStr);
                otherwise
                    error('Unsupported %s variable type found.',hapticPrototype.inputVars(m).category);
            end
        end
    end
end

hapticStruct=hapticPrototype;
end


% --------- END OF FILE ----------