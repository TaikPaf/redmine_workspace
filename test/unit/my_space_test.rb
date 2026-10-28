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

  def add_note_by_other(issue, text)
    issue.update_columns(assigned_to_id: @user.id, status_id: 1)
    journal = issue.init_journal(User.find(3), text)
    journal.save!
    journal
  end

  def test_inbox_groups_changes_by_others_per_issue
    issue = Issue.find(1)
    first = add_note_by_other(issue, 'First note')
    second = add_note_by_other(issue, 'Second note')

    entry = RedmineWorkspace::MySpace.new(@user.reload).inbox.detect {|e| e.issue.id == issue.id}
    assert entry
    assert_equal second, entry.latest
    assert_includes entry.journals, first
    assert entry.journals.none? {|j| j.user_id == @user.id}
    assert entry.unread?
  end

  def test_mark_read_clears_one_issue
    issue = Issue.find(1)
    add_note_by_other(issue, 'Note')
    space = RedmineWorkspace::MySpace.new(@user.reload)
    unread = space.unread_count
    space.mark_read!(issue, 1.second.from_now)

    space = RedmineWorkspace::MySpace.new(@user.reload)
    assert_not space.inbox.detect {|e| e.issue.id == issue.id}.unread?
    assert_equal unread - 1, space.unread_count
  end

  def test_mark_all_read
    add_note_by_other(Issue.find(1), 'Note')
    RedmineWorkspace::MySpace.new(@user).mark_all_read!(1.second.from_now)
    assert_equal 0, RedmineWorkspace::MySpace.new(@user.reload).unread_count
  end

  def test_new_change_after_reading_is_unread_again
    issue = Issue.find(1)
    add_note_by_other(issue, 'Old')
    RedmineWorkspace::MySpace.new(@user).mark_read!(issue, 1.minute.ago)
    add_note_by_other(issue, 'New')
    entry = RedmineWorkspace::MySpace.new(@user.reload).inbox.detect {|e| e.issue.id == issue.id}
    assert_equal 1, entry.unread
  end
end
