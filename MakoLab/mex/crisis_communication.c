/****h* /crisis_communication.c *** 
 * NAME
 *      crisis_communication.c	$Revision: 2449 $
 *
 * COPYRIGHT
 * 	Copyright (c) 2007 Mako Surgical Corp.
 *
 * PURPOSE
 *      This library provides helper functions to parse and check 
 *      crisis_commands and replies
 *
 *      For additional information on the CRISIS communication protocol
 *      refer to CRISIS_API_README
 *
 * SEE ALSO
 *      CRISIS_API_README
 * 
 * CVS INFORMATION
 * 		$Revision: 2449 $
 * 		$Date: 2011-06-10 18:52:42 -0400 (Fri, 10 Jun 2011) $
 * 		$Author: dmoses $
 *
 ****************/

/* includes */
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <stdarg.h>

#include "crisis_communication.h"

/****f*  crisis_communication.c/parse_crisis_comm ****** 
 * NAME
 *	    parse_crisis_comm
 *
 * SYNOPSIS
 *      int32_t parse_crisis_comm(char *comm, 
 *         int32_t paramIndex,
 *         char **commandWord,
 *         char **param,
 *         char *paramType,
 *         int32_t *numberOfArgElements)
 *
 * INPUTS
 *      char *comm
 *              the crisis communication to be parsed
 *              refer to CRISIS_API_README for details on the format used
 *      int32_t paramIndex
 *              indicated which variable to extract from the comm
 *
 * OUTPUT
 *      char **commandWord
 *              the command word extracted from the comm
 *      char **param
 *              the requested param extracted from the comm
 *      char *paramType
 *              the datatype of the extracted parameter
 *      int32_t  *numberOfArgElements
 *              number of arguments present in the comm
 *
 *      int32_t  status
 *              CRISIS_SUCCESS if parameter was successfully extracted
 *              CRISIS_FAILURE if there was an error
 * 
 * PURPOSE
 *	    This function can be used to parse the given command into
 *	    relevant parameters
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *      If any of the outputs is not desired, pass NULL to the function
 *      and that output is ignored
 *
 *      Remember no memory is allocated.  only the pointers to the 
 *      appropriate location in the communication are returned
 *
 * BUGS
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT
 *
 **********************************
 */
int32_t parse_crisis_comm(char *comm, 
          int32_t paramIndex,
          char **commandWord,
          char **param,
          char *paramType,
          int32_t *paramLength)
{
    int32_t i;
    int32_t j;
    int32_t offset;
    char argTypeCode;
    uint32_t numberOfArgs;
    uint32_t numberOfArgElements;
    char tempCommand[100];
   
    /* skip the initial CRISIS_API_HEADER_SIZE bytes.  These  */
    /* are reserved for the CRISIS header information. */
    
    offset = CRISIS_API_HEADER_SIZE;
    
    /* extract the command word from the command */
    /* make sure the command string is terminated  */
    /* (MAX_MODULE_COMMAND_LENGTH chars max) */
    if (sscanf(comm+offset,"%s",tempCommand)!=1)
    {
        return CRISIS_FAILURE;
    }

    if (commandWord != NULL)
    {
        *commandWord = comm+offset;
    }
   
    /* numberOfArgs command word + '\0' */
    offset += (strlen(tempCommand)+1);
    numberOfArgs = *((uint32_t *)(comm + offset));
    /* if no parameters are desired return immediately */
    if (paramIndex==-1)
        return CRISIS_SUCCESS;

    /* offset will be command word + '\0' + space used by numberOfArgs */
    offset += sizeof(numberOfArgs);

    /* make sure we have the number of arguments available */
    if (paramIndex>=numberOfArgs)
        return CRISIS_FAILURE;
    
    /* now find the offset for the parameter desired */
    for (i=0;i<=paramIndex;i++)
    {
        argTypeCode = *(comm+offset);
        numberOfArgElements = *((int32_t *) (comm+offset+sizeof(argTypeCode)));
        
        offset += sizeof(argTypeCode)+sizeof(numberOfArgElements);
        
        /* if desired index has not yet been reached,  */
        /* compute next offset based on datatype */
        if (i<paramIndex)
        {
            switch (argTypeCode)
            {
                case 'd':
                    offset += sizeof(int)*numberOfArgElements;
                    break;
                case 'f':
                    offset += sizeof(double)*numberOfArgElements;
                    break;
                case 'c':
                case 'x':
                    offset += sizeof(char)*numberOfArgElements;
                    break;
                case 's':
                    for (j=0;j<numberOfArgElements;j++)
                    {
                        offset += strlen(comm+offset)+1;
                    }
                    break;
                case 'C':
                    offset += extract_comm_length(comm+offset);
                    break;
                default:
                    /* unsupported argType */
                    return CRISIS_FAILURE;
            }
        }

        /* if the index is at the desired index check if it is a */
        /* supported type */
        if (i==paramIndex)
        {
            switch (argTypeCode)
            {
                case 'd':
                case 'f':
                case 'c':
                case 'x':
                case 's':
                case 'C':
                    break;
                default:
                    /* unsupported argType */
                    return CRISIS_FAILURE;
            }
        }
        
    }

    /* if all went well return the pointer to the parameter */
    /* desired.  The calling function should deal with the  */
    /* data type */
    if (param!=NULL)
        *param =  comm+offset;
    
    if (paramType!=NULL)
        *paramType = argTypeCode;
    
    if (paramLength!=NULL)
        *paramLength = numberOfArgElements;
    
    return CRISIS_SUCCESS;
}

