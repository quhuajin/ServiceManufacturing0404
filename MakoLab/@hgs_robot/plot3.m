function m = plot3(hgs,model_resolution_or_angle)
%PLOT3 display a 3D model of the connected robot.
%
% Syntax:  
%   m = plot3(hgs)
%       show a 3D model of the connected hgs_robot robot identified by the
%       argument hgs.  output m is a structure with all the handles to the
%       patch objects used to create the robot model.
%   plot3(hgs,resolution)
%       the resolution argument can be used to select if the robot models
%       used are high resolution or low resolution.  low resolution models
%       will update faster.  this parameter can be either "high" or "low"
%   
%   plot3(hgs,joint_angles)
%       show the robot in the pose specified by the joint_angles
%
% Notes:
%   For speed reasons the models are preloaded and saved in mat file
%   format.  See README file in the robotSTLfiles directory in the private
%   directory of the hgs_robot object
%
% See also: 
%    hgs_robot/plot, patch, read_stl, transform_vertices
 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% process the inputs
if (nargin==1)
    model_resolution = 'low';
    live_plot_update = true;
else
    if isnumeric(model_resolution_or_angle)
        model_resolution = 'high';
        joint_angles = model_resolution_or_angle;
        live_plot_update = false; 
    else
        model_resolution = model_resolution_or_angle;
        live_plot_update = true;
        if ~(strcmpi(model_resolution,'low') ...
                || strcmpi(model_resolution,'high'))
            error('Model resolution must be "high" or "low"');
        end
    end
end
model_variable_name = ['m_',lower(model_resolution),'_res'];

% Query robot for parameter required for rendering
configParams = commDataPair(hgs,'get_cfg_params');

dhmatrix = reshape(configParams.NOMINAL_DH_MATRIX,4,...
    configParams.WAM_DOF)';

% check joint angle dimensions
if ~live_plot_update && length(joint_angles)~=configParams.WAM_DOF
    error('Joint angles dimension mismatch (dof = %d)',configParams.WAM_DOF);
end

% Load the models file based on the robot version number
if (configParams.ARM_HARDWARE_VERSION>=1.0) ...
        && (configParams.ARM_HARDWARE_VERSION<2.0)
    m_model = load('robot_models_1X.mat',model_variable_name);
elseif (configParams.ARM_HARDWARE_VERSION>=2.0) ...
        && (configParams.ARM_HARDWARE_VERSION<3.0)
    m_model = load('robot_models_2X.mat',model_variable_name);
else
    error('Unsupported Arm model number (arm hardware version = %f)',...
        configParams.ARM_HARDWARE_VERSION);
end

m = m_model.(model_variable_name);

for i=1:configParams.WAM_DOF+1
    m(i).patch = patch(...
        'faces',m(i).faces,...
        'vertices',m(i).verts,...
        'Facecolor',m(i).color,...
        'edgecolor','none');
end

plot3Axes = get(m(1).patch,'parent');
plot3Figure = get(plot3Axes,'parent');
set(plot3Figure, 'CloseRequestFcn', @closePlot3);
plot3DTimer = [];

material dull;

% if this is a static image improve the quality
if ~live_plot_update
    lighting phong;
else
    % setup the camera and workspace
    set(plot3Figure,'renderer','opengl');
end

daspect([1,1,1]);
light('Position',[ 0.250 -0.433  -0.866],'Style','infinite');
light('Position',[-0.433  0.250   0.866],'Style','infinite');
view(3);
axis equal;
axis([-0.600,0.600,-0.600,0.600,-0.300,0.600]);
set(gca,'Xlimmode','manual','ylimmode','manual');
axis off

% if this is a request for a live plot update setup a timer
if live_plot_update
    % the system looks horrible if not started at a known good location.
    % by default start it at current location
    update_robot_pose(m,dhmatrix,get(hgs,'joint_angles'));

    % Setup a timer to update this position
    plot3DTimer = timer(...
        'TimerFcn',@updatePlot,...
        'Period',0.005,...
        'ObjectVisibility','off',...
        'BusyMode','drop',...
        'ExecutionMode','fixedSpacing'...
        );

    start(plot3DTimer);
else
    update_robot_pose(m,dhmatrix,joint_angles);
end

%--------------------------------------------------------------------------
%----------------- Internal function to to update the 3D object    --------
%--------------------------------------------------------------------------

    function updatePlot(varargin)
        update_robot_pose(m,dhmatrix,get(hgs,'joint_angles'));
    end

    function update_robot_pose(models,dhmatrix,joint_angles)
        joint_transforms = dh_to_transforms(dhmatrix,joint_angles);
        for k=1:length(joint_angles)
            set(models(k+1).patch,'Vertices',transform_vertices(...
                models(k+1).verts,joint_transforms{k}));
        end
        drawnow
    end
    function closePlot3(varargin)
        if  ~isempty(plot3DTimer)
            stop(plot3DTimer);
            delete(plot3DTimer);
        end
        closereq;
     end

end
%--------------------------------------------------------------------------
%----------------- Internal function to compute forward kinematics --------
%--------------------------------------------------------------------------
function transforms = dh_to_transforms(dh,joint_angles)
sa  = sin(dh(:,2));
ca  = cos(dh(:,2));
st  = sin(dh(:,4)+joint_angles');
ct  = cos(dh(:,4)+joint_angles');

% stl model was generated in mm so convert dh to mm
A   = dh(:,1);
d   = dh(:,3);

zr = zeros(length(joint_angles),1);
ons = ones(length(joint_angles),1);

tr1 = [ct       -st       zr     A];
tr2 = [st.*ca    ct.*ca  -sa    -d.*sa];
tr3 = [st.*sa    ct.*sa   ca     d.*ca];
tr4 = [zr        zr       zr     ons];

transforms{1}= [tr1(1,:);tr2(1,:);tr3(1,:);tr4(1,:)];
for i=2:length(joint_angles)
    transforms{i}= transforms{i-1}...
        *[tr1(i,:);tr2(i,:);tr3(i,:);tr4(i,:)]; %#ok<AGROW>
end

end


% --------- END OF FILE ----------