module RedmineDingtalk
  module Patches
    module IssuesControllerPatch
     def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable
          #alias_method_chain :build_new_issue_from_params, :qy_wechat
          # 兼容4.0
          alias_method :create_without_corp_wechat, :create
          alias_method :create, :create_with_corp_wechat
          alias_method :destroy_without_corp_wechat, :destroy
          alias_method :destroy, :destroy_with_corp_wechat
        end
     end
     
     module InstanceMethods
      include DingtalkMethods
      # 用钉钉发送 
      def send_by_dingtalk
        agent_id = Setting["plugin_redmine_dingtalk"]["dingtalk_agentid"]
        if agent_id.blank?
          return
        end
        begin
          author_dingid = @issue.author.dingtalk_union_id
          if author_dingid.blank?
            return
          end
          to_users = @issue.notified_users
          cc_users = @issue.notified_watchers - to_users
          notify_users = to_users + cc_users

          
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

          token = get_token
          if token.blank?
            return
          end
          issue_title = "#{@issue.project.name}"
          issue_url =  Setting.protocol + "://" + Setting.host_name + "/issues/#{@issue.id}"
          issue_app_url = "dingtalk://dingtalkclient/page/link?url=#{Addressable::URI.encode(issue_url)}&pc_slide=true"
          executorIds = get_assigned_to(@issue.assigned_to)
          data = {
            "sourceId" => @issue.id,
            "subject" => "#{@issue.tracker} ##{@issue.id}: #{@issue.subject}",
            "creatorId" => author_dingid,
            "description" => @issue.description,
            "dueTime" => (@issue.due_date ? @issue.due_date.to_time.to_i * 1000 : nil),
            "executorIds" => executorIds,
            "participantIds" => participantIds,
            "detailUrl" => {
              "appUrl" => issue_app_url,
              "pcUrl" => issue_app_url,
            },
            # "isOnlyShowExecutor" => true,
            "priority" =>(@issue.priority_id>4 ? 40 : @issue.priority_id * 10),
          }.to_json
          url = URI.parse("https://api.dingtalk.com/v1.0/todo/users/#{author_dingid}/tasks?operatorId=#{author_dingid}")  
          http = Net::HTTP.new(url.host,url.port)
          http.use_ssl = true
          req = Net::HTTP::Post.new(
            url.request_uri, 
            'Content-Type' => 'application/json',
            'x-acs-dingtalk-access-token' => token
            )
          req.body = data
          res = http.request(req)
          res_josn = JSON.parse(res.body)
          # 获得id
          dingtalk_task_id = res_josn["id"]
          if !dingtalk_task_id.blank?
            Issue.where(id: @issue.id).update_all(dingtalk_task_id: dingtalk_task_id)
          end
          if notified_ids.present?
            data = {
              "agent_id" => agent_id,
              "userid_list" => notified_ids,
              "msg" => {
              "msgtype" => "oa",
              "oa" => {
                  "message_url" => issue_app_url,
                  "pc_message_url" => issue_app_url,
                  "head" => {
                  "bgcolor" => "FFBBBBBB",
                        "text" => issue_title,
                  },
                  "body" => {
                  "title" => "#{@issue.tracker} ##{@issue.id}: #{@issue.subject}",
                  "content" => @issue.description,
                  "form"=>[
                    {"key":"创建者：","value": "#{@issue.author}"},
                    {"key":"状态：","value": "#{@issue.status}"},
                    {"key":"指派给：","value": "#{@issue.assigned_to ? "#{@issue.assigned_to}" : "-"}"},
                  ],
                  "author" => "#{@issue.author}",
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
       
      def create_with_corp_wechat
          create_without_corp_wechat
          send_by_dingtalk
        end
      end

      def destroy_with_corp_wechat
        destroy_without_corp_wechat
        begin
          @issues.each do |issue|
            if issue.respond_to?(:dingtalk_task_id) && issue.dingtalk_task_id.present?
              author_dingid = issue.author.dingtalk_union_id
              if author_dingid.blank?
                return
              end
              token = get_token
              if token.blank?
                return
              end
              url = URI.parse("https://api.dingtalk.com/v1.0/todo/users/#{author_dingid}/tasks/#{issue.dingtalk_task_id}?operatorId=#{author_dingid}")  
              http = Net::HTTP.new(url.host,url.port)
              http.use_ssl = true
              req = Net::HTTP::Delete.new(
                url.request_uri, 
                'Content-Type' => 'application/json',
                'x-acs-dingtalk-access-token' => token
                )
              res = http.request(req)
            end
          end
        rescue
        end
      end
    end
  end
end
unless IssuesController.included_modules.include?(RedmineDingtalk::Patches::IssuesControllerPatch)
  IssuesController.send(:include, RedmineDingtalk::Patches::IssuesControllerPatch)
end