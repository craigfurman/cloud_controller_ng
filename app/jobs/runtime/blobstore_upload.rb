module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreUpload < VCAP::CloudController::Jobs::CCJob
        attr_reader :local_path, :blobstore_key, :blobstore_name
        attr_reader :max_attempts

        def initialize(local_path, blobstore_key, blobstore_name)
          @local_path = local_path
          @blobstore_key = blobstore_key
          @blobstore_name = blobstore_name
          @max_attempts = 3
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Uploading '#{blobstore_key}' to blobstore '#{blobstore_name}'")

          if use_bits_service? && blobstore_name.to_sym == :buildpack_cache_blobstore
            bits_client.upload_buildpack_cache(blobstore_key, local_path)
          else
            blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
            blobstore.cp_to_blobstore(local_path, blobstore_key)
          end

          FileUtils.rm_f(local_path)
        end

        def job_name_in_configuration
          :blobstore_upload
        end

        def error(job, _)
          if !File.exist?(local_path)
            @max_attempts = 1
          end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(local_path)
          end
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
