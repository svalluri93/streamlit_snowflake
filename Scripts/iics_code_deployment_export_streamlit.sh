#!/usr/bin/sh

if [ $# -ne 6 -a $# -ne 3 ]
then
        echo "Invalid number of arguments supplied to script $(basename $0). Correct usage is $(basename $0) <username> <timestamp> <folder_name> <object_name> <object_type> <dependency> / $(basename $0) <username> <timestamp>"
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
OBJECT_TYPE=$5
DEPENDENCY=$6
STAGE=Export
SCRIPT_NAME=`echo $(basename $0)`
NUMBER=1

if [ $# -eq 3 ]
then
	UUID=$3
fi
#Using REST API V3
##############
###Login######
##############
#before start of Export
sed -i -e "s/Export: NOT STARTED/Export: STARTED/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt

DECRYPT_PASSWORD=`cat $TEMP_DIR/Src_encrypted_$TIMESTAMP.txt.enc | openssl enc -aes-256-cbc -d -pass pass:$TIMESTAMP`
Login "$USERNAME" "$DECRYPT_PASSWORD"

#Log "Session id is $INFA_SESSION_ID"

######################################################
#Get object Id of the object to be imported###########
######################################################
Delete $TEMP_DIR/Export_Object_Id_$TIMESTAMP.txt
ctr=1
if [ `wc -l $CONFIG_DIR/deployment_template_$UUID.txt | awk '{print $1}'` -eq 1 ]
	then
		Log "No IICS object mentioned in deployment_template.txt. Please mention object to be migrated in deployment template.";
		STATUS=failed
		sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		sed -i -e "s/Export: STARTED/Export: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status" $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log $EMAIL_ID
		LogQuit -1 "$STAGE failed. So exiting..."
	fi
	Log "Reading contents of deployment_template.txt file line by line"

	echo "----------------------------------------------------- $CONFIG_DIR/deployment_template_$UUID.txt"

while read line
do
	if [ $ctr -eq 1 ] || [ -z $line ]
	then
		ctr=`expr $ctr + 1`
		continue;
	fi
	Log "############################################";
        Log "$line";
        Log "############################################";
	OBJ_LOCATION=`echo $line|cut -d, -f1`
	Log "OBJ_LOCATION = $OBJ_LOCATION"
	OBJ_NM=`echo $line|cut -d, -f2`
	OBJ_TYPE=`echo $line|cut -d, -f3`
	DEPENDENCY=`echo $line|cut -d, -f4`
	if [ -z $OBJ_LOCATION ] || [ -z $OBJ_NM ] || [ -z $OBJ_TYPE ] || [ -z $DEPENDENCY ]
	then
		STATUS=failed
		sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		sed -i -e "s/Export: STARTED/Export: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		Log "Any of the parameter(s) object location,object name,object type,dependency is missing in deployment_template.txt. Please mention object to be migrated. at line number $ctr."
               	Send_Mail $TEMP_DIR/Email_Body_${USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status" $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log $EMAIL_ID
                LogQuit -1 "$STAGE failed. So exiting..."
	fi
	OBJ_ID=$(curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d '{"objects":[{"path":"'$OBJ_LOCATION'/'$OBJ_NM'","type":"'$OBJ_TYPE'"}]}' "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/lookup"|grep -o "id.:..*.,.path"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
	Log "Object Location = $OBJ_LOCATION , Object name = $OBJ_NM , Object type = $OBJ_TYPE , Dependency = $DEPENDENCY , ObjectId = $OBJ_ID"
	echo "$OBJ_ID,$DEPENDENCY" >> $TEMP_DIR/Export_Object_Id_$TIMESTAMP.txt
	EXPORT_PACKAGE_NAME=job_${USERNAME}_$TIMESTAMP
done<$CONFIG_DIR/deployment_template_$UUID.txt

Log "Object Id of the object to be exported is `cat $TEMP_DIR/Export_Object_Id_$TIMESTAMP.txt|cut -d, -f1|tr '\n' ','`"


EXPORT_CONFIG='{"name":"'$EXPORT_PACKAGE_NAME'","objects":['

while read line
do
		OBJ_ID=`echo $line|cut -d, -f1`
		DEPENDENCY=`echo $line | cut -d, -f2 | tr 'T' 't' | tr 'F' 'f'`
        EXPORT_CONFIG=$EXPORT_CONFIG'{"id":"'$OBJ_ID'","includeDependencies":'$DEPENDENCY'},'
done<$TEMP_DIR/Export_Object_Id_$TIMESTAMP.txt

EXPORT_CONFIG=$EXPORT_CONFIG'] '
EXPORT_CONFIG=`echo $EXPORT_CONFIG | sed 's/,]/]}/g'`

Log "$EXPORT_CONFIG"
######################################################
#Start export using object Id received above##########
######################################################

#EXPORT_ID=$(curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d '{"name":"'$EXPORT_PACKAGE_NAME'","objects":[{"id":"'$OBJECT_ID'","includeDependencies":'$DEPENDENCY'}]}' "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export"|grep -o "id.:..*.,.createTime"|cut -d':' -f2|cut -d',' -f1|tr -d '"')

curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d "$EXPORT_CONFIG" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export" >$TEMP_DIR/Export_PostRequestProcessing_$TIMESTAMP.log
STATUS=$(cat $TEMP_DIR/Export_PostRequestProcessing_$TIMESTAMP.log | grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/Export_PostRequestProcessing_Status_$TIMESTAMP.log)

if [ `wc -l $TEMP_DIR/Export_PostRequestProcessing_Status_$TIMESTAMP.log | awk '{print $1}'` -ne 0 ]
then
	sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	sed -i -e "s/Export: STARTED/Export: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
	Log "Request submitted to Export failed before processing due to below errors."
        cat $TEMP_DIR/Export_PostRequestProcessing_Status_$TIMESTAMP.log>>$LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log
	Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log $EMAIL_ID
	LogQuit -1 "$STAGE failed. So exiting..."
fi
EXPORT_ID=$(cat $TEMP_DIR/Export_PostRequestProcessing_$TIMESTAMP.log | grep -o "id.:..*.,.createTime"|cut -d':' -f2|cut -d',' -f1|tr -d '"')

Log "Export Id of the export request submitted is $EXPORT_ID"

#####################################################
#Get the status of export############################
#####################################################

STATUS=$(curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "state.:..*.,.message"|cut -d':' -f2|cut -d',' -f1|tr -d '"')

Log "Status of export request submitted is $STATUS"
while [ 1==1 ]
do
	STATUS=$(curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "state.:..*.,.message"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
	Log "Status of export request submitted is $STATUS"
	curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID|grep -o "error\":{\".*}"| cut -d':' -f2- >$TEMP_DIR/ExportStatus_$EXPORT_ID.log

	if [ `wc -l $TEMP_DIR/ExportStatus_$EXPORT_ID.log | awk '{print $1}'` -ne 0 ]
	then
		sed -i -e "s/started/failed/1" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		sed -i -e "s/Export: STARTED/Export: Fail/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt
		Log "Request submitted to Export failed after processing due to below errors."
		cat $TEMP_DIR/ExportStatus_$EXPORT_ID.log>>$LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log
		Send_Mail $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt "Deployment triggered by $LOG_USERNAME : Status " $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_$TIMESTAMP.log $EMAIL_ID
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

curl -X GET -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID?expand=objects | sed -e 's/{/\n{\n/g' -e 's/},/\n},\n/g' | awk -F',' '{print $4,$2,$3,$1}' >$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt

#####################################################
#Get the export package##############################
#####################################################

Log "Downloading exported package(zip format)"

curl -X GET -H "Accept: application/zip" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/export/"$EXPORT_ID"/package" >$EXPORT_DIR/$EXPORT_PACKAGE_NAME.zip 

Log "Download successful. Package name is $EXPORT_DIR/$EXPORT_PACKAGE_NAME.zip"


#####################################################
#########Store Object info to be imported############
#####################################################

Delete $TEMP_DIR/Source_to_Target_Object_Id_$TIMESTAMP.txt
Log "Storing Object info to be imported Started"
for type in Project Connection AgentGroup
do
        grep "$type" "$EXPORT_DIR/ContentsOfExportPackage_$EXPORT_PACKAGE_NAME.txt"|grep -o "name\":\".*\" " | cut -d ' ' -f1 | cut -d':' -f2 | tr -d '"' > $TEMP_DIR/Object_name_${type}_$TIMESTAMP.txt;
        while read SRC_OBJ_NM
        do
		Log "SRC_OBJ_NM = $SRC_OBJ_NM"
                SRC_OBJ_ID=$(curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" -d '{"objects":[{"path":"'$SRC_OBJ_NM'","type":"'$type'"}]}' "https://apse1.dm-ap.informaticacloud.com/saas/public/core/v3/lookup"|grep -o "id.:..*.,.path"|cut -d':' -f2|cut -d',' -f1|tr -d '"')
				Log "Source Object type = $type , Source Object Name = $SRC_OBJ_NM , Source Object Id = $SRC_OBJ_ID"
				echo "$SRC_OBJ_ID,$SRC_OBJ_NM" >> $TEMP_DIR/Source_to_Target_Object_Id_$TIMESTAMP.txt
        done<$TEMP_DIR/Object_name_${type}_$TIMESTAMP.txt
done
Log "Storing Object info to be imported Completed"

###################################
###############Logout##############
###################################

curl -X POST -H "Accept: application/json" -H "INFA-SESSION-ID: $INFA_SESSION_ID" -H "Content-Type: application/json" "https://dm-ap.informaticacloud.com/saas/public/core/v3/logout"

STATUS=succeeded
sed -i -e "s/Export: STARTED/Export: Success/g" $TEMP_DIR/Email_Body_${LOG_USERNAME}_$TIMESTAMP.txt

