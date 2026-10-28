# frozen_string_literal: true

module RedmineWorkspace
  # Groups Redmine statuses into a few categories that share one icon and color everywhere.
  module StatusCategories
    CATEGORIES = %w(backlog todo progress review done cancelled).freeze

    CLOSED_CANCELLED = /rejet|refus|annul|abandon|doublon|cancel|reject|declin|duplicate|won.?t/i
    OPEN_REVIEW = /revue|review|test|recette|valid|commentaire|feedback|r[ée]solu|resolved|qa/i
    OPEN_PROGRESS = /cours|progress|doing|d[ée]v|wip/i
    OPEN_BACKLOG = /backlog|attente|wait|hold|suspend|later|plus tard/i

    module_function

    def category_for(status)
      return 'todo' unless status

      configured = Setting.plugin_redmine_workspace['status_categories']
      value = configured.is_a?(Hash) ? configured[status.id.to_s] : nil
      CATEGORIES.include?(value) ? value : default_for(status)
    end

    def default_for(status)
      name = status.name.to_s
      return(name.match?(CLOSED_CANCELLED) ? 'cancelled' : 'done') if status.is_closed?
      return 'review' if name.match?(OPEN_REVIEW)
      return 'progress' if name.match?(OPEN_PROGRESS)
      return 'backlog' if name.match?(OPEN_BACKLOG)

      first_open = IssueStatus.where(is_closed: false).sorted.first
      status == first_open ? 'todo' : 'progress'
    end

    def map
      IssueStatus.sorted.to_h {|status| [status.id.to_s, category_for(status)]}
    end
  end
end
