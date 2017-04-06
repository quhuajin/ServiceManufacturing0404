/*//////////////////////////////////////////////////////////////////////////////
/                                / Copyright (c) 1993-2010                     /
/ ARMDLL32.H                     /                        All Rights Reserved. /
/                                / Confidential property not for distribution. /
////////////////////////////////////////////////////////////////////////////////
/ Property of Revware, Inc.                                 Phone 919-790-0000 /
/ PO Box 90786, Raleigh, NC 27675-0786 USA                  Fax   919-790-9110 /
////////////////////////////////////////////////////////////////////////////////

OBJECT		ARMDLL32.DLL

DESCRIP:	Header file identifying the interfaces of the MicroScribe interface DLL.

AUTHORS:	W. Thomas Welsh, et al.

NOTES:		MicroScribe is a registered trademark of Revware, Inc.

REVISIONS:

//////////////////////////////////////////////////////////////////////////////*/

//The following ifdef block is the standard way of creating macros which make exporting 
//from a DLL simpler. All files within this DLL are compiled with the ARMDLL32_EXPORTS
//symbol defined on the command line. this symbol should not be defined on any project
//that uses this DLL. This way any other project whose source files include this file see 
//ARMDLL32_API functions as being imported from a DLL, wheras this DLL sees symbols
//defined with this macro as being exported.

#ifndef ARMWIN32_H
#define ARMWIN32_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef ARMDLL32_EXPORTS
#define ARMDLL32_API
	//exported with the def file... no need for declspec
	//#define ARMDLL32_API __declspec(dllexport)
#else
#define ARMDLL32_API __declspec(dllimport)
#endif

#ifdef TRY_AGAIN
#undef TRY_AGAIN
#endif

//September 2008
#ifndef SERIAL_NUMBER_DISCRIMINATOR_ENABLED
	#define SERIAL_NUMBER_DISCRIMINATOR_ENABLED 1
#endif

//***************************************************************************
//Dll's Registered Messages.
//***************************************************************************

#define ARM_MESSAGE							"MscribeUpdate"
#define ARM_DISCONNECTED_MESSAGE			"Mscribe device disconnected"

//****************************************************************************
//Error Codes.
//****************************************************************************
#define ARM_SUCCESS							0
#define ARM_ALREADY_USED					-1
#define ARM_NOT_ACCESSED					-2
#define ARM_CANT_CONNECT					-3
#define ARM_INVALID_PARENT					-4
#define ARM_NOT_CONNECTED					-5
#define ARM_BAD_PORTBAUD					-6

//New error codes for ArmDll32 2.0
#define ARM_OUTOFMEMORY						-7
#define ARM_BUFFER_TOO_SMALL				-8
#define ARM_INVALID_PARAM					-9
#define ARM_DATA_ACCESS_ERROR				-10
#define ARM_VERSION_NUMBER_NOT_AVAILABLE	-11
#define ARM_WRONG_ERROR_HANDLER_TYPE		-12
#define ARM_CANT_GET_NUMDOF					-13

//sphere generate error codes
#define NOT_ENOUGH_POINTS					-14
#define INVALID_ARGUMENTS					-15
#define	NOT_CONVERGED						-16
#define PTS_TOO_CLOSE						-17
#define	SPHERE_SUCCESS						 0
//****************************************************************************
//Exported string.
//****************************************************************************

ARMDLL32_API char     TIMED_OUT[];		//Didn't get complete packet in time
ARMDLL32_API char     SUCCESS[];		//Successful operation
ARMDLL32_API char     BAD_PORT_NUM[];	//Port number not valid
ARMDLL32_API char     CANT_OPEN_PORT[];	//Can't open the port during start-up
ARMDLL32_API char     NO_HCI[];			//No response from HCI during start-up
ARMDLL32_API char     CANT_BEGIN[];		//No response to "BEGIN" at start of session
ARMDLL32_API char     NO_PACKET_YET[];	//Complete packet not yet recv'd
ARMDLL32_API char     BAD_PACKET[];		//Received packet that did not make sense
ARMDLL32_API char     BAD_PASSWORD[];	//Cfg cmd requiring passwd was denied
ARMDLL32_API char     BAD_VERSION[];	//Feature isn't supported by firmware
ARMDLL32_API char     BAD_FORMAT[];		//Parameter block is in unreadable format
ARMDLL32_API char     TRY_AGAIN[];		//Try the operation again

//****************************************************************************
//Constants
//****************************************************************************

