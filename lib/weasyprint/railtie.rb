require 'weasyprint/pdf_helper'

class WeasyPrint
  if defined?(Rails.env)
    class WeasyPrintRailtie < Rails::Railtie
      initializer 'weasyprint.register', :after => 'remotipart.controller_helper' do |_app|
        ActiveSupport.on_load(:action_controller) { ActionController::Base.send :prepend, PdfHelper }
      end
    end

    Mime::Type.register('application/pdf', :pdf) if Mime::Type.lookup_by_extension(:pdf).nil?
  end
end