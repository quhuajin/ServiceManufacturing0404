function [localvars,inputvars] = get(haptic)
%GET get parameter list for a Hgs Haptic object
%
% Syntax:
%
%   GET(hapticObj)
%      Get the parameter list of the hgs_haptic object <hapticObj>, 
%      which is created by hgs_haptic/hgs_haptic.
%
%
% Notes:
%
% See also:
%   hgs_haptic/hgs_haptic
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

%
if nargin==1    

    cellparams=cell(1,length(haptic.inputVars));
    
    if (~haptic.isHapticObjInRobot)
        % This is only used for empty haptic object for now, since all 
        % other haptic object created is in the hgs_robot object
        % automatically
        
       params=haptic.inputVars;
       k=1;
       for i=1:length(params)  
           myName=params(i).name;
           if(strcmp(params(i).type,'s')||strcmp(params(i).type,'c'))
               if(isempty(params(i).value))
                   params(i).value='''''';
               end
               cellparams{k}=myName;
               cellparams{k+1}=params(i).value;
               k=k+2;
           else
               cellparams{k}=myName;
               cellparams{k+1}=params(i).value;
               k=k+2;
           end
       end

       inputvars=struct();
       
       for i=1:2:length(cellparams)
          if(~isfield(inputvars,cellparams(i)))
            inputvars.(cellparams{i})=cellparams{i+1};
          end
       end       
       localvars='no_local';
       
    else 
        %query the local and input variables
        if(isa(haptic.hgsRobot,'hgs_robot'))
            localvars=parseCrisisReply(crisisComm(haptic.hgsRobot,...
                'get_haptic_object_local_state',haptic.name),'-DataPair');
            inputvars=parseCrisisReply(crisisComm(haptic.hgsRobot,...
                'get_haptic_object_input',haptic.name),'-DataPair');
        else
            error('Argument #2 is not a hgs_robot object');
        end
    end
else
    help('hgs_haptic/get');
    
end




% --------- END OF FILE ----------