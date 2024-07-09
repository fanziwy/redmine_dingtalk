module RedmineDingtalk
	module Patches
		module DingtalkJournalsPatch
		  extend ActiveSupport::Concern
		  # 当创建journal时发送消息
		  require 'net/http'
		  require 'net/https'
		  
		  included do
			after_commit :send_messages_after_create_journal
		  end
		  include DingtalkMethods

		  def extract_mentions(issue)
			description = issue.description || ''
			notes = issue.notes || ''
			text = "#{description} #{notes}"
			# 正则表达式匹配提及的用户名
			mentions = text.scan(/@(\w+)/).flatten
			# 根据用户名查找用户
			User.where(:login => mentions).to_a
		  end

		  # 用钉钉发送 
		  def send_by_dingtalk
			agent_id = Setting["plugin_redmine_dingtalk"]["dingtalk_agentid"]
			if agent_id.blank?
			  return
			end
			begin
				operatorId = @issue.journals.last.user.dingtalk_union_id
				if operatorId.blank?
					operatorId = @issue.author.dingtalk_union_id
					if operatorId.blank?
						return
					end
				end

				to_users = @issue.notified_users
				cc_users = @issue.notified_watchers - to_users
				mi_users = extract_mentions(@issue) - to_users - cc_users
				notify_users = to_users + cc_users + mi_users

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
				issue_title = @issue.project.name
				issue_url =  Setting.protocol + "://" + Setting.host_name + "/issues/#{@issue.id}"
				issue_app_url = "dingtalk://dingtalkclient/page/link?url=#{Addressable::URI.encode(issue_url)}&pc_slide=true"
				executorIds = get_assigned_to(@issue.assigned_to)
				data = {
					"subject" => "#{@issue.tracker} ##{@issue.id}: #{@issue.subject}",
					"description" => @issue.description,
					"dueTime" => (@issue.due_date ? @issue.due_date.to_time.to_i * 1000 : nil),
					"done" =>  @issue.status.is_closed,
					"executorIds" => executorIds,
					"participantIds" => participantIds,
				}.to_json

				url = URI.parse("https://api.dingtalk.com/v1.0/todo/users/#{operatorId}/tasks/#{@issue.dingtalk_task_id}?operatorId=#{operatorId}")  
				http = Net::HTTP.new(url.host,url.port)
				http.use_ssl = true
				req = Net::HTTP::Put.new(
					url.request_uri, 
					'Content-Type' => 'application/json',
					'x-acs-dingtalk-access-token' => token
					)
				req.body = data
				res = http.request(req)
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
							"content" => @issue.journals.last.notes,
							"form"=>[
								{"key":"创建者：","value": "#{@issue.author}"},
								{"key":"状态：","value": "#{@issue.status}"},
								{"key":"指派给：","value": "#{@issue.assigned_to ? "#{@issue.assigned_to}" : "-"}"},
							],
							"author" => "#{@issue.journals.last.user}",
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

		  def send_messages_after_create_journal
			@issue = journalized
			send_by_dingtalk
		  end
		end
	end
end
unless Journal.included_modules.include?(RedmineDingtalk::Patches::DingtalkJournalsPatch)
  Journal.send(:include, RedmineDingtalk::Patches::DingtalkJournalsPatch)
end
