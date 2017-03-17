require 'io/console'

module Console

  def respond(*args)
    puts(args)
  end

  def error(*args)
    $err_status = 1
    puts "#{$script_name}: #{args.join(' ')}"
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

    print "#{action}: #{file}: #{prompt}"
    ch = $stdin.getch(min: 1).codepoints.first

    case ch
    when *['y', 'Y', ].map(&:ord)
      puts "#{ch.chr}"
      true
    when *['n', 'N'].map(&:ord)
      puts "#{ch.chr}"
      false
    when 3                      # CTRL-C
      puts "\n#{$script_name}: User cancelled"
      exit
    else
      puts "#{ch.chr}"
      default_response
    end
  end

end
