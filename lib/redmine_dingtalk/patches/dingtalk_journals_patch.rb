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

		  def send_messages_after_create_journal
			send_by_dingtalk(journalized)
		  end
		end
	end
end
unless Journal.included_modules.include?(RedmineDingtalk::Patches::DingtalkJournalsPatch)
  Journal.send(:include, RedmineDingtalk::Patches::DingtalkJournalsPatch)
end
