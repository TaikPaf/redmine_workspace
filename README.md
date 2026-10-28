# Redmine Workspace

Plugin Redmine 7 qui simplifie le travail au quotidien : retrouver ses demandes, voir ses projets et filtrer sans passer par les 50 filtres de Redmine.

Il est conçu pour aller avec le thème [Glassfluid](https://github.com/TaikPaf/redmine_theme) et le plugin [Kanban](https://github.com/TaikPaf/redmine_kanban), mais il fonctionne aussi sans eux.

## Fonctionnalités

- **Mon espace** (`/workspace`) :
  - vos demandes ouvertes classées par urgence (en retard, cette semaine, plus tard, sans échéance), avec des échéances relatives (« -3 j », « ven. ») ;
  - les onglets *Assignées à moi*, *J'ai créé* et *Je surveille* ;
  - l'onglet *Activité* : ce qui a changé sur vos demandes depuis votre dernière visite.

  Option : en faire la page d'accueil des utilisateurs connectés.
- **Projets** (`/workspace/projects`) : une carte par projet avec les demandes ouvertes, assignées à vous et en retard, et l'avancement de la version en cours. L'étoile ajoute un projet aux favoris de Redmine. On peut filtrer par nom, favoris, « mes projets » ou « avec du retard ».
- **Vues rapides** au-dessus de chaque liste de demandes : *Mes demandes*, *Mes retards*, *En retard*, *Non assignées*, *Priorité haute*, *Mises à jour cette semaine*, *Je surveille*, avec leur nombre.
- **Recherche en langage simple** : par exemple `moi en retard prio:haute export`. La ligne « Compris : » montre comment la phrase a été interprétée, et chaque critère se retire d'un clic. Les filtres et options d'affichage classiques de Redmine restent disponibles derrière les boutons *Filtres* (avec le nombre de filtres actifs) et *Affichage*.
- **Icônes de statut et de priorité**, identiques dans Mon espace, les listes de demandes, la page d'une demande et le Kanban. Chaque statut appartient à une catégorie (Backlog, À faire, En cours, En revue, Terminé, Annulé) qui a son icône et sa couleur. Les catégories sont devinées à partir du nom des statuts et se règlent dans la configuration du plugin. La priorité s'affiche en barres (1 à 3), avec une icône rouge pour les deux plus hautes.
- **Palette Ctrl+K** (⌘K sur Mac), sur toutes les pages : aller à une demande (`#123`), à un projet, chercher dans les sujets, lancer une action (`>`).
- **Navigation de gauche** (écrans de 1100 px et plus) : Mon espace, Projets, Demandes, Kanban, Temps passé et projets favoris.
- **Changement de statut en un clic** sur la page d'une demande (« Passer à : »). Seuls les statuts autorisés par le workflow sont proposés.
- **Édition en un clic** des champs d'une demande : statut, priorité, assigné, catégorie, version, dates, avancement, temps estimé et champs personnalisés simples (texte, nombre, date, oui/non, liste, utilisateur, version). Un clic sur la valeur ouvre l'éditeur. Un choix dans la liste, ou Entrée, enregistre. Échap annule. La modification passe par Redmine : workflow, champs en lecture seule ou obligatoires, historique et notifications sont respectés, et une modification faite entre-temps par quelqu'un d'autre est signalée.

### Mots compris par la recherche simple

| Écrire | Effet |
| --- | --- |
| `moi`, `@alice`, `assigne:bruno`, `nonassigne` (ou `non assigné`) | assigné à |
| `retard`, `aujourdhui`, `semaine`, `mois` | échéance |
| `ouvert`, `ferme`, `tous`, `statut:en-cours` | statut (par défaut : ouvert) |
| `prio:haute`, `prio:basse`, `urgent` | priorité |
| `bug`, `tracker:evolution` | tracker |
| `projet:infra`, `version:1.2` | projet, version |
| `suivi`, `auteur:moi`, `maj:semaine` | surveillées, créées par, mises à jour |
| `#123` | ouvre la demande |
| tout autre mot | recherche dans le texte (sujet, description, notes) |

Les mots anglais équivalents fonctionnent aussi (`me`, `overdue`, `open`, `closed`, `watched`…).

## Installation

```bash
cd /chemin/vers/redmine/plugins
git clone https://github.com/TaikPaf/redmine_workspace.git
```

Redémarrez Redmine. Le plugin n'a pas de migration de base de données : il utilise les préférences utilisateur de Redmine. L'option « Mon espace comme page d'accueil » et les catégories de statut se trouvent dans *Administration → Plugins → Redmine Workspace → Configurer*.

## Développement

Le dossier `dev/` lance un Redmine 7.0.2 avec ce plugin, le plugin Kanban et le thème Glassfluid. Les trois dépôts doivent être côte à côte, dans le même dossier parent.

```bash
cd dev
docker compose up -d redmine
docker compose exec redmine bundle exec rails runner plugins/redmine_workspace/dev/seed.rb
```

Ouvrez ensuite http://localhost:3000 (compte `admin` / `admin`, celui par défaut de Redmine, à n'utiliser qu'en local). Les modifications sont prises en compte sans redémarrage, sauf celles de `init.rb`.

Pour lancer les tests :

```bash
docker compose --profile test run --rm test
docker compose --profile test run --rm -e PLUGIN=redmine_kanban test
```

## Licence

GPL v2 ou ultérieure, comme Redmine. Voir le fichier `LICENSE`.
