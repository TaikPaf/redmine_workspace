# frozen_string_literal: true

module RedmineWorkspace
  # Data for the personal "Mon espace" page.
  class MySpace
    TABS = %w(assigned created watched).freeze
    BUCKETS = %w(overdue week later none).freeze
    LIST_LIMIT = 50
    READ_PREF = :workspace_read_at
    READ_ALL_PREF = :workspace_read_all_at
    INBOX_WINDOW = 30.days
    INBOX_LIMIT = 40
    READ_KEEP = 300

    # One issue in the activity inbox, with the changes made by others.
    InboxEntry = Struct.new(:issue, :journals, :unread, keyword_init: true) do
      def latest
        journals.first
      end

      def unread?
        unread > 0
      end
    end

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

    # Changes made by others on my issues over the last 30 days, grouped by issue, latest first.
    def inbox
      @inbox ||= begin
        issue_ids = assigned_scope.pluck(:id) | created_scope.pluck(:id) | watched_scope.pluck(:id)
        journals = issue_ids.empty? ? [] : others_journals(issue_ids, INBOX_WINDOW.ago).
          includes(:user, :details, issue: [:project, :tracker, :status]).
          reorder("#{Journal.table_name}.created_on DESC").limit(400).to_a
        journals.group_by(&:journalized_id).first(INBOX_LIMIT).map do |issue_id, list|
          cutoff = read_cutoff(issue_id)
          InboxEntry.new(issue: list.first.issue, journals: list, unread: list.count {|j| j.created_on > cutoff})
        end
      end
    end

    def unread_count
      inbox.count(&:unread?)
    end

    def mark_read!(issue, now = Time.current)
      return unless issue&.id
      return unless others_journals([issue.id], read_cutoff(issue.id)).exists?

      read = read_map.merge(issue.id.to_s => now.iso8601)
      user.pref[READ_PREF] = read.sort_by {|_, time| time}.last(READ_KEEP).to_h
      user.pref.save
      @inbox = nil
    end

    def mark_all_read!(now = Time.current)
      user.pref[READ_ALL_PREF] = now.iso8601
      user.pref[READ_PREF] = {}
      user.pref.save
      @inbox = nil
    end

    def read_cutoff(issue_id)
      [INBOX_WINDOW.ago, parse_time(user.pref[READ_ALL_PREF]), parse_time(read_map[issue_id.to_s])].compact.max
    end

    private

    def read_map
      value = user.pref[READ_PREF]
      value.is_a?(Hash) ? value.transform_keys(&:to_s) : {}
    end

    def others_journals(issue_ids, after)
      Journal.visible(user).
        where(journalized_type: 'Issue', journalized_id: issue_ids).
        where("#{Journal.table_name}.created_on > ?", after).
        where.not(user_id: user.id)
    end

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
