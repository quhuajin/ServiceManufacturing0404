function oscillate(galilObj,freq,amp,time)

basedir=fileparts(which('galil_mc.m'));

downloadfile(galilObj, fullfile(basedir,'private','oscillate_mo_jo.dmc'));

set(galilObj,'freq', num2str(freq));
set(galilObj,'amp', num2str(amp));
set(galilObj,'time', num2str(time));

comm(galilObj,'SH');
comm(galilObj,'XQ');

pause(.5);
while ~get(galilObj,'DONE')
    pause(.2)
end
