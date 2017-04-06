%VERR_accuracy_assessment  Script to measure system accuracy
%
% Description:
%   VERR_accuracy_assessment measures the system accuracy of the robot.
%   The script guides the user to collect points and orientations 
%   along the the Accuracy assessment fixture with the end-effector.  The
%   results are ploted.
%
% Syntax:
%   VERR_accuracy_assessment
%     run the script using default options.  User will be prompted when
%     required
%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $ 
% Copyright: MAKO Surgical corp 2007

%% 


function []=AccuracyCheck(varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%this is how to initalize the mat files from STL files
%
% [Fprobe,Vprobe,Cprobe] = read_stl('ball_shaft.STL');
% Vprobe_offset=[12.5 12.5 12.5];
% Vprobe= transfrom_vertices(Vprobe,Vprobe_offset)
% save BallShaft.mat Fprobe Vprobe Cprobe
% 
% [Faak,Vaak,Caak] = read_stl('AAK_CBinary.STL');
% save AAK_CBinary.mat Caak Faak Vaak
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

use_file = false;
scriptName = 'Robot Accuracy Assessment';
displayText=scriptName;% 
guiHandles='';
for i=1:nargin
    if strcmp(varargin{i},'record_flag')
        use_file = true;
    end
    if isfield(varargin{i},'uiPanel')
        guiHandles=varargin{i};
    end
end

global collecting
%is the actual rig being used(1) or a file(0)
collecting =~use_file;
%

if ~collecting
    a = dir(['Accuracy-','*']);
    file_loader_struct= a(end,:);
    file_loader=file_loader_struct.name;
    displayText=['Filename : ',file_loader];    %#ok<NASGU>
%     set(displayTextSpace,...
%         'String',sprintf('Filename : %s',file_loader));
    pause(2);
    try
        load(file_loader)
        hgs=robotName;
        displayText=['Loading ',file_loader, ' successful'];
%         set(displayTextSpace,...
%             'String',sprintf('Loading %s successful',file_loader));
        dataFilename = 'none';
    catch
        displayText='Unable to load File...collecting points';
%         set(displayTextSpace,...
%             'String',sprintf('Unable to load File...collecting points'));
        collecting = true;
    end
end


if collecting
    hgs = '';
    for i=1:nargin
        if (isa(varargin{i},'hgs_robot'))
            hgs = varargin{i};
        end
    end

    if (~isa(hgs,'hgs_robot'))
        hgs = hgs_robot;
    end
    common_inputs.robotName = hgs.name;

    log_message(hgs,'Robot Accuracy Check Script Started');

    scriptName='RobotAccuracy';

end



%% Create a Makogui
if isempty(guiHandles)
    guiHandles = generateMakoGui(scriptName,[],hgs,true);
    set(guiHandles.mainButtonInfo,...
        'String',sprintf('Running %s',scriptName)...
        );
end

    
%% set up back button

%set up boundaries
XpushSize = 0.4;
xBounds = 0.35;
YpushSize = 0.1;
yBounds = 0.5;
activePoint.orient=1;
activePoint.point=1;
activePoint.first=1;
activePoint.maxOrient=4;
activePoint.Flag=false;
commonBoxProperties = struct(...
    'Style','pushbutton',...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.5,...
    'BackgroundColor',[204 204 204]/255);
boxPosition=[xBounds yBounds XpushSize YpushSize];
backButton = uicontrol(guiHandles.uiPanel,...
    commonBoxProperties,...
    'Position',boxPosition,...
    'String',sprintf('Redo Point'),...
    'UserData',activePoint,...
    'Callback',@redoPoint); %#ok<NASGU>

%% recompute TCP
hrecomputeTCP = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.78,0.05,0.2,0.06],...
    'FontSize',0.4,...
    'String','recompute TCP',...
    'Callback',{@computeTCP,hgs});

%% Pivot Check
hpivotCheck = uicontrol(guiHandles.uiPanel,...
    'Style','pushbutton',...
    'Units', 'normalized',...
    'FontUnits','normalized',...
    'Position',[0.78,0.15,0.2,0.06],...
    'FontSize',0.4,...
    'String','Pivot Check',...
    'Callback',{@pivotCheck,hgs}); %#ok<NASGU>

