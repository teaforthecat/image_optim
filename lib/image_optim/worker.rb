# encoding: UTF-8

require 'shellwords'
require 'image_optim'

class ImageOptim
  class Worker
    class << self
      # List of avaliable workers
      def klasses
        @klasses ||= []
      end

      # Remember all classes inheriting from this one
      def inherited(base)
        klasses << base
      end

      # Undercored class name
      def underscored_name
        @underscored_name ||= name.split('::').last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end
    end

    include OptionHelpers

    # Configure (raises on extra options)
    def initialize(image_optim, options = {})
      @image_optim = image_optim
      parse_options(options)
      assert_options_empty!(options)
    end

    # List of formats which worker can optimize
    def image_formats
      format_from_name = self.class.name.downcase[/gif|jpeg|png/]
      format_from_name ? [format_from_name.to_sym] : []
    end

    # Ordering in list of workers
    def run_order
      0
    end

    # Check if operation resulted in optimized file
    def optimized?(src, dst)
      dst.size? && dst.size < src.size
    end

  private

    # Forward bin resolving to image_optim
    def resolve_bin!(bin)
      @image_optim.resolve_bin!(bin)
    end

    # Run command setting priority and hiding output
    def execute(bin, *arguments)
      resolve_bin!(bin)

      command = [bin, *arguments].map(&:to_s).shelljoin
      start = Time.now

      Process.wait(fork do
        ENV['PATH'] = "#{@image_optim.resolve_dir}:#{ENV['PATH']}"
        $stdout.reopen('/dev/null')
        $stderr.reopen('/dev/null')
        Process.setpriority(Process::PRIO_PROCESS, 0, @image_optim.nice)
        exec command
      end)

      raise SignalException.new($?.termsig) if $?.signaled?

      $stderr << "#{$?.success? ? '✓' : '✗'} #{Time.now - start}s #{command}\n" if @image_optim.verbose?

      $?.success?
    end
  end
end
