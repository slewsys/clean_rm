#!/usr/bin/env bash
#
# This script generates a .Trashes directory in root of all
# filesystems in $(zfs list).
#
# TODO: Don't create .Trashes in user's home directory.
#
: ${INSTALL:='/usr/bin/install'}
: ${SED:='/usr/bin/sed'}
: ${ZFS:='/sbin/zfs'}

for fs in $($ZFS list -H -o mountpoint | $SED '/^[^/]/d'); do
  trashdir="${fs}/.Trashes"
  $INSTALL -d -m 1333 "$trashdir"
done
