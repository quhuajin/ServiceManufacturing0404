function [FT,s] = mATI_Record(udp)
% MATI_RECORD reads force and torque measurements from UDP socket

%
% $Author: clightcap $
% $Revision: 1.0 $
% $Date: 2008/12/12 $
% Copyright: MAKO Surgical corp (2008)
%

%% 

% define byte order and data size
BYTEORDER = 'network';
DATASIZE = 1;

% number of records received in UDP packet set on 'comm' page
NRECORDS = 1;

% counts per force and counts per torque (N, Nm)
cpf = 1000000;
cpt = 1000000;

% outputs
s = zeros(NRECORDS,1);
FT = zeros(NRECORDS,6);

% read packed from udp socket
len = pnet(udp,'readpacket');

% check that correct sized packet is received
if len == 4*(9*DATASIZE)*NRECORDS,
    for packi = 1:NRECORDS,  % use while loop to read all records
    
        % position of RDT record within a single output stream
        rdt_sequence = pnet(udp,'read',DATASIZE,'uint32',BYTEORDER);

        % internal sample number of the F/T record
        ft_sequence = pnet(udp,'read',DATASIZE,'uint32',BYTEORDER);

        % contains the system status code at the time of the record
        status = pnet(udp,'read',DATASIZE,'uint32',BYTEORDER);

        % F/T data in counts (must convert with counts/force and
        % counts/torque from netftapi2.xml)
        fx = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);
        fy = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);
        fz = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);
        tx = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);
        ty = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);
        tz = pnet(udp,'read',DATASIZE,'int32',BYTEORDER);

        FT(packi,:) = [ double([fx, fy, fz])/cpf, double([tx, ty, tz])/cpt ];
        s = rdt_sequence;

    end

% display error IF packet size is incorrect
else
    fprintf('PACK BAD size: %d \n',len);
end;

% $Log: mATI_Record.m,v $
%
%
%---------- END OF FILE ---------


