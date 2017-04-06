function international_voltage_QIP

%INTERNATIONAL_VOLTAGE_QIP  Script to interface with the Behlman
%transformer to get different voltage and freqency settings
%
% Syntax:
%   international_voltage_qip
%
% Test Description:
%   This test will initiate communication with the Behlman transformer and
%   change the voltages and frequencies for the different countries to be
%   tested.  Following each test the user will be asked to type in the
%   values measured on the voltmeter.  The entered values will be tested to
%   verify the correct operation
%
% Notes
%   The script assumes the Behlman transformer is connected to serial port
%   COM1 and is set to remote
%

% $Author: dmoses $
% $Revision: 1946 $
% $Date: 2009-11-24 17:53:34 -0500 (Tue, 24 Nov 2009) $
% Copyright: MAKO Surgical corp 2007


% Initialize the GUI
guiHandles = generateMakoGui('International Voltage-Freq Check',[],[]);
updateMainButtonInfo(guiHandles,'pushbutton',@run_volt_freq_test);
set(guiHandles.figure,'CloseRequestFcn',@abort_volt_freq_test);

% Define the steps in the test
TEST_SEQUENCE = {...
    'INIT',...
    'JAPAN',...
    'CHANGE_OUTPUT_JAPAN',...
    'POWER_UP_RIO',...
    'UK',...
    'CHANGE_OUTPUT_UK',...
    'POWER_UP_RIO',...
    'US',...
    'CHANGE_OUTPUT_US',...
    'POWER_UP_RIO',...
    'TEST_COMPLETE'};

% Voltages and frequencies for various tests (volts, Hz)
US_VOLTAGE_FREQ = [120,60];
UK_VOLTAGE_FREQ = [240,50];
JAPAN_VOLTAGE_FREQ = [100,50];

VOLTAGE_TOLERANCE = 3; % volts

% Internal test variables
test_step = 1;
connectionId = [];

%-------------------------------------------------------------------------
% Function to run the volt and freq test
%-------------------------------------------------------------------------
    function run_volt_freq_test(varargin)
        try
            % Device Updates
            switch TEST_SEQUENCE{test_step}
                case 'INIT'
                    connectionId = initBehlman;
                    % turn off the outputs for safety
                    disableOutput(connectionId);
                    
                case 'CHANGE_OUTPUT_US'
                    setVoltageFreq(connectionId,US_VOLTAGE_FREQ);

                case 'CHANGE_OUTPUT_UK'
                    setVoltageFreq(connectionId,UK_VOLTAGE_FREQ);

                case 'CHANGE_OUTPUT_JAPAN'
                    setVoltageFreq(connectionId,JAPAN_VOLTAGE_FREQ);

                case 'POWER_UP_RIO'
                    enableOutput(connectionId);
                    
                case {'US','UK','JAPAN'}
                    disableOutput(connectionId);
                case 'TEST_COMPLETE'
                    presentMakoResults(guiHandles,'SUCCESS');
                    return;
                otherwise
                    disableOutput(connectionId);
            end

            % prepare GUI for the next step
            test_step = test_step+1;

            switch TEST_SEQUENCE{test_step}
                case 'CHANGE_OUTPUT_US'
                    confirmVoltageFreqReading(US_VOLTAGE_FREQ);

                case 'CHANGE_OUTPUT_UK'
                    confirmVoltageFreqReading(UK_VOLTAGE_FREQ);

                case 'CHANGE_OUTPUT_JAPAN'
                    confirmVoltageFreqReading(JAPAN_VOLTAGE_FREQ);

                case 'POWER_UP_RIO'
                    confirmTestCompletion;

                case {'US','UK','JAPAN'}
                    confirmTestStart(TEST_SEQUENCE{test_step});

                otherwise
                    disableOutput(connectionId);
            end
        catch
            disp(lasterr);
            % if there was any error display test as a failure
            presentMakoResults(guiHandles,'FAILURE',lasterr);
        end
    end




%-------------------------------------------------------------------------
% Function to verify the voltage and frequency readings
%-------------------------------------------------------------------------
    function confirmVoltageFreqReading(voltageFreq)
        updateMainButtonInfo(guiHandles,...
            'Click to confirm Voltage / Freq entries below');
    end

%-------------------------------------------------------------------------
% Function to verify additional testing is complete
%-------------------------------------------------------------------------
    function confirmTestCompletion
        updateMainButtonInfo(guiHandles,'pushbutton',...
            'Click to confirm completion of RIO Tests');
    end

%-------------------------------------------------------------------------
% Function to verify start of test and UPS unplug
%-------------------------------------------------------------------------
    function confirmTestStart(testName)
        updateMainButtonInfo(guiHandles,'pushbutton',...
            sprintf('Click to start %s voltage/freq test',char(testName)));
    end



