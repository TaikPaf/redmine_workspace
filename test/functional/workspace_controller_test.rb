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
  end

  def test_index_tabs
    %w(created watched activity).each do |tab|
      get :index, params: {tab: tab}
      assert_response :success
      assert_select ".gf-tabs a.selected[href*='tab=#{tab}']"
    end
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
    assert_select '#gf-issues-panel .gf-chip', RedmineWorkspace::QuickViews::DEFINITIONS.size
    assert_select '#gf-issues-panel .gf-token', 2
    assert_select '#gf-appnav .gf-appnav-link', minimum: 3
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
