function makeServiceMfgScripts(option)

% makeServiceMfgScripts Compile all the robot utilites and manufacturing to binaries
%
% Syntax:
%   makeServiceMfgScripts
%       This compiles all the required Binaries for the service and
%       manufacturing scripts
%
%   makeServiceMfgScripts clean
%       clean the previous builds
%
%   makeServiceMfgScripts RobotUtilitiesCD
%       This compiles and generates a directory that can be burn to a CD
%       for installing the RobotUtilities on voyager
%
%   makeServiceMfgScripts ServiceCD
%       This compiles and generates a directory that can be burn to a CD
%       for installing the RobotUtilities on voyager
%
%   makeServiceMfgScripts voyager
%       This compiles all the required Binaries for generating a service
%       and manufacturing CD
%
%   makeServiceMfgScripts RobotUtilitiesCDOnly
%       This option will just assemble the files needed to burn a CD to
%       install robot utilities
%
%   makeServiceMfgScripts ServiceCDOnly
%       This option will just assemble the files needed to burn a CD to
%       install service
%
% Notes:
%   It is assumed that you have the matlab compiler installed and licensed
%
%   To use an executable you will need both the binary and the _mcr
%   subdirectory
%
%   It is also assumed that the ExternalSoftware package from Mako and the
%   MakoLab directory from Mako are at the same level as the
%   HgsServiceManufacturing folder.
%
% See Also:
%   deploytool, makeRobotUtilities, makeQIPScripts
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% Setup constants
WIN_BIN_DIR = 'WindowsBinaries';
LINUX_BIN_DIR = 'LinuxBinaries';
CDROM_DIR = 'ServiceMfgCDROM';
ROBOT_UTIL_CDROM_DIR = 'RobotUtilCDROM';

if ispc
    BIN_DIR = WIN_BIN_DIR;
elseif isunix
    BIN_DIR = LINUX_BIN_DIR;
else
    error('Unsupported operating system');
end

ROBOT_UTILITIES_BIN = fullfile(BIN_DIR,'RobotUtilitiesBin');
QIP_SCRIPTS_BIN = fullfile(BIN_DIR,'QIPScriptsBin');

voyagerBuild = false;

% update paths with MakoLab path
makolabPath = strrep(pwd,'ServiceAndManufacturing','MakoLab');
addpath(makolabPath,fullfile(makolabPath,'mex'));

