module RedmineDingtalk
  module Hooks
      class ViewsUsersHook < Redmine::Hook::ViewListener
          # 用户添加钉钉信息
          def view_users_form(context={})
            dingtalk_account_number_options(context)
          end
          # 个人账户添加钉钉信息
          def view_my_account(context={})
            dingtalk_account_number_options(context)
          end
          # 人员管理添加钉钉信息
          def view_people_form(context={})
            dingtalk_account_number_options(context)
          end
          def dingtalk_account_number_options(context)
            user  = context[:user]
            f     = context[:form]
            s     = ''
            
            if user && User.current.admin?
                s << "<p>"
                s << label_tag( "user_dingtalk_union_id", l(:user_dingtalk_union_id))
                if user && user.dingtalk_union_id
                  s << text_field_tag( 'user[dingtalk_union_id]',user.dingtalk_union_id)
                else
                  s << text_field_tag( 'user[dingtalk_union_id]',nil)
                end
                s << "</p>"

                s << "<p>"
                s << label_tag( "user_dingtalk_user_id", l(:user_dingtalk_user_id))
                if user && user.dingtalk_user_id
                    s << text_field_tag( 'user[dingtalk_user_id]',user.dingtalk_user_id)
                else
                    s << text_field_tag( 'user[dingtalk_user_id]',nil)
                end
                s << "</p>"
            end
            
            return s.html_safe
          end
          
      end
  end
end