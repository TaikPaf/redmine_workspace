# frozen_string_literal: true

module WorkspaceHelper
  STATUS_TONES = %w(blue amber green purple teal pink).freeze

  def workspace_status_tag(status)
    tone = status.is_closed? ? 'gray' : STATUS_TONES[status.position.to_i % STATUS_TONES.size]
    content_tag(:span, status.name, class: "gf-pill gf-tone-#{tone}")
  end

  def workspace_priority_tag(priority)
    return '' unless priority

    content_tag(:span, class: "gf-priority #{priority.css_classes}") do
      content_tag(:span, '', class: 'gf-dot', 'aria-hidden': 'true') + priority.name
    end
  end

  def workspace_due_tag(issue, today = User.current.today)
    return content_tag(:span, '—', class: 'gf-due gf-muted') unless issue.due_date

    css = issue.due_date < today && !issue.closed? ? 'gf-due gf-overdue' : 'gf-due'
    content_tag(:span, format_date(issue.due_date), class: css, title: l(:field_due_date))
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
