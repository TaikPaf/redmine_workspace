# frozen_string_literal: true

module RedmineWorkspace
  module IssuesControllerPatch
    def self.included(base)
      base.after_action :workspace_track_recent_issue, only: :show
    end

    private

    def workspace_track_recent_issue
      return unless response.successful? && request.format.html?

      RecentIssues.track(User.current, @issue)
      MySpace.new(User.current).mark_read!(@issue)
    end
  end
end
