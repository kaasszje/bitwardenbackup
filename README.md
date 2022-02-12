# bitwardenbackup
First off configure your environment by setting these vars:
BWBIN='location to bw cli'
BACKUP_LOCATION='location to store backup'
CONFIG_LOCATION='location to store config files'
LOG_LOCATION='location for log files'

After create a config file with:
./backup.sh genconfig <user>

This will ask for several config items:
BW_CLIENTID
BW_CLIENTSECRET
BW_PASSWORD
  
These will be stored in an gpg encrypted config file.
  
After that you can run the export:
./backup.sh export <user> <passphrase for config>
