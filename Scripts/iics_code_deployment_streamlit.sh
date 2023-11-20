#!/usr/bin/sh

if [ ! -e Config/iics_deployment_profile.txt ]
then
        echo "User profile file .bash_profile does not exist.So exiting..."
	exit -1
else
	. Config/iics_deployment_profile.txt
fi

echo "No. of args = $#"
if [ $# -ne 3 -a $# -ne 5 ]
then 
	echo "Invalid number of arguments supplied to script $(basename $0). Correct usage is $(basename $0) <source_username> <source_password> | $(basename $0) <source_username> <source_password> <target_username> <target_password>"
	exit -1
fi

SRC_USERNAME=$1
SRC_PASSWORD=$2

TIMESTAMP=`date '+%Y%m%d%S%N'`
SCRIPT_NAME=`echo $(basename $0)`

echo $SRC_PASSWORD | openssl enc -aes-256-cbc -salt -pass pass:$TIMESTAMP -out $TEMP_DIR/Src_encrypted_$TIMESTAMP.txt.enc
SRC_ENCRYPT_PASSWORD=`cat $TEMP_DIR/Src_encrypted_$TIMESTAMP.txt.enc`

export LOG_USERNAME=$SRC_USERNAME


##$YES_OR_NO variable validation##
#####Allowed values:-Y,y,N,n######
##################################

if [ $# -eq 5 ]
then
	TGT_USERNAME=$3
	TGT_PASSWORD=$4
	UUID=$5	
else
	TGT_USERNAME="$SRC_USERNAME"
	TGT_PASSWORD="$SRC_PASSWORD"
	UUID=$3
fi

echo $TGT_PASSWORD | openssl enc -aes-256-cbc -salt -pass pass:$TIMESTAMP -out $TEMP_DIR/Tgt_encrypted_$TIMESTAMP.txt.enc
TGT_ENCRYPT_PASSWORD=`cat $TEMP_DIR/Tgt_encrypted_$TIMESTAMP.txt.enc`

##########################################
#calling script to export the IICS objects
##########################################
#Before starting anything
echo -e "$EMAIL_BODY">$TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
sed -i -e "s/\$USERNAME/$LOG_USERNAME/g" -e "s/\$STATUS/NOT STARTED/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
sed -i -e "s/\(IICS code migration from\)\(.*\)\(NOT STARTED\)/\1\2started/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
Log "Calling script  iics_code_deployment_export.sh to take export of IICS objects"

sh $SCRIPT_DIR/iics_code_deployment_export_streamlit.sh $SRC_USERNAME $TIMESTAMP $UUID
EXPORT_RETURN_STATUS=$?
if [ $EXPORT_RETURN_STATUS -ne 0 ]
then
	LogQuit $EXPORT_RETURN_STATUS "iics_code_deployment_export_streamlit.sh failed due to errors. Please check logs"
fi

SCRIPT_NAME=`echo $(basename $0)`
Log "Calling script  iics_code_deployment_export_streamlit.sh to take export of IICS objects - Completed"
##########################################
#calling script to import the IICS objects
##########################################

Log "Calling script iics_code_deployment_import_streamlit.sh to take import of IICS objects"

sh $SCRIPT_DIR/iics_code_deployment_import_streamlit.sh $TGT_USERNAME $TIMESTAMP $UUID
IMPORT_RETURN_STATUS=$?
if [ $IMPORT_RETURN_STATUS -ne 0 ]
then
	LogQuit $IMPORT_RETURN_STATUS "iics_code_deployment_import_streamlit.sh failed due to errors. Please check logs"
fi

SCRIPT_NAME=`echo $(basename $0)`
Delete Src_encrypted_$TIMESTAMP.txt.enc
Delete Tgt_encrypted_$TIMESTAMP.txt.enc
Log "Calling script iics_code_deployment_import_streamlit.sh to take import of IICS objects - Completed"
