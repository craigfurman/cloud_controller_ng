module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackCacheCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger = Steno.logger('cc.background')
          logger.info('Attempting cleanup of buildpack_cache blobstore')

          return bits_client.delete_all_buildpack_caches if use_bits_service?

          blobstore = CloudController::DependencyLocator.instance.buildpack_cache_blobstore
          blobstore.delete_all
        end

        def job_name_in_configuration
          :buildpack_cache_cleanup
        end

        def max_attempts
          3
        end

        private

        def use_bits_service?
          !!bits_client
        end

        def bits_client
          CloudController::DependencyLocator.instance.bits_client
        end
      end
    end
  end
end
