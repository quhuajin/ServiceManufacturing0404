function retData=log_results(hgs,scriptName,resultType,testMessage,varargin)
%LOG_RESULTS add the results of a script to the crisis log files in a standardized format
%
% Syntax:
%   log_results(hgs,scriptName,resultType,testMessage)
%	    hgs
%	        hgs_robot connected
%	    scriptName
%	        name of the script or entity for which the results need to be posted
%	    resultType
%	        the result can be one of the following
%		    "PASS"
%		    "FAIL"
%		    "WARNING"
%	        based on the type defined the log will be stored as either an LOG-1, ERROR, or WARNG
%	    testMessage
%	        one line message describing the result
%
%   log_results(hgs,scriptName,resultType,fieldName,value,fieldname,value,....)
%	    fieldname
%		    name of a descriptor to added to the fields
%	    value
% 		    value for that descriptor
%
%   log_results(hgs,scriptName,resultType,resultsStructure)
%	    resultsStructure
%		    result type value pair can also be passed as a structure
%
%
% NOTE
%	"Message" is a special fieldname that will automatically be added.  this is a one line message that
%	can be used to describe the results
%
%   the standardized format would be like
%        2015-01-15 17:39:52  862   LOG-1   EXT - {
%        2015-01-15 17:39:52  864   LOG-1   EXT - "TestType"      : "SOME_SCRIPT",
%        2015-01-15 17:39:52  865   LOG-1   EXT - "TestResult"    : "PASS",
%        2015-01-15 17:39:52  866   LOG-1   EXT - "TestMessage"   : "the test passed",
%        2015-01-15 17:39:52  867   LOG-1   EXT - "value1"        : "some text ",
%        2015-01-15 17:39:52  869   LOG-1   EXT - "value2"        : "32.200 ",
%        2015-01-15 17:39:52  870   LOG-1   EXT - "value3"        : "1.000 2.000 3.000 4.000 ",
%        2015-01-15 17:39:52  871   LOG-1   EXT - }
%
%
% EXAMPLES
%
%	log_results(hgs,'HOMING','PASS','homing successful')
%
%	log_results(hgs,'HOMING','FAIL','Camera Connection Error')
%
%	log_results(hgs,'ACCURACY CHECK','FAIL','test failure','RMS',0.6,'Max Error',0.2)
%
%	accuracyResults.rms = 0.6
%	accuracyResults.maxError = 0.2
%	log_results(hgs,'ACCURACY CHECK','FAIL','test failure',accuracyResults)
%
% See also:
%    hgs_robot, hgs_loginfo, log_message

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% check the arguments

% update the result type to be CRISIS friendly
switch upper(resultType)
    case {'MESSAGE','SUCCESS','PASS','LOG-1'}
        resultType=' ''PASS'' ';
        messageType='MESSAGE';
    case {'WARNG','WARNING','WARN'}
        resultType=' ''WARNING'' ';
        messageType='WARNING';
    case {'FAIL','ERROR','FAILURE'}
        resultType=' ''FAIL'' ';
        messageType='ERROR';
    otherwise
        error('unsupported log_results type (%s)',resultType);
end

%initialize results data
retData=[];

% check the data

% if varargin is one element check if this is a structure that we need to decompose
dataToFill=false; 

if length(varargin)==1
    if isstruct(varargin{1})
        varNames = fields(varargin{1});
        varValues = struct2cell(varargin{1});
        dataToFill=true;
    elseif isempty(varargin{1})
        % do nothing
    else
        error('Invalid argument to function log_result');
    end
elseif length(varargin)==0
    % do nothing
else
    if rem(length(varargin),2)==1
        error('Result variables must be in variableName, value pairs');
    end
    
    % now break it up in value pairs
    for i=1:length(varargin)/2
        varNames{i}=varargin{2*i-1}; %#ok<AGROW>
        if ~ischar(varNames{i})
            error('Invalid field name (arg #%d), expects strings',2*i+4);
        end
        varValues(i)=varargin(2*i); %#ok<AGROW>
    end
    dataToFill=true;
end

if dataToFill
    for i=1:length(varValues)
        if isfloat(varValues{i})
            varText{i} = sprintf(' %3.3f ',varValues{i}); %#ok<AGROW>
        elseif ischar(varValues{i})
            varText{i} = sprintf(' ''%s'' ',varValues{i}); %#ok<AGROW>
        elseif isinteger(varValues{i})
            varText{i} = sprintf(' %d ',varValues{i}); %#ok<AGROW>
        elseif iscell(varValues{i})
            % if cell assume these are strings
            varText{i} = ''; %#ok<AGROW>
            for j=1:length(varValues{i})
                if ischar(varValues{i}{j})
                    varText{i} = sprintf('%s ''%s'' ',varText{i},varValues{i}{j}); %#ok<AGROW>
                else
                    error('Unsupported data type in log_result (arg #%d)',2*i+4);     
                end
            end
        else
            error('Unsupported data type in log_result (arg #%d)',2*i+4);
        end
    end
end


% start writing the log messages
try
    % first put in the starting bracket
    log_message(hgs,'{',messageType);
    log_message(hgs,sprintf('%s : %s,',...
        rightPadString(quoteString('TestType')),...
        quoteString(sprintf(' ''%s'' ',scriptName))),messageType);
    log_message(hgs,sprintf('%s : %s,',...
        rightPadString(quoteString('TestVersion')),...
        quoteString(sprintf(' ''%s'' ',generateVersionString))),messageType);
    log_message(hgs,sprintf('%s : %s,',...
        rightPadString(quoteString('TestResult')),...
        quoteString(resultType)),messageType);
    
    log_message(hgs,sprintf('%s : %s,',...
        rightPadString(quoteString('TestMessage')),...
        quoteString(sprintf(' ''%s'' ',testMessage))),messageType);
    
    
    % check if there is data to fill
    if dataToFill
        for i=1:length(varNames)
            log_message(hgs,sprintf('%s : %s,',...
                rightPadString(quoteString(varNames{i})),...
                quoteString(varText{i})),messageType);
        end
    end
    
    % close the message
    log_message(hgs,'}',messageType);
    
catch %#ok<CTCH>
    retData.success=0;
    retData.msg=lasterr; %#ok<LERR>
    return;
end

% log message is succesful
retData.success=1;
retData.msg='Success';

end

function returnString=rightPadString(stringToProcess)
returnString = sprintf('%-15s',stringToProcess);
end

function returnString=quoteString(stringToProcess)
returnString = sprintf('"%s"',stringToProcess);
end

function returnString=bracketString(stringToProcess)
returnString = sprintf('[%s]',stringToProcess);
end

% --------- END OF FILE ----------
