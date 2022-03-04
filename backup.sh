#!/bin/bash
BWBIN=/volume1/scripts/vaultwarden-export/bw
BACKUP_LOCATION=/volume1/backup/vaultwarden/export
CONFIG_LOCATION=/volume1/scripts/vaultwarden-export/config
LOG_LOCATION=/volume1/scripts/vaultwarden-export/logs
SERVER_LOCATION=https://bitwarden.com
BREAK="=========================================="
DATE=$(date +%Y%m%d)
DATETIME=$(date +'%Y%m%d %H:%M')
ACTION=$1
USER=$2
ENCPASS=$3
RETENTION=7
DRYRUN=false

BW_BACKUP_FILE=$BACKUP_LOCATION/backup-$USER-$DATE.bck.gpg
BW_BACKUP_ORG_FILE=$BACKUP_LOCATION/backup-org-$USER-$DATE.bck.gpg
LOG_FILE=$LOG_LOCATION/log-$USER-$DATE.txt

function login() {
    $BWBIN config server $SERVER_LOCATION --raw
    source <(gpg -qd --batch --passphrase "$ENCPASS" $CONFIG_LOCATION/$USER.dat.gpg)
	export BW_CLIENTID=$BW_CLIENTID
	export BW_CLIENTSECRET=$BW_CLIENTSECRET
    $BWBIN login --apikey --raw
}

function backup() {
    BW_SESSION=$($BWBIN unlock --raw $BW_PASSWORD)
	export BW_SESSION=$BW_SESSION
	echo Exporting Data to $BW_BACKUP_FILE
	echo
    $BWBIN export $BW_PASSWORD --format json --raw | gpg -c --cipher-algo AES256 --passphrase "$BW_PASSWORD" --batch -o $BW_BACKUP_FILE
	if [[ "$USER" == "martijn" ]]
	then
		echo Exporting Organisation Data to $BW_BACKUP_ORG_FILE
		echo
		ORGID=$($BWBIN list organizations | jq -r .[].id)
		$BWBIN export $BW_PASSWORD --organizationid $ORGID --format json --raw | gpg -c --cipher-algo AES256 --passphrase "$BW_PASSWORD" --batch -o $BW_BACKUP_ORG_FILE
	fi
}

function decrypt() {
	validate_config
    gpg -d --batch --passphrase "$ENCPASS" $CONFIG_LOCATION/$USER.dat.gpg
}

function logout() {
    $BWBIN logout --raw
}

function exportvault() {
	writeheader
	validate_export
	login
	backup
	logout
	cleanup
	writefooter
}

function genconfig() {
	if [ ! -f $CONFIG_LOCATION/$USER.dat.gpg ]
	then
		ENCPASS=$($BWBIN generate -uln --length 64)
		CONFIG_FILE=$CONFIG_LOCATION/$USER.dat.gpg
		read -sp "Bitwarden client id: " BW_CLIENTID
		echo
		read -sp "Bitwarden client secret: " BW_CLIENTSECRET
		echo
		read -sp "Bitwarden password: " BW_PASSWORD
		echo
		echo Writing config file
		writeconfig
		echo Config file: $CONFIG_FILE
		echo Passphrase: $ENCPASS
	else
		echo Config file allready exists, remove first
	fi
}

function writeconfig() {
gpg -c --cipher-algo AES256 --batch --passphrase "$ENCPASS" -o $CONFIG_FILE << EOF
#!/usr/bin/env bash
BW_CLIENTID="$BW_CLIENTID"
BW_CLIENTSECRET="$BW_CLIENTSECRET"
BW_PASSWORD="$BW_PASSWORD"
EOF
}

function cleanup() {
	FILDEL=$(find $BACKUP_LOCATION/backup-* -mtime +$RETENTION -type f| wc -l)
	if (( $FILDEL > 0 ))
	then
		echo Remove backups and logs older as $RETENTION days.
		if [[ "$DRYRUN" == "true" ]]
		then 
			echo Backups which would be removed:
			find $BACKUP_LOCATION/backup-$USER-* -mtime +$RETENTION -type f
			if [[ "$USER" == "martijn" ]]
			then
				echo
				echo Backups from organisations which would be removed:
				find $BACKUP_LOCATION/backup-org-$USER-* -mtime +$RETENTION -type f
			fi
			echo
			echo Logs which would be removed:
			find $LOG_LOCATION/log-$USER-* -mtime +$RETENTION -type f
		else 
			echo "Deleted backups:"
			find $BACKUP_LOCATION/backup-$USER-* -mtime +$RETENTION -type f -delete -print
			if [[ "$USER" == "martijn" ]]
			then
				echo
				echo Backups from organisations deleted:
				find $BACKUP_LOCATION/backup-org-$USER-* -mtime +$RETENTION -type f -delete -print
			fi
			echo
			echo "Deleted logs:"
			find $LOG_LOCATION/log-$USER-* -mtime +$RETENTION -type f -delete -print
		fi
	else
		echo No backups older as $RETENTION days.
	fi
}

function validate_config() {
	if [ ! -f "$CONFIG_LOCATION/$USER.dat.gpg" ]
	then
        	echo "No configuration found"
			writefooter
	        exit 1
	fi
}

function validate_export() {
	validate_config
	if [ -f "$BW_BACKUP_FILE" ]
	then
		echo "Backup allready exists"
		writefooter
		exit 1
	fi
}

function writeheader() {
	echo $BREAK
	echo "= Backup started on $DATETIME       ="
	echo $BREAK
	echo
}

function writefooter() {
	echo
	echo $BREAK
}

#validate input
#if [ $# -eq 2 ]
#then
#        BW_PASSWORD=$2
#else
#        read -sp "Bitwarden wachtwoord: " BW_PASSWORD
#fi
case $ACTION in
	export)
		#exportvault 2>&1 >> $LOG_FILE
		exportvault | tee -a $LOG_FILE
		type $LOG_FILE
		;;
	genconfig)
		genconfig
		;;
	viewconfig)
		decrypt
		;;
	*)
		echo No valid function selected	
		echo "use ./backup [export|genconfig|viewconfig] user encryptionpassphrase"
		;;
esac

