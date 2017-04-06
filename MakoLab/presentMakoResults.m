function presentMakoResults(guiHandles,successFlag,message)
% presentMakoResults Presents the results in the standard way described for Mako Service and Manufacturing Scripts
%
% Syntax:
%    presentMakoResults(guiHandles,successFlag)
%        This function will work only on default Mako service and
%        manufacturing scripts GUI.
%        The argument guiHandles is the list of handles returned from the
%        generateMakoGui function
%        Argument successFlag can be one of 3 possible values
%            'SUCCESS' -> indicating successful test/operation
%            'WARNING' -> indicating marginally passing results
%            'FAILURE' -> indicating failed test/operation
%
%    presentMakoResults(guiHanldes,successFlag,message)
%        message is an optional string that can be appended to the results
%        further showing additional details on the results.  For multiple
%        lines use cells eg {'message line 1','message line 2','message
%        line 3'}
%
% Notes:
%    Please refer to
%    http://twiki.makosurgical.com/view/Robot/HgsServiceAndManufacturingGUITemplate
%    for description on the GUI concept.
%
%    This function will do the following with the results
%       * Color code the results and append keyword SUCCESSFUL, WARNING, FAILED
%         to the final results.  The color coding will be
%             SUCCESS => green
%             WARNING => yellow
%             FAILURE => red
%
%       * Change the "Cancel" button to an "Exit" button.
%       * Change the callback for the exit button to automatically take a
%         screenshot if pressed
%       * Expand the Results section (this section is more important at this
%         stage) and shrink the user interface section.
%       * Makes the "exit" button the default button on the screen
%
% See Also:
%    generateMakoGui, resetMakoGui

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)

% Present the results
if (nargin==2)
    message='';
end

% extract the scriptname.  Typically this should be the title of the window
try
    scriptName = get(guiHandles.figure,'Name');
catch
    scriptName = guiHandles.scriptName;
end

% check if the extraPanel was used or not
if strcmp(get(guiHandles.extraPanel,'Visible'),'on')
    infoPanelPos = [0.01 0.62 0.48 0.35];
    uiPanelPos = [0.01 0.14 0.48 0.46];
    fontScaling = 0.7;
else
    infoPanelPos = [0.02 0.62 0.96 0.35];
    uiPanelPos = [0.02 0.14 0.96 0.46];
    fontScaling = 1;
end

% Enable the main button so the results font is black and printable
set(guiHandles.mainButtonInfo,'enable','on');

% Results are more important at this stage so display them bigger
%find the info panel
infoPanel = get(guiHandles.mainButtonInfo,'Parent');
set(infoPanel,...
    'Position',infoPanelPos);

set(guiHandles.uiPanel,...
    'Position',uiPanelPos);

% Load the sounds
load('makoGUIdata.mat');

% by default hide the warning icon
showWarningIcon = false;

% prepare the display string
switch upper(successFlag)
    case 'SUCCESS'
        successFailureString = {sprintf('%s Successful',scriptName)};
        msgBoxColor = 'green';
        soundType = successSound;
    case 'WARNING'
        successFailureString = {sprintf('%s',scriptName)};
        msgBoxColor = 'green';
        soundType = successSound;
        showWarningIcon = true;
    case 'FAILURE'
        successFailureString = {sprintf('%s Failed',scriptName)};
        msgBoxColor = 'red';
        soundType = errorSound;
    otherwise
        error('Unsupported successFlag should be SUCCESS/WARNING/FAILURE');
end

if ischar(message)
    displayString = {successFailureString{:}, message};
else
    displayString = {successFailureString{:},message{:}};
end

% find the font size
fontSize = 1/(length(displayString)+3);

% Now display the final results
set(guiHandles.mainButtonInfo,...
    'Style','text',...
    'FontWeight','Bold',...
    'FontSize',fontSize*fontScaling,...
    'BackgroundColor',msgBoxColor,...
    'String',displayString...
    );

if showWarningIcon
    %warning Icon and warning pic size are stored on the
    %MakoGuiData.mat file
    warningIconData = warningIcon;
    pictureSize = warningPicSize;
    picMargin = [5,5];
    
    % get the pixel location of the button
    set(guiHandles.mainButtonInfo,'units','pixels');
    buttonPosPixel = get(guiHandles.mainButtonInfo,'Position');
    set(guiHandles.mainButtonInfo,'units','normalized');
    
    % position the warning icon at the right top corner
    warningPosLeft = [...
        buttonPosPixel(1)+picMargin(1),...
        buttonPosPixel(2)+buttonPosPixel(4)-pictureSize(2)-picMargin(2)];
    
    bHandle=uicontrol(get(guiHandles.mainButtonInfo,'parent'),...
        'Style','pushbutton',...
        'units','pixels',...
        'Position',[warningPosLeft,pictureSize],...
        'Enable','Inactive',...
        'CData',warningIconData);
end

% refresh the screen
drawnow

if showWarningIcon
    %set warning button to borderless
    jObj = findjobj(bHandle);
    
    % java obj may contain muliple objects, find with Border field
    for i = 1:length(jObj)
        if(sum(strcmp('Border',fieldnames(jObj(i)))))
            jHandle=java(jObj(i));
            set(jHandle,'Border',[]);
        end
    end
end

% refresh the screen
drawnow

% Now play the sound
sound(soundType);

% Change the cancel button to an exit button

% Search for the report generation frame
reportPanel = findobj(guiHandles.figure,'Title','Report Generation');

% Now search the buttons for the cancel button
cancelButton = findobj(reportPanel,'string','Cancel');
exitButton = findobj(reportPanel,'string','Exit');

set(cancelButton,...
    'Enable','off',...
    'Visible','off'...
    );

set(exitButton,...
    'Enable','on',...
    'Visible','on'...
    );
uicontrol(exitButton);
end


% --------- END OF FILE ----------