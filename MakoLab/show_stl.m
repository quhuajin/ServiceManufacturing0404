function [patchHandle,face,verts] = show_stl(stlFileName)
%SHOW_STL display the model from an stl file
%
% Syntax:
%   show_stl(stlFileName)
%       read and display the model in the STL file specified by by stlFileName
%   show_stl
%       If no file is specified a dialog window will be opened and the user will
%       be prompted to choose a file
%
% See also:
%   patch, read_stl, surface, teapotdemo
%

%
% $Author: rzhou $
% $Revision: 3340 $
% $Date: 2013-12-16 17:50:09 -0500 (Mon, 16 Dec 2013) $
% Copyright: MAKO Surgical corp (creation date)
%

if (nargin==0)
    [selFileName,selPath] = uigetfile({'*.stl'});
    if (selFileName==0)
        warning('No file selected');
        return;
    else
        stlFileName = fullfile(selPath, selFileName);
    end
end

% Read in the STL filename
[face, verts, color] = read_stl(stlFileName);

% Start a new figure and setup some basic properties
figHandle = figure;

% the camera toolbar is very useful for visualization
cameratoolbar;

% Add a simple menu option to change from solid to wireframe or other views
popupHandle = uicontrol(figHandle,...
    'String',[{'Solid'},{'Wireframe'},...
        {'Transparent (50%)'},{'Transparent (25%)'}],...
    'Callback',@updateRenderingMode,...
    'Style','popupmenu',...
    'Units','normalized',...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.2,...
    'Position',[.75,.8,.2,.15]...
    );

set(gcf,'renderer','opengl');
axis off;

daspect([1,1,1]);
light('Position',[ 0.25 -0.433  -0.866],'Style','infinite');
light('Position',[-0.433 0.25 0.866],'Style','infinite');
view(3);

% Now render the stl file
patchHandle = patch('faces',face,...
    'vertices',verts,...
    'facec','flat',...
    'FacevertexCdata',color,...
    'edgecolor','none');

% Setup options for faster rendering.  Lock the zoom and limits
axis equal;
set(gca,'Xlimmode','manual','ylimmode','manual');

drawnow;

function updateRenderingMode(varargin)
    switch get(popupHandle,'value')
        case 1
            set(patchHandle,...
                'facec','flat',...
                'EdgeColor','none',...
                'facealpha',1 ...
                );
        case 2
            set(patchHandle,...
                'facec','none',...
                'EdgeColor','black',...
                'facealpha',0 ...
                );
        case 3
            set(patchHandle,...
                'facec','flat',...
                'EdgeColor','none',...
                'facealpha',0.5 ...
                );
        case 4
            set(patchHandle,...
                'facec','flat',...
                'EdgeColor','none',...
                'facealpha',0.25 ...
                );
    end
end

end



% --------- END OF FILE ----------