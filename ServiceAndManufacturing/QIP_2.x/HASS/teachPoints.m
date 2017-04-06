function h = teachPoints(varargin)

%teachPoints(hgs,filelocation)
%
% teaches points for socket accuracy check. Part of HASS test.

% $Author: rzhou $
% $Revision: 2117 $
% $Date: 2010-02-11 15:18:50 -0500 (Thu, 11 Feb 2010) $
% Copyright: MAKO Surgical corp 2007

% variables 
hgs = '';
viapoints = [];

%% 
if(nargin == 0)
    error('need input. specify a hgs robot object...')
else
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
        end
    end
end

if (isa(hgs,'hgs_robot'))
    mode(hgs,'zerogravity','ia_hold_enable',0);
else
    error('input not an hgs robot');
end

% the second input argument should be the file location
% if the location is not specified, store viapoints in the current
% directory
if nargin == 2
    fullfilename = fullfile(varargin{2},'viapoints.mat');
else
    fullfilename = 'viapoints.mat';
end

%%
points = [];
points_location = {'Right Side, 25mm (~1 inch) above the socket';...
    'Right Side, 2mm above the socket';...
    'Right Side, in the socket';...
    'Neutral Pose';...
    'Left Side, 25mm (~1 inch) above the socket';...
    'Left Side, 2mm above the socket';...
    'Left Side, in the socket'};

count = 0;

%% Create GUI
% create figure
h = figure('Name','Teach Points');
% create main button
hbutton = uicontrol(h,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.7,0.8,0.2],...
    'FontSize',0.3,...
    'String','Click here to Begin Teaching Points',...
    'Callback',@collectpoint);

% highlite the main button
uicontrol(hbutton)

% text box
htext = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.3,0.8,0.1],...
    'FontSize',0.4,...
    'String','Record Point');

%exit button
hexit = uicontrol(h,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.7,0.1,0.2,0.1],...
    'FontSize',0.4,...
    'String','Exit',...
    'Callback',@exitprogram);

    function exitprogram(hObject, eventdata)
        if count >= size(points_location,1)
            save (fullfilename, 'viapoints');
        end
        close(h);
    end
%% collect Points
    function collectpoint(hObject, eventdata)
        if count == 0
            count = count+1;
            set(hbutton,...
                'String',points_location{count})
        else
            joint_angles = hgs.joint_angles;
            points = [points;joint_angles];
            count = count+1;
            
            set(htext,...
                'String',num2str(joint_angles));

            if(count <=size(points_location,1))
                set(hbutton,...
                    'String',points_location{count})
            else
                viapoints = points;
                % display result
                set(hbutton,...
                    'String','Click exit to save and exit',...
                    'Callback','',...
                    'Enable','off');
                % highlite exit button
                uicontrol(hexit)
            end
        end
    end
end


%------------- END OF FILE ----------------
