require 'etc'
require 'fileutils'
require 'shellwords'

$have_sys_filesystem =
  begin
    require 'sys/filesystem'
  rescue LoadError => err
    warn(err.message)
    false
  end

module CleanRm
  class Trashcan

    if RbConfig::CONFIG['target_os'] =~ /linux/
      LS    =  '/usr/bin/ls'
    else
      LS    = '/bin/ls'
    end

    TRASH   = '.Trash'
    TRASHES = '.Trashes'

    attr_reader :filenames
    attr_reader :request
    attr_reader :per_device_trashcan

    def initialize(filenames = [], request = {}, ui_module = :Console)

      @filenames           = filenames
      @request             = request
      @uid                 = Etc.getpwnam(Etc.getlogin).uid
      @trashcan_topdir     = File.join(TRASHES, @uid.to_s)
      @home_trashcan       = File.join(Dir.home, TRASH)
      @per_device_trashcan = {}

      if ! Dir.exists?(@home_trashcan)
        begin
          Dir.mkdir(@home_trashcan, 0700)
        rescue SystemCallError => errmsg
          raise SystemCallError, errmsg
        end
      elsif ! File.writable?(@home_trashcan)
        raise SystemCallError, "#{@home_trashcan}: Permission denied"
      elsif File.world_writable?(@home_trashcan)
        raise SecurityError, "#{@home_trashcan}: Unsafe access permissions"
      end

      # Initialize @per_device_trashcan hash for each mount_point...
      #
      # NB: Though @per_device_trashcan can go out-of-date when new
      #     devices are mounted after Trashcan instantiation,
      #     trashcan(FILE) is always current.
      $have_sys_filesystem ?
        Sys::Filesystem.mounts.map(&:mount_point).each { |dir| trashcan(dir) } :
        trashcan(Dir.home)

      # Include ui_module to expose `confirm' and `respond' methods...
      self.class.include(Object.const_get ui_module)

      yield(self) if block_given?
    end

    # Permanently delete @FILENAMES from trashcans. If @FILENAMES is
    # empty, delete entire contents of all trashcans.
    def empty()
      count = 0
      @per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) do
          expand_toplevel(@filenames).each do |file|
            if (! @request[:interactive] ||
                confirm('Permanently delete', file))
              FileUtils.rm_rf(file, secure: true)
              count += 1
            end
          end
        end
      end
      count
    rescue Exception => err
      respond "#{$script_name}: empty: #{err.message}"
    end

    # List @FILENAMES in trashcans. If @FILENAMES is empty, list entire
    # contents of all trashcans.
    def list()
      count = 0
      @per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) do
          unless (toplevel_files = expand_toplevel(@filenames)).empty?
            respond "#{trash_dir}:"

            # If any toplevel_files have dash (-) prefix, LS
            # interprets them as command-line switches. Therefore,
            # prefixed these with `./' and remove prefix in output.
            IO.popen([LS, '-ald', *toplevel_files.map { |f| './' + f }],
                     :err => [:child, :out]) do |io|
              respond io.readlines.map { |l| l.sub(/ \.\//, ' ') }
            end
            count += toplevel_files.size
          end
        end
      end
      respond "Trashcan is empty." if count.zero?
      count
    end

    # Restore @FILENAMES from trashcans to current directory.
    def restore()
      count = 0
      @per_device_trashcan.values.uniq.each do |trash_dir|
        Dir.chdir(trash_dir) { expand_toplevel(@filenames) }.each do |file|
          next if File.exists?(file) && ! shift_revision(file)
          count += pop_revision(file, trash_dir)
        end
      end
      count
    end

    # `Delete' FILE either by moving it to trashcan(FILE), or if -p
    # option is given, by unlinking it.
    def transfer()
      count = 0
      expand_fileglobs(@filenames).each do |file|
        next if ! have_transfer_permission(file)
        count += @request[:permanent] ? unlink(file) : push_revision(file)
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
    rescue Exception => err
      respond "#{$script_name}: age: #{err.message}"
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
        elsif ! @request[:force]
          respond "#{$script_name}: #{file}: No such file or directory"
        end
      end
      expanded
    end

    def expand_toplevel(filenames)

      # Limit expansion to top-level files.
      Dir.glob(filenames.empty? ? ['*'] : filenames, File::FNM_EXTGLOB).uniq
      .map { |fn| File.basename(fn) }
      .reject { |fn| fn == '.' || fn == '..' }
    end

    def have_transfer_permission(file)
      if ! File.writable?(dirname = File.dirname(file))
        respond "#{$script_name}: #{dirname}: Permission denied"
      elsif ! File.writable?(file) && ! @request[:force] &&
          ! File.symlink?(file)
        respond "#{$script_name}: #{file}: Use -f to override permissions"
      elsif File.directory?(file) && ! @request[:recursive] &&
          ! @request[:directory]
        respond "#{$script_name}: #{file}: Use -r or -d for directories"
      elsif File.directory?(file) && @request[:directory] &&
          ! Dir.empty?(file)
        respond "#{$script_name}: #{file}: Directory not empty"
      else
        true
      end
    end

    def mount_point(file)
      $have_sys_filesystem ? Sys::Filesystem.mount_point(file) : '/'
    rescue Exception => err
      respond "#{$script_name}: mount_point: #{err.message}" \
        if @request[:verbose]
      '/'
    end

    # Push FILE to top of revision stack (FILO).
    def push_revision(file)
      count = 0
      if (@request[:force] || ! @request[:interactive] ||
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
      count
    rescue Exception => err
      respond "#{$script_name}: #{revision}: #{err.message}"
      0
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
        count = 1
      end
      count
    rescue Exception => err
      respond "#{$script_name}: #{file}: #{err.message}"
      0
    end

    # Shift FILE to end (bottom) of revision stack (FILO).
    # Returns false on error or user-cancel.
    def shift_revision(file)

      # Confirm overwriting even if not @request[:interative].
      if ((@request[:force] || confirm('Overwrite existing', file)) &&
          have_transfer_permission(file))
        trash_dir = trashcan(file)
        rev = Dir.chdir(trash_dir) do
          unique_name(File.basename(file))
        end
        FileUtils.mv(file, File.join(trash_dir, rev))
        Dir.chdir(trash_dir) do
          age(rev)
        end
      end
    rescue Exception => err
      respond "#{$script_name}: #{file}: #{err.message}"
    end

    # Return trashcan of device on which FILE resides, otherwise
    # @home_trashcan.
    def trashcan(file)
      mount_point = mount_point(file)
      trash_dir = File.join(mount_point, @trashcan_topdir)
      @per_device_trashcan[mount_point] ||=
        (Dir.exists?(trash_dir) &&
         File.writable?(trash_dir) &&
         ! File.world_writable?(trash_dir)) ?
        trash_dir : @home_trashcan
    end

    # Return FILE with timestamp + 3-digit index appended.
    def unique_name(file)
      unique = file + ".##{File.stat(file).mtime}#"
      index = Dir.glob(unique + "-*").sort.last
      revision = index.nil? ? 0 : index.sub(/^.*-([0-9]{3,})$/, '\1')
      unique += "-%03d" % ((revision.to_i + 1) % 1000)
    end

    # Skip trashcan and permanently delete FILE.
    def unlink(file)
      count = 0
      if (@request[:force] ||
          ! @request[:interactive] ||
          confirm('Permanently delete', file))

        # Only overwrite "regular" files.
        IO.write(file, IO.read("/dev/random", File.size(file))) \
          if @request[:overwrite] && File.ftype(file) == "file"

        FileUtils.rm_rf(file, secure: true)
        count = 1
      end
      count
    rescue Exception => err
      respond "#{$script_name}: #{file}: #{err.message}"
      0
    end

  end
end
