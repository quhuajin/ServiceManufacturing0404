function [] = bbar_collect_data(hgs)
% BBAR_COLLECT_DATA Gui is used to collect ball-bar data for
% kinematic calibaration
%
% Syntax:
%   bbar_collect_data(hgs)
%       This will start  the user interface for ball-bar data collection
%
% Notes:
%   This script requires the hgs_robot object as input argument, i.e. a
%   connection to robot must be established before running this script.
%
% See also:
%   hgs_robot, home_hgs, phase_hgs
%
%
% $Author: dmoses $
% $Revision: 2231 $
% $Date: 2010-07-06 14:05:39 -0400 (Tue, 06 Jul 2010) $
% Copyright: MAKO Surgical corp (2008)
%

% Checks for arguments if any.  If none connect to the default robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

%% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: argument must be an hgs_robot object');
end


ballLocation = 1;
startCollection = 0;
angleUpdateTimer = [];
%ballbar data structure  initializations:
bbarData.dof = hgs.JE_DOF;
bbarData.nominalFlangeTransform = reshape(hgs.NOMINAL_FLANGE_TRANSFORM, 4, 4)';
bbarData.nominalDH_Matrix = reshape(hgs.NOMINAL_DH_MATRIX,4, bbarData.dof)';
bbarData.lbb = 0;
bbarData.basePos = [];
bbarData.baseBall = [];
bbarData.data(1).location = [hgs.CALIB_BALL_A]';
bbarData.data(2).location = [hgs.CALIB_BALL_B]';
bbarData.data(3).location = [hgs.CALIB_BALL_C]';
bbarData.data(1).je_angles = [];
bbarData.data(2).je_angles = [];
bbarData.data(3).je_angles = [];
%we assume there are only 3 calibration balls, but try for the 
%forth ball (ball D) in case there is 1.x or earlier version of 2.0
%robot
try
  ball_D = [hgs.CALIB_BALL_D]';
catch
  ball_D = [];
end
if ~isempty(ball_D)
  bbarData.data(4).location = ball_D; 
  bbarData.data(4).je_angles = [];
  radialErr = cell(1,4);
else
  radialErr = cell(1,3);
end

%% Setup Script Identifiers for generic GUI
scriptName = 'Ball-bar Data Collection';

% Create generic Mako GUI
guiHandles = generateMakoGui(scriptName,[],hgs, 1);

% use own callback for cancel button
changeCancelBtnCallBck;

set(guiHandles.figure,...
    'CloseRequestFcn',@closeCallBackFcn);

% Setup the main function
updateMainButtonInfo(guiHandles,'pushbutton',@startScript);
          
% Add axis for EE image
guiHandles.axis = axes('parent', guiHandles.extraPanel, ...
                       'XGrid','off','YGrid','off','box','off','visible','off');

defaultColor = get( guiHandles.uiPanel, 'BackgroundColor');

% load sounds for use later
% tinyBeep = wavread(fullfile('Sounds','tinybeep.wav'));

% Add initial UI components.
commonProperties = struct(...
    'Style','text',...
    'HorizontalAlignment', 'left', ...
    'Units','Normalized',...
    'BackgroundColor',defaultColor,...
    'FontWeight','normal',...
    'FontUnits','normalized',...
    'FontSize',0.6,...
    'SelectionHighlight','off',...
    'Visible','off'...
    );
guiHandles.CALEESerialNumberLabel = uicontrol(guiHandles.uiPanel,...
                                    commonProperties,...
                                    'Position',[0.1, 0.75 0.8 0.05],...
                                    'String','Calibration EE Serial Number');
guiHandles.CALEESerialNumberText = uicontrol(guiHandles.uiPanel,...
                                    commonProperties,...
                                    'BackgroundColor','white',...
                                    'Position',[0.1, 0.65 0.8 0.1],...
                                    'String',hgs.CALEE_SERIAL_NUMBER);
