# frozen_string_literal: true

# In-place editing of a single issue attribute, and the side preview of an issue.
class WorkspaceIssuesController < ApplicationController
  PEEK_NOTES = 5

  before_action :require_login
  before_action :find_issue

  helper :issues
  helper :journals
  helper :workspace

  def peek
    @notes = @issue.visible_journals_with_index.select {|journal| journal.notes.present?}.last(PEEK_NOTES)
    RedmineWorkspace::RecentIssues.track(User.current, @issue)
    render partial: 'workspace_issues/peek', locals: {issue: @issue, notes: @notes}
  end

  def add_note
    return render_error_json(l(:notice_not_authorized), :forbidden) unless @issue.notes_addable?

    notes = params[:notes].to_s.strip
    return render_error_json(l(:error_workspace_note_blank)) if notes.blank?

    journal = @issue.init_journal(User.current, notes)
    journal.private_notes = params[:private_notes] == '1' if User.current.allowed_to?(:set_notes_private, @project)
    call_hook(:controller_issues_edit_before_save, {params: params, issue: @issue, time_entry: nil, journal: journal})
    return render_error_json(@issue.errors.full_messages.join(', ')) unless @issue.save

    call_hook(:controller_issues_edit_after_save, {params: params, issue: @issue, time_entry: nil, journal: journal})
    render json: {lock_version: @issue.reload.lock_version}
  rescue ActiveRecord::StaleObjectError
    render_error_json(l(:notice_issue_update_conflict), :conflict)
  end

  def fields
    inline = RedmineWorkspace::InlineFields.new(@issue)
    render json: {lock_version: @issue.lock_version, fields: inline.fields}
  end

  def update
    attribute = params[:attribute].to_s
    value = params[:value].to_s
    inline = RedmineWorkspace::InlineFields.new(@issue)
    unless inline.editable? && inline.fields.values.any? {|f| f[:attribute] == attribute}
      return render_error_json(l(:notice_not_authorized), :forbidden)
    end

    @issue.init_journal(User.current)
    @issue.lock_version = params[:lock_version] if params[:lock_version].present?
    @issue.safe_attributes = inline.attributes_for(attribute, value)
    return render_error_json(l(:error_workspace_inline_not_allowed)) unless inline.applied?(attribute, value)

    call_hook(:controller_issues_edit_before_save,
              {params: params, issue: @issue, time_entry: nil, journal: @issue.current_journal})
    return render_error_json(@issue.errors.full_messages.join(', ')) unless @issue.save

    call_hook(:controller_issues_edit_after_save,
              {params: params, issue: @issue, time_entry: nil, journal: @issue.current_journal})
    render json: {lock_version: @issue.reload.lock_version}
  rescue ActiveRecord::StaleObjectError
    render_error_json(l(:notice_issue_update_conflict), :conflict)
  end

  private

  def find_issue
    @issue = Issue.visible.find(params[:id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def render_error_json(message, status = :unprocessable_content)
    render json: {error: message}, status: status
  end
end
