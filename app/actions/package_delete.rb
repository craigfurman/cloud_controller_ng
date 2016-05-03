module VCAP::CloudController
  class PackageDelete
    def initialize(bits_service_enabled = false)
      @bits_service_enabled = bits_service_enabled
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(key(package), :package_blobstore, nil)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        package.destroy
      end
    end

    private

    def key(package)
      @bits_service_enabled ? package.package_hash : package.guid
    end
  end
end
