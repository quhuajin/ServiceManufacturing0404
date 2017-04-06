function haptic = hgs_haptic(obj,name,varargin)
%HGS_HAPTIC Constructor for Hgs Haptic object
%
% Syntax:
%   HGS_HAPTIC(robotObj,hapticObjName)
%    Constructor for a hgs_haptic object, create a hgs_haptic object from 
%    an existing haptic object in <robotObj>, the haptic object name is
%    <hapticObjName>.
%
%   HGS_HAPTIC(robotObj,hapticObjName,stlFileName,requiredInputs)
%    Constructor for a hgs_haptic object, create a Polygon hgs_haptic 
%    object from stl file, the haptic object name is <hapticObjName>, and
%    requiredInputs are list of input arguments required for the polygon 
%    object, see examples in makolabdemo.m for detail.
%
%   HGS_HAPTIC(robotObj,hapticObjName,'input1',value1,'input2',value2,...)
%    Constructor for a hgs_haptic object, create a new hgs_haptic object in
%    a hgs_robot object<robotObj>,with given name <hapticObjName> and
%    inputs list.
%
%   HGS_HAPTIC(hapticObj)
%    A copy constructor for a hgs_haptic object.
%
%
% Notes:
%   use <methods('hgs_haptic')> to find out the public interfaces of the class.
%
% See also:
%   hgs_robot/hgs_robot, makolabdemo
%

%
% $Author: kziaei $
% $Revision: 1722 $
% $Date: 2009-05-19 16:30:57 -0400 (Tue, 19 May 2009) $
% Copyright: MAKO Surgical corp (2007)
%

%
isHapticCreated=false;
if nargin == 0
        error('Required argument hgs robot object is not specified');    
elseif nargin == 1
    if(isa(obj,'hgs_robot'))        
        haptic_help(obj);
        error('Required input arguments missing.');
    elseif(isa(obj,'hgs_haptic'))
        haptic=obj;
        haptic=class(haptic,'hgs_haptic');
        isHapticCreated=true;
    else
        help('hgs_haptic/hgs_haptic');
        error('Input argument #1 must be a hgs_robot object.');
    end

elseif nargin == 2
    if isa(obj,'hgs_robot')
        [cm, ho] = status(obj);
        nHapticObj=length(ho);
        hapticType = cell2mat(regexp(name, '(?i)\w*(?=___)',...
                    'match'));
        for i=1:nHapticObj
            if(strcmp(ho(i),name))
                %Display haptic object exist
                displayText=sprintf('Haptic object %s exists.',name);
                disp(displayText);
                %create a prototype haptic struct
                paramStr=haptic_help(obj,name);

                myHaptic=create_prototype_haptic_obj(obj,paramStr,...
                    hapticType);

                %get paramter for haptic object speicifed by name <inStr>
                myStr=parseCrisisReply(crisisComm(obj,...
                    'get_haptic_object_input',name),...
                    '-DataPair');
                
                %change the haptic object struct of the existing haptic
                %object
                haptic=create_haptic_struct(myHaptic,myStr,name);

                %create a hgs_haptic object for existing haptic object
                haptic=class(haptic,'hgs_haptic');
                isHapticCreated=true;
                break;
            end
        end
        % Haptic object with matched name does not exist,display help for 
        % creating new haptic object 
        if(~isHapticCreated)            
            haptic_help(obj);
            display('To create a haptic object, use the overloaded');
            display('hgs_haptic() with input arguments.');
            display('use <help hgs_haptic/hgs_haptic> for detail. ');
            error('Haptic object <%s> does not exist!',name);

        end
        
    end
    
elseif(nargin>2) %assume at least one input required for a haptic object
    paramStr=haptic_help(obj,name);
    
    hapticType = cell2mat(regexp(name, '(?i)\w*(?=___)',...
        'match'));    
    haptic=create_prototype_haptic_obj(obj,paramStr,hapticType);

    %create a default hgs_haptic object of <inStr>.
    haptic=class(haptic,'hgs_haptic');

    haptic.name=name;
    %create a haptic object prototype in order to que
    haptic=create(haptic,varargin{:});

    haptic.isHapticObjInRobot=true;
    isHapticCreated=true;

end


%create an empty haptic object to avoid matlab uninitialized output error
if(~isHapticCreated)
    haptic.name='no_haptic';
    haptic.type='no_type';
    haptic.hgsRobot='no_robot';
    haptic.isChanged=false;
    haptic.inputVars=struct('name','no_input','type','s','size',1,...
        'category','REQUIRED','value',' ');
    haptic.hgsRobot=struct('name','no_robot');
    haptic=class(haptic,'hgs_haptic');   
    haptic.isHapticObjInRobot=false;
    help('hgs_haptic/hgs_haptic');
    error('Required input arguments missing.')
end
end




% --------- END OF FILE ----------