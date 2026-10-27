# frozen_string_literal: true

class WorkspaceController < ApplicationController
  before_action :require_login
  before_action :find_context_project, only: [:search, :palette]

  helper :issues
  helper :journals
  helper :workspace

  def index
    @space = RedmineWorkspace::MySpace.new(User.current)
    @space.register_visit!
    @tab = RedmineWorkspace::MySpace::TABS.include?(params[:tab]) ? params[:tab] : 'assigned'
    @issues = @space.issues(@tab)
  end

  def projects
    @cards = RedmineWorkspace::ProjectsOverview.new(User.current).cards
  end

  def search
    text = params[:q].to_s.strip
    result = RedmineWorkspace::SearchParser.new(project: @project).parse(text)
    if result.issue_id && (issue = Issue.visible.find_by(id: result.issue_id))
      redirect_to issue_path(issue)
    else
      redirect_to _project_issues_path(@project, result.query_params.merge(gf_q: text))
    end
  end

  def palette
    render json: RedmineWorkspace::Palette.new(User.current, project: @project, view: view_context).
      results(params[:q].to_s)
  end

  private

  def find_context_project
    @project = Project.visible.find_by(id: params[:project_id]) || Project.visible.find_by(identifier: params[:project_id]) if params[:project_id].present?
  end
end