% check if this is an option to clean
if nargin==1
    if strcmpi(option,'clean')
        disp('Cleaning previous builds...');
        try
            rmdir(BIN_DIR,'s');
        catch
        end
        disp('done');
        
        % clean is complete exit immediately
        return;
    elseif strcmpi(option,'voyager')
        voyagerBuild=true;
        % do nothing just pass this option along
    elseif strcmpi(option,'ServiceCD')
        displayCompileVersion('Service Manufacturing CD');
        makemex
        makeServiceMfgScripts
        makeServiceMfgScripts ServiceCDOnly
        return;
    elseif strcmpi(option,'ServiceCDOnly')
        
        disp('Remove previous Builds...');
        try
            delete *.iso;
            rmdir(CDROM_DIR,'s');
        catch
        end
        disp('done');
        
        disp('Creating CDROM ...');
        
        % check if windows folders are included
        if ~exist(WIN_BIN_DIR,'dir')
            error(['No Windows Binaries found...please compile on a windows ',...
                'machine and copy the "WindowsBinaries" folder here']);
        end
        
        % Now create the CDrom folder and
        if ~exist(CDROM_DIR,'dir')
            mkdir(CDROM_DIR);
            mkdir(fullfile(CDROM_DIR,WIN_BIN_DIR));
        end
        
        copyfile(WIN_BIN_DIR,fullfile(CDROM_DIR,WIN_BIN_DIR));
        
        % copy the additional helper files
        copyfile(fullfile('Misc','*.vbs'),CDROM_DIR);
        copyfile(fullfile('Misc','*.inf'),CDROM_DIR);
        copyfile(fullfile('Misc','*.bat'),CDROM_DIR);
        copyfile(fullfile('Misc','*.ico'),CDROM_DIR);
        
        % compile the installer script
        % first check if the nsis compiler is installed
        disp('Compiling installer')
        [sysCmdResult,sysCmdReturn] =  system('makensis /version'); %#ok<NASGU>
        if sysCmdResult
            error(['makensis not found...Please make sure the NSIS',...
                'compiler is installed makensis is in the PATH']);
        end
        
        [compileResult,resultString] = system(['makensis /V2 /DVersion=(ver:',generateVersionString,') ',...
            fullfile('Misc','MakoService.nsi')]);
        if compileResult
            error('Error compiling NSIS script %s',resultString)
        end
        % If i got here installer was successfully created.  copy it to the
        % cdrom dir
        copyfile(fullfile('Misc','setup.exe'),CDROM_DIR);
        disp('Done');
        
        % copying Runtime Component
        disp('Copying Matlab Runtime Component');
        pause(0.01);
        %assume External Software project is one level up
        copyfile(fullfile('..','ExternalSoftware','MatlabRuntime','MCRInstaller.exe'),CDROM_DIR);
        disp('Done');
        
        % copy windows runtime redistributable
        disp('Copying VC++ 2010 Redistributable');
        pause(0.01);
        copyfile(fullfile('..','ExternalSoftware','VC-Redistributable','vcredist_x64.exe'),CDROM_DIR);
        disp('Done');
        
        % copy Galil runtime redistributable
        disp('Copying Galil Motor Controller Redistributable');
        pause(0.01);
        copyfile(fullfile('..','ExternalSoftware','GALIL','LibGalilRedist-1.6.4.552-Win-x64.exe'),CDROM_DIR);
        disp('Done');
        
        % copy NDI drivers and utilities
        disp('Copying NDI drivers and utilities...');
        copyfile(fullfile('..','ExternalSoftware','NDI_Drivers_USB'),...
            fullfile(CDROM_DIR,'NDI_Drivers_USB'));
        %rmdir(fullfile(CDROM_DIR,'NDI_Drivers_USB','.svn'),'s');
        disp('done');        
        
        disp('Generating pacakge files');
        
        % Copy the version string for later use
        updatedVersionString = generateVersionString;
        
        % generate a version file
        fid = fopen(fullfile(CDROM_DIR,'version'),'w');
        fprintf(fid,'%s',updatedVersionString);
        fclose(fid);
        
        % generate a package name file (this is for consistency)
        fid = fopen(fullfile(CDROM_DIR,'package'),'w');
        fprintf(fid,'Mako Service Manufacturing');
        fclose(fid);
        
        disp('done');
        
        % Generate the iso image
        disp('Generating ISO image')
        [sysCmdResult,sysCmdReturn] =  system(sprintf(['imgburn ',...
            '/MODE BUILD ',...
            '/OUTPUTMODE IMAGEFILE ',...
            '/SRC ServiceMfgCDROM ',...
            '/DEST ServiceMfg.iso ',...
            '/FILESYSTEM "UDF" ',...
            '/VOLUMELABEL %s ',...
            '/OVERWRITE YES ',...
            '/ROOTFOLDER YES ',...
            '/BUILDINPUTMODE STANDARD ',...
            '/CLOSE /NOIMAGEDETAILS ',...
            '/START'],updatedVersionString));
        disp('done');
        
        % clean up extra files
        disp('Cleaning temp files and directories');
        delete *.mds;
        rmdir(CDROM_DIR,'s');
        disp('done');
        
        disp('');
        disp('---------------------------------------');
        disp(['VERSION    : ',generateVersionString]);
        fprintf('ISO image created ServiceMfg.iso\n');
        disp('---------------------------------------');
        
        % exit now
        return
    elseif strcmpi(option,'RobotUtilitiesCD')
        displayCompileVersion('Robot Utilities CD');
        makemex
        makeServiceMfgScripts voyager
        makeServiceMfgScripts RobotUtilitiesCDOnly
        return;
    elseif strcmpi(option,'RobotUtilitiesCDOnly')
        
        disp('Remove previous Builds...');
        try
            delete *.iso;
            rmdir(ROBOT_UTIL_CDROM_DIR,'s');
        catch
        end
        disp('done');
        
        disp('Creating CDROM ...');
        
        % check if the linux folders are included
        if ~exist(LINUX_BIN_DIR,'dir')
            error(['No Linux Binaries found...please compile on a linux ',...
                'machine and copy the "LinuxBinaries" folder here']);
        end
        
        % Now create the CDrom folder and
        if ~exist(ROBOT_UTIL_CDROM_DIR,'dir')
            mkdir(ROBOT_UTIL_CDROM_DIR);
            mkdir(fullfile(ROBOT_UTIL_CDROM_DIR,LINUX_BIN_DIR));
            mkdir(fullfile(ROBOT_UTIL_CDROM_DIR,'VoyagerInstallFiles'));
        end
        
        copyfile(LINUX_BIN_DIR,fullfile(ROBOT_UTIL_CDROM_DIR,LINUX_BIN_DIR));
        
        % Adding voyager install files
        disp('Copy voyager installation files')
        
        copyfile(fullfile('RobotUtilities','Misc','configure'),...
            fullfile(ROBOT_UTIL_CDROM_DIR,'VoyagerInstallFiles'));
        copyfile(fullfile('RobotUtilities','Misc','configure.service'),...
            fullfile(ROBOT_UTIL_CDROM_DIR,'VoyagerInstallFiles'));
        copyfile(fullfile('RobotUtilities','Misc','setupMatlabEnv.sh'),...
            fullfile(ROBOT_UTIL_CDROM_DIR,'VoyagerInstallFiles'));
        copyfile(fullfile('Misc','installScript'),ROBOT_UTIL_CDROM_DIR);
        
        disp('Generating package files');
        
        % tweak the version number if this is from the main branch or has a
        % branch.  This is done by adding the compile date information
        if isempty(strfind(generateVersionString,'MainBranch')) ...
                && isempty(strfind(generateVersionString,'_branch'))
            updatedVersionString = generateVersionString;
            includeDateInfo = false;
        else
            buildDateString = datestr(now,'yyyy-mm-dd-HH-MM');
            updatedVersionString = [generateVersionString,'-',buildDateString];
            includeDateInfo = true;
        end
        
        % generate a version file
        fid = fopen(fullfile(ROBOT_UTIL_CDROM_DIR,'version'),'w');
        fprintf(fid,'%s',updatedVersionString);
        fclose(fid);
        
        % generate a package name file (this is for voyager only)
        fid = fopen(fullfile(ROBOT_UTIL_CDROM_DIR,'package'),'w');
        fprintf(fid,'Robot Utilities');
        fclose(fid);
        
        % generate a build date information file if needed
        if includeDateInfo
            fid = fopen(fullfile(ROBOT_UTIL_CDROM_DIR,'BUILD_DATE'),'w');
            fprintf(fid,buildDateString);
            fclose(fid);
        end
        
        disp('done');
        
        
        % Generate the iso image
        disp('Generating ISO image')
        
        % mkisofs allows volume names of max 32 chars.  so truncate name to
        % max of 31 chars
        if length(updatedVersionString)>31
            trim_length = 31;
        else
            trim_length = length(updatedVersionString);
        end
        
        [sysCmdResult,sysCmdReturn] =  system(sprintf(['mkisofs ',...
            '-V %s -J -R ',...
            '-o RobUtil.iso ',...
            '%s'],....
            updatedVersionString(1:trim_length),...
            ROBOT_UTIL_CDROM_DIR)); %#ok<NASGU>
        
        disp('done');
        if sysCmdResult
            error(sprintf(['Error creating ISO image...Please make sure mkisofs is installed',...
                'is in the windows PATH environment variable %s'],sysCmdReturn));
        end
        
        % clean up extra files
        disp('Cleaning temp files and directories');
        rmdir(ROBOT_UTIL_CDROM_DIR,'s');
        disp('done');
        
        disp('');
        disp('---------------------------------------');
        disp(['VERSION    : ',generateVersionString]);
        fprintf('ISO image created RobUtil.iso\n');
        disp('---------------------------------------');
        
        % exit now
        return
    else
        error(['Invalid option...valid options are ''clean'' ''voyager'''...
            ' ''RobotUtilitiesCD'' and ''ServiceCD'' ']);
    end
