function upload_ee_file(fileName,hgs)
% upload_ee_file Gui to help upload EE constants to the arm
%
% Syntax:
%   upload_ee_file(fileName)
%       This function will upload data in the fileName to the default
%       robot.  The data in the file should be one of the following
%           EE data
%           CALIB EE data
%           CALIB BAR data
%   
%   upload_ee_file(fileName,hgs)
%       specify the robot to connect to
%
%   upload_ee_file('',hgs)
%       specify robot and still use the file selection menu
%
% Notes:
%   All data will be checked against nominals, as per the part drawing
%
%   This function will connect to the default robot automatically, if the
%   hgs argument is specified the user must specify a filename.  leave as
%   '' for forcing the file section
%
%   Default behavior would be to load the file.  check it against the
%   nominals, and the ask user to confirm.  once user confirms data is sent
%   to the robot.
% 
%   Also when no files are specified the script will check the current
%   directory.  if there is only one file available there, it will select
%   that file by default
%
%   filenames MUST be of the form *serial*.tcl
%
% See Also:
%   hgs_robot
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% connect to the default robot
if nargin<2
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

% setup the GUI
guiHandles = generateMakoGui('Upload EE File',[],hgs);
log_message(hgs,'Upload EE File Started');

if (nargin<1) || isempty(fileName)
    % search for files and load the first tcl file you find

    fileList = dir('*serial*.tcl');
    if isempty(fileList) || length(fileList)>1
        fileName = '';
        updateMainButtonInfo(guiHandles,...
            'Click to select file to load',{@read_ee_files,true})
    else
        fileName = fileList(1).name;
        updateMainButtonInfo(guiHandles,...
            sprintf('Click here to load %s file',fileName),{@read_ee_files,true});
    end
else
    updateMainButtonInfo(guiHandles,...
        sprintf('Click here to load %s file',fileName),{@read_ee_files,true});
end

checkStatusBox = uicontrol(guiHandles.uiPanel,...
    'Style','edit',...
    'Units','normalized',...
    'FontUnits','normalized',...
    'FontSize',0.25,...
    'String','File Check',...
    'Enable','off',...
    'Position',[0.1 0.6 0.8 0.2]);

fileWriteBox = uicontrol(guiHandles.uiPanel,...
    'Style','edit',...
    'Units','normalized',...
    'FontUnits','normalized',...
    'FontSize',0.3,...
    'String','Upload to Arm',...
    'Enable','off',...
    'Position',[0.1 0.2 0.8 0.2]);

% default constants
NOMINAL_CALIB_BALL_A = [-100.0000000    0.0000000  23.2214130 ].*0.001; %m
NOMINAL_CALIB_BALL_B = [   0.0000000 -100.0000000 -12.7785870].*0.001; %m
NOMINAL_CALIB_BALL_C = [   0.0000000  100.0000000 -12.7785870].*0.001; %m

% default TKA constants
NOMINAL_CALIB_BALL_A_TKA = [-98.8509    -0.10516  -48.344 ].*0.001; %m
NOMINAL_CALIB_BALL_B_TKA = [   -0.31935 -99.5939 -84.543].*0.001; %m
NOMINAL_CALIB_BALL_C_TKA = [   -0.8007  99.91855 -84.5378].*0.001; %m

CALIB_BALL_ERROR_ALLOWED = 10*0.001; %m


NOMINAL_EE_TOOL_AXIS.Knee_EE = [-0.939689384  0.000000  0.342029036];
NOMINAL_EE_ORIGIN.Knee_EE = [-172.598982 0.000000 26.576501].*0.001; %m
%Nominal Hip EE constants-from solidorks part
NOMINAL_EE_TOOL_AXIS.Hip_EE = [-0.996195 0 -0.08716];
NOMINAL_EE_ORIGIN.Hip_EE = [-205.1046078 0 -168.6678566]*0.001; %m
%Offset Hip EE constants-from solidorks part
NOMINAL_EE_TOOL_AXIS.Hip_EE_OFFSET=[-0.9961947 -0.00759612 -0.08682409];
NOMINAL_EE_ORIGIN.Hip_EE_OFFSET=[-202.0099653 0 -204.0397832]*0.001;%m
%Offset 90 Hip EE constants-from solidorks part
NOMINAL_EE_TOOL_AXIS.Hip_EE_OFFSET90=[-0.9961947 -0.00759612 -0.08682409];
NOMINAL_EE_ORIGIN.Hip_EE_OFFSET90=[-202.0099653 0 -204.0397832]*0.001;%m

