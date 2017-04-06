function portHandle=init_tool(ndi,filename)  
%INIT_TOOL load the srom tool data to the ndi camera
%
% Syntax:
%   init_tool(ndi,filename)
%       loads the srom specified by the filename to the ndi camera.  camera must
%       be in non-tracking mode.
%
% Notes:
%   The function initializes tools in the static tracking mode.  see Polaris
%   documentation for additional details on static/dynamic tracking mode.
%
% See also:
%   ndi_camera, track
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp (2007)
% 

% check if the srom file is valid
if (~exist(filename,'file'))
    error('srom file (%s) does not exist',filename);
end

% Request the port handle
handle = comm(ndi,'PHRQ *********1****');
portHandle=str2double(char(handle(1:2)));

% Now access the srom file
fid = fopen(filename,'r');
sromDataSize=1024;
sentData=0;
nstr=64;

% SROM data has to be sent 128 bytes at a time.
% do so with the PVWR command
while ((sentData<sromDataSize) && (nstr==64))

    [str, nstr]=  fread(fid,64,'uchar=>uchar');
    if nstr==64
        hexadeciStr=sprintf('%02X',str);
    else
        hexadeciStr=sprintf('%02X',str);
        for i=size(hexadeciStr,2):128
            hexadeciStr(1,i)=sprintf('0');
        end
    end
 
    ndiCmd = sprintf('PVWR %02X%04X%s',portHandle,sentData,hexadeciStr);
    comm(ndi,ndiCmd);
    sentData=sentData+nstr;
end

% all data sent no need for the file anymore 
fclose(fid);

% Now initialize the port handle for the loaded srom
comm(ndi,sprintf('PINIT %02X',portHandle));
% Start the tool in static tracking mode
% Most of our applications are use tracker that are relatively static
comm(ndi,sprintf('PENA %02XS',portHandle));


%---- END OF FILE -----