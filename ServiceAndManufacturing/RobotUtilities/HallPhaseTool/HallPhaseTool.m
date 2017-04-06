function HallPhaseTool(hgs)
%HALLPHASECHECK Gui to help perfrom motor phasing check
%
% Syntax:
%   HALLPHASECHECK(hgs)
%       This script verifies motor phasing by comparing electrical phase
%       angle of each motor against the theoretical value of phase angle
%       at each hall transition.  User manually rotates the joint(s) of
%       interest and observes the hall status.
%
%
% Notes:
%   This script requires the hgs_robot to see if the homing is
%   performed or not. The script can only be used with robots equipped
%   with  2.x Mako CPCI motor controller hardware. .
%
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home_hgs,
%   phase_hgs, phasing_check
%

% 
% $Author: jforsyth $
% $Revision: 3175 $
% $Date: 2013-08-20 18:09:03 -0400 (Tue, 20 Aug 2013) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

angleUpdateTimer = [];

% Setup Script Identifiers for generic GUI
scriptName = 'Hall vs Electrical Angles';
guiHandles = generateMakoGui(scriptName,[],hgs);
log_message(hgs,'Hall Phase Tool Started');

% Setup the main function
set(guiHandles.mainButtonInfo,...
    'CallBack',@mainProcedure);
set(guiHandles.figure,...
    'CloseRequestFcn',@closeCallBackFcn);


jeDof = hgs.JE_DOF;
cpr = hgs.ME_COUNTS_PER_REVOLUTION;

xMin = 0.1;
xRange = 0.8;
yMin = 0.2;
yRange = 0.10;
spacing = 0.02;

commonBoxProperties = struct(...
    'Style','edit',...
    'Units','Normalized',...
    'FontWeight','bold',...
    'FontUnits','normalized',...
    'FontSize',0.4,...
    'SelectionHighlight','off',...
    'Enable','Inactive');

for i=1:jeDof
    boxPosition = [xMin+(xRange+spacing)*(i-1)/jeDof,...
        yMin+spacing,...
        xRange/jeDof-spacing,...
        yRange];
    AngleBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'Position',boxPosition,...
        'String',sprintf('%5.2f', 0)); %#ok<AGROW>
    uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...,
        'style', 'text',...
        'Position',boxPosition+[0 .12 0 -0.05],...
        'String',sprintf('M%d Elec. Angle (deg)',i));%%#ok<AGROW>
    HallBox(i) = uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...
        'Position',boxPosition+[0 .22 0 0],...
        'String',sprintf('%5.2f', 0)); %#ok<AGROW>
    uicontrol(guiHandles.uiPanel,...
        commonBoxProperties,...,
        'style', 'text',...
        'Position',boxPosition+[0 .32 0 -0.05],...
        'String',sprintf('M%d Hall',i));%%#ok<AGROW>
        
%         phaseErr(i) = uicontrol(guiHandles.uiPanel,...
%         commonBoxProperties,...
%         'Position',boxPosition+[0 .42 0 0],...
%         'String',sprintf('%1d', 0)); %#ok<AGROW>
%         
%         uicontrol(guiHandles.uiPanel,...
%           commonBoxProperties,...
%           'style', 'text',...
%           'Position',boxPosition+[0 .52 0 -0.05],...
%           'String',sprintf('M%d Phase Error',i)); %#ok<AGROW>
      
        phaseErrLatched(i) = uicontrol(guiHandles.uiPanel,...
                                       commonBoxProperties,...
                                       'Foregroundcolor','red',...
                                       'FontSize',0.2,...                               
                                       'Position',boxPosition+[0 .62 0 0],...
                                       'String',''); %#ok<AGROW>
        
        uicontrol(guiHandles.uiPanel,...
                  commonBoxProperties,...
                  'style', 'text',...
                  'Position',boxPosition+[0 .72 0 -0.05],...
                  'String',sprintf('M%d Latched Error',i)); %#ok<AGROW>
end
dt = 25;
lmin = [30, 150, 90, 270 330 210];
lmax = [90, 210, 150, 330, 30, 270];
emin = lmin - dt;
emax = lmax + dt;
%h=uicontrol('style', 'slider','min', 0.0, 'max', 30.0, 'value', 25)
phaseAngleLimitSlider = uicontrol(guiHandles.uiPanel, ...
                                  'Units','Normalized',...
                                  'Position', [0.62 0.1 0.2 0.03],...
                                  'Style', 'slider', ...
                                  'Min', 0.0, ...
                                  'Max', 30.0, ...
                                  'Value', 25.0, ...
                                  'SliderStep', [1/60, 1/15], ... 
                                  'CallBack', @setLimits);
