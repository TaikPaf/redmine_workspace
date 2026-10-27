# frozen_string_literal: true

module RedmineWorkspace
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      return '' unless User.current.logged?

      stylesheet_link_tag('workspace', plugin: 'redmine_workspace') +
        javascript_include_tag('workspace', plugin: 'redmine_workspace', defer: true)
    end

    render_on :view_layouts_base_body_top, partial: 'workspace/hooks/appnav'
    render_on :view_issues_index_bottom, partial: 'workspace/hooks/issues_panel'
    render_on :view_issues_show_details_bottom, partial: 'workspace/hooks/transitions'
  end
end