//Update Type
#define ARM_3DOF			0x0001		//only arm_rec.stylus_tip fields and buttons are updated
#define ARM_6DOF			0x0002		//Both arm_rec.stylus_tip, arm_rec.stylus_dir and buttons fields are updated
#define ARM_3JOINT			0x0004		//only first 3 joint angles of arm_rec.joint_rad and arm_rec.joint_deg  are updated
#define ARM_6JOINT			0x0008		//the 6 joint angles are updated
#define ARM_FULL			0x0010		//same as ARM_6DOF

#define ARM_INCHES			1
#define ARM_MM				2

#define ARM_DEGREES			1
#define ARM_RADIANS			2

#define NUM_ENCODERS		7       //Max # encoders supported by Microscribe HCI
#define NUM_ANALOGS			8       //Max # of A/D channels supported
#define NUM_BUTTONS			7       //Max # of buttons supported

//# of bytes in longest possible packet, plus some extra room
#define MAX_PACKET_SIZE         42

//Max length of descriptor string from HCI
#define MAX_STRING_SIZE         32
#define PARAM_BLOCK_SIZE		40
#define EXT_PARAM_BLOCK_SIZE	10
#define NUM_DOF					6
#define NUM_THETA_PARAM			7

//Maximum value of 6th encoder value
#define MAX_STYLUS_ROLL_ENCODER	2000

//Default minimum period update
#define DEFAULT_PERIOD_UPDATE	20	//ms this is also the default update rate used by ArmDll32 v1.xx,
									//which also used 9600bauds as default baud rate
#define MINIMUM_PERIOD_UPDATE	1	//ms //@D0001 Changed from 2 ms to 1 ms for improved compatability with Kreon Lasers.
#define MAXIMUM_PERIOD_UPDATE	250	//ms

//Buttons
#define ARM_BUTTON_1			0x0001
#define ARM_BUTTON_2			0x0002
#define ARM_BUTTON_3			0x0004
#define ARM_BUTTON_4			0x0008
#define ARM_BUTTON_5			0x0010
#define ARM_BUTTON_6			0x0020
#define ARM_BUTTON_7			0x0040


//Device status
#define ARM_CONNECTED			0x0001
#define ARM_USING_USB_PORT		0x0002
#define ARM_USING_SERIAL_PORT	0x0004

//Error handler function type constants
#define BAD_PORT_HANDLER		0x0001
#define CANT_OPEN_HANDLER		0x0002
#define NO_HCI_HANDLER			0x0004
#define CANT_BEGIN_HANDLER		0x0008
#define TIMED_OUT_HANDLER		0x0010
#define BAD_PACKET_HANDLER		0x0020

//***************************************************************************
//Simple Data Type definition
//***************************************************************************

//Shorthand for a byte
typedef unsigned char   byte;

//Use hci_result as if it were an enumerated type.  Compare variables of
//this type to the string constants declared below.  An hci_result is
//actually a string, so it can be directly printed as well.
typedef char*   hci_result;
typedef float   length;
typedef float   angle;
typedef float   ratio;
typedef float   matrix_4[4][4];

//Strings as enumerated types.
//Variables of these types will point to one of several global
//string constants.  This means you can compare these variables
//to the global string pointers, just as you would compare a regular
//enumerated type to a set of enumerated constants.  You can also
//directly print these labels, since they are actually strings.

typedef char*   length_units;
typedef char*   angle_units;
typedef char*   angle_format;

//****************************************************************************
//Structure definitions
//****************************************************************************

//General 3D spatial coordinate data type
#pragma pack(push, 1)
typedef struct
{
	length  x;
	length  y;
	length  z;
} length_3D;

//General 3D angular coordinate data type
typedef struct
{
	angle   x;
	angle   y;
	angle   z;
} angle_3D;

//Record for packet
#pragma pack(push, 1)
typedef struct
{
	int     parsed;		//Flag tells whether this packet has been parsed
	int     error;		//Flag tells whether there has been com error
	int     num_bytes_needed;
	byte    cmd_byte;
	byte    data[MAX_PACKET_SIZE];
	byte    *data_ptr;
} packet_rec;

typedef struct
{
	DWORD status;
	UINT Baud;
	UINT PortNumber;
} device_status;

//Record containing all HCI data
//Declare one of these structs for each Microscribe HCI in use.
//The hci_connect() command will establish communication with a Microscribe
//HCI and set up an hci_rec corresponding to it.
//Example references: (assuming 'hci' is declared as an hci_rec)
//hci.button[2] - ON/OFF status of button #2
//hci.encoder[1] - total count for encoder #1
//hci.baud_rate - baud rate in use with this Microscribe HCI

