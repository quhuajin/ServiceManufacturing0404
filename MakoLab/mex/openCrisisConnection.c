/****h* $RCSfile: openCrisisConnection.c,v $ *** 
 * NAME
 *      $RCSfile: openCrisisConnection.c,v $    $Revision: 2753 $
 *
 * COPYRIGHT
 *      Copyright (c) 2007 Mako Surgical Corp
 *
 * PURPOSE
 *      This function connects to the socket based HgsSocket
 *
 * SEE ALSO
 *      refer to m file documentation on useage
 *    
 * CVS INFORMATION
 *      $Revision: 2753 $
 *      $Date: 2012-10-25 14:49:42 -0400 (Thu, 25 Oct 2012) $
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
    int sock;
    struct hostent *hp;
    struct sockaddr_in hgsServerAddr;
    char *hostname;
    uint16_T port=0;
    int connectStatus = -1;
    mxArray *mx_host;
    mxArray *mx_port;
    mxArray *mx_sock;
    int port_search_start=7101;
    int port_search_end  =7110;
    char lockFileName[1024];
    FILE *fid;
    int prev_sock;
    int prev_port;
    int peer_size;

    long unsigned int socketOptions;
    fd_set sockFD;
    struct timeval socketTimeout;
    int res;
    int opts=0;
    
#ifdef _WIN32
    WSADATA wsaData;
#endif

    /* Verify the inputs */
    if ((nrhs > 2) || (nrhs<1))
    {
        mexErrMsgTxt("Wrong number of inputs");
        return;
    }

    /* if there are more than one input  */
    /* the first is assumed to */
    /* be a string which is the hostname */
    if (!mxIsChar(prhs[0])) 
    {
        mexErrMsgTxt("Hostname must be a string.");
        return;
    }
    hostname = mxArrayToString(prhs[0]);

    if(nrhs == 2) 
    {
        /* if there are two inputs the first input is assumed */
        /* to be the hostname and the second is assumed to be  */
        /* the port number */
        if(!mxIsNumeric(prhs[1])) 
        {
            mexErrMsgTxt("Port number must be an Unsigned Integer");
            return;
        }
        port = (uint32_T)(mxGetScalar(prhs[1]));
        port_search_start = port;
        port_search_end = port;
    }

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

    /* check if a lock file for the given hostname exists */
    if (!access(lockFileName,0))
    {
        /* test the connection */
        if ((fid = fopen(lockFileName,"r"))==NULL)
        {
            mexErrMsgTxt("Unable to open lock file");
            return;
        }

        /* retrive the sock id  */
        if (fscanf(fid,"%d %d",&prev_sock,&prev_port)!=2)
        {
            fclose(fid);
            mexErrMsgTxt("Invalid lock file");
            return;
        }
        fclose(fid);
        /* now check if the connection is valid */
        peer_size = sizeof(struct sockaddr);
        if ((getpeername(prev_sock,(struct sockaddr *)&hgsServerAddr,
                    &peer_size)==0)&&(prev_port==port))
        {
            /* this socket seems to be valid */
            /* just return it */
            plhs[0] = mxCreateCellMatrix(3,1);
            /* Set output */
            mxSetCell(plhs[0],0,mxCreateString(hostname));
            mxSetCell(plhs[0],1,mxCreateDoubleScalar(prev_port));
            mxSetCell(plhs[0],2,mxCreateDoubleScalar(prev_sock));
            return;
        }
    } 

    /* Start the socket interface dll */
#ifdef _WIN32
    WSAStartup(0x0101,&wsaData);
#endif
    sock = -1;

    /* Prepare the socket for use */
    if((sock = (int)socket(AF_INET,SOCK_STREAM,0)) == -1) 
    {
        mexErrMsgTxt("Cannot open socket");
        return;
    }

#ifdef _WIN32
    socketOptions=1;
    ioctlsocket(sock,FIONBIO,&socketOptions);
#else
    opts = fcntl(sock,F_GETFL);
    fcntl(sock, F_SETFL, O_NONBLOCK);
#endif

    /* setup the timeout */
    socketTimeout.tv_sec = 0;
    socketTimeout.tv_usec = 200000;

    /* for all the available ports try connecting */
    for (port=port_search_start;port<=port_search_end;port++) 
    {
        /* clear the hgsServerAddr before use */
        memset(&hgsServerAddr,0,sizeof(hgsServerAddr));

        /* now start setting the components */
        hgsServerAddr.sin_family = AF_INET;
        hgsServerAddr.sin_addr.s_addr = 
            ((struct in_addr *)hp->h_addr)->s_addr;
        hgsServerAddr.sin_port = htons(port);

        /* Try to connect */
        connectStatus = connect(sock,(struct sockaddr *)&hgsServerAddr,
                    sizeof(hgsServerAddr));

        if (connectStatus >= 0) 
        {
            break;
        }
        else
        {

            /* wait for connection success using select */
            FD_ZERO(&sockFD);
            FD_SET(sock,&sockFD);
            if (select(sock+1,NULL,&sockFD,NULL,&socketTimeout)>0)
            {
                connectStatus = 1;
                break;
            }
        }
    }

    /* set back in the blocking mode */
#ifdef _WIN32
    socketOptions=0;
    ioctlsocket(sock,FIONBIO,&socketOptions);
#else
    fcntl(sock, F_SETFL, opts);
#endif
        
    if (connectStatus < 0) {
        mexErrMsgTxt("Unable to open connection to Arm Software");
#ifdef _WIN32
        closesocket(sock);
#else
        close(sock);
#endif
        sock = -1;
        return;
    } 
    else 
    {
        /* create a lock file and store the sock id for future */
        /* reference incase we lose the sock id */
        /* test the connection */
        if ((fid = fopen(lockFileName,"w"))==NULL)
        {
#ifdef _WIN32
            closesocket(sock);
#else
            close(sock);
#endif
            sock = -1;
            mexErrMsgTxt("Unable to create lock file");
            return;
        }
        fprintf(fid,"%d %d",sock,port);
        fflush(fid);
        fclose(fid);        
        
        /* prepare for the reply */
        plhs[0] = mxCreateCellMatrix(3,1);
        /* Set output */
        mxSetCell(plhs[0],0,mxCreateString(hostname));
        mxSetCell(plhs[0],1,mxCreateDoubleScalar(port));
        mxSetCell(plhs[0],2,mxCreateDoubleScalar(sock));
        return;
    }
}

/*--------- END OF FILE ----------- */
