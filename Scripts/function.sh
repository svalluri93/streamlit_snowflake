LogQuit()
{
	sleep 0.2
	Status=$1;
	message=$2;
	echo "$SCRIPT_NAME | `date` | $message" | tee -a $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_${UUID}.log;
	#echo "-------------------------------------------------------------------------" | tee -a $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_${UUID}.log;
	exit $Status;
}

Log()
{
	sleep 0.2
	message=$1;
    echo "$SCRIPT_NAME | `date` | $message" | tee -a $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_${UUID}.log;
    #echo "-------------------------------------------------------------------------" | tee -a $LOG_DIR/iics_code_deployment_${LOG_USERNAME}_${UUID}.log;
}
Delete()
{	
	FILE_NAME=$1
	if [ -f $FILE_NAME ] && [ -e $FILE_NAME ]
	then
		rm $FILE_NAME
	fi
}
Send_Mail(){

if [ $# -eq 3 ]
then
	export mail_body=$1
	export mail_subject=$2
	export mail_recipient=$3
	echo "sending mail to $mail_recipient"

	cat $mail_body| mailx -v -s "$mail_subject" $mail_recipient
	echo ''
fi
if [ $# -eq 4 ]
then
        export mail_body=$1
        export mail_subject=$2
	export mail_attachment=$3
        export mail_recipient=$4
	echo "sending mail to $mail_recipient"

	cat $mail_body| mailx -v -s "$mail_subject" -a $mail_attachment $mail_recipient
	echo ''
fi
}

Login()
{
	USERNAME=$1
	LOGIN_PWD=$2
	Log "Start Login";
	MESSAGE=$(curl -X POST -H "Accept: application/json" -H "Content-Type: application/json" -d '{"username":"'$USERNAME'","password":"'$LOGIN_PWD'"}' "https://dm-ap.informaticacloud.com/saas/public/core/v3/login"|tr -d '"')
	ERR_MSG=`echo "$MESSAGE" | grep -o "error:{.*}"| cut -d':' -f2- `
	if [ ! -z $ERR_MSG ]
	then
		Log "Error message is $ERR_MSG"
	fi
	if [ -z "$ERR_MSG" ]	
	then
		INFA_SESSION_ID=`echo "$MESSAGE" | grep -o "sessionId:.*,"|cut -d':' -f2|cut -d',' -f1`
		#Log "INFA_SESSION_ID = $INFA_SESSION_ID"
		Log "Login successful"
	else
		TMSTMP=`date '+%Y%m%d%S%N'`
		echo "$ERR_MSG" > $LOG_DIR/Login_Failure_$TMSTMP.log
		sed "s/\$USERNAME/$USERNAME/g" $CONFIG_DIR/Email_Body_Failure_On_Login.txt>$LOG_DIR/Email_Body_Failure_On_Login_$UUID.txt
		Send_Mail1 `sed "s/\$USERNAME/$USERNAME/g" $CONFIG_DIR/Email_Body_Failure_On_Login.txt` "Login failed for user $USERNAME : FAILURE " $LOG_DIR/Login_Failure_$TMSTMP.log $EMAIL_ID
		LogQuit -1 "Login Failed.So exiting..."
	fi
}

