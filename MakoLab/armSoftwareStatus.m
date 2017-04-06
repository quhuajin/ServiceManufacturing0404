function resultStruct = armSoftwareStatus(target_ip_or_hgs)
%armSoftwareStatus Check the status of the Arm software (CRISIS) processes
%
% Syntax:
%   armSoftwareStatus(hgs_or_ip)
%       returns an array of structure with the following fields
%           ProcessName     => Name of the process
%           StatusText      => Text stating staus "OK" or "NOT RUNNING"
%           Status          => binary value, true=> process is running
%                               false otherwise
%
%   armSoftwareStatus
%       If no inputs are presented the code will assume the host is defined
%       by environment variable ROBOT_HOST
%
% Description
%   This script uses telnet to query the status of all the processes in
%   CRISIS.
%
%   The function accepts either IP or HOSTNAME or hgs_robot object
%   
% Notes
%   Currently this function works only in unix platforms that have telnet
%   built in.
%

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp 2007


if ~isunix
    error('This function is only supported in linux');
end

USERNAME='root';
PASSWORD='50%sOlN';

% figure out which type of input is presented
if nargin<1
    target_ip = getenv('ROBOT_HOST');
else
    if isa(target_ip_or_hgs,'hgs_robot')
        target_ip = target_ip_or_hgs.host;
    else
        target_ip = target_ip_or_hgs;
    end
end

% Do a quick ping to make sure we can reach the machine
if ispc
    pingCommand = 'ping -w 1000 -n 1 ';
else
    pingCommand = 'ping -w 1 -c 1 ';
end

% ping the robot for a quick check
[pingFailure,pingReply] = system([pingCommand,target_ip]); %#ok<NASGU>
if pingFailure
    error('Target (%s) not reachable...network error',target_ip);
end


% setup the command to send
systemCommand = sprintf(['(sleep 1; echo %s; sleep 2; echo %s; sleep 1; '...
    'echo "cd /CRISIS/bin"; echo "./crisis_manager -s"; sleep 1; echo "exit") | telnet %s'],...
    USERNAME,PASSWORD,target_ip);

[resultStatus,resultText] = system(systemCommand);
if ~resultStatus
    error('Error executing shell command (%s)',resultText);
end

% parse the reply text
% This is the crisis_manager -s response so use the dots to find the
% relevant lines
ln = [];
lineSplit = regexp(resultText,sprintf('\n'),'split');
for i=1:length(lineSplit)
    if ~isempty(strfind(lineSplit{i},'........'))
        ln(end+1) = i; %#ok<AGROW>
    end
end

if isempty(ln)
    error('Unable to parse remote response (%s)',resultText);
end

for i=1:length(ln)
    resultCell(i) = textscan(lineSplit{ln(i)},'%s'); %#ok<AGROW>
    
    % NOT RUNNING is split as two separate words so concat words 3 and 4 if
    % they exist
    if length(resultCell{i})==4
        resultCell{i}{3} = [resultCell{i}{3},' ',resultCell{i}{4}]; %#ok<AGROW>
        resultCell{i}{4} = []; %#ok<AGROW>
    end
    resultCell{i}(2) = resultCell{i}(3); %#ok<AGROW>
    
    % change 3rd element as a logical operator for easy use
    resultCell{i}(3)=[]; %#ok<AGROW>
    if strcmp(resultCell{i}(2),'OK')
        resultCell{i}{3} = true; %#ok<AGROW
    else
        resultCell{i}{3} = false; %#ok<AGROW>
    end
end

% convert result to struct
for i=1:length(resultCell)
    resultStruct(i) = cell2struct(resultCell{i},...
        {'processName','StatusText','Status'}); %#ok<AGROW>
end


%---- END OF FILE ------
