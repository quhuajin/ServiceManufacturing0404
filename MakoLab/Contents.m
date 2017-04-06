% MakoLab Interface for CRISIS through Matlab
% Version 0.0    06-Aug-2007
%
% Hgs Arm Related
%   hgs_robot             - Constructor for Hgs Robot object
%   hgs_robot/reset       - clear all currently initialized modules, haptic objects and ref frames on the robot   
%   hgs_robot/reconnect   - re-establish connection to the hgs robot
%   hgs_robot/mode        - get/set/control modes of the hgs_robot
%   hgs_robot/get         - overloading method for accessing hgs_robot elements 
%   hgs_robot/set         - overloading method for updateing hgs_robot elements
%   hgs_robot/collect     - Quickly capture specified variables into matlab workspace
%   hgs_robot/status      - Get the status of the hgs_robot.
%   hgs_robot/close       - close the TCP socket based connection 
%   hgs_robot/comm        - Send command to crisis and parse the elements of the reply
%   hgs_robot/commDataPair - Send command to crisis and parse the elements of the reply as a DataPair
%   hgs_robot/crisisComm  - Send command to crisis and receive the binary reply
%   hgs_robot/home        - Query if the hgs_robot is homed
%   hgs_robot/stop        - stop any mode currently executing on the hgs_robot
%   hgs_robot/send_file   - Send a file to store on the robot
%   hgs_robot/get_file    - get_file Get a file contents of a file stored on the robot
%
%   hgs_robot/fieldnames  - overloading method for accessing hgs_robot fields
%   hgs_robot/subsref     - overloading method for accessing hgs_robot elements 
%   hgs_robot/subsasgn    - overloading method for editing hgs_robot configuration variables
%   hgs_robot/display     - Overloaded method to Display the value of a hgs_robot object
%   hgs_robot/plot        - Overloaded method to quickly plot hgs_robot variables
%
% Haptic Object related
%   hgs_haptic/create     - create a Hgs Haptic object
%   hgs_haptic/delete     - delete a Hgs Haptic object
%   hgs_haptic/display    - Overloaded method to Display the value of a hgs robot object
%   hgs_haptic/get        - get parameter list for a Hgs Haptic object
%   hgs_haptic            - Constructor for Hgs Haptic object
%   hgs_haptic/set        - set parameter of a Hgs Haptic object or its prototype
%   hgs_haptic/subsasgn   - overloading method for editing hgs_haptic object name
%   hgs_haptic/subsref    - overloading method for accessing hgs_haptic elements
% 
% NDI Polaris Camera Related
%   ndi_camera/comm       - Send a command to the ndi camera and return the reply
%   ndi_camera/display    - Overloaded method to display parameters of the ndi camera
%   ndi_camera/init       - Initialize the ndi camera system
%   ndi_camera/init_tool  - load the srom tool data to the ndi camera
%   ndi_camera            - Constructor for NDI Camera object connected through the hgs
%   ndi_camera/plot       - Overloaded method to graphically display the ndi camera tools
%   ndi_camera/setmode    - Set the mode of the camera
%   ndi_camera/tx         - Send the tx command to the ndi camera and parse the reply
%   ndi_camera/bx         - Send the bx command to the ndi camera and parse the reply
%
% MakoLab Scripts
%   phase_hgs             - Gui to help perfrom the phasing procedure on the Hgs Robot.
%   home_hgs              - Gui to help perfrom the homing procedure on the Hgs Robot.
%   crisis_logger         - crisis_logger GUI interface to view various crisis variables
%
% Miscellaneous functions
%   read_stl              - Read an stl file to provide the facet and vertices data for patch command.
%   show_stl              - display the model from an stl file
%   transform_vertices    - Multiply a transform to all the vertices
%   setup_network         - changes a computers network settings to either DHCP or static
%
% GUI related functions
%   generateMakoGui       - generateMakoGui Generate the default GUI template for the Mako Service and Manufcaturing
%   presentMakoResults    - presentMakoResults Presents the results in the standard way described for Mako Service and Manufacturing Scripts
%
% Low Level functions
%   closeCrisisConnection - Close a socket based TCP connection to CRISIS
%   matlabtoCrisisComm    - convert Matlab format arguments to Crisis API format
%   openCrisisConnection  - Open a socket based TCP connection to CRISIS
%   parseCrisisReply      - Parse the reply received from CRISIS
%   sendReceiveCrisisComm - Send command to CRISIS and receive the reply
%   convertBytesToFloat   - Converts given 4 bytes to equivalent float number
%   convertStructToString - converts matlab structures into strings that can be used for display
%
% Makolab Demonstrations
%   makolabdemo           - Simple Demo showing the use of the MakoLab package
%

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: MAKO Surgical corp 2007
% 


% --------- END OF FILE ----------