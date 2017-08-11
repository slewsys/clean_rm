#!/usr/bin/env bash
#
# This script generates .Trashes directories for user root and
# all user IDs above $first_uid on all filesystems in $(zfs list).
#
# TODO: Don't create .Trashes in user's home directory.
#
: ${CHMOD:='/bin/chmod'}
: ${CHOWN:='/usr/sbin/chown'}
: ${CUT:='/usr/bin/cut'}
: ${MKDIR:='/bin/mkdir'}
: ${PW:='/usr/sbin/pw'}
: ${SED:='/usr/bin/sed'}
: ${SUDO:='/usr/local/bin/sudo'}
: ${ZFS:='/sbin/zfs'}

first_uid=1001
last_uid=$($PW user next | $CUT -d: -f1)
(( --last_uid ))

for fs in $($ZFS list -o mountpoint | $SED '/^[^/]/d'); do
  trashdir="${fs}/.Trashes"
  $SUDO $MKDIR -p "$trashdir"
  $SUDO $CHMOD 1333 "$trashdir"
  for id in 0 $(eval echo "{$first_uid..$last_uid}"); do
    userdir="${trashdir}/${id}"
    $SUDO $MKDIR -p "$userdir"
    perms=$($PW user show "$id" | $CUT -d: -f3,4)
    $SUDO $CHOWN "$perms" "$userdir"
    $SUDO $CHMOD 700 "$userdir"
  done
done
