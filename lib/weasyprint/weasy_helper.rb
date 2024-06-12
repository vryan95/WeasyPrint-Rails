class WeasyPrint
  module WeasyHelper
    def self.add_extension(filename, extension)
      filename.to_s.split('.').include?(extension) ? filename : "#{filename}.#{extension}"
    end
  end
end