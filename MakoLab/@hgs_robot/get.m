function varargout = get(hgs, varargin)
%GET overloading method for accessing hgs_robot elements 
%
% Syntax:  
%   GET(hgs,varName)
%       get the value of the variable_name from the hgs_robot.  This
%       applies to both read/write variables and configuration variables
%   [out1,out2,...] = GET(hgs,v1,v2,...)
%       get multiple variables from the hgs_robot.  number of requested
%       elements MUST equal number of outputs
%   [out1,out2] = GET(hgs)
%       returns all the available read/write variables as a structure out1
%       and all available configuration variables as structure out2 
% See also: 
%    hgs_robot/subsref, hgs_robot/plot, hgs_robot/collect
 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% check inputs and outputs
if (nargin==1)
    subrefArg.type = '()';
    subrefArg.subs = {':'};
    varargout{1} = subsref(hgs,subrefArg);
    subrefArg.type = '{}';
    varargout{2} = subsref(hgs,subrefArg);
    return;
end

if ((nargin>2)&&((nargin-1)~= nargout))
    error('Number of inputs and outputs MUST match');
end

% Query the robot for the variables
hgsData = commDataPair(hgs,'get_state','-DataPair');
hgsCfg = commDataPair(hgs,'get_cfg_params');
% start getting additional inputs and outputs
for i=1:(nargin-1)
    % check if this is a read variable, if not check cfg params
    try
        varargout{i}= hgsData.(varargin{i});
    catch
        if exist('hgsCfg','var')
            hgsCfg = commDataPair(hgs,'get_cfg_params');
        end
        try
            varargout{i}= hgsCfg.(varargin{i});
        catch
            error('Invalid variable or configuration parameter (%s)',...
                varargin{i});
        end
    end
end


% --------- END OF FILE ----------