typedef struct hci_rec
{
//Communications parameters
	int             port_num;		//This HCI's serial port number
	long int        baud_rate;		//This Probe's baud rate
	float           slow_timeout;	//Timeout period for slow process
	float           fast_timeout;	//Timeout period for fast process
	packet_rec      packet;			//The current packet
	int             packets_expected; //Determines whether timeout is important

	//Marker field lets you mark different segments of data in incoming
	//buffer.  hci_insert_marker() makes HCI insert a marker into the
	//data stream, so you can switch modes in a host application
	//without misinterpreting some data that may still be waiting
	//in the buffer; just insert a marker, and don't switch modes
	//until you see the marker come back.
	int             marker;
	int             marker_updated;

//Primary quantities:
	int     buttons;				//button bits all together
	int     button [NUM_BUTTONS];	//ON/OFF flags for buttons
	long    timer;					//Running counter
	int     analog [NUM_ANALOGS];	//A/D channels
	int     encoder [NUM_ENCODERS];	//Encoder counts

	//Normalization values for primary quantities:
	//These values give some reference or normalization quantity for each field.
	//A zero in any of these fields means there is no hardware
	//support for that data in this particular system.
	int     button_supported [NUM_BUTTONS];	//zero = button not supported
	int     max_timer;						//Max count reached before wrapping
	int     max_analog [NUM_ANALOGS];		//Full-scale A/D reading
	int     max_encoder [NUM_ENCODERS];		//Max value each encoder reaches INCLUDING quadrature

	//Status of primary fields:
	//A zero in any of these fields indicates that the corresponding
	//primary quantity is out of date (wasn't updated by the previous packets)
	//Note: buttons are updated with every packet
	int     timer_updated;
	int     analog_updated [NUM_ANALOGS];
	int     encoder_updated [NUM_ENCODERS];

	//Encoder "home" position:
	//The relative encoders supported by the Microscribe HCI only report
	//their NET angular motion from the time they are powered up.  If
	//an encoder's initial angular value is important, it must somehow
	//be assumed or calibrated at start-up.  These fields contain values
	//to be assumed at start-up.  They can be read from or written to the
	//Microscribe HCI EEPROM.  If written to the Microscribe HCI EEPROM,
	//these "home" values will be retained even after power is turned off.
	int     home_pos [NUM_ENCODERS];

	//Home position references:
	//In many cases some calibration procedure will be required to ensure
	//that the encoder positions truly match the assumed home position.
	//This array can store any data that is useful for that purpose.
	 int    home_ref [NUM_ENCODERS];

	//Descriptor strings:
	//These strings provide information about a particular HCI system.
	char    serial_number [MAX_STRING_SIZE];
	char    product_name [MAX_STRING_SIZE];
	char    product_id [MAX_STRING_SIZE];
	char    model_name [MAX_STRING_SIZE];
	char    comment [MAX_STRING_SIZE];
	char    param_format [MAX_STRING_SIZE];
	char    version [MAX_STRING_SIZE];

	//Function pointers to handle application-specific functions
	//These pointers are initialized to NULL.
	//The user can make these point to handlers for each specific condition.
	//These handlers must be declared as follows:
	//hci_result   my_handler(hci_rec *hci, hci_result condition);
	//See programmer's guide for more discussion.

	//Handlers for errors
	hci_result      (*BAD_PORT_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*CANT_OPEN_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*NO_HCI_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*CANT_BEGIN_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*TIMED_OUT_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*BAD_PACKET_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*BAD_PASSWORD_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*BAD_VERSION_handler)(struct hci_rec *hci, hci_result condition);
	hci_result      (*BAD_FORMAT_handler)(struct hci_rec *hci, hci_result condition);

	//Handler to use for an error if everything above is NULL
	//The simplest way to get diagnostic reporting is to
	//set default_handler to a function that outputs the string
	//that is passed as the 'condition'.  This can be implemented
	//under any operating system or window environment by including
	//the appropriate o.s. calls in the function pointed to by
	//this handler pointer.
	hci_result      (*default_handler)();

	//Extra field available for user's application-specific purpose
	long int        user_data;
} hci_rec;
#pragma pack(pop)

//Error Handler function definition
typedef hci_result ( *PERRORHANDLER ) (struct hci_rec *hci, hci_result condition);

