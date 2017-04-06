function [rms_result]=rms(values)
% rms 
%
% Calculates RMS of input [1 x n] or [n x 1] array
%
% Syntax:
%   [rms_result] = rms(values)
%       

% $Author: jmorgan $
% $Revision:  $
% $Date: 
% Copyright: MAKO Surgical corp (2007)
%

rms_result = sqrt(sum(values.^2)/length(values));

end