function checkCfgParams(hgs)
% CheckCfgParams Service script to check the configuration file
%
% Syntax:
%   CheckCfgParams
%       Starts up the GUI to allow the user to check the configuration file
%
% Notes:
%   The given configuration file is compared to the default configuration
%   file stored as defaultCfgFile.  This file contains the default values
%   for configuration parameters in addition to check critera.  The
%   variables in this file are listed below
%       checkType
%           equal   -   list of configuration parameters that MUST be equal to
%                       the default value
%           strings -   list of params that are strings of a particular
%                       format
%           none    -   Params for which no check should be performed
%           notDefault - Params which must NOT match the default.  these
%                        are robot specific parameters that must be set
%                        prior to use
%           range   -   Parameters that will be checked within the range
%                       specified
%
%       checkValueMin, checkValueMax
%           Structure with the min and max values needed for "range" type checks
%
%       defaultCfg
%           Structure containing default values for the configuration
%           parameters
%
% See also:
%    hgs_robot/subref

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2007)
%

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

guiHandles = generateMakoGui('Configuration File Check',[],hgs);
log_message(hgs,'Configuration File Check Started');
updateMainButtonInfo(guiHandles,@checkCfgParamsCallback)

%--------------------------------------------------------------------------
% Internal function to perform the configuration file check
%--------------------------------------------------------------------------
    function checkCfgParamsCallback(varargin)
        updateMainButtonInfo(guiHandles,'text','Checking File...');
        drawnow;
        [checkResult,resultString,reasonString] = checkCfgParamsInternal(hgs);
        
        % Save results and a copy of the configuration file from the robot
        dataFileName=['CfgFileCheck-',...
            hgs.name,'-',...
            datestr(now,'yyyy-mm-dd-HH-MM')];
        fullDataFileName = fullfile(guiHandles.reportsDir,dataFileName);
        configurationFileData = hgs{:}; %#ok<NASGU>
        save(fullDataFileName,...
            'configurationFileData',...
            'checkResult',...
            'resultString',...
            'reasonString');
        
        if checkResult
            presentMakoResults(guiHandles,'SUCCESS','All Parameters Checked');
            log_results(hgs,guiHandles.scriptName,'PASS','Check Configuration File Passed');
        else
            % list out all the error results in boxes and set tool tip
            % string to reasons
            cellHeight = 0.05;
            cellSpacing = 0.01;
            numOfFail = length(resultString);
            
            boldLast = false;
            fontWeightSetting = 'normal';
            
            if (numOfFail>32)
                reasonString{32} = sprintf('%s --> %s\n',...
                    resultString{32:end},reasonString{32:end});
                resultString{32} = '>>>>> MOUSE HERE FOR ADDITIONAL FAILURES <<<<<';
                numOfFail = 32;
                boldLast = true;
            end
            
            for i=1:numOfFail
                if boldLast && i==32
                    fontWeightSetting = 'bold';
                end
                uicontrol(guiHandles.uiPanel,...
                    'Style','text',...
                    'Units','normalized',...
                    'FontUnits','normalized',...
                    'FontSize',0.8,...
                    'FontWeight',fontWeightSetting,...
                    'HorizontalAlignment','left',...
                    'background','yellow',...
                    'Position',[0.02+floor(i/17)*0.48 ...
                    1-(i-floor(i/17)*16)*(cellHeight+cellSpacing) 0.46 cellHeight],...
                    'String',resultString{i},...
                    'ToolTipString',reasonString{i});
            end
            
            presentMakoResults(guiHandles,'WARNING');
            log_results(hgs,guiHandles.scriptName,'WARN','Check Configuration File Ended in Warning');
            
        end
    end
end

%--------------------------------------------------------------------------
% internal function to convert cell to string seperating with space
%--------------------------------------------------------------------------
function stringValue = cellToStringWithSpace(cellValue)
stringValue='';
for cellIndex=1:length(cellValue)
    stringValue = [stringValue,cellValue{cellIndex},' '];  %#ok<AGROW>
end
end

%--------------------------------------------------------------------------
% Internal function to perform the configuration file check
%--------------------------------------------------------------------------
function [checkResult,resultString,reasonString] = checkCfgParamsInternal(hgs)
    % If no arguments are specified, connect to the default robot
    switch int32(hgs.ARM_HARDWARE_VERSION * 10 + 0.05)
        case 20
            load(fullfile('configurationFile','defaultCfgFile-2_0.mat'));
        case 21
            load(fullfile('configurationFile','defaultCfgFile-2_1.mat'));
        case 22
            load(fullfile('configurationFile','defaultCfgFile-2_2.mat'));
        case 23
            load(fullfile('configurationFile','defaultCfgFile-2_3.mat'));
        case 30
            load(fullfile('configurationFile','defaultCfgFile-3_0.mat'));
        otherwise
            load(fullfile('configurationFile','defaultCfgFile-3_0.mat'));
    end
    
    armCfgParams = hgs{:};
    
    % initialize the result string and value
    resultString = {};
    reasonString = {};
    checkResult = 1;
    
    % extract list of parameters
    paramNames = fields(armCfgParams);

