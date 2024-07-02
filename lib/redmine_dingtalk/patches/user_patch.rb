module RedmineDingtalk
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          safe_attributes 'dingtalk_union_id'
          safe_attributes 'dingtalk_user_id'
        end
      end
    end
  end
end
unless User.included_modules.include?(RedmineDingtalk::Patches::UserPatch)
  User.send(:include, RedmineDingtalk::Patches::UserPatch)
end