require 'date'
require 'shellwords'

module StatSymlink
  refine File.singleton_class do
    alias_method :file_stat, :stat
    alias_method :file_utime, :utime

    # Monkey patch File.stat() to support symbolic links.
    def stat(file)
      st_obj =  File.symlink?(file) ? Object.new : File.file_stat(file)
      unless st_obj.respond_to?(:atime)

        # Run OS command stat(1) to get st_* stat var assignments.
        stat_s = `stat -s #{file.shellescape}`
        st = stat_s.split(' ').map { |assign| assign.split('=') }.to_h
        st.keys.each do |var|

          # stat().atime, stat().mtime and stat().ctime return Time instances,
          # corresponding to shell vars st_atime, st_mtime and st_ctime.
          if var[-4..-1] == 'time'
            st_obj.define_singleton_method(var[3..-1]) do
              Time.at(st[var].to_i)
            end
          else
            st_obj.define_singleton_method(var[3..-1]) do
              st[var].to_i
            end
          end
        end
      end
      st_obj
    end

    # Monkey patch File.utime() to support symbolic links.
    def utime(atime, mtime, *file_list)
      file_list.each do |file|
        unless File.symlink?(file)
          file_utime(atime, mtime, file)
        else
          atime_to_touch = atime.to_datetime.strftime("%G%m%d%H%M%W")
          mtime_to_touch = mtime.to_datetime.strftime("%G%m%d%H%M%W")
          `touch -aht #{atime_to_touch} #{file.shellescape}`
          `touch -mht #{mtime_to_touch} #{file.shellescape}`
        end
      end
      file_list.size
    end
  end
end
