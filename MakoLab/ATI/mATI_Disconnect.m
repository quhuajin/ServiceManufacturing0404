function mATI_Disconnect(udp)
% MATI_DISCONNECT stops streaming of ATI F/T sensor data.

%
% $Author: clightcap $
% $Revision: 1.0 $
% $Date: 2008/12/12 $
% Copyright: MAKO Surgical corp (2008)
%

%%

% destination hostname and port for F/T sensor NetBox
host='192.168.1.1';
port=49152;

% required header
command_header = uint16(hex2dec('1234'));

% command to stop streaming
command = uint16(hex2dec('0000'));

% number of samples to output (0 = infinite)
sample_count = uint32(0);

% write to write buffer
pnet(udp,'write',command_header);
pnet(udp,'write',command);
pnet(udp,'write',sample_count);

% send buffer as UDP packet
pnet(udp,'writepacket',host,port);

% small pause needed between each packet else packets be lost.
pause(0.03);

% close connection
pnet(udp,'close');

% $Log: mATI_Disconnect.m,v $
%
%
% ----- END OF FILE -------