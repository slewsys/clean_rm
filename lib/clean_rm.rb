require 'etc'
require 'find'
require 'fileutils'
require 'timeout'

$have_sys_filesystem =
  begin
    require 'sys/filesystem'
  rescue LoadError => err
    warn err.message
    false
  end

unless Dir.respond_to? :empty?
  def Dir.empty? dir
    glob = Dir.glob(File.join(dir, '*'), File::FNM_DOTMATCH).map do |p|
      File.basename p
    end
    (glob - ['.', '..']).empty?
  end
end

module CleanRm
  class Trashcan

    # Path of POSIX-compatible `ls' command.
    LS = case RbConfig::CONFIG['target_os']
         when /darwin|bsd|linux-gnu/
           '/bin/ls'
         else
           '/usr/bin/ls'
         end

    # Path of trashcan relative to user HOME directory.
    TRASH = case RbConfig::CONFIG['target_os']
            when /darwin/
              '.Trash'
            else
              '.local/share/Trash'
            end

    # Path of per-device trashcans relative device mount point.
    # See instance method #trashcan for complete path derivation.
    TRASHES = '.Trashes'

    # Seconds before file access times out.
    FILE_ACCESS_TIMEOUT = 10

    SECURE_OVERWRITE = 3

    attr_reader :request

    def initialize(ui_module = :Console)
      @uid                 = Etc.getpwuid.uid
      @home_trashcan       = File.join(Dir.home, TRASH)
      @icloud_drive        = File.join(Dir.home, 'Library', 'Mobile Documents')
      @icloud_trashcan     = File.join(@icloud_drive, 'com~apple~CloudDocs', TRASH)
      @request             = { verbose: false }

      if ! Dir.exists?(@home_trashcan)
        begin
          FileUtils.mkdir_p(@home_trashcan, mode: 0700)
        rescue SystemCallError => err
          raise SystemCallError, err.message
        end
      elsif ! File.writable?(@home_trashcan)
        raise SystemCallError, "#{@home_trashcan}: Permission denied"
      elsif File.world_writable?(@home_trashcan)
        raise SecurityError, "#{@home_trashcan}: Unsafe access permissions"
      end

      # Include ui_module to expose `confirm', `respond' and `error' methods...
      self.class.include(Object.const_get ui_module)

      yield(self) if block_given?
    end

    # Permanently delete FILENAMES from trashcans. If FILENAMES is
    # empty, delete contents of all trashcans.
    def empty(filenames, request = {})
      @request = request
      @found = []
      count = 0
      per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) do
          expand_toplevel(filenames).each do |file|
            count += unlink(file)
          end
        end
      end
      report_not_found(filenames)
      count
    end

    # List FILENAMES in trashcans. If FILENAMES is empty, list entire
    # contents of all trashcans.
    def list(filenames, request = {})
      @request = request
      @found = []
      count = 0
      per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) do
          unless (toplevel_files = expand_toplevel(filenames)).empty?

            # If any toplevel_files have dash (-) prefix, LS
            # interprets them as command-line switches. Therefore,
            # prefix these with `./' and then filter `./' on output.
            begin
              IO.popen([LS, '-ald', *toplevel_files.map { |f| './' + f }],
                       :err => [:child, :out]) do |io|
                respond "#{trash_dir}:"
                respond io.readlines.map { |l| l.sub(/ \.\//, ' ') }
              end
              count += toplevel_files.size
            rescue SystemCallError => err
              case err
              when Errno::ENOENT
                error "#{LS}: No such file or directory"
              else
                raise
              end
            end
          end
        end
      end
      report_not_found(filenames)
      count
    end

    # Restore FILENAMES from trashcans to current directory.
    def restore(filenames, request = {})
      @request = request
      @found = []
      count = 0
      per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) { expand_toplevel(filenames) }.each do |file|
          next if File.exists?(file) && ! shift_revision(file)
          count += pop_revision(file, trash_dir)
        end
      end
      report_not_found(filenames)
      count
    end

    # `Delete' FILENAMES by either moving them to trashcan(FILE) or,
    # if option -p is given, by unlinking them.
    def transfer(filenames, request = {})
      @request = request
      count = 0
      expand_fileglobs(filenames).each do |file|
        next if ! have_transfer_permission(file)
        count += request[:permanent] ? unlink(file) : push_revision(file)
      end
      count
    end

    private

    # Set FILE's time to oldest among revisions.
    # See method `unique_name' for revision naming convention.
    def age(file)
      unless (revs = Dir.glob(File.basename(file, ".*") + ".#*#*")).empty?

        # Set FILE's atime to older than oldest revision.
        oldest_atime = revs.map { |f| File.stat(f).atime.to_i }.sort.first
        File.utime(Time.at(oldest_atime - 1), File.stat(file).mtime, file)
      end
    rescue SystemCallError => err
      case err
      when Errno::EPERM
        error "#{file}: Operation not permitted"
      when Errno::EINVAL
        error "#{file}: Invalid argument"
      else
        raise
      end
    end

    def expand_fileglobs(filenames)
      expanded = []
      filenames.each do |file|

        # Do not limit expansion to top-level files.
        files =
          (Dir.glob(file, File::FNM_EXTGLOB).uniq
           .reject { |fn| fn == '.' || fn == '..' })
        if ! files.empty?
          expanded += files
        elsif file == '.' || file == '..'
          error '"." and ".." may not be removed'
        elsif File.exists?(file)
          expanded << file
        elsif ! request[:force]
          error "#{file}: No such file or directory"
        end
      end
      expanded
    end

    def expand_toplevel(filenames)
      expanded = []
      (filenames.empty? ? ['*', '.*'] : filenames).each do |file|

        # Limit expansion to top-level files.
        files =
          (Dir.glob(file, File::FNM_EXTGLOB).uniq
           .map { |fn| File.basename(fn) }
           .reject { |fn| fn == '.' || fn == '..' })
        if ! files.empty?
          expanded += files
          @found << file
        elsif file == '.' || file == '..'
          error '"." and ".." may not be accessed'
        elsif File.exists?(file)
          expanded << file
          @found << file
        # elsif file != '*' && file != '.*' && ! request[:force]
        #   error "#{file}: No such file or directory"
        end
      end
      expanded
    end

    def have_transfer_permission(file)
      if request[:force]
        true
      elsif ! File.writable?(dirname = File.dirname(file))
        error "#{dirname}: Permission denied"
      elsif ! File.writable?(file) && ! request[:force] &&
          ! File.symlink?(file)
        error "#{file}: Use -f to override permissions"
      elsif File.directory?(file) && ! request[:recursive] &&
          ! request[:directory]
        error "#{file}: Use -r or -d for directories"
      elsif File.directory?(file) && request[:directory] &&
          ! Dir.empty?(file)
        error "#{file}: Directory not empty"
      else
        true
      end
    end

    # Refresh device hash for each mount_point and return it.
    def per_device_trashcan
      if $have_sys_filesystem
        Sys::Filesystem.mounts.map(&:mount_point).map do |dir|
          [dir, trashcan(dir)]
        end.to_h
      else
        { '/' => trashcan(Dir.home) }
      end.merge!({ @icloud_drive => @icloud_trashcan }) if Dir.exists?(@icloud_drive)
    end

    def mount_point(file)
      $have_sys_filesystem ? Sys::Filesystem.mount_point(file) : '/'
    rescue SystemCallError
      warn "#{$script_name}: #{file}: Permission denied" \
        if request[:verbose]
      '/'
    end

    # Push FILE to top of revision stack (FILO).
    def push_revision(file)
      count = 0
      if (request[:force] || ! request[:interactive] ||
          confirm('Move to trash', file))
        trash_dir = trashcan(file)
        basename = File.basename(file)
        Dir.chdir(trash_dir) do
          FileUtils.mv(basename, unique_name(basename)) \
            if File.exists?(basename)
        end
        FileUtils.mv(file, File.join(trash_dir, basename))
        count = 1
      end
    rescue SystemCallError => err
      case err
      when Errno::EACCES
        error "#{file}: Permission denied"
      when Errno::EINVAL
        error "#{file}: Invalid argument"
      else
        raise
      end
    ensure
      count
    end

    # Pop FILE from top of revision stack (FILO).
    def pop_revision(file, trash_dir)
      count = 0
      FileUtils.mv(File.join(trash_dir, file), file)
      Dir.chdir(trash_dir) do

        # If previous revisions (i.e., `file.#*#*') exist, then use
        # most recent revision as new FILE.
        unless (revs = Dir.glob(file + ".#*#*")).empty?
          rev = revs.sort_by { |f| test(?A, f) }.last
          FileUtils.mv(rev, file)
        end
      end
      count = 1
    rescue SystemCallError => err
      case err
      when Errno::EACCES
        error "#{File.writable?(Dir.pwd) ? file : '.'}: Permission denied"
      when Errno::EINVAL
        error "#{file}: Invalid argument"
      else
        raise
      end
    ensure
      count
    end

    # Return string of SIZE random bytes.
    def random_bytes(size)
      @random ||= Random.new
      size.times.map { @random.rand(256) }.pack("C" * size)
    end

    def report_not_found(filenames)
      if ! request[:force]
        (filenames - @found).each do |file|
          error "#{file}: No such file or directory"
        end
      end
    end

    # Shift FILE to end (bottom) of revision stack (FILO).
    # Returns nil if error or user-cancel.  Otherwise true.
    def shift_revision(file)

      # Confirm overwriting even if not request[:interative].
      if ((request[:force] || have_transfer_permission(file) &&
           confirm('Overwrite existing', file)))
        trash_dir = trashcan(file)
        rev = Dir.chdir(trash_dir) do
          unique_name(File.basename(file))
        end
        FileUtils.mv(file, File.join(trash_dir, rev))
        Dir.chdir(trash_dir) do
          age(rev)
        end
        true
      end
    rescue SystemCallError => err
      case err
      when Errno::EACCES
        error "#{file}: Permission denied"
      when Errno::EINVAL
        error "#{file}: Invalid argument"
      else
        raise
      end
    end

    # Return trashcan of device on which FILE resides, otherwise
    # @home_trashcan.
    def trashcan(file)
      mount_point = mount_point(file)
      trashes_dir = File.join(mount_point, TRASHES)
      trash_dir = File.join(trashes_dir, @uid.to_s)
      Timeout::timeout(FILE_ACCESS_TIMEOUT) do
        if (Dir.exists?(trash_dir) &&
            File.readable?(trash_dir) &&
            File.writable?(trash_dir) &&
            File.executable?(trash_dir) &&
            ! File.world_writable?(trash_dir))
          trash_dir
        elsif (Dir.exists?(trashes_dir) &&
            File.writable?(trashes_dir) &&
            File.executable?(trashes_dir) &&
            File.sticky?(trashes_dir))
          begin
            Dir.mkdir(trash_dir, 0700)
            trash_dir
          rescue SystemCallError
            # File.open(trash_dir) { |dir| dir.chmod(0700) }
            Dir.exists?(trash_dir) ? trash_dir : @home_trashcan
          rescue
            @home_trashcan
          end
        else
          @home_trashcan
        end
      end
    rescue Timeout::Error
      error "#{file}: Cannot access"
       @home_trashcan
    end

    # Return name of FILE with timestamp + 3-digit index appended.
    def unique_name(file)
      unique = file + ".##{File.stat(file).mtime}#"
      index = Dir.glob(unique + "-*").sort.last
      revision = index.nil? ? 0 : index.sub(/^.*-([0-9]{3,})$/, '\1')
      unique += "-%03d" % ((revision.to_i + 1) % 1000)
    end

    # Permanently delete FILE.
    def unlink(file)
      count = 0
      if (request[:force] ||
          ! request[:interactive] ||
          confirm('Permanently delete', file))

        # Only overwrite "regular" files.
        if request[:overwrite]
          begin
            case File.ftype(file)
            when "file"
              SECURE_OVERWRITE.times do
                IO.write(file, random_bytes(File.size(file)))
              end
            when "directory"
              Find.find(file) do |path|
                (File.file?(path) ? SECURE_OVERWRITE : 0).times do
                  IO.write(path, random_bytes(File.size(path)))
                end
              end
            end
          rescue SystemCallError => err
            case err
            when Errno::EACCES
              error "#{file}: Permission denied"
            when Errno::EINVAL
              error "#{file}: Invalid argument"
            else
              raise
            end
          ensure
            return count
          end
        end

        begin
          FileUtils.rm_rf(file, secure: true)
          count = 1
        rescue SystemCallError => err
          case err
          when Errno::EACCES
            error "#{file}: Permission denied"
          when Errno::EINVAL
            error "#{file}: Invalid argument"
          else
            raise
          end
        end
      end
      count
    end

  end
end
