require 'io/console'

module Console

  TRASHCAN_COLOR = "\e[1;34m"
  RESET_COLOR = "\e[0m"

  def respond(*args)
    if $stdout.isatty
      args.each do |a|
        puts(a.to_s =~ /^\/.*:$/ ? "#{TRASHCAN_COLOR}#{a}#{RESET_COLOR}" : a)
      end
    else
      puts(args)
    end
  end

  def error(*args)
    $err_status = 1
    STDERR.puts "#{$script_name}: #{args.join(' ')}"
    false
  end

  def confirm(action, file, default = 'n')

    default_response =
      case default
      when /n.*/ || /N.*/
        prompt = '[y|N]? '
        false
      else
        prompt = '[Y|n]? '
        true
      end

    STDERR.print "#{action}: #{file}: #{prompt}"
    ch = $stdin.getch(min: 1).codepoints.first

    case ch
    when *['y', 'Y', ].map(&:ord)
      STDERR.puts "#{ch.chr}"
      true
    when *['n', 'N'].map(&:ord)
      STDERR.puts "#{ch.chr}"
      false
    when 3                      # CTRL-C
      STDERR.puts "\n#{$script_name}: User cancelled"
      exit
    else
      STDERR.puts "#{ch.chr}"
      default_response
    end
  end

end
