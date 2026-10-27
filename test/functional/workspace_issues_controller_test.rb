# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class WorkspaceIssuesControllerTest < Redmine::ControllerTest
  def setup
    @request.session[:user_id] = 2
  end

  def test_fields
    get :fields, params: {id: 1}
    assert_response :success
    json = response.parsed_body
    assert_equal Issue.find(1).lock_version, json['lock_version']
    assert_equal 'priority_id', json['fields']['priority']['attribute']
    assert_equal 'select', json['fields']['priority']['type']
    assert_equal 'date', json['fields']['due-date']['type']
    statuses = json['fields']['status']['options'].map(&:last)
    assert_equal Issue.find(1).new_statuses_allowed_to(User.find(2)).map {|s| s.id.to_s}, statuses
  end

  def test_fields_without_edit_permission
    Role.find(1).remove_permission!(:edit_issues)
    get :fields, params: {id: 1}
    assert_response :success
    assert_equal({}, response.parsed_body['fields'])
  end

  def test_update_priority_creates_journal
    issue = Issue.find(1)
    target = IssuePriority.active.detect {|p| p.id != issue.priority_id}
    assert_difference 'Journal.count' do
      patch :update, params: {id: 1, attribute: 'priority_id', value: target.id.to_s, lock_version: issue.lock_version}, xhr: true
    end
    assert_response :success
    assert_equal target.id, issue.reload.priority_id
    assert_equal issue.lock_version, response.parsed_body['lock_version']
  end

  def test_update_date_and_clear_it
    patch :update, params: {id: 1, attribute: 'due_date', value: '2030-01-15'}, xhr: true
    assert_response :success
    assert_equal Date.new(2030, 1, 15), Issue.find(1).due_date

    patch :update, params: {id: 1, attribute: 'due_date', value: ''}, xhr: true
    assert_response :success
    assert_nil Issue.find(1).due_date
  end

  def test_update_custom_field
    field = IssueCustomField.create!(name: 'Client', field_format: 'string', is_for_all: true, tracker_ids: Tracker.pluck(:id))
    patch :update, params: {id: 1, attribute: "custom_field_#{field.id}", value: 'ACME'}, xhr: true
    assert_response :success
    assert_equal 'ACME', Issue.find(1).custom_field_value(field)
  end

  def test_update_status_not_allowed_by_workflow
    issue = Issue.find(1)
    forbidden = IssueStatus.where.not(id: issue.status_id).last
    WorkflowTransition.where(tracker_id: issue.tracker_id, old_status_id: issue.status_id, new_status_id: forbidden.id).delete_all
    patch :update, params: {id: 1, attribute: 'status_id', value: forbidden.id.to_s}, xhr: true
    assert_response :unprocessable_content
    assert_equal issue.status_id, issue.reload.status_id
  end

  def test_update_invalid_value
    patch :update, params: {id: 1, attribute: 'estimated_hours', value: '-3'}, xhr: true
    assert_response :unprocessable_content
    assert response.parsed_body['error'].present?
  end

  def test_update_unknown_attribute_is_forbidden
    patch :update, params: {id: 1, attribute: 'author_id', value: '3'}, xhr: true
    assert_response :forbidden
    assert_equal 2, Issue.find(1).author_id
  end

  def test_update_with_stale_lock_version
    issue = Issue.find(1)
    patch :update, params: {id: 1, attribute: 'due_date', value: '2030-01-15', lock_version: issue.lock_version - 1}, xhr: true
    assert_response :conflict
  end

  def test_update_read_only_field
    issue = Issue.find(1)
    WorkflowPermission.create!(role_id: 1, tracker_id: issue.tracker_id, old_status_id: issue.status_id,
                               field_name: 'priority_id', rule: 'readonly')
    patch :update, params: {id: 1, attribute: 'priority_id', value: IssuePriority.active.first.id.to_s}, xhr: true
    assert_response :forbidden
  end

  def test_invisible_issue
    @request.session[:user_id] = nil
    get :fields, params: {id: 1}
    assert_response :redirect
  end
end
