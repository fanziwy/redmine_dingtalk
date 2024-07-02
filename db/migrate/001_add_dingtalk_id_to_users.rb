class AddDingtalkIdToUsers  < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    add_column :users, :dingtalk_union_id, :string
    add_column :users, :dingtalk_user_id, :string
  end
end
