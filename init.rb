Redmine::Plugin.register :redmine_dingtalk do
  name 'Redmine Dingtalk plugin'
  author 'Andy'
  description '钉钉登陆、待办、工作通知'
  version '1.0.2'
  url 'https://github.com/fanziwy/redmine_dingtalk'
  author_url 'https://github.com/fanziwy'
  
  permission :dingtalk, { :dingtalk => [:new] }, :public => true
  menu :admin_menu, :dingtalk, {:controller => 'settings', :action => 'plugin', :id => "redmine_dingtalk"},:caption => :menu_dingtalk
  settings :default => {}, :partial => 'settings/dingtalk'

end
require File.expand_path('../lib/redmine_dingtalk', __FILE__)
