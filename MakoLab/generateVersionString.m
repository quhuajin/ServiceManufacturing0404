function versionStr = generateVersionString
% generateVersionString function parse SVN keyword for version number
%
% Syntax:
%    versionStr = generateVersionString
%       This function will generate a string containing the tag or branch
%       name from the svn keyword HeadURL
%
% See Also:
%    generateMakoGui

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)

% get the SVN keyword substitution
svnKeyword = '$HeadURL: svn+ssh://svn.makosurgical.com/var/svnroot/repos/robot/MfgAndTestSoftware/branches/ServiceMfg-1_14_branch/MakoLab/generateVersionString.m $';

% query the SVN version info (check if a top level folder is available)
try
    [svnVersionResult,svnVersionText] = system('svnversion -n');
catch
    svnVersionResult='';
end

% check if there was an error in determining the svn version
if (svnVersionResult)
    svnVersionText = '-(svnversion-NA)';
else
    % check if this is an unrevisioned directory if so hide this
    % information
    if strcmp(svnVersionText,'Unversioned directory')
        svnVersionText ='-(Unversioned-Dir)';
    else
        % remove any colons if existing
        svnVersionText = strrep(svnVersionText,':','-');
        
        % append the r to indicate this is a rev number
        svnVersionText = ['-r' svnVersionText];
    end
end

% extract the tag name or the branch name
if ~isempty(strfind(svnKeyword,'/tags/'))
    startIndex = strfind(svnKeyword,'/tags/')+length('/tags/');
    % check if this tag path includes repository name, if so remove it
    if ~isempty(strfind(svnKeyword,'/MakoLab/'))
        endIndex = strfind(svnKeyword,'/MakoLab/generateVersionString')-1;
    else
        endIndex = strfind(svnKeyword,'/generateVersionString')-1;
    end
    versionStr = svnKeyword(startIndex:endIndex);
elseif ~isempty(strfind(svnKeyword,'/branches/'))
    startIndex = strfind(svnKeyword,'/branches/')+length('/branches/');
    % check if this tag path includes repository name, if so remove it
    if ~isempty(strfind(svnKeyword,'/MakoLab/'))
        endIndex = strfind(svnKeyword,'/MakoLab/generateVersionString')-1;
    else
        endIndex = strfind(svnKeyword,'/generateVersionString')-1;
    end
    versionStr = svnKeyword(startIndex:endIndex);
    
    % append the svn version info
    versionStr = sprintf('%s%s',versionStr,svnVersionText);
    
else
    versionStr = sprintf('MainBranch%s',svnVersionText);
end

end


% --------- END OF FILE ----------
