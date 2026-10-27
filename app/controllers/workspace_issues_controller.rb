# frozen_string_literal: true

# In-place editing of a single issue attribute from the issue page.
class WorkspaceIssuesController < ApplicationController
  before_action :require_login
  before_action :find_issue

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
