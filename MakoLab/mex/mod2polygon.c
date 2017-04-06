/****h* $RCSfile: mod2polygon.c,v $ ***
 * NAME
 *      $RCSfile: mod2polygon.c,v $    $Revision: 3020 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function convert stl file to polygon object data
 *
 * SEE ALSO
 *
 *
 * CVS INFORMATION
 *      $Revision: 3020 $
 *      $Date: 2013-06-28 10:13:25 -0400 (Fri, 28 Jun 2013) $
 *      $Author: jforsyth $
 *
 ***************
 */
#include "mex.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>


#define DEBUG 1
#define FALSE 0
#define TRUE 1
#define MODALITY_LEN 7
#define MAX_TRI_PER_VOX 29
#define MM2M 0.001;
#define EPSILON 1e-12


#define x_6n(n, x) \
	((n == 0) ? x+1 : \
	((n == 1) ? x   : \
	((n == 2) ? x-1 : \
	((n == 3) ? x   : \
	((n == 4) ? x   : \
	((n == 5) ? x   : \
			    x   ))))))
#define y_6n(n, y) \
	((n == 0) ? y   : \
	((n == 1) ? y-1 : \
	((n == 2) ? y   : \
	((n == 3) ? y+1 : \
	((n == 4) ? y   : \
	((n == 5) ? y   : \
			    y   ))))))
#define z_6n(n, z) \
	((n == 0) ? z   : \
	((n == 1) ? z   : \
	((n == 2) ? z   : \
	((n == 3) ? z   : \
	((n == 4) ? z-1 : \
	((n == 5) ? z+1 : \
			    z   ))))))

typedef struct {
    char *volName;
    char modality[MODALITY_LEN + 1];
    int xDim, yDim, zDim;
    float xRes, yRes, zRes;
    float scale;
    float gantryTilt;
    int orientValid;
    int numtriangles;
    float stdTrans[4][4];
    float regTrans[4][4];
    unsigned short *voxelPtr;
    unsigned char *voxelMap;
    float *facetPtr;
    unsigned short maxPix;
    unsigned short minPix;
} Polygon;

typedef struct{
    float x;
    float y;
    float z;
}Point;

/*
 * Prototypes for functions referenced only in this file
 */

int model2Polygon (
		char *volName,
		int numtriangles,
		int numvertices,
		int *triIndex,
		int maxTriPerVox,
		float scaleFactor,
		float *vertex,
		float resolution,
		unsigned char *voxelDataOut,
		unsigned char *facetDataOut,
		double *vsizeDataOut,
		double *hwiDataOut,
        unsigned char *voxelMapOut);

void computeModelBounds (int numtriangles,
		float triSurface[][3][3],
		float maxBound[3],
		float minBound[3]);

void generatePolygonMap(Polygon *vPtr,
		int numtriangles,
		int maxTrianglePerVoxel,
		float triSurface[][3][3],
		float maxBounds[],
		float minBounds[],
		float haptic_wrt_implant[]);

void computeFacetBounds(float triangle[3][3],
		float minBounds[3],
		float maxBounds[3]);

void findClosestPointOnTriangle(float *orig,
		float *dir, float *vert0,
		float *vert1, float *vert2,
		float *interp);

void projectOnTriangleEdge(float *c,
		float *p, float *q,
		float *cproj);

int get_num_of_voxels(
		int numtriangles,
		int numvertices,
		int *triIndex,
		float scaleFactor,
		float *vertex,
		float resolution);
