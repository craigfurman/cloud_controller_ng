require 'cloud_controller/blobstore/url_generator/url_generator_helpers'
require 'cloud_controller/blobstore/url_generator/upload_url_generator'
require 'cloud_controller/blobstore/url_generator/internal_url_generator'
require 'cloud_controller/blobstore/url_generator/local_url_generator'

module CloudController
  module Blobstore
    class UrlGenerator
      include UrlGeneratorHelpers
      extend Forwardable

      def initialize(blobstore_options, package_blobstore, buildpack_cache_blobstore, admin_buildpack_blobstore, droplet_blobstore, bits_client=nil)
        @blobstore_options         = blobstore_options
        @package_blobstore         = package_blobstore
        @buildpack_cache_blobstore = buildpack_cache_blobstore
        @admin_buildpack_blobstore = admin_buildpack_blobstore
        @droplet_blobstore         = droplet_blobstore
        @internal_url_generator    = InternalUrlGenerator.new(blobstore_options, package_blobstore, buildpack_cache_blobstore, admin_buildpack_blobstore, droplet_blobstore)
        @local_url_generator       = LocalUrlGenerator.new(blobstore_options, package_blobstore, buildpack_cache_blobstore, admin_buildpack_blobstore, droplet_blobstore)
        @upload_url_generator      = UploadUrlGenerator.new(blobstore_options)
        @bits_client               = bits_client
      end

      def app_package_download_url(app)
        if @package_blobstore.local?
          @local_url_generator.app_package_download_url(app)
        else
          @internal_url_generator.app_package_download_url(app)
        end
      end

      def package_download_url(package)
        if @package_blobstore.local?
          @local_url_generator.package_download_url(package)
        else
          @internal_url_generator.package_download_url(package)
        end
      end

      def buildpack_cache_download_url(app)
        if use_bits_service?
          return @bits_client.download_url(:buildpack_cache, app.buildpack_cache_key)
        end

        if @buildpack_cache_blobstore.local?
          @local_url_generator.buildpack_cache_download_url(app)
        else
          @internal_url_generator.buildpack_cache_download_url(app)
        end
      end

      def v3_app_buildpack_cache_download_url(app_guid, stack)
        if @buildpack_cache_blobstore.local?
          @local_url_generator.v3_app_buildpack_cache_download_url(app_guid, stack)
        else
          @internal_url_generator.v3_app_buildpack_cache_download_url(app_guid, stack)
        end
      end

      def admin_buildpack_download_url(buildpack)
        return @bits_client.download_url(:buildpacks, buildpack.key) if use_bits_service?

        if @admin_buildpack_blobstore.local?
          @local_url_generator.admin_buildpack_download_url(buildpack)
        else
          @internal_url_generator.admin_buildpack_download_url(buildpack)
        end
      end

      def droplet_download_url(app)
        if use_bits_service?
          droplet = app.current_droplet
          return nil unless droplet && droplet.droplet_hash
          return @bits_client.download_url(:droplets, droplet.droplet_hash)
        end

        if @droplet_blobstore.local?
          @local_url_generator.droplet_download_url(app)
        else
          @internal_url_generator.droplet_download_url(app)
        end
      end

      def v3_droplet_download_url(droplet)
        if use_bits_service?
          return nil unless droplet.droplet_hash
          return @bits_client.download_url(:droplets, droplet.droplet_hash)
        end

        if @droplet_blobstore.local?
          @local_url_generator.v3_droplet_download_url(droplet)
        else
          @internal_url_generator.v3_droplet_download_url(droplet)
        end
      end

      def unauthorized_perma_droplet_download_url(app)
        return nil unless app.droplet_hash

        no_auth_uri("/internal/v2/droplets/#{app.guid}/#{app.droplet_hash}/download")
      end

      def_delegators :@upload_url_generator,
        :droplet_upload_url,
        :package_droplet_upload_url,
        :v3_app_buildpack_cache_upload_url,
        :buildpack_cache_upload_url

      private

      def use_bits_service?
        !!@bits_client
      end
    end
  end
end