guiHandles.CALBARSerialNumberLabel = uicontrol(guiHandles.uiPanel,...
                                    commonProperties,...
                                    'Position',[0.1, 0.4 0.8 0.05],...
                                    'String','Calibration Bar Serial Number');
guiHandles.CALBARSerialNumberText = uicontrol(guiHandles.uiPanel,...
                                    commonProperties,...
                                    'BackgroundColor','white',...
                                    'Position',[0.1, 0.3 0.8 0.1],...
                                    'String',hgs.CALBAR_SERIAL_NUMBER);
                                
guiHandles.EE_Ball =   uicontrol(guiHandles.extraPanel,...
                                commonProperties,...
                                 'BackgroundColor', 'white',...
                                 'FontSize',0.7,...
                                 'Position',[0.1 0.85 0.8 0.1],...
                                 'String', 'Calib EE Ball: A');       
str = sprintf('Robot Configuration: %s','---');
guiHandles.baseB_Location  =   uicontrol(guiHandles.uiPanel,...
                                         commonProperties,...
                                         'FontSize',0.8,...
                                         'Position',[0.05 0.9 0.9 0.05],...
                                         'String', str);       

str = sprintf('Ball-bar length [mm]: %s',...
              sprintf('  %3.3f',  hgs.BALLBAR_LENGTH_1*1000));

guiHandles.bbar_Length  =   uicontrol(guiHandles.uiPanel,...
                                      commonProperties,...
                                      'FontSize',0.8,...
                                      'Position',[0.05 0.85, 0.9 0.05],...
                                      'String', str);

guiHandles.radial_err_S = uicontrol(guiHandles.uiPanel,...
                                      commonProperties,...
                                      'FontSize',0.8,...
                                      'Position',[0.05 0.6 0.6 0.1],...
                                      'BackgroundColor', defaultColor,...
                                      'String', sprintf('Radial error [mm]:'));
       
guiHandles.radial_err_D = uicontrol(guiHandles.uiPanel,...
                                      commonProperties,...
                                      'HorizontalAlignment', 'Right', ...
                                      'FontSize',0.8,...
                                      'Position',[0.65 0.6 0.3 0.1],...
                                      'String', sprintf('%6.3f', 0),...
                                      'visible', 'off');

 guiHandles.RMS_S = uicontrol(guiHandles.uiPanel,...
                           commonProperties,...
                           'FontSize',0.8,...
                           'Position',[0.05 0.5 0.45 0.1],...
                           'String', sprintf('RMS [mm]:'),...
                           'visible', 'off' );
 guiHandles.RMS_D = uicontrol(guiHandles.uiPanel,...
                           commonProperties,...
                           'HorizontalAlignment', 'Right', ...
                           'FontSize',0.8,...
                           'Position',[0.5 0.5 0.45 0.1],...
                           'String','---',...
                           'visible', 'off' );

guiHandles.nextBallBtn = uicontrol(guiHandles.uiPanel,...
                                   'Style','pushbutton',...
                                   'Units','Normalized',...
                                   'FontWeight','bold',...
                                   'FontUnits','normalized',...
                                   'FontSize',0.4,...
                                   'SelectionHighlight','off',...
                                   'Position',[0, 0.12, 0.32 0.1],...
                                   'BackgroundColor',defaultColor,...   
                                   'Callback','',...
                                   'String', 'Next Calib EE Ball', ...
                                   'Callback',@nextBall,...
                                   'Enable','off',...
                                   'visible', 'off');


guiHandles.eraseBtn = uicontrol(guiHandles.uiPanel,...
                                'Style','pushbutton',...
                                'Units','Normalized',...
                                'FontWeight','bold',...
                                'FontUnits','normalized',...
                                'FontSize',0.4,...
                                'SelectionHighlight','off',...
                                'Position',[0.33, 0.12, 0.32 0.1],...
                                'BackgroundColor',defaultColor,...   
                                'Callback',@erasePose,...
                                'String', 'Erase Pose', ...
                                'Enable','off',...
                                'visible', 'off');

