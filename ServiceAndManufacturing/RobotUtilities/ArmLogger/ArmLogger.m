function ArmLogger 
% 
% ArmLogger wrapper function to view all robot variables

% Syntax:  
%   ArmLogger
%       Starts up the GUI to allow the user to view logs on the robot
%
% Notes:
%   The function is implemented in the MakoLab project.  This script is
%   heavily used in makolab and hence is maintained there.
%   
% See also: 
%    hgs_loginfo, crisis_logger

% 
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% connect to the default robot
try
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end

    log_message(hgs,'Arm Logger Script Started');
    figHandle = crisis_logger(hgs);
catch %#ok<CTCH>
    errordlg(lasterr); %#ok<LERR>
    return;
end

% wait for the figure handle to terminate
while any(allchild(0)==figHandle)
    pause(0.2);
end

log_message(hgs,'Arm Logger Script Closed');

% close the connection
close(hgs);
end

% --------- END OF FILE ----------
