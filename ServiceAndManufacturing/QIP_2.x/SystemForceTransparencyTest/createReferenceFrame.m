function [frame,p_origin] = createReferenceFrame(varargin)

% createReferenceFrame creates a reference frame at the EE origing using
% three points, collected using the hgs robot. Points 1 and 2 define the Z
% axis. Point 1 is the origin of the frame.
% saves output to 'frame.mat' with variables 'frame' and 'p_origin'


%%
if(nargin == 0)
% select default robot
hgs = hgs_robot;

else
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
        end
    end
end

if ~(isa(hgs,'hgs_robot'))
    error('input should be an hgs robot object')
end

% chekc is output director is specified. If not jsut put framefile in the
% current directory.
if nargin == 2;
    dirlocation = varargin{2};
    framefile = fullfile(dirlocation,'frame.mat');
else
    framefile = 'frame.mat';
end


%% Variables
done = 0; %done flag
count = 0;
point_description = {   'Teach Origin on the Force Gauge';
    'Teach Offset point along the Force Gauge Axis';
    'Select a random point'};
points = [];

%% Create GUI
% create figure
h = figure('Name','Create Referece','windowstyle','modal');
% create main button
hbutton = uicontrol(h,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.7,0.8,0.2],...
    'FontSize',0.25,...
    'String','Click Here to create Reference Frame',...
    'Callback',@main);

% highlite the main button
uicontrol(hbutton)

%text box for displaying device
htext0 = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.3,0.8,0.3],...
    'FontSize',0.2,...
    'String','');

% % text box
% htext = uicontrol(h,...
%     'Style','text',...
%     'Units', 'normalized',...
%     'FontUnits','normalized',...
%     'Position',[0.1,0.22,0.8,0.2],...
%     'FontSize',0.4,...
%     'String','Compute TCP');

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
        % if done flag is on, save the frame info
        if done
            save (framefile,'frame','p_origin');
        end
        close(h);
    end


%% Create Refernce
    function main(hObject,eventData)
        % this function computes the current tool center location

        if count == 0
            count = count+1;
            set(hbutton,...
                'String',point_description{count})
        else

            tool_offset = [hgs.EE_ORIGIN,1]'; %tool offset in homogeneous matrix form
            flange = reshape(hgs.flange_tx,4,4)';
            tool = flange*tool_offset;
            points(1:3,count) = tool(1:3);
            
            set(htext0,...
                'String',num2str(tool(1:3)'))

            % if count = 3 compute reference else increment count by 1 
            if count == 3
                p1 = points(:,1);
                p2 = points(:,2);
                p_rand = points(:,3);
                % create z-axis
                nz = (p2-p1)/norm(p2-p1);
                % create a temporary axis
                ntemp = (p_rand - p1)/norm(p_rand-p1);
                % cross temp axis with z-axis for creating a 
                % axis normal to both, which can be used a the y-asis
                ny = cross(nz,ntemp);
                ny = ny / norm(ny);
                % cross y-axis and z-axis to create x-axis
                nx = cross(ny,nz);
                nx = nx / norm(nx);
                
                frame = [nx,ny,nz];
                p_origin = p1;
                done = 1;
                
                set(htext0,...
                    'String',{'Reference Frame ';num2str(frame)})
                
                set(hbutton,...
                    'String','Click exit to save and exit',...
                    'Callback','',...
                    'Enable','off');
                uicontrol(hexit)
            else
            % increment count by 1
            count = count+1;
            set(hbutton,...
                'String',point_description{count})
            end
        end
    end
end

% not a nested function

