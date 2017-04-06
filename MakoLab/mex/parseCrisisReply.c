/****h* $RCSfile: parseCrisisReply.c,v $ *** 
 * NAME
 *      $RCSfile: parseCrisisReply.c,v $    $Revision: 2702 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function can be used to extract a single data
 *      element from the crisis communication as per 
 *      CRISIS_API_README
 *      
 *      CrisisComm Format is documented in the CRISIS_API_README in the 
 *      CRISIS project
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 2702 $
 *      $Date: 2012-08-23 16:15:22 -0400 (Thu, 23 Aug 2012) $
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
#define DATAPAIR_KEY "-DataPair"
#define RAWMODE_KEY "-DataPairRaw"

void mexFunction(int nlhs, mxArray *plhs[],
                    int nrhs, const mxArray *prhs[])
{
    char *crisisComm;
    char *param;
    char paramType;
    int32_t  paramNumberOfElements;
    int32_t  paramIndex;
    char msgText[1024];
    int32_t i;
    int32_t offset;
    char errorMsg[1024];
    int32_t dataPairFlag = FALSE;
    int32_t rawModeFlag = FALSE;
    char inputString[50];
    char fieldNames[256][50];
    char *tempfieldNames[256];
    int32_t numberOfArgs;
    mxArray *tempData;

    /* first check the inputs */
    if (nrhs < 2)
    {
        mexErrMsgTxt("Unsupported number of inputs parseCrisisReply");
        return;
    }

    /* If the second argument is a single string  */
    /* only one output is desired */
    /* if not a string check if it is the  */
    /* keyword "-DataPair" for  */
    if (!mxIsNumeric(prhs[1]))
    {
        if ((!mxGetString(prhs[1],inputString,strlen(DATAPAIR_KEY)+1)) 
                && (strcmp(DATAPAIR_KEY,inputString)==0))
        {
            dataPairFlag = TRUE;
        }
        else if((!mxGetString(prhs[1],inputString,strlen(RAWMODE_KEY)+1)) 
                && (strcmp(RAWMODE_KEY,inputString)==0))
        {
            dataPairFlag = TRUE;
            rawModeFlag = TRUE;
        }
        else
        {
            mexErrMsgTxt("Index must be an int or keyword \'-DataPair\'"
                    " or keyword \'-DataPairRaw'\'");
            return;
        }
    }

    /* extract the data */
    if ((crisisComm = mxGetPr(prhs[0]))==NULL)
    {
        mexErrMsgTxt("Error extracting data");
        return;
    }
    paramIndex = (uint32_T)(mxGetScalar(prhs[1]));

    /* Check the status word to make sure this is not an error */
    /* Errors will be reported as errors */
    /* warnings as warnings. Success will be passed on */
    if (strncmp(CRISIS_REPLY_SUCCESS,
                crisisComm+CRISIS_API_HEADER_SIZE,
                strlen(CRISIS_REPLY_SUCCESS))!=0)
    {
        /* This is either an error or a warning */
        /* return accordingly */
        if (strncmp(CRISIS_REPLY_ERROR,
                    crisisComm+CRISIS_API_HEADER_SIZE,
                    strlen(CRISIS_REPLY_ERROR))==0)
        {
            /* this is an error check if there is an */
            /* error message.  */
            if ((parse_crisis_comm(crisisComm, 0, NULL,
                    &param,&paramType, &paramNumberOfElements)==CRISIS_SUCCESS)
                && (paramType == 's')
                && (paramNumberOfElements == 1))
            {
                sprintf(errorMsg,
                        "CRISIS returned error: %s",param);
            } 
            else
            {
                sprintf(errorMsg,
                        "CRISIS returned error: "
                        "Unfortunately Matlab could not parse error");
            }
            mexErrMsgTxt(errorMsg);
            return;
        } 
        else if (strncmp(CRISIS_REPLY_WARNING,
                    crisisComm+CRISIS_API_HEADER_SIZE,
                    strlen(CRISIS_REPLY_WARNING))==0)
        {
            /* this is a warning check if there is an */
            /* error message.  */
            if ((parse_crisis_comm(crisisComm, 0, NULL,
                    &param,&paramType, &paramNumberOfElements)==CRISIS_SUCCESS)
                && (paramType == 's')
                && (paramNumberOfElements == 1))
            {
                sprintf(errorMsg,
                        "CRISIS returned warning: %s",param);
            } 
            else
            {
                sprintf(errorMsg,
                        "CRISIS returned warning: "
                        "Unfortunately Matlab could not parse error");
            }
            mexWarnMsgTxt(errorMsg);
            return;
        }
        else
        {
            /*mexErrMsgTxt("Unrecoganized reply type");
            return;*/
        }
    }

    /* allow only positive index */
    if (paramIndex<=0)
    {
        mexErrMsgTxt("Param index must be a positive number");
        return;
    }

    /* now let the parsing function check and parse the function */

    /* if this is a data pair we need to do more work */
    if (dataPairFlag == TRUE)
    {
        /* first check if the number of arguments are even */
        numberOfArgs = extract_comm_num_of_var(crisisComm);
        if ((numberOfArgs%2)!=0)
        {
            mexErrMsgTxt("CrisisComm must have even variables "
                    "for a valid data pair");
            return;
        }
        if (numberOfArgs==0)
        {
            mexWarnMsgTxt("No elements in structure");
            return;
        }

        /* now start extracting each data pair.  the first */
        /* element in the pair should be a text string which  */
        /* will identify the structure and the second will be */
        /* the value */
        for (i=0;i<numberOfArgs;i+=2)
        {
            /* directly call the parse function to establish  */
            /* if the parameter is a string */
            if (parse_crisis_comm(crisisComm, i, NULL,
                &param,&paramType, &paramNumberOfElements)
                    ==CRISIS_FAILURE)
            {
                sprintf(msgText,"Invalid CrisisComm or "
                    "Element (%d) does not exist in crisisComm",
                    i+1);
                mexErrMsgTxt(msgText);
                return;
            }
            /* now make sure this is a string */
            if ((paramType!='s')||(paramNumberOfElements!=1))
            {
                sprintf(msgText,"Odd elements in CrisisComm data pairs "
                    "must be single strings got [%c,%d] for variable %d",
                    paramType,paramNumberOfElements,i+1);
                mexErrMsgTxt(msgText);
                return;
            }
            /* all went well collect the field name */
            strcpy(fieldNames[i/2],param);
            
            /* adjust the field names to point within the fieldname */
            /* structure */
            tempfieldNames[i/2] = fieldNames[i/2];
        }
        
        /* Now create a structure with the fieldnames */
        plhs[0] = mxCreateStructMatrix(1,1,numberOfArgs/2,
                tempfieldNames);
        
        /* now extract and fill the data */
        for (i=2;i<=numberOfArgs;i+=2)
        {
            /* parse each data */
            if (crisis_comm_to_matlab(crisisComm,i,
                        &tempData,msgText,rawModeFlag)==CRISIS_FAILURE)
            {
                mexErrMsgTxt(msgText);
                return;
            }
            mxSetFieldByNumber(plhs[0],0,(i-1)/2,tempData);
        }
        return;
    }
    else
    {
        /* if the requested data is in a single data parse and  */
        /* reply immediately. */
         if (crisis_comm_to_matlab(crisisComm,paramIndex,
                    plhs,msgText,rawModeFlag)==CRISIS_FAILURE)
        {
            mexErrMsgTxt(msgText);
        }
    }
    return;
}


