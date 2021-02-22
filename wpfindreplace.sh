#!/bin/bash

#### CONSTANTS
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# GRAB THE DOMAIN NAMES ON CPANEL
echo -e "${YELLOW}Please enter the cPanel hostname the Wordpress site exists under (without www eg. site.com)${NC}"
echo -e "${YELLOW}!IMPORTANT! You will be asked for the NEW and OLD site name later. ${NC}"
read -p 'Wordpress site cPanel hostname: ' NEWSITE

# CHECK IF SITE'S EXISTS ON SERVER
for site in $NEWSITE
do
  if ! /scripts/whoowns $site >/dev/null; then
    echo -e "$site ${RED}does NOT exist on the server. Please check and try again.${NC}"
    exit 0
  else
    echo -e "$site ${GREEN}exists on server!${NC}"
  fi
done

# GET THE USERNAME FOR SITE:
NEWUSER=$(/scripts/whoowns $NEWSITE)

# GET THE WP DOC ROOT FOR NEW SITE
NEWDIR=$(grep documentroot /var/cpanel/userdata/$NEWUSER/$NEWSITE | awk '{print $2 "/"}')

# CHECK IF WP IS INSTALLED
for wp in $NEWDIR
do
  if ! /usr/local/cpanel/3rdparty/bin/wp core is-installed --allow-root --path=$wp/; then
    echo -e "$wp ${RED}does NOT contain a Wordpress install. Please check and try again.${NC}"
    exit 0

    else
    echo -e "$wp ${GREEN} contains a Wordpress install!${NC}"
  fi
done

# GET THE WP DETAILS
echo -e "Grabbing wp-config.php details from new site..."
NEWDBNAME=$(/usr/local/cpanel/3rdparty/bin/wp config get DB_NAME --allow-root --path=$NEWDIR)
NEWDBPASS=$(/usr/local/cpanel/3rdparty/bin/wp config get DB_PASSWORD --allow-root --path=$NEWDIR)
NEWDBUSER=$(/usr/local/cpanel/3rdparty/bin/wp config get DB_USER --allow-root --path=$NEWDIR)
NEWDBPREF=$(/usr/local/cpanel/3rdparty/bin/wp config get table_prefix --allow-root --path=$NEWDIR)

# SEARCH AND REPLACE without http/https
echo -e "${YELLOW}Please enter the FIND site hostname (eg dev.site.com)${NC}"
read -p 'OLD Wordpress site name: ' FIND
echo -e "${YELLOW}Please enter the REPLACE site hostname (eg www.site.com)${NC}"
read -p 'NEW Wordpress site name: ' REPLACE

# Dry Run URL change in Database
/usr/local/cpanel/3rdparty/bin/wp search-replace '$FIND' '$REPLACE' $NEWDBPREFposts $NEWDBPREFpostmeta $NEWDBPREFoptions --dry-run --allow-root --path=$NEWDIR

# Check happy to proceed after dry run
echo -e "\n"
read -p $'Dry run completed! Do you wish to proceed with URL replacemet?\n[Y] Yes\n[N] No\n> ' -n 1 -r
echo -e "\n"
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo -e "\nExited Wordpress Search and Replace"
  exit 1
fi

# EXPORT MYSQL DUMP - ORIGINAL SITE
echo -e "${YELLOW}Exporting MySQL dump of ${NEWDBNAME}_backup.sql...${NC}"
mysqldump ${NEWDBNAME} > ${NEWDBNAME}_backup.sql

# Change URL
/usr/local/cpanel/3rdparty/bin/wp search-replace '$FIND' '$REPLACE' $NEWDBPREFposts $NEWDBPREFpostmeta $NEWDBPREFoptions --allow-root --path=$NEWDIR