%% set up text positions
%%set up display text location

commonTextProperties =struct(...
   'Style','text',...
   'Units','normalized',...
   'FontWeight','bold',...
   'FontUnits','normalized',...
   'FontSize',0.45,...
   'HorizontalAlignment','left');
displayTextSpace = uicontrol(guiHandles.uiPanel,...
   commonTextProperties,...
   'Position',[0.02 0.75 .95 0.2],...
   'String',displayText); %#ok<NASGU>

%% Set up point collection structure

common_inputs.axis_names={'X axis', 'Y axis', 'Z axis'};
common_inputs.block_length_groups= 7;
common_inputs.row_length = 6;
common_inputs.socket_per_surface = 15;   %ball points per surface
common_inputs.samples = 20;                 %samples per ball
common_inputs.sides= {'top' 'front' 'right'};
common_inputs.edges = {'first_edge' ,'diagonal', 'last_edge'};
common_inputs.orintations=5;
common_inputs.orintation_text= {'+ 30about','-30 about'};
common_inputs.last_edge=false;
common_inputs.AllsocketsSum=0;
common_inputs.AllLengthSum=0;
common_inputs.SumIndex = 0;
common_inputs.line=1;
common_inputs.errors=[];

TOP=1;
FRONT=2;
RIGHT=3;
EDGE1=1; %#ok<NASGU>
%DIAG=2;
EDGE3=3;

common_inputs.bal_one...
    =[ 15, 15, 20;... %ball 1 top
    15, -20, -15;...   %ball 1 front
    -20, 15, -15;...   % ball 1 right
    ];
common_inputs.bal_trans(TOP).move...
    =[60 0 0;...
     -60 60 0;...
      0 -60 0];
common_inputs.bal_trans(FRONT).move...
    =[0 0 -60;...
      60 0 60;...
      -60 0 0];
common_inputs.bal_trans(RIGHT).move...
    =[0 60 0;...
      0 -60 -60;...
      0 0 60];
common_inputs.bal_rot...
    =(pi()/180)*...
    [90, 0, 0;...   %normal top 
    180, 0, 0;...   %normal front 
    180, 0, -90;... %normal right 
    45, 0, 0;...    % pos x 
    -45, 0, 0;...   % neg x 
    0, 45, 0;...    % pos y 
    0, -45, 0;...   % neg y 
    0, 0, 45;...    % pos Z
    0, 0, -45;...   % neg z
    ];
common_inputs.viewAngle=...
    [32 60;...      % right TOP
     20 15;...      % right Front
     -120 72;...    % left TOP
     -115 32];      % left Front
 common_inputs.Pos=...
    [0.25 0.10 0.8 0.8;...      % righty TOP
     0.25 0.2 0.8 0.8;...      % righty Front
     -0.1 0.1 0.8 0.8;...    % lefty TOP
     -0.0 0.15 0.8 0.8];      % lefty Front


%% if colecting set up visuals
    %% plot the rig
    uiPanelPlot = axes('Position',[0.1 0.2 0.8 0.8],...
        'Parent',guiHandles.extraPanel,'Visible','off');
if collecting
%     load AAK_CBinary.mat
    load AAK_CBinary.mat
    rig_handles.patch_handle_AAK...
        =patch('faces',Faak,'vertices',Vaak,...
        'facevertexcdata',Caak,...
        'Parent',uiPanelPlot,... 
        'edgecolor','none','facec','flat');
    % plot the EE
    load BallShaft.mat
    rig_handles.Vprobe=Vprobe;
    rig_handles.patch_handle_ball...
        =patch('faces',Fprobe,'vertices',Vprobe,...
        'facevertexcdata',Cprobe,...
        'Parent',uiPanelPlot,...
        'edgecolor','none','facec','flat');
    set(rig_handles.patch_handle_ball,'FaceColor', [0 0 1]);
    set(uiPanelPlot,'position',[0.15 0.1 0.9 0.9]);
    axis(uiPanelPlot,'manual');
    axis(uiPanelPlot,[-50 350 -50 350 -300 100]);
    view(uiPanelPlot,22,32);
    %zoom in
    camzoom(uiPanelPlot,1.6)
    daspect(uiPanelPlot,[1,1,1]);  
    light('Position',[-0.433 -0.45 -0.866],'Style','infinite',...
        'Parent',uiPanelPlot);
    light('Position',[0.433 0.45 0.866],'Style','infinite',...
        'Parent',uiPanelPlot);
    
    % initilize location of ball
    set(rig_handles.patch_handle_ball,...
        'vertices',transform_vertices(...
        rig_handles.Vprobe,...
        common_inputs.bal_one(1,:),...
        common_inputs.bal_rot(1,:))...
        );
    
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');