else
    option = 'all';
end

% Clean previous builds
makeServiceMfgScripts clean

% Make the folders for the compilation
if ~exist(BIN_DIR,'dir')
    mkdir(BIN_DIR);
    mkdir(ROBOT_UTILITIES_BIN);
    mkdir(QIP_SCRIPTS_BIN);
end

% Compile the robot utilities
makemex
disp('Building Robot Utilities....');
cd('RobotUtilities');
makeRobotUtilities(option);
cd('..');
copyfile(fullfile('RobotUtilities','RobotUtilitiesBin'),ROBOT_UTILITIES_BIN);
disp('Done');

if (voyagerBuild==false)
    % Compile the 2.X QIPs
    disp('Building QIP Scripts....');
    cd('QIP_2.x');
    makeQIPScripts(option)
    cd('..');
    copyfile(fullfile('QIP_2.x','QIPScriptsBin'),QIP_SCRIPTS_BIN);
    disp('Done');
    
    % Compiling top level loader
    fullPrjFile = fullfile('Misc','loadServiceMfgScripts.prj');
    fprintf('Now building...%s',fullPrjFile);
    % put a small pause to force the output to show on the screen
    pause(0.01);
    
    % Compile the file
    topLevelScriptDir = fullfile('Misc','Temp');
    if ~exist(topLevelScriptDir,'dir')
        mkdir(topLevelScriptDir);
    end
    
    % Compile the file
    deploytool('-build',fullPrjFile);
    
    % check if the build has completed.  Allow upto 1 min
    waitCount = 0;
    waitLimit = 120; % seconds
    disp('');
    while (~exist(fullfile(topLevelScriptDir,'loadServiceMfgScripts.exe'),'file') ...
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
        topLevelScriptDir,filesep,...
        'loadServiceMfgScripts','.ctf']);
    
    if result
        error(resultText);
    end
    
    loadFile = fullfile(topLevelScriptDir,'loadServiceMfgScripts');
    
    % Complie top level menu
    fullPrjFile = fullfile('Misc','ServiceAndManufacturingMain.prj');
    fprintf('Now building...%s',fullPrjFile);
    % put a small pause to force the output to show on the screen
    pause(0.01);
    
    % Compile the file
    topLevelScriptDir = fullfile('Misc','Temp');
    if ~exist(topLevelScriptDir,'dir')
        mkdir(topLevelScriptDir);
    end
    
    % Compile the file
    deploytool('-build',fullPrjFile);
    
    % check if the build has completed.  Allow upto 1 min
    waitCount = 0;
    waitLimit = 120; % seconds
    disp('');
    while (~exist(fullfile(topLevelScriptDir,'ServiceAndManufacturingMain.exe'),'file') ...
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
        topLevelScriptDir,filesep,...
        'ServiceAndManufacturingMain','.ctf']);
    
    if result
        error(resultText);
    end
    
    execFile = fullfile(topLevelScriptDir,'ServiceAndManufacturingMain');
    
    % Copy the files to the target directory
    if ispc
        compiledLoadFile = [loadFile,'.exe'];
        compiledFileName = [execFile,'.exe'];
    else
        compiledLoadFile = loadFile;
        compiledFileName = execFile;
    end
    
    copyfile(compiledFileName,BIN_DIR);
    copyfile([execFile,'.ctf'],BIN_DIR);
    movefile([execFile,'_mcr'],BIN_DIR);
    copyfile(compiledLoadFile,BIN_DIR);
    copyfile([loadFile,'.ctf'],BIN_DIR);
    movefile([loadFile,'_mcr'],BIN_DIR);
    
    disp('done');
end

% All Compilation is complete

disp('---------------------------------------');
disp(['Compilation complete...binaries are in ',BIN_DIR]);
disp('---------------------------------------');

% restore Version file


%-------------------------------------------------------------------------
% Internal function to display the compile version
%-------------------------------------------------------------------------
    function displayCompileVersion(str)
        % Display what is being compiled
        fprintf('\n---------------------------------------------------------\n');
        disp(['Compiling : ',str]);
        disp(['VERSION   : ',generateVersionString]);
        fprintf('---------------------------------------------------------\n');
        pause(2);
    end

end

% --------- END OF FILE ----------
