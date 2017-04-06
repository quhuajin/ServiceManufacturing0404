/****h* $RCSfile: convertBytesToDouble.c,v $ *** 
 * NAME
 *      $RCSfile: convertBytesToDouble.c,v $    $Revision: 1707 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function will convert an array of 
 *      8 bytes to the corresponding float
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 1707 $
 *      $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
 *      $Author: dmoses $
 *
 ***************
 */

#include <mex.h>
#include <string.h>

/* defines */
#define TRUE 1
#define FALSE 0

void mexFunction(int nlhs, mxArray *plhs[],
                    int nrhs, const mxArray *prhs[])
{
    /* first check the inputs */
    if(nrhs < 1) 
    {
        mexErrMsgTxt("Must specify bytes to convert");
        return;
    }
  
    /* Make sure the bytes are sent as uint8 type */
    if (mxGetClassID(prhs[0])!=mxUINT8_CLASS)
    {
        mexErrMsgTxt("Datatype must be uint8");
        return;
    }
    
    /* prepare the reply */
    /* The reply will be a numericUnsignedInt */
    plhs[0] = mxCreateDoubleMatrix(1,1,mxREAL);
    
    /* populate the matrix */
    memcpy(mxGetData(plhs[0]),mxGetData(prhs[0]),8);

    return;
}

/*----------- END OF FILE ------------ */