%% recording
    mode(hgs,'zerogravity','ia_hold_enable',0);
end

%% Set up Main Button for Detecting Robot position (Lefty or Righty)
set(guiHandles.mainButtonInfo,...
    'String','Click here to Detect Robot Position',...
    'Callback',{@detect_RightyLefty,hgs,...
    guiHandles,rig_handles,common_inputs,...
    scriptName, uiPanelPlot, displayTextSpace})


end  %%% END OF MAIN FUNCTION
%============================================

%% Detect righty or lefty
function detect_RightyLefty(hObject,eventdata,hgs,...
    guiHandles,rig_handles,common_inputs,...
    scriptName,uiPanelPlot, displayTextSpace)
% Used to distinguish whether the robot is at the Righty or Lefty testing
% position and load the corresponding CMM file  
% CMMDone= false;  % used for deciding when to terminate the CMM loading procedure 
% TOP=1;
FRONT=2;
% RIGHT=3;
EDGE1=1; %#ok<NASGU>
%DIAG=2;
% EDGE3=3;

set(guiHandles.mainButtonInfo,...
    'String','Place EE on the First Socket of the Testing Rig');
joint_angles= get(hgs, 'joint_angles');
    
% Detect Righty or Lefty position
% Support both '..Left.mat'/'..Right.mat' and '..Lefty.mat'/'..Righty.mat'
% for input filenames
if joint_angles(3) > 0*pi/180  %  LEFTY robot position
    CMMFileName= 'C:\PyramidCMMDefinition\Pyramid_Left.mat';
    displayText='Lefty CMM Data Loading Successful!';
    CMMFileNameAlt= 'C:\PyramidCMMDefinition\Pyramid_Lefty.mat';
    fileNameIni='Lefty'; % used to construct data file name
else  % RIGHTY robot position
    CMMFileName= 'C:\PyramidCMMDefinition\Pyramid_Right.mat';
    displayText='Righty CMM Data Loading Successful!';
    CMMFileNameAlt= 'C:\PyramidCMMDefinition\Pyramid_Righty.mat';
    fileNameIni='Righty'; % used to construct data file name
end  % end of if

try
    load(CMMFileName, 'Pyramid');
    common_inputs.nom_lengths=...
        0.001*Pyramid.rawData;
    % show text to indicate the file loading is successful
    set(displayTextSpace,'String',...
        displayText,...
        'fontsize', 0.2, 'ForegroundColor',[0 0 0]);
    pause(0.3);
catch  % if loading fails, then try the alternate filename
    try
        load(CMMFileNameAlt, 'Pyramid');
        common_inputs.nom_lengths=...
            0.001*Pyramid.rawData;
        % show text to indicate the file loading is successful
        set(displayTextSpace,'String',...
            displayText,...
            'fontsize', 0.2, 'ForegroundColor',[0 0 0]);
        pause(0.3);
    catch  % if loading fails, then display the error message
        set(displayTextSpace,'String',...
            'CMM Data Loading Failure!!',...
            'fontsize', 0.2, 'ForegroundColor','r');
        pause(0.3);
        uiwait(errordlg('CMM Data Loading Failure!! Click OK to Exit Program.',...
            'CMM Data Reading Error', 'modal'));
        hFound= findobj(guiHandles.figure, 'String','Cancel');
        feval(get(hFound, 'Callback'));
    end % end try-catch
