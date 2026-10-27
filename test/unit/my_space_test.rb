# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineWorkspace::MySpaceTest < ActiveSupport::TestCase
  def setup
    @user = User.find(2)
    User.current = @user
    @space = RedmineWorkspace::MySpace.new(@user)
  end

  def teardown
    User.current = nil
  end

  def test_buckets
    today = @user.today
    assert_equal 'overdue', @space.bucket_for(Issue.new(due_date: today - 1))
    assert_equal 'week', @space.bucket_for(Issue.new(due_date: today))
    assert_equal 'later', @space.bucket_for(Issue.new(due_date: today.end_of_week + 1))
    assert_equal 'none', @space.bucket_for(Issue.new)
  end

  def test_assigned_issues_are_open_and_mine
    issues = @space.issues('assigned')
    assert issues.any?
    assert issues.all? {|issue| !issue.closed? && issue.assigned_to_id == @user.id}
    assert_equal @space.assigned_scope.count, @space.summary.values.sum
  end

  def test_watched_issues
    Watcher.create!(watchable: Issue.find(1), user: @user) unless Issue.find(1).watched_by?(@user)
    assert_includes @space.issues('watched'), Issue.find(1)
  end

  def test_register_visit_keeps_previous_visit
    first = Time.zone.parse('2026-01-01 10:00')
    @space.register_visit!(first)
    later = first + 2.hours
    since = RedmineWorkspace::MySpace.new(@user.reload).register_visit!(later)
    assert_equal first.to_i, since.to_i
  end

  def test_activity_lists_changes_by_others_since_last_visit
    issue = Issue.find(1)
    issue.update_columns(assigned_to_id: @user.id, status_id: 1)
    @user.pref[RedmineWorkspace::MySpace::PREVIOUS_VISIT_PREF] = 1.hour.ago.iso8601
    @user.pref.save
    journal = issue.init_journal(User.find(3), 'Fresh note')
    journal.save!

    activity = RedmineWorkspace::MySpace.new(@user.reload).activity
    assert_includes activity, journal
    assert activity.none? {|j| j.user_id == @user.id}
  end
end
