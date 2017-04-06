function commandReply = load_arm_software(hgs,fullFileName)
%LOAD_ARM_SOFTWARE start a specific version of CRISIS
%
% Syntax:  
%    LOAD_ARM_SOFTWARE(hgs,fullFileName)
%       the file name is assumed to be the installation file that will be
%       executed on the remote machine
%
% See also: 
%    hgs_robot, hgs_robot/reconnect

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

if (nargin<2)
    [fileName,pathStr] = uigetfile('*.*');
    fullFileName = [pathStr,fileName];
end

% Read the raw file.  All files will be treated as raw binaries
fid = fopen(fullFileName);
fileContents = fread(fid,'*uint8');
fclose(fid);

commandReply = comm(hgs,'load_arm_software',fileContents);

% wait about 15 seconds to allow restart
% parse the data
totalWaitTime = 15; %sec
updateRate = 0.05; %secs per update
h = waitbar(0,'Please wait...', ...
            'Name', 'Waiting for CRISIS restart', ...
            'visible', 'off');
movegui(h,'north');
set(h,'visible', 'on');
for i=0:updateRate:totalWaitTime
    waitbar(i/totalWaitTime,h,...
        sprintf('Waiting for CRISIS restart (%2.2f sec)',totalWaitTime-i));
    pause(updateRate);
    drawnow;
end
close(h);

% close currently existing connections
reconnect(hgs);


% --------- END OF FILE ----------