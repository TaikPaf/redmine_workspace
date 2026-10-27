# frozen_string_literal: true

module RedmineWorkspace
  # Turns a short plain-language search ("moi en retard prio:haute export")
  # into IssueQuery filter params plus human-readable tokens.
  class SearchParser
    Token = Struct.new(:raw, :label, keyword_init: true)
    Result = Struct.new(:filters, :tokens, :issue_id, keyword_init: true) do
      def query_params
        params = {set_filter: '1', f: [], op: {}, v: {}}
        filters.each do |field, (operator, values)|
          params[:f] << field
          params[:op][field] = operator
          params[:v][field] = values
        end
        params[:f] << ''
        params
      end
    end

    STOPWORDS = %w(en de la le les du des a et cette ce ces mes mon ma the in of par pour avec sur dans my).freeze
    ME = %w(moi me @moi @me).freeze
    UNASSIGNED = %w(nonassigne non-assigne unassigned sans-assigne).freeze
    OVERDUE = %w(retard en-retard retards overdue late).freeze
    TODAY = %w(aujourdhui today).freeze
    WEEK = %w(semaine week).freeze
    MONTH = %w(mois month).freeze
    OPEN = %w(ouvert ouverte ouverts ouvertes open).freeze
    CLOSED = %w(ferme fermee fermes fermees closed).freeze
    ALL = %w(tous toutes all).freeze
    WATCHED = %w(suivi suivies surveille surveillees watched watching).freeze
    BUGS = %w(bug bugs anomalie anomalies).freeze
    HIGH = %w(haute haut high elevee).freeze
    LOW = %w(basse bas low).freeze
    URGENT = %w(urgent urgente urgents urgentes immediat immediate).freeze
    PREFIXES = {
      'projet' => :project, 'project' => :project,
      'version' => :version,
      'statut' => :status, 'status' => :status,
      'prio' => :priority, 'priorite' => :priority, 'priority' => :priority,
      'tracker' => :tracker, 'type' => :tracker,
      'assigne' => :assignee, 'assignee' => :assignee, 'pour' => :assignee,
      'auteur' => :author, 'author' => :author, 'cree' => :author,
      'maj' => :updated, 'updated' => :updated, 'modifie' => :updated
    }.freeze

    attr_reader :project, :user

    def initialize(project: nil, user: User.current)
      @project = project
      @user = user
    end

    def parse(text)
      @filters = {}
      @tokens = []
      issue_id = nil
      words = []
      pending_not = false

      text.to_s.split(/\s+/).reject(&:blank?).each do |raw|
        word = normalize(raw)
        if pending_not
          pending_not = false
          if %w(assigne assignee assignees assignees).include?(word)
            unassigned(raw)
            next
          end
          words << 'non'
        end

        if (m = word.match(/\A#(\d+)\z/))
          issue_id = m[1].to_i
          add('issue_id', '=', [m[1]], raw, l(:label_workspace_token_issue, id: m[1]))
        elsif word == 'non' || word == 'not'
          pending_not = true
        elsif (m = word.match(/\A@(.+)\z/)) && !ME.include?(word)
          assignee(m[1], raw)
        elsif word.include?(':') && PREFIXES.key?(word.split(':', 2).first)
          prefixed(word, raw)
        elsif !keyword(word, raw) && !STOPWORDS.include?(word)
          words << raw
        end
      end
      words << 'non' if pending_not

      if words.any?
        phrase = words.join(' ')
        add('any_searchable', '~', [phrase], phrase, l(:label_workspace_token_text, text: phrase))
      end
      unless @filters.key?('status_id')
        @filters['status_id'] = ['o', ['']]
      end
      issue_id = nil if @tokens.size > 1
      Result.new(filters: @filters, tokens: @tokens, issue_id: issue_id)
    end

    private

    def keyword(word, raw)
      if ME.include?(word)
        add('assigned_to_id', '=', ['me'], raw, l(:label_workspace_token_assigned_to, name: l(:label_workspace_me)))
      elsif UNASSIGNED.include?(word)
        unassigned(raw)
      elsif OVERDUE.include?(word)
        add('due_date', '<=', [(user.today - 1).to_s], raw, l(:label_workspace_token_overdue))
      elsif TODAY.include?(word)
        add('due_date', 't', [''], raw, l(:label_workspace_token_due_today))
      elsif WEEK.include?(word)
        add('due_date', 'w', [''], raw, l(:label_workspace_token_due_week))
      elsif MONTH.include?(word)
        add('due_date', 'm', [''], raw, l(:label_workspace_token_due_month))
      elsif OPEN.include?(word)
        status_open(raw)
      elsif CLOSED.include?(word)
        add('status_id', 'c', [''], raw, l(:label_workspace_token_status, name: l(:label_closed_issues)))
      elsif ALL.include?(word)
        add('status_id', '*', [''], raw, l(:label_workspace_token_status, name: l(:label_all)))
      elsif WATCHED.include?(word)
        add('watcher_id', '=', ['me'], raw, l(:label_workspace_token_watched))
      elsif BUGS.include?(word)
        tracker = Tracker.all.detect {|t| %w(anomalie bug).include?(normalize(t.name))}
        return false unless tracker

        add('tracker_id', '=', [tracker.id.to_s], raw, l(:label_workspace_token_tracker, name: tracker.name))
      elsif URGENT.include?(word)
        found = IssuePriority.active.detect {|p| normalize(p.name).start_with?(word[0, 5])} || IssuePriority.active.last
        return false unless found

        add('priority_id', '=', [found.id.to_s], raw, l(:label_workspace_token_priority, name: found.name))
      else
        return false
      end
      true
    end

    def prefixed(word, raw)
      key, value = word.split(':', 2)
      return if value.blank?

      value = value.delete('-') unless PREFIXES[key] == :project

      case PREFIXES[key]
      when :project then project_filter(value, raw)
      when :version then version_filter(value, raw)
      when :status then status_filter(value, raw)
      when :priority then priority_filter(value, raw)
      when :tracker then tracker_filter(value, raw)
      when :assignee
        ME.include?(value) ? keyword('moi', raw) : assignee(value, raw)
      when :author
        if ME.include?(value)
          add('author_id', '=', ['me'], raw, l(:label_workspace_token_author, name: l(:label_workspace_me)))
        elsif (u = find_user(value))
          add('author_id', '=', [u.id.to_s], raw, l(:label_workspace_token_author, name: u.name))
        end
      when :updated
        operator = {'aujourdhui' => 't', 'today' => 't', 'semaine' => 'w', 'week' => 'w', 'mois' => 'm', 'month' => 'm'}[value]
        add('updated_on', operator, [''], raw, l(:label_workspace_token_updated, period: raw.split(':', 2).last)) if operator
      end
    end

    def unassigned(raw)
      add('assigned_to_id', '!*', [''], raw, l(:label_workspace_token_unassigned))
    end

    def status_open(raw)
      add('status_id', 'o', [''], raw, l(:label_workspace_token_status, name: l(:label_open_issues)))
    end

    def assignee(value, raw)
      return keyword('moi', raw) if ME.include?("@#{value}") || ME.include?(value)

      user_found = find_user(value)
      if user_found
        add('assigned_to_id', '=', [user_found.id.to_s], raw, l(:label_workspace_token_assigned_to, name: user_found.name))
      end
    end

    def find_user(value)
      scope = project ? Principal.member_of(project) : Principal.visible
      scope.active.detect do |principal|
        [principal.try(:login), principal.name].compact.any? {|name| normalize(name).delete(' ').include?(value.delete(' '))}
      end
    end

    def project_filter(value, raw)
      found = Project.visible.detect do |p|
        normalize(p.identifier) == value || normalize(p.name).delete(' ').include?(value)
      end
      add('project_id', '=', [found.id.to_s], raw, l(:label_workspace_token_project, name: found.name)) if found
    end

    def version_filter(value, raw)
      scope = project ? project.shared_versions : Version.visible
      found = scope.to_a.detect {|v| normalize(v.name).delete(' ') == value} ||
              scope.to_a.detect {|v| normalize(v.name).include?(value)}
      add('fixed_version_id', '=', [found.id.to_s], raw, l(:label_workspace_token_version, name: found.name)) if found
    end

    def status_filter(value, raw)
      return status_open(raw) if OPEN.include?(value)
      return keyword('ferme', raw) if CLOSED.include?(value)
      return keyword('tous', raw) if ALL.include?(value)

      found = IssueStatus.sorted.detect {|s| normalize(s.name).delete(' ').include?(value)}
      add('status_id', '=', [found.id.to_s], raw, l(:label_workspace_token_status, name: found.name)) if found
    end

    def priority_filter(value, raw)
      if HIGH.include?(value)
        default = IssuePriority.default_or_middle
        found = IssuePriority.active.select {|p| p.position > default.position}
        add('priority_id', '=', found.map {|p| p.id.to_s}, raw, l(:label_workspace_token_priority_high)) if found.any?
      elsif URGENT.include?(value)
        keyword(value, raw)
      elsif LOW.include?(value)
        default = IssuePriority.default_or_middle
        ids = IssuePriority.active.select {|p| p.position < default.position}.map {|p| p.id.to_s}
        add('priority_id', '=', ids, raw, l(:label_workspace_token_priority_low)) if ids.any?
      else
        found = IssuePriority.active.detect {|p| normalize(p.name).delete(' ').include?(value)}
        add('priority_id', '=', [found.id.to_s], raw, l(:label_workspace_token_priority, name: found.name)) if found
      end
    end

    def tracker_filter(value, raw)
      return keyword('bug', raw) if BUGS.include?(value)

      found = Tracker.sorted.detect {|t| normalize(t.name).delete(' ').include?(value)}
      add('tracker_id', '=', [found.id.to_s], raw, l(:label_workspace_token_tracker, name: found.name)) if found
    end

    def add(field, operator, values, raw, label)
      @filters[field] = [operator, values]
      @tokens.reject! {|t| t.raw == raw}
      @tokens << Token.new(raw: raw, label: label)
    end

    def normalize(text)
      I18n.transliterate(text.to_s.downcase, replacement: '').delete("'’")
    end

    def l(key, **args)
      ::I18n.t(key, **args)
    end
  end
end
