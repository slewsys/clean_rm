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
         verbose: false,
         whiteout: false
        }.merge(option)
    end

    def parse_opts(argv)
      parser = OptionParser.new(nil, 18) do |opts|
        opts.banner = "Usage: #{$script_name} [-dfiPpRrW] FILE ...\n"
        opts.banner += "       #{$script_name} -e [-fiP] [FILE ...]\n"
        opts.banner += "       #{$script_name} -l [-R] [FILE ...]\n"
        opts.separator "Options:"

        opts.on("-d", "--directory",
                "Transfer empty directories as well as other file types
                       to the trashcan.") do
          unless @option[:recursive]
            @option[:directory] = true
          end
        end

        opts.on("-e", "--empty",
                "Purge FILEs from trashcan so that they can no longer be
                       restored. If FILE is not given, purge entire trashcan
                       contents.") do
          unless @option[:whiteout]
            @option[:empty] = true
          end
        end

        opts.on("-f", "--force",
                "Force - i.e., ignore warnings and without prompting.
                       The -f option overrides any previous -i options.") do
          @option.merge!(force: true, interactive: false)
        end

        opts.on("-h", "--help",
                     "Show this message, then exit.") do
          puts opts
          exit $err_status
        end

        opts.on("-i", "--interactive",
                "Prompt for confirmation before transfering each FILE.
                       The -i option overrides any previous -f options.") do
          @option.merge!(force: false, interactive: true)
        end

        opts.on("-l", "--list",
                "List any FILEs in trashcan. If no FILE is given, list
                       entire trashcan contents.") do
          @option[:list] = true
        end

        opts.on("-P", "--overwrite",
                "Overwrite regular FILEs before purging. The -P option
                       implies option -p.") do
          @option.merge!(overwrite: true, permanent: true)
        end

        opts.on("-p", "--purge",
                "Purge FILEs so that they cannot be restored.") do
          @option[:permanent] = true
        end

        opts.on("-R", "--recursive",
                "Recursively list or transfer directory hierarchies.
                       The -R option supersedes option -d.") do
          @option.merge!(recursive: true, directory: false)
        end

        opts.on("-r",
                "Equivalent to option -R.") do
          @option.merge!(recursive: true, directory: false)
        end

        opts.on("-V", "--version",
                     "Show version, then exit.") do
          puts "#{$script_name.capitalize} #{CleanRm::VERSION}"
          exit $err_status
        end

        opts.on("-v", "--verbose",
                "Report diagnostics.") do
          @option[:verbose] = true
        end

        opts.on("-W", "--whiteout",
                "Restore FILEs in trashcan to working directory.") do
          @option.merge!(whiteout: true, empty: false,
                         recursive: true, directory: false)
        end

      end

      begin
        parser.parse(argv)
      rescue StandardError => err
        puts "#{$script_name}: #{err.message}"
        $err_status = 1
        parser.parse(%w[--help])
      end
    end

  end
end
