class WeasyPrint
  module PdfHelper
    def self.prepended(base)
      # Protect from trying to augment modules that appear
      # as the result of adding other gems.
      return if base != ActionController::Base

      base.class_eval do
        after_action :clean_temp_files
      end
    end

    def render(*args)
      options = args.first
      if options.is_a?(Hash) && options.key?(:pdf)
        render_with_weasy(options)
      else
        super
      end
    end

    def render_to_string(*args)
      options = args.first
      if options.is_a?(Hash) && options.key?(:pdf)
        render_to_string_with_weasy(options)
      else
        super
      end
    end

    def render_with_weasy(options)
      raise ArgumentError, 'missing keyword: pdf' unless options.is_a?(Hash) && options.key?(:pdf)

      make_and_send_pdf(options.delete(:pdf), options)
    end

    def render_to_string_with_weasy(options)
      raise ArgumentError, 'missing keyword: pdf' unless options.is_a?(Hash) && options.key?(:pdf)

      options.delete :pdf
      make_pdf(options)
    end

    private

    def clean_temp_files
      return unless defined?(@wp_tempfiles)

      @wp_tempfiles.each(&:close)
    end

    def make_pdf(options = {})
      render_opts = {
        :template => options[:template],
        :layout => options[:layout],
        :formats => options[:formats],
        :handlers => options[:handlers],
        :assigns => options[:assigns]
      }
      render_opts[:locals] = options[:locals] if options[:locals]
      render_opts[:file] = options[:file] if options[:file]
      html_string = render_to_string(render_opts)
      w = WeasyPrint.new(html_string, {})
      w.to_pdf
    end

    def make_and_send_pdf(pdf_name, options = {})
      options[:layout] ||= false
      options[:template] || File.join(controller_path, action_name)
      options[:disposition] ||= "attachment"
      if options[:show_as_html]
        render_opts = {
          :template => options[:template],
          :layout => options[:layout],
          :formats => options[:formats],
          :handlers => options[:handlers],
          :assigns => options[:assigns],
          :content_type => 'text/html'
        }
        render_opts[:locals] = options[:locals] if options[:locals]
        render_opts[:file] = options[:file] if options[:file]
        render(render_opts)
      else
        pdf_content = make_pdf(options)
        File.open(options[:save_to_file], 'wb') { |file| file << pdf_content } if options[:save_to_file]
        send_data(pdf_content, :filename => pdf_name + '.pdf', :type => 'application/pdf', :disposition => options[:disposition]) unless options[:save_only]
      end
    end
  end
end