# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'fileutils'
require_relative '../../../tasks/diff_coverage'

# Unit tests for the diff-coverage gate (tasks/diff_coverage.rb). MRI-only: the
# tool runs under CRuby in the diff-coverage CI job; it needs no driver or DB.
RSpec.describe DiffCoverage do
  describe '.parse_diff' do
    let(:diff) do
      <<~DIFF
        diff --git a/lib/mri/foo.rb b/lib/mri/foo.rb
        --- a/lib/mri/foo.rb
        +++ b/lib/mri/foo.rb
        @@ -10,0 +11,2 @@ def x
        +  added line 11
        +  added line 12
        @@ -20 +22 @@
        +  modified line 22
        diff --git a/lib/jruby/bar.rb b/lib/jruby/bar.rb
        --- /dev/null
        +++ b/lib/jruby/bar.rb
        @@ -0,0 +1,3 @@
        +a
        +b
        +c
      DIFF
    end

    it 'collects added and modified new-side line numbers per path' do
      parsed = described_class.parse_diff(diff)
      expect(parsed['lib/mri/foo.rb']).to eq [11, 12, 22]
      expect(parsed['lib/jruby/bar.rb']).to eq [1, 2, 3]
    end

    it 'ignores a deleted file (+++ /dev/null)' do
      deletion = <<~DIFF
        diff --git a/lib/mri/gone.rb b/lib/mri/gone.rb
        --- a/lib/mri/gone.rb
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -was here
        -and here
      DIFF
      expect(described_class.parse_diff(deletion)).to be_empty
    end
  end

  describe '#violations' do
    around do |example|
      Dir.mktmpdir do |root|
        @root = root
        example.run
      end
    end

    # Writes a SimpleCov-shaped resultset for `command` mapping absolute file
    # paths (under @root) to their line hit-count arrays, and returns its path.
    def write_resultset(command, files)
      dir = File.join(@root, 'coverage', command)
      FileUtils.mkdir_p(dir)
      coverage = files.transform_keys { |rel| File.join(@root, rel) }
                      .transform_values { |lines| { 'lines' => lines } }
      path = File.join(dir, '.resultset.json')
      File.write(path, JSON.dump(command => { 'coverage' => coverage }))
      path
    end

    def violations_for(changed_lines, *resultsets)
      described_class.new(root: @root, resultset_paths: resultsets, changed_lines: changed_lines)
                     .violations.map { |v| "#{v.path}:#{v.line}" }.sort
    end

    it 'flags only executable, loaded, zero-hit changed lines' do
      # line 11 covered(1), line 12 uncovered(0), line 22 non-executable(nil)
      mri = write_resultset('mri', 'lib/mri/foo.rb' => (Array.new(10) + [1, 0] + Array.new(10)))
      changed = { 'lib/mri/foo.rb' => [11, 12, 22] }
      expect(violations_for(changed, mri)).to eq ['lib/mri/foo.rb:12']
    end

    it 'treats a shared line as covered if any flavour covered it (union)' do
      # shared line 5 uncovered under MRI(0) but covered under JRuby(3)
      mri = write_resultset('mri', 'lib/shared/s.rb' => [nil, nil, nil, nil, 0])
      jruby = write_resultset('jruby', 'lib/shared/s.rb' => [nil, nil, nil, nil, 3])
      expect(violations_for({ 'lib/shared/s.rb' => [5] }, mri, jruby)).to be_empty
    end

    it 'flags an uncovered shared line when no flavour covered it' do
      mri = write_resultset('mri', 'lib/shared/s.rb' => [nil, nil, nil, nil, 0])
      expect(violations_for({ 'lib/shared/s.rb' => [5] }, mri)).to eq ['lib/shared/s.rb:5']
    end

    it 'skips a changed file no run loaded (no coverage evidence)' do
      mri = write_resultset('mri', 'lib/mri/foo.rb' => [1])
      expect(violations_for({ 'lib/jruby/gone.rb' => [1, 2] }, mri)).to be_empty
    end

    it 'ignores a resultset file that does not exist' do
      mri = write_resultset('mri', 'lib/mri/foo.rb' => [nil, 0])
      missing = File.join(@root, 'coverage/absent/.resultset.json')
      expect(violations_for({ 'lib/mri/foo.rb' => [2] }, mri, missing)).to eq ['lib/mri/foo.rb:2']
    end
  end
end