/****f*  crisis_communication.c/crisis_comm_to_matlab ****** 
 * NAME
 *      crisis_comm_to_matlab
 *
 * SYNOPSIS
 *      int crisis_comm_to_matlab(char *crisisComm, int paramIndex,
 *              const mxArray *plhs[],char *msgText)
 *
 * INPUTS
 *      char *comm
 *              the crisis communication to be parsed
 *              refer to CRISIS_API_README for details on the format used
 *      int paramIndex
 *              indicated which variable to extract from the comm
 *      int rawModeFlag
 *              if the raw mode is used the output datatype will not be altered
 *              ints will be kept as ints
 *
 * OUTPUT
 *      mxArray *plhs[]
 *              matlab array with the data of appropriate
 *              matlab data class as per the communication datatype
 *      
 *      char *msgText 
 *              error message if there is an error
 *      
 *      int  status
 *              CRISIS_SUCCESS if parameter was successfully extracted
 *              CRISIS_FAILURE if there was an error
 * 
 * PURPOSE
 *	    This function can be used to parse the given command into
 *	    relevant parameters readable by matlab
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *      Remember no memory is allocated.  only the pointers to the 
 *      appropriate location in the communication are returned
 *
 *      This is a purely parsing function.  all error checking
 *      should be done prior to calling this function
 *      
 * BUGS
 *
 * SEE ALSO
 *      CRISIS_API_README, parse_crisis_comm
 *
 **********************************
 */

int crisis_comm_to_matlab(char *crisisComm, int paramIndex,
        const mxArray *matlabArray[],char *msgText,int rawModeFlag)
{
    char *param;
    int paramNumberOfElements;
    char paramType;
    int i;
    int offset;
    double *arrayPtr;

    if (parse_crisis_comm(crisisComm, (paramIndex-1), NULL,
          &param,&paramType, &paramNumberOfElements)==CRISIS_FAILURE)
    {
        sprintf(msgText,"Invalid CrisisComm or "
                "Element (%d) does not exist in crisisComm",
                paramIndex);
        return CRISIS_FAILURE;
    }

    /* now that we have the data prepare the output */
    switch (paramType)
    {
        case 'd':
            if (rawModeFlag)
            {
                matlabArray[0] = mxCreateNumericMatrix(1,paramNumberOfElements,
                        mxINT32_CLASS,mxREAL);
                memcpy(mxGetPr(matlabArray[0]),param,
                        sizeof(int)*paramNumberOfElements);
            }
            else
            {
                matlabArray[0] = mxCreateDoubleMatrix(1,
                        paramNumberOfElements,mxREAL);
                arrayPtr = mxGetPr(matlabArray[0]);
                for (i=0;i<paramNumberOfElements;i++)
                    arrayPtr[i] = ((int *)param)[i];
            }
            break;
        case 'f':
            matlabArray[0] = mxCreateDoubleMatrix(1,
                        paramNumberOfElements,mxREAL);
            memcpy(mxGetPr(matlabArray[0]),param,
                    sizeof(double)*paramNumberOfElements);
            break;
        case 'b':
        case 'x':
        case 'c':
            matlabArray[0] = mxCreateNumericMatrix(1,paramNumberOfElements,
                    mxUINT8_CLASS,mxREAL);
            memcpy(mxGetPr(matlabArray[0]),param,paramNumberOfElements);
            break;
        case 's':
            matlabArray[0] = mxCreateCellMatrix(1,paramNumberOfElements);
            offset = 0;
            for (i=0;i<paramNumberOfElements;i++)
            {
                mxSetCell(matlabArray[0],i,mxCreateString(param+offset));
                offset += (strlen(param+offset)+1);
            }
            break;    
        default:
            sprintf(msgText,"Unsupported datatype detected");
            return CRISIS_FAILURE;
    }
    return CRISIS_SUCCESS;
} 

/*----------- END OF FILE ------------ */