%Offset 45 Hip EE constants-from solidorks part
NOMINAL_EE_TOOL_AXIS.Hip_EE_OFFSET45=[-0.9961947 0.0613939 -0.06186204];
NOMINAL_EE_ORIGIN.Hip_EE_OFFSET45=[-202.9163651 25.10726986 -193.6795858]*0.001;%m

%Offset 135 Hip EE constants-from solidorks part
NOMINAL_EE_TOOL_AXIS.Hip_EE_OFFSET135=[-0.9961947 -0.0613939 -0.06186204];
NOMINAL_EE_ORIGIN.Hip_EE_OFFSET135=[-202.9163651 -25.10726986 -193.6795858]*0.001;%m

EE_ORIGIN_ERROR_ALLOWED = 10*0.001; %m
EE_AXIS_ERROR_ALLOWED = 10*pi/180; % rad

% NOMINAL_EE_OFFSET = 0; %m

NOMINAL_BALLBAR_LENGTH_1 = 600*0.001; %m
BALLBAR_LENGTH_ERROR_ALLOWED = 10*0.001; %m

eeNames=fields(NOMINAL_EE_ORIGIN);
numberOfEE=length(eeNames);


%--------------------------------------------------------------------------
% Internal function to read the ee files.  This function supports EE-KIT,
% EE, CALEE and CALBAR files
%--------------------------------------------------------------------------
    function read_ee_files(hobj,eve,check) %#ok<INUSL,INUSD>

        % parse the tcl file and maintain a structure with all the data
        if isempty(fileName)
            [f,p] = uigetfile({'*serial*.tcl','End effector files'});
            if f==0
                return;
            else
                fileName = fullfile(p,f);
            end
        end
        fid = fopen(fileName);
        dataNum = 1;
        % read a line at a time
        fileData = '';

        while ~feof(fid)

            % see if this is  a line to skip
            fileLine = fgetl(fid);

            if isempty(fileLine) || (fileLine(1)=='#')
                continue;
            end

            % this looks like valid data
            % data can be stored in 3 different forms
            % deal with each one separately
            
            try
                [varName,varValue] = strread(fileLine,'set %s %f');
                % all configuration parameters are upper case as per CRISIS
                % convention
                varName = upper(varName);
                fileData(dataNum).name = varName;
                fileData(dataNum).value{1} = varValue;
                dataNum = dataNum+1;
                % if i didnt error i got valid data
                continue;
            catch
            end
            
            
            try
                [varName,varValue] = strread(fileLine,'set %s %s');
                % all configuration parameters are upper case as per CRISIS
                % convention
                varName = upper(varName);
                fileData(dataNum).name = varName;
                fileData(dataNum).value{1} = varValue;
                dataNum = dataNum+1;
                % the only string should be the serial number (assume this)
                serialNumString = varName;
                serialNumValue = varValue;
                % if i didnt error i got valid data
                continue;
            catch
            end

            try
                [varName,varValue1,varValue2,varValue3] = strread(fileLine,...
                    'set %s { %f %f %f }');
                
                % all configuration parameters are upper case as per CRISIS
                % convention
                varName = upper(varName);
                fileData(dataNum).name = varName;
                fileData(dataNum).value{1} = [varValue1 varValue2 varValue3];
                % if i didnt error i got valid data
                dataNum = dataNum+1;
                continue;
            catch
            end
        end

        fclose(fid);

        % check the file the function should error on failure
        err_msg = write_file_data(fileData,serialNumString,serialNumValue,check);
        
        if ~isempty(err_msg)
            presentMakoResults(guiHandles,'FAILURE',{'',err_msg});
            return;
        end
        
        if check
            % if i got here ask user to click again to confirm
            updateMainButtonInfo(guiHandles,...
                sprintf('Click to send %s data to Arm',char(serialNumValue)),...
                {@read_ee_files,false});
        else
            % the data was successfully written to the arm.  present
            % results
            [p,n] = fileparts(fileName);
            presentMakoResults(guiHandles,'WARNING',...
                sprintf('File %s \nloaded to RIO Arm \nUse GUD cart to upload for application',n));
        end

    end

