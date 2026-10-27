# frozen_string_literal: true

module RedmineWorkspace
  # Remembers the issues a user opened last, in their preferences.
  module RecentIssues
    PREF_KEY = :workspace_recent_issue_ids
    LIMIT = 10

    def self.track(user, issue)
      return unless user.logged? && issue&.id

      ids = ids(user)
      ids.delete(issue.id)
      ids.unshift(issue.id)
      value = ids.first(LIMIT).join(',')
      return if user.pref[PREF_KEY] == value

      user.pref[PREF_KEY] = value
      user.pref.save
    end

    def self.ids(user)
      user.pref[PREF_KEY].to_s.split(',').map(&:to_i).reject(&:zero?)
    end

    def self.issues(user, limit: LIMIT)
      ids = ids(user).first(limit)
      by_id = Issue.visible(user).where(id: ids).includes(:project, :status, :tracker).index_by(&:id)
      ids.filter_map {|id| by_id[id]}
    end
  end
end
