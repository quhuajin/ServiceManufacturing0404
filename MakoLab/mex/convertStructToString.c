/****h* $RCSfile: convertStructToString.c,v $ *** 
 * NAME
 *      $RCSfile: convertStructToString.c,v $    $Revision: 2449 $
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

/* Defines */
#define MAX_STRING_LENGTH 30  /* This will determine where the data  */
                              /* to value separation will occur */

#define TEXT_SEPARATION "   "
#define MAX_NUM_OF_COLUMNS 6

void mexFunction(int nlhs, mxArray *plhs[],
        int nrhs, const mxArray *prhs[])
{
    int numberOfFields;
    int numberOfElements;
    int i;
    int j;
    char stringReply[1024*20]="\0";
    char tempString[2*MAX_STRING_LENGTH];
    char formatedName[2*MAX_STRING_LENGTH];
    mxArray *fieldValue;
    mxArray *cellElement;
    void *tempData;
    char whiteSpaces[MAX_STRING_LENGTH];
    int maxDoubleColumns;
    int nameLength=0;

    /* first check the inputs */
    if ((nrhs != 1) || (!mxIsStruct(prhs[0]))) 
    {
        mexErrMsgTxt("Function requires single structure argument");
        return;
    }

    /* initialize the white space string to fill up extra space */
    memset(whiteSpaces,' ',MAX_STRING_LENGTH);
    whiteSpaces[MAX_STRING_LENGTH-1]='\0';

    /* Now start going through all the fields and handling them appropriately  */
    numberOfFields = mxGetNumberOfFields(prhs[0]); 

    for (i=0;i<numberOfFields;i++)
    {
        fieldValue = mxGetFieldByNumber(prhs[0],0,i);
        numberOfElements = mxGetNumberOfElements(fieldValue);
        tempData = mxGetData(fieldValue);

        /* Print the field name */
        sprintf(tempString,"%s",mxGetFieldNameByNumber(prhs[0],i));
        nameLength = strlen(tempString);
        if (nameLength>=MAX_STRING_LENGTH-2)
        {
            sprintf(formatedName,"%s  : ",tempString);
        }
        else
        {
            sprintf(formatedName,"%s%s: ",tempString,
                whiteSpaces+nameLength);
        }
        strcat(stringReply,formatedName);

        /* Now process the data */
        switch (mxGetClassID(fieldValue))
        {
            case mxDOUBLE_CLASS:
                /* otherwise just print in a row */
                for (j=0;j<numberOfElements;j++)
                {
                    /* if this is has 16 elements assume this is a transform */
                    if (numberOfElements == 16)
                        maxDoubleColumns = 4;
                    else
                        maxDoubleColumns = MAX_NUM_OF_COLUMNS;

                    if ((j!=0) && (j%maxDoubleColumns == 0))
                    {
                        /* automatically wrap text to number of columns */
                        strcat(stringReply,"\n  ");
                        strcat(stringReply,whiteSpaces);
                    }

                    sprintf(tempString,"% 5.5f" TEXT_SEPARATION,
                            ((double *)tempData)[j]);
                    strcat(stringReply,tempString);
                }
                break;

            case mxSINGLE_CLASS:
                for (j=0;j<numberOfElements;j++)
                {
                    sprintf(tempString,"% 5.5f" TEXT_SEPARATION,
                            ((float *)tempData)[j]);
                    strcat(stringReply,tempString);
                }
                break;

            case mxINT8_CLASS:
            case mxUINT8_CLASS:
            case mxINT16_CLASS:
            case mxUINT16_CLASS:
            case mxINT32_CLASS:
            case mxUINT32_CLASS:
            case mxINT64_CLASS:
            case mxUINT64_CLASS:
                for (j=0;j<numberOfElements;j++)
                {
                    if ((j!=0) && (j%MAX_NUM_OF_COLUMNS == 0))
                    {
                        /* automatically wrap text to number of columns */
                        strcat(stringReply,"\n  ");
                        strcat(stringReply,whiteSpaces);
                    }
                    sprintf(tempString,"% 8d" TEXT_SEPARATION,
                            ((int *)tempData)[j]);
                    strcat(stringReply,tempString);
                }
                break;

            case mxCELL_CLASS:
                for (j=0;j<numberOfElements;j++)
                {
                    cellElement = mxGetCell(fieldValue, j);
                    strcat(stringReply,"'");
                    strcat(stringReply,mxArrayToString(cellElement));
                    strcat(stringReply,"' ");
                }
                break;
            case mxCHAR_CLASS:
                strcat(stringReply,"'");
                strcat(stringReply,mxArrayToString(fieldValue));
                strcat(stringReply,"'");
                break;
            default:
                break;
        }
        /* terminate with a newline charecter */
        strcat(stringReply,"\n");
    }

    plhs[0] = mxCreateString(stringReply);

    return;
}

/*----------- END OF FILE ------------ */