for i=1:length(paramNames)
    try
        % check if this is a parameter to be ignored
        if any(strcmp(paramNames{i},checkType.none))
            % do nothing
        elseif any(strcmp(paramNames{i},checkType.equal))
            % check if this a variable in the equal list
            % compare with loaded default and generate a
            % success or failure message if needed
            %paramNames{i}
            if iscell(armCfgParams.(paramNames{i}))
                if any(~strcmp(armCfgParams.(paramNames{i}),defaultCfg.(paramNames{i})))
                    checkResult = false;
                    resultString{end+1} = sprintf(...
                        'Param (%s) not equal to default value',paramNames{i}); %#ok<AGROW>
                    reasonString{end+1} = sprintf(...
                        'Current Value for (%s) = "%s"\nDefault Value for (%s) = "%s"',...
                        paramNames{i},cellToStringWithSpace(armCfgParams.(paramNames{i})),...
                        paramNames{i},cellToStringWithSpace(defaultCfg.(paramNames{i}))); %#ok<AGROW>
                end
            elseif any(abs(armCfgParams.(paramNames{i})-defaultCfg.(paramNames{i}))>1e-9)
                checkResult = false;
                resultString{end+1} = sprintf('Param (%s) not equal to default value',paramNames{i}); %#ok<AGROW>
                reasonString{end+1} = sprintf(...
                    'Current Value for (%s) = [ %s]\nDefault Value for (%s) = [ %s]',...
                    paramNames{i},sprintf('%3.3g  ',armCfgParams.(paramNames{i})),...
                    paramNames{i},sprintf('%3.3g  ',defaultCfg.(paramNames{i}))); %#ok<AGROW>
            end
        elseif any(strcmp(paramNames{i},checkType.strings))
            % this check is for strings that need to match a particular pattern
            % for convention
            if isempty(strmatch(defaultCfg.(paramNames{i}),armCfgParams.(paramNames{i})))
                checkResult = false;
                resultString{end+1} = sprintf(...
                    'Param (%s) set with invalid format or is not set',...
                    paramNames{i}); %#ok<AGROW>
                reasonString{end+1} = sprintf(...
                    'Param %s is set to %s expected format "%s*"',...
                    paramNames{i},char(armCfgParams.(paramNames{i})),...
                    char(defaultCfg.(paramNames{i}))); %#ok<AGROW>
            end
        elseif any(strcmp(paramNames{i},checkType.notDefault))
            % these are values that MUST NOT be equal to default.  These are
            % values that are expected to be updated
            if defaultCfg.(paramNames{i})== armCfgParams.(paramNames{i})
                checkResult = false;
                resultString{end+1} = sprintf('Param (%s) is not set',paramNames{i}); %#ok<AGROW>
                reasonString{end+1} = sprintf('Value of %s should be setup prior to use',...
                    paramNames{i}); %#ok<AGROW>
            end
        elseif any(strcmp(paramNames{i},checkType.range))
            % check against the min and max values
            if any(armCfgParams.(paramNames{i})<checkValueMin.(paramNames{i})) ...
                    || any(armCfgParams.(paramNames{i})>checkValueMax.(paramNames{i}))
                checkResult = false;
                resultString{end+1} = sprintf('Param (%s) out of range',paramNames{i}); %#ok<AGROW>
                reasonString{end+1} = sprintf(...
                    'Current Value for (%s) = [ %s]\nMaximum Value for (%s) = [ %s]\nMinimum Value for (%s) = [ %s]',...
                    paramNames{i},sprintf('%3.3g  ',armCfgParams.(paramNames{i})),...
                    paramNames{i},sprintf('%3.3g  ',checkValueMax.(paramNames{i})),...
                    paramNames{i},sprintf('%3.3g  ',checkValueMin.(paramNames{i}))); %#ok<AGROW>
            end
        else
            % Parameter is not in any check list mark as an unknown/unchecked
            % parameter
            checkResult = false;
            resultString{end+1} = sprintf('Unknown parameter (%s)',paramNames{i}); %#ok<AGROW>
            reasonString{end+1} = sprintf('No conditions have been set to check %s',...
                paramNames{i}); %#ok<AGROW>
        end
    catch
        resultString{end+1} = sprintf('Error checking (%s)',paramNames{i}); %#ok<AGROW>
        reasonString{end+1} = sprintf('Error while checking %s (%s)',...
            paramNames{i},lasterr); %#ok<AGROW>
    end
end

% all variables from the file have been checked, now double check if there
% are any variables that should have been present and are missing
checkedCfgParams = {checkType.equal{:}, checkType.range{:}, checkType.strings{:},...
    checkType.notDefault{:}};
for i=1:length(checkedCfgParams)
    if ~any(strcmp(checkedCfgParams{i},paramNames))
        checkResult = false;
        resultString{end+1} = sprintf(...
            'Param (%s) missing from file',checkedCfgParams{i}); %#ok<AGROW>
        reasonString{end+1} = sprintf(...
            'Parameter %s expected but was not found in file',...
            checkedCfgParams{i}); %#ok<AGROW>
    end
end

log_message(hgs,'Configuration File Check Closed');
end

% --------- END OF FILE ----------
