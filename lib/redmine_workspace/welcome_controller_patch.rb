# frozen_string_literal: true

module RedmineWorkspace
  module WelcomeControllerPatch
    def self.included(base)
      base.before_action :workspace_redirect_home, only: :index
    end

    private

    def workspace_redirect_home
      return unless User.current.logged? && Setting.plugin_redmine_workspace['home_redirect'] == '1'

      redirect_to workspace_path
    end
  end
end
