#!/bin/bash
# script for execution of deployed applications
#
# Sets up the MCR environment for the current $ARCH and executes 
# the specified command.
#

export MCRROOT=/opt/MATLAB/MATLAB_Compiler_Runtime/v715
LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
MCRJRE=${MCRROOT}/sys/java/jre/glnxa64/jre/lib/amd64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRJRE}/server;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRJRE};
XAPPLRESDIR=${MCRROOT}/X11/app-defaults;
export LD_LIBRARY_PATH;
export XAPPLRESDIR;

echo $LD_LIBRARY_PATH

