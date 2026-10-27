# frozen_string_literal: true

module RedmineWorkspace
  # Per-project figures for the project cards page.
  class ProjectsOverview
    Card = Struct.new(:project, :open, :mine, :overdue, :version, :updated_on, :bookmarked, :member, keyword_init: true) do
      def progress
        version ? version.completed_percent.round : nil
      end
    end

    COLORS = %w(#4F8BFF #2FC7B0 #F08C2E #7C5CE0 #E5484D #5AA9E6 #2FA36B #C2410C).freeze

    def self.color_for(project)
      COLORS[project.id % COLORS.size]
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def cards
      projects = Project.visible(user).where(status: Project::STATUS_ACTIVE).sorted.to_a
      ids = projects.map(&:id)
      open_scope = Issue.visible(user).open.where(project_id: ids)
      open = open_scope.group(:project_id).count
      mine = open_scope.where(assigned_to_id: [user.id] + user.group_ids).group(:project_id).count
      overdue = open_scope.where("#{Issue.table_name}.due_date < ?", user.today).group(:project_id).count
      updated = Issue.visible(user).where(project_id: ids).group(:project_id).maximum(:updated_on)
      bookmarked = user.bookmarked_project_ids
      member_ids = user.memberships.map(&:project_id)
      versions = current_versions(ids)

      cards = projects.map do |project|
        Card.new(
          project: project, open: open[project.id].to_i, mine: mine[project.id].to_i,
          overdue: overdue[project.id].to_i, version: versions[project.id], updated_on: updated[project.id],
          bookmarked: bookmarked.include?(project.id), member: member_ids.include?(project.id)
        )
      end
      cards.sort_by {|card| [card.bookmarked ? 0 : 1, card.project.lft.to_i]}
    end

    private

    # The open version with the nearest due date, else the first open one.
    def current_versions(project_ids)
      Version.visible(user).where(project_id: project_ids, status: 'open').to_a.
        group_by(&:project_id).
        transform_values do |versions|
          versions.min_by {|v| [v.effective_date ? 0 : 1, v.effective_date || Date.new(9999), v.id]}
        end
    end
  end
end