void ComputeVoxelMap (int x,int y, int z,Polygon *vPtr, int maxTrianglePerVoxel);
int ClosestPointOnTriangle(float *p, float *a, float *b, float *c, float *ip);
void GenerateVoxelMap(Polygon *vPtr, int maxTrianglePerVoxel);
int CheckDuplicateVox (Point *voxelList, int nVoxels, int x, int y, int z);
/*
 *------------------------------------------------------------------------
 *  mexFunction
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void mexFunction(int nlhs, mxArray *plhs[],
				int nrhs, const mxArray *prhs[])
{
    char *volName;
    int numtriangles;
    int numvertices;
    int *triIndex;
    float scaleFactor;
    float *vertex;
    float resolution;
     
    unsigned char *voxelDataOut;
    unsigned char *facetDataOut;
    double *vsizeDataOut;
    double *hwiDataOut;
    unsigned char *voxelMapOut;
	int dims[2];
    
    
    int lengthName;
    int nvoxels;
    int maxTriPerVox;
    
    lengthName=(int)mxGetN(prhs[0])+1;
    
    volName=(char*)mxCalloc(lengthName,sizeof(char));
    
    /*get the input arguments */
	/*check for proper number of input and output arguments */
    if(nrhs == 7){
		/* default the maxTriPerVox */
		maxTriPerVox = MAX_TRI_PER_VOX;
    }
	else if (nrhs == 8) {
		maxTriPerVox = (int)mxGetScalar(prhs[7]);
	}
	else {
        mexErrMsgTxt("Invalid number of arguments for mex function <mod2polygon>");
	}


    mxGetString(prhs[0],volName,lengthName);
    numtriangles=(int)mxGetScalar(prhs[1]);
    numvertices=(int)mxGetScalar(prhs[2]);
    triIndex=(int *)mxGetPr(prhs[3]);
    scaleFactor=(float)mxGetScalar(prhs[4]);
    vertex=(float *)mxGetPr(prhs[5]);
    resolution=(float)mxGetScalar(prhs[6]);
    
    /*get number of voxels */
    nvoxels= get_num_of_voxels(
			numtriangles,
			numvertices,
			triIndex,
			scaleFactor,
			vertex,
			resolution);
    
	dims[0]=1;
	dims[1]=nvoxels*(maxTriPerVox+1)*sizeof(unsigned short);    
	plhs[0]=mxCreateNumericArray(2, dims,mxUINT8_CLASS, mxREAL);

	dims[1]=numtriangles*12*sizeof(float);
	plhs[1]=mxCreateNumericArray(2, dims,mxUINT8_CLASS, mxREAL);
	
    dims[1]=3;
	plhs[2]=mxCreateNumericArray(2, dims,mxDOUBLE_CLASS, mxREAL);
	plhs[3]=mxCreateNumericArray(2, dims,mxDOUBLE_CLASS, mxREAL);   
    
    dims[1]=nvoxels;
    plhs[4]=mxCreateNumericArray(2, dims, mxUINT8_CLASS, mxREAL);
    
    voxelDataOut=(unsigned char*)mxGetPr(plhs[0]);
    facetDataOut=(unsigned char*)mxGetPr(plhs[1]);
    vsizeDataOut=mxGetPr(plhs[2]);
    hwiDataOut=mxGetPr(plhs[3]);
    voxelMapOut=(unsigned char *)mxGetPr(plhs[4]);
   
    model2Polygon (
			volName,
			numtriangles,
			numvertices,
			triIndex,
			maxTriPerVox,
			scaleFactor,
			vertex,
			resolution,
			voxelDataOut,
			facetDataOut,
			vsizeDataOut,
			hwiDataOut,
            voxelMapOut);  
}

/*
 *------------------------------------------------------------------------
 *  Model2Polygon
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */

