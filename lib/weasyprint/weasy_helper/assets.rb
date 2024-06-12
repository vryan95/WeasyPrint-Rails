class WeasyPrint
  module WeasyHelper
    module Assets
      ASSET_URL_REGEX = /url\(['"]?([^'"]+?)['"]?\)/

      class MissingAsset < StandardError; end

      class MissingLocalAsset < MissingAsset
        attr_reader :path

        def initialize(path)
          @path = path
          super("Could not find asset '#{path}'")
        end
      end

      def weasy_stylesheet_link_tag(*sources)
        stylesheet_contents = sources.collect do |source|
          source = WeasyHelper.add_extension(source, 'css')
          "<style type='text/css'>#{read_asset(source)}</style>"
        end.join("\n")

        stylesheet_contents.gsub(ASSET_URL_REGEX) do
          if Regexp.last_match[1].starts_with?('data:')
            "url(#{Regexp.last_match[1]})"
          else
            "url(#{weasy_pdf_asset_path(Regexp.last_match[1])})"
          end
        end.html_safe
      end

      def weasy_asset_path(asset)
        if(pathname = asset_pathname(asset).to_s) =~ URI_REGEXP
          pathname
        else
          "file:///#{pathname}"
        end
      end

      def weasy_javascript_include_tag(*sources)
        sources.collect do |source|
          source = WeasyHelper.add_extension(source, 'js')
          "<script type='text/javascript'>#{read_asset(source)}</script>"
        end.join("\n").html_safe
      end

      def weasy_image_tag(img, options = {})
        image_tag weasy_asset_path(img), options
      end

      private

      # borrowed from wicked_pdf, who borrowed from actionpack/lib/action_view/helpers/asset_url_helper.rb
      URI_REGEXP = %r{^[-a-z]+://|^(?:cid|data):|^//}

      def asset_pathname(source)
        if precompiled_or_absolute_asset?(source)
          asset = asset_path(source)
          pathname = prepend_protocol(asset)
          if pathname =~ URI_REGEXP
            # asset_path returns an absolute URL using asset_host if asset_host is set
            pathname
          else
            File.join(Rails.public_path, asset.sub(/\A#{Rails.application.config.action_controller.relative_url_root}/, ''))
          end
        else
          asset = find_asset(source)
          if asset
            # older versions need pathname, Sprockets 4 supports only filename
            asset.respond_to?(:filename) ? asset.filename : asset.pathname
          else
            File.join(Rails.public_path, source)
          end
        end
      end

      def find_asset(path)
        if Rails.application.assets.respond_to?(:find_asset)
          Rails.application.assets.find_asset(path, :base_path => Rails.application.root.to_s)
        elsif defined?(Propshaft::Assembly) && Rails.application.assets.is_a?(Propshaft::Assembly)
          PropshaftAsset.new(Rails.application.assets.load_path.find(path))
        elsif Rails.application.respond_to?(:assets_manifest)
          asset_path = File.join(Rails.application.assets_manifest.dir, Rails.application.assets_manifest.assets[path])
          LocalAsset.new(asset_path) if File.file?(asset_path)
        else
          SprocketsEnvironment.find_asset(path, :base_path => Rails.application.root.to_s)
        end
      end

      def read_asset(source)
        asset = find_asset(source)
        return asset.to_s.force_encoding('UTF-8') if asset

        unless precompiled_or_absolute_asset?(source)
          raise MissingLocalAsset, source if WeasyPrint.configuration.raise_on_missing_assets

          return
        end

        pathname = asset_pathname(source)
        if pathname =~ URI_REGEXP
          read_from_uri(pathname)
        elsif File.file?(pathname)
          IO.read(pathname)
        elsif WeasyPrint.configuration[:raise_on_missing_assets]
          raise MissingLocalAsset, pathname if WeasyPrint.configuration.raise_on_missing_assets
        end
      end

      # will prepend a http or default_protocol to a protocol relative URL
      # or when no protcol is set.
      def prepend_protocol(source)
        protocol = WeasyPrint.configuration.default_protocol || 'http'
        if source[0, 2] == '//'
          source = [protocol, ':', source].join
        elsif source[0] != '/' && !source[0, 8].include?('://')
          source = [protocol, '://', source].join
        end
        source
      end

      def precompiled_or_absolute_asset?(source)
        !Rails.configuration.respond_to?(:assets) ||
          Rails.configuration.assets.compile == false ||
          source.to_s[0] == '/' ||
          source.to_s.match(/\Ahttps?\:\/\//)
      end

    end
  end
end