#!/usr/bin/sh

if [ $# -ne 4 ] && [ $# -ne 2 ]
then
        echo "Invalid number of arguments supplied to script $(basename $0). Correct usage is $(basename $0) <username> <timestamp> <folder_name> <object_name> / $(basename $0) <username> <timestamp>"
        exit -1
fi

if [ ! -e Config/iics_deployment_profile.txt ]
then
        echo "User profile file .bash_profile does not exist.So exiting..."
        exit -1
else
		. Config/iics_deployment_profile.txt
fi

USERNAME=$1
TIMESTAMP=$2
FOLDER_NAME=$3
OBJECT_NAME=$4
STAGE=Backup
NUMBER=2
SCRIPT_NAME=`echo $(basename $0)`
#Using REST API V3
##############
###Login######
##############

DECRYPT_PASSWORD=`cat $TEMP_DIR/Tgt_encrypted_$TIMESTAMP.txt.enc | openssl enc -aes-256-cbc -d -pass pass:$TIMESTAMP`
#echo $DECRYPT_PASSWORD
Login "$USERNAME" "$DECRYPT_PASSWORD"
Log "Session id is $INFA_SESSION_ID"

sed -i -e "s/Backup: NOT STARTED/Backup: STARTED/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt

######################################################
#Get object Id of the object to be imported###########
######################################################

if [ -z $FOLDER_NAME ] || [ -z $OBJECT_NAME ]
then
	EXPORT_PACKAGE_NAME=`echo "$(basename $EXPORT_DIR/job*$TIMESTAMP*)"|rev|cut -d. -f2-|rev`
else
	EXPORT_PACKAGE_NAME=${OBJECT_NAME}_${USERNAME}_$TIMESTAMP
fi

Delete $TEMP_DIR/Backup_Target_Object_Id_$TIMESTAMP.txt
touch $TEMP_DIR/Backup_Target_Object_Id_$TIMESTAMP.txt
for type in DTEMPLATE MTT DSS MAPPLET WORKFLOW TASKFLOW
do
	Delete $TEMP_DIR/Backup_Object_name_path_${type}_$TIMESTAMP.txt
       for OBJ_NM in $(grep -i "\"$type\"" "$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt"|grep -io "name\":\".*\" "|cut -d':' -f2|cut -d ' ' -f1|tr -d '"'|tr '\n' ' ')
	do
		OBJ_PATH_TMP=$(grep -i "\"$OBJ_NM\"" "$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt"|grep -io "path\":\".*\" "|cut -d':' -f2|tr -d '"')
		OBJ_PATH=`echo $OBJ_PATH_TMP | cut -d/ -f2-`
		Log "Object type = $type , Object name = $OBJ_NM, Object path = $OBJ_PATH"
		echo "$OBJ_NM,$OBJ_PATH">$TEMP_DIR/Backup_Object_name_path_${type}_$TIMESTAMP.txt
		cat $TEMP_DIR/Backup_Object_name_path_${type}_$TIMESTAMP.txt;
	        while read line
        	do
			OBJ_PATH=`echo $line | cut -d, -f2`
			SRC_PROJECT_NAME=`echo $OBJ_PATH | cut -d/ -f1`
			SRC_FOLDER_NAME=`echo $OBJ_PATH | cut -d/ -f2`
			TGT_PROJECT_NAME=`grep -i Project $CONFIG_DIR/Source_to_Target_config.csv | grep -i ",$SRC_PROJECT_NAME," $CONFIG_DIR/Source_to_Target_config.csv | cut -d, -f3`
			TGT_FOLDER_NAME=$SRC_FOLDER_NAME
			TGT_OBJ_NM=`echo $line | cut -d, -f1`
			curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d '{"objects":[{"path":"'$TGT_PROJECT_NAME'/'$TGT_FOLDER_NAME'/'$TGT_OBJ_NM'","type":"'$type'"}]}' "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/lookup" >$TEMP_DIR/Backup_Target_Object_name_details_$TIMESTAMP.txt
			TGT_OBJ_ID=$(cat $TEMP_DIR/Backup_Target_Object_name_details_$TIMESTAMP.txt | grep -io "id.:..*.,.path"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
			TGT_OBJ_PATH=$(cat $TEMP_DIR/Backup_Target_Object_name_details_$TIMESTAMP.txt | grep -io "\"path\":\"$TGT_PROJECT_NAME/$TGT_FOLDER_NAME/$TGT_OBJ_NM\",\"type"|cut -d: -f2|cut -d, -f1|tr -d '"')
			if [ ! -z $TGT_OBJ_ID ] && [ ! -z $TGT_OBJ_PATH ]
			then
	        	        Log "Target object name,project,folder,Object Id are $TGT_OBJ_NM,$TGT_FOLDER_NAME,$TGT_PROJECT_NAME,$TGT_OBJ_ID respectively"
        	        	echo "$TGT_OBJ_ID" >> $TEMP_DIR/Backup_Target_Object_Id_$TIMESTAMP.txt
			fi
	        done<$TEMP_DIR/Backup_Object_name_path_${type}_$TIMESTAMP.txt
	done
done

EXPORT_PACKAGE_NAME=BACKUP_${EXPORT_PACKAGE_NAME}

######################################################
#Start export using object Id received above##########
######################################################

EXPORT_CONFIG='{"name":"'$EXPORT_PACKAGE_NAME'","objects":['

if [ `wc -l $TEMP_DIR/Backup_Target_Object_Id_$TIMESTAMP.txt | awk '{ print $1}'` -eq 0 ]
then
	LogQuit 0 "No need to take backup as all objects are new ";
fi

while read TGT_OBJ_ID
do
	EXPORT_CONFIG=$EXPORT_CONFIG'{"id":"'$TGT_OBJ_ID'","includeDependencies":true},'
done<$TEMP_DIR/Backup_Target_Object_Id_$TIMESTAMP.txt

EXPORT_CONFIG=$EXPORT_CONFIG'] '
EXPORT_CONFIG=`echo $EXPORT_CONFIG | sed 's/,]/]}/g'`

Log "EXPORT_CONFIG = $EXPORT_CONFIG"
curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d "$EXPORT_CONFIG"  "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export" >$TEMP_DIR/Backup_PostRequestProcessing_$TIMESTAMP.log
STATUS=$(cat $TEMP_DIR/Backup_PostRequestProcessing_$TIMESTAMP.log | grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/Backup_PostRequestProcessing_Status_$TIMESTAMP.log)

if [ `wc -l $TEMP_DIR/Backup_PostRequestProcessing_Status_$TIMESTAMP.log | awk '{print $1}'` -ne 0 ]
then
	STATUS=failed
	LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
	sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	sed -i -e "s/Backup: STARTED/Backup: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	Log "Request submitted to take backup failed before processing. Please check logs"
	cat $TEMP_DIR/Backup_PostRequestProcessing_Status_$TIMESTAMP.log>>$LOG_FILE_NAME
	Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_FILE_NAME $EMAIL_ID
	LogQuit -1 "$STAGE failed. So exiting..."
fi
EXPORT_ID=$(cat $TEMP_DIR/Backup_PostRequestProcessing_$TIMESTAMP.log | grep -o "id.:..*.,.createTime"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
Log "Export Id to take backup submitted is $EXPORT_ID"

#####################################################
##########Get the status of backup###################
#####################################################

STATUS=$(curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "state.:..*.,.message"|cut -d':' -f2|cut -d',' -f1|tr -d '"')

Log "Status of backup request submitted is $STATUS"
while [ 1==1 ]
do
	STATUS=$(curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "state.:..*.,.message"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
	Log "Status of backup request submitted is $STATUS"
	curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/BackupStatus_$EXPORT_ID.log

	if [ `wc -l $TEMP_DIR/BackupStatus_$EXPORT_ID.log | awk '{print $1}'` -ne 0 ]
	then
		STATUS=failed
		LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
		sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		sed -i -e "s/Backup.*STARTED/Backup: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		Log "Request submitted to take backup failed after processing. Please check logs"
		cat $TEMP_DIR/BackupStatus_$EXPORT_ID.log>>$LOG_FILE_NAME
		Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_FILE_NAME $EMAIL_ID
		LogQuit -1 "$STAGE failed. So exiting..."
	fi
	if [ $STATUS != "SUCCESSFUL" ]
	then
		sleep 15;
		continue;
	else
		break;
	fi
done

curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID?expand=objects | sed -e 's/{/\n{\n/g' -e 's/},/\n},\n/g' | awk -F',' '{print $4,$2,$1}' >$BACKUP_DIR/ContentsOfBackupPackage_$EXPORT_PACKAGE_NAME.txt

#####################################################
###############Get the backup########################
#####################################################

Log "Downloading backup(zip format)"

curl -X GET -H "Accept: application/zip" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID"/package" >$BACKUP_DIR/$EXPORT_PACKAGE_NAME.zip 

Log "Download successful. Package name is $BACKUP_DIR/$EXPORT_PACKAGE_NAME.zip"

###################################
###############Logout##############
###################################

curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://dm-ap.informaticacloud.com/saas/public/core/v3/logout"

STATUS=succeeded
LOG_FILE_NAME=`find $LOG_DIR -maxdepth 1 -name iics_code_deployment_*_$TIMESTAMP.log|head -1`
sed -i -e "s/Backup.*STARTED/Backup: Success/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