//Record containing all Arm data
//Declare one of these structs for each Arm in use.
//Each arm_rec must be init'ed with arm_init() before use.
//Example references: (assuming 'arm' is declared as a arm_rec)
//arm.stylus_tip.x - x coord of stylus tip (stylus is last joint of arm)
//arm.stylus_dir.y - the y-axis angle of stylus orientation
//arm.joint_deg[ELBOW] - joint angle #2 (elbow) in degrees
typedef struct arm_rec
{
	//Fields for direct use by programmers:
	//These fields will be maintained and used consistently in future releases
	//If a field's units are not specified, then they are user-settable
	//as inches/mm or radians/degrees

	//Fundamental 6DOF quantities
	length_3D       stylus_tip;		//Coordinates of stylus tip
	angle_3D        stylus_dir;		//Direction (roll,pitch,yaw) of stylus

	//Transformation matrix representing stylus 6DOF coordinates
	//4-by-4 matrix, arm.T[0][0] through arm.T[3][3]
	matrix_4        T;

	//Series of linkage endpoints
	length_3D       endpoint [NUM_DOF];	//also includes stylus tip

	//Joint angles
	angle           joint_rad [NUM_DOF];	//radians
	angle           joint_deg [NUM_DOF];	//degrees

	//Units and orientation format:
	//READ-ONLY.  Use functions provided to set these.

	//Unit conversion and data format specifiers:
	length_units    len_units;		//inches/mm for xyz coordinates
	angle_units     ang_units;		//radians/degrees for stylus angles
	angle_format    ang_format;		//xyz_fixed/zyx_fixed ... for stylus angles

	//Fields describing internal physical structure:
	//These may change with refinements to the Arm and calibration techniques.

	length  D[NUM_DOF];		//Offsets between joint axes
	length  A[NUM_DOF];		//Offsets between joint axes
	angle   ALPHA[NUM_DOF];	//Skew angles between joint axes
	angle   BETA;			//the beta angle in T23

	//Internal working variables:
	//These are used internally for efficient calculation and are subject to change.
	//Pre-computed conversion factors
	//Factors to multiply by encoder counts in order to get angles in radians
	ratio   JOINT_RADIANS_FACTOR[NUM_DOF];
	//Factors to multiply by encoder counts in order to get angles in degrees
	ratio   JOINT_DEGREES_FACTOR[NUM_DOF];

	//Intermediate matrix products
	matrix_4        M[NUM_DOF];

	//Trigonometric quantities:
	ratio           cs[NUM_DOF];		//cosines of all angles
	ratio           sn[NUM_DOF];		//sines of all angles
	ratio           csALPHA[NUM_DOF];	//cs & sn of ALPHA const's
	ratio           snALPHA[NUM_DOF];

	//Internal status variables:
	//Do not access directly.  Use functions provided to manipulate these.

	//Fields requested in subsequent reports
	int             timer_report;	//Flag telling whether to report timer
	int             anlg_reports;	//# of analog values to report

	//Number of points needed in next endpoint calculation
	int             num_points;

	//Calculation function to execute after getting next packet
	void            (* packet_calc_fn)(struct arm_rec*);

	//Low-level data:
	hci_rec         hci;
	byte            param_block[PARAM_BLOCK_SIZE];
	int             p_block_size;

	byte			ext_param_block[EXT_PARAM_BLOCK_SIZE];
    int				ext_p_block_size;

    float			pt2ptdist;		//distance between points in AutoPlotPoint()
	float			lastX, lastY, lastZ; //last point taken

	float			D5Point;		//standard stylus length with standard point tip
} arm_rec;

#pragma pack(pop)


//****************************************************************************
//Exported variables
//****************************************************************************
ARMDLL32_API char     INCHES[];
ARMDLL32_API char     MM[];

//****************************************************************************
//Function Prototypes
//****************************************************************************
ARMDLL32_API int	__stdcall	ArmStart				(HWND hwndParent);
ARMDLL32_API void	__stdcall	ArmEnd					(void);

ARMDLL32_API int	__stdcall	ArmConnectSN			(int port, long baud, char* serialNumber);
ARMDLL32_API int	__stdcall	ArmConnect				(int port, long baud);

ARMDLL32_API void	__stdcall	ArmDisconnect			(void);
ARMDLL32_API int	__stdcall	ArmReconnect			(void);
ARMDLL32_API int	__stdcall	ArmSetBckgUpdate		(int type);
ARMDLL32_API int	__stdcall	ArmSetUpdate			(int type);

