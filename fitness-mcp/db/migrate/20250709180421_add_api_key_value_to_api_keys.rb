class AddApiKeyValueToApiKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :api_keys, :api_key_value, :text
  end
end
