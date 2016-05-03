module VCAP::CloudController
  class BitsExpiration
    def initialize(input_config=Config.config)
      config = {}
      config[:packages] = input_config[:packages] || {}
      config[:droplets] = input_config[:droplets] || {}
      @droplets_storage_count = config[:packages][:max_valid_packages_stored] || 5
      @packages_storage_count = config[:droplets][:max_staged_droplets_stored] || 5
    end

    attr_reader :droplets_storage_count, :packages_storage_count

    def expire_droplets!(app)
      return unless is_v3? app
      dataset = DropletModel.where(state: DropletModel::STAGED_STATE, app_guid: app.guid).
                exclude(guid: app.droplet_guid)
      return if dataset.count < droplets_storage_count
      data_to_expire = filter_dataset(dataset, droplets_storage_count)

      # cc does nil the droplet_hash in the next line, that will break the bit-serivce
      # just removed the nil'ing of the droplet_hash for now - this should come back when bits-service stores its blob guid
      # in a better place than the package_hash
      DropletModel.where(id: expired_ids(data_to_expire)).update(state: DropletModel::EXPIRED_STATE)
    end

    def expire_packages!(app)
      return unless is_v3? app
      current_package_guid = app.droplet ? app.droplet.package.guid : nil
      dataset = PackageModel.where(state: PackageModel::READY_STATE, app_guid: app.guid).
                exclude(guid: current_package_guid)
      return if dataset.count < packages_storage_count
      data_to_expire = filter_dataset(dataset, packages_storage_count)

      # cc does nil the package_hash in the next line, that will break the bit-serivce
      # just removed the nil'ing of the package_hash for now - this should come back when bits-service stores its blob guid
      # in a better place than the package_hash
      PackageModel.where(id: expired_ids(data_to_expire)).update(state: PackageModel::EXPIRED_STATE)
    end

    private

    def is_v3?(app)
      app.is_a? AppModel
    end

    def expired_ids(dataset)
      dataset.map(:id)
    end

    def filter_dataset(dataset, storage_count)
      data_to_keep = dataset.order_by(Sequel.desc(:created_at)).limit(storage_count).map(:guid)
      dataset.exclude(guid: data_to_keep)
    end
  end
end
