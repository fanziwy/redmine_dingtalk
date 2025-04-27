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

  def extract_mentions(issue)
    description = issue.description || ''
    notes = issue.notes || ''
    text = "#{description} #{notes}"
    # 正则表达式匹配提及的用户名
    mentions = text.scan(/@(\w+)/).flatten
    # 根据用户名查找用户
    User.where(:login => mentions).to_a
  end

  # 自动添加到关注者
  def add_watcher_on_mention(issue,mi_users)
    if !mi_users.empty?
      mi_users.each do |user|
        issue.watchers.create(:user => user) unless issue.watchers.exists?(:user_id => user.id)
      end
    end
  end

  # 用钉钉发送 
  def send_by_dingtalk(issue)
    agent_id = Setting["plugin_redmine_dingtalk"]["dingtalk_agentid"]
    if agent_id.blank?
      return
    end
    begin
      operatorId = issue.author.dingtalk_union_id
      if issue.dingtalk_task_id.present? && issue.journals.last.user.dingtalk_union_id.present?
        operatorId = issue.journals.last.user.dingtalk_union_id
      end

      if operatorId.blank?
        return
      end

      token = get_token
      if token.blank?
        return
      end

      to_users = issue.notified_users
      cc_users = issue.notified_watchers - to_users
      mi_users = extract_mentions(issue) - to_users - cc_users
      notify_users = to_users + cc_users + mi_users

      add_watcher_on_mention(issue,mi_users) # 自动添加到关注者

      participantIds = []
      notified_ids = ''

      notify_users.each do |user|
        unless user.dingtalk_union_id.blank?
          participantIds.push(user.dingtalk_union_id)
        end
        unless user.dingtalk_user_id.blank?
          notified_ids.concat(user.dingtalk_user_id).concat(",")
        end
      end

      
      issue_title = issue.project.name
      issue_url =  Setting.protocol + "://" + Setting.host_name + "/issues/#{issue.id}"
      issue_app_url = "dingtalk://dingtalkclient/page/link?url=#{Addressable::URI.encode(issue_url)}&pc_slide=true"
      corpid = Setting["plugin_redmine_dingtalk"]["dingtalk_corp_id"]
      appid = Setting["plugin_redmine_dingtalk"]["dingtalk_appid"]
      issue_pc_url = "dingtalk://dingtalkclient/action/openapp?corpid=#{corpid}&container_type=work_platform&app_id=#{appid}&redirect_type=jump&redirect_url=#{Addressable::URI.encode(issue_url)}"
      executorIds = get_assigned_to(issue.assigned_to)

      data = {
        "subject" => "#{issue.tracker} ##{issue.id}: #{issue.subject}",
        "description" => issue.description,
        "dueTime" => (issue.due_date ? issue.due_date.to_time.to_i * 1000 : nil),
        "executorIds" => executorIds,
        "participantIds" => participantIds,
      }

      if issue.dingtalk_task_id.present?
        data.merge!({
          "done" =>  issue.status.is_closed,
        })
        task_post_url = "https://api.dingtalk.com/v1.0/todo/users/#{operatorId}/tasks/#{issue.dingtalk_task_id}?operatorId=#{operatorId}"
      else
        data.merge!({
          "sourceId" => issue.id,
          "creatorId" => operatorId,
          "detailUrl" => {
              "appUrl" => issue_app_url,
              "pcUrl" => issue_pc_url,
            },
          "priority" =>(issue.priority_id>4 ? 40 : issue.priority_id * 10),
        })
        task_post_url = "https://api.dingtalk.com/v1.0/todo/users/#{operatorId}/tasks?operatorId=#{operatorId}"
      end

      url = URI.parse(task_post_url)  
      http = Net::HTTP.new(url.host,url.port)
      http.use_ssl = true
      if issue.dingtalk_task_id.present?
        req = Net::HTTP::Put.new(
          url.request_uri, 
          'Content-Type' => 'application/json',
          'x-acs-dingtalk-access-token' => token
          )
      else
        req = Net::HTTP::Post.new(
            url.request_uri, 
            'Content-Type' => 'application/json',
            'x-acs-dingtalk-access-token' => token
            )
      end
      req.body = data.to_json
      res = http.request(req)
      if issue.dingtalk_task_id.blank?
        res_josn = JSON.parse(res.body)
        # 获得id
        dingtalk_task_id = res_josn["id"]
        if !dingtalk_task_id.blank?
          Issue.where(id: issue.id).update_all(dingtalk_task_id: dingtalk_task_id)
        end
      end
      
      if notified_ids.present?
        msg_content = issue.description
        msg_author = "#{issue.author}"
        if issue.dingtalk_task_id.present?
          msg_content = issue.journals.last.notes
          msg_author = "#{issue.journals.last.user}"
        end
        data = {
          "agent_id" => agent_id,
          "userid_list" => notified_ids,
          "msg" => {
          "msgtype" => "oa",
          "oa" => {
            "message_url" => issue_app_url,
            "pc_message_url" => issue_pc_url,
            "head" => {
            "bgcolor" => "FFBBBBBB",
                   "text" => issue_title,
            },
            "body" => {
            "title" => "#{issue.tracker} ##{issue.id}: #{issue.subject}",
            "content" => msg_content,
            "form"=>[
              {"key":"创建者：","value": "#{issue.author}"},
              {"key":"状态：","value": "#{issue.status}"},
              {"key":"指派给：","value": "#{issue.assigned_to ? "#{issue.assigned_to}" : "-"}"},
            ],
            "author" => msg_author,
            },
          }
          }
        }.to_json
        url = URI.parse("https://oapi.dingtalk.com/topapi/message/corpconversation/asyncsend_v2?access_token=#{token}")  
        http = Net::HTTP.new(url.host,url.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(url.request_uri, 'Content-Type' => 'application/json')
        req.body = data
        res = http.request(req)
      end
    rescue
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