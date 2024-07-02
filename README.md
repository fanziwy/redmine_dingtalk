# Redmine DingTalk Plugin

## 核心特性
- **集成登录**：无缝对接钉钉账号登录支持钉钉内免登和钉钉扫码登录。
- **待办同步**：自动同步Redmine任务至钉钉待办事项。
- **即时通知**：实时推送工作通知至钉钉。


## 安装与配置指南
### 1: 插件部署

将插件文件解压缩到 Redmine 的 `plugins` 目录下。
   

### 2: 数据迁移

执行命令以完成数据库迁移：
   ```shell
   RAILS_ENV=production bundle exec rake redmine:plugins:migrate
   ```


### 3. 钉钉应用配置

- **注册应用**：
  访问[钉钉开发者平台](https://open.dingtalk.com)，按照指引注册一个新的钉钉应用。
  
- **配置信息**：
  在Redmine系统中，导航至插件的设置页面。根据页面上的具体提示填写应用及企业信息。


### 4: 配置钉钉应用权限

为确保功能完整，请分配以下权限给钉钉应用：

| 权限信息                               | 权限点code        |
| -------------------------------------- | ----------------- |
| 通讯录个人信息读权限                   | Contact.User.Read |
| 调用SNS API时需要具备的基本权限        | snsapi_base       |
| 成员信息读权限                         | qyapi_get_member  |
| 调用企业API基础权限                    | qyapi_base        |
| 获取钉钉开放接口用户访问凭证的基础权限 | open_app_api_base |
| 待办应用中待办写权限                   | Todo.Todo.Write   |
| 待办应用中待办读权限                   | Todo.Todo.Read    |


### 5: 重启服务

完成上述步骤后，重启 Redmine 服务以使更改生效。


### 注意事项

- 确保在配置钉钉应用时，正确设置回调URL和令牌，以保证与Redmine的无缝集成。