/****f*  crisis_communication.c/check_crisis_comm ****** 
 * NAME
 *      check_crisis_comm
 *
 * SYNOPSIS
 *      int32_t check_crisis_comm(
 *              char *comm,
 *              uint32_t commLength,
 *              int32_t commandOrReply,
 *              int32_t *errorCode
 *              )
 *
 * INPUTS
 *      char *comm
 *              the crisis communication to be checked
 *              refer to CRISIS_API_README for details on the format used
 *      uint32_t commLength
 *              Number of Bytes in comm
 *      int32_t commandOrReply
 *              this specifies if the communication to be checked is a 
 *              command or a reply
 *              CRISIS_COMMAND  => comm is a command to CRISIS
 *              CRISIS_REPLY    => comm is a reply from CRISIS
 *
 * OUTPUT
 *      int32_t  status
 *              CRISIS_SUCCESS if communication is in correct format
 *              CRISIS_FAILURE if there was an error
 *      char *errorMessage
 *              Error message if the check failed.  Message should be
 *              atleast 100 bytes long
 *              
 * 
 * PURPOSE
 *	    This function can be used to check if the given command is 
 *      in proper CRISIS api command
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *
 * BUGS
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT, CRISIS_REPLY_FORMAT
 *
 **********************************
 */

int32_t check_crisis_comm(char *comm,
        uint32_t commLength,
        int32_t commandOrReply,
        char *errorMessage)
{
    char tempCommand[100];
    uint32_t  numberOfBytes;
    int32_t  numberOfVariables;
   
    /* min command length should be  */
    /* the size of the header */
    if (commLength<CRISIS_API_HEADER_SIZE)
    {
        sprintf(errorMessage,"Incomplete header");
        return CRISIS_FAILURE;
    }
    
    /* first extract which type of communication we would like to check */
    if ((commandOrReply!=CRISIS_COMMAND) 
            && (commandOrReply!=CRISIS_REPLY))
    {
        sprintf(errorMessage,"Invalid CRISIS Comm type");
        return CRISIS_FAILURE; 
    }
    
    /* check the keyword */
    if (commandOrReply==CRISIS_COMMAND)
    {
        if (memcmp(comm,CRISIS_COMMAND_KEYWORD,CRISIS_KEYWORD_LENGTH)!=0)
        {
            sprintf(errorMessage,"Invalid Keyword");
            return CRISIS_FAILURE;
        }
    }
    else
    {
        if (memcmp(comm,CRISIS_REPLY_KEYWORD,CRISIS_KEYWORD_LENGTH)!=0)
        {
            sprintf(errorMessage,"Invalid Keyword");
            return CRISIS_FAILURE;
        }
    }

    /* check number of bytes */
    numberOfBytes = *((uint32_t *) (comm+CRISIS_KEYWORD_LENGTH));
    if (numberOfBytes!=commLength)
    {
        sprintf(errorMessage,"Data length mismatch");
        return CRISIS_FAILURE;
    }

    /* check if there is a command present */
    if (sscanf(comm+CRISIS_API_HEADER_SIZE,"%s",tempCommand)!=1)
    {
        sprintf(errorMessage,"No command in Crisis Comm");
        return CRISIS_FAILURE;
    }

    /* make sure number of variables is defined */
    if (commLength<(CRISIS_API_HEADER_SIZE+strlen(tempCommand)+1))
    {
        sprintf(errorMessage,"Number of variables not defined");
        return CRISIS_FAILURE;
    }
    
    /* now check the variables supplied */
    /* we will check the number of variables supplied */
    /* the variables are automatically checked as part of the parsing */
    /* so if I can reach the final variable it will mean that all the */
    /* variables upto the final variable are correct */

    numberOfVariables = *((uint32_t *)(comm+CRISIS_API_HEADER_SIZE
                +strlen(tempCommand)+1));
  
    if (parse_crisis_comm(comm,numberOfVariables-1,
                NULL,NULL,NULL,NULL)==CRISIS_FAILURE)
    {
        sprintf(errorMessage,"Unable to parse crisis comm variable");
        return CRISIS_FAILURE;
    }

    /* all checks passed  */
    return CRISIS_SUCCESS;
}

