function resetMakoGui(guiHandles)
% resetMakoGui Reset the default GUI template for the Mako Service and Manufcaturing
%
% Syntax:
%    guiHandles = resetMakoGui(guiHandles)
%        This function will work only on default Mako service and
%        manufacturing scripts GUI.  
%        The argument guiHandles is the list of handles returned from the 
%        generateMakoGui function
%        
%        Using the presentMakoResults function alters the relative size of
%        the uiPanel and the mainButtonInfo box.  This function restores
%        these buttons to their original proportions.  The button text is
%        also modified to "Press Here" with the intension that the user
%        will update this after this function call.
%   
% Notes:
%    Please refer to
%    http://twiki.makosurgical.com/view/Robot/HgsServiceAndManufacturingGUITemplate
%    for description on the GUI concept.
%
%    This function is valid only for GUI created with the generateMakoGui
%    function.
%
% See Also:
%    presentMakoResults, generateMakoGui, extraPanelControl

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)

% Check the frame sizes basaed on if the extraFrame is requested or not
if  (strcmp(get(guiHandles.extraPanel,'Visible'),'on'))
    infoPanelPos = [0.01 0.82 0.48 0.15];
    uiPanelPos = [0.01 0.14 0.48 0.66];
else
    infoPanelPos = [0.02 0.82 0.96 0.15];
    uiPanelPos = [0.02 0.14 0.96 0.66];
end

% Setup the Service frames
set(get(guiHandles.mainButtonInfo,'parent'),...
    'Position',infoPanelPos...
    );

set(guiHandles.mainButtonInfo,...
    'Style','pushbutton',...
    'BackgroundColor',[0.92549 0.913725 0.847059],...
    'String','Press Here'...
    );

set(guiHandles.uiPanel,...
    'Position',uiPanelPos...
    );

% make the mainButton the default button
uicontrol(guiHandles.mainButtonInfo);


% find the exit button and change it back to a cancel button
% Search for the report generation frame
reportPanel = findobj(guiHandles.figure,'Title','Report Generation');

% Now search the buttons for the cancel button
cancelButton = findobj(reportPanel,'string','Cancel');
exitButton = findobj(reportPanel,'string','Exit');

set(cancelButton,...
    'Enable','on',...
    'Visible','on'...
    );

set(exitButton,...
    'Enable','off',...
    'Visible','off'...
    );


% --------- END OF FILE ----------