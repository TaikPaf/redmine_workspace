# frozen_string_literal: true

get 'workspace', to: 'workspace#index', as: 'workspace'
get 'workspace/projects', to: 'workspace#projects', as: 'workspace_projects'
get 'workspace/search', to: 'workspace#search', as: 'workspace_search'
get 'workspace/palette', to: 'workspace#palette', as: 'workspace_palette'
get 'workspace/issues/:id/inline', to: 'workspace_issues#fields', as: 'workspace_issue_inline'
patch 'workspace/issues/:id/inline', to: 'workspace_issues#update'
get 'workspace/issues/:id/peek', to: 'workspace_issues#peek', as: 'workspace_issue_peek'
post 'workspace/issues/:id/notes', to: 'workspace_issues#add_note', as: 'workspace_issue_notes'
