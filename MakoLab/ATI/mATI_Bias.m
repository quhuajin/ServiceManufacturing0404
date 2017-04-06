function mATI_Bias(udp)
% MATI_BIAS sets software bias for ATI F/T sensor data.
%
% Syntax:
%     udp = mATI_Bias
%       Sets software bias for incoming UPD packets.
%
% Notes:
%
% See also:
%   mATIConnect, mATIDisconnect, mATIRecord, mATISample

%
% $Author: clightcap $
% $Revision: 1.0 $
% $Date: 2008/12/09 00:00:15 $
% Copyright: MAKO Surgical corp (2008)
%
%% 

% destination hostname and port for F/T sensor NetBox
host='192.168.1.1';
port=49152;

% required header
command_header = uint16(hex2dec('1234'));

% command to set software bias
command = uint16(hex2dec('0042'));

% number of samples to output (?)
sample_count = uint32(hex2dec('0000'));

% write to write buffer
pnet(udp,'write',command_header);
pnet(udp,'write',command);
pnet(udp,'write',sample_count);

% send buffer as UDP packet
pnet(udp,'writepacket',host,port);

% small pause needed between each packet else packets be lost. 
pause(0.03);

% $Log: mATI_Bias.m,v $
%
%
%------------- END OF FILE ------------
