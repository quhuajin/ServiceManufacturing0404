function udp = mATI_Connect()
% MATI_CONNECT starts streaming of ATI F/T sensor data.
%
% Syntax:
%     udp = mATI_Connect
%       Requests streaming UPD packets from NetBox.
%
% Notes:
%
% See also:
%   mATIDisconnect, mATIRecord, mATISample

%
% $Author: clightcap $
% $Revision: 1.0 $
% $Date: 2008/12/09 00:00:15 $
% Copyright: MAKO Surgical corp (2008)
%
%% 

% prepare by closing existing pnet connections
pnet('closeall'); 

% destination hostname and port for F/T sensor NetBox
host='192.168.1.1';
port=49152;

% required header
command_header = uint16(hex2dec('1234'));

% command to start high-speed buffered streaming
command = uint16(hex2dec('0002'));

% number of samples to output (0 = infinite)
sample_count = uint32(hex2dec('0000'));

% create udp socket
udp = pnet('udpsocket',port);

if udp ~= -1,
    % write to write buffer
    pnet(udp,'write',command_header);
    pnet(udp,'write',command);
    pnet(udp,'write',sample_count);

    % send buffer as UDP packet
    pnet(udp,'writepacket',host,port);
    
    % small pause needed else packets be lost. 
    pause(0.03);
end

% $Log: mATI_Connect.m,v $
%
%
%------------- END OF FILE ------------