guiHandles.getDataBtn = uicontrol(guiHandles.uiPanel,...
                                  'Style','pushbutton',...
                                  'Units','Normalized',...
                                  'FontWeight','bold',...
                                  'FontUnits','normalized',...
                                  'FontSize',0.4,...
                                  'SelectionHighlight','off',...
                                  'Position',[0.66, 0.12, 0.32 0.1],...
                                  'BackgroundColor',defaultColor,...   
                                  'Callback',@collectData,...
                                  'String', 'Record Pose', ...
                                  'Enable','off',...
                                  'visible', 'off');

guiHandles.eraseAllBtn = uicontrol(guiHandles.uiPanel,...
                                   'Style','pushbutton',...
                                   'HorizontalAlignment', 'Left', ...
                                   'Units','Normalized',...
                                   'FontWeight','bold',...
                                   'FontUnits','normalized',...
                                   'FontSize',0.4,...
                                   'SelectionHighlight','off',...
                                   'Position',[0.0, 0.0, 0.45 0.1],...
                                   'BackgroundColor',defaultColor,...   
                                   'Callback',@eraseAll,...
                                   'String', 'Clear All Poses', ...
                                   'Enable','off',...
                                   'visible', 'off');

guiHandles.writeToFileBtn = uicontrol(guiHandles.uiPanel,...
                                      'Style','pushbutton',...
                                      'Units','Normalized',...
                                      'HorizontalAlignment', 'Right', ...
                                      'FontWeight','bold',...
                                      'FontUnits','normalized',...
                                      'FontSize',0.4,...
                                      'SelectionHighlight','off',...
                                      'Position',[0.55, 0.0, 0.45 0.1],...
                                      'BackgroundColor',defaultColor,...   
                                      'Callback',@writeToFile,...
                                      'String', 'Write output file', ...
                                      'Enable','off',...
                                      'visible', 'off');
%create local copy of base ball postion
base_ball_right_calib = hgs.BASEBALL_RIGHT_CALIB';
base_ball_left_calib = hgs.BASEBALL_LEFT_CALIB';
bbarData.basePos = base_ball_left_calib;

%------------------------------------------------------------------------------
% Callback function to start the script
%------------------------------------------------------------------------------
    function startScript(varargin)
        
        % Ask user to confirm the serial number, and if so continue to data
        % collection
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Click to confirm SERIAL NUMBERS below',...
            @collectData);
        
        % Show the serial number
        set(guiHandles.CALEESerialNumberText,'Visible','on');
        set(guiHandles.CALEESerialNumberLabel,'Visible','on');
        set(guiHandles.CALBARSerialNumberText,'Visible','on');
        set(guiHandles.CALBARSerialNumberLabel,'Visible','on');
        
    end
                                  
