/****h* $RCSfile: convertBytesToFloat.c,v $ *** 
 * NAME
 *      $RCSfile: convertBytesToFloat.c,v $    $Revision: 2449 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function will convert an array of 
 *      4 bytes to the corresponding float
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 2449 $
 *      $Date: 2011-06-10 18:52:42 -0400 (Fri, 10 Jun 2011) $
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
    plhs[0] = mxCreateNumericMatrix(1,1,mxSINGLE_CLASS,mxREAL);
    
    /* populate the matrix */
    memcpy(mxGetData(plhs[0]),mxGetData(prhs[0]),4);

    return;
}

/*----------- END OF FILE ------------ */
