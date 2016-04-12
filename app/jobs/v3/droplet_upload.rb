module VCAP::CloudController
  module Jobs
    module V3
      class DropletUpload
        attr_reader :max_attempts

        def initialize(local_path, droplet_guid)
          @local_path   = local_path
          @droplet_guid = droplet_guid
          @max_attempts = 3
        end

        def perform
          droplet = DropletModel.find(guid: @droplet_guid)
          digest = nil

          if droplet
            if use_bits_service?
              digest = upload_to_bits_service(@local_path)
            else
              digest = Digester.new.digest_path(@local_path)

              blobstore.cp_to_blobstore(
                @local_path,
                File.join(@droplet_guid, digest)
              )
            end

            droplet.update(droplet_hash: digest)
          end

          FileUtils.rm_f(@local_path)
        end

        def error(job, _)
          if !File.exist?(@local_path)
            @max_attempts = 1
          end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(@local_path)
          end
        end

        def job_name_in_configuration
          :droplet_upload
        end

        def blobstore
          @blobstore ||= CloudController::DependencyLocator.instance.droplet_blobstore
        end

        private

        def upload_to_bits_service(file_path)
          response = bits_client.upload_droplet(file_path)
          JSON.parse(response.body)['guid']
        rescue BitsClient::Errors::Error => e
          raise VCAP::Errors::ApiError.new_from_details('BitsServiceError', e.message)
        end

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
