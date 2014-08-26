#!/usr/bin/env bash

# Version 1.0
# Date: 2014-08-26
# Author: Christopher Collins <collins.christopher@gmail.com>
# URL: https://github.com/clcollins/wp-dukeshib-fpm

f_errout() {
  PROGNAME="$(basename $0)"
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

f_confirm() {
        echo -n "$1 "
        read ans
        case "$ans" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) f_errout "Aborted by user." ;;
        esac
}

f_read_wpconfig() {
  DATABASE="$( awk -F\' '/DB_NAME/ {print $4}' $1 2>/dev/null)"
}

DIR="$(pwd | awk -F / '{print $NF}')"

if [ "$DIR" != "html" ] ; then
        f_confirm "The current directory is not an \"html\" directory.  Do you want to continue anyway? (y/n)" 
fi


# WordPress can have a wp-config.php in the docroot, or one above.  
# Check for both.
if [[ -f './wp-config.php' ]] ; then
  f_read_wpconfig './wp-config.php'
else  
  echo "Uable to find a wp-config.php file in this directory.  Looking one directory up..."
  if [[ -f '../wp-config.php' ]] ; then
    f_read_wpconfig '../wp-config.php'
  else
    f_errout "Uable to find a wp-config.php file.  Please update manually."
  fi
fi

CLONEDIR='/tmp/wp-dukeshib-fpm'
if [[ ! -d $CLONEDIR ]] ; then
  f_errout "$CLONEDIR doesn't exit.  Erm...that shouldn't be possible."
fi

SHIBDIR='./wp-content/mu-plugins/shibboleth'
if [[ ! -f $SHIBDIR/shibboleth.php ]] ; then
  f_errout "$SHIBDIR/shibboleth.php does not exist."
else
  patch $SHIBDIR/shibboleth.php < $CLONEDIR/shibboleth.php.patch
fi

DGDIR='./wp-content/mu-plugins/duke_groups'
if [[ ! -f "$DGDIR/duke_groups.php" ]] ; then
  f_errout "$DGDIR/duke_groups.php does not exist."
else
  patch $DGDIR/duke_groups.php < $CLONEDIR/duke_groups.php.patch
fi

USERHOMEDIR="/home/$USER"
echo "Making MySQL backup of the $DATABASE database via 'mysqldump' as the root user. This can sometimes cause the site to slow down or become unresponsive. The backup will be placed into $USERHOMEDIR"
f_confirm "Continue and enter MySQL root password? (y/n)"


mysqldump -u root -p --skip-lock-tables $DATABASE > $USERHOMEDIR/$DATABASE-backup.sql
if [[ "$?" == "0" ]] ; then
  echo "Applying mysql patch to $DATABASE as MySQL root user."
  mysql -u root -p $DATABASE < $CLONEDIR/patch.sql
else
  f_errout "Something went wrong making a backup of the $DATABASE database."
fi

echo "Done.  Please check the site."

