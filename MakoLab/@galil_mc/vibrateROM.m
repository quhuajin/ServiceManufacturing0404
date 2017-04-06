function vibrateROM(galilObj,freq,amp,grcycls,limneg,limpos,groper,steps)

% '   galilObj - galil motor controller object
% '   freq    - Oscillation frequency
% '   amp     - Oscillation amplitude
% '   grcycls - Number of gross cycles to execute
% '   limpos  - Positive position limit
% '   limneg  - Negative position limit
% ' **Input parameters
% '   groper=40  - Gross motion period
% '   steps=200  - Steps per range (of motion)

comm(galilObj,'DA*');
basedir=fileparts(which('galil_mc.m'));

downloadfile(galilObj, fullfile(basedir,'private','vibrate_rom.dmc'));

set(galilObj, 'freq', num2str(freq));
set(galilObj,'amp', num2str(amp));
set(galilObj,'grcycls', num2str(grcycls));
set(galilObj,'limpos', num2str(limpos));
set(galilObj,'limneg', num2str(limneg));
set(galilObj,'groper', num2str(groper));
set(galilObj,'steps', num2str(steps));
comm(galilObj,'XQ');

