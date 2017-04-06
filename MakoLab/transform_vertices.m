function transformedVerts = transform_vertices(verts,transform,ypr)
%TRANSFORM_VERTICES Multiply the transform to all the vertices 
%
% Syntax:
%   transfromedVerts = transfrom_vertices(verts,transform)
%       Where the argument "verts" is the set of vertices that can be used
%       with the patch command.  This is equvivalent to multiplying each of
%       the vertices with the transform, thus effectively moving the object
%       to a new location.  Argument Transform is a 4X4 transform that needs to be
%       multiplied to all the vertices
%
%   transfromedVerts = transfrom_vertices(verts,pos)
%       if the 2nd argument is a vector with 3 elements, this function will
%       just change the position of all the vertices
%
%   transfromedVerts = transfrom_vertices(verts,pos,ypr)
%       If the 2nd argument is a vector the function will also accept a 3rd
%       argument.  this will be an angle vector represented in the standard
%       ypr format
%
% Example:
%   This is an example of how to read and display an stl file.  For this example
%   i will assume that there is an stl file ABCD.stl to be displayed.
% 
%   >> [face,vert,color] = read_stl('ABCD.stl');
%   >> phandle  = patch('faces',face,'vertices',vert,'facec','flat',...
%           'FacevertexCdata',c,'edgecolor','none')
%   >> light % this will help distinguish edges
%
%   Now to move the object by 2 m in X dir and 3 m in y direction 
%   transform = [1 0 0 2; 0 1 0 3; 0 0 1 0; 0 0 0 1];
%   set(phandle,'vertices',transform_vertices(verts,tranform));
%
%   or 
%   set(phandle,'vertices',transform_vertices(verts,[2 3 0]));
%
% See also:
%   patch, show_stl, read_stl
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%

% check if this is a valid 4X4 transform
dim = size(transform);

% if not construct the transform from the position and angle information
if ((dim(1)~=4) || (dim(2)~=4))
    
    pos = transform;
    
    if nargin==3
        sx = sin(ypr(1));
        cx = cos(ypr(1));
        sy = sin(ypr(2));
        cy = cos(ypr(2));
        sz = sin(ypr(3));
        cz = cos(ypr(3));
        
        transform = [...
            cy*cz   sx*sy*cz-cx*sz  cx*sy*cz+sx*sz      pos(1);
            cy*sz   sx*sy*sz+cx*cz  cx*sy*sz-sx*cz      pos(2);
            -sy     sx*cy           cx*cy               pos(3);
            0       0               0                   1;
            ];
        
    else
        transform = eye(4);
        transform(1:3,4) = pos';
    end     
end

dim = size(verts);

transformedVerts = transform*[verts,ones(dim(1),1)]';
transformedVerts = transformedVerts(1:3,:)';

end


% --------- END OF FILE ----------