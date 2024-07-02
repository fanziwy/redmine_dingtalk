class AddDingtalkTaskIdToIssues < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
    def change
      add_column :issues, :dingtalk_task_id, :string
    end
  end