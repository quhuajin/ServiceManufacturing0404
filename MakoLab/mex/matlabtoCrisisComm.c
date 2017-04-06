/****h* $RCSfile: matlabtoCrisisComm.c,v $ *** 
 * NAME
 *      $RCSfile: matlabtoCrisisComm.c,v $    $Revision: 2450 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This command will convert a given matlab
 *      command into the CRISIS_API format, as
 *      documented in the CRISIS_API_README in the 
 *      CRISIS project
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 2450 $
 *      $Date: 2011-06-10 18:54:10 -0400 (Fri, 10 Jun 2011) $
 *      $Author: dmoses $
 *
 ***************
 */

#include <mex.h>
#include <string.h>
#include "crisis_communication.h"

/* defines */
#define TRUE 1
#define FALSE 0

void mexFunction(int nlhs, mxArray *plhs[],
                    int nrhs, const mxArray *prhs[])
{
    char crisisCommStaticBuffer[DEFAULT_COMM_SIZE];
    char *crisisComm;
    char *crisisCommTemp;
    char commandString[DEFAULT_COMM_SIZE];
    int32_t  commLength;
    int32_t  *numberOfArgsPtr;
    int32_t nCols;
    int32_t nRows;
    int32_t vectorLength;
    int32_t i;
    int32_t j;
    mxArray *tempData;
    mxArray *intConversion;
    char tempString[1024];
    bool dynamicMemAllocated;
    size_t availableCommMemory;
    size_t requiredSize;
    char errorMessage[100];

    /* first check the inputs */
    if(nrhs < 1) 
    {
        mexErrMsgTxt("Must specify crisis command");
        return;
    }
  
    /* extract the command */
    if (mxGetString(prhs[0],commandString,DEFAULT_COMM_SIZE))
    {
        mexErrMsgTxt("Command must be a string");
        return;
    }

    /* by default start off with the static buffer to save time */
    crisisComm = (char *) crisisCommStaticBuffer;
    dynamicMemAllocated = false;
    availableCommMemory = DEFAULT_COMM_SIZE;

    /* now for each element try to determine the datatype */
    /* and start filling out a crisisComm structure */
    init_command_comm(crisisComm,commandString);

    /* recover the comm length used so far.  */
    /* Refer to the CRISIS_API documentation */
    commLength = *((uint32_t *) (crisisComm
            + CRISIS_KEYWORD_LENGTH));

    numberOfArgsPtr = (int32_t *) (crisisComm + CRISIS_API_HEADER_SIZE
        + strlen(commandString) +1);

    /* now for every remaining variable start adding to the */
    /* comm */
    for (i=1;i<nrhs;i++)
    {
        /* check dimensions */
        if (mxGetNumberOfDimensions(prhs[i])>2)
        {
            mexErrMsgTxt("Max 2 dimensional matrix supported");
            return;
        }

        /* find vector length */
        nRows = mxGetN(prhs[i]);
        nCols = mxGetM(prhs[i]);
        
        /* increment number of args */
        (*numberOfArgsPtr)++;

        /* vectorLength will be the size of the matrix */
        vectorLength = nCols*nRows;

        /* do a quick check to see if memory needs to be allocated */
        /* for speed all ints are treated as int32 and all strings */
        /* will be assumed to have 1024 bytes (max allowed) */
        switch(mxGetClassID(prhs[i]))
        {
            case mxDOUBLE_CLASS:
                requiredSize = 1 + sizeof(unsigned long int) 
                    + vectorLength*sizeof(double);
                break;
            case mxINT8_CLASS:
            case mxINT16_CLASS:
            case mxUINT16_CLASS:
            case mxINT32_CLASS:
            case mxUINT32_CLASS:
                requiredSize = 1 + sizeof(unsigned long int) 
                    + vectorLength*sizeof(int);
                break;
            case mxCELL_CLASS:
                requiredSize = 1 + sizeof(unsigned long int) 
                    + vectorLength*1024;
            case mxUINT8_CLASS:
                requiredSize = 1 + sizeof(unsigned long int) 
                    + vectorLength*sizeof(char);
                break;
            case mxCHAR_CLASS:
                requiredSize = 1 + sizeof(unsigned long int) 
                    + vectorLength*sizeof(char)+1;
                break;
            default:
                if (dynamicMemAllocated)
                    mxFree(crisisComm);
                mexErrMsgTxt("Unsupported class");
                return;
        }

        /* now check if it will fit */
        if (requiredSize+commLength>availableCommMemory)
        {
            /* If this is the first time allocating memory */
            /* copy the static buffer */
            if (!dynamicMemAllocated)
            {
                if ((crisisComm = mxMalloc(requiredSize+commLength))
                        == NULL)
                {
                    sprintf(errorMessage,"Unable to allocate requested "
                            "(%d) bytes in CrisisComm",
                            (int)(requiredSize+commLength));
                    mexErrMsgTxt(errorMessage);
                    return;
                }
                availableCommMemory = requiredSize+commLength;
                dynamicMemAllocated = true;
                memcpy(crisisComm,crisisCommStaticBuffer,commLength);
                numberOfArgsPtr = (int32_t *) (crisisComm + CRISIS_API_HEADER_SIZE
                    + strlen(commandString) +1);
            }
            else
            {
                if ((crisisCommTemp = mxRealloc(crisisComm,requiredSize+commLength))
                        == NULL)
                {
                    sprintf(errorMessage,"Unable to allocate requested "
                            "(%d) bytes in CrisisComm",
                            (int)(requiredSize+commLength));
                    mxFree(crisisComm);
                    mexErrMsgTxt(errorMessage);
                    return;
                }
                crisisComm = crisisCommTemp;
                availableCommMemory = requiredSize+commLength;
                numberOfArgsPtr = (int32_t *)(crisisComm + CRISIS_API_HEADER_SIZE
                    + strlen(commandString) +1);
            }
        }

        /* If the data is already a vector */
        /* just copy the memory. if not for voyager compatability  */
        /* purposes data must be read rowwise */
        mexCallMATLAB(1, &tempData, 1, (const struct mxArray **)(prhs+i),"transpose");

        /* extract the data type */
        switch(mxGetClassID(prhs[i]))
        {
            case mxDOUBLE_CLASS:
                /* Doubles which have all ints can be considered */
                /* as ints.  CRISIS handles conversion of ints to  */
                /* doubles if required. */
                if (!isDataInt(mxGetData(prhs[i]),vectorLength))
                {
                    /* fill data preamble */
                    crisisComm[commLength] = 'f';
                    *((unsigned long int *)(crisisComm + commLength + 1)) 
                        = vectorLength;
                    commLength += (1+sizeof(uint32_t));
                    
                    memcpy(crisisComm + commLength,
                            mxGetData(tempData),
                            sizeof(double)*vectorLength);
                    commLength += (sizeof(double)*vectorLength);
                    break;
                }
            case mxINT8_CLASS:
            case mxINT16_CLASS:
            case mxUINT16_CLASS:
            case mxINT32_CLASS:
            case mxUINT32_CLASS:
                /* 32 bit data can be handled natively.  all other */
                /* forms of int will have to be converted to  */
                /* 32 bit data  */
                mexCallMATLAB(1, &intConversion, 1, &tempData,"int32");
                /* fill data preamble */
                crisisComm[commLength] = 'd';
                *((uint32_t *)(crisisComm + commLength + 1)) 
                    = vectorLength;
                commLength += (1+sizeof(uint32_t));
                /* now fill the data */
                memcpy(crisisComm + commLength,
                        mxGetData(intConversion),
                        sizeof(int32_t)*vectorLength);
                commLength += (sizeof(int32_t)*vectorLength);
                break;
            case mxCELL_CLASS:
                /* define the datatype */
                crisisComm[commLength] = 's';
                *((uint32_t *)(crisisComm + commLength + 1)) 
                    = vectorLength;
                commLength += (1+sizeof(uint32_t));
                /* cells will be treated as multiple strings */
                for (j=0;j<vectorLength;j++)
                {
                    if(mxGetString(mxGetCell(tempData,j),tempString,1024))
                    {
                        mexErrMsgTxt("All elements in cell must be strings "
                                "(max length 1024)");
                        return;
                    }
                    /* copy the string to the comm */
                    sprintf(crisisComm + commLength,"%s",tempString);
                    commLength += (strlen(tempString)+1);
                }
                break;
            case mxCHAR_CLASS:
                /* define the datatype */
                crisisComm[commLength] = 's';
                *((uint32_t *)(crisisComm + commLength + 1)) 
                    = 1;
                commLength += (1+sizeof(uint32_t));
                if(mxGetString(tempData,tempString,1024))
                {
                    mexErrMsgTxt("Invalid string received "
                            "(max length 1024)");
                    return;
                }
                /* copy the string to the comm */
                sprintf(crisisComm + commLength,"%s",tempString);
                commLength += (strlen(tempString)+1);
                break;
            case mxUINT8_CLASS:
                /* fill data preamble */
                crisisComm[commLength] = 'x';
                *((uint32_t *)(crisisComm + commLength + 1)) 
                    = vectorLength;
                commLength += (1+sizeof(uint32_t));
                /* now fill the data */
                memcpy(crisisComm + commLength, mxGetData(tempData),
                        sizeof(char)*vectorLength);
                commLength += (sizeof(char)*vectorLength);
                break;
            default:
                if (dynamicMemAllocated)
                    mxFree(crisisComm);
                mexErrMsgTxt("Unsupported class");
                return;
        }
    }

    /* Update the commLength variable */
    *((uint32_t *)(crisisComm + CRISIS_KEYWORD_LENGTH)) = commLength;

    /* prepare the reply */
    /* The reply will be a numericUnsignedInt */
    plhs[0] = mxCreateNumericMatrix(1,commLength,mxUINT8_CLASS,mxREAL);
    
    /* populate the matrix */
    memcpy((char *)mxGetData(plhs[0]),crisisComm,commLength);

    /* if memory was allocated free it */
    if (dynamicMemAllocated)
        mxFree(crisisComm);

    return;
}

/****f*  $RCSfile: matlabtoCrisisComm.c,v $/isDataInt ****** 
 * NAME
 *      isDataInt
 *
 * SYNOPSIS
 *      int isDataInt(double *Data,
 *         int vectorLength)
 *
 * INPUTS
 *      double *Data
 *              Data to be checked
 *      int vectorLength
 *              Number of elements in the Data vector
 *
 * OUTPUT
 *      int  returnValue
 *              TRUE if all values in the data are ints
 *              FALSE if any one of the values are doubles
 *
 * PURPOSE
 *      This function can be used to detemine if a given vector
 *      of doubles can be converted into ints.
 *
 * NOTES
 *
 * BUGS
 *
 * SEE ALSO
 *
 **********************************
 */
int isDataInt(double *data, int vectorLength)
{
    int i;

    for (i=0;i<vectorLength;i++)
    {
        if ((((int)(data[i]))-data[i])!=0)
            return FALSE;
    }
    return TRUE;
}

/*----------- END OF FILE ------------ */
