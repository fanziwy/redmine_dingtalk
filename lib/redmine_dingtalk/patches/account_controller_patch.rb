module RedmineDingtalk
  module Patches
    module AccountControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
          # defind a globle var for backurl
          # 适配4.0 
          alias_method :login_without_login_dingtalk, :login
          alias_method :login, :login_with_login_dingtalk
          alias_method :successful_authentication_without_login_dingtalk, :successful_authentication
          alias_method :successful_authentication, :successful_authentication_with_login_dingtalk
          alias_method :register_without_login_dingtalk, :register
          alias_method :register, :register_with_login_dingtalk
        end
      end

      def empty_dingtalk
        session.delete(:dingtalk_union_id)
        session.delete(:dingtalk_user_id)
      end
    
      module InstanceMethods
        include DingtalkMethods
        def login_with_login_dingtalk
          auth_code = params[:authCode]
          if !auth_code.blank?
            state = params[:state]
            # 如果是钉钉登录回调
            if state == "DingTalkSTATE"
              appid = Setting["plugin_redmine_dingtalk"]["dingtalk_appid"]
              appsecret = Setting["plugin_redmine_dingtalk"]["dingtalk_appsecret"]
              redirect_url = Setting["plugin_redmine_dingtalk"]["dingtalk_redirect"]
              
              dingtalk_union_id = nil

              if (appid.blank? || appsecret.blank? || redirect_url.blank?)
                return
              end
              begin
                empty_dingtalk
                token_uri = URI.parse("https://api.dingtalk.com/v1.0/oauth2/userAccessToken")
                http = Net::HTTP.new(token_uri.host,token_uri.port)
                http.use_ssl = true

                data = {
                  "clientId" => "#{appid}",
                  "clientSecret" => "#{appsecret}",
                  "code" => "#{auth_code}",
                  "grantType" => "authorization_code"
                }.to_json

                request_token = Net::HTTP::Post.new(token_uri)
                request_token['Content-Type'] = 'application/json'
                request_token.body = data
                response = http.request(request_token)
              
                # 获得accessToken
                response_json = JSON.parse(response.body)
                access_token = response_json["accessToken"]
                if(access_token.blank?)
                  empty_dingtalk
                  return
                end

                response = Net::HTTP::Get.new(
                  "https://api.dingtalk.com/v1.0/contact/users/me",
                  'Content-Type' => 'application/json',
                  'x-acs-dingtalk-access-token' => access_token
                )
            
                response = http.request(response)
                response_json = JSON.parse(response.body)
                
                # 获得用户id
                dingtalk_union_id = response_json["unionId"]
                session[:dingtalk_union_id] = dingtalk_union_id
            
                # 获得token
                token = get_token
                data = {
                  "unionid" => "#{dingtalk_union_id}"
                }.to_json

                request_token = Net::HTTP::Post.new("https://oapi.dingtalk.com/topapi/user/getbyunionid?access_token=#{token}", 'Content-Type' => 'application/json')
                request_token.body = data
                response = http.request(request_token)
                response_json = JSON.parse(response.body)
                session[:dingtalk_user_id] = response_json['result']["userid"]
            
                rescue
                  empty_dingtalk
                  flash[:notice] = l(:flash_dingtalk_bind)
                  return
                end
                user = User.find_by dingtalk_union_id: dingtalk_union_id unless dingtalk_union_id.blank?
                unless user.blank?
                  if user.active?
                    user.update_last_login_on!
                    successful_authentication(user)
                  else
                    handle_inactive_user(user)
                  end
                  empty_dingtalk
                else
                  unless dingtalk_union_id.blank?
                    flash[:notice] = l(:flash_dingtalk_bind)
                  end
                end
              return
            else  # 处理钉钉免登
              dingtalk_union_id = session[:dingtalk_union_id]
              if (!dingtalk_union_id.blank?)
                flash[:notice] = l(:flash_dingtalk_bind)
                return
              end
              appid = Setting["plugin_redmine_dingtalk"]["dingtalk_appid"]
              if (appid.blank?)
                flash[:error] = l(:flash_dingtalk_autologin_error)
                redirect_to home_url
                return
              end
              
              dingtalk_union_id = nil

              begin
                # 获得token
                token = get_token
                data = {
                  "code" => "#{auth_code}"
                }.to_json

                token_uri = URI.parse("https://oapi.dingtalk.com/topapi/v2/user/getuserinfo?access_token=#{token}")
                http = Net::HTTP.new(token_uri.host,token_uri.port)
                http.use_ssl = true

                request_token = Net::HTTP::Post.new(token_uri)
                request_token['Content-Type'] = 'application/json'
                request_token.body = data
                response = http.request(request_token)
                response_json = JSON.parse(response.body)
                err_code = response_json["errcode"]

                if err_code != 0
                  flash[:error] = l(:flash_dingtalk_autologin_error)
                  return
                end
                dingtalk_data = response_json["result"]
                dingtalk_union_id = dingtalk_data["unionid"]
                session[:dingtalk_union_id] = dingtalk_union_id
                session[:dingtalk_user_id] = dingtalk_data["userid"]
                
              rescue
                flash[:error] = l(:flash_dingtalk_autologin_error)
                redirect_to home_url
                return
              end
              user = User.find_by dingtalk_union_id: dingtalk_union_id unless dingtalk_union_id.blank?
              unless user.blank?
                if user.active?
                  user.update_last_login_on!
                  successful_authentication(user)
                else
                  handle_inactive_user(user)
                end
                empty_dingtalk
              else
                flash[:error] = l(:flash_dingtalk_autologin_error)
                redirect_to home_url
              end
            return
          end
        end
        login_without_login_dingtalk
      end
    end
      
      def successful_authentication_with_login_dingtalk(user)
        dingtalk_union_id = session[:dingtalk_union_id]
        if !dingtalk_union_id.blank? and user.dingtalk_union_id.blank?
          dingtalk_user_id = session[:dingtalk_user_id]
          # 更新当前的dingtalk_union_id
          user.update(dingtalk_union_id: dingtalk_union_id,dingtalk_user_id: dingtalk_user_id)
          empty_dingtalk
        end
        successful_authentication_without_login_dingtalk user
      end

      def register_with_login_dingtalk()
        dingtalk_union_id = session[:dingtalk_union_id]
        dingtalk_user_id = session[:dingtalk_user_id]
        if register_without_login_dingtalk
          if request.post?
            if @user.save
              # 更新当前的dingtalk_union_id
              @user.update(dingtalk_union_id: dingtalk_union_id,dingtalk_user_id: dingtalk_user_id)
              empty_dingtalk
            end
          end
        end
      end
    end
  end
end

unless AccountController.included_modules.include?(RedmineDingtalk::Patches::AccountControllerPatch)
  AccountController.send(:include, RedmineDingtalk::Patches::AccountControllerPatch)
end