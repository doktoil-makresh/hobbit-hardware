#!/bin/sh

# ALL THIS SCRIPT IS UNDER GPL LICENSE
# Version 0.2.1
# Title:     hobbit-hardware
# Author:    Damien Martins  ( doctor |at| makelofine |dot| org)
# Date:      2010-01-22
# Purpose:   Check Uni* hardware sensors
# Platforms: Uni* having lm-sensor and hddtemp utilities
# Tested:    Xymon 4.2.2 / hddtemp version 0.3-beta15 (Debian Lenny and Etch packages) / sensors version 3.0.2 with libsensors version 3.0.2 (Debian Lenny package) / sensors version 3.0.1 with libsensors version 3.0.1 (Debian Etch package)
 
#TODO for v0.3
#       -To be independent of /etc/sensors.conf -> we get raw values, and we set right ones from those, and define thresolds in hobbit-hardware.conf file
#	-Support for multiples sensors
#	-Support for independant temperatures thresolds for each disk
#	-Support for multiples disk controllers chipset
#
# History :
# 22 jan 2010 - Damien Martins
#	v0.2.1 - Minor bug fix
# 14 nov 2009 - Damien Martins
#	v0.2 : -Getting sensor probe no more hard coded
#	-More verbosity when commands fail
#	-Disk temperature thresolds in hobbit-hardware.conf file.
#	-Support smartctl to replace hddtemp (if needed)
#	-Possibility to disable lm-sensors
#	-Possibility to choose smartctl chipset
# 25 jun 2009 - Damien Martins
#       v0.1.2 : -New error messages (more verbose, more accurate)
# 18 jun 2009 - Damien Martins
#       v0.1.1 : -Bug fixes
# 15 jan 2009 - Damien Martins
#        v0.1 : First lines, trying to get :
#       -temperatures value, and defined thresolds
#       -fan rotation speed and thresold
#       -voltages and thresolds
#       -HDD temperature (thresold is not include, so we set it in this file)
 
#################################################################################
# YOU MUST CONFIGURE LM-SENSORS IN ORDER TO GET VALUES BEFORE USING THIS SCRIPT #
#################################################################################
 
#This script should be stored in ext directory, located in Xymon/Xymon client home (typically ~xymon/client/ext or ~hobbit/client/ext).
#You must configure the hobbit-hardware.conf file (or whatever name defined in CONFIG_FILE

#Change to fit your system/wills :
TEST="hardware"
MSG_FILE=""${BBTMP}"/hobbit-hardware.msg"
CONFIG_FILE=""${HOBBITCLIENTHOME}"/etc/hobbit-hardware.conf"
TMP_FILE=""${BBTMP}"/hobbit-hardware.tmp"
CMD_HDDTEMP="sudo /usr/sbin/hddtemp"
SENSORS="/usr/bin/sensors"
BC="/usr/bin/bc"
SUDO="/usr/bin/sudo"
SMARTCTL="/usr/sbin/smartctl"

#Debug
if [ "$1" == "debug" ] ; then
	echo "Debug ON"
        BB=echo
        HOBBITCLIENTHOME="/usr/local/xymon/client/"
        BBTMP="$PWD"
        BBDISP=your_hobbit_server
        MACHINE=$(hostname)
        CAT="/bin/cat"
        AWK="/usr/bin/nawk"
        GREP="/bin/grep"
	RM="/bin/rm"
	CUT="/usr/bin/cut"
	DATE="/bin/date"
	SED="/bin/sed"
	CONFIG_FILE="hobbit-hardware.conf"
	TMP_FILE="hobbit-hardware.tmp"
	MSG_FILE="hobbit-hardware.msg"
fi

#Don't change anything from here (or assume all responsibility)
YELLOW=""
RED=""

#Basic tests :
if [ -z "$HOBBITCLIENTHOME" ] ; then
        echo "HOBBITCLIENTHOME not defined !"
        exit 1
