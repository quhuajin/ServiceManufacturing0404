function returnValue = send_file(hgs,fullFileName,remoteFileName)
%SEND_FILE Send a file to store on the robot
%
% Syntax:  
%    SEND_FILE(hgs,fullFileName)
%       Send the file specified by fullFileName to the robot.  The file will be
%       saved on the robot with the same fileName.  directory information will
%       be stripped.  function will return 'DONE' on success
%    SEND_FILE(hgs,fullFileName,remoteFileName)
%       This will allow the user to specify a remote file name to save the file
%       to.  The remote file name could be a complete qualifying path specifying
%       the directory where the file needs to be stored.
%    SEND_FILE(hgs)
%       Opens up the UI to select the file to send.
%
% See also: 
%    hgs_robot, hgs_robot/get_file

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

% Now extract the name of the file without the directory name
[pathStr,fileName,ext] = fileparts(fullFileName);
fileName = [fileName,ext];


% Now send CRISIS The command to save the file
if (nargin~=3)
    remoteFileName = fileName;
end

returnValue = comm(hgs,'save_file',remoteFileName,fileContents);


% --------- END OF FILE ----------