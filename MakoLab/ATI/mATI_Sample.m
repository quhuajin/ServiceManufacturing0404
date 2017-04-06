function mATI_Sample()
% MATI_SAMPLE is a sample F/T sensor program that connects to the F/T
% sensor NetBox, takes some force measurements and disconnects

%
% $Author: clightcap $
% $Revision: 1.0 $
% $Date: 2008/12/09 $
% Copyright: MAKO Surgical corp (2008)
%

%% 

% connect to the F/T sensor and request streaming UDP packets
disp 'Connect to the F/T sensor...'
udp = mATI_Connect();
pause(2.0);

% set software bias
% mATI_Bias(udp)

% record force/torque measurements
disp 'Record force/torque measurements...'
[FT,s] = mATI_Record(udp);

% real-time plot
x = 0; y = FT(3);
h = plot(x,y,'XDataSource','x','YDataSource','y');

nsamples = 1e4;
start_time=clock();
while 1

    [FT,s] = mATI_Record(udp);
    if rem(s,20) == 0
        x = [ x, etime(clock(),start_time) ];
        y = [ y, FT(3) ];

        refreshdata(h,'caller') % Evaluate x in the function workspace
        drawnow;
    end

end

% disconnect from the F/T sensor once the measurements are done.
disp 'Now disconnect from the F/T sensor...'
mATI_Disconnect(udp);

% $Log: mATI_Sample.m,v $
%
%
%---------- END OF FILE ---------


