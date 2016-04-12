module CloudController
  module BlobSender
    class BitsServiceBlobSender
      def send_blob(blob, controller)
        url = blob.public_download_url
        logger.debug "bits service redirect #{url}"

        if controller.is_a?(ActionController::Base)
          controller.response_body    = nil
          controller.status           = 302
          controller.response.headers['Location'] = url
        else
          return [302, { 'Location' => url }, '']
        end
      end

      private

      def logger
        @logger ||= Steno.logger('cc.bits_service_blob_sender')
      end
    end
  end
end
