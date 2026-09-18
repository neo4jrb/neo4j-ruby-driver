# frozen_string_literal: true

require 'json'
require 'open3'

# Enforces 100% test coverage on lines added or modified since a base ref.
#
# Coverage is the UNION of every per-flavour SimpleCov resultset passed in
# (spec_helper writes coverage/mri and coverage/jruby; CI adds one per server
# version): a line counts as covered if any run that loaded it hit it, so a
# shared line reachable only under one flavour still passes, version-specific
# code passes when its matching-server run covered it, and each flavour-specific
# file is judged by the run that actually loads it.
#
# A changed line is a violation only when it is executable (non-nil in the
# merged coverage) AND has zero hits. Lines absent from every resultset — blank
# lines, comments, or a file no run loaded — are skipped: the gate never fails
# on a line it has no coverage evidence about, so it stays free of false
# positives (the always-loaded shims like version.rb carry no logic).
class DiffCoverage
  Violation = Data.define(:path, :line)

  def initialize(root:, resultset_paths:, changed_lines:)
    @root = root
    @resultset_paths = resultset_paths
    @changed_lines = changed_lines
  end

  # Merged line hit-counts keyed by repo-relative path, unioned across every
  # resultset so a line covered by any run counts; a line stays relevant
  # (non-nil) if any run marked it executable.
  def coverage
    @coverage ||= @resultset_paths.select { File.exist?(it) }
                                  .each_with_object({}) { |path, merged| merge_resultset(path, merged) }
  end

  def violations
    @changed_lines.flat_map do |rel, lines|
      file_cov = coverage[rel]
      next [] unless file_cov # no run loaded this file → no evidence, skip

      lines.filter_map { |line| Violation.new(rel, line) if file_cov[line - 1]&.zero? }
    end
  end

  # Added/modified line numbers (new side) per path, from `base...HEAD` limited
  # to `pathspec`. Three-dot so only the branch's own changes are considered.
  # git is invoked with an argument array (no shell), and a non-zero status
  # raises — an unknown base must fail the gate, not silently yield an empty diff.
  def self.changed_lines(base:, root:, pathspec: 'lib')
    out, status = Open3.capture2('git', 'diff', '--unified=0', '--no-color',
                                 "#{base}...HEAD", '--', pathspec, chdir: root)
    raise "git diff failed (base #{base.inspect}); ensure the base ref is fetched." unless status.success?

    parse_diff(out)
  end

  def self.parse_diff(text)
    changed = Hash.new { |hash, key| hash[key] = [] }
    path = nil
    text.each_line do |line|
      path = header_path(line) if line.start_with?('+++ ')
      added_range(line).each { |n| changed[path] << n } if path
    end
    changed
  end

  # New-side path of a `+++ ` diff header, or nil for /dev/null (a deleted file,
  # which contributes no new lines). git emits the literal string "/dev/null"
  # in headers on every OS, so it is matched as text, not File::NULL.
  def self.header_path(line)
    path = line[4..].strip
    path == '/dev/null' ? nil : path.delete_prefix('b/') # rubocop:disable Style/FileNull
  end

  # Added-line range from an `@@ -a,b +c,d @@` hunk header (empty otherwise).
  def self.added_range(line)
    return [] unless line.start_with?('@@') && (match = line.match(/\+(\d+)(?:,(\d+))?/))

    start = match[1].to_i
    start...(start + (match[2] || '1').to_i)
  end

  private

  def merge_resultset(path, merged)
    JSON.parse(File.read(path)).each_value do |run|
      run.fetch('coverage', {}).each do |file, data|
        merge_lines(merged[relativize(file)] ||= [], data.is_a?(Hash) ? data['lines'] : data)
      end
    end
  end

  def merge_lines(acc, lines)
    lines.each_with_index { |hit, i| acc[i] = (acc[i] || 0) + hit unless hit.nil? }
  end

  def relativize(path)
    path.start_with?("#{@root}/") ? path.delete_prefix("#{@root}/") : path
  end
end
