# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class StatusCategoriesTest < ActiveSupport::TestCase
  def teardown
    Setting.plugin_redmine_workspace = {'home_redirect' => '1'}
  end

  def category(name)
    RedmineWorkspace::StatusCategories.category_for(IssueStatus.find_by(name: name))
  end

  def test_defaults_follow_redmine_statuses
    assert_equal 'todo', category('New')
    assert_equal 'progress', category('Assigned')
    assert_equal 'review', category('Resolved')
    assert_equal 'review', category('Feedback')
    assert_equal 'done', category('Closed')
    assert_equal 'cancelled', category('Rejected')
  end

  def test_setting_overrides_default
    status = IssueStatus.find_by(name: 'Feedback')
    Setting.plugin_redmine_workspace = {'status_categories' => {status.id.to_s => 'backlog'}}
    assert_equal 'backlog', RedmineWorkspace::StatusCategories.category_for(status)
  end

  def test_unknown_setting_value_falls_back_to_default
    status = IssueStatus.find_by(name: 'Closed')
    Setting.plugin_redmine_workspace = {'status_categories' => {status.id.to_s => 'nonsense'}}
    assert_equal 'done', RedmineWorkspace::StatusCategories.category_for(status)
  end

  def test_priority_levels
    levels = IssuePriority.active.sorted.map {|p| RedmineWorkspace::Icons.priority_level(p)}
    assert_equal 'low', levels.first
    assert_equal 'urgent', levels.last
    assert_includes levels, 'normal'
  end
end
