function motor_bandwidth_test(hgs)
%MOTOR_BANDWIDTH_TEST Gui to help perform closed-loop bandwidth calculation or
%  current loop tuning.
%
% Syntax:
%   MOTOR_BANDWIDTH_TEST(hgs)
%       This script measures and verifies motor current loop bandwidth. It
%       will calculate motor bandwidth for each motor and verifies if the
%       minimum bandwidth requirement are met.
%
%
% Notes:
%   This script requires the hgs_robot to see if the homing is
%   performed or not. The script can only be used with robots equipped
%   with  2.x Mako CPCI motor controller hardware.
%
%
% See also:
%   hgs_robot, hgs_robot/mode, hgs_robot/home_hgs,
%   curr_loop_hgs
%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% If no arguments are specified create a connection to the default
% hgs_robot
if nargin<1
    hgs = connectRobotGui;
    if isempty(hgs)
        return;
    end
end

ACCEPTABLE_BW = [800 1600 1600 1600 1600 1600];


% Checks for arguments if any
if (~isa(hgs,'hgs_robot'))
    error('Invalid argument: motor_bandwidth_test argument must be an hgs_robot object');
end

log_message(hgs,'Motor Bandwidth Script Started');
% Setup Script Identifiers for generic GUI with extra panel
scriptName = 'motor bandwidth test';
guiHandles = generateMakoGui(scriptName,[],hgs);
try
    %set gravity constants to Knee EE
    comm(hgs,'set_gravity_constants','KNEE');
    %figure/GUI fullscreen figures, use simple java to maximize the window
    set(get(guiHandles.figure,'JavaFrame'),'Maximized',true);

set(guiHandles.figure,...
    'CloseRequestFcn',@closeCallBackFcn);
    % Setup the main function
    set(guiHandles.mainButtonInfo,'CallBack', ...
                      @bandwidthProcedure)
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@bandwidth_close);
    
    %set degree of freedom parameters
    dof = hgs.ME_DOF;

    %initialize the phasing error to false
    isProcedureCanceled=false;
    % Setup boundaries for phasing  boxes
    xMin = 0.05;
    xRange = 0.9;
    yMin = 0.45;
    yRange = 0.15;
    spacing = 0.05;

    %define the common properties for all uicontrol
    commonBoxProperties = struct(...
        'Units','Normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'SelectionHighlight','off',...
        'Enable','Inactive');

    %add pushbuttons to show phasing status
    for j=1:dof %#ok<FXUP>
        boxPosition = [xMin+(xRange+spacing)*(j-1)/dof,...
            yMin,...
            xRange/dof-spacing,...
            yRange];
        motorBox(j) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','pushbutton',...
            'Position',boxPosition,...
            'FontSize',0.3,...
            'String',sprintf('M%d',j)); %#ok<AGROW>
        bwText(j) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','text',...
            'Position',boxPosition+[0 -0.15 0 0],...
            'FontSize',0.15,...
            'visible', 'off',...                  
            'String',sprintf('Bandwidth %4.0f Hz',0)); %#ok<AGROW>
    end

    %setup mainbutton and display message
    tmpStr = sprintf('Click here to start Motor Current Bandwidth Check');
    updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
    set(guiHandles.mainButtonInfo,'FontSize',0.3);
    time_ = (0:255)*50e-6;
    meas_current_log = zeros(size(time_));
    ref_current_log = zeros(size(time_));
    calcBandwidthData.time = time_; 
    calcBandwidthData.ref_current = zeros(dof, length(ref_current_log));
    calcBandwidthData.meas_current = zeros(dof, length(meas_current_log));

    tuningMotor = 1;
    currentValue  = 0.5;
    frequencyValue = 500;
    KpValue = hgs.CURRENT_LOOP_KP;
    KiValue = hgs.CURRENT_LOOP_KI;
    useSine = 1;
    meas_current_log = zeros(size(time_));
    ref_current_log = zeros(size(time_));
    
catch
    %phase error handling
    check_motor_current_bandwidth_error();
end