/****f*  crisis_communication.c/extract_comm_num_of_var ****** 
 * NAME
 *      extract_comm_num_of_var
 *
 * SYNOPSIS
 *      int32_t extract_comm_num_of_var(char *comm) 
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to be parsed
 *          refer to CRISIS_API_README for details on the format used
 *
 * OUTPUT
 *      int32_t  numberOfVariables
 *          Number of CRISIS_VARIABLES in the comm as encoded in the
 *          CRISIS_API_FORMAT
 *          in case of error the return value will be CRISIS_FAILURE
 * 
 * PURPOSE
 *	    This function can be used to find how many arguments are present
 *	    in the given command 
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *
 * BUGS
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT
 *
 **********************************
 */

int32_t extract_comm_num_of_var(char *comm) 
{
    int32_t offset;
    offset = CRISIS_API_HEADER_SIZE + strlen(comm+CRISIS_API_HEADER_SIZE)+1;
    
    return *((uint32_t *)(comm+offset));
    
}



/****f*  crisis_communication.c/extract_comm_length ****** 
 * NAME
 *      extract_comm_length
 *
 * SYNOPSIS
 *      int32_t extract_comm_length(char *comm) 
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to be parsed
 *          refer to CRISIS_API_README for details on the format used
 *
 * OUTPUT
 *      int32_t  commLength
 *          length of the comm as encoded in the Comm
 *          The keyword will be checked to make sure the comm is valid
 *          in case of error the return value will be CRISIS_FAILURE
 * 
 * PURPOSE
 *	    This function can be used to determine the number of bytes in the
 *	    given command 
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *
 * BUGS
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT
 *
 **********************************
 */

int32_t extract_comm_length(char *comm)
{
    /* check the keyword */
    if ((memcmp(comm,CRISIS_COMMAND_KEYWORD,CRISIS_KEYWORD_LENGTH)!=0)
            && (memcmp(comm,CRISIS_REPLY_KEYWORD,CRISIS_KEYWORD_LENGTH)!=0))
    {
        return CRISIS_FAILURE;
    }

    return *((uint32_t *)(comm+CRISIS_KEYWORD_LENGTH));
}

/****f*  crisis_communication.c/convert_crisis_comm_to_text ****** 
 * NAME
 *	    convert_crisis_comm_to_text
 *
 * SYNOPSIS
 *      int32_t convert_crisis_comm_to_text(char *comm, 
 *         int32_t detailsFlag,
 *         char **commInTextFormatPtr);
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to be converted to text
 *          refer to CRISIS_API_README for details on the format used
 *      int32_t  detailsFlag
 *         This can be used to turn on or turn off format and size details     
 *              DETAILS_DISPLAY_ON
 *              DETAILS_DISPLAY_OFF (default)
 *
 * OUTPUT
 *      char **commInTextFormatPtr
 *          the crisis communication expressed in text format
 *
 *      int32_t returnValue
 *         CRISIS_SUCCESS if conversion was successful
 *         CRISIS_FAILURE if conversion failed
 * 
 * PURPOSE
 *	    This function can be used to parse and convert a given comm
 *	    in the CRISIS_API_FORMAT.  This is useful for debugging and display
 *
 *	    refer to CRISIS_API_README
 *
 * NOTES
 *      Each variable will be separated by a newline char.  If the 
 *      variable is a vector, each element of the vector will be separated
 *      by a ','.  If the detailsFlag is set
 *
 * BUGS
 *      There is no check built in for the commInTextFormat variable.  It 
 *      is assumed that enough memory is allocated to the text to load the 
 *      complete string
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT
 *
 **********************************
 */

