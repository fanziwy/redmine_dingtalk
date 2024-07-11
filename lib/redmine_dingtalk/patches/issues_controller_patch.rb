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
        def create_with_corp_wechat
            create_without_corp_wechat
            send_by_dingtalk(@issue)
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
end
unless IssuesController.included_modules.include?(RedmineDingtalk::Patches::IssuesControllerPatch)
  IssuesController.send(:include, RedmineDingtalk::Patches::IssuesControllerPatch)
end