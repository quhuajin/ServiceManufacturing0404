/*copyright 2005 ATI Industrial Automation*/
// ATICombinedDAQFT.h

/*
Initial version Dec.13.2004

modifications:
July.22.2005 - Sam Skuce (ATI Industrial Automation) - added ConnectionType enum
aug.5.2005a - ss - added GetHardwareTempComp
*/

#pragma once

#ifndef ATIDAQHARDWAREINTERFACE_H
#define ATIDAQHARDWAREINTERFACE_H

using namespace ati_SYSTEM_NAMESPACE;

#include "ATIDAQHardwareInterface.h"
#include "ftconfig.h"
#include "NIDAQmx.h"

namespace ATICombinedDAQFT
{
	/*July.22.2005 - ss - added ConnectionType*/

	ati_PUBLIC __value enum ConnectionType
	{
		DIFFERENTIAL = DAQmx_Val_Diff,
		REFERENCED_SINGLE_ENDED = DAQmx_Val_RSE,
		NON_REFERENCED_SINGLE_ENDED = DAQmx_Val_NRSE,
		PSEUDO_DIFFERENTIAL = DAQmx_Val_PseudoDiff,
	};

	ati_PUBLIC __gc class FTSystem
		{
	public:
		FTSystem(); /*default constructor*/
		~FTSystem(); /*destructor*/

		/*
		int ReadSingleGaugePoint( float64 gaugeValues __gc[] )
		Reads gauge values from system, with averaging.
		arguments:
			gaugeValues - in - array with room for all six or seven gauges (seven if software temperature
								compensation is enabled)
						 out - the averaged gauge values
		returns: 0 if successful, 2 if gauges are saturated, 1 if some other error occurs
		*/
		int ReadSingleGaugePoint( float64 gaugeValues __gc[] );	

		/*
		int StartSingleSampleAcquisition( String * deviceName, float64 sampleFrequency, int averaging,
			int firstChannel, bool useTempComp )
		starts the single sample acquisition
		arguments:
			deviceName - the name of the device which the transducer is connected to
			sampleFrequency - the frequency at which to sample the transducer voltages
			averaging - the number of raw samples to average together to make one output sample
			firstChannel - the lowest-numbered channel that the transducer is connected to on the DAQ card
			useTempComp - whether or not to enable temperature compensation.
		returns:
			 0 if successful, -1 otherwise
		*/
		int StartSingleSampleAcquisition( String * deviceName, float64 sampleFrequency, int averaging,
			int firstChannel, bool useTempComp );

		
		/*
		int StartBufferedAcquisition( String * deviceName, float64 sampleFrequency, int averaging,
			int firstChannel, bool useTempComp, int bufferSize )
		starts the buffered acquisition
		arguments:
			deviceName - the name of the device which the transducer is connected to
			sampleFrequency - the frequency at which to sample the transducer voltages
			averaging - the number of raw samples to average together to make one output sample
			firstChannel - the lowest-numbered channel that the transducer is connected to on the DAQ card
			useTempComp - whether or not to enable temperature compensation.
			bufferSize - the size of the buffer to allocate to hold the samples.  This is the number of output
				samples you wish the buffer to hold, so the total number of raw samples will be 
				(bufferSize * averaging)
		returns:
			 0 if successful, -1 otherwise
		*/
		int StartBufferedAcquisition( String * deviceName, float64 sampleFrequency, int averaging,
			int firstChannel, bool useTempComp, int bufferSize );		

		/*
		int StopAcquisition()
		stops the running hardware acquisition
		returns:
			0 if successful, -1 otherwise
		*/
		int StopAcquisition();

		/*
		String GetErrorInfo()
		get information about the last error that occurred
		returns:
			String with description of error
		*/
		String * GetErrorInfo();
		
		/*
		String * GetDeviceName()
		gets the name of the DAQ device to which the transducer is attached
		returns: the name of the DAQ device
		*/
		String * GetDeviceName() { return m_hiHardware->GetDeviceName(); }

		
		/*
		float64 GetSampleFrequency()
		get the frequency at which the transducer is sampled.  Divide this number by the AveragingSize (see
		GetAveragingSize) to get the effective sample rate.
		returns:
			the hardware sampling frequency
		*/
		float64 GetSampleFrequency( ) { return m_hiHardware->GetSampleFrequency(); }

		/*
		int GetAveragingSize()
		get the number of samples which are averaged together to reduce noise.  Divide the 'raw' sampling frequency,
		as returned by GetSampleFrequency, by this number to get the effective sampling rate
		returns:
			the number of raw samples which are averaged together to make one output sample
		*/
		int GetAveragingSize() { return m_hiHardware->GetAveragingSamples(); }

		/*
		int GetFirstChannel()
		get the first (lowest-numbered) channel that the transducer is connected to
		returns:
			the first channel that the transducer is connected to
		*/
		int GetFirstChannel() { return m_hiHardware->GetFirstChannel(); }

		
		/*
		int LoadCalibrationFile( calFile, calibrationIndex )
		loads an F/T transducer calibration file
		arguments:
			calFile - path to the .cal file for the transducer you are using
			calibrationIndex - the calibration within the file to use.  Should be 1 if there is only one
				calibration in the file
		returns:
			0 if successful, !0 if not successful
		side effects:
			resets the output units to whatever the calibration file specifies. If the hardware acquisition task is 
			currently running, make sure to restart it (i.e. via StartSingleSampleAcquisition) before attempting to
			read f/t values.  Otherwise, the temperature compensation, voltage range, etc. may not be correct for 
			the system you are using.
		*/
		int LoadCalibrationFile( String * calFile, int calibrationIndex );

		/*
		String * GetSerialNumber()
		get the serial number of the transducer, as specified in the loaded calibration file
		returns:
			the serial number of the transducer, or "" if no calibration has been successfully loaded
		*/
		String * GetSerialNumber();

		/*
		String * GetCalibrationDate()
		get the calibration date of the loaded calibration
		returns:
			a string reprenting the calibration date, or "" if no calibration has been successfully loaded
		*/
		String * GetCalibrationDate();

		/*		
		float64 GetMaxLoad( int axisIndex )
		get the maximum load of an axis.
		arguments:
			axisIndex - the index of the axis to find the maximum load of.  0=fx,1=fy,2=fz,3=tx,4=ty,5=tz
		returns:
			the maximum rated load of the specified axis, in the current output units, or 0 if the 
			calibration has not been initialized by calling LoadCalibrationFile
		*/
		float64 GetMaxLoad( int axisIndex );

		/*
		int SetForceUnits( String * forceUnits )
		set the units of the force outputs
		arguments:
			forceUnits - the force units to output in.  Acceptable values are "lb","klb","N","kN","g", or "kg"
		returns:
			0: successful completion
			1: calibration not initialized (call LoadCalibrationFile before calling this function )
			2: invalid force units specified
		*/
		int SetForceUnits( String * forceUnits );

		/*
		String * GetForceUnits()
		get the units of the force outputs
		returns:
			the current force output units, or "" if the calibration has not been successfully loaded
			by calling LoadCalibrationFile
		*/
		String * GetForceUnits();

		/*
		int SetTorqueUnits( String * torqueUnits )
		sets the units of the torque outputs
		arguments:
			torqueUnits - the units to output torques in.  Acceptable values are "in-lb","ft-lb","N-m","N-mm","kg-cm"
		returns:
			0: successful completion
			1: Calibration not initialized (call LoadCalibrationFile before calling this function)
			2: invalid units specified
		*/
		int SetTorqueUnits( String * torqueUnits );

		/*
		String * GetTorqueUnits( )
		get the units of the torque outputs
		returns:
			The output torque units, or "" if the calibration has not been initalized by calling
			LoadCalibrationFile
		*/
		String * GetTorqueUnits();

		/*
		bool GetTempCompAvailable()
		whether or not temperature compensation is available with this calibration
		returns:
			true if the loaded calibration has temperature compensation available, false if
			the loaded calibration does not have temperature compensation otherwise.  Also returns
			false if no calibration has been loaded with the function LoadCalibrationFile
		*/
		bool GetTempCompAvailable();

		/*
		bool GetTempCompEnabled()
		get whether or not temperature compensation is used
		returns:
			true if software temperature compensation is available and enabled, false if temperature compensation
			is not available or not enabled.  also returns false if this calibration has not been initialized
			by calling LoadCalibrationFile
		*/
		bool GetTempCompEnabled();	

		/*
		int ToolTransform( float64 transformVector __gc[6], String * distanceUnits, String * angleUnits )
		create a tool transformation to measure the forces and torques acting at a point other than the
		origin of the transducer
		arguments:
			transformVector: the displacements and rotations relative to the origin of the transducer
				transformVector[0] = displacement along x axis
				transformVector[1] = displacement along y axis
				transformVector[2] = displacement along z axis
				transformVector[3] = rotation about x axis (right-hand rotation)
				transformVector[4] = rotation about y axis (right-hand rotation)
				transformVector[5] = rotatation about z axis (right-hand rotation)
			distanceUnits - the units of the displacements.  Acceptable values are "in", "m", "mm", "cm", or "ft"
			angleUnits - the units of the rotations.  Acceptable values are "deg", "degrees", "degree", "rad",
				"radians", or "radian"
		returns:
			0: successful completion
			1: Calibration not initialized.  Call LoadCalibrationFile before calling this function
			2: Invalid Distance Units
			3: Invalid Angle Units
		*/
		int ToolTransform( float64 transformVector __gc[], String * distanceUnits, String* angleUnits );

		/*
		int GetTransformVector( float64 transformVector __gc[6] )
		get the displacements and rotations of the active Tool Transformation.
		arguments:
			transformVector - out - the displacements and rotations of the Active Tool Transformation.
				transformVector[0] = displacement along x axis
				transformVector[1] = displacement along y axis
				transformVector[2] = displacement along z axis
				transformVector[3] = rotation about x axis (right-hand rotation)
				transformVector[4] = rotation about y axis (right-hand rotation)
				transformVector[5] = rotatation about z axis (right-hand rotation)	
		returns:
			0: successful completion
			1: calibration not initialized (Call LoadCalibrationFile before calling this function)
		*/
		int GetTransformVector( float64 transformVector __gc[] );

		/*
		String * GetTransformDistanceUnits()
		gets the distance units of the transform vector returned by GetTransformVector
		returns:
			the distance units of the tranformation
		*/
		String * GetTransformDistanceUnits();

		/*
		String * GetTransformAngleUnits()
		gets the angle units of the transform vector returned by GetTransformVector
		returns:
			the angle units of the transformation
		*/
		String * GetTransformAngleUnits();

		/*
		String * GetBodyStyle()
		get the body style of the transducer
		returns:
			the transducer's body style,i.e. "Gamma", "Nano17", etc., or "" if no calibration
			has been loaded by calling the function LoadCalibrationFile
		*/
		String * GetBodyStyle();

		/*
		String * GetCalibrationType()
		get the calibration of the transducer
		returns:
			the transducer's calibration, i.e. 'US-600-3600' or 'SI-10-100', or "" if no 
			calibration was loaded using the function LoadCalibrationFile.  The first 
			section is "US" or "SI", indicating whether this calibration uses metric (SI)
			or imperial (US) units.  The first number is the force rating for this calibration,
			which is in Newtons if this is a metric calibration, or pounds if this is an 
			imperial calibration.  The second number is the torque rating for this calibration,
			which is in	Newton-meters if this is a metric calibration, or Pound-feet if 
			this is an imperial	calibration.
		*/
		String * GetCalibrationType();

		/*
		int GetWorkingMatrix( float64 matrix __gc[6,6] )
		get the working calibration matrix for this sensor.
		arguments:
			matrix - out - the 6 x 6 calibration matrix for this sensor.  This matrix is 
			multiplied by the strain gauge vector to calculate the resolved forces and
			torques
		returns:
			0: success
			1: calibration not initialized.  Call LoadCalibrationFile before calling this function
		*/
		int GetWorkingMatrix( float64 matrix __gc[ati_ARRAY_DEC2(6,6)] ); //KAP [,]

		/*
		int ReadSingleFTRecord( double readings __gc[6] )
		scans the hardware, performs any averaging necessary, and computes the 
		force/torque readings
		arguments:
			readings - out - the force/torque readings.
				readings[0] = fx
				readings[1] = fy
				readings[2] = fz
				readings[3] = tx
				readings[4] = ty
				readings[5] = tz
				the readings are in the current force and torque output units.
		returns:
			0 if successful
			1 if calibration not initialized ( call LoadCalibrationFile before calling this function)
			2 if gauges are saturated ( gauge saturation is defined as 99.5% of maximum voltage )
			other: error code resulting from hardware read.
		*/
		int ReadSingleFTRecord( double readings __gc[] );

		/*
		int ReadBufferedFTRecords( int numRecords, double readings __gc[] )
		scans the hardware, performs any averaging necessary, and computes the 
		buffered force/torque readings
		arguments:
			numRecords - the number of records to read
			readings - out - the force/torque readings, if no error occurred.  If an
				error occurred (non-zero return code), the values in readings are undefined.
				readings[0] = fx1
				readings[1] = fy1
				readings[2] = fz1
				readings[3] = tx1
				readings[4] = ty1
				readings[5] = tz1
				readings[6] = fx2
				...
				the readings are in the current force and torque output units.
		returns:
			0 if successful
			1 if calibration not initialized ( call LoadCalibrationFile before calling this function)
			2 if gauges are saturated at any point while reading the buffered data
				( gauge saturation is defined as 99.5% of maximum voltage )
			other: error code resulting from hardware read.
		REMEMBER:
			if an error occurs, such as gauge saturation or a NI-DAQmx error, further processing will stop,
			including force and torque calculations.  Therefore, if the return value is non-zero, you cannot
			trust the values in readings.  This is done intentionally, because if even a single gauge is saturated, 
			you cannot reliably calculate any axis of the force and torque readings.
		*/
		int ReadBufferedFTRecords( int numRecords, double readings __gc[] );

		/*
		int BiasKnownLoad( float64 biasVoltages __gc[6] )
		bias out a known load on the transducer
		arguments:
			biasVoltages - the value of the strain gauge voltages when the load you wish
				to bias out is applied to the transducer.
		returns:
			0: successfully applied
			1: calibration not initialized.  Call LoadCalibrationFile before calling this function.
		*/
		int BiasKnownLoad( float64 biasVoltages __gc[] );

		/*
		int BiasCurrentLoad()
		bias out the current load applied to the transducer.
		returns:
			0 for success
			1: calibration not initialized.  Call LoadCalibrationFile before calling this function
			other: error/warning code from hardware. <0 if error, >0 if warning
		*/
		int BiasCurrentLoad();

		/*
		int GetMaxVoltage()
		get the maximum voltage output by the transducer
		returns: the maximum voltage output by the transducer, defaults to 10 if no calibration has been loaded
		*/
		int GetMaxVoltage()	{ return m_iMaxVoltage; }

		/*
		int GetMinVoltage()
		get the minimum voltage output by the transducer
		returns: the minimum voltage output by the transducer, defaults to -10 if no calibration has been loaded
		*/
		int GetMinVoltage() { return m_iMinVoltage; }

		/*
		int GetBiasVector(double biasVector __gc[6])
		get the active bias vector
		arguments:
			biasVector - out - the active bias vector, or the in-value if no calibration is loaded
		returns:
			0 if successful, 1 if no calibration has been loaded via the LoadCalibrationFile function
		*/
		int GetBiasVector( double biasVector __gc[] );

		/*
		float64 GetThermistorValue()
		Get the thermistor value at calibration.  This value is used to perform software temperature compensation.
		returns:
			The value of the thermistor at calibration, or 0 if no calibration has been loaded using LoadCalibrationFile.
		*/
		float64 GetThermistorValue();

		/*
		float64 GetBiasSlope( int index )
		Get the bias slope values.  The bias slope is used to perform software temperature compensation.
		arguments:
			index - The index of the bias slope you wish to retrieve.  Valid values are 0 to 5.
		returns:
			The bias slope at the specified index, or 0 if no calibration has been loaded using LoadCalibrationFile.
		*/
		float64 GetBiasSlope( int index );

		/*
		float64 GetGainSlope( int index )
		Get the gain slope values.  The gain slope is used to perform software temperature compensation.
		arguments:
			index - The index of the gain slope you wish to retrieve.  Valid values are 0 to 5.
		returns:
			The gain slope at the specified index, or 0 if no calibration has been loaded using LoadCalibrationFile.
		*/
		float64 GetGainSlope( int index );
			

		/*
		void SetConnectionMode( ConnectionType connType );
		set the DAQ connection mode (differential, RSE, etc.)
		arguments:
			connType - the type of connection to use
		*/
		void SetConnectionMode( ConnectionType connType );

		/*
		ConnectionType GetConnectionMode( )
		get the type of DAQ connection
		returns:
			the connection mode (differential, rse, etc.)
		*/
		ConnectionType GetConnectionMode( );

		/*aug.5.2005a - ss*/
		/*
		bool GetHardwareTempComp( )
		get whether or not hardware temperature compensation is included with this transducer
		returns:
			true if hardware temperature compensation is installed, false otherwise
		*/
		bool GetHardwareTempComp( );
		
		
	private:
		ATIDAQHardwareInterface * m_hiHardware; /*the hardware interface for this system*/
		String * m_sErrorInfo; /*error information*/
		Calibration __nogc * m_Calibration; /*the f/t calibration*/
		int m_iMaxVoltage; /*the maximum voltage of the gauges in the transducer*/
		int m_iMinVoltage; /*the minimum voltage of the gauges in the transducer*/
		float64 m_dUpperSaturationVoltage; /*the upper voltage at which the gauges are considered saturated*/
		float64 m_dLowerSaturationVoltage; /*the lower voltage at which the gauges are considered saturated*/
		

		/*
		void ConvertStringToCString( String * sourceString, char destString[], int destSize )
		copies a managed string to an unmanaged string, with bounds-checking
		arguments:
			sourceString - the managed string to copy
			destString - out - null-terminated string copy of sourceString
			destSize - the size of destString, including room for the null character, i.e.
				pass 2048 if destString is declared as a char[2048].
		*/
		void ConvertStringToCString( String * sourceString, char destString __nogc[], int destSize );
		
	};
}

#endif /*#ifndef*/