int32_t convert_crisis_comm_to_text(char *comm, 
         int32_t detailsFlag, 
         char *commInTextFormat)
{
    int32_t i;
    int32_t offset;
    int32_t paramIndex;
    char *param;
    char paramType;
    int32_t paramLength;
    char *tempString;
  
    /* if the details are requested print32_t the size */
    if (detailsFlag==DETAILS_DISPLAY_ON)
    {
        memcpy(commInTextFormat,comm,CRISIS_KEYWORD_LENGTH);
        commInTextFormat[CRISIS_KEYWORD_LENGTH] = '\0';

        sprintf(commInTextFormat,"%s (%d)\n",
                commInTextFormat,
                extract_comm_length(comm));
    }

    /* extract the command or replyType */
    if (parse_crisis_comm(comm,-1,&tempString,NULL,NULL,NULL)
            ==CRISIS_FAILURE)
    {
        return CRISIS_FAILURE;
    }

    sprintf(commInTextFormat,"%s%s",
                commInTextFormat,tempString);
    /* if details are requested also print32_t the number of variables */
    /* sent */
    if (detailsFlag==DETAILS_DISPLAY_ON)
    {
        sprintf(commInTextFormat,"%s (%d)\n",commInTextFormat,
                extract_comm_num_of_var(comm));
    }
    else
    {
        printf(commInTextFormat,"%s\n",commInTextFormat);
    }
    

    /* Extract parameters till we run out */
    paramIndex = 0;
    while (parse_crisis_comm(comm,paramIndex,NULL,
                &param,&paramType,&paramLength)==CRISIS_SUCCESS)
    {
        if (detailsFlag==DETAILS_DISPLAY_ON)
        {
            sprintf(commInTextFormat,"%s[%c,%d]\t",
                    commInTextFormat,paramType,paramLength);
        }
        switch (paramType)
        {
            case 'd':
                for (i=0;i<paramLength;i++)
                {
                    sprintf(commInTextFormat,"%s%d, ",
                        commInTextFormat,((int32_t *)param)[i]);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;
            case 'f':
                for (i=0;i<paramLength;i++)
                {
                    sprintf(commInTextFormat,"%s%g, ",
                        commInTextFormat,((double *)param)[i]);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;
            case 'c':
                for (i=0;i<paramLength;i++)
                {
                    sprintf(commInTextFormat,"%s%c, ",
                        commInTextFormat,((char *)param)[i]);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;
            case 'x':
                for (i=0;i<paramLength;i++)
                {
                    sprintf(commInTextFormat,"%s0x%x, ",
                        commInTextFormat,((char *)param)[i]);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;
            case 's':
                offset = 0;
                for (i=0;i<paramLength;i++)
                {
                    /* extract each string individually */
                    sprintf(commInTextFormat,"%s%s, ",
                        commInTextFormat,param+offset);
                    offset += (strlen(param+offset)+1);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;
            case 'C':
                for (i=0;i<paramLength;i++)
                {
                    offset = strlen(commInTextFormat);
                    convert_crisis_comm_to_text(param,
                        detailsFlag, commInTextFormat+offset);
                }
                sprintf(commInTextFormat,"%s\n",commInTextFormat);
                break;

            default:
                /* unsupported argType */
                return CRISIS_FAILURE;
        }
        /* Now deal with the next parameter */
        paramIndex++;
    } 

    return CRISIS_SUCCESS;
}


/****f*  crisis_communication.c/add_strings_to_comm ****** 
 * NAME
 *	    add_strings_to_comm
 *
 * SYNOPSIS
 *      int32_t add_strings_to_comm(char *comm, 
 *         char *strings_to_add,
 *         int32_t number_of_elements)
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to which the double variable will
 *          be added
 *
 *      void *strings_to_add
 *          this is the pointer to the variable that contains the data to be
 *          added.  This has to be a '\0' terminated string.  Multiple strings
 *          are allowed indicated by the same pointer.  Each string must be 
 *          separated by a '\0'
 *      int32_t number_of_elements
 *          this is the number of '\0' separated strings in the vector pointed 
 *          to by 
 *          *strings_to_add.
 *
 * OUTPUT
 *      char *comm
 *          the data will be added and the appropriate header information
 *          will be updated
 *
 *      int32_t returnValue
 *         CRISIS_SUCCESS if conversion was successful
 *         CRISIS_FAILURE if conversion failed
 * 
 * PURPOSE
 *	    This function can be used to add a vector of strings to the 
 *	    comm according to the CRISIS_API_FORMAT.  The difference between using
 *	    this function and add_variable_to_comm is that this function accepts
 *	    a single string which has elements separated by \0 while the 
 *	    add_variable_to_comm accepts an array of char *.  It is often more
 *	    convinient to use a single string rather than allocate and free pointers
 *	    specially when the string length is not constant
 *
 * NOTES
 *      It is assumed that the comm has a valid header already defined
 *
 * BUGS
 *      There is no check builtin for the comm variable.  It 
 *      is assumed that enough memory is allocated to load the 
 *      complete data
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT, add_variable_to_comm,
 *      init_reply_comm
 *
 **********************************
 */

int32_t add_strings_to_comm(char *comm, char *strings_to_add,
        int32_t number_of_elements)
{
    /* Internally CRISIS_API_FORMAT uses the same  */
    /* strings separated by \0.  Hence all we have to do */
    /* is to fill in the appropriate variable header */
    
    int32_t commLength;
    int32_t i;
    int32_t numberOfVariablesOffset;
    char tempString[100];
    int32_t totalStringLength;
    
    if ((commLength = extract_comm_length(comm))==CRISIS_FAILURE)
        return CRISIS_FAILURE;
  
    /* check if there is a command present */
    if (sscanf(comm+CRISIS_API_HEADER_SIZE,"%s",tempString)!=1)
    {
        return CRISIS_FAILURE;
    }
    
    /* extract the number of variables */
    numberOfVariablesOffset = CRISIS_API_HEADER_SIZE+strlen(tempString)+1;
    
    /* make sure there is atleast one variable specified */
    if (number_of_elements<1)
        return CRISIS_FAILURE;
   
    /* first fill in the the preamble to the data */
    comm[commLength] = 's';
    *((uint32_t *)(comm+commLength+1)) = number_of_elements;
    
    commLength += 1+sizeof(uint32_t);
    
    /* and then fill in the data */
    totalStringLength = 0;
    for (i=0;i<number_of_elements;i++)
        totalStringLength += strlen(strings_to_add+totalStringLength)+1;
    
    /* copy the buffer */
    memcpy(comm+commLength,strings_to_add,totalStringLength);
    commLength += totalStringLength;
                
    /* now update the header to reflect the latest commLength */
    *((uint32_t *)(comm+CRISIS_KEYWORD_LENGTH)) = commLength;
  
    /* incremement the variable count */
    (*((uint32_t *)(comm+numberOfVariablesOffset)))+=1;
    
    return CRISIS_SUCCESS;
}




/****f*  crisis_communication.c/add_variable_to_comm ****** 
 * NAME
 *	    add_variable_to_comm
 *
 * SYNOPSIS
 *      int32_t add_double_variable_to_comm(char *comm, 
 *         void *variable_to_add,
 *         char data_type,
 *         int32_t number_of_elements)
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to which the double variable will
 *          be added
 *
 *      void *variable_to_add
 *          this is the pointer to the variable that contains the data to be
 *          added.  This could be one of the datatypes supported by CRISIS
 *          refer to CRISIS_API_FORMAT/CRISIS_VARIABLE_FORMAT for supported 
 *          data formats
 *      char data_type
 *          this is the datatype code.  The data type code is defined in the 
 *          CRISIS_API_FORMAT/CRISIS_VARIABLE_FORMAT documentation
 *      int32_t number_of_elements
 *          this is the number of elements in the vector pointed to by 
 *          *variable_to_add.
 *
 * OUTPUT
 *      char *comm
 *          the data will be added and the appropriate header information
 *          will be updated
 *
 *      int32_t returnValue
 *         CRISIS_SUCCESS if conversion was successful
 *         CRISIS_FAILURE if conversion failed
 * 
 * PURPOSE
 *	    This function can be used to add a vector of variables to the 
 *	    comm according to the CRISIS_API_FORMAT.  
 *
 * NOTES
 *      It is assumed that the comm has a valid header already defined
 *      when using the string format. it is assumeed that the strings arguments
 *      are less than FIXED_STRING_LENGTH long
 *
 * BUGS
 *      There is no check builtin for the comm variable.  It 
 *      is assumed that enough memory is allocated to load the 
 *      complete data
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT
 *
 **********************************
 */

int32_t add_variable_to_comm(char *comm, void *variable_to_add,
        char data_type, int32_t number_of_elements)
{
    int32_t commLength;
    int32_t i;
    int32_t numberOfVariablesOffset;
    char tempString[100];
    
    if ((commLength = extract_comm_length(comm))==CRISIS_FAILURE)
        return CRISIS_FAILURE;
  
    /* check if there is a command present */
    if (sscanf(comm+CRISIS_API_HEADER_SIZE,"%s",tempString)!=1)
    {
        return CRISIS_FAILURE;
    }
    
    /* extract the number of variables */
    numberOfVariablesOffset = CRISIS_API_HEADER_SIZE+strlen(tempString)+1;
    
    /* make sure there is atleast one variable specified */
    if (number_of_elements<1)
        return CRISIS_FAILURE;
   
    /* first fill in the the preamble to the data */
    comm[commLength] = data_type;
    *((uint32_t *)(comm+commLength+1)) = number_of_elements;
    
    commLength += 1+sizeof(uint32_t);
    
    /* and then fill in the data */
    switch (data_type)
    {
        case 'f':
            for (i=0;i<number_of_elements;i++)
            {
                memcpy(comm+commLength,(char *)variable_to_add+i*sizeof(double),
                    sizeof(double));
                commLength+=sizeof(double);
            }
            break;
        case 'd':
            for (i=0;i<number_of_elements;i++)
            {
                memcpy(comm+commLength,(char *)variable_to_add+i*sizeof(int32_t),
                        sizeof(int32_t));
                commLength+=sizeof(int32_t);
            }
            break;

        case 's':
            for (i=0;i<number_of_elements;i++)
            {
                sprintf(comm+commLength,"%s",
                        ((char **)(variable_to_add))[i]);
                commLength+=(strlen(((char **)(variable_to_add))[i])+1);
            }
            break;
        case 'c':
        case 'x':
            for (i=0;i<number_of_elements;i++)
            {
                memcpy(comm+commLength,(char *)variable_to_add+i*sizeof(char),
                        sizeof(char));
                commLength+=sizeof(char);
            }
            break;
        case 'C':
            for (i=0;i<number_of_elements;i++)
            {
                memcpy(comm+commLength,
                        ((char **)(variable_to_add))[i],
                        extract_comm_length(((char **)(variable_to_add))[i]));
                commLength+=extract_comm_length(
                        ((char **)(variable_to_add))[i]);
            }
            break;
        default:
            return CRISIS_FAILURE;
    }

    /* now update the header to reflect the latest commLength */
    *((uint32_t *)(comm+CRISIS_KEYWORD_LENGTH)) = commLength;
  
    /* incremement the variable count */
    (*((uint32_t *)(comm+numberOfVariablesOffset)))+=1;
    
    return CRISIS_SUCCESS;
}
            
/****f*  crisis_communication.c/init_command_comm ****** 
 * NAME
 *      init_command_comm
 *
 * SYNOPSIS
 *      int32_t init_command_comm(char *comm, char *command) 
 *
 * INPUTS
 *      char *comm
 *          the crisis communication to which the double variable will
 *          be added
 *      char *command
 *          the command to be included in the comm
 * OUTPUT
 *      char *comm
 *          the header will be initialized
 *
 *      int32_t returnValue
 *         CRISIS_SUCCESS if conversion was successful
 *         CRISIS_FAILURE if conversion failed
 * 
 * PURPOSE
 *	    This function can be used to initialize a header for a CRISIS reply
 *	    as per the CRISIS_COMMAND_FORMAT description.  
 *
 * NOTES
 *      All previous information stored in the header will be lost
 *
 * BUGS
 *      There is no check builtin for the comm variable.  It 
 *      is assumed that enough memory is allocated  for storing the headder
 *
 * SEE ALSO
 *      CRISIS_API_README, CRISIS_COMMAND_FORMAT, CRISIS_HEADER_FORMAT
 *
 **********************************
 */

int32_t init_command_comm(char *comm, char *command)
{
    int32_t offset;
    
    /* insert the keyword */
    memcpy(comm,CRISIS_COMMAND_KEYWORD,CRISIS_KEYWORD_LENGTH);
    
    /* a pure header is 32 bits in length.   */
    /* and by default always initialize with SUCCESS with 0 variables  */
    sprintf(comm+CRISIS_API_HEADER_SIZE,"%s",command);
    offset = CRISIS_API_HEADER_SIZE+strlen(command)+1;
    *((uint32_t *)(comm+offset)) = 0;
    
    /* update the comm length */
    *((uint32_t *)(comm+CRISIS_KEYWORD_LENGTH)) = offset
            +sizeof(uint32_t);
   
    return CRISIS_SUCCESS;
}
