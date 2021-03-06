require 'fileutils'
require File.dirname(__FILE__) + '/scm.rb'

module Blastr::SourceControl
  
  class SubversionRevision
    attr_accessor :name
    
    def initialize(name)
      @name = name
    end
    
    def to_s
      @name
    end
    
    def ==(other)
      @name == other.name
    end
    
    def before?(revision)
      return false if @name == "HEAD"
      return true if revision.name == "HEAD"
      @name.to_i < revision.name.to_i
    end
  end
  
  class Subversion
    def name; "Subversion"; end
    
    def self.understands_url?(url)
      not url.match(/^(https?:|svn:)(.+)$/).nil?
    end
    
    def initialize(svn_url)
      @svn_url = svn_url
    end
    
    def as_revision(arg)
      raise "Invalid revision: #{arg}" unless arg =~ /^(HEAD)|(\d+)$/
      SubversionRevision.new(arg.to_s)
    end
    
    def latest_revision
      entries = commits_since(as_revision("HEAD"))
      return entries.first.revision unless entries.empty?
      1
    end

    def commits_since(since_revision = 1)
      svn_log_output = svn_log(since_revision)
      svn_log_entries(svn_log_output)
    end
    
    def svn_log_entries(log_output)
      entries = []
      log_output.scan(/r(\d+)\s\|\s(.*?)\s\|.*?\n\n(.*?)\n(-)+/mu).each do |entry|
        revision = as_revision(entry[0])
        author = entry[1]
        comment = entry[2]
        entries << LogEntry.new(revision, author, comment)
      end
      entries
    end

    private
    def svn_log(since_revision = as_revision("1"))
      temp_file = Tempfile.new("svn.log").path
      Blastr::delete_at_exit(temp_file)
      begin
        revision = "#{since_revision}:#{as_revision('HEAD')}"
        revision = as_revision("HEAD") if since_revision.to_s == as_revision("HEAD").to_s
        %x[svn log #{@svn_url} -r #{revision} > #{temp_file}]
        return content_of(temp_file)
      ensure
        FileUtils.remove_file(temp_file)
      end
    end

    private
    def content_of(file)
      file = open(file)
      content = file.read
      file.close
      content
    end
    
  end

end

Blastr::SourceControl.register_implementation(Blastr::SourceControl::Subversion)
