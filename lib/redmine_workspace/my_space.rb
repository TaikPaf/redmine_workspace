# frozen_string_literal: true

module RedmineWorkspace
  # Data for the personal "Mon espace" page.
  class MySpace
    TABS = %w(assigned created watched).freeze
    BUCKETS = %w(overdue week later none).freeze
    LIST_LIMIT = 50
    VISIT_PREF = :workspace_visit_at
    PREVIOUS_VISIT_PREF = :workspace_previous_visit_at
    # A new "visit" starts after this much inactivity on the page.
    VISIT_GAP = 30.minutes

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def today
      @today ||= user.today
    end

    def assigned_scope
      base.where(assigned_to_id: [user.id] + user.group_ids)
    end

    def created_scope
      base.where(author_id: user.id)
    end

    def watched_scope
      base.joins(:watchers).where(Watcher.table_name => {user_id: user.id})
    end

    def scope_for(tab)
      send("#{tab}_scope")
    end

    def issues(tab)
      scope_for(tab).
        includes(:project, :status, :tracker, :priority, :assigned_to).
        order(Arel.sql("CASE WHEN #{Issue.table_name}.due_date IS NULL THEN 1 ELSE 0 END"),
              "#{Issue.table_name}.due_date ASC", "#{Issue.table_name}.id DESC").
        limit(LIST_LIMIT).to_a
    end

    def tab_counts
      @tab_counts ||= TABS.index_with {|tab| scope_for(tab).count}
    end

    def bucket_for(issue)
      return 'none' if issue.due_date.nil?
      return 'overdue' if issue.due_date < today
      return 'week' if issue.due_date <= today.end_of_week

      'later'
    end

    def grouped(issues)
      groups = issues.group_by {|issue| bucket_for(issue)}
      BUCKETS.filter_map {|bucket| [bucket, groups[bucket]] if groups[bucket]}
    end

    def summary
      @summary ||= begin
        scope = assigned_scope
        {
          'overdue' => scope.where("#{Issue.table_name}.due_date < ?", today).count,
          'week' => scope.where("#{Issue.table_name}.due_date >= ? AND #{Issue.table_name}.due_date <= ?",
                                today, today.end_of_week).count,
          'later' => scope.where("#{Issue.table_name}.due_date > ?", today.end_of_week).count,
          'none' => scope.where(due_date: nil).count
        }
      end
    end

    # Records this visit and returns when the previous one started.
    def register_visit!(now = Time.current)
      last = parse_time(user.pref[VISIT_PREF])
      if last.nil? || now - last > VISIT_GAP
        user.pref[PREVIOUS_VISIT_PREF] = last&.iso8601
        user.pref[VISIT_PREF] = now.iso8601
        user.pref.save
      end
      @since = parse_time(user.pref[PREVIOUS_VISIT_PREF]) || 7.days.ago
    end

    def since
      @since ||= parse_time(user.pref[PREVIOUS_VISIT_PREF]) || 7.days.ago
    end

    def activity(limit: 12)
      issue_ids = assigned_scope.pluck(:id) | created_scope.pluck(:id) | watched_scope.pluck(:id)
      return [] if issue_ids.empty?

      Journal.visible(user).
        where(journalized_type: 'Issue', journalized_id: issue_ids).
        where("#{Journal.table_name}.created_on > ?", since).
        where.not(user_id: user.id).
        includes(:user, :details, issue: [:project, :tracker]).
        reorder("#{Journal.table_name}.created_on DESC").
        limit(limit).to_a
    end

    def recent_issues
      RecentIssues.issues(user, limit: 6)
    end

    def favorite_projects
      @favorite_projects ||= Project.visible(user).where(id: user.bookmarked_project_ids).sorted.to_a
    end

    def favorite_counts
      @favorite_counts ||= assigned_scope.where(project_id: favorite_projects.map(&:id)).group(:project_id).count
    end

    private

    def base
      Issue.visible(user).open
    end

    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
