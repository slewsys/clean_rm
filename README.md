# CleanRm

__CleanRm__ is a Ruby library for managing filesystem trash. Previously
"deleted" versions of a file can be restored in reverse order of
deletion. Each restore iteration replaces the current file with an older
version, until the original file is restored.

The command-line utility, `trash` (described below), offers a safe
alternative to the Unix `rm(1)` command.

## System Requirements

The file revision stack (FILO) depends on file-access time, which
should work with any filesystem implementing POSIX `stat(2)` system
call.

Device mount-point information is provided by Rubygem
__sys-filesystem__, an FFI interface to `getmntent(3)`/`getmntinfo(3)`.

To display trashcan contents, a POSIX-compatible `ls(1)` command is expected
(see `Trashcan::LS`).

## Notes

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'clean_rm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install clean_rm

Per-device trashcans are recommended and used if available.
These must be created separately and are expected to be of the form:


_mount-point_`/.Trashes/`_user-id_,

where _mount-point_ is device's filesystem root, and _user-id_
is provided by the POSIX `getuid(2)` system call.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/slewsys/clean_rm. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
