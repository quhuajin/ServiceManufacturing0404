function haptic = set( haptic,varargin )
%SET set parameter of a Hgs Haptic object or its prototype
%
% Syntax:
%
%   SET(hapticObj,'name','haptic object name',
%                 'param1',value1,'param2',value2,...)
%    Set the paramter of the input haptic object,if <name> is specified,
%    the return haptic object will have a different name. 
%
% Notes:
%    
%
% See also:
%   hgs_haptic/hgs_haptic,hgs_haptic/get, hgs_robot/status
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

%
if ((nargin>2) && rem(nargin,2))
    if isa(haptic,'hgs_haptic')    
        for i=2:2:nargin
            %check if a ne haptic object name is provided
            if(strcmp(varargin(i-1),'name'))
                    myStr = regexp(haptic.name, '\w*___','match');
                    haptic.name=strcat(myStr,varargin(i));                
            else
                %only change the variable values
                for j=1:length(haptic.inputVars)
                    if(strcmp(haptic.inputVars(j).name,varargin(i-1)))
                        if(iscell(varargin(i)))
                            myVar=cell2mat(varargin(i));
                        else
                            myVar=varargin(i);
                        end                        
                        
                        if(length(myVar)==haptic.inputVars(j).size)
                            haptic.inputVars(j).value=myVar;
                        else
                            myStr=sprintf('%s expect %d values, get %d',...
                                haptic.inputVars(j).name,haptic.params(j).size,...
                                length(myVar));
                            disp(myStr);
                            return;
                        end

                    end
                end
            end
        end

    else
        help('hgs_haptic/set');
    end
else
    help('hgs_haptic/set');
end
end




% --------- END OF FILE ----------