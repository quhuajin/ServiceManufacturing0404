/****h* /crisis_commuication.h *** 
 * NAME
 * 		crisis_commuication.h	$Revision: 2929 $
 *
 * COPYRIGHT
 * 		Copyright (c) 2007 Mako Surgical Corp.
 *
 * PURPOSE
 *              Set of functions implementing the CRISIS API.  
 *              See CRISIS_API_README.txt for details
 * 
 * CVS INFORMATION
 * 		$Revision: 2929 $
 * 		$Date: 2013-05-20 15:24:47 -0400 (Mon, 20 May 2013) $
 * 		$Author: dmoses $
 *
 ***************
 */

#ifndef __CRISIS_COMMUNICATION_H__ /*make sure that crisis_commuication is not redeclared */
#define __CRISIS_COMMUNICATION_H__

#ifdef _WIN32
#include "stdint.h"
#else
#include <inttypes.h>
#endif


/* defines */
#define CRISIS_SUCCESS 1
#define CRISIS_FAILURE -1

#define CRISIS_COMMAND  1
#define CRISIS_REPLY    2

#define CRISIS_REPLY_SUCCESS    "SUCCESS"
#define CRISIS_REPLY_ERROR      "ERROR"
#define CRISIS_REPLY_WARNING    "WARNING"

#define DETAILS_DISPLAY_ON      1
#define DETAILS_DISPLAY_OFF     0

#define CRISIS_COMMAND_KEYWORD  "HgsClient"
#define CRISIS_REPLY_KEYWORD    "HgsServer"
#define CRISIS_KEYWORD_LENGTH   9

#define CRISIS_API_HEADER_SIZE  32
#define MAX_REPLY_STRING_LENGTH 102400 /* 100 KB */
#define DEFAULT_COMM_SIZE 1024

/* function definations */
int32_t parse_crisis_comm(char *comm, 
          int32_t paramIndex,
          char **commandWord,
          char **param,
          char *paramType,
          int32_t *paramLength);

int32_t check_crisis_comm(char *comm,
        uint32_t commLength,
        int32_t commandOrReply,
        char *errorMessage);

int32_t extract_comm_num_of_var(char *comm);

int32_t extract_comm_length(char *comm);

int32_t add_strings_to_comm(char *comm, char *strings_to_add,
        int32_t number_of_elements);

int32_t add_variable_to_comm(char *comm, void *variable_to_add,
        char data_type, int32_t number_of_elements);

int32_t init_command_comm(char *comm, char *command);

#endif /* __CRISIS_COMMUNICATION_H__ */




/*------------ END OF FILE ------------- */
