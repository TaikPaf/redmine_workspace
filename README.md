# Redmine Workspace

Plugin Redmine 7 qui simplifie le travail au quotidien : retrouver ses demandes, voir ses projets et filtrer sans passer par les 50 filtres de Redmine.

Il est conçu pour aller avec le thème [Glassfluid](https://github.com/TaikPaf/redmine_theme) et le plugin [Kanban](https://github.com/TaikPaf/redmine_kanban), mais il fonctionne aussi sans eux.

## Fonctionnalités

- **Mon espace** (`/workspace`) :
  - vos demandes ouvertes classées par urgence (en retard, cette semaine, plus tard, sans échéance), avec des échéances relatives (« -3 j », « ven. ») ;
  - les onglets *Assignées à moi*, *J'ai créé* et *Je surveille* ;
  - l'onglet *Activité* : ce qui a changé sur vos demandes depuis votre dernière visite.

  Option : en faire la page d'accueil des utilisateurs connectés.
- **Projets** (`/workspace/projects`) : une liste, avec les sous-projets sous leur parent. Pour chaque projet, on voit les demandes ouvertes, celles assignées à vous et celles en retard, puis la version en cours avec son avancement et la dernière activité. Une vue en grille (cartes) est aussi disponible, et le choix est mémorisé. L'étoile ajoute un projet aux favoris de Redmine. On peut filtrer par nom, favoris, « mes projets » ou « avec du retard ».
- **Vues rapides** au-dessus de chaque liste de demandes : *Mes demandes*, *Mes retards*, *En retard*, *Non assignées*, *Priorité haute*, *Mises à jour cette semaine*, *Je surveille*, avec leur nombre. Les requêtes enregistrées de Redmine suivent sous forme d'onglets, avec un bouton *Enregistrer la vue*.
- **Barre d'actions groupées** : dès qu'une demande est cochée dans une liste, une barre en bas de l'écran indique le nombre de demandes sélectionnées. Elle ouvre le menu d'actions de Redmine (statut, assignation, version…) et permet de tout désélectionner.
- **Raccourcis clavier** (`?` pour la liste) : `g m` Mon espace, `g p` Projets, `g i` Demandes, `g k` Kanban, `/` recherche, `c` nouvelle demande, `j` / `k` ligne suivante ou précédente, `p` aperçu de la ligne.
- **Recherche en langage simple** : par exemple `moi en retard prio:haute export`. La ligne « Compris : » montre comment la phrase a été interprétée, et chaque critère se retire d'un clic. Les filtres et options d'affichage classiques de Redmine restent disponibles derrière les boutons *Filtres* (avec le nombre de filtres actifs) et *Affichage*.
- **Icônes de statut et de priorité**, identiques dans Mon espace, les listes de demandes, la page d'une demande et le Kanban. Chaque statut appartient à une catégorie (Backlog, À faire, En cours, En revue, Terminé, Annulé) qui a son icône et sa couleur. Les catégories sont devinées à partir du nom des statuts et se règlent dans la configuration du plugin. La priorité s'affiche en barres (1 à 3), avec une icône rouge pour les deux plus hautes.
- **Palette Ctrl+K** (⌘K sur Mac), sur toutes les pages : aller à une demande (`#123`), à un projet, chercher dans les sujets, lancer une action (`>`).
- **Navigation de gauche** : Mon espace, Projets, Demandes, Kanban, Temps passé et projets favoris. En bas : les liens de la barre du haut de Redmine (Administration, Aide…), le compte, le mode clair ou sombre et la déconnexion.
  - À partir de 1280 px, elle est complète. Un bouton la réduit en colonne d'icônes, et ce choix est mémorisé.
  - Entre 900 et 1279 px, elle est réduite en icônes par défaut.
  - Sur téléphone, elle est remplacée par une barre d'onglets en bas : Mon espace, Demandes, Recherche, Kanban et Plus (le menu de Redmine).
- **Page d'une demande en deux colonnes** : description, sous-tâches et historique à gauche ; à droite, une colonne qui reste visible au défilement avec les propriétés (modifiables en un clic), puis les observateurs et le reste de la barre latérale de Redmine.
- **Aperçu latéral** : le bouton d'aperçu, qui apparaît au survol d'une ligne dans les listes de demandes, dans Mon espace et sur les cartes du Kanban, ouvre la demande dans un panneau à droite sans quitter la page. On y modifie les propriétés en un clic et on ajoute une note (Ctrl+Entrée). Les flèches ↑ ↓ passent à la demande précédente ou suivante, Échap ferme le panneau. La page se recharge à la fermeture si quelque chose a été modifié.
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