%-------------------------------------------------------------------------
% Function to set specific voltage and freq
%-------------------------------------------------------------------------
    function setVoltageFreq(id,voltageFreq)

        updateMainButtonInfo(guiHandles,'text','Updating Mode');
        
        voltage = voltageFreq(1);
        freq = voltageFreq(2);

        % turn off the power for safety
        disableOutput(id);

        % Adjust high range or low range
        if voltage>135
            commBehlmanCheck(id,'R','M03000.0');
        else
            commBehlmanCheck(id,'r','M04000.0');
        end        
        
        pause(2);
        
        % if voltage is more than 135 V change current to 5A
        if voltage>135
            commBehlmanCheck(id,'I00005.0I00005.0','M00000.2');
        end
        
        pause(1);
        
        updateMainButtonInfo(guiHandles,'text',...
            sprintf('Updating Voltage to %3.1f Volts',voltage));
        
        % change the voltage
        voltageCommand = sprintf('V%05d.%1dV%05d.%1d',...
            voltage,rem(int32(voltage*10),100),...
            voltage,rem(int32(voltage*10),100));
        commBehlmanCheck(id,voltageCommand,'M00000.1')
        % allow time to complete change tolerance at 1V
        for i=1:20
            pause(0.5);
            voltageMeasured = getVoltage(connectionId);
            updateMainButtonInfo(guiHandles,'text',...
                 sprintf('Updating Voltage to %3.1f V (measured = %3.1f)',...
                 voltage,voltageMeasured));
            if abs(voltageMeasured-voltage)<VOLTAGE_TOLERANCE
                break;
            end
        end

        % one final check
        if abs(getVoltage(connectionId)-voltage)>VOLTAGE_TOLERANCE
            error('Unable to set voltage');
        end
        
        % change the frequency
        freqCommand = sprintf('F%05d.%1dF%05d.%1d',...
            freq,rem(int32(freq*10),100),...
            freq,rem(int32(freq*10),100));
        commBehlmanCheck(id,freqCommand,'M00000.3');
        
        updateMainButtonInfo(guiHandles,'text',...
            sprintf('Updating Frequency to %3.2f',freq));
        
        % voltage was less than 135V change current to 15A
        if voltage<=135
            commBehlmanCheck(id,'I00015.0I00015.0','M00000.2');
        end
        
        
    end

%-------------------------------------------------------------------------
% Function to communicate with the Behlman transfomer to get voltage
%-------------------------------------------------------------------------
    function voltage = getVoltage(id)
        voltText = commBehlman(id,'A');
        voltage = sscanf(voltText,'A%f');
    end


%-------------------------------------------------------------------------
% Function to communicate with the Behlman transfomer
%-------------------------------------------------------------------------
    function response = commBehlman(id,command)
        fwrite(id,command);
        pause(0.25);
        response = char(fread(id,9))';  %#ok<FREAD>
    end

%-------------------------------------------------------------------------
% Function to communicate with the Behlman transfomer and check response
%-------------------------------------------------------------------------
    function commBehlmanCheck(id,command,expectedResponse)
        % retry command upto 3 times
        for commandRetry=1:3
            fwrite(id,command);
            pause(0.25);
            response = char(fread(id,9))';  %#ok<FREAD>
            response = response(1:8);
            if strcmp(response,expectedResponse)
                return;
            end
        end

        %if i got here retrys were exhausted
        error('Response mismatch (expected <%s> got <%s>)',...
            expectedResponse,response);
    end


%-------------------------------------------------------------------------
% Function to establish communication with Behlman transformer (%assume the
% connection is always on COM1
%-------------------------------------------------------------------------
    function id = initBehlman

        % close and delete everything on COM1
        delete(instrfind('port','COM1'))

        % open a new COM1 connection
        id = serial('COM1',...
            'BaudRate',9600,...
            'terminator',0,...
            'Timeout',0.5,...
            'StopBits',1,...
            'DataBits',8,...
            'InputBufferSize',9);
        fopen(id);
    end


%-------------------------------------------------------------------------
% Function to close open connection to Behlman transformer (always turn off
% before closing)
%-------------------------------------------------------------------------
    function closeBehlman(id)
        commBehlman(id,'o');
        delete(id);
    end

%-------------------------------------------------------------------------
% Function to close open connection to Behlman transformer (always turn off
% before closing)
%-------------------------------------------------------------------------
    function enableOutput(id)
        commBehlmanCheck(id,'O','M01000.0');
    end

%-------------------------------------------------------------------------
% Function to reset the transformers
%-------------------------------------------------------------------------
    function resetBehlman(id)
        commBehlmanCheck(id,'E','M05000.0');
        pause(3);
    end

%--------------------------------------------------------------------------
% Function to turn off power
%-------------------------------------------------------------------------
    function disableOutput(id)
        commBehlmanCheck(id,'o','M02000.0');
    end

%--------------------------------------------------------------------------
% Function to abort the test
%-------------------------------------------------------------------------
    function abort_volt_freq_test(varargin)
        try
            disableOutput(connectionId);
            closeBehlman(connectionId);
        catch
        end
    end

end

