/****h* $RCSfile: sendReceiveCrisisComm.c,v $ *** 
 * NAME
 *      $RCSfile: sendReceiveCrisisComm.c,v $    $Revision: 2449 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function can be used to send a command to CRISIS
 *      and receive the response.  It must be noted that the
 *      command and response are in the CRISIS API format
 *
 *      CRISIS API Format is documented in the CRISIS_API_README in the 
 *      CRISIS project
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
#include "matrix.h"
#include <string.h>
#include "crisis_communication.h"

#ifdef _WIN32
/* use windows sockets */
#include <winsock2.h>

#else

/* Assume this is a unix based system  */
/* configure using berkley sockets */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h> 
#include <errno.h>
#endif /* _WIN32 */

void mexFunction(int nlhs, mxArray *plhs[],
		int nrhs, const mxArray *prhs[])
{
    int sockID;
    char *sendBuffer;
    char recvBuffer[MAX_REPLY_STRING_LENGTH];
    int sendBufferSize;
    int receiveSize;
    int bytesReceived;
    int totalBytesReceived;
    char errorMessage[100];

    /* check the inputs */
    if (nrhs!=2)
    {
        mexErrMsgTxt("Incompatible number of inputs "
                "for sendReceiveCrisisComm");
        return;
    }

    /* get the socket id */
    if (!mxIsNumeric(prhs[0]))
    {
        mexErrMsgTxt("Socket id MUST be an integer");
        return;
    }
    sockID = (int)mxGetScalar(prhs[0]);

    /* get pointer to the data */
    sendBuffer = (char *) mxGetData(prhs[1]);
    sendBufferSize = extract_comm_length(sendBuffer);

    /* send the data */
    if (send(sockID,sendBuffer,sendBufferSize,0)<0)
    {
#ifdef _WIN32
        sprintf(errorMessage,"Error sending command to CRISIS "
                "(Winsock ErrCode = %d)",WSAGetLastError());
#else
        sprintf(errorMessage,"Error sending command to CRISIS "
                "(%s)",strerror(errno));
#endif
        mexErrMsgTxt(errorMessage);
        return;
    }

    /* block and wait for reply */
    receiveSize = 0;
    totalBytesReceived = 0;
    do 
    {
        bytesReceived = recv(sockID,
                recvBuffer+totalBytesReceived,
                MAX_REPLY_STRING_LENGTH,0);
        if (bytesReceived == 0)
        {
            mexErrMsgTxt("Socket connection lost "
                    "(Connection closed by server)");
            return;
        }
        else if (bytesReceived<0)
        {
#ifdef _WIN32
            sprintf(errorMessage,"Error receiving CRISIS reply"
                    "(Winsock ErrCode = %d)",WSAGetLastError());
#else
            sprintf(errorMessage,"Error sending command to CRISIS "
                    "(%s)",strerror(errno));
#endif
            mexErrMsgTxt(errorMessage);
            return;
        }

        if (receiveSize==0)
        {
            if ((receiveSize = extract_comm_length(recvBuffer))
                    ==CRISIS_FAILURE)
            {
                mexErrMsgTxt("Invalid CRISIS reply received ");
                return;
            }
        }
        totalBytesReceived += bytesReceived;
    } while (totalBytesReceived<receiveSize);

    plhs[0] = mxCreateNumericMatrix(1,receiveSize,
                    mxUINT8_CLASS,mxREAL);
    
    memcpy(mxGetPr(plhs[0]),recvBuffer,receiveSize);
    return;
}

/* ------ END OF FILE ------- */
