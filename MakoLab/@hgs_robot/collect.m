function varargout = collect(hgs, varargin)
%COLLECT capture the specified number of samples of the specified variables
%
% Syntax:  
%   COLLECT(hgs,varName)
%       collect 10 seconds worth of the specified variable from the connected
%       hgs arm
%   [out1,out2,...] = COLLECT(hgs,v1,v2,...)
%       collect multiple variables from the hgs_robot.  number of requested
%       elements MUST equal number of outputs
%   out = COLLECT(hgs)
%       collects all the available read/write variables and returns a structure
%       with all the collected data
%   COLLECT(hgs,duration,...)
%       if the first argument is a number it will be interpreted as a time
%       duration and the data will be collected for that duration of time.  rest
%       of the calling options are the same.
%   COLLECT(hgs,duration,period,...)
%       if the second argument is a number it will insert a pause between
%       datapoints for the clock period specified (in seconds).
% See also: 
%    hgs_robot/subsref, hgs_robot/get, hgs_robot/plot
 
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% determine how many variables are requested
numLogVars = nargin-1;

% check if the time has been specified as an option
if (nargin>1) ...
        && (length(varargin{1})==1)...
        && (isnumeric(varargin{1}))
    logTime = varargin{1};
    numLogVars = numLogVars-1;
else
    logTime = 10;
end


% check if a clock period is specified
clockPeriodSpecified = false;
if (nargin>2) ...
        && (length(varargin{2})==1)...
        && (isnumeric(varargin{2}))
    clockPeriod = varargin{2};
    clockPeriodSpecified = true;
    numLogVars = numLogVars-1;
end



if numLogVars ~= 0
    fldNames = fieldnames(commDataPair(hgs,'get_state'));
    indcs = zeros(numLogVars, 1, 'int32');
    k = 0;
    for i = 1:numLogVars 
        varName{i} = varargin{i+nargin-numLogVars-1};
        for j=1:size(fldNames,1)
            if strcmp(fldNames(j), varName{i}),
                k = k+1;
                indcs(k) = j;
                break;
            else
                if j == size(fldNames,1) 
                   error('requested variable "%s", not found, ', varName(i) ); 

                end
            end            
        end        
    end
end


% check inputs and outputs
if ((numLogVars>1)&&(numLogVars~= nargout))
    error('Number of inputs and outputs MUST match');
end

% get the raw socket id
hgsSock = feval(hgs.sockFcn);

% Query the robot for the variables
hgsCommand = matlabtoCrisisComm('get_state');

% Collect all the data as fast as possible, for performance reasons I will parse
% the data after all the data is collected.
tic;
numSamples = 0;

% newer computers (2014) seem to perform much much better than the initial esitmate of 200Hz
% benchmarking showed 700-2000 hz.  changing the memory allocation to 2000 for improved performance
hgsReply = cell(ceil(2000*logTime),1);

% Define count based on processor performance
if clockPeriodSpecified
    tic;
    i = 1;
    while i < 1000
        i = i + 1;
    end
    a = toc;
    TimePeriod = a/1000;
    %     disp(TimePeriod);
    Count = clockPeriod/TimePeriod;
end
% Now log as fast as possible or at userdefined frequency
while toc<logTime
    numSamples = numSamples+1;
    hgsReply{numSamples} = sendReceiveCrisisComm(...
        hgsSock,hgsCommand);
    
    % if a clock period is specified insert a pause
    if clockPeriodSpecified
        i = 1;
        if Count <= 1
            while i < 2
                i = i + 1;
            end
        else
            while i < Count
                i = i + 1;
            end
        end

    end 
end

% parse the data
h = waitbar(0,'Please wait...', ...
            'Name', 'Parsing collected data', ...
            'visible', 'off');
movegui(h,'north');
set(h,'visible', 'on');
if numLogVars == 0    
    for i=1:numSamples
        hgsData(i) = parseCrisisReply(hgsReply{i},...
            '-DataPair'); %#ok<AGROW>
        waitbar(i/numSamples, h);
    end
else
    for i=1:numSamples
        hgsData(i) = parseCrisisReplyByLocation(hgsReply{i},...
            indcs); %#ok<AGROW>
        waitbar(i/numSamples, h);
    end
end

% start getting additional inputs and outputs
if (numLogVars==0)
    % merge array into single structure  This will make it a lot easier to
    % access and plot the data as a whole.
    varNames = fields(hgsData);
    for i=1:length(varNames)
        outData.(varNames{i}) = smartReshape([hgsData.(varNames{i})],...
            hgsData(1).(varNames{i}));
    end
    varargout{1} = outData;
else
    % If specific variables are requested populate only those variables
    for i=1:numLogVars
        varargout{i}= smartReshape([hgsData.(varName{i})],...
            hgsData(1).(varName{i}));
    end
end
close(h);
end

% Helper function for reshaping data to store each sample in a separate row
function shapedData = smartReshape(totalData,singleSample)
    shapedData = reshape(totalData,...
            length(singleSample),...
            length(totalData)/length(singleSample)...
            )';
end


% --------- END OF FILE ----------
