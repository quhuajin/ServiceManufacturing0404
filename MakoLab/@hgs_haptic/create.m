function hapticout=create(haptic,varargin)
%CREATE create a Hgs Haptic object
%
% Syntax:
%
%   CREATE(hapticObj,'param1',value1,'param2',
%          value2,...)
%    Create a haptic object in <hgs>, which is a hgs_robot object.
%    The haptic object share the same type as <hapticPrototype>,which is
%    created by hgs_haptic/hgs_haptic, and its name is <hapticObjName>,
%    which is an char array.
%
%   CREATE(hapticObj,fileNameSTL)
%    Create an haptic object<hapticObj> in a hgs_robot object from a
%    STL binary file <fileNameSTL>
%
%   CREATE(hapticObj,hgs,hapticObjName)
%    Create an haptic object<hapticObj> with the name <hapticObjName>
%    in a hgs_robot object<hgs>
%
% Notes:
%
% See also:
%   hgs_haptic/hgs_haptic,hgs_robot/status
%

%
% $Author: rzhou $
% $Revision: 3511 $
% $Date: 2014-06-06 10:49:22 -0400 (Fri, 06 Jun 2014) $
% Copyright: MAKO Surgical corp (2007)
%
%

if (nargin ==0)
    help('hgs_haptic/create');
elseif (nargin==1)
    if(isa(haptic,'hgs_haptic'))
        error('Directly create haptic object to be implemented.');
    else
        help('hgs_haptic/create');
    end
else
    %check if the input argument #2 is a stl file or not
   [pathstr,name,ext]=fileparts(varargin{1});
   
   if(strcmpi(ext,'.stl'))
       hapticObjName=haptic.name;
       
       [facets,vertices,color,nfacets,nvertices,ifacets,volName]=...
           read_stl(varargin{1});
       
       nameFields = regexp(hapticObjName,'___','split');
       switch nameFields{1}
           case 'Polygon'               
               %get polygon model data
               maxTriPerVoxel=29;
               scale_factor = single(1.0);
               resolution= single(1.0);
               
               [voxelData,facetData,vsizeData,hwiData,voxelMap]=mod2polygon(volName,...
                   nfacets,nvertices,ifacets,scale_factor,...
                   vertices,resolution, maxTriPerVoxel);
               
               voxGridSize=vsizeData;
               hapticWrtImplantVec=hwiData;
               valuePairs={...
                   'voxGridSize',voxGridSize,...
                   'maxTriPerVoxel',maxTriPerVoxel,...
                   'haptic_wrt_implant_vec',hapticWrtImplantVec,...
                   'data_facet',facetData,...
                   'maxTriangles',nfacets,...
                   'data_voxel',voxelData,...
                   'data_voxmap',voxelMap,...
                   varargin{(2:nargin-1)}
                   };
               
           case 'TriMeshVol'
               %get polygon model data
               maxTriPerVoxel=60;
               valuePairs={...
                   'numTriangles',nfacets,...
                   'maxTriPerVoxel',maxTriPerVoxel,...
                   'dataVertices',typecast(double(vertices),'uint8'),...
                   varargin{(2:nargin-1)}
                   };
           case 'AutoAlignTriMesh'
               %get polygon model data
               maxTriPerVoxel=60;
               valuePairs={...
                   'numTriangles',nfacets,...
                   'maxTriPerVoxel',maxTriPerVoxel,...
                   'dataVertices',typecast(double(vertices),'uint8'),...
                   varargin{(2:nargin-1)}
                   };
               
           case 'Polygon2'
               %get polygon model data
               maxTriPerVoxel=29;
               valuePairs={...
                   'numTriangles',nfacets,...
                   'maxTriPerVoxel',maxTriPerVoxel,...
                   'dataVertices',typecast(double(vertices),'uint8'),...
                   varargin{(2:nargin-1)}
                   };
       end

       comm(haptic.hgsRobot,'create_haptic_object',hapticObjName,...
           valuePairs{:});
       hapticout.isHapticObjInRobot=true;

   else
       hapticObjName=haptic.name;
       comm(haptic.hgsRobot,'create_haptic_object',hapticObjName,varargin{:});
       haptic.isHapticObjInRobot=true;
       [local,inputs]=get(haptic);

       fnInputs=fieldnames(inputs);

       for j=1:length(fnInputs)
           try
            haptic.inputVars(j).value=inputs.(haptic.inputVars(j).name);
           catch %#ok<CTCH>
           end
       end
   end

end

hapticout=haptic;

end




% --------- END OF FILE ----------