end % end try-catch

% Put Lefty or Righty Info into common_inputs   
common_inputs.fileNameIni= fileNameIni;

% setup graphics for LEFTY position
if strcmp(fileNameIni,'Lefty')
    set(rig_handles.patch_handle_AAK,'facecolor','k');
    
    common_inputs.bal_trans(FRONT).move...
        =[0 60 0;...
        0 -60 -60;...
        0 0 60];
    
    common_inputs.bal_one...
        =[ 15, 15, 15;... %ball 1 top
        -18, 15, -15;...   %ball 1 front
        15, -18, -15;...   % ball 1 right
        ];
    
    common_inputs.bal_rot...
        =(pi()/180)*...
        [90, 0, 0;...   %normal top
        180, 0, -90;...   %normal front
        180, 0, 0;... %normal right
        45, 0, 0;...    % pos x
        -45, 0, 0;...   % neg x
        0, 45, 0;...    % pos y
        0, -45, 0;...   % neg y
        0, 0, 45;...    % pos Z
        0, 0, -45;...   % neg z
        ];
end

%% data file name
Filename=sprintf('%s-%s-%s-%s%s',...
    strrep(scriptName,' ',''),fileNameIni, ...
    hgs.name,...
    datestr(now,'yyyy-mm-dd-HH-MM'),...
    '.mat');
dataFilename = fullfile(guiHandles.reportsDir,Filename);

%% Set up Main Button for Computing TCP
set(guiHandles.mainButtonInfo,...
    'String','Click here to Begin Test',...
    'Callback',{@compute_TCP,hgs,...
    guiHandles,rig_handles,common_inputs,...
    dataFilename,uiPanelPlot, displayTextSpace})

end

%% Compute TCP
function compute_TCP(hObject,eventdata,hgs,...
    guiHandles,rig_handles,common_inputs,...
    dataFilename,uiPanelPlot, displayTextSpace)

% call computeTCP function
feval(@computeTCP,hgs)
uiwait();

% update GUI
set(guiHandles.mainButtonInfo,...
    'String','Click here to Start Collecting Points',...
    'Callback',{@collectPoints,hgs,...
    guiHandles,rig_handles,common_inputs,...
    dataFilename,uiPanelPlot, displayTextSpace})
end

%% Collect points,
function collectPoints(hObject,eventdata,hgs,...
    guiHandles,rig_handles,common_inputs,...
    dataFilename,uiPanelPlot, displayTextSpace)
global acc;
% globals
TOP=1;
FRONT=2;
% RIGHT=3;
EDGE1=1; %#ok<NASGU>
%DIAG=2;
EDGE3=3;

% set tool center point (TCP), aka tool offset.
common_inputs.eeArray2flange=eye(4);
common_inputs.eeArray2flange(1:3,4) = hgs.EE_ORIGIN;


%%%%%%%%%%%%%load points Method 2:  X, X, Y, Z only
if strcmp(common_inputs.fileNameIni,'Lefty')
    vAngleTOP=common_inputs.viewAngle(3,:);
    vAngleFRONT=common_inputs.viewAngle(4,:);
    posTOP=common_inputs.Pos(3,:);
    posFRONT=common_inputs.Pos(4,:);
else
    vAngleTOP=common_inputs.viewAngle(1,:);
    vAngleFRONT=common_inputs.viewAngle(2,:);
    posTOP=common_inputs.Pos(1,:);
    posFRONT=common_inputs.Pos(2,:);
end

view(uiPanelPlot,vAngleTOP); set(uiPanelPlot,'position',posTOP);
record_points(1,6,TOP,hgs,guiHandles,rig_handles,common_inputs,displayTextSpace);
record_points(11,15,TOP,hgs,guiHandles,rig_handles,common_inputs,displayTextSpace);
view(uiPanelPlot,vAngleFRONT); set(uiPanelPlot,'position',posFRONT);
record_points(1,6,FRONT,hgs,guiHandles,rig_handles,common_inputs,displayTextSpace);
record_points(11,15,FRONT,hgs,guiHandles,rig_handles,common_inputs,displayTextSpace);

