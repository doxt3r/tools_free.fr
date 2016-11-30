#!/bin/bash
set -e

cd "$(dirname "$0")"
if [ $# -ne 3 ]; then
	echo "usage: $0 Login Password db_type"
	exit 1
fi

if ! [[ "$3" =~ ^(mysql|postgresql)$ ]]; then 
	echo "Only mysql or postgresql are accepted as DB Type."
	echo "usage: $0 Login Password db_type"
fi

LFTP_EXISTS="$(which lftp)"
if [ -z "$LFTP_EXISTS" ]; then
	echo "This script uses LFTP tool, please install it to be able to use it."
	exit 1
fi

LOGIN=${1}
PASSWD=${2}
DBTYPE=${3}



website_backup() {
echo "----------------------------------"
echo "Starting backup of website artifacts"
echo "----------------------------------"
# Ignore sessions folder, you can add other folders to ignore after -x option
EXCLUDE_LIST="-x sessions -x lab999"

if [ ! -d "${LOGIN}" ]; then
	echo "Creating fresh copy folder ..."
	mkdir -p "$LOGIN"
	# create folder to backup website artifacts
	lftp ftp://${LOGIN}:${PASSWD}@ftpperso.free.fr -e "mirror -e --verbose ${EXCLUDE_LIST} / ${LOGIN}.free.fr ; quit" || false
else
	# in case copy folder already exists
	echo "/!\ A copy already exists, let's update it !"
	lftp ftp://${LOGIN}:${PASSWD}@ftpperso.free.fr -e "mirror --verbose --only-newer ${EXCLUDE_LIST} / ${LOGIN}.free.fr ; quit" || false
fi

}

db_backup() {
# Exemple de fichier de sauvegarde SQL
echo "----------------------------------"
echo "Step2: Dumping database..."
echo "----------------------------------"

TIMESTAMP="$(date "+%Y-%m-%d_%H%M%S")"
DUMP_FILE="db_dump_${LOGIN}_${TIMESTAMP}.sql.gz"


if [ "${DBTYPE}" == "mysql" ]; then
	#CASE 1: Mysql
	lftp -e "open http://sql.free.fr ; set http:post-content-type application/x-www-form-urlencoded ; quote post /backup.php 'login=${LOGIN}&password=${PASSWD}&check=1&all=1' > ${DUMP_FILE} ; bye"

fi

if [ "${DBTYPE}" == "postgresql" ]; then
	#Case 2: Postgesql
	wget --save-cookies /tmp/PPA_ID --keep-session-cookies -O /dev/null "http://sql.free.fr/phpPgAdmin/redirect.php?subject=server&server=%3A5432%3Adisable&" || false	
	wget --load-cookie /tmp/PPA_ID --keep-session-cookies --post-data="subject=server&server=:5432:disable&loginServer=:5432:disable&loginUsername=$LOGIN&loginPassword=$PASSWD&loginSubmit=Connexion" -O /dev/null "http://sql.free.fr/phpPgAdmin/redirect.php?subject=server&server=%3A5432%3Adisable&" || false
	wget --output-document=${DUMP_FILE} --load-cookie /tmp/PPA_ID --keep-session-cookies --post-data="d_format=copy&what=structureanddata&sd_format=copy&sd_clean=on&sd_oids=on&output=gzipped&action=export&subject=database&server=:5432:disable&database=$LOGIN" "http://sql.free.fr/phpPgAdmin/dbexport.php" || false

fi

}

package_and_clean() {
# Compression de l'ensemble
echo "Packaging...."
tar -cjf backup_"${LOGIN}"_"${TIMESTAMP}".tar.bz2 "${LOGIN}".free.fr "${DUMP_FILE}"
echo "Cleaning..."
rm "${DUMP_FILE}"
echo "Done: backup_${LOGIN}_${TIMESTAMP}.tar.bz2"
}

website_backup
db_backup
package_and_clean
