# frozen_string_literal: true

module RedmineWorkspace
  # Status and priority icons, shared by the workspace views, the issue lists (through a <template>) and the kanban plugin.
  module Icons
    STATUS_SHAPES = {
      'backlog' => '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-dasharray="2 2.4"/>',
      'todo' => '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5"/>',
      'progress' => '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5"/>' \
                    '<path d="M8 4.5A3.5 3.5 0 0 1 8 11.5Z" fill="currentColor"/>',
      'review' => '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5"/>' \
                  '<path d="M8 4.5A3.5 3.5 0 1 1 4.5 8H8Z" fill="currentColor"/>',
      'done' => '<circle cx="8" cy="8" r="6.75" fill="currentColor"/>' \
                '<path d="M5.4 8.2l1.8 1.8 3.4-3.6" fill="none" stroke="var(--gf-surface, #fff)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
      'cancelled' => '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5"/>' \
                     '<path d="M6 6l4 4M10 6l-4 4" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
    }.freeze

    PRIORITY_SHAPES = {
      'urgent' => '<rect x="1" y="1" width="14" height="14" rx="3.5" fill="currentColor"/>' \
                  '<path d="M8 4.5v4.2M8 11.2v.3" stroke="var(--gf-surface, #fff)" stroke-width="1.8" stroke-linecap="round"/>'
    }.freeze

    PRIORITY_BARS = {'low' => [1, 0.25, 0.25], 'normal' => [1, 1, 0.25], 'high' => [1, 1, 1]}.freeze
    PRIORITY_LEVELS = %w(low normal high urgent).freeze

    module_function

    def status_svg(category)
      svg(STATUS_SHAPES.fetch(category, STATUS_SHAPES['todo']))
    end

    def priority_svg(level)
      return svg(PRIORITY_SHAPES['urgent']) if level == 'urgent'

      a, b, c = PRIORITY_BARS.fetch(level, PRIORITY_BARS['normal'])
      svg(%(<rect x="2" y="9" width="3" height="5" rx="1" fill="currentColor" opacity="#{a}"/>) +
          %(<rect x="6.5" y="6" width="3" height="8" rx="1" fill="currentColor" opacity="#{b}"/>) +
          %(<rect x="11" y="3" width="3" height="11" rx="1" fill="currentColor" opacity="#{c}"/>))
    end

    # Redmine names priorities by rank around the default one: lowest, low2, default, high2, high1, highest...
    def priority_level(priority)
      name = priority&.position_name.to_s
      return 'urgent' if %w(highest high1).include?(name)
      return 'high' if name.start_with?('high')
      return 'low' if name.start_with?('low')

      'normal'
    end

    def status(status, label: true)
      category = StatusCategories.category_for(status)
      html = %(<span class="gf-status gf-status-#{category}" title="#{ERB::Util.h(status&.name)}">#{status_svg(category)})
      html << %(<span>#{ERB::Util.h(status&.name)}</span>) if label
      (html << '</span>').html_safe
    end

    def priority(priority, label: true)
      return ''.html_safe unless priority

      level = priority_level(priority)
      html = %(<span class="gf-prio gf-prio-#{level}" title="#{ERB::Util.h(priority.name)}">#{priority_svg(level)})
      html << %(<span>#{ERB::Util.h(priority.name)}</span>) if label
      (html << '</span>').html_safe
    end

    def svg(inner)
      %(<svg class="gf-icon" viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" focusable="false">#{inner}</svg>)
    end
  end
end