int model2Polygon (
		char *volName,
		int numtriangles,
		int numvertices,
		int *triIndex,
		int maxTrianglePerVoxel,
		float scaleFactor,
		float *vertex,
		float resolution,
		unsigned char *voxelDataOut,
		unsigned char *facetDataOut,
		double *vsizeDataOut,
		double *hwiDataOut,
        unsigned char *voxelMapOut)
{
    Polygon *vPtr;
    float *triSurface;
    
    int i, j, idx;
    int xDim, yDim, zDim, nvoxels;
    
    float maxBounds[3], minBounds[3];
    unsigned short voxel_size[3];
    float haptic_wrt_implant[3];
    
    unsigned short *voxels;
    float *facets;
    
    
    if ((vPtr = (Polygon *) malloc (sizeof (Polygon))) == NULL) {
        perror ("Can't alloc memory for polygon structure");
        return -1;
    }
    
    if ((triSurface = (float *) malloc (numvertices*3*sizeof (float))) == NULL) {
        perror ("Can't alloc memory for triangle array");
        return -1;
    }
    

  /* map into voxel coordinate */
    for (i = 0; i < numtriangles; i++) {
        for (j = 0; j < 3; j++) {
            idx = triIndex[i * 3 + j];
            if (idx < 0 || idx > (numvertices - 1))
                fprintf (stderr, "ERROR: triangle %d vertex %d not defined!\n", i, j);
            else
            {
                triSurface[i * 9 + j * 3 + 0] = scaleFactor * vertex[idx * 3 + 0] / resolution;
                triSurface[i * 9 + j * 3 + 1] = scaleFactor * vertex[idx * 3 + 1] / resolution;
                triSurface[i * 9 + j * 3 + 2] = scaleFactor * vertex[idx * 3 + 2] / resolution;
            }
        }
    }
  /* compute object bounds */
    computeModelBounds (numtriangles, (float (*)[3][3]) triSurface,
    maxBounds, minBounds);
  /* translate triangle coords to be within minimum bounds */
    for (i = 0; i < numtriangles; i++) {
        for (j = 0; j < 3; j++) {
            triSurface[i * 9 + j * 3 + 0] = triSurface[i * 9 + j * 3 + 0] - minBounds[0];
            triSurface[i * 9 + j * 3 + 1] = triSurface[i * 9 + j * 3 + 1] - minBounds[1];
            triSurface[i * 9 + j * 3 + 2] = triSurface[i * 9 + j * 3 + 2] - minBounds[2];
        }
    }
  /* compute the position vector of haptic origin w.r.t. the implant origin */
    for (i = 0; i < 3; i++)
        haptic_wrt_implant[i] = minBounds[i];
    
  /* re-compute object bounds */
    computeModelBounds (numtriangles, (float (*)[3][3]) triSurface,
    maxBounds, minBounds);
  /* Initialize Voxel */
    xDim = (int)ceil(maxBounds[0]) - (int)floor(minBounds[0]);
    yDim = (int)ceil(maxBounds[1]) - (int)floor(minBounds[1]);
    zDim = (int)ceil(maxBounds[2]) - (int)floor(minBounds[2]);
    
    voxel_size[0]=(unsigned short)xDim;
    voxel_size[1]=(unsigned short)yDim;
    voxel_size[2]=(unsigned short)zDim;
    
    nvoxels = xDim * yDim * zDim;
    
    vPtr->volName = (char *) malloc (strlen (volName) + 1);
    memcpy (vPtr->volName, volName,strlen(volName));
    vPtr->scale = scaleFactor;
    vPtr->xDim = xDim;
    vPtr->yDim = yDim;
    vPtr->zDim = zDim;
    vPtr->xRes = resolution;
    vPtr->yRes = resolution;
    vPtr->zRes = resolution;
    vPtr->numtriangles=numtriangles;
    
    /* each voxel has maxTrianglePerVoxel + 1 elements */
    vPtr->voxelPtr = (unsigned short *) malloc (
			nvoxels * (maxTrianglePerVoxel+1) *
			sizeof (unsigned short));
    memset (vPtr->voxelPtr, 0,
			nvoxels * (maxTrianglePerVoxel+1) *
			sizeof(unsigned short));
    /* memory for voxel map */
    vPtr->voxelMap = (unsigned char *) malloc (nvoxels *sizeof(unsigned char));
    memset (vPtr->voxelMap, 0, nvoxels * sizeof(unsigned char));
    
    
  /* intialize the memory for voxel data map */
    for (i=0;i<nvoxels*(maxTrianglePerVoxel+1);i++) {
        vPtr->voxelPtr[i] = 0;
    }
    
  /* each facet has 12 elements, 3 for normal and 9 for three vertices */
    vPtr->facetPtr = (float *)malloc(numtriangles * 12 * sizeof(float));
    memset (vPtr->facetPtr, 0, numtriangles * 12 * sizeof(float));
    
  /* this variable is not used, but need to be deleted later */
    vPtr->orientValid = 1;;
  /* generate polygon map */
    generatePolygonMap(vPtr, numtriangles, maxTrianglePerVoxel,
			(float (*)[3][3]) triSurface,
			maxBounds, minBounds,haptic_wrt_implant);
 
    if ((voxels = (unsigned short *)malloc(
    nvoxels * (maxTrianglePerVoxel + 1) *
    sizeof (unsigned short)))==NULL) {
        perror("Can't allocate voxel data");
        return -1;
    }
    for (i=0;i<nvoxels*(maxTrianglePerVoxel+1);i++) {
        voxels[i] = (unsigned short)(vPtr->voxelPtr[i]);
    }
    if ((facets =
    (float *)malloc( numtriangles * 12* sizeof (float)))==NULL) {
        perror ("Can't allocate facet data");
        return -1;
    }
    for (i=0;i<numtriangles*12;i++) {
        facets[i] = (float)(vPtr->facetPtr[i]);
    }
    memcpy(voxelDataOut,voxels,nvoxels*(maxTrianglePerVoxel+1)*sizeof(unsigned short));
    memcpy(facetDataOut,facets,numtriangles*12*sizeof(float));    
    memcpy(voxelMapOut,vPtr->voxelMap, nvoxels * sizeof(char));   
    
    for(i=0;i<3;i++)
    {
        vsizeDataOut[i]=(double)(voxel_size[i]);
        hwiDataOut[i]=(double)(haptic_wrt_implant[i])*MM2M;
    }    
    
    free(vPtr->volName);
    free(vPtr->voxelPtr);
    free(vPtr->facetPtr);
    free(vPtr->voxelMap);
    free (vPtr);
    free (triSurface);
    free ((void *) voxels);
    free ((void *) facets);
    return 1;
}


