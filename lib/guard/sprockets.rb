require 'guard'
require 'guard/guard'

require 'sprockets'
require 'execjs'

module Guard
  class Sprockets < Guard
    def initialize(watchers=[], options={})
      super

      @libs = options.delete(:require) || []
      @libs.each do |lib|
        require lib
      end

      @sprockets = ::Sprockets::Environment.new

      # Unregister the DirectiveProcessor so nested assets wont be compiled
      if options[:develop_mode]
        @sprockets.unregister_preprocessor('application/javascript', ::Sprockets::DirectiveProcessor)
      end

      @asset_paths = options.delete(:asset_paths) || []
      @asset_paths.each do |p|
        @sprockets.append_path p
      end

      if options.delete(:minify)
        begin
          require 'uglifier'
          @sprockets_env.js_compressor = ::Uglifier.new
          UI.info "Sprockets will compress output (minify)."
        rescue
          UI.error "minify: Uglifier cannot be loaded. No compression will be used.\nPlease include 'uglifier' in your Gemfile.\n#{$!}"
        end
      end
      # store the output destination
      @destination = options.delete(:destination)
      @root_file   = options.delete(:root_file)

      @opts = options
    end

    def start
       UI.info "Sprockets activated."
       UI.info "  - external asset paths = #{@asset_paths.inspect}" unless @asset_paths.empty?
       UI.info "  - destination path = #{@destination.inspect}"
       UI.info "  - loaded libs = #{@libs.inspect}" if !@libs.empty?
       UI.info "  - Development Mode" if @opts[:develop_mode]
       UI.info "Sprockets guard is ready and waiting for some file changes..."

       run_all
    end

    def run_all
      run_on_change([ @root_file ]) if @root_file

      true
    end

    def run_on_change(paths)
      if @root_file
        sprocketize(@root_file)
      else
        paths.each do |file|
          sprocketize(file)
        end
      end

      true
    end

    private

    def determine_extension(path)
      path.gsub(/\.(coffee|hamlc)$/, '.js')
    end

    def sprocketize(path)
      changed = Pathname.new(path)

      @sprockets.append_path changed.dirname

      output_basename = changed.basename.to_s
      output_basename.gsub!(/^(.*\.(?:js|css))\.[^.]+$/, '\1')

      if @opts[:develop_mode]
        output_base = path
        # Clear out possible asset path's
        @asset_paths.each do |b_path|
          output_base = path.gsub(/^#{b_path}\//, '')
        end

        # Replace
        output_basename = determine_extension(output_base)
      end

      output_file = Pathname.new(File.join(@destination, output_basename))

      UI.info "Sprockets: compiling #{output_file}"

      FileUtils.mkdir_p(output_file.parent) unless output_file.parent.exist?
      output_file.open('w') do |f|
        f.write @sprockets[output_basename]
      end

      UI.info "Sprockets finished compiling #{output_file}"
      Notifier.notify "Compiled #{output_basename}"
    rescue ExecJS::ProgramError => e
      UI.error "Sprockets failed to compile #{output_file}"
      UI.error e.message
      Notifier.notify "Syntax error in #{output_basename}: #{e.message}", :priority => 2, :image => :failed
    end
  end
end
