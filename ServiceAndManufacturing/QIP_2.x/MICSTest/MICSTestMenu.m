function MICSTestMenu

% MICSTestMenu is top level gui to execute QIP scripts for MICS
%
% Syntax:
%   MICSTestMenu
%       Starts up the top level gui to allow user to execute QIP scripts
%       for MICS
%
% Notes:
%
%
% See Also:
%


% Create the top level gui and return
customMenu('MICS Test','MICS QIP Test','',{'Motor Seal','Hand Piece','Config MICS','Cancel'});

%--------------------------------------------------------------------------
% internal function to customize matlabs default menu function
%--------------------------------------------------------------------------

    function [itemNumber,stringValue] = customMenu(figTitle,menuTitle,subTitle,stringList) %#ok<STOUT>
        
        screenSize = get(0,'MonitorPositions');
        
        % Setup
        topMargin = 10;
        bottomMargin = 20;
        itemSpacing = 10;
        buttonHeight = 30; %per button
        lineSeparatorHeight = 3;
        
        % default to the first screen size
        screenSize = screenSize(1,:);
        
        % determine the required height
        menuTitleHeight = 25;
        
        if isempty(subTitle)
            subTitleHeight = 0;
        else
            if iscell(subTitle)
                subTitleHeight = 15*length(subTitle);
            else
                subTitleHeight = 15;
            end
        end
        
        % number of lineSeparators
        numLineSeparators = length(find(strcmp(stringList,'------')));
        numOfButtons = length(stringList)-numLineSeparators;
        
        % now process the buttons
        stringListHeight = buttonHeight*numOfButtons;
        
        % Compute the total required Height
        
        totalRequiredHeight = menuTitleHeight+subTitleHeight...
            +topMargin+bottomMargin...
            +stringListHeight + numOfButtons*itemSpacing...
            +numLineSeparators*(lineSeparatorHeight+itemSpacing);
        
        % make the dialog box exactly in the middle of the screen
        dialogSize = [screenSize(3)/2-150, (screenSize(4)-totalRequiredHeight)/2,...
            300 totalRequiredHeight];
        % create a new figure
        figHandle = dialog;
        set(figHandle,...
            'Position',dialogSize,...
            'Color',[0.7 0.7 0.7],...
            'Name',figTitle);
        
        % start making the buttons
        
        % make title text
        titleYLocation = totalRequiredHeight-topMargin-menuTitleHeight;
        uicontrol(figHandle,...
            'Style','text',...
            'Position',[20 titleYLocation 260 menuTitleHeight],...
            'Background','white',...
            'fontsize',16,...
            'Background',[0.7 0.7 0.7],...
            'String',menuTitle);
        
        if ~isempty(subTitle)
            subTitleYLocation = titleYLocation-subTitleHeight;
            uicontrol(figHandle,...
                'Style','text',...
                'Position',[20 subTitleYLocation 260 subTitleHeight],...
                'Background','white',...
                'fontsize',8,...
                'Background',[0.7 0.7 0.7],...
                'String',subTitle);
        else
            subTitleYLocation = titleYLocation;
        end
        
        % Now starting making all the buttons
        numButtonsRendered = 0;
        numLinesRendered = 0;
        for i=1:length(stringList)
            if strcmp(stringList{i},'------')
                numLinesRendered = numLinesRendered+1;
                buttonYLocation = subTitleYLocation ...
                    -(itemSpacing+buttonHeight)*numButtonsRendered...
                    -(itemSpacing+lineSeparatorHeight)*numLinesRendered;
                uicontrol(figHandle,...
                    'BackgroundColor','black',...
                    'Style','togglebutton',...
                    'Value',1,...
                    'Position',[5 buttonYLocation 290 lineSeparatorHeight],...
                    'Enable','off');
            else
                numButtonsRendered = numButtonsRendered+1;
                buttonYLocation = subTitleYLocation ...
                    -(itemSpacing+buttonHeight)*numButtonsRendered...
                    -(itemSpacing+lineSeparatorHeight)*numLinesRendered;
                uicontrol(figHandle,...
                    'Style','pushbutton',...
                    'Position',[20 buttonYLocation 260 buttonHeight],...
                    'HorizontalAlignment','left',...
                    'fontsize',12,...
                    'String',stringList{i},...
                    'UserData',i,...
                    'Callback',@buttonPressCallback);
            end
        end
       
        %------------------------------------------------------------------
        % Internal function for callback
        %------------------------------------------------------------------
        function buttonPressCallback(objHandle,varargin)
            stringValue = get(objHandle,'String');
            switch stringValue
                case 'Hand Piece'
                    %testing for handpiece
                    MICSTest(stringValue,'10.1.1.177','tcpip',23);
                case 'Motor Seal'
                    %testing for motor seal
                    MICSTest(stringValue,'10.1.1.177','tcpip',23);
                case 'Config MICS'
                    %testing for motor seal
                    MICSTest(stringValue,'10.1.1.177','tcpip',23);
                case 'Cancel'
                    close(figHandle)
                otherwise
                    %
            end
        end
        
    end
end


% --------- END OF FILE ----------

