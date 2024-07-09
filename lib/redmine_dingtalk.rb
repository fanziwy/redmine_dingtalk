module DingtalkMethods
  def get_api_token
    appid = Setting["plugin_redmine_dingtalk"]["dingtalk_appid"]
          appsecret = Setting["plugin_redmine_dingtalk"]["dingtalk_appsecret"]
    if appid.blank? || appsecret.blank?
      return nil
    end
    uri = URI.parse("https://oapi.dingtalk.com/gettoken?appkey=#{appid}&appsecret=#{appsecret}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)  
    response = http.request(request)
    response_josn = JSON.parse(response.body)

    # 获得token
    token = response_josn["access_token"]
    return token
  end

  def get_token
    access_token = Rails.cache.fetch('dingtalk_access_token',expires_in:6000) do
      get_api_token
    end
    return access_token
  end

  def get_assigned_to(assigned_to)
    if(assigned_to)
      if(assigned_to.login.present?)
        return assigned_to.dingtalk_union_id ? [assigned_to.dingtalk_union_id] :[]
      else
        group = Group.find(assigned_to.id)
        users = group.users
        executorIds = []
				users.each do |user|
					unless user.dingtalk_union_id.blank?
						executorIds.push(user.dingtalk_union_id)
					end
				end
        return executorIds
      end
    end
    return []
  end

  # 自动添加到关注者
  def add_watcher_on_mention(issue,mi_users)
    if !mi_users.empty?
      mi_users.each do |user|
        issue.watchers.create(:user => user) unless issue.watchers.exists?(:user_id => user.id)
      end
    end
  end
end
# patches
require File.expand_path('../redmine_dingtalk/patches/issues_controller_patch', __FILE__)
require File.expand_path('../redmine_dingtalk/patches/dingtalk_journals_patch', __FILE__)
require File.expand_path('../redmine_dingtalk/patches/account_controller_patch', __FILE__)
# hooks
require File.expand_path('../redmine_dingtalk/hooks/views_users_hook', __FILE__)
require File.expand_path('../redmine_dingtalk/hooks/work_dingtalk_hook_listener', __FILE__)