dt =get( phaseAngleLimitSlider, 'value');

phaseAngleLimitText = uicontrol(guiHandles.uiPanel,...
                                commonBoxProperties,...
                                'Position', [0.69 0.13 0.05 0.03],...
                                'Style', 'text', ...
                                'FontSize',0.7, ...        
                                'String', sprintf('%3.1f',dt));

phaseAngleLimit = uicontrol(guiHandles.uiPanel,...
                            commonBoxProperties,...
                            'Position', [0.62 0.07 0.2 0.03],...
                            'HorizontalAlignment', 'center', ...
                            'style', 'text', ...
                            'FontSize',0.7, ...                 
                            'String', '+/- acceptable phase (deg)');

clearBtn = uicontrol(guiHandles.uiPanel, ...
                     commonBoxProperties, ...
                     'Position', [0.2 0.09 0.1 0.05], ...
                     'Style', 'pushbutton', ...
                     'CallBack', @clearFault, ...
                     'Enable', 'off', ...
                     'String', 'Clear Fault');

%create a timer object to shown joint angles
angleUpdateTimer = timer(...
    'TimerFcn',@updateAnglesAndError,...
    'Period',0.05,...
    'ObjectVisibility','off',...
    'BusyMode','drop',...
    'ExecutionMode','fixedSpacing'...
    );

    function setLimits(hObject,varargin)
       dt = get(hObject,'value');
       emin = lmin - dt;
       emax = lmax + dt;
       set(phaseAngleLimitText,'String', sprintf('%3.1f',dt));
    end
    
    function clearFault(hObject,varargin)
        for i=1:jeDof
            set(phaseErrLatched(i),'String',' ');
        end
        set(clearBtn,'Enable','Off');
    end

    function mainProcedure(varargin)
    updateMainButtonInfo(guiHandles,'text',{'Hall 330-30=>5, 30-90=>1',...
                        '    90-150=>3, 150-210=>2', ...
                        '    210-270=>6, 270-330=>4'})
        %start timer
        start(angleUpdateTimer)
    end
    function resetAngles(varargin)
       updateAnglesAndError;
    end
        
    
    function [] = updateAnglesAndError(varargin)
        [elecAngle, halls, phase_err] = get(hgs,'phase_angle', 'hall_states', ...
                                                'phase_error');

        for i=1:jeDof
            elecAngle(i)= elecAngle(i) * 0.0109863281250; %angle in degree
            % conversion factor 360/36768
            set( AngleBox(i),  'String', ...
                sprintf('%4.1f', elecAngle(i)));
            set( HallBox(i),  'String', ...
                sprintf('%1d', halls(i)));
%             set( phaseErr(i),  'String', ...
%                 sprintf('%1d', phase_err(i)));

            bgColor = 'white';
            
            switch halls(i)
              case 1
                if elecAngle(i)<emin(1) ||  elecAngle(i)>emax(1),
                    bgColor = 'red';
                end
              case 2
                if elecAngle(i)<emin(2) ||  elecAngle(i)>emax(2),
                    bgColor = 'red';
                end
              case 3
                if elecAngle(i)<emin(3) ||  elecAngle(i)>emax(3),
                    bgColor = 'red';
                end
              case 4
                if elecAngle(i)<emin(4) ||  elecAngle(i)>emax(4),
                    bgColor = 'red';
                end
              case 5
                if elecAngle(i)<emin(5) &&  elecAngle(i)>emax(5),
                    bgColor = 'red';
                end
              case 6
                if elecAngle(i)<emin(6) ||  elecAngle(i)>emax(6),
                    bgColor = 'red';
                end
            end  
            if strcmp(bgColor, 'red')
                set(phaseErrLatched(i),'String',...
                                  sprintf('H:%d Ph:%4.1f',halls(i), ...
                                          elecAngle(i)));
                set(clearBtn,'Enable','On');
            end
            
            set(AngleBox(i), 'BackgroundColor', bgColor) 
                       
         % tmp = mod((hgs.motor_encoder(i)-
         % hgs.PHASING_INFORMATION(i))/cpr(i),1);
         % set(motorAngle(i), 'String',...
         % sprintf('%4.1f', mod(tmp*6,1)*360));
        end
        
    end
%------------------------------------------------------------------------------
% Call back function to close the gui
%------------------------------------------------------------------------------
    function closeCallBackFcn(varargin)
         if  ~isempty(angleUpdateTimer)
              stop(angleUpdateTimer);
              delete(angleUpdateTimer);
         end
         log_message(hgs,'Hall Phase Tool Closed');
         closereq;
    end
end



% --------- END OF FILE ----------