%------------------------------------------------------------------------------
% Callback function to collect data
%------------------------------------------------------------------------------

    function collectData(varargin)
        % first disable the guiHandles.mainButtonInfo and emphasize the
        % text
        if  startCollection == 0,
            startCollection =1;
            hndls = [...
                guiHandles.CALEESerialNumberLabel,...
                guiHandles.CALEESerialNumberText,...
                guiHandles.CALBARSerialNumberLabel,...
                guiHandles.CALBARSerialNumberText];
            set(hndls, 'Enable','off', 'visible','off');
           
           hndls = [guiHandles.EE_Ball, guiHandles.baseB_Location , ...
                    guiHandles.bbar_Length,  guiHandles.radial_err_S, ...
                    guiHandles.radial_err_D, ...
                    guiHandles.RMS_S, guiHandles.RMS_D,  ...
                    guiHandles.nextBallBtn, guiHandles.eraseBtn, ...
                    guiHandles.getDataBtn, ...
                    guiHandles.eraseAllBtn, guiHandles.writeToFileBtn];
           set(hndls, 'visible','on', 'Enable', 'on');
           set(guiHandles.eraseBtn,'Enable', 'off');
           set(guiHandles.eraseAllBtn,'Enable', 'off');
           set(guiHandles.extraPanel,'BackgroundColor','white');

           bbarData.lbb = hgs.BALLBAR_LENGTH_1;

           str = sprintf('Ball-bar length [mm]: %s',...
                           sprintf('  %3.3f', ...
                                    bbarData.lbb*1000));
           set(guiHandles.bbar_Length,'string',str);
           showCallEE();
           %create a timer object to shown joint angles
           angleUpdateTimer = timer(...
               'TimerFcn',@updateAnglesAndError,...
               'Period',0.2,...
               'ObjectVisibility','off',...
               'BusyMode','drop',...
               'ExecutionMode','fixedSpacing'...
               );
           %start timer
           start(angleUpdateTimer)
           dataLength = 0;
           %finally switch to gravity mode:
           %mode(hgs,'home_mako');
           mode(hgs,'zerogravity','ia_hold_enable',0);
        else
           %sound(tinyBeep);
           [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
           
           bbarData.data(ballLocation).je_angles = ...
               [bbarData.data(ballLocation).je_angles; ...
                               joint_angles];
           %compute radial error
           currentRadialErr = computeRadialErr(flange_tx);
           radialErr{ballLocation}  = [ radialErr{ballLocation}; ...
                               currentRadialErr];
           %update RMS
           updateRMS;
           dataLength = size(bbarData.data(ballLocation).je_angles,1);           
        end
        updateMainButtonInfo(guiHandles,...
                          sprintf('Number of Poses: %d', ...
                                  dataLength ));
        if (dataLength >0)
          set(guiHandles.eraseBtn,'Enable', 'on');
          set(guiHandles.eraseAllBtn,'Enable', 'on');
        end

    end
%------------------------------------------------------------------------------
% Callback function to erase last recorded pose.
%------------------------------------------------------------------------------
  function  erasePose(varargin)
    dataLength = size(bbarData.data(ballLocation).je_angles,1);  
    %if there are data available clear the last data;
    if dataLength > 0 
      bbarData.data(ballLocation).je_angles(dataLength,:) = [];
      radialErr{ballLocation}(end) = [];
      dataLength = dataLength -1;
    end
    updateRMS;
    % disable button if there is no Data available
    if dataLength == 0
      set(guiHandles.eraseBtn,'Enable', 'off');
      set(guiHandles.eraseAllBtn,'Enable', 'off');
    end
    updateMainButtonInfo(guiHandles,sprintf('Number of Poses: %d', ...    
                                                   dataLength));
    changeFocus;
  end
%------------------------------------------------------------------------------
% Callback function to erase All recorded poses.
%------------------------------------------------------------------------------
  function  eraseAll(varargin)
         updateMainButtonInfo(guiHandles,'Number of Poses: 0');
         bbarData.data(ballLocation).je_angles = [];
         radialErr{ballLocation} = [];
         updateRMS;
         set(guiHandles.eraseBtn,'Enable', 'off');
         set(guiHandles.eraseAllBtn,'Enable', 'off');
         changeFocus;
   end
%------------------------------------------------------------------------------
% Callback function to write collected data to file
%------------------------------------------------------------------------------
    function  writeToFile(varargin)
  
      % check if there is a specific directory specified for all the reports
      % this is specified by MAKO_REPORTS_DIR environment variable
      % if not specified on windows use the desktop directory and on linux use
      % the tmp directory
          %Determine if the collected data is for lefty or righty configuration
          j3 = [];
          %stack all joint 3 data to find lefty/righty
          for i=1: size(bbarData.data,2),
              % make sure for the current Calib EE Ball there is data available
              if ~isempty(bbarData.data(i).je_angles)
                  j3 = [j3;  bbarData.data(i).je_angles(:,3)]; %#ok<AGROW>
              end
          end
           numPosJ3 = length(find(j3>0));
           numNegJ3 = length(find(j3<0));
           
           %first stop and delete gui update timer function, 
           %since data collection is done           
           if ~isempty(angleUpdateTimer)
               stop(angleUpdateTimer);
               delete(angleUpdateTimer);
           end;
           
           %if most of the data has negative j3 angle then robot is in
           %righty configuration,  otherwise it's lefty
           if numNegJ3 > numPosJ3
               bbarData.baseBall = 'BASEBALL_RIGHT_CALIB';
               bbarData.basePos = hgs.NOMINAL_BASEBALL_RIGHT_CALIB';
               robotPose = 'righty';
               set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                            'RIGHTY']);
           else
               bbarData.baseBall = 'BASEBALL_LEFT_CALIB';
               bbarData.basePos = hgs.NOMINAL_BASEBALL_LEFT_CALIB';
               robotPose = 'lefty';
               set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                            'LEFTY']);
           end          
           unitName = hgs.name;
           if isempty(getenv('ROBOT_BBAR_ORIG'))
               if ispc
                   baseDir = fullfile(getenv('USERPROFILE'),'Desktop');
               else
                   baseDir = tempdir;
               end
               dirName  = fullfile(baseDir,...
                                   [unitName,'-bbar-Data']);
           else
               dirName = getenv('ROBOT_BBAR_ORIG');
           end
           if (~isdir(dirName))
               mkdir(dirName);
           end
           fileName = sprintf('%s-%s-%s-%s',...
                              'bbar', robotPose, unitName, ...
                              datestr(now,'yyyy-mm-dd-HH-MM-SS'));
           fullFileName = fullfile(dirName, fileName);
           try 
               save(fullFileName, 'bbarData');
               resultStr{1} = sprintf('File is saved to:');
               resultStr{2} = sprintf('%s', fullFileName);
               presentMakoResults(guiHandles,'SUCCESS',resultStr);
               set([guiHandles.writeToFileBtn, ...
                    guiHandles.nextBallBtn, guiHandles.eraseBtn, ...
                    guiHandles.getDataBtn, ...
                    guiHandles.eraseAllBtn, ...
                    guiHandles.writeToFileBtn],'Enable','off')
           catch
               resultStr{1} = sprintf('Save was not successful');
               resultStr{2} = lasterr;
               presentMakoResults(guiHandles,'FAILURE', resultStr);
           end

           set(guiHandles.mainButtonInfo, 'FontSize',0.12);

       end