/*
 *------------------------------------------------------------------------
 *  computeModelBounds
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void computeModelBounds (int numtriangles,
float triSurface[][3][3],
float maxBound[3],
float minBound[3])
{
    int i, j;
    float maxX, maxY, maxZ, minX, minY, minZ;
    
    minX = triSurface[0][0][0];
    minY = triSurface[0][0][1];
    minZ = triSurface[0][0][2];
    maxX = minX; maxY = minY; maxZ = minZ;
    
    for (i = 0; i < numtriangles; i++) {
        for (j = 0; j < 3; j++) {
            if (triSurface[i][j][0] < minX)
                minX = triSurface[i][j][0];
            if (triSurface[i][j][1] < minY)
                minY = triSurface[i][j][1];
            if (triSurface[i][j][2] < minZ)
                minZ = triSurface[i][j][2];
            
            if (triSurface[i][j][0] > maxX)
                maxX = triSurface[i][j][0];
            if (triSurface[i][j][1] > maxY)
                maxY = triSurface[i][j][1];
            if (triSurface[i][j][2] > maxZ)
                maxZ = triSurface[i][j][2];
        }
    }
    maxBound[0] = maxX+2;
    maxBound[1] = maxY+2;
    maxBound[2] = maxZ+2;
    
    minBound[0] = minX-2;
    minBound[1] = minY-2;
    minBound[2] = minZ-2;
}

/*
 *------------------------------------------------------------------------
 *  generatePolygonMap
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void generatePolygonMap(Polygon *vPtr,
int numtriangles,
int maxTrianglePerVoxel,
float triSurface[][3][3],
float maxBounds[],
float minBounds[],
float haptic_wrt_implant[])
{
    unsigned short *voxels = vPtr->voxelPtr;
    float *facets = vPtr->facetPtr;
    int i, j, it, ix, iy, iz;
    int xDim = vPtr->xDim, yDim = vPtr->yDim, zDim = vPtr->zDim;
    float nvec[3], t1vec[3], t2vec[3],*normals;
    float triangle[3][3], minB[3], maxB[3];
    float magVec;
    int lBound[3],uBound[3],ip;
    unsigned int offset;
    float scale=vPtr->scale, resolution[3];
    float colDistance;
    float triVert0[3], triVert1[3], triVert2[3], triNormal[3];
    float voxelCenter[3], intersectPos[3], intersectVec[3], intersectDistance;
    int addFlag, num_triangles, voxel_map_size;
    int maxTriangles, maxTriangleVoxelIndex;
    int maxTriangleVoxelXYZ[3];
    int voxel_size[3];
    FILE *fid;
    
    maxTriangles =0;
    maxTriangleVoxelIndex=0;
    
    resolution[0]=vPtr->xRes;
    resolution[1]=vPtr->yRes;
    resolution[2]=vPtr->zRes;
    
    voxel_size[0] = xDim;
    voxel_size[1] = yDim;
    voxel_size[2] = zDim;
    
    
  /* compute the distance to check a collision from
   * voxel center to a closest point on a triangle
   */
    colDistance = (float)sqrt((double)(
    resolution[0] * resolution[0] +
    resolution[1] * resolution[1] +
    resolution[2] * resolution[2]))/2.0;
    
    normals = (float *) malloc(numtriangles * 3 * sizeof(float));
    memset (normals, 0, numtriangles * 3 * sizeof(float));
    
    voxel_map_size = xDim * yDim * zDim * (maxTrianglePerVoxel + 1);
    for (i = 0; i < voxel_map_size; i++) {
        voxels[i] = 0;
    }
    
  /* compute normal for each triangle */
    for (it = 0; it < numtriangles; it++) {
        t1vec[0] = triSurface[it][1][0] - triSurface[it][0][0];
        t1vec[1] = triSurface[it][1][1] - triSurface[it][0][1];
        t1vec[2] = triSurface[it][1][2] - triSurface[it][0][2];
        t2vec[0] = triSurface[it][2][0] - triSurface[it][0][0];
        t2vec[1] = triSurface[it][2][1] - triSurface[it][0][1];
        t2vec[2] = triSurface[it][2][2] - triSurface[it][0][2];
        nvec[0] =  t1vec[1] * t2vec[2] - t1vec[2] * t2vec[1];
        nvec[1] =  t1vec[2] * t2vec[0] - t1vec[0] * t2vec[2];
        nvec[2] =  t1vec[0] * t2vec[1] - t1vec[1] * t2vec[0];
        
        magVec = sqrt(nvec[0] * nvec[0] +
        nvec[1] * nvec[1] +
        nvec[2] * nvec[2]);
        magVec = (magVec>0) ? magVec : 1.0;
        for (i = 0; i < 3; i++)
            normals[it * 3 + i] = nvec[i]/magVec;
        
        for (i = 0; i < 3; i++)
            facets[it * 12 + i] = normals[it * 3 + i];
    }
  /*******************************************************
   * Compute the Bounding Box for each triangle
   * *****************************************************/
    for (it = 0; it < numtriangles; it++) {
    /* Select a triangle */
        for (i = 0; i < 3; i++) {
            triangle[i][0] = triSurface[it][i][0];
            triangle[i][1] = triSurface[it][i][1];
            triangle[i][2] = triSurface[it][i][2];
            /* vertex in mm */
            triVert0[i] = triSurface[it][0][i] * resolution[0] /scale;
            triVert1[i] = triSurface[it][1][i] * resolution[1] /scale;
            triVert2[i] = triSurface[it][2][i] * resolution[2] /scale;
            triNormal[i] = normals[it * 3 + i];
        }
    /* Compute the bounding box for triangle */
        computeFacetBounds(triangle, minB, maxB);
        for (j = 0; j < 3; j++) {
            lBound[j]=(int)floor(minB[j]);
            uBound[j]=(int)ceil(maxB[j]);
        }
    /* need to adjust when the triangle is parallel
     * to voxel surface */
        for ( i = 0; i < 3; i++) {
            if ( lBound[i] == uBound[i] ) {
                if ( lBound[i] == 0 ) uBound[i] = uBound[i]+1;
                else {
                    if ( uBound[i] == voxel_size[i] ) lBound[i] = lBound[i]-1;
                    else {
                        lBound[i] = lBound[i]-1;
                        uBound[i] = uBound[i]+1;
                    }
                }
            }
        }
        for (ix = lBound[0]; ix < uBound[0]; ix++) {
            for (iy = lBound[1]; iy < uBound[1]; iy++) {
                for (iz = lBound[2]; iz < uBound[2]; iz++) {
                    /* compute the center of each voxel */
                    voxelCenter[0] = (float)ix * resolution[0] + resolution[0]/2.0;
                    voxelCenter[1] = (float)iy * resolution[1] + resolution[1]/2.0;
                    voxelCenter[2] = (float)iz * resolution[2] + resolution[2]/2.0;
                    ClosestPointOnTriangle(voxelCenter, triVert0, triVert1, triVert2, intersectPos);
                    /*ClosestPointOnTriangle(voxelCenter, triVert0, triVert1, triVert2, intersectPos);*/
                    /* compute the distance from the center of voxel */
                    /* to the closest point on a triangle */
                    intersectDistance = 0.0;
                    for (i = 0; i < 3; i++) {
                        intersectVec[i] = intersectPos[i] - voxelCenter[i];
                        
                        intersectDistance += intersectVec[i] * intersectVec[i];
                    }
                    intersectDistance = (float)sqrt((double)intersectDistance);
                    if ( intersectDistance < colDistance) { /* intersected */
                        ip = (ix + iy * xDim + iz * xDim * yDim) * (maxTrianglePerVoxel + 1);
                        num_triangles = (int)((unsigned short *)voxels)[ip];
                        if (num_triangles == 0) { /* No triangle was registered in this voxel */
                            voxels[ip+1] = (unsigned short)it;
                            voxels[ip+0] = (unsigned short)1;
                        }
                        else {
                            addFlag = 1;
                            for (i = 0; i < num_triangles; i++) {
                                if (it == (int)((unsigned short *)voxels)[ip + 1 + i])
                                    addFlag = 0;
                            }
                            if (addFlag == 1) {
                                voxels[ip + 1 + i] = it;
                                voxels[ip + 0] = num_triangles + 1;
                                if (num_triangles+1>maxTriangles) {
                                    maxTriangles = num_triangles+1;
                                    maxTriangleVoxelIndex = ip;
                                    maxTriangleVoxelXYZ[0]=ix;
                                    maxTriangleVoxelXYZ[1]=iy;
                                    maxTriangleVoxelXYZ[2]=iz;
                                }
                            }                            
                        }
                    }
                }
            }
        }
    }

    /* generate voxel map */
    /* ComputeVoxelMap(0,0,0,vPtr, maxTrianglePerVoxel); */
   GenerateVoxelMap(vPtr, maxTrianglePerVoxel); 

  /* translate the vertex in the voxel space into the original space */
    for (it = 0; it < numtriangles; it++) {
        for ( i = 0; i< 3; i++) {
            for (j=0;j<3;j++) {
                triSurface[it][i][j] = triSurface[it][i][j]+haptic_wrt_implant[j];
            }
        }
    }
    for (it = 0; it < numtriangles; it++) {
    /* STL file created in mm unit, so need to scale to m */
        for (i = 0; i < 3; i++)
            for (j = 0; j < 3; j++)
                facets[it * 12 + i * 3 + j + 3] = (float)
                triSurface[it][i][j] *
                resolution[j] / scale / 1000.0;
    }

    free ((void *) normals);
}

