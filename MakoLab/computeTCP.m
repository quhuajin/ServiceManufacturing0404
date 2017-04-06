function computeTCP(varargin)

% computeTCP, comutes the Tool Center point.
% Syntatx:
%     computeTCP(device)
%     device can be,
%     1. hgs robot
%     2. ndi camera
%     3. microscribe (scribe)
% currently supports only hgs robot device
% Example:
%     computeTCP(hgs), where hgs is a hgs_robot object

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

hgs = '';
collectfunction = '';
device = 'device specification incorrect';
%% selecting device.
if(nargin == 0)
    error('need input. Specify Robot, Camera or Microscrbie')
else
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
            collectfunction = @collectpoint_hgs;
            device = 'hgs robot';
            mode(hgs,'zerogravity','ia_hold_enable',0);
        end

        if (strcmp(varargin{i},'scribe'))
            msArm = mscribe();
            collectfunction = @collectpoint_scribe;
            device = 'scribe';
        end
    end
end

%% Variables
T = [];
sample_size = 10;
count = 0;
tcp_tool = [];
P = [];

%% Create GUI
% create figure
h = figure('Name','Find Tool Centre Point','WindowStyle','Modal');
% create main button
hbutton = uicontrol(h,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.7,0.8,0.2],...
    'FontSize',0.4,...
    'String','Click Here to Collect Points',...
    'Callback',{collectfunction});

% highlite the main button
uicontrol(hbutton)

%text box for displaying device
htext0 = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.42,0.8,0.2],...
    'FontSize',0.4,...
    'String',['Device: ',device]);

% text box
htext = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.22,0.8,0.2],...
    'FontSize',0.4,...
    'String','Compute TCP');

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
        if count >= sample_size
            if strcmp(device,'hgs robot')
                hgs.EE_ORIGIN = tcp_tool;
            end
        end
        close(h);
    end

%% compute TCP using the robot
    function collectpoint_hgs(hObject, eventdata)

        count = count+1;
        % Flange transform
        T(1:4,1:4,count) = reshape(hgs.flange_tx,4,4)';
        set(htext,...
            'String',[num2str(count),'/ 10']);

        if(size(P,2)>=2)
            P_mean = mean(P,2);
            for n = 1:size(P,2)
                P_err(n)= norm(P_mean - P(:,n));
            end
            rms = sqrt(sum(P_err.^2)/size(P_err,2));
        end

        if count == sample_size
            % disable main button
            set(hbutton,...
                'String','Click exit to save and exit',...
                'Callback','',...
                'Enable','off');
            % compute TCP
            for i=1:count-1
                A((i-1)*3+1:(i-1)*3+3,1:3) = T(1:3,1:3,i)-T(1:3,1:3,i+1);
                b((i-1)*3+1:(i-1)*3+3,1)   = T(1:3,4,i+1)-T(1:3,4,i);
            end

            tcp_tool = (pinv(A)*b)';

            % display result
            set(htext0,...
                'FontSize',0.3,...
                'String',{'TCP:'; num2str(tcp_tool)});

            % find measurement error
            rms_error = find_rms_error(T,tcp_tool);
            % display result
            set(htext,...
                'FontSize',0.3,...
                'String',{'rms error (mm): ',num2str(rms_error*1000)});

            % highlite exit button
            uicontrol(hexit)

        end
    end
%% compute TCP using micro scribe
    function collectpoint_scribe(hObject, eventdata)
        count = count+1;
        T(1:4,1:4,count) = get(msArm,'transform');
        set(htext,...
            'String',[num2str(count),'/ 10']);

        if count == sample_size
            % disable main button
            set(hbutton,...
                'String','Click exit to save and exit',...
                'Callback','',...
                'Enable','off');

            for i=1:count-1
                A((i-1)*3+1:(i-1)*3+3,1:3) = T(1:3,1:3,i)-T(1:3,1:3,i+1);
                b((i-1)*3+1:(i-1)*3+3,1)   = T(1:3,4,i+1)-T(1:3,4,i);
            end
            tcp_tool = (pinv(A)*b)';

            % display result
            set(htext0,...
                'FontSize',0.3,...
                'String',{'TCP:'; num2str(tcp_tool)});

            % find measurement error
            rms_error = find_rms_error(T,tcp_tool);
            % display result
            set(htext,...
                'FontSize',0.3,...
                'String',{'rms error (mm): ',num2str(rms_error)});

            % highlite exit button
            uicontrol(hexit)
        end
    end
end

function rms_error = find_rms_error(T,tcp_tool)

P = [];
% find the tool tip loacation for each measurement
for count = 1:size(T,3)
    t = T(1:4,1:4,count);
    p = t*[tcp_tool,1]';
    P = [P,p(1:3)];
end
% find mean loacation
P_mean = mean(P,2);
% find measurement error
for n = 1:size(P,2)
    P_err(n)= norm(P_mean - P(:,n));
end
% rms
rms_error = sqrt(sum(P_err.^2)/size(P_err,2));

end


%------------- END OF FILE ----------------
