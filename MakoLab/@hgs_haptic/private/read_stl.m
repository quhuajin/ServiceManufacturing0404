function [facets,vertices,color,nfacets,nvertices,ifacets,volName] = read_stl(filename)
% Reads CAD STL BINARY files, which most CAD programs can export.
% Used to create Matlab patches of CAD 3D data.
% Returns a vertex list and face list, for Matlab patch command.
%
if nargin == 0
    error('STL filename missing');
end

fid=fopen(filename, 'r','l'); %Open the file, assumes STL binary format.
if fid == -1
    error('File could not be opened, check name or path.')
end

if(strcmp(fgetl(fid),'solid'))
    [facets,vertices,color,nfacets,nvertices,ifacets,volName]=read_stl_asc(fid);
else
    [facets,vertices,color,nfacets,nvertices,ifacets,volName]=read_stl_bin(fid);
end


fclose(fid);

end

function [facets,vertices,color,nfacets,nvertices,ifacets,volName]=read_stl_bin(fid)


fseek(fid,0,'bof');

% The first 80 bytes are header(6 bytes) and file name(74 bytes)
header=fread(fid,80,'*char');

volName=sprintf('%s',header(7:74));

%next 4 bytes are number of facets
nfacets=fread(fid,1,'*uint32');

nvertices=nfacets*3;

v=zeros(3,nfacets*3);
c=zeros(1,nfacets*3);

%
vnum=0;       %Vertex number counter.

while(vnum<nfacets*3)
    %read normal
fread(fid,3,'*float32'); 
    %read vertex
    vnum = vnum + 1;
    v(:,vnum) = fread(fid,3,'*float32'); 
    vnum = vnum + 1;
    v(:,vnum) = fread(fid,3,'*float32'); 
    vnum = vnum + 1;
    v(:,vnum) = fread(fid,3,'*float32'); 
    %read color
    c(:,vnum) = fread(fid,1,'*uint16');
end
%Build face list; The vertices are in order, so just number them.
fnum = vnum/3;      
ifacets = 1:vnum;     
F = reshape(ifacets, 3,fnum); 

%Return the faces and vertexs.
facets = F';  
vertices=single(reshape(v,1,vnum*3));
color =c';

ifacets=int32(ifacets-1);

end

function [facets,vertices,color,nfacets,nvertices,ifacets,volName]=read_stl_asc(fid)

fseek(fid,0,'bof');
%
% Render files take the form:
%
volName=fgetl(fid); 
 
vnum=0;       
VColor = 0;
%
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
vertices=single(reshape(v,1,vnum*3));
color =uint16(c');
nvertices=int32(vnum);
ifacets=int32(ifacets-1);

end

% --------- END OF FILE ----------
