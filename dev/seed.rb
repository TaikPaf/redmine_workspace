# frozen_string_literal: true

# Demo data for local development:
#   docker compose exec redmine bundle exec rails runner plugins/redmine_workspace/dev/seed.rb
# Admin login stays Redmine's default (admin / admin); other demo users use "<login>-dev-1234".

Redmine::DefaultData::Loader.load('fr') unless IssueStatus.any?
Setting.ui_theme = 'glassfluid'
Setting.default_language = 'fr'

admin = User.find_by(login: 'admin')
admin.update!(must_change_passwd: false, language: 'fr', firstname: 'Tanguy', lastname: 'Admin')

manager = Role.find_by(name: 'Manager') || Role.where(builtin: 0).first
developer = Role.find_by(name: 'Développeur') || manager
[manager, developer].each do |role|
  role.add_permission!(:view_kanban, :rank_kanban_cards, :manage_kanban)
end

def demo_user(login, first, last)
  User.find_by(login: login) || User.create!(
    login: login, firstname: first, lastname: last, mail: "#{login}@example.test",
    password: "#{login}-dev-1234", language: 'fr'
  )
end
alice = demo_user('alice', 'Alice', 'Martin')
bruno = demo_user('bruno', 'Bruno', 'Petit')

projects = [
  ['demo', 'Projet démo', 'Application web principale'],
  ['client', 'Site client', 'Site vitrine et espace client'],
  ['infra', 'Infra', 'Serveurs, CI et bases de données'],
  ['mobile', 'Application mobile', 'Apps iOS et Android']
].map do |identifier, name, description|
  project = Project.find_by(identifier: identifier) || Project.create!(
    name: name, identifier: identifier, description: description, is_public: true,
    tracker_ids: Tracker.pluck(:id),
    enabled_module_names: %w(issue_tracking time_tracking kanban news wiki)
  )
  project.enable_module!(:kanban)
  {admin => manager, alice => developer, bruno => developer}.each do |user, role|
    Member.create!(project: project, principal: user, roles: [role]) unless Member.exists?(project: project, user: user)
  end
  project
end

User.current = admin
statuses = IssueStatus.sorted.to_a
open_statuses = statuses.reject(&:is_closed?)
priorities = IssuePriority.active.to_a
subjects = [
  'Page de connexion', 'Export CSV des factures', 'Notifications par e-mail', 'Recherche plein texte',
  'Corriger le tri des dates', 'Optimiser la requête du tableau de bord', 'Ajouter le mode sombre',
  'Traduire les libellés', 'Migrer vers PostgreSQL 16', 'Écrire la documentation API',
  'Gestion des rôles', "Import d'utilisateurs", 'Corriger le bug de pagination', 'Tests de charge',
  'Refonte du menu', 'Webhook de paiement', 'Cache des avatars', 'Journal des connexions',
  'Certificat TLS expiré sur staging', 'Lenteur de la page Factures', 'Bouton Enregistrer inactif sur Safari',
  'Mettre à jour les dépendances', 'Sauvegardes nocturnes', 'Mode hors ligne'
]

projects.each_with_index do |project, p_index|
  next if project.issues.any?

  version = Version.create!(project: project, name: 'v1.0', effective_date: Date.today + 20 + p_index * 7)
  Version.create!(project: project, name: 'v1.1')
  front = IssueCategory.create!(project: project, name: 'Front')
  IssueCategory.create!(project: project, name: 'Back')

  subjects.rotate(p_index * 5).first(9 + p_index * 2).each_with_index do |subject, i|
    status = i % 7 == 6 ? statuses.detect(&:is_closed?) : open_statuses[i % open_statuses.size]
    issue = Issue.create!(
      project: project, tracker: Tracker.sorted.to_a[i % Tracker.count], author: [admin, alice, bruno][i % 3],
      subject: subject, status: status, priority: priorities[(i + p_index) % priorities.size],
      assigned_to: [admin, alice, bruno, nil][(i + p_index) % 4],
      fixed_version: i.even? ? version : nil, category: i % 3 == 0 ? front : nil,
      start_date: Date.today - 10 + i, due_date: (i % 5 == 4 ? nil : Date.today + (i - 4) * 2),
      estimated_hours: (i % 4) + 1, done_ratio: (i * 10) % 100,
      description: "Contexte de la demande « #{subject} ».\n\nÉtapes pour reproduire, résultat attendu et captures."
    )
    if i % 2 == 0
      journal = issue.init_journal(alice, "Je regarde ça aujourd'hui, retour dans l'après-midi.")
      journal.save!
    end
    issue.add_watcher(admin) if i % 4 == 1
  end
end

puts "Demo data ready. Theme: #{Setting.ui_theme}"