/*
 *------------------------------------------------------------------------
 *  computeFacetBounds
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void computeFacetBounds(
float triangle[3][3],
float minBounds[3],
float maxBounds[3])
{
    int i, j;
    for (j = 0; j < 3; j++) {
        minBounds[j] = triangle[0][j];
        maxBounds[j] = triangle[0][j];
    }
    for (j = 0; j < 3; j++) {
        for (i = 0; i < 3; i++) {
            if (triangle[i][j] < minBounds[j])
                minBounds[j] = triangle[i][j];
            if (triangle[i][j] > maxBounds[j])
                maxBounds[j] = triangle[i][j];
        }
    }
}

/*
 *------------------------------------------------------------------------
 *  findClosestPointOnTriangle
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void findClosestPointOnTriangle(float *orig, float *dir,
float *vert0, float *vert1,
float *vert2, float *interp)
{
    int i;
    float edge1[3],edge2[3],pvec[3],tvec[3],qvec[3],c[3];
    float det, inv_det;
    float u,v,t;
    /* find vectors for two edges sharing vert0 */
    for (i=0;i<3;i++) {
        edge1[i] = vert1[i]-vert0[i];
        edge2[i] = vert2[i]-vert0[i];
    }
    /* begin calculating determinant */
    pvec[0]=dir[1]*edge2[2]-dir[2]*edge2[1];
    pvec[1]=dir[2]*edge2[0]-dir[0]*edge2[2];
    pvec[2]=dir[0]*edge2[1]-dir[1]*edge2[0];
    /* if determinant is near zero, ray lies in plane of triangle */
    det = edge1[0]*pvec[0]+edge1[1]*pvec[1]+edge1[2]*pvec[2];
    inv_det =(float) 1.0 / det;
    /* calculate distance from vert0 to ray origin */
    for(i=0;i<3;i++) {
        tvec[i]=orig[i]-vert0[i];
    }
    /*calculate u parameter and test bounds */
    u = (tvec[0]*pvec[0]+tvec[1]*pvec[1]+tvec[2]*pvec[2])*inv_det;
    /* prepare to test v parameter */
    qvec[0]=tvec[1]*edge1[2]-tvec[2]*edge1[1];
    qvec[1]=tvec[2]*edge1[0]-tvec[0]*edge1[2];
    qvec[2]=tvec[0]*edge1[1]-tvec[1]*edge1[0];
    /* calculate v parameter and test bounds */
    v = (dir[0] * qvec[0] + dir[1] * qvec[1] + dir[2] * qvec[2])*inv_det;
    t = (edge2[0]*qvec[0] + edge2[1]*qvec[1] + edge2[2]*qvec[2])*inv_det;
    
    /* region G */
    if ( u >= 0.0 && v >= 0.0 && (u+v) <= 1.0 ) {
        for (i = 0; i < 3; i++)
            *(interp+i) = orig[i]+t*dir[i];
    }
    /* region A */
    else if ( u < 0.0 && v < 0.0 && (u+v) <= 1.0 ) {
        for (i = 0; i < 3; i++)
            *(interp+i) = vert0[i];
    }
    /* region C */
    else if ( u >= 0.0 && v < 0.0 && (u+v) > 1.0 ) {
        for (i = 0; i < 3; i++)
            *(interp+i) = vert1[i];
    }
    /* region E */
    else if ( u < 0.0 && v >= 0.0 && (u+v) > 1.0 ) {
        for (i = 0; i < 3; i++)
            *(interp+i) = vert2[i];
    }
    /* region B */
    else if ( u >= 0.0 && v < 0.0 && (u+v) <= 1.0 ) {
        for(i=0;i<3;i++)
            c[i] = orig[i]+t*dir[i];
        projectOnTriangleEdge(c, vert0, vert1, interp);
    }
    /* region D */
    else if ( u >= 0.0 && v >= 0.0 && (u+v) > 1.0 ) {
        for(i=0;i<3;i++)
            c[i] = orig[i]+t*dir[i];
        projectOnTriangleEdge(c, vert1, vert2, interp);
    }
    /* region F */
    else{
        for(i=0;i<3;i++)
            c[i] = orig[i] + t * dir[i];
        projectOnTriangleEdge(c, vert2, vert0, interp);
    }
}

