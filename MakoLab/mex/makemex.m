function makemex(varargin)
%MAKEMEX Internal 'makefile' like function to make all the mex files 
%
% Syntax:
%   makemex 
%       builds/rebuilds all the mex files in MakoLab
%   makemex clean
%       removes all previous builds
%   makemex <options> ...
%       use any of the mex options to compile all the mex functions.  For a
%       complete list of options supported by mex see documentation for mex.
%
% Example:
%   makemex -g -O
%       make with debugging and optimization.  
%   makemex -v
%       be verbose during compilation
%   
% Notes:
%   the function deletes all the libraries and executable files and
%   recompiles them.
%   The old files will not be deleted and a warning will be issued
%   if any of the libraries are in use.
% 
% See Also:
%   mex
%

% $Author: dberman $
% $Revision: 3602 $
% $Date: 2014-11-05 19:02:46 -0500 (Wed, 05 Nov 2014) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% Assume that the makemex is in the same directory as the mex files to compile
% also if this has been called from matlab and matlab has recoganized it is
% assumed that this is in the path.  Extract this information and move to that
% directory

mexDirName = fileparts(which('makemex'));

% save current directory to comeback to on exit
currentDir = pwd;

% Now change to the mex directory and start the compilation process
cd(mexDirName);

% delete previously compiled files if any
delete(['*.',mexext]);

% check if this is a request to clean, if so do not rebuild, quit
% immediately
if (nargin~=0) && (strcmpi('clean',varargin{1}))
    cd(currentDir);
    return;
end


% if there are any libraries or c files declared these must be included as
% linking options

compileOptions = varargin;

% Add additional options if any as shown below
if (ispc)
   socketLib = {'wsock32.lib'};
else
    socketLib = {};
end

% now start recompiling
try
mex(compileOptions{:},'sendReceiveCrisisComm.c','crisis_communication.c',socketLib{:})
mex(compileOptions{:},'openCrisisConnection.c',socketLib{:})
mex(compileOptions{:},'matlabtoCrisisComm.c','crisis_communication.c') 
mex(compileOptions{:},'closeCrisisConnection.c',socketLib{:}) 
mex(compileOptions{:},'convertBytesToFloat.c')
mex(compileOptions{:},'convertBytesToDouble.c')
mex(compileOptions{:},'parseCrisisReply.c','crisis_communication.c')
mex(compileOptions{:},'parseCrisisReplyByLocation.c','crisis_communication.c')
mex(compileOptions{:},'mod2polygon.c')
mex(compileOptions{:},'convertStructToString.c')
display('All mex files successfully compiled');
catch
    % There was a compile error
    % return to the original directory and show the error again.
    cd(currentDir);
    rethrow(lasterror);
end


% return to the original directory
cd(currentDir);
end

%---------------------------------------------------
% Internal Function for finding the compiler that has been setup with 
% mex -setup
%---------------------------------------------------

function compilerType = findWin32Compiler
    compilerType = '';

    % open the mexopts file where the compiler name is stored
    fid = fopen(fullfile(prefdir,'mexopts.bat'),'r');
    if (fid==-1)
        error('mexopts file error, make sure mex has been setup');
    end
    
    % read line by line to determine the compiler name
    while(~feof(fid))
        optionLine = fgetl(fid);
        if (~isempty(findstr('COMPILER=',optionLine)))
            % compiler line found 
            % extract the name
            compilerType = sscanf(strtrim(optionLine),'set COMPILER=%s');
            break;
        end
    end
    fclose(fid);
   
end


% --------- END OF FILE ----------