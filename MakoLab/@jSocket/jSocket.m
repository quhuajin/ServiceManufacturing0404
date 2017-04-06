%TCP/UDP socket class using java class
%
% Syntax:
%   
%       Create a tcp/ip socket object or a udp socket object 
%
% Notes:
%   
%
% Examles:
%
% See also:
%   
%   

%
% $Author: dmoses $
% $Revision: 3738 $
% $Date: 2015-01-16 17:34:21 -0500 (Fri, 16 Jan 2015) $
% Copyright: MAKO Surgical Corp (2012)
%

classdef jSocket
    %
    % public properties
    %
    properties
        mHost='localhost';
        mTcpPort=23;
        mUdpPort=65501;
        mTimeout=1000;
        mTcpSocket;
        mUdpSocket;
        mSocketType ='tcpip';
        mUdpPacketLength=97;
        mSocketCreated = false;
    
        % other properties
        mOutputStream;
        mObjectOutputStream;
        mInputStream;
        mObjectInputStream;
        
    end
    
    %
    % public methods
    %
    methods
      
        %------------------------------------------------------------------
        % Function acts as a default constructor
        %------------------------------------------------------------------
        function  Obj= jSocket(host,type,port)            
            
            %import suporting java classes
            import java.net.DatagramSocket
            import java.net.DatagramPacket
            import java.net.InetAddress
            import java.net.Socket
            import java.io.*
            
            switch nargin
                case 1
                    % Get input properties
                    Obj.mHost = host;
                case 2
                    % Get input properties
                    Obj.mHost = host;
                    Obj.mSocketType = type;
                case 3                    
                    % Get input properties
                    Obj.mHost = host;
                    Obj.mSocketType = type;
                    %check port number
                    if(port >65535 || port <0)
                        error('Invalid port number %d',port);
                    end
                    Obj.mTcpPort = port;
                    Obj.mUdpPort = port;
            end          
            
            %check host ip address
            if strcmpi(Obj.mHost,'localhost')
            else
                ipCell=regexp(Obj.mHost,'\.','split');                

                % get ip address values
                ipAddrFields=str2num(char(ipCell{:})); %#ok<ST2NM>
                
                %check number of field
                if length(ipAddrFields)~=4
                    error('Invalid ip ''%s''',Obj.mHost);
                end
                 %check the field range
                if ~isempty(find(ipAddrFields>255)) || ~isempty(find(ipAddrFields <0)) %#ok<EFIND>
                    error('Invalid ip ''%s''',Obj.mHost);
                end
     
            end

            % create the socket as requested, also check the type
            switch type
                case 'tcpip'
                    % Create a tcp socket.
                    try
                        Obj.mTcpSocket = Socket(Obj.mHost,Obj.mTcpPort);
                        Obj.mTcpSocket.setSoTimeout(Obj.mTimeout);
                        %add java path
                        currentFile=which('jSocket.m');
                        tempDir = fileparts(currentFile);
                        currentDir=[tempDir '\java'];
                        dpath = javaclasspath;
                        javaPathExist = false;
                        for i = 1: length(dpath)
                            if(strcmp(dpath{i}, currentDir))
                                javaPathExist = true;
                                break;
                            end
                        end
                        if(~javaPathExist)
                            javaaddpath(currentDir);
                        end
                        %import the java class
                        import java.net.Socket
                        import java.io.*                       
                        
                        % get the input stream
                        Obj.mInputStream = Obj.mTcpSocket.getInputStream;
                        Obj.mObjectInputStream = DataInputStream(Obj.mInputStream);
                    catch err
                        rethrow(err);
                    end
                case 'udp'
                    % Create a udp socket
                    try
                        while ~(system('netstat -nao |grep 65501'))
                            pause(0.5);
                        end
                        Obj.mUdpSocket = DatagramSocket(Obj.mUdpPort);
                        Obj.mUdpSocket.setSoTimeout(Obj.mTimeout);
                        Obj.mUdpSocket.setReuseAddress(1);
                        Obj.mUdpSocket.setReceiveBufferSize(Obj.mUdpPacketLength);
                    catch err
                        rethrow(err);
                    end
                otherwise
                    error('Input ''%s'' not supported, expected ''tcpip''  or ''udp''',type);
            end            
        end
        %------------------------------------------------------------------
        %  Function to read data from data tcpip stream
        %------------------------------------------------------------------
        function [outStream] = TCPRead(Obj,rLength)
            tic;
            %check data available or not
            while(1)
                byteAvailable = Obj.mInputStream.available;
                
                if(byteAvailable >= rLength)
                    break;
                end                
                %check for timeout
                if(toc > 1.0) 
                    break; 
                end                
                pause(0.005);
            end
            
            % intialize the output stream
            outStream=zeros(1,byteAvailable,'int8'); %#ok<NASGU>
            
            % read/return data if data available in 1 seconds
            % otherwise return empty data
            if byteAvailable > 0
                dReader=DataReader(Obj.mObjectInputStream);
                outStream=typecast(dReader.readBuffer(byteAvailable),'uint8');
            else
                outStream = [];
            end
        end
        
        %------------------------------------------------------------------
        % Function to write data to tcpip stream
        %
        % write data is an array of unit8, all type of data have to
        % be converted to binary array before sending out, make sure they
        % have the right endians. Even this really does not affect the
        % functionality of the function, since it will receive an error
        % reply, it is user's reponsibility to check the return and
        % make sure the data or command are executed properly.
        %------------------------------------------------------------------
        function [result] = TCPWrite(Obj,mMsg)
            %check the socket type
            if ~strcmpi(Obj.mSocketType,'tcpip')
                error('Incorrect socket type ''%s'' on TCPWrite',Obj.mSocketType);
            end
            
            %import 
            import java.net.Socket
            import java.io.*
            
            % Create ouput stream
            Obj.mOutputStream = Obj.mTcpSocket.getOutputStream;
            Obj.mObjectOutputStream = DataOutputStream(Obj.mOutputStream);
            
            % Now write the data to the socket
            try
                for i=1:length(mMsg)
                    Obj.mObjectOutputStream.write(int32(mMsg(i)));
                end
                Obj.mObjectOutputStream.flush;
                result = true;
            catch err
                result = false; %#ok<NASGU>
                rethrow(err);
            end
        end
        %------------------------------------------------------------------
        %  Function to read data from udp stream
        %------------------------------------------------------------------
        function [outStream,sourceHost] = UdpRead(Obj)
            
            %check the socket type
            if ~strcmpi(Obj.mSocketType,'udp')
                error('Incorrect socket type ''%s'' on UdpRead',Obj.mSocketType);
            end
            
            %import java classes
            import java.io.*
            import java.net.DatagramSocket
            import java.net.DatagramPacket
            import java.net.InetAddress
            
            %read data
            try
                %receive data
                packet = DatagramPacket(zeros(1,Obj.mUdpPacketLength,'int8'),...
                    Obj.mUdpPacketLength);
                Obj.mUdpSocket.receive(packet);
                outStream = packet.getData;
                outStream = outStream(1:packet.getLength);
                inetAddress = packet.getAddress;
                sourceHost = char(inetAddress.getHostAddress);
            catch err
                rethrow(err);
            end
        end
        %------------------------------------------------------------------
        % Close
        %------------------------------------------------------------------
        function  Close(Obj)
            try
                switch Obj.mSocketType
                    case 'tcpip'
                        Obj.mTcpSocket.close;
                    case 'udp'
                        Obj.mUdpSocket.close;
                        Obj.mUdpSocket.disconnect;
                end
            catch err
                rethrow(err);
            end
        end
    end

end