%--------------------------------------------------------------------------
% internal function: Main function for phasing
%--------------------------------------------------------------------------
    function bandwidthProcedure(varargin)       
        try
            %guide user to enable arm
            robotFrontPanelEnable(hgs,guiHandles);
            
            passBWCheck = zeros(1,dof);
            stop(hgs);
            pause(0.25);
            %put the arm in zero gravity, notice this is using the nominal
            %gravity constants and homing constants.
            mode(hgs,'current_tuning','motor_current', ...
                 currentValue, 'use_sine', useSine,'motor_number', ...
                 tuningMotor-1, 'freq_input',frequencyValue, ...
                 'current_loop_kp_float', KpValue(tuningMotor), ...
                 'current_loop_ki_float', KiValue(tuningMotor));
            for tuningMotor = 1:dof %#ok<FXUP>
                updateMainButtonInfo(guiHandles,'text',...
                                     sprintf('Checking motor current bandwidth for M%d',...
                                             tuningMotor));
                [bwFreq(tuningMotor), amp_dB(tuningMotor)] = calcBandwidth;  %#ok<AGROW>
                str = sprintf('Bandwidth %4.0f Hz', bwFreq(tuningMotor));
                set(bwText(tuningMotor), 'String', str, ...
                                  'Visible', 'On');
                if (bwFreq(tuningMotor) >= ACCEPTABLE_BW(tuningMotor) && ...
                    amp_dB(tuningMotor) ~= -1000)
                    set(motorBox(tuningMotor),'BackgroundColor', ...
                                      'green');
                    passBWCheck(tuningMotor) = 1;
                else
                    set(motorBox(tuningMotor),'BackgroundColor', 'red');
                    passBWCheck(tuningMotor) = 0;
                end
                pause(0.1);
            end
            
            if passBWCheck
                presentMakoResults(guiHandles,'SUCCESS',...
                                   'All motor current bandwidths within acceptable range');
                log_results(hgs,guiHandles.scriptName,'PASS',...
                    'Motor Bandwidth Test Successful');
            else
                k = 1;
                errorStr{1} =' ';
                for j = 1:dof %#ok<FXUP>
                    if amp_dB(j) == -1000
                        errorStr{k} = sprintf(['Motor (%d) Current ', ...
                                            'measurement too noisy'], ...
                                              j); %#ok<AGROW>
                        k = k+1;
                        continue;
                    elseif bwFreq(j) < ACCEPTABLE_BW(j)
                        errorStr{k} = sprintf(['Motor (%d) Bandwidth %4.0fHz ', ...
                                            '(limit %4.0fHz)'], j,...
                                              bwFreq(j), ACCEPTABLE_BW(j)); %#ok<AGROW>
                        k = k+1;
                    end
                end
                presentMakoResults(guiHandles,'FAILURE',...
                                   errorStr);
                log_results(hgs,guiHandles.scriptName,'FAIL',...
                            errorStr);
            end
            %Write data to File
            fileName =[sprintf('CurrentLoopBandwidth-%s-data-',hgs.name),...
                       datestr(now,'yyyy-mm-dd-HH-MM')];
            fullFileName=fullfile(guiHandles.reportsDir,fileName);
            save(fullFileName, 'calcBandwidthData');
        catch
            %update error joint button first            
            if(~isProcedureCanceled)
                set(motorBox(j),'BackgroundColor','red');
            end   
            %phase error handling
            check_motor_current_bandwidth_error();
            
            return;
        end
    end
%--------------------------------------------------------------------------
% internal function: calculating bandwidth
%--------------------------------------------------------------------------    
     function [freq, amp_dB] = calcBandwidth(varargin)
         for i=400:400:2500
            frequencyValue = i;
            amp_dB = getCurrentLog();
            if (amp_dB< -3.0103)
                break;
            end
        end
        if i==400
            startFreq = 300;
            endFreq = 500;
        else
            startFreq=i-400;
            endFreq=i+100;
        end
        for i=startFreq:50:endFreq
            frequencyValue = i;
            amp_dB = getCurrentLog();
            if (amp_dB< -3.0103)
                break;
            end
        end
        freq = frequencyValue;
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------       
    function amp_dB=getCurrentLog() 
        set(hgs,'current_tuning','motor_current', currentValue);
        set(hgs,'current_tuning','motor_number', tuningMotor-1);
        set(hgs,'current_tuning','freq_input', frequencyValue);
        set(hgs,'current_tuning','current_loop_kp_float', KpValue(tuningMotor));
        set(hgs,'current_tuning','current_loop_ki_float', KiValue(tuningMotor));
        set(hgs,'current_tuning','use_sine', useSine);
        amp_dB = zeros(12,1);
        
        pause(0.05);
        % we try to get currentlog several times in case there is a large
        % current noise.
        numOfSuccessFulMeasurements = 0;
        for k=1:12,
            set(hgs,'current_tuning','get_new_data', 1);
            while( hgs.current_tuning.data_ready ~= 1 )
                pause(0.2);
                % disp('waiting ...')
            end
            % data is ready plot data
            meas_current_log = hgs.current_tuning.meas_curr_data * 15/ 16777215;
            ref_current_log = hgs.current_tuning.ref_curr_data * 15 / 16777215;
            freqResp=get_freqResp(time_(:), meas_current_log(:), ...
                                                ref_current_log(:), ...
                                                frequencyValue);
            % if standard deviation on fitting is acceptable break
            if freqResp.stdAcceptable == 1
                numOfSuccessFulMeasurements = numOfSuccessFulMeasurements+1;
                amp_dB(numOfSuccessFulMeasurements) = freqResp.dB;
                if numOfSuccessFulMeasurements >= 4;
                    break;
                end
            end
        end
        
        calcBandwidthData.ref_current(tuningMotor,:) = ref_current_log;
        calcBandwidthData.meas_current(tuningMotor,:) = meas_current_log;
        if numOfSuccessFulMeasurements<3
            amp_dB = -1000; %-1000dB is used to indicate an unacceptable
                         %frequency Response calculation.
        else
            %use average value
            amp_dB = sum(amp_dB) / numOfSuccessFulMeasurements;
        end
    end
