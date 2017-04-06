function [phase_lag amplitude_ratio transmissiondata] = transmissioncheck_qip(varargin)
% TRANSMISSIONCHECK_QIP, check the cable tension at the Joint-level test
% (QIP 0202) for TGS 2.x
%
%   Syntax:
%       [phase_lag amplitude_ratio] = transmissioncheck_qip(galilObj,joint,basedir)
%       The script activates an oscillatory motor movement and measures the
%       phase angle lag and amplitude ratio between motor and joint oscillations
%
%       input:
%           galilObj: galil motor controller object in testing joint
%           joint: testing joint number
%           basedir: base directory
%       output:
%           phase_lag: phase angle difference between motor and joint
%           movements
%           amplitude_ratio: the ratio of the amplitude of joint to motor
%           movements

galilObj = varargin{1};
joint = varargin{2};
basedir = varargin{3};
testing=0;
saving=0;
plottrace=0;
if length(varargin)>3
    for n=4:length(varargin)
        if strcmpi(varargin{n},'test')
            testing=1;
        end
        if strcmpi(varargin{n},'save')
            saving=1;
        end
        if strcmpi(varargin{n},'PlotHandle')
            phandle=varargin{n+1};
            plottrace=1;
        end
        
    end
end

% load joint and motor configuration data
[MOTORDATA, JOINTDATA]= ReadJointConfiguration();

testpos = JOINTDATA.TRANSMISSION_POSE(joint);
freq    = JOINTDATA.TRANSMISSION_FREQ(joint);
amp     = JOINTDATA.TRANSMISSION_AMP(joint);
duration= JOINTDATA.TRANSMISSION_DURATION(joint);
gratio=   JOINTDATA.GRATIO(joint);
cpr_motor= MOTORDATA.CPR(joint);
cpr_joint= JOINTDATA.CPR(joint);

% Go to test position
goto_jointpos(galilObj,joint,testpos,basedir,MOTORDATA,JOINTDATA);

% Oscillate for Transmission test
oscillate(galilObj,freq,amp,duration)
pause(1);

