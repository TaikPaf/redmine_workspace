# frozen_string_literal: true

module RedmineWorkspace
  # One-click views shown above issue lists, each defined as a plain-language search.
  module QuickViews
    View = Struct.new(:key, :text, :label, :count, keyword_init: true)

    DEFINITIONS = [
      %w(mine moi),
      ['my_overdue', 'moi retard'],
      %w(overdue retard),
      %w(unassigned nonassigne),
      %w(high prio:haute),
      %w(updated maj:semaine),
      %w(watched suivi)
    ].freeze

    def self.for(project, user = User.current)
      parser = SearchParser.new(project: project, user: user)
      DEFINITIONS.map do |key, text|
        query = IssueQuery.new(name: '_', project: project)
        query.build_from_params(parser.parse(text).query_params)
        View.new(key: key, text: text, label: ::I18n.t("label_workspace_view_#{key}"),
                 count: query.valid? ? query.issue_count : 0)
      end
    end
  end
end