%--------------------------------------------------------------------------
% internal function: for calculating frequency response
%--------------------------------------------------------------------------   
    function freqResp=get_freqResp(t, y, u, freq)
        stdMax = max(u) * 0.2; % maximum threshold for standard
                                % deviation is set to 20% of amplitude
        psi = [cos(2*pi * t(:)*freq), -sin(2*pi*t(:)*freq) ones(length(t),1)];
        %sinusoidal curve fitting on output signal
        X = psi\y;
        phi_output = atan2(X(2), X(1));
        A_output = norm(X(1:2));
        e_out =(y-A_output*(cos(2*pi*t(:)*freq + phi_output) )-X(3) );
        
        %sinusoidal curve fitting on input
        X = psi\u;
        phi_input = atan2(X(2), X(1));
        A_input = norm(X(1:2));
        e_inp = (u-A_input*(cos(2*pi*t(:)*freq + phi_input) )-X(3) );
        amplitude_dB = 20*log10(A_output/A_input);
        
        if ( std(e_out) < stdMax ) && ( std(e_inp) < stdMax )
            freqResp.stdAcceptable = 1;
        else
            freqResp.stdAcceptable = 0;
        end
        freqResp.Ao = A_output;
        freqResp.Ai = A_input;
        freqResp.Po = phi_output;
        freqResp.Pi = phi_input;
        freqResp.dB = amplitude_dB;
        freqResp.Phase = (freqResp.Po - freqResp.Pi) * 180/pi;
        if (freqResp.Phase >0) 
            freqResp.Phase = freqResp.Phase - 360;
        end
        runPlot = false;
        if runPlot,
            h(1) = subplot(221);
            plot(t,y,t,A_output*(cos(2*pi*t(:)*freq + phi_output) ),'r.');
            h(2) = subplot(223);
            plot(t,e_out);
            title(num2str(norm(e_out)/sqrt(length(e_out))))
            h(3) = subplot(222);
            plot(t,u,t,A_input*(cos(2*pi*t(:)*freq + phi_input) ),'r.');
            h(4) = subplot(224);
            plot(t,e_inp);
            title(num2str(norm(e_inp)/sqrt(length(e_inp))))
            linkaxes(h, 'x')
        end
    end

  
%--------------------------------------------------------------------------
% internal function: close GUI, override the default cancel button callback
%--------------------------------------------------------------------------
    function bandwidth_close(varargin)
        %set phasing cancel flag
        isProcedureCanceled=true;
        log_message(hgs,'Motor Bandwidth Script closed');
        try
            mode(hgs,'zerogravity');
        catch
        end
        %close figures
        closereq;
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------
    function check_motor_current_bandwidth_error(errorMsg) %#ok<INUSD>
        %Process error and stop hgs
        bandwidth_error=lasterror;
        bandwidthErrorMessage=...
            regexp(bandwidth_error.message,'\n','split');
        if ~isProcedureCanceled
            presentMakoResults(guiHandles,'FAILURE',...
                bandwidthErrorMessage{2});
            log_results(hgs,guiHandles.scriptName,'FAIL',...
                            bandwidthErrorMessage{2});
            stop(hgs);
        end
    end
end


% --------- END OF FILE ----------