set(guiHandles.mainButtonInfo,...
        'String',sprintf('View Accuracy results'),...
        'Callback',{@Return_press,guiHandles}...
        );
%%%calculate the block lengths for each side/edge
[output]...
    =block_length_fun...
    (TOP,EDGE1,dataFilename,common_inputs);
common_inputs.AllsocketsSum=output.AllsocketsSum;
common_inputs.AllLengthSum=output.AllLengthSum;
common_inputs.SumIndex = output.SumIndex;
common_inputs.line=output.line;
common_inputs.errors=output.errors;
[output]...
    =block_length_fun...
    (TOP,EDGE3,dataFilename,common_inputs);
common_inputs.AllsocketsSum=output.AllsocketsSum;
common_inputs.AllLengthSum=output.AllLengthSum;
common_inputs.SumIndex = output.SumIndex;
common_inputs.line=output.line;
common_inputs.errors=output.errors;
[output]...
    =block_length_fun...
    (FRONT,EDGE1,dataFilename,common_inputs);
common_inputs.AllsocketsSum=output.AllsocketsSum;
common_inputs.AllLengthSum=output.AllLengthSum;
common_inputs.SumIndex = output.SumIndex;
common_inputs.line=output.line;
common_inputs.errors=output.errors;

[output]...
    =block_length_fun...
    (FRONT,EDGE3,dataFilename,common_inputs);
common_inputs.AllsocketsSum=output.AllsocketsSum;
common_inputs.AllLengthSum=output.AllLengthSum;
common_inputs.SumIndex = output.SumIndex;
common_inputs.line=output.line;
common_inputs.errors=output.errors;

AccRMS=sqrt(common_inputs.AllLengthSum...
    /common_inputs.SumIndex)*1000;
PivotRMS=sqrt(common_inputs.AllsocketsSum...
    /common_inputs.SumIndex)*1000;