% Calculate Transmission Test Results
calculate_results()

    function calculate_results()
        
        Arrays = get(galilObj,'arrays');
        s=size(Arrays.data);w=s(1);
        
        for x=1:w
            if strcmp(Arrays.var(x),'MPOS');
                transmissiondata.c_me_joint_angles=Arrays.data{x}/gratio/...
                    cpr_motor*2*pi;  % in radian
            end
            
            if strcmp(Arrays.var(x),'JPOS');
                transmissiondata.c_je_joint_angles=Arrays.data{x}/cpr_joint*2*pi;  % in radian
            end
            
            if strcmp(Arrays.var(x),'T');
                t=(Arrays.data{x}-Arrays.data{x}(1))/1000;
            end
            
            if strcmp(Arrays.var(x),'TIME');
                t=(Arrays.data{x}-Arrays.data{x}(1))/1000;
            end
        end

        % Drop the first second of data
        x=transmissiondata.c_je_joint_angles(501:end);
        y=transmissiondata.c_me_joint_angles(501:end);
        t=t(501:end);
        
        transmissiondata.t=t;
        transmissiondata.frequency=freq;
        transmissiondata.amplitude=amp;
        
        %% CALCULATE and PLOT
        
        Fs = 1/(t(2)-t(1)); % Sampling Frequency
        npts = length(t);
        
        % remove bias
        x = x - mean(x);
        y = y - mean(y);
        
        transmissiondata.c_je_joint_angles=x;
        transmissiondata.c_me_joint_angles=y;
        
        % take the FFT
        X=fft(x);
        Y=fft(y);
        
        XX=X;YY=Y;
        XX(1:10)=0; %ignore data below 4hz
        YY(1:10)=0; %ignore data below 4hz
        
        % Calculate the number of unique points
        NumUniquePts = ceil((npts+1)/2);
        
        freqlim=100;
        f = (0:NumUniquePts-1)*Fs/npts;
        
        % Plot External Figures
        if plottrace
            CyclesToShow=20;
            tmax=1+CyclesToShow/freq;
            plot(phandle,t,x,t,y);
            xlabel(phandle,'time (s)');
            legend(phandle,'Joint Angle',...
                'Motor-Joint Angle');
            xlim(phandle,[1 tmax]);
        end
        
        if testing
            CyclesToShow=20;
            tmax=1+CyclesToShow/freq;
            figure(1);
            plot(t,x,t,y);
            xlabel('time (s)');
            legend('Joint Angle',...
                'Motor-Joint Angle');
            xlim([1 tmax]);
            
            figure(2)
            subplot(211);
            plot(f,abs(X(1:NumUniquePts)));
            title('Joint Angle');
            xlim([0 freqlim]);
            subplot(212)
            plot(f,abs(Y(1:NumUniquePts)));
            title('Motor-Joint Angle')
            xlim([0 freqlim]);
            xlabel('frequency (Hz)');
            
            figure(3)
            subplot(211)
            plot(f,angle(X(1:NumUniquePts)));
            set(gca,'YTick',-pi:pi/2:pi)
            set(gca,'YTickLabel',{'-pi','-pi/2','0','pi/2','pi'})
            ylim(gca,[-pi pi]);
            title('Joint Angle');
            xlim([0 freqlim]);
            ylabel('phase (rad)');
            subplot(212)
            plot(f,angle(Y(1:NumUniquePts)));
            set(gca,'YTick',-pi:pi/2:pi)
            set(gca,'YTickLabel',{'-pi','-pi/2','0','pi/2','pi'})
            ylim(gca,[-pi pi]);
            title('Motor-Joint Angle');
            xlim([0 freqlim]);
            xlabel('frequency (Hz)');
            ylabel('phase (rad)');
        end
        
        
        % Determine the max value and max point.
        % This is where the sinusoidal
        % is located. See Figure 2.
        [mag_x idx_x] = max(abs(XX(1:NumUniquePts))); %#ok<NASGU>
        [mag_y idx_y] = max(abs(YY(1:NumUniquePts)));
        
        % determine the phase difference
        % at the maximum point.
        px = angle(X(idx_y)); %Calculate phase at the peak motor index
        py = angle(Y(idx_y)); %Calculate phase at the peak motor index
        phase_lag = py - px;
        
        % determine the amplitude scaling
        amplitude_ratio = max(x)/max(y);
        
        %% Log to transmissiondata structure
        transmissiondata.test_time=clock;
        transmissiondata.phase_lag=phase_lag;
        transmissiondata.amplitude_ratio=amplitude_ratio;
        transmissiondata.frequency_excite=freq;
        transmissiondata.frequency_m=f(idx_y);
        transmissiondata.frequency_m=f(idx_y);
        
        
        %% Setup Directory and Save
        if saving
            da=num2str(date);da=da(1:(length(da)-5));
            % savedir=['testdata\TransmissionDataGalil\' da '\'];
            savedir=['TransmissionDataGalil\' da '\'];
            if ~(exist(savedir,'dir'))
                mkdir(savedir);
            end
            
            num=length(dir([savedir 'TestJoint' num2str(joint) '*']));
            
            savfil=['TestJoint' num2str(joint) '_' num2str(num+1, '%0.3d')];
            savefile=[savedir savfil];
            save(savefile, 'transmissiondata')
                       
            disp(['TestJoint ' num2str(joint) '  '...
                num2str(freq) 'Hz  ' num2str(amp) 'amp' ...
                '   phase=' num2str(phase_lag) '(rad)= ' num2str(phase_lag/pi*180) '°' ...
                '   M/J=' num2str(amplitude_ratio) ...
                '   ' savfil]);
        else
            disp(['TestJoint ' num2str(joint) '  '...
                num2str(freq) 'Hz  ' num2str(amp) 'amp' ...
                '   phase=' num2str(phase_lag) '(rad)= ' num2str(phase_lag/pi*180) '°' ...
                '   M/J=' num2str(amplitude_ratio)]);
        end
        
    end

end
