function updateMainButtonInfo(guiHandles,varargin)
% updateMainButtonInfo control the main button properties
%
% Syntax:
%    updateMainButtonInfo(guiHandles,mode)
%        this function can be used to control the main button, info text
%        box.  
%        The mode can be used to change this to a button or a textbox
%        valid values for mode are
%            mode = 'pushbutton';  % change the gui to a button
%            mode = 'text';  % change the gui to a text box
%
%    updateMainButtonInfo(guiHandles,mode,string)
%    updateMainButtonInfo(guiHandles,mode,string,function)
%        The arguments can be any order.  If the argument is a string the
%        string on the button/text box will be updated.  If the argument is
%        a function the callback function will be updated.
%        
% Example
%    updateMainButtonInfo(guiHandles,'text','Some text');
%    updateMainButtonInfo(guiHandles,@ls);
%
% Notes:
%    This function is valid only for GUI created with the generateMakoGui
%    function.
%    Please refer to
%    http://twiki.makosurgical.com/view/Robot/HgsServiceAndManufacturingGUITemplate
%    for description on the GUI concept.
%
% See Also:
%    presentMakoResults, generateMakoGui, resetMakoGui

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)

% Adjust font scaling based on full panel or half
DEFAULTFONTSIZE = 0.35;
if  (strcmp(get(guiHandles.extraPanel,'Visible'),'on'))
    fontScaling = 0.7;
else
    fontScaling = 1;
end

for argNumber=2:nargin
    i = argNumber-1;

    if (isa(varargin{i},'function_handle') ...
            || (iscell(varargin{i})... 
                && (isa(varargin{i}{1},'function_handle'))))
        % check if this is a function.  if so replace callback for button
        set(guiHandles.mainButtonInfo,'Callback',varargin{i});
        
    elseif (strcmpi(varargin{i},'pushbutton'))
        % if this is a request to change to a push button, do so
        % make sure the button is released
        set(guiHandles.mainButtonInfo,...
            'Style','pushbutton',...
            'fontSize',DEFAULTFONTSIZE*fontScaling,...
            'Value',0,...
            'BackgroundColor',[0.9255, 0.9137, 0.8471]);
        uicontrol(guiHandles.mainButtonInfo);
        
    elseif (strcmpi(varargin{i},'text'))
        % if this is a request to change to text box do so
        set(guiHandles.mainButtonInfo,...
            'Style','text',...
            'BackgroundColor','white');
    else
        % By default assume this is the text to be it in
        % find the font size
        if iscell(varargin{i})
            fontSize = DEFAULTFONTSIZE/length(varargin{i});
        else
            fontSize = DEFAULTFONTSIZE;
        end
        set(guiHandles.mainButtonInfo,...
            'FontSize',fontSize*fontScaling,...
            'String',varargin{i});
    end
    drawnow;
end


% --------- END OF FILE ----------