function jobId = getMakoJobId
% getMakoJobID function to query the user for the job id needed in service mfg scripts
%
% Syntax:
%    
%    jobId = getMakoJobId
%       This function will open a dialog box that will allow the user to
%       enter a job id.  the entered job id will be returned as jobId
%
% Return Value Description
%    return value jobID is a string with the job id name.  the word 'JobID'
%    will be prepended to the string.  If the user hits the cancel button,
%    the job id string will be the empty
%
% See Also:
%    presentMakoResults, resetMakoGui, generateMakoGui

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)

% Query the user for the serial number/workid
jobId = 'EnterJobID';
while strcmp(jobId,'EnterJobID')
    jobId = cell2mat(inputdlg('Please Enter Job ID','JobID',1,...
        {'EnterJobID'}));
    
    % handle the cancel button
    if isempty(jobId)
        return;
    end
    
    % check the format for the returned value to be a valid filename
    if ~isempty(regexp(jobId,'\W','ONCE'))
        uiwait(errordlg(sprintf('Invalid Job ID (%s)',jobId)));
        jobId = 'EnterJobID';
    end
end

jobId=['JobID-',jobId];


% --------- END OF FILE ----------
