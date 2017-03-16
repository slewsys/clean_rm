require 'optparse'
require 'clean_rm/version'
require 'clean_rm/ui_console'

module CleanRm
  class CLI

    attr_reader :option

    def initialize(option = {})
      @option =
        {
         directory: false,
         empty: false,
         force: false,
         interactive: false,
         list: false,
         permanent: false,
         overwrite: false,
         recursive: false,
         shift: false,
         whiteout: false
        }.merge(option)
    end

    def parse_opts(argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$script_name} [-dfilPpRrW] [FILE] ...\n"
        opts.banner += "       #{$script_name} -e [-fiP] [FILE] ...\n"
        opts.separator "Options:"

        opts.on("-d", "--directory",
                "Remove directories as well as other
                                     file types.") do
          unless @option[:recursive]
            @option[:directory] = true
          end
        end

        opts.on("-e", "--empty",
                "Empty contents of trashcan (permanently).") do
          unless @option[:whiteout]
            @option[:empty] = true
          end
        end

        opts.on("-f", "--force",
                "Force, i.e., ignore warnings and without
                                     prompting. The -f option overrides any
                                     previous -i options.") do
          @option.merge!(force: true, interactive: false)
        end

        opts.on("-i", "--interactive",
                "Prompt for confirmation before removing.
                                     The -i option overrides any previous -f
                                     options.") do
          @option.merge!(force: false, interactive: true)
        end

        opts.on("-l", "--list",
                "List trashcan contents.") do
          @option[:list] = true
        end

        opts.on("-p", "--permanent",
                "Permanently remove.") do
          @option[:permanent] = true
        end

        opts.on("-P", "--overwrite",
                "Overwrite regular files before deleting.
                                     The -P option implies option -p.") do
          @option.merge!(overwrite: true, permanent: true)
        end

        opts.on("-R", "--recursive",
                "Recursively remove directory hierarchies.
                                     The -R option supersedes option -d.") do
          @option.merge!(recursive: true, directory: false)
        end

        opts.on("-r", "--recursive",
                "Equivalent to option -R.") do
          @option.merge!(recursive: true, directory: false)
        end

        opts.on("-W", "--whiteout",
                "Restore deleted file(s) to current
                                     directory.") do
          @option.merge!(whiteout: true, empty: false,
                         recursive: true, directory: false)
        end

        # No argument, shows at tail.  This will print an option summary.
        opts.on_tail("-h", "--help",
                     "Display this message, then exit.") do
          puts opts
          exit
        end

        # Version.
        opts.on_tail("-V", "--version",
                     "Show version, then exit.") do
          puts "#{$script_name.capitalize} #{CleanRm::VERSION}"
          exit
        end
      end.parse(argv)
    end

  end
end
