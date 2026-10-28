# frozen_string_literal: true

module WorkspaceHelper
  def workspace_status_tag(status)
    RedmineWorkspace::Icons.status(status)
  end

  def workspace_priority_tag(priority, label: true)
    RedmineWorkspace::Icons.priority(priority, label: label)
  end

  # Short relative due date: "-3 j" when late, the weekday within the week, a short date beyond.
  def workspace_due_tag(issue, today = User.current.today)
    due = issue.due_date
    return content_tag(:span, '', class: 'gf-due') unless due

    title = "#{l(:field_due_date)} : #{format_date(due)}"
    if due < today && !issue.closed?
      content_tag(:span, l(:label_workspace_due_late, count: (today - due).to_i), class: 'gf-due gf-overdue', title: title)
    elsif due == today
      content_tag(:span, l(:label_workspace_due_today), class: 'gf-due gf-due-soon', title: title)
    elsif due <= today.end_of_week
      content_tag(:span, ::I18n.t('date.abbr_day_names')[due.wday], class: 'gf-due gf-due-soon', title: title)
    else
      content_tag(:span, ::I18n.l(due, format: :short), class: 'gf-due', title: title)
    end
  end

  def workspace_project_dot(project)
    content_tag(:span, '', class: 'gf-appnav-dot', 'aria-hidden': 'true',
                style: "background: #{RedmineWorkspace::ProjectsOverview.color_for(project)}")
  end

  def workspace_bucket_label(bucket)
    l("label_workspace_bucket_#{bucket}")
  end

  def workspace_search_link(text, label, project: nil, **options)
    link_to label, workspace_search_path(q: text, project_id: project&.id), **options
  end

  def workspace_project_badge(project, size: 40)
    content_tag(:span, project.name[0].to_s.upcase, class: 'gf-project-badge', 'aria-hidden': 'true',
                style: "background: #{RedmineWorkspace::ProjectsOverview.color_for(project)}; --gf-badge-size: #{size}px")
  end

  def workspace_greeting(user)
    hour = Time.now.in_time_zone(user.time_zone || Time.zone).hour
    key = hour < 18 ? :label_workspace_hello : :label_workspace_good_evening
    l(key, name: user.firstname.presence || user.name)
  end

  def workspace_journal_summary(journal)
    issue_label = "##{journal.issue.id} #{journal.issue.subject}"
    if journal.notes.present?
      l(:text_workspace_journal_comment, user: journal.user, issue: issue_label)
    else
      detail = journal.visible_details.first
      change = detail ? show_detail(detail, true) : l(:label_updated_time, '')
      l(:text_workspace_journal_change, user: journal.user, issue: issue_label, change: change)
    end
  end
end