%------------------------------------------------------------------------------
% Callback function for switching to next calibration Calib EE Ball
%------------------------------------------------------------------------------
function nextBall(varargin)
      ballLocation = ballLocation + 1;
      %if ballLocation is larger than available number of cal balls then reset.
      if ballLocation > size(bbarData.data,2)
         ballLocation = 1;
      end
      dataLength = size(bbarData.data(ballLocation).je_angles,1);
      set(guiHandles.mainButtonInfo,'String',...
                        sprintf('Number of Poses: %d', ...
                                dataLength ));
      if dataLength > 0
        set(guiHandles.eraseBtn,'Enable', 'on');
        set(guiHandles.eraseAllBtn,'Enable', 'on');
      else
        set(guiHandles.eraseBtn,'Enable', 'off');
        set(guiHandles.eraseAllBtn,'Enable', 'off');
      end
      showCallEE();
      changeFocus;
    end
%------------------------------------------------------------------------------
% Internal function to show the emage of the current calibration Calib EE Ball
%------------------------------------------------------------------------------
    function showCallEE()
        EE_BallString = {'Calib EE Ball: A',...
            'Calib EE Ball: B',...
            'Calib EE Ball: C',...
            'Calib EE Ball: D'};
        % if only 3 calibration balls available we assume new calibaration EE
        if size(bbarData.data,2) == 3,
            imageEE = {'eeBall_2_0_A.jpg','eeBall_2_0_B.jpg', ...
                'eeBall_2_0_C.jpg'};
        else
            imageEE = {'eeball_A.jpg', 'eeball_B.jpg', 'eeball_C.jpg', ...
                'eeball_D.jpg'};
        end
        imageFile = fullfile('robot_images',imageEE{ballLocation});
        set(guiHandles.EE_Ball, 'string', ...
            EE_BallString{ballLocation});
        eeImg = imread(imageFile);
        set(guiHandles.axis, 'NextPlot', 'replace');
        image(eeImg,'parent', guiHandles.axis);
        axis (guiHandles.axis, 'off')
        axis (guiHandles.axis, 'image')
        drawnow;
    end

