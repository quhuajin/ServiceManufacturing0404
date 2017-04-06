function h = pivotCheck(varargin)

% pivotCheck(device) performs pivot check.
%   Syntatx:
%     pivotCheck(device), Or
%     pivotCheck(device,ToolOffset)
%
%     device can be,
%     1. hgs robot
%     2. ndi camera
%     3. microscribe (mscribe)
%
%     ToolOffset is an optional input. If ToolOffset is not specified, the
%     function looks for the tcpfile.mat for offsets
%
%   Note:
%       currently supports only hgs robot device
%   Example:
%       pivotCheck(hgs), where hgs is a hgs_robot object
%       pivotCheck(hgs,Offset), where Offset is the TCP offset


%% Variables
hgs = '';
P = [];
count = 0;
hgs = '';
collectfunction = '';
device = 'device specification incorrect';
tcp_tool = [];

% result structure
result = [];
result.rms = [];
result.mean = [];
result.unit = 'mm';
result.count = 0;

%% Selecting device
if(nargin == 0)
    error('Need input. Specify Robot, Camera or Microscribe')
else
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
            collectfunction = @collectpoint_hgs;
            device = 'hgs robot';
            mode(hgs,'zerogravity','ia_hold_enable',0);
        end
        
        if isa(varargin{i},'mscribe')
            msArm = varargin{i};
            collectfunction = @collectpoint_scribe;
            device = 'scribe';
            
        end
    end
end

% check if offset is specified. If not look for tcpfile.mat
if(nargin == 2)
    if(size(varargin{2}) == [1,3])
        tcp_tool = varargin{2};
    else
        errordlg({'TCP definition is not correct!';...
            'TCP should be a 1x3 vector'});
    end
else
    if strcmp(device,'hgs robot')
    tcp_tool = hgs.EE_ORIGIN;
    end
end

%% Create GUI
% create figure
h = figure('Name',['Pivot Check, Device: ',device])

% create main button
hbutton = uicontrol(h,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.7,0.8,0.2],...
    'FontSize',0.4,...
    'String','Click Here to Collect Points',...
    'Callback',{collectfunction});

set(h,'UserData',result);
% highlite the main button
uicontrol(hbutton)

% text box
htext = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.5,0.8,0.1],...
    'FontSize',0.6,...
    'String','Pivot Check');

hresult = uicontrol(h,...
    'Style','text',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.1,0.2,0.8,0.2],...
    'FontSize',0.3,...
    'String',{'RMS';'Mean'});

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
        close(h);
    end


%% pivot check using the robot
    function result = collectpoint_hgs(hObhect,eventdata)
        count = count+1;
        set(hbutton,...
            'String',['Collect (',num2str(count),')']);
        T(1:4,1:4) = reshape(hgs.flange_tx,4,4)';
        p = T*[tcp_tool,1]';
        set(htext,...
            'String',num2str(p(1:3)'));
        P = [P,p(1:3)];
        if(size(P,2)>=2)
            P_mean = mean(P,2);
            for n = 1:size(P,2)
                P_err(n)= norm(P_mean - P(:,n));
            end
            rms = sqrt(sum(P_err.^2)/size(P_err,2));
            set(hresult,...
                'String',...
                {['RMS(mm):  ',num2str(rms*1000)];...
                ['Mean(mm): ',num2str(mean(P_err)*1000)]});
            % set results to user data
            result.rms = rms*1000;
            result.mean = mean(P_err)*1000;
            result.count = count;
            set(h,'UserData',result);
        end
    end

%% pivot check using the microScribe
    function result = collectpoint_scribe(hObhect,eventdata)
        count = count+1;
        set(hbutton,...
            'String',['Collect (',num2str(count),')']);
        p = get(msArm,'position');
        set(htext,...
            'String',num2str(p(1:3)));
        P = [P,p(1:3)'];
        if(size(P,2)>=2)
            P_mean = mean(P,2);
            for n = 1:size(P,2)
                P_err(n)= norm(P_mean - P(:,n));
            end
            rms = sqrt(sum(P_err.^2)/size(P_err,2));
            set(hresult,...
                'String',...
                {['RMS(mm):  ',num2str(rms)];...
                ['Mean(mm): ',num2str(mean(P_err))]});
            result.rms = rms;
            result.mean = mean(P_err);
            result.count = count;
            set(h,'UserData',result);
         end
    end
end

