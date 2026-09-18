# Audit de Seuil — 17 septembre 2026

## Complément du 18 septembre 2026

Catalogue de démonstration étendu à 20 apps, recherche par nom/catégorie et choix conservés pendant le filtrage. **22 tests automatisés réussis**, dont ajout/sauvegarde/session de chacune des 20 apps, recherche avec casse et accents, compatibilité des sauvegardes antérieures et absence de doublons. Recherche successive de Facebook puis Instagram, sélection et persistance après rechargement vérifiées dans le navigateur. Le plugin Frontend Design a guidé la simplification des titres, la suppression de décorations et le passage à une palette bleu pétrole.

Le catalogue web reste fictif, sans détection des installations. Côté iPhone, `FamilyActivityPicker` reste le sélecteur natif et `Label(ApplicationToken)` affiche les apps sélectionnées : aucune liste de marques codée en dur ne limite les choix. La compilation distante est désormais réussie ; les essais sur iPhone restent non effectués.

### Vérification distante du 18 septembre

Dépôt privé `ChickenZoo270/Seuil`, commit `8f80be8a7f63353cf2df0a3143d997253c28b649` : [GitHub Actions, exécution 35349246757](https://github.com/ChickenZoo270/Seuil/actions/runs/35349246757), statut **Success**. Les trois tâches `preview-tests`, `core-tests` et `ios-build` ont réussi. Le premier import via l’éditeur web avait créé un workflow vide ; corrigé, l’import suivant a réussi. Les avertissements de CI concernent la transition du runtime Node des actions v4 ; ils ne constituent pas des tests métier échoués.

### Lancement natif et contrôle d’accessibilité ciblé

Le [premier test simulateur](https://github.com/ChickenZoo270/Seuil/actions/runs/35390900479) a réussi : compilation, installation, lancement, fermeture puis relancement, avec contrôle que le processus reste vivant et captures PNG. Le journal identifie Xcode 26.6, SDK simulateur 26.5 et une destination iPhone 17 Pro / iOS 26.4 ; **ce n’est pas un test de l’iPhone 16 Pro sous iOS 26.7 de l’utilisateur**. Les fichiers téléchargés correspondent au SHA-256 publié par GitHub : `453cb021b23313805c2050e575346cd1391ec7bcfc8350ff284530d516fb9606`.

La capture expose une erreur de conteneur App Group sur cette version non signée. Ce résultat est conservé comme limite de configuration, pas dissimulé ni présenté comme une protection fonctionnelle. Aucun test du sélecteur, de l’autorisation ou du rebloquage réel n’a été réalisé en simulateur.

La revue visuelle a repéré un bouton principal au texte trop sombre et des textes secondaires trop pâles. Correction native : couleurs explicites pour les boutons et le texte secondaire, adaptées aux deux apparences. Contrastes calculés des couleurs nominales selon WCAG 2.1 : bouton clair **8,24:1**, bouton sombre **9,80:1**, texte secondaire sur le fond clair **5,59:1**, sur le fond sombre **9,57:1** (objectif 4,5:1). Ce contrôle ne couvre pas les états désactivés, tous les fonds système, VoiceOver ou Dynamic Type. [Tests et compilation du correctif réussis](https://github.com/ChickenZoo270/Seuil/actions/runs/35391502977).

Le [second test simulateur, après correction](https://github.com/ChickenZoo270/Seuil/actions/runs/35391503074), est également **réussi** (commit `d7b661d`). La capture de lancement a été inspectée : texte blanc lisible sur le bouton, textes secondaires assombris, erreur de stockage partagé toujours explicite. Archive vérifiée : `3cfd551d4adabbaa2bd3c9e1e1c8b71209e51495d2969c03a7a0a4ffec901127`. Les captures sont des preuves de lancement et d’apparence initiale, **pas de protection Temps d’écran opérationnelle**. Le thème sombre n’a pas été contrôlé visuellement dans ce passage.

## Conclusion

**Audit de préparation à la diffusion : 45/100, diffusion bloquée tant que signature et essais iPhone ne sont pas terminés.** Ce score est une appréciation qualitative, pas une mesure de fiabilité. La démo web est exécutable et ses parcours principaux ont été testés. La version native iOS compile sans signature, mais n’est pas validée sur iPhone. Il serait incorrect d’affirmer que le blocage réel de TikTok/X est déjà testé ou que l’ensemble est sans bug.

## Vérifications effectuées

| Vérification | Résultat |
| --- | --- |
| Tests automatisés du moteur web | 22 réussis, 0 échec, localement et en CI |
| Syntaxe des scripts du navigateur et du serveur | Vérifiée avec Node |
| Intention précise dans le navigateur | Session de 15 min, bonne app sélectionnée, budget +15 |
| Défilement sans objectif | Refus, budget inchangé |
| Intention vague | Demande de précision, pas de session |
| Rechargement pendant une session | Même échéance, compteur poursuivi, budget conservé |
| Fin de session simulée | Retour à l’écran d’intention, statut de rebloquage simulé |
| Fin anticipée | Session terminée, minutes toujours réservées |
| Quatrième session après 45 minutes | Refus explicite |
| Retrait de toutes les apps | Message d’état vide et validation désactivée |
| Présentation mobile et ordinateur | Inspectée dans le navigateur, aucun débordement horizontal à la largeur mobile testée |
| Console navigateur au moment du contrôle | Aucun avertissement/erreur capturé |
| Contrastes après correction | Aucun échec dans le contrôle automatique des textes visibles de l’accueil ; ce contrôle ciblé n’est pas une certification WCAG |
| Serveur de démonstration | Pages et modules servis en 200 ; accès hors liste autorisée refusé en 404 |
| Entitlements Apple | XML lisible, clés Family Controls et App Groups présentes |
| Icône | PNG opaque 1024 × 1024 généré et référencé dans le catalogue d’assets |
| Tests Swift | Tâche `core-tests` réussie sur macOS GitHub ; suite de 8 tests |
| Compilation iOS | App et trois extensions compilées sans signature, tâche `ios-build` réussie |
| Tests Screen Time sur appareil physique | Non effectués ; bloquants avant diffusion |

La dictée réelle n’a pas été testée : aucun microphone n’a été ouvert ni autorisé pendant l’audit. La version native utilise la dictée du clavier iOS ; la démo utilise, s’il existe, le service vocal du navigateur avec un repli écrit.

## Problèmes repérés et corrigés pendant l’audit

- **Arrêt entre enregistrement et déblocage :** ajout d’un état `isArmed`. La session ne peut retirer un blocage qu’après programmation effective et confirmation persistée. Au retour, une session non confirmée est abandonnée et sa réservation remboursée.
- **Surveillance disparue :** l’app vérifie que la surveillance existe avant de restaurer une session. Sinon elle rebloque.
- **Rappel tardif d’une ancienne session :** noms UUID et vérification d’identité avant toute modification.
- **Accumulation des plages de surveillance :** arrêt de la plage terminée après traitement du callback.
- **Échec de sauvegarde en fin manuelle :** arrêt de la surveillance malgré l’erreur pour empêcher une restauration ultérieure de l’accès par la réconciliation.
- **Focus clavier de la démo :** les boutons d’app ne sont plus reconstruits à chaque seconde.
- **Contraste :** textes secondaires et placeholders assombris après mesure des rapports de contraste.
- **Cibles tactiles :** dictée, exemples et boutons texte ont une hauteur minimale de 44 px.
- **Message périmé après modification des apps :** remplacé par une confirmation de la sélection.

## Risques restants et conditions de diffusion

1. Conserver la compilation iOS et les tests verts à chaque changement. La première compilation distante a réussi ; elle ne prouve pas le fonctionnement des services Screen Time sur appareil.
2. Effectuer les essais iPhone du plan de tests : autorisations, rebloquage réel, fermeture forcée, veille, redémarrage, changement d’heure et erreurs de stockage.
3. Tester la classification Apple Intelligence sur des formulations françaises variées. Le modèle et la grammaire locale peuvent se tromper ; aucune règle ne prouve la sincérité de l’intention.
4. Valider VoiceOver, Dynamic Type et mode sombre dans l’app native.
5. Configurer les identifiants, l’App Group et la signature, obtenir les autorisations Family Controls Distribution, puis signer pour TestFlight. Rien n’a été publié ou envoyé sur le compte Apple.
6. Vérifier la disponibilité du nom Seuil avant une publication commerciale.

L’aperçu navigateur ne remplace pas ces essais. Le bouton « Tester la fin des 15 minutes » avance seulement l’horloge de démonstration. Les autorisations individuelles Apple sont révocables ; l’app n’est pas conçue pour être impossible à contourner.