fi
if [ -z "$BBTMP" ] ; then
        echo "BBTMP not defined !"
        exit 1
fi
if [ -z "$BB" ] ; then
        echo "BB not defined !"
        exit 1
fi
if [ -z "$BBDISP" ] ; then
        echo "BBDISP not defined !"
        exit 1
fi
if [ -z "$MACHINE" ] ; then
        echo "MACHINE not defined !"
        exit 1
fi

#Let's start baby !!!
#
#Hard disk temperature monitoring

if [ -f "$MSG_FILE" ] ; then
	"$RM" "$MSG_FILE"
fi

DISK_WARNING_TEMP=$($GREP ^DISK_WARNING_TEMP= $CONFIG_FILE | $SED s/^DISK_WARNING_TEMP=//)
DISK_PANIC_TEMP=$($GREP ^DISK_PANIC_TEMP= $CONFIG_FILE | $SED s/^DISK_PANIC_TEMP=//)

function use_hddtemp ()
{
for DISK in $("$GREP" "^DISK=" "$CONFIG_FILE" | "$SED" s/^DISK=//) ; do
	HDD_TEMP="$($CMD_HDDTEMP $DISK | $SED s/..$// | $AWK '{print $4}')"
	if [ ! "$(echo $HDD_TEMP | grep "^[ [:digit:] ]*$")" ] ; then
		RED=1
		LINE="&red Disk $DISK temperature is UNKNOWN (HDD_TEMP VALUE IS : $HDD_TEMP).
It seems S.M.A.R.T. is no more responding !!!"
	echo "La température de $DISK n'est pas un nombre :/
HDD_TEMP : $HDD_TEMP"
	elif [ "$HDD_TEMP" -ge "$DISK_PANIC_TEMP" ] ; then
		RED="1"
		LINE="&red Disk temperature is CRITICAL (Panic is $DISK_PANIC_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
	elif [ "$HDD_TEMP" -ge "$DISK_WARNING_TEMP" ] ; then
		YELLOW="1"
		LINE="&yellow Disk temperature is HIGH (Warning is $DISK_WARNING_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
	elif [ "$HDD_TEMP" -lt "$DISK_WARNING_TEMP" ] ; then
		LINE="&green Disk temperature is OK (Warning is $DISK_WARNING_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
	fi
	echo "$LINE" >> "$MSG_FILE"
done
}

function use_smartctl ()
{
SMARTCTL_CHIPSET="$($GREP ^SMARTCTL_CHIPSET= $CONFIG_FILE | $SED s/^SMARTCTL_CHIPSET=//)"
if [ $SMARTCTL_CHIPSET ] ; then
	SMARTCTL_ARGS="-A -d $SMARTCTL_CHIPSET"
else
	SMARTCTL_ARGS="-A"
fi
for DISK in $("$GREP" "^DISK=" "$CONFIG_FILE" | "$SED" s/^DISK=//) ; do
	HDD_TEMP="$($SUDO $SMARTCTL $SMARTCTL_ARGS $DISK | $GREP "^194" | $AWK '{print $10}')"
        if [ ! "$(echo $HDD_TEMP | grep "^[ [:digit:] ]*$")" ] ; then
                RED=1
                LINE="&red Disk $DISK temperature is UNKNOWN (HDD_TEMP VALUE IS : $HDD_TEMP).
It seems S.M.A.R.T. is no more responding !!!"
        echo "La température de $DISK n'est pas un nombre :/
HDD_TEMP : $HDD_TEMP"
        elif [ "$HDD_TEMP" -ge "$DISK_PANIC_TEMP" ] ; then
                RED="1"
                LINE="&red Disk temperature is CRITICAL (Panic is $DISK_PANIC_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
        elif [ "$HDD_TEMP" -ge "$DISK_WARNING_TEMP" ] ; then
                YELLOW="1"
                LINE="&yellow Disk temperature is HIGH (Warning is $DISK_WARNING_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
        elif [ "$HDD_TEMP" -lt "$DISK_WARNING_TEMP" ] ; then
                LINE="&green Disk temperature is OK (Warning is $DISK_WARNING_TEMP) :
"$DISK"_temperature: "$HDD_TEMP""
        fi
        echo "$LINE" >> "$MSG_FILE"
done
}

#Motherboard sensors monitoring (CPU, Mobo, Fans...)

function test_temperature ()
{
SOURCE=$1
TEMPERATURE=$2
WARNING=$3
PANIC=$4
#echo "Source : $SOURCE
#Temperature : $TEMPERATURE
#Warning : $WARNING
#Panic : $PANIC"
if [ $(echo "$TEMPERATURE >= $PANIC" | "$BC") -eq 1  ] ; then
	RED=1
	LINE="&red $SOURCE temperature is CRITICAL !!! (Panic is $PANIC) :
"$SOURCE"_temperature: $TEMPERATURE"
elif [ $(echo "$TEMPERATURE >= $WARNING" | "$BC") -eq 1 ] ; then
	YELLOW=1
	LINE="&yellow $SOURCE temperature is HIGH ! (Warning is $WARNING) :
"$SOURCE"_temperature: $TEMPERATURE"
elif [ $(echo "$TEMPERATURE < $WARNING" | "$BC") -eq 1 ] ; then
	LINE="&green $SOURCE temperature is OK (Warning is $WARNING) :
"$SOURCE"_temperature: $TEMPERATURE"
fi
echo "$LINE" >> "$MSG_FILE"
unset MIN MAX PANIC VALUE WARNING
}
function test_fan ()
{
SOURCE=$1
RPM=$2
MIN=$3
#echo "Source : $SOURCE
#RPM : $RPM
#MIN : $MIN"
if [ $(echo "$RPM <= $MIN" |"$BC") -eq 1 ] ; then
	RED=1
	LINE="&red $SOURCE RPM speed is critical !!! (Lower or equal to $MIN) :
"$SOURCE"_rpm: $RPM"
elif [ $(echo "$RPM > $MIN" |"$BC") -eq 1 ] ; then
	LINE="&green $SOURCE RPM is OK (Higher than $MIN) :
"$SOURCE"_rpm: $RPM"
fi
echo "$LINE" >> "$MSG_FILE"
unset MIN MAX PANIC VALUE WARNING
}
function test_volt ()
{
SOURCE=$1
VOLT=$2
MIN=$3
MAX=$4
#echo "Source : $SOURCE
#Volt : $VOLT
#Min : $MIN
#Max : $MAX"
if [ $(echo "$VOLT < $MIN" | "$BC") -eq 1 ] || [ $(echo "$VOLT > $MAX" | "$BC") -eq 1 ] ; then
	RED="1"
	LINE="&red $SOURCE voltage is OUT OF RANGE !!! (between $MIN and $MAX) :
"$SOURCE"_volt: $VOLT"
elif [ $(echo "$VOLT == $MIN" |"$BC") -eq 1 ] || [ $(echo "$VOLT == $MAX" |"$BC") -eq 1 ] ; then
	YELLOW="1"
	LINE="&yellow $SOURCE voltage is very NEAR OF LIMITS ! (between $MIN and $MAX) :
"$SOURCE"_volt: $VOLT"
elif [ $(echo "$VOLT > $MIN" |"$BC") -eq 1 ] && [ $(echo "$VOLT < $MAX" |"$BC") -eq 1 ] ; then
	LINE="&green $SOURCE voltage is OK (between $MIN and $MAX) :
"$SOURCE"_volt: $VOLT"
fi
echo "$LINE" >> "$MSG_FILE"
unset MIN MAX PANIC VALUE WARNING
}
function find_type ()
{
LINE=$1
echo "$LINE" | "$GREP" "in[0-9]" 1>/dev/null
        if [ $? -eq 0 ] ; then
                TYPE=volt
        else
                echo "$LINE" | "$GREP" "fan[0-9]" 1>/dev/null
                if [ $? -eq 0 ] ; then
                        TYPE=fan
                        else
                                echo "$LINE" |"$GREP" "temp[0-9]" 1>/dev/null
                                if [ $? -eq 0 ] ; then
                                        TYPE=temp
                                fi
                fi
        fi
#	echo "Type : $TYPE"
}

function use_lmsensors ()
{
SENSOR_PROBE="$($GREP ^SENSOR_PROBE= $CONFIG_FILE | $SED s/^SENSOR_PROBE=//)"
if [ -z $SENSOR_PROBE ] ; then
	echo "No sensor probe configured"
	break
fi

"$SENSORS" -uA "$SENSOR_PROBE" | "$GREP" : | "$GREP" -v beep_enable | $GREP -v "alarm" | $GREP -v "type" > "$TMP_FILE"
while read SENSORS_LINE ; do
#echo 	"Ligne : $SENSORS_LINE"
	echo $SENSORS_LINE | "$AWK" -F: '{print $2}' | "$GREP" "[0-9]" 1>/dev/null

	if [ $? -ne 0 ] ; then
		TITLE=$(echo $SENSORS_LINE | "$AWK" -F: '{print $1}' | $SED 's/\ /_/g' |$SED 's/^-/Negative_/' |$SED 's/^+/Positive_/')
#		echo "Title : $TITLE"
	else
		find_type "$SENSORS_LINE"
		echo $SENSORS_LINE | "$GREP" "input:" 1>/dev/null 
			if [ $? -eq 0 ] ; then
				VALUE=$(echo $SENSORS_LINE | "$AWK" '{print $2}')
#				echo "Value : $VALUE"
			fi
		echo $SENSORS_LINE |"$GREP" "_max:" 1>/dev/null
			if [ $? -eq 0 ] ; then
				PANIC=$(echo $SENSORS_LINE | "$AWK" '{print $2}')
				MAX=$PANIC
#				echo  "Panic : $PANIC"
			fi
		echo $SENSORS_LINE |"$GREP" "_max_hyst:" 1>/dev/null
			if [ $? -eq 0 ] ; then
				WARNING=$(echo $SENSORS_LINE | "$AWK" '{print $2}')
#				echo "Warning : $WARNING"
			fi
		echo $SENSORS_LINE |"$GREP" "_min:" 1>/dev/null
			if [ $? -eq 0 ] ; then
                        	MIN=$(echo $SENSORS_LINE | "$AWK" '{print $2}')
#				echo "Min : $MIN"
	                fi
			if [ "$TYPE" == "volt" ] && [ "$MIN" ] && [ $VALUE ] && [ $MAX ] ; then
				test_volt $TITLE $VALUE $MIN $MAX
			elif [ "$TYPE" == "fan" ] && [ $TITLE ] && [ $MIN ] && [ $VALUE ] ; then
				test_fan $TITLE $VALUE $MIN
			elif [ "$TYPE" == "temp" ] && [ $TITLE ] && [ $VALUE ] && [ $WARNING ] && [ $PANIC ] ; then
				test_temperature $TITLE $VALUE $WARNING $PANIC
			fi
	fi

done < "$TMP_FILE"
}

$GREP -q ^SMARTCTL=1 $CONFIG_FILE
if [ $? -eq 0 ] ; then
	use_smartctl
else
	use_hddtemp
fi

$GREP -q ^SENSOR=1 $CONFIG_FILE
if [ $? -eq 0 ] ; then
	use_lmsensors
fi
if [ "$RED" ] ; then
	FINAL_STATUS=red
elif [ "$YELLOW" ] ; then
	FINAL_STATUS=yellow
else
	FINAL_STATUS=green
fi
"$BB" "$BBDISP" "status "$MACHINE"."$TEST" "$FINAL_STATUS" $("$DATE")

$("$CAT" "$MSG_FILE")
"