/*
 *------------------------------------------------------------------------
 *  projectOnTriangleEdge
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
void projectOnTriangleEdge(float *c, float *p, float *q, float *cproj)
{
    int i;
    float lamda;
    float qp[3], cp[3], d1,d2;
    
    for (i=0;i<3;i++) {
        cp[i] = c[i] - p[i];
        qp[i] = q[i] - p[i];
    }
    d1 = cp[0]*qp[0] + cp[1]*qp[1] + cp[2]*qp[2];
    d2 = qp[0]*qp[0] + qp[1]*qp[1] + qp[2]*qp[2];
    lamda = d1/d2;
    if (lamda > 1.0) lamda = 1.0;
    if (lamda < 0.0) lamda = 0.0;
    for (i=0;i<3;i++)
        *(cproj+i) = p[i] + lamda * qp[i];
}

/*
 *------------------------------------------------------------------------
 *  get_num_of_voxels
 *
 *
 * Description:
 *
 *
 * Results:
 *
 *
 * Side effects:
 *     None
 *
 *------------------------------------------------------------------------
 */
int get_num_of_voxels(
int numtriangles,
int numvertices,
int *triIndex,
float scaleFactor,
float *vertex,
float resolution
)
{
    float maxBounds[3], minBounds[3];
    int idx;
    int i,j;
    float *triSurface;
    int xDim,yDim,zDim;
    int nvoxels;
    
    
    if ((triSurface = (float *) malloc (numvertices*3*sizeof (float))) == NULL) {
        perror ("Can't alloc memory for triangle array");
        return -1;
    }

    
  /* map into voxel coordinate */
    for (i = 0; i < numtriangles; i++) {
        for (j = 0; j < 3; j++) {
            idx = triIndex[i * 3 + j];
            if (idx < 0 || idx > (numvertices - 1))
                fprintf (stderr, "ERROR: triangle %d vertex %d not defined!\n", i, j);
            else
            {
                triSurface[i * 9 + j * 3 + 0] = scaleFactor * vertex[idx * 3 + 0] / resolution;
                triSurface[i * 9 + j * 3 + 1] = scaleFactor * vertex[idx * 3 + 1] / resolution;
                triSurface[i * 9 + j * 3 + 2] = scaleFactor * vertex[idx * 3 + 2] / resolution;
            }
        }
    }
  /* compute object bounds */
    computeModelBounds (numtriangles, (float (*)[3][3]) triSurface,
    maxBounds, minBounds);
  /* translate triangle coords to be within minimum bounds */
    for (i = 0; i < numtriangles; i++) {
        for (j = 0; j < 3; j++) {
            triSurface[i * 9 + j * 3 + 0] = triSurface[i * 9 + j * 3 + 0] - minBounds[0];
            triSurface[i * 9 + j * 3 + 1] = triSurface[i * 9 + j * 3 + 1] - minBounds[1];
            triSurface[i * 9 + j * 3 + 2] = triSurface[i * 9 + j * 3 + 2] - minBounds[2];
        }
    }
    
  /* re-compute object bounds */
    computeModelBounds (numtriangles, (float (*)[3][3]) triSurface,
    maxBounds, minBounds);
  /* Initialize Voxel */
    xDim = (int)ceil(maxBounds[0]) - (int)floor(minBounds[0]);
    yDim = (int)ceil(maxBounds[1]) - (int)floor(minBounds[1]);
    zDim = (int)ceil(maxBounds[2]) - (int)floor(minBounds[2]);
    
    nvoxels = xDim * yDim * zDim;
    
    free(triSurface);
    
    return nvoxels;
}