%% Save Results
save(dataFilename,'common_inputs','AccRMS','PivotRMS','output','acc');
%% plot results
set(uiPanelPlot,'Position',[0.1 0.1 0.8 0.8]);
stem(uiPanelPlot, common_inputs.errors')
legend(uiPanelPlot,'0','1','2','3','4','5')
xlabel(uiPanelPlot, 'sockets')
ylabel(uiPanelPlot, 'error in length, meters')
title(uiPanelPlot,'Measurement Error and Measured Length')

% save results to workspace  Save in the reports directory
dataFile = fullfile(guiHandles.reportsDir,'RobotAccuracyCheckData.mat');
save(dataFile);

% Add a string on result screenshot to indicate whether the test is for
% Righty or Lefty robot position
set(displayTextSpace, 'String',...
    sprintf('%s Robot Accuracy Test Completed!',common_inputs.fileNameIni));  

%Log Results struct
LogResults.AccuracyRMS = AccRMS;
LogResults.AccuracyRMSLimit = 0.35;
LogResults.PivotRMS = PivotRMS;
LogResults.PivotRMSLimit = 0.35;

% pass. GREEN. Limit set at 0.3mm
if AccRMS< 0.3 && PivotRMS< 0.3
    presentMakoResults(...
        guiHandles,'SUCCESS',...
        {['AccuracyRMS= ',num2str(AccRMS),' mm'],...
        ['PrecisionRMS = ',num2str(PivotRMS),' mm']});
    log_results(hgs,'RobotAccuracyCheck',...
    	'PASS','Robot Accuracy Check was Successful',LogResults);
    
% warning. YELLOW. Limit set at 0.35mm     
elseif AccRMS< 0.35 && PivotRMS< 0.35
    presentMakoResults(...
        guiHandles,'WARNING',...
        {['AccuracyRMS= ',num2str(AccRMS),' mm'],...
        ['PrecisionRMS = ',num2str(PivotRMS),' mm'],...
        'Limit: 0.35 mm, Warning at 0.30 mm'});
    log_results(hgs,'RobotAccuracyCheck',...
    	'WARNING','Robot Accuracy Test Passed with a Warning',LogResults);

else
    presentMakoResults(...
        guiHandles,'FAILURE',...
        {['AccuracyRMS= ',num2str(AccRMS),' mm'],...
        ['PrecisionRMS = ',num2str(PivotRMS),' mm'],...
        'Limit: 0.35 mm'});
    log_results(hgs,'RobotAccuracyCheck',...
    	'FAIL','Robot Accuracy Test Failed',LogResults);
    
end
log_message(hgs,'RobotAccuracyCheck Script Closed');
end

%% record points (of a side)
function []=record_points...
    (first,last,surface,hgs,...
    guiHandles,rig_handles,common_inputs, displayTextSpace)
%global acc;
TOP=1;
FRONT=2;
RIGHT=3;
EDGE1=1;
DIAG=2;
EDGE3=3;

% get the handles of childrens in the uiPanel, and find out the handle of
% the "redo point" button
hChildren = get(guiHandles.uiPanel,'Children');
for n = 1:length(hChildren)
    if (strcmp({get(hChildren(n),'String')},'Redo Point'))
        backButton = hChildren(n);
    end
end

%set gravity constants to Knee EE
comm(hgs,'set_gravity_constants','KNEE');

mode(hgs,'zerogravity','ia_hold_enable',0);
switch surface
    case TOP
        tilt_axes=[1 2];
    case FRONT
        tilt_axes=[1 3];
    case RIGHT
        tilt_axes=[2 3];
end
i=first;
orient=0;
orient_done=false;
while i<=last
    % collect data for points first to last
    %set up translation
    if i <= common_inputs.row_length  %%edge 1
        movement= (i-1)...
            *common_inputs.bal_trans(surface).move(EDGE1,:);
    elseif i > common_inputs.row_length  ...
            && i < (2*common_inputs.row_length )  %edge 2
        firstOnEdge=(common_inputs.row_length-1)...
            *common_inputs.bal_trans(surface).move(EDGE1,:);
        movement=firstOnEdge+(i-common_inputs.row_length)...
            *common_inputs.bal_trans(surface).move(DIAG,:);
    else %edge 3
        movement=-common_inputs.bal_trans(surface).move(EDGE3,:)...
            *(common_inputs.socket_per_surface+1-i);
    end
    if orient>0
        %this is the cycle thought the orientations
        sign=orient;
            tilt_index=1;
            if orient>2
                sign=orient-2;
                tilt_index=2;
            end
        %display the point on the button
            button_press=false;
            set(guiHandles.mainButtonInfo,...
                'String',sprintf...
                ('Press at point %s on %s side,%s %s ',...
                num2str(i),...
                char(common_inputs.sides(surface)),...
                char(common_inputs.orintation_text(sign)),...
                char(common_inputs.axis_names(tilt_axes(tilt_index)))),...
                'UserData',button_press,...
                'Callback',{@Return_press,guiHandles}...
                );
        %move Visual ball
            set(rig_handles.patch_handle_ball,...
                'vertices',transform_vertices(...
                rig_handles.Vprobe,...
                common_inputs.bal_one(surface,:)+ movement,...
                common_inputs.bal_rot((2*tilt_axes(tilt_index)+sign+1),:)...
                +common_inputs.bal_rot(surface,:)...
                )...
                );
       %wait for the button to be pushed
            BackFlag=false;
            pointNow.point=i;
            pointNow.orient=orient; %%orientation
            pointNow.Flag=BackFlag;
            set(backButton,'UserData',pointNow);
            % check if backbutton or main button was pushed
            while ~get(guiHandles.mainButtonInfo,'UserData')...
                    && ~BackFlag
                pause(0.1)
                newPoint=get(backButton,'UserData');
                BackFlag=newPoint.Flag;
            end
       %give back button the current values
            i=newPoint.point;
            orient=newPoint.orient; 
       %get average of multiple samples of normal(cartesian point)
            ball_info(1+orient,:)...
                =muilti_point_ave(common_inputs.samples,...
                hgs,common_inputs);
            
            %done collecting an orientation

    else
        %display the point on the button
        button_press=false;
        set(guiHandles.mainButtonInfo,...
            'String',sprintf...
            ('Press at point %s on %s side, normal to surface',...
            num2str(i), char(common_inputs.sides(surface))),...
            'UserData',button_press,...
            'Callback',{@Return_press,guiHandles}...
            );
        %move Visual ball
        set(rig_handles.patch_handle_ball,...
            'vertices',transform_vertices(...
            rig_handles.Vprobe,...
            common_inputs.bal_one(surface,:)+ movement,...
            common_inputs.bal_rot(surface,:))...
            );

        %wait for a button to be pushed
        BackFlag=false;
        pointNow.point=i;
        pointNow.orient=orient; %%orientation
        pointNow.first=first;
        pointNow.maxOrient=4;
        pointNow.Flag=BackFlag;
        set(backButton,'UserData',pointNow);
        % check if backbutton or main button was pushed
        while ~get(guiHandles.mainButtonInfo,'UserData')...
                && ~BackFlag
            pause(0.1);
            newPoint=get(backButton,'UserData');
            BackFlag=newPoint.Flag;
        end
        %give back button the current values
        i=newPoint.point;
        orient=newPoint.orient;
        %get average of multiple samples of normal(cartesian point)
        ball_info(1,:)=muilti_point_ave...
            (common_inputs.samples,hgs, common_inputs);
        %done collecting a point
    end % 1 point or orientation collected for

    %increment or end
    if ((surface == RIGHT)...
            ||(orient ...
            == 2*length(common_inputs.orintation_text))...
            )   && (~BackFlag)
        orient_done=true;
    elseif ~BackFlag
        orient=orient+1;
    end

    % save the ball info to the structure if orient_done=true
    if ~BackFlag && orient_done
        %save cartesian points in proper places in structure
        if i==1
            index = 1;
            edge=1;
            load_points(surface,edge,index,ball_info,common_inputs);
            index = common_inputs.row_length;
            edge=3;
            load_points(surface,edge,index,ball_info,common_inputs);
        elseif i < common_inputs.row_length
            index = i;
            edge = 1;
            load_points(surface,edge,index,ball_info,common_inputs);
        elseif i == common_inputs.row_length
            index = common_inputs.row_length;
            edge=1;
            load_points(surface,edge,index,ball_info,common_inputs);
            index = 1;
            edge=2;
            load_points(surface,edge,index,ball_info,common_inputs);
        elseif i > common_inputs.row_length  ...
                && i < (2*common_inputs.row_length -1)
            index = i+ 1 -common_inputs.row_length;
            edge = 2;
            load_points(surface,edge,index,ball_info,common_inputs);
        elseif i == 2*common_inputs.row_length-1
            index = common_inputs.row_length;
            edge=2;
            load_points(surface,edge,index,ball_info,common_inputs);
            index = 1;
            edge=3;
            load_points(surface,edge,index,ball_info,common_inputs);
        else
            index = i+ 2 -2*common_inputs.row_length;
            edge = 3;
            load_points(surface,edge,index,ball_info,common_inputs);
        end
        
        % test pivot variation after completing five orientation on each
        % socket
        nrow= size(ball_info,1);
        for ior=1:nrow
           dist(ior)=norm(ball_info(ior,:)-mean(ball_info,1));  %#ok<AGROW>
        end
        RMSPivotErr= sqrt(mean(dist.^2))*1000.0;   % Pivoting error in mm
        
        % check error and generate display text accordingly
        if RMSPivotErr < 1 % if error is smaller than 1 mm
            displayString= sprintf('Pivoting Variation(RMS): %8.4f mm',...
                                    RMSPivotErr);
            set(displayTextSpace,'String', displayString, 'Foregroundcolor','k');
        else
            displayString= sprintf(...
                 'Pivoting Variation(RMS): %8.4f mm, Please redo socket',...
                                    RMSPivotErr);
            set(displayTextSpace,'String', displayString, 'Foregroundcolor','r');
        end
        
        

        %increment the ball, initialize orientation, reset done
        i=i+1;
        orient=0;
        orient_done=false;
    end

end

end

%% return function
function Return_press(src,evt,guiHandles)  %#ok<INUSL>
button_press=true;
set(guiHandles.mainButtonInfo,...
    'UserData',button_press)
end


%% the function behind the back button

function redoPoint(a,b) %#ok<INUSD>
set(a,'background','green');
pause(0.2)
abc=get(a,'UserData');
abc.orient=abc.orient-1;
if abc.orient < 0
    abc.point=abc.point-1;
    if abc.point < abc.first
        new_point.point=abc.first;
        new_point.orient=0;
    else
        new_point.point=abc.point;
        new_point.orient=abc.maxOrient;
    end
else
    new_point.point=abc.point;
    new_point.orient=abc.orient;
end
new_point.Flag=true;
new_point.maxOrient=abc.maxOrient;
new_point.first=abc.first;
set(a,'UserData',new_point);
set(a,'BackgroundColor',[204 204 204]/255);
end



%% multipoint collection at a singe socket point
%returns the mean point and the max and
%min points from the mean
function [meanpp]...
    = muilti_point_ave(samp,hgs,common_inputs)

%collect loop
for i = 1:samp
    f2b=reshape(hgs.flange_tx,4,4)';
    ballA2Base=f2b*common_inputs.eeArray2flange;
    points(i,:)= [ballA2Base(1,4) ...
        ballA2Base(2,4) ballA2Base(3,4)];
end
%find mean point
meanpp= mean(points);   %(xmean ymean xmean)

end

%% populate the point collection structure

function []=load_points(...
    surface,edge,index,ball_info,common_inputs)
 global   acc; %#ok<NUSED>
%%%example of acc structure
%    acc.top.first_edge(3).orintation(2,:)=ball_info(m,:)
% [row,col]=size(ball_info);
[row]=size(ball_info);
for m = 1:row(1)
    eval(['acc.',common_inputs.sides{surface},'.'...
        ,common_inputs.edges{edge},'(',num2str(index),')'...
        ,'.orintation','(',num2str(m),',:)',...
        '=','ball_info(m,:);']);
end

end

%% find distances between sockets on a row
function [common_out]=block_length_fun...
    (surface,edge,dataFilename,common_inputs)
global acc block_length collecting;  %#ok<NUSED>
 if common_inputs.last_edge && collecting         
     robotName = common_inputs.robotName; %#ok<NASGU>
     save (dataFilename, 'acc','robotName');
 end

AllsocketsSum=common_inputs.AllsocketsSum;
AllLengthSum=common_inputs.AllLengthSum;
SumIndex=common_inputs.SumIndex; 
line=common_inputs.line;
errors=common_inputs.errors;
%run through all balls on a row
for i=1:common_inputs.row_length
    %collect all data for the socket

    datai=eval(['acc.',common_inputs.sides{surface},'.',...
        common_inputs.edges{edge},'(',num2str(i),')'...
        ,'.orintation']);
    centeri = mean(datai);
    
    if i==1
        centerone = mean(datai);
        [row]=size(datai);
    else
        for orient=1:row(1)
            %accuracy calculations
            distOne2orient(orient)...
                =norm(datai(orient,:)-centerone);
            lengthError(orient)...
                =distOne2orient(orient)...
                - common_inputs.nom_lengths(line,i-1);
            errors(i,orient...
                +common_inputs.row_length*(line-1))...
                =distOne2orient(orient)...
                - common_inputs.nom_lengths(line,i-1);
            lengthErrorSqu(orient)...
                =lengthError(orient)^2;
            AllLengthSum= AllLengthSum + lengthErrorSqu(orient);
            %piviot calculations
            distCenter2Piv(orient)...
                =norm(datai(orient,:)-centeri);
            distCen2PivSqu(orient)...
                =distCenter2Piv(orient)^2;
            AllsocketsSum= AllsocketsSum ...
                + distCen2PivSqu(orient);
            SumIndex = SumIndex + 1;
        end
    end

end
%output sum index and AllsocketsSum
common_out.line=common_inputs.line+1;
common_out.SumIndex=SumIndex;
common_out.AllLengthSum=AllLengthSum;
common_out.AllsocketsSum=AllsocketsSum;
common_out.errors=errors;
end


