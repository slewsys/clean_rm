require 'spec_helper'
require 'clean_rm/cli'

RSpec.describe CleanRm do
  context 'command-line options' do
    it 'prints a version number' do
      expect { trash '-V' }.to output_string('Trash ' + CleanRm::VERSION)
    end

    it 'summarizes usage if no arguments' do
      expect { trash '-h' }.to output_contents_of('help.txt')
    end

    it 'summarizes usage with option -h' do
      expect { trash '-h' }.to output_contents_of('help.txt')
    end

    it 'empties the trashcan with option -e' do
      expect { trash '-ef' }.to output_nothing
    end

    it 'says trashcan is empty with option -l' do
      expect { trash '-l' }.to output_contents_of('trashcan-empty.txt')
    end

    it 'complains about non-existent files' do
      expect { trash 'no-such-file' }.to output_contents_of('no-such-file.txt')
    end

    it 'does not complain about non-existent files with option -f' do
      expect { trash '-f', 'no-such-file' }.to output_nothing
    end
  end

  context 'files' do
    it 'transfers files' do
      File.write('1', Time.now)
      expect { trash '1' }.to output_nothing
      expect(File.exists?("1")).to eq(false)
    end

    it 'lists trashcan contents' do
      expect { trash '-l' }.to output_matching(/[rwx-]+ 1 .* 1/)
    end

    it 'versions transferred files' do
      File.write('1', Time.now)
      expect { trash '1' }.to output_nothing
      expect { trash '-l' }.to output_matching(/[rwx-]+ 1 .* 1.#.*#-\d{3}/)
    end

    it 'restores transferred files' do
      expect { trash '-W', '1'}.to output_nothing
      expect(File.exists?("1")).to eq(true)
    end
  end

  context 'directories' do
    it 'complains about transfering directories' do
      Dir.mkdir('2') if ! Dir.exists?('2')
      expect { trash '2' }.to output_contents_of('use-r-for-dirs.txt')
    end

    it 'transfers directories with option -d' do
      expect { trash '-d', '2' }.to output_nothing
      expect(Dir.exists?("2")).to eq(false)
    end

    it 'complains about non-empty directories with option -d' do
      Dir.mkdir('2') if ! Dir.exists?('2')
      File.write('2/1', Time.now)
      expect { trash '-d', '2' }.to output_contents_of('dir-not-empty.txt')
      expect(Dir.exists?("2")).to eq(true)
    end

    it 'transfers non-empty directories with option -r' do
      Dir.mkdir('2') if ! Dir.exists?('2')
      File.write('2/1', Time.now)
      expect { trash '-r', '2' }.to output_nothing
      expect(Dir.exists?("2")).to eq(false)
    end
  end

  context 'versioning transfers' do
    before {
      trash '-ef'
      oldest =   Time.now.to_s
      middle =   (Time.now + 1).to_s
      youngest = (Time.now + 2).to_s
      @dates = [oldest, middle, youngest]
      @dates.each do |date|
        File.write('1', date)
        trash '1'
      end
    }

    it 'restores in reverse order of transfer' do
      @dates.reverse.each do |date|
        trash '-W', '1'
        expect(File.read('1')).to eq(date)
        File.delete('1')
      end
    end

    it 'files overwritten by restore are versioned' do
      @dates.reverse.each do |date|
        trash '-Wf', '1'
        expect(File.read('1')).to eq(date)
      end
      @dates.reverse.each do |date|
        trash '-Wf', '1'
        expect(File.read('1')).to eq(date)
      end
    end

  end

end