ARMDLL32_API void * __stdcall	ArmGetArmRec			(void);
ARMDLL32_API void	__stdcall	ArmSetLengthUnits		(int type);
ARMDLL32_API void	__stdcall	ArmSetAngleUnits		(int type);

ARMDLL32_API  void	__cdecl		arm_calc_stylus_3DOF	(arm_rec *arm);
ARMDLL32_API  void  __cdecl		arm_calc_joints			(arm_rec *arm);
ARMDLL32_API  void  __cdecl		arm_calc_params			(arm_rec *arm);

//New functions for ArmDll32 2.0
ARMDLL32_API int	__stdcall	ArmSetUpdateEx			(int type, UINT minUpdatePeriodms);
ARMDLL32_API void	__stdcall	ArmCustomTip			(float delta);
ARMDLL32_API  int	__stdcall	ArmGetTipPosition 		(length_3D* pPosition);
ARMDLL32_API  int	__stdcall	ArmGetTipOrientation	(angle_3D  *pAngles);
ARMDLL32_API  int	__stdcall	ArmGetTipOrientationUnitVector(angle_3D  *pOrientationUnitVector);
ARMDLL32_API  int	__stdcall	ArmGetProductName		(char *szProductName, UINT  uiBufferLength);
ARMDLL32_API  int	__stdcall	ArmGetSerialNumber		(char *szSerialNumber, UINT  uiBufferLength);
ARMDLL32_API  int	__stdcall	ArmGetModelName			(char *szModelName, UINT  uiBufferLength);
ARMDLL32_API  int	__stdcall	ArmGetVersion			(char *szArmDllVersionNumber, char *szFirmwareVersionNumber, UINT  uiBufferLength);
ARMDLL32_API  int	__stdcall	ArmGetNumButtons		(int* piNumButtons);
ARMDLL32_API  int	__stdcall	ArmGetButtonsState		(DWORD *pdwButtonsState);
ARMDLL32_API  int	__stdcall	ArmGetDeviceStatus		(device_status *pDeviceStatus);
ARMDLL32_API  int	__stdcall	ArmSetErrorHandlerFunction(int iErrorType, PERRORHANDLER pErrorHandlerFunction );
ARMDLL32_API  int	__stdcall	ArmGetNumDOF			(int *piNumDOF);
ARMDLL32_API  int	__stdcall	ArmGetEncoderCount		(int *piEncoderValues );
ARMDLL32_API  int	__stdcall	ArmGetJointAngles		(int iUnitID, angle *piJointAngle );
ARMDLL32_API  int	__stdcall	ArmSetHomeEncoderOffset (int *piEncoderOffsets);
ARMDLL32_API  int	__stdcall	ArmSetTipPositionOffset (int iUnitID, length Xoffset, length Yoffset, length ZOffset);
ARMDLL32_API  int	__stdcall	ArmSetSoftHome();

ARMDLL32_API  int	__stdcall	ArmGetFullTip(length_3D* pPosition, 
												angle_3D  * vecT0, angle_3D *vecT1, angle_3D *vecT2, DWORD *pdwButtonsState);


//custom tip support functions
ARMDLL32_API int   __stdcall ArmSetTipProfile(int _tipNumber);
ARMDLL32_API int   __stdcall ArmGetTipProfile(int *_tipNumber);
ARMDLL32_API int   __stdcall ArmSaveTipProfile(int _tipNumber, 
												int *_homeDelta,
												float *_tipOffset,
												char *_name);
ARMDLL32_API int   __stdcall ArmGetTipProfileHomeOffset(int _tipNumber,
														 int *_homeDelta);
ARMDLL32_API int   __stdcall ArmGetTipProfilePositionOffset(int _tipNumber,
														     float *_tipOffset);
ARMDLL32_API int   __stdcall ArmGetTipNameData(int _tipNumber,
												char *_name);
ARMDLL32_API int  __stdcall ArmGenerateTipPositionOffset(length_3D *_points,
														 angle_3D *_orientations,
													     int _numPoints,
														 length_3D &_offset );

ARMDLL32_API int  __stdcall ArmGenerateTipPositionOffsetEx(length_3D *_points,
														 angle_3D *_orientations,
													     int _numPoints,
														 length_3D &_offset,
														 angle_3D *_unitOrientations );


#ifdef __cplusplus
}
#endif

#endif //ARMDLL32_H
