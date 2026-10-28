# frozen_string_literal: true

module RedmineWorkspace
  class Hooks < Redmine::Hook::ViewListener
    # Decides between the full side navigation and the icon rail before the first paint:
    # the rail by default from 900 to 1279 px, the full navigation above, unless the user chose otherwise.
    NAV_MODE_SCRIPT = <<~JS
      (function () {
        var root = document.documentElement, pref = null;
        try { pref = window.localStorage.getItem('glassfluid:nav'); } catch (e) {}
        function apply() {
          var w = window.innerWidth;
          root.classList.toggle('gf-rail', w >= 900 && (w < 1280 ? pref !== 'full' : pref === 'rail'));
        }
        apply();
        window.addEventListener('resize', apply);
        window.gfSetNavMode = function (mode) {
          pref = mode;
          try { window.localStorage.setItem('glassfluid:nav', mode); } catch (e) {}
          apply();
        };
      })();
    JS

    def view_layouts_base_html_head(context = {})
      return '' unless User.current.logged?

      javascript_tag(NAV_MODE_SCRIPT) +
        stylesheet_link_tag('workspace', plugin: 'redmine_workspace') +
        javascript_include_tag('workspace', plugin: 'redmine_workspace', defer: true)
    end

    render_on :view_layouts_base_body_top, partial: 'workspace/hooks/appnav'
    render_on :view_issues_index_bottom, partial: 'workspace/hooks/issues_panel'
    render_on :view_issues_show_details_bottom, partial: 'workspace/hooks/transitions'
  end
end
