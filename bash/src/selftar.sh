#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     selftar.sh
# Description:  This script is for creating self-executing tar packages
# Shout-out:    https://github.com/alexradzin
# ----------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------
# Script:
# It is a good idea to create script that takes regular tar.gz and creates
# self-extracting archive. The script is available here.
# It accepts the following arguments:
#
#     mandatory path to tar.gz 
#     optional command that is automatically executed right after the archive
#     extracting. Typically it is script packaged into the tar. 
#
# The name of resulting executable is as name of tar.gz with suffix ".run".
#
# Usage Examples: 
#
# Create self-extracted executable: 
#     ./selftar.sh my.tar.gz
#
# Create self-extracted executable with command executed after archive extracting: 
#     ./selftar.sh "my.tar.gz" "\$PREFIX/tmp/install.sh"
#
# Both examples create executable file my.tar.gz.run that extracts files initially
# packaged to my.tar.gz to current directory:
#     ./my.tar.gz.run
#
# Example to run (include brackets):
#     (mkdir -p $PREFIX/tmp/selftar ; cd $PREFIX/tmp/selftar ; $PREFIX/tmp/installer_pkg.tar.gz.run)
# Note: You can rename Selftar output file to whatever your want:
#     installer_pkg.tar.gz.run --> installer.run
# ----------------------------------------------------------------------------------

if [ $# -eq 0 ]
then
  echo "This script creates self extractable executable"
  echo Usage: $0 TAR.GZ [COMMAND]
  exit;
fi
if [ $# -gt 0 ]
then
  TAR_FILE=$1
fi
EXIT_COMMAND=exit
if [ $# -gt 1 ]
then
  EXIT_COMMAND="exec $2"
fi

SELF_EXTRACTABLE="$TAR_FILE.run"

echo '#!/bin/sh' > $SELF_EXTRACTABLE
echo 'dd bs=1 skip=`head -3 $0 | wc -c`  if=$0  | gunzip -c  | tar -x' >> $SELF_EXTRACTABLE
echo "$EXIT_COMMAND" >> $SELF_EXTRACTABLE

cat $TAR_FILE >> $SELF_EXTRACTABLE
chmod a+x $SELF_EXTRACTABLE
#-----------------------------------------------------------------------------------