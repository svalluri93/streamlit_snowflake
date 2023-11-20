#!/usr/bin/sh

if [ $# -ne 4 ] && [ $# -ne 3 ]
then
	echo "Invalid number of arguments supplied to $(basename $0) : correct syntax is $(basename $0) <username> <timestamp> <folder_name> <object_name> / $(basename $0) <username> <timestamp> <uuid>"
	exit -1
fi

USERNAME=$1
TIMESTAMP=$2
FOLDER_NAME=$3
OBJECT_NAME=$4
SCRIPT_NAME=`echo $(basename $0)`
STAGE=Import
NUMBER=3
UUID=$3
if [ ! -e Config/iics_deployment_profile.txt ]
then
        echo "User profile file .bash_profile does not exist.So exiting..."
        exit -1
else
        . Config/iics_deployment_profile.txt
fi

##############################################
########Take backup before importing##########
##############################################

Log "Calling script iics_code_deployment_backup.sh to take backup of IICS objects to be imported"
if [ -z $FOLDER_NAME ] || [ -z $OBJECT_NAME ]
then
	sh $SCRIPT_DIR/iics_code_deployment_backup_streamlit.sh "$USERNAME" $TIMESTAMP
	BACKUP_RETURN_STATUS=$?
        if [ $BACKUP_RETURN_STATUS -ne 0 ]
        then
                LogQuit $BACKUP_RETURN_STATUS "iics_code_deployment_backup_streamlit.sh failed due to errors. Please check logs"
        fi
	EXPORT_PACKAGE_NAME=`echo "$(basename $EXPORT_DIR/job*$TIMESTAMP*)"|rev|cut -d. -f2-|rev`
	SCRIPT_NAME=`echo $(basename $0)`
	Log $EXPORT_PACKAGE_NAME
else
	sh $SCRIPT_DIR/iics_code_deployment_backup_streamlit.sh "$USERNAME" $TIMESTAMP "$FOLDER_NAME" "$OBJECT_NAME"
        BACKUP_RETURN_STATUS=$?
        if [ $BACKUP_RETURN_STATUS -ne 0 ]
        then
                LogQuit $BACKUP_RETURN_STATUS "iics_code_deployment_backup_streamlit.sh failed due to errors. Please check logs"
        fi

	EXPORT_PACKAGE_NAME=${OBJECT_NAME}_${USERNAME}_$TIMESTAMP
	SCRIPT_NAME=`echo $(basename $0)`
	Log $EXPORT_PACKAGE_NAME
fi
Log "Calling script iics_code_deployment_backup_streamlit.sh to take backup of IICS objects to be imported - Completed"
 
sed -i -e "s/Import: NOT STARTED/Import: STARTED/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
#Using REST API V3
####################################
###############Login################
####################################

DECRYPT_PASSWORD=`cat $TEMP_DIR/Tgt_encrypted_$TIMESTAMP.txt.enc | openssl enc -aes-256-cbc -d -pass pass:$TIMESTAMP`

Login "$USERNAME" "$DECRYPT_PASSWORD"
Log "Session id is $INFA_SESSION_ID"


####################################
#######Submit Import request########
####################################

IMPORT_ID=$(curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: multipart/form-data" --form 'package=@'$EXPORT_DIR/$EXPORT_PACKAGE_NAME.zip "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/package"|grep -o "jobId\":\".*\",\""|cut -d':' -f2|cut -d',' -f1|tr -d '"')

Log "Import Id for the submitted import request is $IMPORT_ID"

####################################
###########Start Import#############
####################################
IMPORT_CONFIG='{   "name" : "Importing object '$OBJECT_NAME' from package '$EXPORT_PACKAGE_NAME'",   "importSpecification" : {       "defaultConflictResolution" : "OVERWRITE",	"includeObjects" : [ '
Delete $TEMP_DIR/Source_Object_Id_$TIMESTAMP.txt
for type in DTEMPLATE MTT DSS MAPPLET WORKFLOW TASKFLOW
do
        grep "$type" "$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt" | grep -io "name\":\".*\" " | cut -d ' ' -f1 | cut -d':' -f2 | tr -d '"' > $TEMP_DIR/Object_name_${type}_$TIMESTAMP.txt;
        while read SRC_OBJ_NM
        do
                SRC_OBJ_ID=`grep "\"$SRC_OBJ_NM\"" "$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt"|grep -o "id\":\".*\""|cut -d':' -f2|tr -d '"'`;
		Log "Source Object type = $type , Source Object name = $SRC_OBJ_NM , Source Object Id = $SRC_OBJ_ID"
                IMPORT_CONFIG=$IMPORT_CONFIG'"'$SRC_OBJ_ID'",'
	done<$TEMP_DIR/Object_name_${type}_$TIMESTAMP.txt
done

IMPORT_CONFIG=$IMPORT_CONFIG'] '
IMPORT_CONFIG=`echo $IMPORT_CONFIG | sed 's/,]/]/g'`
IMPORT_CONFIG=$IMPORT_CONFIG', "objectSpecification" : [ '

Log "IMPORT_CONFIG = $IMPORT_CONFIG"

for line in `cat $TEMP_DIR/Source_to_Target_Object_Id_$TIMESTAMP.txt`
do 
	SRC_OBJ_ID=`echo $line|cut -d, -f1`
	SRC_OBJ_NM=`echo $line|cut -d, -f2`
	TGT_OBJ_NM=`grep -i ",$SRC_OBJ_NM," $CONFIG_DIR/Source_to_Target_config.csv | cut -d, -f3 | tr ' ' '+'`
	TGT_OBJ_TYP=`grep -i ",$SRC_OBJ_NM," $CONFIG_DIR/Source_to_Target_config.csv | cut -d, -f1`
	Log "Target Object name, Target Object type are $TGT_OBJ_NM,$TGT_OBJ_TYP respectively"
	TGT_OBJ_ID=$(curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d '{"objects":[{"path":"'$TGT_OBJ_NM'","type":"'$TGT_OBJ_TYP'"}]}' "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/lookup"|grep -o "id.:..*.,.path"|cut -d':' -f2|cut -d',' -f1| cut -d ' ' -f1 | tr -d '"')

	Log "Target Object name, Target Object type, Target Object Id are $TGT_OBJ_NM,$TGT_OBJ_TYP,$TGT_OBJ_ID respectively"	
	IMPORT_CONFIG=$IMPORT_CONFIG'{"sourceObjectId" : "'$SRC_OBJ_ID'", "targetObjectId" : "'$TGT_OBJ_ID'"},'
done

IMPORT_CONFIG=$IMPORT_CONFIG'] }}'
IMPORT_CONFIG=`echo $IMPORT_CONFIG | sed 's/,]/]/g'`

Log "Import configuration is $IMPORT_CONFIG"

curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d \
"$IMPORT_CONFIG" \
"https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/"$IMPORT_ID>$TEMP_DIR/Import_PostRequestProcessing_$TIMESTAMP.log

STATUS=$(cat $TEMP_DIR/Import_PostRequestProcessing_$TIMESTAMP.log | grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/Import_PostRequestProcessing_Status_$TIMESTAMP.log)

if [ `wc -l $TEMP_DIR/Import_PostRequestProcessing_Status_$TIMESTAMP.log | awk '{print $1}'` -ne 0 ]
then
	STATUS=failed
	LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
	Log "Request submitted to Import Failed before processing. Please check logs"
	cat $TEMP_DIR/Import_PostRequestProcessing_Status_$TIMESTAMP.log>>$LOG_FILE_NAME
	sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	sed -i -e "s/Import: STARTED/Import: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_FILE_NAME $EMAIL_ID
	LogQuit -1 "$STAGE failed. So exiting..."
fi
IMPORT_ID=$(cat $TEMP_DIR/Import_PostRequestProcessing_$TIMESTAMP.log | grep -o "id.:..*.,.createTime"|cut -d':' -f2|cut -d',' -f1|tr -d '"')


####################################
########GET Status of Import########
####################################
curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/"$IMPORT_ID

while [ 1 ]
do
	sleep 5
	STATUS=$(curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/"$IMPORT_ID | grep -o "state\":\".*\",\"message\"" |cut -d':' -f2|cut -d',' -f1|tr -d '"')
	curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/"$IMPORT_ID | grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/ImportStatus_$IMPORT_ID.log

	if [ `wc -l $TEMP_DIR/ImportStatus_$IMPORT_ID.log | awk '{print $1}'` -ne 0 ]
	then
		STATUS=failed
		LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
		Log "Request submitted to Import failed after processing. Please check logs"
		cat $TEMP_DIR/ImportStatus_$IMPORT_ID.log>>$LOG_FILE_NAME
		sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		sed -i -e "s/Import: STARTED/Import: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		#Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : State " $LOG_FILE_NAME $EMAIL_ID
		LogQuit -1 "$STAGE failed. So exiting..."
	fi
	if [ X"$STATUS" == X"IN_PROGRESS" ]
	then
		Log "Import in progress. Check for status after 10 seconds"
		sleep 10;
	else
		Log "Import Completed. Status of the import is $STATUS"
		break;
	fi
done

###################################
########Get the import log#########
###################################
curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/import/$IMPORT_ID/log">$TEMP_DIR/${IMPORT_ID}_${USERNAME}_$TIMESTAMP.log

###################################
###############Logout##############
###################################


curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://dm-ap.informaticacloud.com/saas/public/core/v3/logout"

STATUS=succeeded
LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
sed -i -e "s/started/successful/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
sed -i -e "s/Import: STARTED/Import: Success/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_FILE_NAME $EMAIL_ID

