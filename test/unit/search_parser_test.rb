# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineWorkspace::SearchParserTest < ActiveSupport::TestCase
  def setup
    User.current = User.find(2)
    @parser = RedmineWorkspace::SearchParser.new(project: Project.find(1), user: User.current)
  end

  def teardown
    User.current = nil
  end

  def parse(text)
    @parser.parse(text)
  end

  def test_empty_text_defaults_to_open_issues
    result = parse('')
    assert_equal({'status_id' => ['o', ['']]}, result.filters)
    assert_empty result.tokens
  end

  def test_me_and_overdue
    result = parse('moi en retard')
    assert_equal ['=', ['me']], result.filters['assigned_to_id']
    assert_equal ['<=', [(User.current.today - 1).to_s]], result.filters['due_date']
    assert_equal ['o', ['']], result.filters['status_id']
    assert_equal 2, result.tokens.size
  end

  def test_english_keywords
    result = parse('me overdue closed')
    assert_equal ['=', ['me']], result.filters['assigned_to_id']
    assert_equal 'c', result.filters['status_id'].first
  end

  def test_accents_and_case_are_ignored
    assert_equal ['!*', ['']], parse('NON ASSIGNÉ').filters['assigned_to_id']
    assert_equal 't', parse("aujourd'hui").filters['due_date'].first
  end

  def test_free_text_goes_to_full_text_search
    result = parse('moi export pdf')
    assert_equal ['~', ['export pdf']], result.filters['any_searchable']
  end

  def test_high_priority_selects_priorities_above_default
    result = parse('prio:haute')
    default = IssuePriority.default_or_middle
    expected = IssuePriority.active.select {|p| p.position > default.position}.map {|p| p.id.to_s}
    assert_equal ['=', expected], result.filters['priority_id']
  end

  def test_project_prefix
    result = parse('projet:ecookbook')
    assert_equal ['=', ['1']], result.filters['project_id']
  end

  def test_unknown_project_is_ignored
    result = parse('projet:nope')
    assert_nil result.filters['project_id']
  end

  def test_tracker_and_status_prefixes
    tracker = Tracker.find(1)
    status = IssueStatus.find(2)
    result = parse("tracker:#{tracker.name.downcase} statut:#{status.name.downcase.delete(' ')}")
    assert_equal ['=', [tracker.id.to_s]], result.filters['tracker_id']
    assert_equal ['=', [status.id.to_s]], result.filters['status_id']
  end

  def test_hyphenated_status_name
    status = IssueStatus.create!(name: 'En cours de test')
    result = parse('statut:en-cours-de-test')
    assert_equal ['=', [status.id.to_s]], result.filters['status_id']
  end

  def test_assignee_mention
    result = parse('@jsmith')
    assert_equal ['=', ['2']], result.filters['assigned_to_id']
  end

  def test_watched_and_updated
    result = parse('suivi maj:semaine')
    assert_equal ['=', ['me']], result.filters['watcher_id']
    assert_equal ['w', ['']], result.filters['updated_on']
  end

  def test_issue_number_alone
    result = parse('#3')
    assert_equal 3, result.issue_id
  end

  def test_issue_number_with_other_words_is_a_filter
    result = parse('#3 moi')
    assert_nil result.issue_id
    assert_equal ['=', ['3']], result.filters['issue_id']
  end

  def test_query_params_build_a_valid_query
    %w(moi retard semaine prio:haute nonassigne suivi bug projet:ecookbook).each do |text|
      query = IssueQuery.new(name: '_', project: Project.find(1))
      query.build_from_params(parse(text).query_params)
      assert query.valid?, "#{text}: #{query.errors.full_messages.join(', ')}"
      assert_nothing_raised { query.issue_count }
    end
  end
end
