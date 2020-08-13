[![Build Status](https://travis-ci.com/slewsys/clean_rm.svg?branch=master)](https://travis-ci.com/slewsys/clean_rm)

# CleanRm

__CleanRm__ is a Ruby library for managing filesystem trash. When a
file is deleted, it's moved to a directory from where it can later be
restored. Files residing in a user's home directory are moved to
`${XDG_DATA_HOME}/Trash` (or `${HOME}/.Trash` on OS X). To avoid
moving across file systems, files outside a user's home directory are
moved to a `.Trash` (or `.Trashes` on OS X) directory created in the
root of the file system containing the file. In the event that such a
trash directory does not exist and cannot be created, then a user's
home trash directory is used instead. On freedesktop.org systems,
presently no attempt is made to create `.Trash-$uid` if a top-level
`.Trash` directory cannot be used.

Previously "deleted" versions of a file can be restored in reverse
order of deletion. Each restore iteration replaces the current file
with an older version until there are no more, then the newest version
is restored again.

Options are available for listing deleted files, prompting before
every removal and permanently removing files, with or without random
overwrites.

Command-line utility `trash` (described below) is intended as a
cross-platform, option-compatible alternative to the Unix `rm(1)` command.

## System Requirements

The file revision stack (FILO) depends on file-access time, as defined
by POSIX `stat(2)` system call.

Device mount-points are provided by Rubygem __sys-filesystem__, an FFI
interface to system-dependent, though generally available, library
interfaces `getmntent(3)`/`getmntinfo(3)`.

To display trashcan contents, a POSIX-compatible `ls(1)` command is expected.
Its path is defined by constant `Trashcan::LS`.

Per-device trashcans are used if available and recommended because
they eliminate the load of moving deleted files across files systems.
__CleanRm__ attempts to create per-device trashcans as needed.
Otherwise, they can be created manually, as defined in
`Trashcan#trashcan()`, of the form _mount-point_`/.Trashes/`,
where _mount-point_ is device's filesystem root, and the `/.Trashes/`
sub-directory permissions must be world writable, executable and
_sticky_.

## Installation
With a recent version of the [Ruby](https://www.ruby-lang.org/en/)
interpreter installed (e.g., ruby 2.5), run the following commands
from a Unix shell:

```bash
git clone https://github.com/slewsys/clean_rm.git
cd clean_rm
sudo gem update --system
bundle
rake build
sudo gem install pkg/clean_rm*.gem
```

The RSpec test suite can be run with:

```bash
bundle exec rspec spec
```

To build RDoc documentation, use:

```bash
rake rdoc
```

## Command-line Interface

```
Usage: trash [-dfiPpRrW] FILE ...
       trash -e [-fiP] [FILE ...]
       trash -l [-R] [FILE ...]
Options:
    -d, --directory    Transfer empty directories as well as other file types
                       to the trashcan.
    -e, --empty        Purge FILEs from trashcan so that they can no longer be
                       restored. If FILE is not given, purge entire trashcan
                       contents.
    -f, --force        Force - i.e., ignore warnings and without prompting.
                       The -f option overrides any previous -i options.
    -h, --help         Show this message, then exit.
    -i, --interactive  Prompt for confirmation before transfering each FILE.
                       The -i option overrides any previous -f options.
    -l, --list         List any FILEs in trashcan. If no FILE is given, list
                       entire trashcan contents.
    -P, --overwrite    Overwrite regular FILEs before purging. The -P option
                       implies option -p.
    -p, --purge        Purge FILEs so that they cannot be restored.
    -R, --recursive    Recursively list or transfer directory hierarchies.
                       The -R option supersedes option -d.
    -r                 Equivalent to option -R.
    -V, --version      Show version, then exit.
    -v, --verbose      Report diagnostics.
    -W, --whiteout     Restore FILEs in trashcan to working directory.
```

## Contributing

Bug reports and pull requests can be sent to
[GitHub clean_rm](https://github.com/slewsys/clean_rm).

## License

This Rubygem is free software. It can be used and redistributed under
the terms of the [MIT License](http://opensource.org/licenses/MIT).
