/****h* $RCSfile: closeCrisisConnection.c,v $ *** 
 * NAME
 *      $RCSfile: closeCrisisConnection.c,v $    $Revision: 2761 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function closes a socket
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 2761 $
 *      $Date: 2012-10-26 13:34:25 -0400 (Fri, 26 Oct 2012) $
 *      $Author: jforsyth $
 *
 ***************
 */

#include <mex.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

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

#include <unistd.h>
#include <fcntl.h>

#endif /* _WIN32 */



void mexFunction(int nlhs, mxArray *plhs[],
	 int nrhs, const mxArray *prhs[])
{

    char lockFileName[1024];
    FILE *fid;
    struct hostent *hp;
    char *hostname;

    int sock = -1;
    
    /* retrive the hostname */
    hostname = mxArrayToString(prhs[0]);
    
    /* resolve the host */
    if ((hp = gethostbyname(hostname))==NULL) 
    { 
        mexErrMsgTxt("Unable to resolve host");
        return;
    }

    /* generate a lock filename based on the ip address */
    /* to account for aliases. */
        #ifdef _WIN32
    sprintf(lockFileName,"%s\\~%s",getenv("TEMP"),
            inet_ntoa(*((struct in_addr *)hp->h_addr)));
    #else
        sprintf(lockFileName,P_tmpdir"/.%s",
                inet_ntoa(*((struct in_addr *)hp->h_addr)));
    #endif
    
    if (remove(lockFileName) != 0){
             perror("Error in deleting a file");
    }

    /* extract the input */
    if(nrhs != 2)
    {
        mexErrMsgTxt("Wrong number of inputs");
        return;
    }

    /* Extract the data */
    if(!mxIsNumeric(prhs[1]))
    {
        mexErrMsgTxt("Argument should be numeric");
        return;
    }

    sock = (int) mxGetScalar(prhs[1]);
    if(sock==-1)
        return;

#ifdef _WIN32
    shutdown(sock,SD_BOTH);
    closesocket(sock);
#else
    close(sock);
#endif
    return;
}

/*-------- END OF FILE -------- */
