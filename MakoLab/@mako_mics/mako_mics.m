% mako_mics class
% Syntax:
%   mics = mako_mics();
%   mics = mako_mics('tcpip','10.1.1.177',23);
%   mics = mako_mics(misc_obj);
%
%
% Notes:
%
%
% See also:
%   jSocket class
%

%
% $Author: rzhou $
% $Revision: 2876 $
% $Date: 2013-04-08 16:12:16 -0400 (Mon, 08 Apr 2013) $
% Copyright: MAKO Surgical corp (2012)
%
classdef mako_mics < handle
    properties (Dependent)
        serial_number;
        ee_tool_axis;
        ee_normal_axis;
        ee_origin;
        constant_file_name;
    end
    properties(SetAccess = private)
        stream_data;
        motor_currents;
        bus_voltage;
        irrigation_voltage;
        speed;
        speed_command;
        temperature;
        hall_info;
        firmware_ver_mics;
        firmware_ver_hp;
        mode = 0; %default to polling mode
        timerObj;
        error_msg = '';
    end
    properties (Constant)
        %limit setting for handpiece
        limitEEOriginLow =  [-90,-2,-46];
        limitEEOriginHigh = [-80,2,-36];
        limitEEToolLow =    [-135,-2,-46];
        limitEEToolHigh =   [-125,2,-36];
        limitEENormalLow =  [-90,-2,-81];
        limitEENormalHigh = [-80,2,-71];
        
        limitEEPointNorm = 1.0e-5;%mm
        
        limitMotorCurrent = 0.9; %amps
        limitBusVoltage = 5.0; % 43 ~ 53 volts
        limitIrrigationVoltage = 2.0; % 9.0 ~ 13 volts
        limitMaxSpeed = 1000; %11000~12000 rpm
        limitTeperature = 5; %
        
        nominalBusVoltage  = 48; % volt
        nominalMaxSpeed = 12000; % rpm
        nominalTemperature = 30; % degree celcius
        nominalIrrigationVoltage = 12; % volt
        
        %error message
        fault_message = {...
            'Software E-Stop fault', ...
            'Low bus voltage fault',...
            'High bus voltage fault',...
            'Low current fault',...
            'High current fault',...
            'Watchdog fault',...
            'High temperature fault',...
            'Motor stalled fault',...
            'Hardware current fault',...
            'RIO system fault',...
            'Handpiece communication fault',...
            'Handpiece hall fault',...
            'Motor short fault',...
            'Handpiece trigger initial position fault',...
            'Reserved',...
            'Reserved',...
            'Handpiece forward hall warning',...
            'Handpiece reverse hall warning',...
            'Handpiece direction hall range warning',...
            'Handpiece trigger range warning',...
            'Handpiece trigger sequence warning',...
            'Reserved',...
            'Reserved',...
            'Reserved',...
            'Handpiece trigger hall-1 high warning',...
            'Handpiece trigger hall-2 high warning',...
            'Handpiece trigger hall-3 high warning',...
            'Handpiece trigger hall-4 high warning',...
            'Handpiece trigger hall-1 low warning',...
            'Handpiece trigger hall-2 low warning',...
            'Handpiece trigger hall-2 low warning',...
            'Handpiece trigger hall-4 low warning',...
            };
        %commands to read constants
        readEEOriginCmd = uint8(hex2dec({'ff','05','12','50','9a'})');
        readEEToolAxisCmd = uint8(hex2dec({'ff','05','12','51','99'})');
        readEENormalAxisCmd = uint8(hex2dec({'ff','05','12','52','98'})');
        readEESNCmd = uint8(hex2dec({'ff','05','12','53','97'})');
        
        %irrigation level and voltage table
        irrigationLevels = [ 255, 202, 164,  144,  121,  92,   65,   42 ];
        irrigationNominalVoltages = [ 7.6, 9.1, 10.5, 11.5, 13.0, 15.5, 19.0, 23.6];
        
        % streaming data constant
        number_of_bytes_streaming = 38;
        number_of_variables_streaming = 6;
    end
    
    properties
        socket_type = 'tcpip'
        ip_address = '10.1.1.177';
        port = 23;
        number_of_samples = 10; %set this property before every read
        jSocketHdl;
        direction;
        irrigation;
        fault;
        speedMax;
    end
       
    methods
        %--------------------------------------------------------------------------
        % default constructor
        %--------------------------------------------------------------------------
        function obj = mako_mics(varargin)
            if(nargin ==0)
                %default constructor
            else
                if isa(varargin,'mics')
                    %copy constructor
                    obj = micsObj;
                    obj.socket_type = micsObj.socket_type;
                    obj.ip_address = micsObj.ip_address;
                    obj.port = micsObj.port;
                else
                    %user defined constructor
                    try
                        obj.socket_type = varargin{1};
                        obj.ip_address = varargin{2};
                        obj.port = varargin{3};
                    catch ME
                        throw(ME);
                    end
                end
            end
            
            %create a timer object
            obj.timerObj = timer('TimerFcn',@(~,~)keepConnectionAlive(obj),...
                 'ExecutionMode','fixedSpacing', 'Period', 0.1);
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read error message
        %--------------------------------------------------------------------------
        function errMsg = get.error_msg(obj)
            errMsg = 'No error';
            %read data from mics
            faultBuffer = readMICSStreamData(obj,'fault');
            faultIndices = find(faultBuffer > 0);
            if(~isempty(faultIndices))                
                %parse error string
                logIndex = log2(double(faultBuffer(faultIndices(1)))) + 1;
                errMsg = { sprintf('%s',obj.fault_message{logIndex})};
            end
        end
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function dataBuffer = get.stream_data(obj)
            %read data from mics
            dataBuffer = readMICSStreamData(obj,'all');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function temperatureBuffer = get.temperature(obj)
            %read data from mics
            temperatureBuffer = readMICSStreamData(obj,'temperature');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function motorCurrentBuffer = get.motor_currents(obj)

            %read data from mics
            motorCurrentBuffer = readMICSStreamData(obj,'motor_current');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function busVoltageBuffer = get.bus_voltage(obj)
            
            %read data from mics
            busVoltageBuffer = readMICSStreamData(obj,'bus_voltage');            
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function speedCmdBuffer = get.speed_command(obj)

            %read data from mics
            speedCmdBuffer = readMICSStreamData(obj,'speed_command');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function dirBuffer = get.direction(obj)

            %read data from mics
            dirBuffer = readMICSStreamData(obj,'direction');
        end
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function faultBuffer = get.fault(obj)

            %read data from mics
            faultBuffer = readMICSStreamData(obj,'fault');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function irrigationVoltageBuffer = get.irrigation_voltage(obj)
 
           %read data from mics
            irrigationVoltageBuffer = readMICSStreamData(obj,'irr_voltage');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function speedBuffer = get.speed(obj)

            %read data from mics
            speedBuffer = readMICSStreamData(obj,'speed');
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read hall information on handpiece
        %--------------------------------------------------------------------------
        function hallInfoBuffer = get.hall_info(obj)

            %read data from mics
            hallInfoBuffer = readMICSStreamData(obj,'hall_info');
        end
        
        %--------------------------------------------------------------------------
        % Internal class destructor
        %--------------------------------------------------------------------------
        function delete(obj)
            %check and close tcp connection
            try
                %stop the keep alive timer function
                if(isvalid(obj.timerObj))
                    stop(obj.timerObj);
                    delete(obj.timerObj);
                end
                %close the java socket
                obj.jSocketHdl.Close();
            catch %#ok<CTCH>
            end
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read mics board firmware version
        %--------------------------------------------------------------------------
        function firmwareVersion = get.firmware_ver_hp(obj)

            %create a socket
            if(obj.mode)
                %in the streaming mode, connection is active
                mHdl = obj.jSocketHdl;
            else
                mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
                obj.jSocketHdl = mHdl;
            end
            
            %stop streaming
            stopStreaming(obj);
            
            %now start reading firmware version
            cmdFv = uint8(hex2dec({'ff','05','12','4f','9B'})');
            TCPWrite(mHdl,cmdFv);
            fwVersion = TCPRead(mHdl,24)';
            idx =find(fwVersion);
            
            % firmware version start from 3rd byte and stop at second
            % last non-zero byte, the last non-zero byte is check sum
            firmwareVersion = char(fwVersion(4 : idx(end-1)));
            
            %close socket
            mHdl.Close();
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read mics board firmware version
        %--------------------------------------------------------------------------
        function firmwareVersion = get.firmware_ver_mics(obj)

             %create a socket
            if(obj.mode)
                %in the streaming mode, connection is active
                mHdl = obj.jSocketHdl;
            else
                mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
                obj.jSocketHdl = mHdl;
            end
            %stop streaming
            stopStreaming(obj);
            
            %now start reading firmware version
            cmdFv = uint8(hex2dec({'ff','05','12','00','ea'})');
            TCPWrite(mHdl,cmdFv);
            fwVersion = TCPRead(mHdl,24)';
            idx =find(fwVersion);
            
            % firmware version start from 3rd byte and stop at second
            % last non-zero byte, the last non-zero byte is check sum
            firmwareVersion = char(fwVersion(4 : idx(end-1)));
            
            %close socket
            mHdl.Close();
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read mics board maximum speed
        %--------------------------------------------------------------------------
        function maxSpeed = get.speedMax(obj)

             %create a socket
            if(obj.mode)
                %in the streaming mode, connection is active
                mHdl = obj.jSocketHdl;
            else
                mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
                obj.jSocketHdl = mHdl;
            end
            %stop streaming
            stopStreaming(obj);
            
            %now start reading firmware version
            cmdMaxSpeed = uint8(hex2dec({'ff','05','12','03','e7'})');
            TCPWrite(mHdl,cmdMaxSpeed);
            replyStr = TCPRead(mHdl,24)';
            maxSpeed = typecast(replyStr(4:7),'int32');
            %close socket
            mHdl.Close();
        end
        
        %--------------------------------------------------------------------------
        % Internal function to generate CRC8
        %--------------------------------------------------------------------------
        function checkSum = CRC_8(obj,iCRC, iChar) %#ok<*INUSL>
            data = uint16(bitxor(iCRC, iChar));
            data = bitshift(data, 8);
            for i = 1: 8
                if(bitand(data, uint16(2 ^15)) ~= 0)
                    data = bitxor(data, bitshift(uint16(4208), 3));
                end
                data = bitshift(data, 1);
            end
            checkSum = uint8(bitshift(data, -8));
        end
       
        %--------------------------------------------------------------------------
        % Internal function to check EE constants check sum
        %--------------------------------------------------------------------------
        function ckSum = checkEEConstantsChecksum(obj,eeConstants) %#ok<INUSL>
            %run a checksum on the data
            ckSum = uint8(0);
            for i =1:length(eeConstants)
                ckSum = CRC_8(obj,ckSum, eeConstants(i));
            end
        end
        %--------------------------------------------------------------------------
        % Internal function to load update EE constants from a file
        %--------------------------------------------------------------------------
        function set.constant_file_name(obj,fName)
            fh = fopen(fName, 'r');
            % ee file is in the following format (without the %)
            
            %Measured Date
            %09-Apr-2013
            %EE Serial Number
            %SN-1234567
            %Origin(mm)
            %-85.1234, 0.1234, -41.1234
            %Tool axis point(mm)
            %-85.1234, 0.1234, -21.1234
            %Normal axis point(mm)
            %-130.1234, 0.1234, -41.1234
            %read the first two lines and ignore them
            eeContantDate = fgetl(fh); %#ok<*NASGU>
            eeContantDate = fgetl(fh);
            
            eeSNName = fgetl(fh); %#ok<NASGU>
            eeSNStr = fgetl(fh);
            eeSN = sscanf(eeSNStr,['SN-' '%07d']);
            rNames{1} = fgetl(fh);
            eeOrigin = fscanf(fh,'%f,%f,%f');
            rNames{2} = fgetl(fh);
            eeToolAxis = fscanf(fh,'%f,%f,%f');
            rNames{3} = fgetl(fh); %#ok<NASGU>
            eeNormalAxis = fscanf(fh,'%f,%f,%f');
            %close file
            fclose(fh);
            
            %start to load the constants to handpiece
            obj.error_msg = checkAndUpdateEEConstants(obj,eeSN,0);
            if(isempty(obj.error_msg))
                obj.error_msg = checkAndUpdateEEConstants(obj,eeOrigin',1);
            end
            if(isempty(obj.error_msg))
                obj.error_msg = checkAndUpdateEEConstants(obj,eeToolAxis',2);
            end
            if(isempty(obj.error_msg))
                obj.error_msg = checkAndUpdateEEConstants(obj,eeNormalAxis',3);
            end
        end
        
        %--------------------------------------------------------------------------
        % get function for property
        %--------------------------------------------------------------------------
        function eeSN = get.serial_number(obj)
            [eeSN,errStr] = readEESerialNumberMICS(obj);
            obj.error_msg = errStr;
        end
        
        %--------------------------------------------------------------------------
        % get function for property
        %--------------------------------------------------------------------------
        function eeOrigin = get.ee_origin(obj)
            [eeOrigin,errStr] = readEEConstantsMICS(obj,obj.readEEOriginCmd);
            obj.error_msg = errStr;
        end
        
        %--------------------------------------------------------------------------
        % get function for property
        %--------------------------------------------------------------------------
        function eeToolAxis = get.ee_tool_axis(obj)
            [eeToolAxis,errStr] = readEEConstantsMICS(obj,obj.readEEToolAxisCmd);
            obj.error_msg = errStr;
        end
        
        %--------------------------------------------------------------------------
        % get function for property
        %--------------------------------------------------------------------------
        function eeNormalAxis = get.ee_normal_axis(obj)
            [eeNormalAxis,errStr] = readEEConstantsMICS(obj,obj.readEENormalAxisCmd);
            obj.error_msg = errStr;
        end
        
        %--------------------------------------------------------------------------
        % Internal function to check and update EE serial number to handpiece
        %--------------------------------------------------------------------------
        function set.serial_number(obj,eeConstantsInput)
            obj.error_msg = checkAndUpdateEEConstants(obj,eeConstantsInput,0);
        end
        
        %--------------------------------------------------------------------------
        % Internal function to check and update EE origin to handpiece
        %--------------------------------------------------------------------------
        function set.ee_origin(obj,eeConstantsInput)
            obj.error_msg = checkAndUpdateEEConstants(obj,eeConstantsInput,1);
        end
        
        %--------------------------------------------------------------------------
        % Internal function to check and update EE tool axis to handpiece
        %--------------------------------------------------------------------------
        function set.ee_tool_axis(obj,eeConstantsInput)
            obj.error_msg = checkAndUpdateEEConstants(obj,eeConstantsInput,2);
        end
        
        
        %--------------------------------------------------------------------------
        % Internal function to check and update EE normal axis to handpiece
        %--------------------------------------------------------------------------
        function set.ee_normal_axis(obj,eeConstantsInput)
            obj.error_msg = checkAndUpdateEEConstants(obj,eeConstantsInput,3);
        end
        
        %--------------------------------------------------------------------------
        % Internal function to set direction os handpiece
        %--------------------------------------------------------------------------
        function set.direction(obj,drct)
            %initialize reurn
            errString =[];
            %convert data to 8 bit unsigned integers
            tempData = uint8(drct);
            %intialize the out stream data header and data
            dirData = uint8(zeros(1,6));
            dirData(1:4) = uint8(hex2dec({'FF','06','13','0d'}));
            expectedReply = uint8(hex2dec({'fe','04','13','eb'})');
            %setup header and data
            dirData(5) = tempData;
            
            %get communication checksum
            cksum = sum(dirData(1:length(dirData)-1));
            cksum = 256 - mod(cksum,256);
            dirData(end) = uint8(cksum);
            
            %create a socket
            mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            
            %send data to handpiece
            TCPWrite(mHdl,dirData);
            pause(1);
            actualReply = TCPRead(mHdl,length(expectedReply))';
            if( any(actualReply ~= expectedReply))
                errString = 'direction command failed';
            end
            %close socket
            mHdl.Close();
            
        end   
        
        %--------------------------------------------------------------------------
        % Internal function to irrigation level on handpiece
        %--------------------------------------------------------------------------
        function set.irrigation(obj,irr)
            %initialize reurn
            errString =[];
            %convert data to 8 bit unsigned integers
            tempData = uint8(obj.irrigationLevels(irr));
            %intialize the out stream data header and data
            irrData = uint8(zeros(1,7));
            irrData(1:4) = uint8(hex2dec({'FF','07','13','15'}));
            expectedReply = uint8(hex2dec({'fe','04','13','eb'})');
            %setup header and data
            irrData(5) = tempData;
            
            %get communication checksum
            cksum = sum(irrData(1:length(irrData)-1));
            cksum = 256 - mod(cksum,256);
            irrData(end) = uint8(cksum);
            
            %create a socket
            mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            
            %send data to handpiece
            TCPWrite(mHdl,irrData);
            pause(1);
            actualReply = TCPRead(mHdl,length(expectedReply))';
            if( any(actualReply ~= expectedReply))
                errString = 'irrigation level command failed';
            end
            %close socket
            mHdl.Close();
            
            %update irrigation level
            obj.irrigation = irr;
        end  
        
        %--------------------------------------------------------------------------
        % Internal function to maximum speed on handpiece
        %--------------------------------------------------------------------------
        function set.speedMax(obj,spd)
            %initialize reurn
            errString =[];
            %convert data to 8 bit unsigned integers
            tempData = typecast(uint32(spd),'uint8');
            %intialize the out stream data header and data
            spdData = uint8(zeros(1,9));
            spdData(1:4) = uint8(hex2dec({'FF','09','13','03'}));
            expectedReply = uint8(hex2dec({'fe','04','13','eb'})');
            %setup header and data
            spdData(5:8) = tempData;
            
            %get communication checksum
            cksum = sum(spdData(1:length(spdData)-1));
            cksum = 256 - mod(cksum,256);
            spdData(end) = uint8(cksum);
            
            %create a socket
            mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            
            %send data to handpiece
            TCPWrite(mHdl,spdData);
            pause(1);
            actualReply = TCPRead(mHdl,length(expectedReply))';
            if( any(actualReply ~= expectedReply))
                errString = 'maximum speed command failed';
            end
            %close socket
            mHdl.Close();
            
        end
        
        %--------------------------------------------------------------------------
        % Internal function to clear fault
        %--------------------------------------------------------------------------
        function set.fault(obj,flt) %#ok<INUSD>
            %initialize reurn
            errString =[];
            %intialize the out stream data header and data
            faultData = uint8(zeros(1,9));
            faultData(1:8) = uint8(hex2dec({'FF','09','13','14','00','00','00','00'}));
            expectedReply = uint8(hex2dec({'fe','04','13','eb'})');
            
            %get communication checksum
            cksum = sum(faultData(1:length(faultData)-1));
            cksum = 256 - mod(cksum,256);
            faultData(end) = uint8(cksum);
            
            %create a socket
            mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port); %#ok<MCSUP>
            %stop streaming
            obj.jSocketHdl = mHdl; %#ok<MCSUP>
            stopStreaming(obj);
            
            
            %send data to handpiece
            TCPWrite(mHdl,faultData);
            pause(1);
            actualReply = TCPRead(mHdl,length(expectedReply))';
            if( any(actualReply ~= expectedReply))
                errString = 'fault clear command failed';
            end
            %close socket
            mHdl.Close();
            
        end     
        
    end
    
    methods(Access = private)
        %--------------------------------------------------------------------------
        % Private function to keep connection alive in streaming mode
        %--------------------------------------------------------------------------
        function keepConnectionAlive(obj)
            %create a socket
            mHdl = obj.jSocketHdl;
            try
                %keep alive
                TCPRead(mHdl,obj.number_of_bytes_streaming);
            catch %#ok<CTCH>
            end
        end
        %--------------------------------------------------------------------------
        % Private function to stop the streaming mode
        %--------------------------------------------------------------------------
        function stopStreaming(obj)
            %create a socket
            mHdl = obj.jSocketHdl;
            
            %stop  the keep alive timer function
            stop(obj.timerObj);

            %stop streaming
            cmdFv = uint8(hex2dec({'ff','04','24','d9'})');
            TCPWrite(mHdl,cmdFv);
            warning off all;
            TCPRead(mHdl,9999);
            warning on all;
            obj.mode = 0;
        end
        
        %--------------------------------------------------------------------------
        % Private function to stop the streaming mode
        %--------------------------------------------------------------------------
        function startStreaming(obj)
            %create a socket
            mHdl = obj.jSocketHdl;
            
            %star streaming
            cmdFv = uint8(hex2dec({'ff','04','23','da'})');
            TCPWrite(mHdl,cmdFv);
            TCPRead(mHdl,4);
            obj.jSocketHdl = mHdl;
            obj.mode = 1;
        end
        
        %--------------------------------------------------------------------------
        % Private function to load update EE constants from a file
        %--------------------------------------------------------------------------
        function [eeSN,eeConstantsErr] = readEESerialNumberMICS(obj)
            %initialize the serial number to 0;
            eeSN = 0;
            eeConstantsErr = '';
            
            %create a socket
            if(obj.mode)
                %in the streaming mode, connection is active
                mHdl = obj.jSocketHdl;
            else
                mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            end
            
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            %first read ee serial number
            TCPWrite(mHdl,obj.readEESNCmd);
            tempData = TCPRead(mHdl,9)';
            eeSNData = tempData(4 : 7);
            tempChecksum = checkEEConstantsChecksum(obj,eeSNData);
            if(tempChecksum ~= tempData(end -1))
                eeConstantsErr = ...
                    sprintf('EE constant checksum mismatch, expected %x, get %x',...
                    tempChecksum, tempData(end));
                return;
            end
            
            %get ee serial number, it is a 32 bit interger
            eeSN = typecast(eeSNData(1:4),'uint32');
            %close socket
            mHdl.Close();
            
        end
        %--------------------------------------------------------------------------
        % Private function to load update EE constants from a file
        %--------------------------------------------------------------------------
        function [eeConstant,eeConstantsErr] = readEEConstantsMICS(obj,readEEConstCmd)
            
            %initialize the constant to empty
            eeConstant = [];
            eeConstantsErr = '';
            % ee constants reply is 17 bytes, first three bytes is header
            % byte 4 ~ 15 is data, byte 16 is data checksum, byte 17 is
            % total reply checksum.
            eeConstantLength = 17;
            eeConstantStartIndex = 4;
            eeConstantEndIndex = 15;
            
            %create a socket
            if(obj.mode)
                %in the streaming mode, connection is active
                mHdl = obj.jSocketHdl;
            else
                mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            end
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            %now start reading ee constants, start with ee origin first
            TCPWrite(mHdl,readEEConstCmd);
            tempData = TCPRead(mHdl,eeConstantLength)';
            eeConstants = tempData(eeConstantStartIndex : eeConstantEndIndex);
            tempChecksum = checkEEConstantsChecksum(obj,eeConstants);
            if(tempChecksum ~= tempData(end -1))
                eeConstantsErr = ...
                    sprintf('EE Origin checksum mismatch, expected %x, get %x',...
                    tempChecksum, tempData(end));
                return;
            end
            for i =1: 3
                tempIndex = (i-1)*4;
                eeConstant(i) = typecast(eeConstants(tempIndex+1:tempIndex+4),'single'); %#ok<AGROW>
            end
            %close socket
            mHdl.Close();
        end
        
        %--------------------------------------------------------------------------
        % private function to check and update EE constants to handpiece
        %--------------------------------------------------------------------------
        function errString = checkAndUpdateEEConstants(obj,eeConstantsInput,eeConstantsId)
            %initialize reurn
            errString =[];
            %convert data to 8 bit unsigned integers
            tempData = typecast(single(eeConstantsInput),'uint8');
            %intialize the out stream data header and data
            eeConstData = uint8(zeros(1,18));
            eeConstData(1:3) = uint8(hex2dec({'FF','12','13'}));
            expectedReply = uint8(hex2dec({'fe','04','13','eb'})');
            
            %check against the limit and fill in checksum to the out stream
            switch(eeConstantsId)
                case 0
                    % serial number
                    eeConstData = eeConstData(1:10);
                    eeConstData(2) = uint8(hex2dec('0a'));
                    eeConstData(4) = uint8(hex2dec('53'));
                    %convert data to 8 bit unsigned integers
                    tempData = typecast(uint32(eeConstantsInput),'uint8');
                case 1
                    eeConstData(4) = uint8(hex2dec('50'));
                    %ee origin
                    if(any((eeConstantsInput - obj.limitEEOriginLow) < 0.0))
                        errString = 'EE origin lower limit check failed';
                        return;
                    end
                    if(any((eeConstantsInput - obj.limitEEOriginHigh) > 0.0))
                        errString = 'EE origin higher limit check failed';
                        return;
                    end
                case 2
                    eeConstData(4) = uint8(hex2dec('51'));
                    %ee tool axis
                    if(any((eeConstantsInput - obj.limitEEToolLow) < 0.0))
                        errString = 'EE tool axis point lower limit check failed';
                        return;
                    end
                    if(any((eeConstantsInput - obj.limitEEToolHigh) > 0.0))
                        errString = 'EE tool axis point higher limit check failed';
                        return;
                    end
                    
                case 3
                    eeConstData(4) = uint8(hex2dec('52'));
                    %ee normal axis
                    if(any((eeConstantsInput - obj.limitEENormalLow) < 0.0))
                        errString = 'EE normal axis point lower limit check failed';
                        return;
                    end
                    if(any((eeConstantsInput - obj.limitEENormalHigh) > 0.0))
                        errString = 'EE normal axis point higher limit check failed';
                        return;
                    end
            end
            %setup header and data
            eeConstData(5:length(tempData)+4) = tempData;
            
            %get EE data checksum
            cksum = uint8(0);
            for i=1:length(tempData)
                cksum = CRC_8(obj,tempData(i),cksum);
            end
            eeConstData(end-1) = cksum;
            %get communication checksum
            cksum = sum(eeConstData(1:length(eeConstData)-1));
            cksum = 256 - mod(cksum,256);
            eeConstData(end) = uint8(cksum);
            
            %create a socket
            mHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);
            %stop streaming
            obj.jSocketHdl = mHdl;
            stopStreaming(obj);
            
            
            %send data to handpiece
            TCPWrite(mHdl,eeConstData);
            pause(1);
            actualReply = TCPRead(mHdl,length(expectedReply))';
            if( actualReply ~= expectedReply) %#ok<BDSCI>
                errString = 'EE constants update failed';
            end
            %close socket
            mHdl.Close();
        end
        
        %--------------------------------------------------------------------------
        % Internal function to read handpiece data
        %--------------------------------------------------------------------------
        function dataBuffer = readMICSStreamData(obj,id)

            %start streaming mode
            if(~obj.mode)
                %create a socket
                obj.jSocketHdl = jSocket( obj.ip_address, obj.socket_type, obj.port);            
                startStreaming(obj);
            else
                %stop the keep alive timer function
                stop(obj.timerObj);
            end
            
            mHdl = obj.jSocketHdl;
            
            %get limit save typing
            strDataSize = obj.number_of_bytes_streaming;
            
            %create a buffer for data recording            
            dataBufferSize = obj.number_of_samples;
            switch id
                case 'all'
                    nuberOfVariables = obj.number_of_variables_streaming;
                    dataBuffer = zeros(dataBufferSize,nuberOfVariables);
                case 'hall_info'
                    dataBuffer = zeros(dataBufferSize,6);
                otherwise
                    dataBuffer = zeros(dataBufferSize,1);
            end

            lCounter = 1;
            
            while(1)
                tcpReply = TCPRead(mHdl,strDataSize);
                idx =strfind(tcpReply',[253,strDataSize]);
                %check if enough data is ready
                if(~isempty(idx))
                    if ((length(tcpReply) - idx(end)) >= (strDataSize - 1))
                        rpl = tcpReply(idx : idx + strDataSize - 1);
                        l_motorCurrent = double(typecast(rpl(3:4),'int16')) / 1000;
                        l_busVoltage = double(typecast(rpl(5:8),'int32')) / 1000;
                        l_speed = double(typecast(rpl(9:12),'uint32'));                        
                        l_dirRotor = rpl(13);
                        l_fault = typecast(rpl(14:17),'uint32');
                        l_temperature = double(typecast(rpl(18:19),'int16'));
                        l_irrigationVoltage = double(typecast(rpl(20:21),'int16')) / 1000;
                        l_speedCmd = double(typecast(rpl(34:37),'uint32'));
                        for i = 0 : 2: 11
                            l_hallInfo(idivide(uint8(i),2)+1) = double(typecast(rpl(22+i:23+i),'uint16')); %#ok<AGROW>
                        end
                        %collect data
                        switch id
                            case 'all'                                
                                dataBuffer = [dataBuffer(2:end,:); [l_motorCurrent, l_busVoltage, ...
                                    l_speed, l_speedCmd, l_temperature, l_irrigationVoltage]];
                            case 'motor_current'
                                dataBuffer = [dataBuffer(2:end); l_motorCurrent];
                            case 'bus_voltage'
                                dataBuffer = [dataBuffer(2:end); l_busVoltage];
                            case 'irr_voltage'
                                dataBuffer = [dataBuffer(2:end); l_irrigationVoltage];
                            case 'speed'
                                dataBuffer = [dataBuffer(2:end); l_speed];
                            case 'speed_command'
                                dataBuffer = [dataBuffer(2:end); l_speedCmd];
                            case 'temperature'
                                dataBuffer = [dataBuffer(2:end); l_temperature];
                            case 'hall_info'
                                dataBuffer = [dataBuffer(2:end,:); l_hallInfo];
                            case 'direction'
                                dataBuffer = [dataBuffer(2:end); l_dirRotor];
                            case 'fault'
                                dataBuffer = [dataBuffer(2:end); l_fault];
                            otherwise
                                dataBuffer =[];
                                obj.error_msg = sprintf('Invalid stream data item %s',id);
                        end
                        %check if all data are collected
                        if(lCounter > dataBufferSize)
                            %reset number of samples
                            obj.number_of_samples = 10;
                            break;
                        else
                            lCounter = lCounter + 1;
                        end
                    end
                end
            end    
            
            %restart the timer to keep the coomunication alive
            start(obj.timerObj);
        end        
    end
end


% --------- END OF FILE ----------
