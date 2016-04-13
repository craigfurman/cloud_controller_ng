module CloudController
  module BlobSender
    class BitsServiceBlobSender
      def initialize(use_nginx: true)
        @use_nginx = use_nginx
      end

      def send_blob(blob, controller)
        url = blob.public_download_url
        logger.debug "bits service redirect #{url}"

        if @use_nginx
          nginx_redirect(url, controller)
        else
          http_redirect(url, controller)
        end
      end

      private

      def nginx_redirect(url, controller)
        if controller.is_a?(ActionController::Base)
          controller.response_body    = nil
          controller.status           = 200
          controller.response.headers['X-Accel-Redirect'] = "/bits_redirect/#{url}"
        else
          [200, { 'X-Accel-Redirect' => "/bits_redirect/#{url}" }, '']
        end
      end

      def http_redirect(url, controller)
        if controller.is_a?(ActionController::Base)
          controller.response_body    = nil
          controller.status           = 302
          controller.response.headers['Location'] = url
        else
          [302, { 'Location' => url }, '']
        end
      end

      def logger
        @logger ||= Steno.logger('cc.bits_service_blob_sender')
      end
    end
  end
end
