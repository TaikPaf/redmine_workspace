# frozen_string_literal: true

Redmine::Plugin.register :redmine_workspace do
  name 'Redmine Workspace'
  author 'TaikPaf'
  description 'Personal workspace, project overview, quick views, plain-language search and command palette.'
  version '1.0.0'
  url 'https://github.com/TaikPaf/redmine_workspace'
  requires_redmine version_or_higher: '7.0.0'

  settings default: {'home_redirect' => '1'}, partial: 'settings/workspace_settings'

  menu :top_menu, :workspace, {controller: 'workspace', action: 'index'},
       caption: :label_workspace, first: true, if: proc { User.current.logged? }
end

RedmineWorkspace::Hooks
IssuesController.include(RedmineWorkspace::IssuesControllerPatch) unless IssuesController < RedmineWorkspace::IssuesControllerPatch
WelcomeController.include(RedmineWorkspace::WelcomeControllerPatch) unless WelcomeController < RedmineWorkspace::WelcomeControllerPatch
