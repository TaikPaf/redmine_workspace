# frozen_string_literal: true

module RedmineWorkspace
  module IssuesControllerPatch
    def self.included(base)
      base.after_action :workspace_track_recent_issue, only: :show
    end

    private

    def workspace_track_recent_issue
      RecentIssues.track(User.current, @issue) if response.successful? && request.format.html?
    end
  end
end