void ComputeVoxelMap (int x,int y, int z,Polygon *vPtr, int maxTrianglePerVoxel)
{
  int i, ix, iy, iz;
  int voxLoc = x + y * vPtr->xDim + z*vPtr->xDim * vPtr->yDim;
  int triLoc = voxLoc * (maxTrianglePerVoxel + 1);
  if (vPtr->voxelPtr[triLoc] < 1)
    {
      vPtr->voxelMap[voxLoc] = 1;
         /* printf("\{%d %d %d\} ", x, y, z); */
      for (i = 0; i < 6; i++) {
        ix = x_6n(i, x);
        iy = y_6n(i, y);
        iz = z_6n(i, z);
        if (ix >=0 && ix < vPtr->xDim && iy >=0 && iy < vPtr->yDim 
            && iz >=0 && iz < vPtr->zDim) {
          voxLoc = ix + iy * vPtr->xDim + iz * vPtr->xDim * vPtr->yDim;
          if (vPtr->voxelMap[voxLoc] == 0) {
            ComputeVoxelMap (ix,iy,iz,vPtr, maxTrianglePerVoxel);
          }
        }
      }
    }
}
/* function used by GenerateVoxelMap() */
int CheckDuplicateVox (Point *voxelList, int nVoxels, int x, int y, int z) {
  int i;
  for (i = 0; i < nVoxels; i++) {
    if (voxelList[i].x == x && voxelList[i].y == y 
        && voxelList[i].z == z) {
      return 1;
    }
  }
  return 0;
}

/* this is a improved boundary search algo */
void GenerateVoxelMap(Polygon *vPtr, int maxTrianglePerVoxel) {
  Point *oldVoxels, *newVoxels;
  int nVoxToCheck, i, j, k, nVoxToAdd, voxLoc, triLoc, ix, iy, iz;
  nVoxToCheck = 1;
  oldVoxels = (Point *) malloc (nVoxToCheck * sizeof(Point));
  oldVoxels[0].x = 0;
  oldVoxels[0].y = 0;
  oldVoxels[0].z = 0;
  while (nVoxToCheck > 0) {
    for (i = 0; i < nVoxToCheck; i++) {
      /* set those points to be outside */
      voxLoc = oldVoxels[i].x + oldVoxels[i].y*vPtr->xDim
        + oldVoxels[i].z*vPtr->xDim*vPtr->yDim;
      vPtr->voxelMap[voxLoc] = 1;
    }
    newVoxels = (Point *) malloc (nVoxToCheck * 6 * sizeof(Point));
    nVoxToAdd = 0;
    for (i = 0; i < nVoxToCheck; i++) {
      /* Add the neighbours of voxToCheck to newVoxels list. */
      for (j = 0; j < 6; j++) {
        ix = x_6n(j, oldVoxels[i].x);
        iy = y_6n(j, oldVoxels[i].y);
        iz = z_6n(j, oldVoxels[i].z);
        if (ix >=0 && ix < vPtr->xDim && iy >=0 && iy < vPtr->yDim 
            && iz >=0 && iz < vPtr->zDim) {
          voxLoc = ix + iy*vPtr->xDim + iz*vPtr->xDim*vPtr->yDim;
          triLoc = voxLoc * (maxTrianglePerVoxel + 1);
          if (vPtr->voxelMap[voxLoc] == 0 && vPtr->voxelPtr[triLoc] < 1) {
            if (!CheckDuplicateVox(newVoxels, nVoxToAdd, ix, iy, iz)) {
              newVoxels[nVoxToAdd].x = ix;
              newVoxels[nVoxToAdd].y = iy;
              newVoxels[nVoxToAdd++].z = iz;
            }
          }
        }
      }
    }
    free((void *)oldVoxels);
    oldVoxels = newVoxels;
    nVoxToCheck = nVoxToAdd;
  }
  free((void *)oldVoxels);
}



