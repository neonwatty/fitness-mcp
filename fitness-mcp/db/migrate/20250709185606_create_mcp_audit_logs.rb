class CreateMcpAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :api_key, null: false, foreign_key: true
      t.string :tool_name
      t.text :arguments
      t.boolean :result_success
      t.string :ip_address
      t.datetime :timestamp

      t.timestamps
    end
    
    add_index :mcp_audit_logs, :timestamp
    add_index :mcp_audit_logs, [:user_id, :timestamp]
    add_index :mcp_audit_logs, [:api_key_id, :timestamp]
  end
end
