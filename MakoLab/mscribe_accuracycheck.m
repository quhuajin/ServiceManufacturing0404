function mscribe_accuracycheck(varargin)
%ACCURACYCHECK performs pivot accuracy check on the micro scribe arm

% Syntax:
%   mscribe_accuracycheck(varargin)
%
% Note:
%   The tool has to be calibrated following the procedure listed in the
%   micro scribe application software.
%

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%

%% Accuracy Check

% Connect to the micro scribe arm
if(nargin == 0)
    msArm = mscribe();
else
    msArm = varargin{1};
end
disp('Place magnetic socket on the fixed ball and press Enter take first measurement');
pause()
pinit = get(msArm,'position');
clear error
error = [];
vals = [];
for n = 1:10
    disp(['press enter to collect point ', num2str(n)])
    pause()
    p = get(msArm,'position');
    error = [error;norm(pinit-p)];
    vals = [vals;norm(pinit-p),p] %for debugging
%     
end
% display results
disp('RESULTS...')
disp(['Mean: ', num2str(mean(error))])
disp(['Max: ',num2str(max(error))])
disp(['std: ',num2str(std(error))])

disconnect(msArm);

%--------- END OF FILE -------