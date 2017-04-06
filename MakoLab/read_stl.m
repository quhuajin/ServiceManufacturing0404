function [facets,vertices,color] = read_stl(filename)
%READ_STL Read an stl file to provide the facet and vertices data for patch command.
%
% Syntax:
%   [facets, vertices] = read_stl(stlFileName)
%       stlFileName is a string with the STL file name.  The STL file can be
%       ascii or Binary.  Facets and vertices are the respective data
%       elements read from the stl file.
%   [facets, vertices, color] = read_stl(stlFileName)
%       color is an optional parameter that can be read from the STL file if
%       needed.  
% Notes:
%   Unfortunately to detemine if a file is ascii or not the function will go
%   through the whole file byte by byte.  for ASCII STL files this is a  slow
%   process (reason for using this inefficient method documented in the code).
%   I would strongly recommend the use of BINARY STL FILES.  additionally if stl
%   files need to be read as part of a gui, i would recommend reading and saving
%   the data in a mat file.  This is much more efficient
%
%   If the file does not contain any color information, the
%   function will choose a dark grey color [0.66 0.66 0.66]
%   
%   teapotdemo is a useful demo that shows how to manipulate the patch object
%
% Example:
%   This is an example of how to read and display an stl file.  For this example
%   i will assume that there is an stl file ABCD.stl to be displayed.
% 
%   >> [face,vert,color] = read_stl('ABCD.stl');
%   >> patch('faces',face,'vertices',vert,'facec','flat',...
%           'FacevertexCdata',c,'edgecolor','none')
%   >> light  % this will help distinguish edges
%
% See also:
%   patch, show_stl, trasform_vertices, surface, teapotdemo
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%


if nargin == 0
    error('STL filename missing');
end

% Open the file assuming binary format.
fid=fopen(filename, 'r','l');
if fid == -1
    error('File could not be opened, check name or path.')
end

% Now check if the format is binary or ascii.  
if(isFileASCII(fid))
    [facets,vertices,color]=read_stl_ascii(fid);
else
    [facets,vertices,color]=read_stl_binary(fid);
end

fclose(fid);

end

%-----------------------------------------------------------------------------
% Internal function to check if file is binary or acii
%-----------------------------------------------------------------------------
function boolReturn = isFileASCII(fid)

% In theory this is simple for STL files.  the header should contain the word
% "solid" for ascii files and not for binary.  However i notice that some of our
% binary files at mako have the word solid in it.  Here i will check the whole
% file for non ascii chars and if any will declare it a binary file.  Obviously
% this is very slow
frewind(fid);
while(~feof(fid))
    % the whole vector stream read from the file should be checked.
    if (any(fgetl(fid)>128))
        % Non ascii char found declare as binary file
        boolReturn=false;
        return;
    end
end

% The whole file was checked and all bytes were valid ascii charecters
% assume this is ascii
boolReturn = true;
return;
end


%------------------------------------------------------------------------------
% Internal function to handle reading of binary stl files
%------------------------------------------------------------------------------

function [facets,vertices,color]=read_stl_binary(fid)

frewind(fid);

% The first 80 bytes are header(6 bytes) and file name(74 bytes)
header=fread(fid,80,'*char');
volName=sprintf('%s',header(7:74));

%next 4 bytes are number of facets
nfacets=fread(fid,1,'*uint32');

% pre fill the data for faster processing
v=zeros(3,nfacets*3);
cread=zeros(1,nfacets);

% Initialize the vertex number counter
vnum=1;

while(vnum<nfacets*3)
    %read normal
    fread(fid,3,'*float32');
    %read vertex
    v(:,vnum) = fread(fid,3,'*float32');
    v(:,vnum+1) = fread(fid,3,'*float32');
    v(:,vnum+2) = fread(fid,3,'*float32');
    vnum = vnum + 3;

    %read color
    cread(:,(vnum-1)/3) = fread(fid,1,'*uint16');

end

% If no color is specified default to grey
if (isempty(find(cread, 1)))
    c = ones(3,nfacets).*0.66;
else
    % Parse the color into corresponding rgb values
    r=bitshift(bitand(2^16-1, cread),-10);
    g=bitshift(bitand(2^11-1, cread),-5);
    b=bitand(2^6-1, cread);
    c=[r g b];
end

%Build face list; The vertices are in order, so just number them.
ifacets = 1:(nfacets*3);
F = reshape(ifacets, 3,nfacets);

%Return the faces and vertexs.
facets = F';
vertices=v';
color = c';

end

%------------------------------------------------------------------------------
% Internal function to handle reading of ascii stl files
%------------------------------------------------------------------------------
function [facets,vertices,color]=read_stl_ascii(fid)

frewind(fid);

% Render files take the form:
volName=fgetl(fid);

vnum=0;
VColor = 0;

% Start scanning file as per the standard STL file format.
% Reference: Wikipedia
while feof(fid) == 0
    tline = fgetl(fid);
    fword = sscanf(tline, '%s ');
    % Check for color
    if strncmpi(fword, 'c',1) == 1;
        VColor = sscanf(tline, '%*s %f %f %f');
    end
    if strncmpi(fword, 'v',1) == 1;
        vnum = vnum + 1;
        v(:,vnum) = sscanf(tline, '%*s %f %f %f');
        c(:,vnum) = VColor;
    end
end
%   Build face list; The vertices are in order, so just number them.
nfacets = int32(vnum/3);
ifacets = 1:vnum;
F = reshape(ifacets, 3,nfacets);
%   Return the faces and vertexs.
facets = F';
vertices=v';
color = c';

end


% --------- END OF FILE ----------