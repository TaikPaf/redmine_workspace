# frozen_string_literal: true

module RedmineWorkspace
  # Results for the Ctrl+K command palette.
  class Palette
    ISSUE_LIMIT = 6
    PROJECT_LIMIT = 5

    attr_reader :user, :project, :view, :issue

    def initialize(user, project:, view:, issue: nil)
      @user = user
      @project = project
      @view = view
      @issue = issue
    end

    def results(text)
      text = text.to_s.strip
      sections =
        if text.empty?
          [
            section(:label_workspace_palette_this_issue, issue_actions),
            section(:label_workspace_palette_recent, recent_items),
            section(:label_workspace_palette_actions, actions)
          ]
        elsif text.start_with?('>')
          needle = text[1..].to_s.strip
          [
            section(:label_workspace_palette_this_issue, filter_items(issue_actions, needle)),
            section(:label_workspace_palette_actions, filter_actions(needle))
          ]
        else
          [
            section(:label_workspace_palette_this_issue, filter_items(issue_actions, text)),
            section(:label_issue_plural, issue_items(text)),
            section(:label_project_plural, project_items(text)),
            section(:label_workspace_palette_actions, filter_actions(text)),
            section(:label_search, [search_item(text)])
          ]
        end
      {sections: sections.reject {|s| s[:items].empty?}}
    end

    private

    def section(title, items)
      {title: ::I18n.t(title), items: items}
    end

    def issue_items(text)
      found = []
      if (m = text.match(/\A#?(\d+)\z/)) && (issue = Issue.visible(user).find_by(id: m[1].to_i))
        found << issue
      end
      pattern = "%#{Issue.sanitize_sql_like(text.downcase)}%"
      found += Issue.visible(user).joins(:status).
        where("LOWER(#{Issue.table_name}.subject) LIKE ?", pattern).
        where.not(id: found.map(&:id)).
        includes(:project, :status, :tracker, :priority, :assigned_to).
        reorder(Arel.sql("#{IssueStatus.table_name}.is_closed ASC, #{Issue.table_name}.updated_on DESC")).
        limit(ISSUE_LIMIT).to_a
      found.first(ISSUE_LIMIT).map {|issue| issue_item(issue)}
    end

    def issue_item(issue)
      {
        kind: 'issue', badge: issue.id.to_s, label: "##{issue.id} #{issue.subject}",
        hint: "#{issue.project} · #{issue.status}", url: view.issue_path(issue),
        preview: issue_preview(issue)
      }
    end

    # Shown next to the results when the issue is selected.
    def issue_preview(issue)
      rows = [
        [::I18n.t(:field_status), issue.status.to_s],
        [::I18n.t(:field_priority), issue.priority.to_s],
        [::I18n.t(:field_assigned_to), issue.assigned_to&.name || '—'],
        [::I18n.t(:field_due_date), issue.due_date ? ::I18n.l(issue.due_date) : '—'],
        [::I18n.t(:field_updated_on), ::I18n.t(:label_workspace_ago, time: view.distance_of_time_in_words(Time.now, issue.updated_on))]
      ]
      {
        title: issue.subject,
        context: "#{issue.project} · #{issue.tracker} ##{issue.id}",
        status_category: StatusCategories.category_for(issue.status),
        rows: rows,
        excerpt: issue.description.to_s.gsub(/\s+/, ' ').strip.truncate(280)
      }
    end

    def project_items(text)
      pattern = "%#{Project.sanitize_sql_like(text.downcase)}%"
      Project.visible(user).
        where("LOWER(#{Project.table_name}.name) LIKE :p OR LOWER(#{Project.table_name}.identifier) LIKE :p", p: pattern).
        sorted.limit(PROJECT_LIMIT).map {|p| project_item(p)}
    end

    def project_item(project)
      {
        kind: 'project', badge: project.name[0].to_s.upcase, color: ProjectsOverview.color_for(project),
        label: project.name, hint: project.identifier, url: view.project_path(project)
      }
    end

    def recent_items
      issues = RecentIssues.issues(user, limit: 5).map {|issue| issue_item(issue)}
      projects = Redmine::ProjectJumpBox.new(user).recently_used_projects.first(3).map {|p| project_item(p)}
      issues + projects
    end

    def search_item(text)
      {
        kind: 'search', badge: '?', label: ::I18n.t(:label_workspace_palette_search, text: text),
        hint: ::I18n.t(:label_workspace_palette_search_hint),
        url: view.workspace_search_path(q: text, project_id: project&.id)
      }
    end

    def filter_actions(text)
      filter_items(actions, text)
    end

    def filter_items(items, text)
      needle = normalize(text)
      items.select {|a| needle.empty? || normalize(a[:label]).include?(needle)}
    end

    # Status changes and "assign to me" for the issue being viewed, within what the workflow allows.
    def issue_actions
      @issue_actions ||= begin
        fields = issue ? InlineFields.new(issue, user).fields : {}
        url = issue && view.workspace_issue_inline_path(issue)
        list = []
        if (status = fields['status'])
          status[:options].each do |name, id|
            next if id == issue.status_id.to_s

            list << issue_action('→', ::I18n.t(:label_workspace_palette_move_to, status: name), url, 'status_id', id)
          end
        end
        assignee = fields['assigned-to']
        if assignee && issue.assigned_to_id != user.id && assignee[:options].any? {|_, id| id == user.id.to_s}
          list << issue_action('@', ::I18n.t(:label_workspace_palette_assign_me), url, 'assigned_to_id', user.id.to_s)
        end
        list
      end
    end

    def issue_action(badge, label, url, attribute, value)
      {kind: 'issue-action', badge: badge, label: label, hint: "##{issue.id}", endpoint: url,
       js: 'issue-update', attribute: attribute, value: value}
    end

    def actions
      @actions ||= begin
        list = []
        if user.allowed_to?(:add_issues, project, global: project.nil?)
          url = project ? view.new_project_issue_path(project) : view.new_issue_path
          list << action('+', :label_issue_new, url)
        end
        list << action('E', :label_workspace, view.workspace_path)
        list << action('P', :label_workspace_projects, view.workspace_projects_path)
        list << action('!', :label_workspace_view_my_overdue, view.workspace_search_path(q: 'moi retard', project_id: project&.id))
        if view.respond_to?(:kanban_path) && user.allowed_to?(:view_kanban, project, global: project.nil?)
          url = project ? view.project_kanban_path(project) : view.kanban_path
          list << action('K', :label_kanban, url)
        end
        if user.allowed_to?(:log_time, project, global: project.nil?)
          url = project ? view.new_project_time_entry_path(project) : view.new_time_entry_path
          list << action('T', :button_log_time, url)
        end
        list << action('C', :label_my_account, view.my_account_path)
        list << {kind: 'action', badge: '◐', label: ::I18n.t(:label_workspace_toggle_theme), hint: '', js: 'toggle-theme'}
        list
      end
    end

    def action(badge, label, url)
      {kind: 'action', badge: badge, label: ::I18n.t(label), hint: '', url: url}
    end

    def normalize(text)
      I18n.transliterate(text.to_s.downcase, replacement: '')
    end
  end
end