int ClosestPointOnTriangle(float *p, float *a, float *b, float *c, float *ip)
{
    int i;
    float ab[3],ac[3],bc[3],ap[3],bp[3],cp[3],tv[3];
    float d1, d2, d3, d4, d5, d6;
    float v,w,va,vb,vc,denom;

    /* find vectors */
    for (i=0;i<3;i++)
    {
        ab[i] = b[i] - a[i];
        ac[i] = c[i] - a[i];
        ap[i] = p[i] - a[i];
    }

    /* region outside vertex a */
    d1 = d2 =0.0;
    for(i = 0; i<3; i++)
    {
    	d1 += ab[i] * ap[i];
    	d2 += ac[i] * ap[i];
    }

    if(d1 <=0.0 && d2 <= 0.0)
    {
    	memcpy(ip, a, 3*sizeof(float));
    	return 0;
    }

    /* more vector */
    for (i=0;i<3;i++)
    {
        bp[i] = p[i] - b[i];
    }

    /* region outside vertex b */
    d3 = d4 = 0.0f;
    for(i = 0; i<3; i++)
    {
    	d3 += ab[i] * bp[i];
    	d4 += ac[i] * bp[i];
    }

    if(d3 >=0.0f && d4 <= d3)
    {
    	memcpy(ip, b, 3*sizeof(float));
    	return 0;
    }

    /* more vectors */
    for (i=0;i<3;i++)
    {
        cp[i] = p[i] - c[i];
        bc[i] = c[i] - b[i];
    }

    /* region edge ab */
    vc = d1 *d4 - d3 * d2;

    if(vc <= 0.0f && d1 >= 0.0 && d3 <= 0.0f)
    {
    	if(fabs(d1 - d3) > EPSILON)
    	{
    		v = d1 / (d1 - d3);
    		for (i =0; i < 3; i++)
    		{
    			tv[i] = a[i] + v * ab[i];
    		}
    		memcpy(ip, tv, 3* sizeof(float));
    	}
    	else
    	{
    		memcpy(ip, a, 3* sizeof(float)); /* could be b as well */
    	}
    	return 0;
    }

    /* region outside vertex c */
     d5 = d6 =0.0;
     for(i = 0; i<3; i++)
     {
     	d5 += ab[i] * cp[i];
     	d6 += ac[i] * cp[i];
     }

     if(d6 >=0.0f && d5 <= d6)
     {
     	memcpy(ip, c, 3*sizeof(float));
     	return 0;
     }

     /* region edge ac */
     vb = d5 *d2 - d1 * d6;

     if(vb <= 0.0f && d2 >= 0.0f && d6 <= 0.0f)
     {
    	 if( fabs(d2 -d6) > EPSILON)
    	 {
    		 w = d2 / (d2 -d6);
    		 for (i =0; i < 3; i++)
    		 {
    			 tv[i] = a[i] + w * ac[i];
    		 }
    		 memcpy(ip, tv, 3* sizeof(float));
    	 }
    	 else
    	 {
    		 memcpy(ip, a, 3* sizeof(float)); /* could be c as well */
    	 }
     	return 0;
     }

     /* region edge bc */
     va = d3 * d6 - d5 * d4;

     if(va <= 0.0f && (d4 -d3) >= 0.0f && (d5 - d6) >= 0.0f)
     {
    	 if( fabs(d4 -d3 + d5 - d6) > EPSILON)
    	 {
    		 w = (d4 -d3) / ((d4 - d3) +(d5 -d6));
    		 for (i =0; i < 3; i++)
    		 {
    			 tv[i] = b[i] + w * bc[i];
    		 }
    		 memcpy(ip, tv, 3* sizeof(float));
    	 }
    	 else
    	 {
    		 memcpy(ip, b, 3* sizeof(float)); /* could be c as well */
    	 }
     	return 0;
     }

     /* region inside */
     if(fabs(va + vb + vc) > EPSILON)
     {
    	 denom = 1.0f / (va + vb + vc);
    	 v = vb * denom;
    	 w = vc * denom;
      	for (i =0; i < 3; i++)
      	{
      		tv[i] = a[i] + v * ab[i] + w * ac[i];
      	}
      	memcpy(ip, tv, 3* sizeof(float));
    	return 1;
     }
     else
     {
    	 /* the triangle is too small */
    	 memcpy(ip, a, 3* sizeof(float)); /* could be b or c */
         return 0;
     }
}

/*-------- END OF FILE -------- */
