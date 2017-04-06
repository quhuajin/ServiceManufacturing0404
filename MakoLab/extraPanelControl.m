function extraPanelControl(guiHandles,onOff)
% extraPanelControl turn on or turn off the extra panel
%
% Syntax:
%    extraPanelControl(guiHandles,onOff)
%        This function will work only on default Mako service and
%        manufacturing scripts GUI.  The argument onOff is a boolean that
%        can be used to control the behavor, boolean true for displaying
%        the extra panel and boolean false to hide it.
%   
% Example
%    % to turn on extra panel
%    extraPanelControl(guiHandles,true);
%
% Notes:
%    This function is valid only for GUI created with the generateMakoGui
%    function.
%
% See Also:
%    presentMakoResults, generateMakoGui, resetMakoGui

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)

% Check the frame sizes basaed on if the extraFrame is requested or not
if isempty(guiHandles.extraPanel)
    % do nothing cause there is no extra panel
    return;
end

if onOff
    onOff = 1;
else
    onOff = 0;
end

% change the visibility of the extra panel, and adjust scaling to match
if onOff && (strcmp(get(guiHandles.extraPanel,'Visible'),'off'))
    % double the window size
    windowSize = get(guiHandles.figure,'Position');
    windowSize(3) = windowSize(3)*2;
    set(guiHandles.figure,'Position',windowSize);
    
    set(guiHandles.extraPanel,'Visible','on');
    infoPanelPos = [0.01 0.82 0.48 0.15];
    uiPanelPos = [0.01 0.14 0.48 0.66];
    repPanelPos = [0.01 0.02 0.48 0.10];
elseif (~onOff) && (strcmp(get(guiHandles.extraPanel,'Visible'),'on'))

    % make the window size half
    windowSize = get(guiHandles.figure,'Position');
    windowSize(3) = windowSize(3)/2;
    set(guiHandles.figure,'Position',windowSize);
    
    set(guiHandles.extraPanel,'Visible','off');
    infoPanelPos = [0.02 0.82 0.96 0.15];
    uiPanelPos = [0.02 0.14 0.96 0.66];
    repPanelPos = [0.02 0.02 0.96 0.10];
else
    % do nothing
    return;
end

set(get(guiHandles.mainButtonInfo,'parent'),...
    'Position',infoPanelPos...
    );

set(guiHandles.uiPanel,'Position',uiPanelPos);

% find the repPanel
reportPanel = findobj(guiHandles.figure,'Title','Report Generation');
set(reportPanel,'Position',repPanelPos);
        
end


% --------- END OF FILE ----------