%--------------------------------------------------------------------------
% Internal function the check and write the EE kit data
%--------------------------------------------------------------------------
    function err_msg = write_file_data(fileData,serialNumString,serialNumValue,check)
        
        err_msg = '';
        
        switch serialNumString{1}
            case 'EE_SERIAL_NUMBER'
                fileTypeString = sprintf('FileType: EE (%s)',...
                    char(serialNumValue));
                % this is an end effector file
                try
                    ee_origin = extract_data(fileData,'EE_ORIGIN',0.001);
                    ee_axis = extract_data(fileData,'EE_TOOL_AXIS',1);
                catch
                    err_msg = lasterr;
                    return;
                end
                % check against nominal, if pass one nominal, the origin check 
                % pass.
                eeCheckPassed=0;
                for i=1:numberOfEE
                    eeDistFromNominal(i)=norm(ee_origin-NOMINAL_EE_ORIGIN.(eeNames{i}));
                    if eeDistFromNominal(i)<=EE_ORIGIN_ERROR_ALLOWED
                        eeCheckPassed=1;
                    end
                end
                %check if origin check passed
                if ~eeCheckPassed
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                        'EE ORIGIN distance from nominal %3.3f mm (lim %3.3f)',...
                        min(eeDistFromNominal)*1000,...
                        EE_ORIGIN_ERROR_ALLOWED*1000)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'EE ORIGIN invalid';
                    return;
                end
                %reset check pass flag
                eeCheckPassed=0;
                % check against nominal
                for i=1:numberOfEE
                    angle_from_nominal(i) = atan2(norm(cross(ee_axis,NOMINAL_EE_TOOL_AXIS.(eeNames{i}))),...
                        dot(ee_axis,NOMINAL_EE_TOOL_AXIS.(eeNames{i})));

                    if angle_from_nominal(i) <= EE_AXIS_ERROR_ALLOWED
                        eeCheckPassed=1;
                    end
                end

                %check if axis check passed
                if ~eeCheckPassed
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                        'EE AXIS angle from nominal = %3.3f deg (lim %3.3f)',...
                        min(angle_from_nominal)*180/pi,EE_AXIS_ERROR_ALLOWED*180/pi)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'EE AXIS invalid';
                    return;
                end

                if check
                    set(checkStatusBox,...
                        'String',['File Check Passed - ',fileTypeString],...
                        'Enable','inactive',...
                        'Background','green');
                    return;
                end
                
                % i got here all data is valid
                % write the file data
                hgs.EE_ORIGIN = ee_origin;
                hgs.EE_TOOL_AXIS = ee_axis;
                hgs.EE_SERIAL_NUMBER = serialNumValue;
                
                set(fileWriteBox,...
                        'String','File Upload Successful',...
                        'Enable','inactive',...
                        'Background','green');

            case 'CALEE_SERIAL_NUMBER'
                fileTypeString = sprintf('FileType: CALEE (%s)',...
                    char(serialNumValue));
                % this is an CALIBRATION EE file
                try
                    calib_ball_A = extract_data(fileData,'CALIB_BALL_A',0.001);
                    calib_ball_B = extract_data(fileData,'CALIB_BALL_B',0.001);
                    calib_ball_C = extract_data(fileData,'CALIB_BALL_C',0.001);
                catch
                    err_msg = lasterr;
                    return;
                end
                
                % check against nominal
                minDist = min(norm(calib_ball_A-NOMINAL_CALIB_BALL_A),norm(calib_ball_A-NOMINAL_CALIB_BALL_A_TKA));
                if minDist>CALIB_BALL_ERROR_ALLOWED
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                            'CALIB_BALL_A distance from nominal %3.3f mm (lim %3.3f)',...
                            minDist*1000,...
                            CALIB_BALL_ERROR_ALLOWED*1000)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'CALIB BALL A location invalid';
                    return;
                end

                % check against nominal
                minDist = min(norm(calib_ball_B-NOMINAL_CALIB_BALL_B),norm(calib_ball_B-NOMINAL_CALIB_BALL_B_TKA));
                if minDist>CALIB_BALL_ERROR_ALLOWED
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                            'CALIB_BALL_B distance from nominal %3.3f mm (lim %3.3f)',...
                            minDist*1000,...
                            CALIB_BALL_ERROR_ALLOWED*1000)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'CALIB BALL B location invalid';
                    return;
                end

                % check against nominal
                minDist = min(norm(calib_ball_C-NOMINAL_CALIB_BALL_C),norm(calib_ball_C-NOMINAL_CALIB_BALL_C_TKA));
                if minDist>CALIB_BALL_ERROR_ALLOWED
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                        'CALIB_BALL_C distance from nominal %3.3f mm (lim %3.3f)',...
                        minDist*1000,...
                        CALIB_BALL_ERROR_ALLOWED*1000)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'CALIB BALL C location invalid';
                    return;
                end

                if check
                    set(checkStatusBox,...
                        'String',['File Check Passed - ',fileTypeString],...
                        'Enable','inactive',...
                        'Background','green');
                    return;
                end
                
                % i got here all data is valid
                % write the file data
                hgs.CALIB_BALL_A = calib_ball_A;
                hgs.CALIB_BALL_B = calib_ball_B;
                hgs.CALIB_BALL_C = calib_ball_C;

                hgs.CALEE_SERIAL_NUMBER = serialNumValue;

                set(fileWriteBox,...
                        'String','File Upload Successful',...
                        'Enable','inactive',...
                        'Background','green');
                
            case 'CALBAR_SERIAL_NUMBER'
                fileTypeString = sprintf('FileType: CALBAR (%s)',...
                    char(serialNumValue));
                % this is an CALIBRATION BALL file
                try
                    ballbar_length_1 = extract_data(fileData,'BALLBAR_LENGTH_1',0.001);
                catch
                    err_msg = lasterr;
                    return;
                end
                % check against nominal
                if abs(ballbar_length_1 - NOMINAL_BALLBAR_LENGTH_1) ...
                        > BALLBAR_LENGTH_ERROR_ALLOWED
                    set(checkStatusBox,...
                        'Style','text',...
                        'FontSize',0.3,...
                        'String',{fileTypeString,sprintf(...
                        'CALIB_BALL_C distance from nominal %3.3f mm (lim %3.3f)',...
                        abs(ballbar_length_1 - NOMINAL_BALLBAR_LENGTH_1)*1000,...
                        BALLBAR_LENGTH_ERROR_ALLOWED*1000)},...
                        'Enable','inactive',...
                        'Background','red');
                    err_msg = 'BALLBAR_LENGTH invalid';
                    return;
                end

                if check
                    set(checkStatusBox,...
                        'String',['File Check Passed - ',fileTypeString],...
                        'Enable','inactive',...
                        'Background','green');
                    return;
                end
                
                % i got here all data is valid
                % write the file data
                hgs.BALLBAR_LENGTH_1 = ballbar_length_1;
                hgs.CALBAR_SERIAL_NUMBER = serialNumValue;
                
                set(fileWriteBox,...
                        'String','File Upload Successful',...
                        'Enable','inactive',...
                        'Background','green');
                
            otherwise
                err_msg = ['Unknown file type (%s)',serialNumString{1}];
                return;
        end
    end

end

%--------------------------------------------------------------------------
% Internal function to extract the data to be loaded
%--------------------------------------------------------------------------
function varData = extract_data(fileData,varDesired,scale)
variableFound = false;
for i=1:length(fileData)
    if strcmp(fileData(i).name,varDesired)
        varData = fileData(i).value{1}.*scale;
        variableFound = true;
        break;
    end
end

if ~variableFound
    error('Variable %s not found in file',varDesired);
end
end

% --------- END OF FILE ----------