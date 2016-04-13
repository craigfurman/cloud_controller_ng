Sequel.migration do
  change do
    add_column :route_mappings, :port, Integer, default: nil
  end
end