%------------------------------------------------------------------------------
% Call back function to Change call back function for cancel button
%------------------------------------------------------------------------------  
  function [] = changeCancelBtnCallBck()
      frames = get(guiHandles.figure,'Children');
      % Search for the report generation frame
      for i=1:length(frames)
        if (strcmp(get(frames(i),'Title'),'Report Generation'))
          % Now look for the buttons in the report frame
          repButtonList = get(frames(i),'Children');
          break;
        end
      end
      % Now search the buttons for the cancel button
      for i=1:length(repButtonList)
        if strcmp(get(repButtonList(i),'string'),'Cancel')
          set(repButtonList(i),...
              'Callback', @closeCallBackFcn,...
              'String','Cancel');
        end
      end
  end
%------------------------------------------------------------------------------
% Update function for timer object
%------------------------------------------------------------------------------
function []= updateAnglesAndError(varargin)
    
    [joint_angles, flange_tx] = get(hgs,'joint_angles','flange_tx');
    
    %update info about robot's lefty/righty configuration
    %based on J3 joint angle
    if joint_angles(3) < 0
        set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                            'RIGHTY']);
        bbarData.basePos = base_ball_right_calib;
    else
        set(guiHandles.baseB_Location,'String', ['Robot Configuration: ' ...
                            'LEFTY']);
        bbarData.basePos = base_ball_left_calib;
    end
    

    %compute radial error
    currentRadialErr = computeRadialErr(flange_tx);
    set(guiHandles.radial_err_D, 'String', ...
        sprintf('%6.3f', currentRadialErr*1000));
    
    drawnow;
  end
  
%------------------------------------------------------------------------------
% This Internal function computes radial error
%------------------------------------------------------------------------------
  function rdlErr = computeRadialErr(flange_tx)
    flange_tx = reshape(flange_tx,4,4)';
    ballPos_wrt_base = flange_tx(1:3, 1:3) * ...
        bbarData.data(ballLocation).location + flange_tx(1:3,4);
    rdlErr =  norm (ballPos_wrt_base -  bbarData.basePos) - ...
        bbarData.lbb;
    end
%------------------------------------------------------------------------------
% This Internal function computes RMS error
%------------------------------------------------------------------------------
    function [] = updateRMS()
        lgData = 0;
        sumSqr = 0;
        for k=1:size(radialErr,2)
            lgData =  lgData + length(radialErr{k});
            sumSqr = sumSqr + sum(radialErr{k}.^2) ;
        end
        if lgData >0
            rms = sqrt(sumSqr/lgData);
            set(guiHandles.RMS_D, ...
                'String', sprintf('%6.3f', rms*1000) );
        else
            set(guiHandles.RMS_D, ...
                'String','---');
        end
    end
%------------------------------------------------------------------------------
% Call back function to close the gui
%------------------------------------------------------------------------------
  function changeFocus(varargin)
    uicontrol(guiHandles.mainButtonInfo);
  end
%------------------------------------------------------------------------------
% Call back function to close the gui
%------------------------------------------------------------------------------
  function closeCallBackFcn(varargin)
    if  ~isempty(angleUpdateTimer)
       stop(angleUpdateTimer);
       delete(angleUpdateTimer);
    end
    closereq;
  end
end


% --------- END OF FILE ----------
