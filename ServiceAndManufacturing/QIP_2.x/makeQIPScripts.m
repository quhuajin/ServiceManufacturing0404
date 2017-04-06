function makeQIPScripts(option)

% makeQIPScripts Compile all the robot utilites to binaries
%
% Syntax:
%   makeRobotUtilities
%       This compiles all the Robot utility scripts.  All the scripts are
%       compiled in the RobotUtilities/Temp directory and the final
%       binaries are moved to RobotUtilites/RobotUtilites/bin directory
%
%   makeRobotUtilities clean
%       Cleans and removes all compiled code
%
% Notes:
%   It is assumed that you have the matlab compiler installed and licensed
%
%   This script MUST be run from the RobotUtilities directory
%
%   To use an executable you will need both the binary and the _mcr
%   subdirectory
%
% See Also:
%   mcc, makeRobotUtilities
%

%
% $Author: dmoses $
% $Revision: 3679 $
% $Date: 2014-12-15 18:25:21 -0500 (Mon, 15 Dec 2014) $
% Copyright: MAKO Surgical corp (2008)
%

voyagerScripts = {};

% Setup constants
BIN_DIR = 'QIPScriptsBin';
COMPILE_DIR = 'Temp';
compileVoyagerScriptsOnly = false;

% check if this is an option to clean
if nargin==1
    if strcmpi(option,'clean')
        disp('Cleaning previous builds...');
        try
            rmdir(BIN_DIR,'s');
            rmdir(COMPILE_DIR,'s');
        catch
        end
        disp('done');
        
        % clean is complete exit immediately
        return;
    elseif strcmpi(option,'voyager')
        compileVoyagerScriptsOnly = true;
    elseif strcmpi(option,'all')
        % do nothing special this is the default
    else
        error('Invalid option...valid options are ''clean''');
    end
end

% Clean previous builds
makeQIPScripts clean

% Make the folders for the compilation
if ~exist(COMPILE_DIR,'dir')
    mkdir(COMPILE_DIR);
end

if ~exist(BIN_DIR,'dir')
    mkdir(BIN_DIR);
end

% find all the sub directories
fileList = dir;

for i=1:length(fileList)
    
    % check if this is a valid directory
    if fileList(i).isdir ...
            && ~strcmp(fileList(i).name,'.') ...
            && ~strcmp(fileList(i).name,'..')
        
        % check if there is a project file to be built
        prjFile = dir(fullfile(fileList(i).name,'*.prj'));
        
        if ~isempty(prjFile)
            % make sure there is only one project per directory
            if length(prjFile)~=1
                cd ..
                error('Multiple project files in directory %s',...
                    fileList(i).name);
            end

            [~,execFile] = fileparts(prjFile.name);
            % check if this file is needed for this build
            if compileVoyagerScriptsOnly ...
                    && ~any(strcmpi(voyagerScripts,execFile))
                continue;
            end
            
            fullPrjFile = fullfile(fileList(i).name,prjFile.name);
            fprintf('Now building...%s\n',fullPrjFile);
            % put a small pause to force the output to show on the screen
            pause(0.01);
            
            % Compile the file
            deploytool('-build',fullPrjFile);
            
            % check if the build has completed.  Allow upto 7 min
            waitCount = 0;
            waitLimit = 60*7; % seconds
            disp('');
            while (~exist(fullfile(COMPILE_DIR,[execFile,'.exe']),'file') ...
                    && (waitCount<waitLimit))
                fprintf('*');
                pause(5);
                waitCount=waitCount+5;
            end
            if waitCount>=waitLimit
                error('Compile timeout');
            end
            fprintf('\ndone...took approx %d seconds\n',waitCount');
            pause(2);
            
            % Extract the binaries
            disp('Extracting Binaries..');
            
            [result,resultText] = system(['extractCTF ',...
                COMPILE_DIR,filesep,execFile,'.ctf']);

            if result
                error(resultText);
            end
            
            % Copy the files to the target directory
            if ispc
                compiledFileName = [execFile,'.exe'];
            else
                compiledFileName = execFile;
            end
            
            copyfile(fullfile(COMPILE_DIR,compiledFileName),BIN_DIR);
            copyfile(fullfile(COMPILE_DIR,[execFile,'.ctf']),BIN_DIR);
            movefile(fullfile(COMPILE_DIR,'*_mcr'),BIN_DIR);

            disp('done');
        end
    end
end

disp(['Compilation complete...binaries are in ',BIN_DIR]);

% --------- END OF FILE ----------
