# frozen_string_literal: true

get 'workspace', to: 'workspace#index', as: 'workspace'
get 'workspace/projects', to: 'workspace#projects', as: 'workspace_projects'
get 'workspace/search', to: 'workspace#search', as: 'workspace_search'
get 'workspace/palette', to: 'workspace#palette', as: 'workspace_palette'
