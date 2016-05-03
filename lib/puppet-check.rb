require_relative 'puppet-check/puppet_parser'
require_relative 'puppet-check/ruby_parser'
require_relative 'puppet-check/data_parser'

# interfaces from CLI/tasks and to individual parsers
class PuppetCheck
  # initialize future parser and style check bools
  @future_parser = false
  @style_check = false

  # initialize diagnostic output arrays
  @error_files = []
  @warning_files = []
  @clean_files = []
  @ignored_files = []

  # initialize style arg arrays
  @puppetlint_args = []
  @rubocop_args = []

  # let the parser methods read user options and append to the file arrays; let CLI and tasks write to user options
  class << self
    attr_accessor :future_parser, :style_check, :error_files, :warning_files, :clean_files, :ignored_files, :puppetlint_args, :rubocop_args
  end

  # TODO: RC find a way to completely remove need for initialize and these vars
  def initialize
    # initialize file type arrays
    @puppet_manifests = []
    @puppet_templates = []
    @ruby_rubies = []
    @ruby_templates = []
    @data_yamls = []
    @data_jsons = []
    @ruby_librarians = []
  end

  # main runner for PuppetCheck
  def run(paths)
    # grab all of the files to be processed and categorize them
    files = parse_paths(paths)
    sort_input_files(files)

    # parse the files
    execute_parsers

    # output the diagnostic results
    self.class.output_results
  end

  # parse the paths and return the array of files
  def parse_paths(paths)
    files = []

    # traverse the unique paths, return all files, and replace // with /
    paths.uniq.each do |path|
      if File.directory?(path)
        files.concat(Dir.glob("#{path}/**/*").select { |subpath| File.file? subpath })
      elsif File.file?(path)
        files.push(path)
      end
    end

    # check that at least one file was found, remove double slashes, and return unique files
    raise "No files found in supplied paths #{paths.join(', ')}." if files.empty?
    files.map! { |file| file.gsub('//', '/') }
    files.uniq
  end

  # sorts the files to be processed and returns them in categorized arrays
  def sort_input_files(input_files)
    input_files.each do |input_file|
      case input_file
      when /.*\.pp$/ then @puppet_manifests.push(input_file)
      when /.*\.epp$/ then @puppet_templates.push(input_file)
      when /.*\.rb$/ then @ruby_rubies.push(input_file)
      when /.*\.erb$/ then @ruby_templates.push(input_file)
      when /.*\.ya?ml$/ then @data_yamls.push(input_file)
      when /.*\.json$/ then @data_jsons.push(input_file)
      when /.*Puppetfile$/, /.*Modulefile$/ then @ruby_librarians.push(input_file)
      else self.class.ignored_files.push("-- #{input_file}")
      end
    end
  end

  # pass the categorized files out to the parsers to determine their status
  def execute_parsers
    PuppetParser.manifest(@puppet_manifests)
    PuppetParser.template(@puppet_templates)
    RubyParser.ruby(@ruby_rubies)
    RubyParser.template(@ruby_templates)
    DataParser.yaml(@data_yamls)
    DataParser.json(@data_jsons)
    RubyParser.librarian(@ruby_librarians)
  end

  # output the results for the files that were requested to be checked
  def self.output_results
    puts "\033[31mThe following files have errors:\033[0m", error_files.join("\n\n") unless error_files.empty?
    puts "\n\033[33mThe following files have warnings:\033[0m", warning_files.join("\n\n") unless warning_files.empty?
    puts "\n\033[32mThe following files have no errors or warnings:\033[0m", clean_files unless clean_files.empty?
    puts "\n\033[34mThe following files were unrecognized formats and therefore not processed:\033[0m", ignored_files unless ignored_files.empty?
  end
end
