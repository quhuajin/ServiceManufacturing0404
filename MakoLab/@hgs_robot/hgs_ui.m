function hgs_ui(hgs)
%HGS_UI Gui to help perform common control tasks on the HGS robot
%
% Syntax:
%   control(hgs)
%       Starts up a simple gui to preform common operations on a connected hgs
%       robot.  Currently supported buttons are
%           * STOP - Stop the exectuion on any modes (ctrl modules) on the hgs
%           * FREE - Start the zerogravity module
%           * RECONNECT - Reconnects incase of a lost conection or restart
%
% Notes:
%   FREE button can be used only if homing has been performed
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home
%

%
% $Author: rzhou $
% $Revision: 2116 $
% $Date: 2010-02-11 15:15:37 -0500 (Thu, 11 Feb 2010) $
% Copyright: MAKO Surgical corp (creation date)
%

%% Create the simple gui

% Generic GUI options follow
defaultColor = [236 233 216]/255;

% get a new figure  and set up the static elements
figHandle = figure(...
    'Menubar','none',...
    'Name',['HGS: ',hgs.name],...
    'NumberTitle','off',...
    'Resize','on',...
    'Visible','on',...
    'HandleVisibility','off',...
    'Position',[200 200 200 300],...
    'Color',defaultColor...
    );

% organize all buttons onto a structure
% Stop button
buttonProperties(1) = struct(...
    'String','STOP',...
    'BackgroundColor','red',...
    'Callback',@stopHgs...
    );

% Free button
buttonProperties(2) = struct(...
    'String','Free (zerogravity)',...
    'BackgroundColor',defaultColor,...
    'Callback',@freeHgs...
    );

% Reconnect
buttonProperties(3) = struct(...
    'String','Reconnect',...
    'BackgroundColor',defaultColor,...
    'Callback',@reconnectHgs...
    );

% Render the buttons
spacing = 0.05;
numOfButtons = length(buttonProperties);
for i=1:numOfButtons
    % compute positions based on number of buttons
    buttonPosition = [ spacing, spacing + 1-i/numOfButtons, 1-2*spacing,...
        1/numOfButtons-2*spacing];
    uicontrol(figHandle,...
        buttonProperties(i),...
        'Style','pushbutton',...
        'Units','normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'FontSize',0.25,...
        'Position',buttonPosition...
        );
end

%% Callback functions

% Stop callback function
    function stopHgs(varargin)
        stop(hgs);
    end

% Free callback function
    function freeHgs(varargin)
        mode(hgs,'zerogravity','ia_hold_enable',0);
    end

% Reconnect the hgs
    function reconnectHgs(varargin)
        reconnect(hgs);
    end

end

% --------- END OF FILE ----------
