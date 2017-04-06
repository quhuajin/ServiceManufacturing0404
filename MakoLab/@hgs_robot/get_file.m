function returnValue = get_file(hgs,remoteFileName,localFileName)
%get_file Get a file contents of a file stored on the robot
%
% Syntax:  
%    get_file(hgs,remoteFileName)
%       Read data from a remote file stored on the robot
%    get_file(hgs,remoteFileName,localFileName)
%       Read and save the contents of the remote file to a local file specified
%       by localFilename
%
% See also: 
%    hgs_robot, hgs_robot/send_file

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% Remember that currently CRISIS supports only 50KB at a time
% so keep reading till the filecontent size is less than 50KB
fileReadComplete = false;
fileOffset = 0;
returnValue = '';
while ~fileReadComplete
    crisisReply = crisisComm(hgs,'get_file',remoteFileName,fileOffset);
    readSize = parseCrisisReply(crisisReply,1);
    returnValue = [returnValue,parseCrisisReply(crisisReply,2)]; %#ok<AGROW>
    fileOffset = fileOffset + readSize;
    if (readSize~=(50*1024) || (readSize==0))
        fileReadComplete = true;
    end
end

% check if we want to save the contents to a file
if nargin==3
    [fid,message] = fopen(localFileName,'w');
    if (fid==-1)
        error('Unable to open file for writing (%s)',message);
    end
    fwrite(fid,returnValue);
    fclose(fid);
end


% --------- END OF FILE ----------