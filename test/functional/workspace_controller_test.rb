# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class WorkspaceControllerTest < Redmine::ControllerTest
  def setup
    @request.session[:user_id] = 2
  end

  def test_index_requires_login
    @request.session[:user_id] = nil
    get :index
    assert_response :redirect
  end

  def test_index
    get :index
    assert_response :success
    assert_select '.gf-myspace .gf-tabs a', 4
    assert_select '.gf-issue-row', minimum: 1
    assert_select '.gf-issue-row .gf-status svg.gf-icon', minimum: 1
    assert_select '.gf-issue-row .gf-prio svg.gf-icon', minimum: 1
    assert_select '.gf-issue-item button.gf-peek-btn[data-gf-peek]', minimum: 1
  end

  def test_index_tabs
    %w(created watched activity).each do |tab|
      get :index, params: {tab: tab}
      assert_response :success
      assert_select ".gf-tabs a.selected[href*='tab=#{tab}']"
    end
  end

  def test_activity_tab_lists_unread_issues
    issue = Issue.find(1)
    issue.update_columns(assigned_to_id: 2, status_id: 1)
    issue.init_journal(User.find(3), 'Une nouvelle note').save!
    get :index, params: {tab: 'activity'}
    assert_response :success
    assert_select ".gf-inbox-item.unread a[href^='/issues/1']"
    assert_select '.gf-tabs .gf-tab-badge'
    assert_select "form[action='/workspace/activity/read']"
  end

  def test_mark_all_read
    issue = Issue.find(1)
    issue.update_columns(assigned_to_id: 2, status_id: 1)
    issue.init_journal(User.find(3), 'Note').save!
    travel 1.second do
      post :mark_all_read
    end
    assert_redirected_to '/workspace?tab=activity'
    assert_equal 0, RedmineWorkspace::MySpace.new(User.find(2)).unread_count
  end

  def test_palette_offers_actions_on_the_current_issue
    get :palette, params: {q: '', issue_id: 1}
    assert_response :success
    section = response.parsed_body['sections'].first
    assert_equal I18n.t(:label_workspace_palette_this_issue), section['title']
    assert section['items'].all? {|item| item['js'] == 'issue-update' && item['endpoint'] == '/workspace/issues/1/inline'}
    assert section['items'].any? {|item| item['attribute'] == 'status_id'}
  end

  def test_layout_carries_status_icon_templates
    get :index
    assert_select 'template#gf-icon-templates[data-status-categories]'
    assert_select 'template#gf-icon-templates [data-status=done]'
    assert_select 'template#gf-icon-templates [data-priority=urgent]'
  end

  def test_projects
    get :projects
    assert_response :success
    assert_select '.gf-project-card', Project.visible(User.find(2)).where(status: Project::STATUS_ACTIVE).count
    assert_select '.gf-project-card [data-gf-bookmark]', minimum: 1
    assert_select '.gf-project-table tr.gf-project-item', Project.visible(User.find(2)).where(status: Project::STATUS_ACTIVE).count
    assert_select '.gf-project-table tr.gf-depth-1', minimum: 1
  end

  def test_search_redirects_to_issues_with_filters
    get :search, params: {q: 'moi retard', project_id: 'ecookbook'}
    assert_response :redirect
    location = response.location
    assert_includes location, '/projects/ecookbook/issues'
    assert_includes location, 'gf_q=moi+retard'
    assert_includes location, 'assigned_to_id'
  end

  def test_search_with_issue_number_opens_the_issue
    get :search, params: {q: '#1'}
    assert_redirected_to '/issues/1'
  end

  def test_palette_json
    get :palette, params: {q: 'cannot'}
    assert_response :success
    json = response.parsed_body
    titles = json['sections'].pluck('title')
    assert_includes titles, I18n.t(:label_issue_plural)
    issue = json['sections'].first['items'].first
    assert_match '/issues/', issue['url']
    assert issue['preview']['title'].present?
    assert_includes RedmineWorkspace::StatusCategories::CATEGORIES, issue['preview']['status_category']
    assert_equal I18n.t(:field_status), issue['preview']['rows'].first.first
  end

  def test_palette_actions
    get :palette, params: {q: '>'}
    assert_response :success
    labels = response.parsed_body['sections'].first['items'].pluck('label')
    assert_includes labels, I18n.t(:label_workspace)
  end

  def test_palette_hides_invisible_issues
    @request.session[:user_id] = 3
    get :palette, params: {q: '#4'}
    urls = response.parsed_body['sections'].flat_map {|s| s['items']}.pluck('url').compact
    assert_not_includes urls, '/issues/4' unless Issue.find(4).visible?(User.find(3))
  end
end

class WorkspaceHooksTest < Redmine::ControllerTest
  tests IssuesController

  def setup
    @request.session[:user_id] = 2
  end

  def test_issues_index_shows_quick_views_and_parsed_tokens
    get :index, params: {project_id: 'ecookbook', gf_q: 'moi retard', set_filter: '1'}
    assert_response :success
    assert_select '#gf-issues-panel .gf-chip:not(.gf-chip-saved):not(.gf-chip-add)', RedmineWorkspace::QuickViews::DEFINITIONS.size
    assert_select '#gf-issues-panel .gf-token', 2
    assert_select '#gf-appnav .gf-appnav-link', minimum: 3
  end

  def test_issues_index_shows_saved_queries_as_views
    query = IssueQuery.visible(User.find(2)).global_or_on_project(Project.find(1)).sorted.first
    get :index, params: {project_id: 'ecookbook', query_id: query.id}
    assert_response :success
    assert_select "#gf-issues-panel a.gf-chip-saved.active[href*='query_id=#{query.id}']", text: /#{Regexp.escape(query.name)}/
    assert_select '#gf-issues-panel [data-gf-save-view]'
  end

  def test_layout_has_tab_bar_and_navigation_mode_script
    get :index, params: {project_id: 'ecookbook'}
    assert_select '#gf-tabbar .gf-tab', minimum: 4
    assert_select '#gf-appnav [data-gf-nav-toggle]'
    assert_includes response.body, 'gfSetNavMode'
  end

  def test_issue_show_has_note_composer_and_marks_issue_read
    issue = Issue.find(1)
    issue.update_columns(assigned_to_id: 2, status_id: 1)
    issue.init_journal(User.find(3), 'À lire').save!
    travel 1.second do
      get :show, params: {id: 1}
    end
    assert_response :success
    assert_select "form.gf-note-composer[action='/workspace/issues/1/notes'] textarea[name=notes]"
    entry = RedmineWorkspace::MySpace.new(User.find(2)).inbox.detect {|e| e.issue.id == 1}
    assert_not entry.unread?
  end

  def test_issue_show_has_status_buttons_and_tracks_recent
    get :show, params: {id: 1}
    assert_response :success
    assert_select '.gf-transitions .gf-transition', minimum: 1
    assert_equal 1, RedmineWorkspace::RecentIssues.ids(User.find(2)).first
  end
end

class WorkspaceWelcomeTest < Redmine::ControllerTest
  tests WelcomeController

  def test_home_redirects_logged_users
    @request.session[:user_id] = 2
    with_settings plugin_redmine_workspace: {'home_redirect' => '1'} do
      get :index
      assert_redirected_to '/workspace'
    end
  end

  def test_home_without_redirect
    @request.session[:user_id] = 2
    with_settings plugin_redmine_workspace: {'home_redirect' => '0'} do
      get :index
      assert_response :success
    end
  end
end
