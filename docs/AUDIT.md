# Audit de Seuil — 17 septembre 2026

## Complément du 18 septembre 2026

Catalogue de démonstration étendu à 20 apps, recherche par nom/catégorie et choix conservés pendant le filtrage. **22 tests automatisés réussis**, dont ajout/sauvegarde/session de chacune des 20 apps, recherche avec casse et accents, compatibilité des sauvegardes antérieures et absence de doublons. Recherche successive de Facebook puis Instagram, sélection et persistance après rechargement vérifiées dans le navigateur. Le plugin Frontend Design a guidé la simplification des titres, la suppression de décorations et le passage à une palette bleu pétrole.

Le catalogue web reste fictif, sans détection des installations. Côté iPhone, `FamilyActivityPicker` reste le sélecteur natif et `Label(ApplicationToken)` affiche les apps sélectionnées : aucune liste de marques codée en dur ne limite les choix. La compilation et les tests iPhone restent non effectués.

## Conclusion

**La démo web est exécutable et ses parcours principaux ont été testés. La version native iOS est un MVP source, non compilé et non validé sur iPhone.** Il serait incorrect d’affirmer que le blocage réel de TikTok/X est déjà testé ou que l’ensemble est sans bug.

## Vérifications effectuées

| Vérification | Résultat |
| --- | --- |
| Tests automatisés du moteur web | 18 réussis, 0 échec, via `node --test Preview/tests/engine.test.mjs` |
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
| Tests Swift | 8 tests fournis, non exécutés |
| Compilation iOS et tests Screen Time | Non effectués : Xcode/Mac indisponible |

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

1. Compiler avec un SDK iOS 26.5+ et corriger tout diagnostic réel de Xcode. La relecture de code n’est pas une compilation.
2. Effectuer les essais iPhone du plan de tests : autorisations, rebloquage réel, fermeture forcée, veille, redémarrage, changement d’heure et erreurs de stockage.
3. Tester la classification Apple Intelligence sur des formulations françaises variées. Le modèle et la grammaire locale peuvent se tromper ; aucune règle ne prouve la sincérité de l’intention.
4. Valider VoiceOver, Dynamic Type et mode sombre dans l’app native.
5. Configurer les identifiants, l’App Group et la signature, obtenir les autorisations Family Controls Distribution, puis signer pour TestFlight. Rien n’a été publié ou envoyé sur le compte Apple.
6. Vérifier la disponibilité du nom Seuil avant une publication commerciale.

L’aperçu navigateur ne remplace pas ces essais. Le bouton « Tester la fin des 15 minutes » avance seulement l’horloge de démonstration. Les autorisations individuelles Apple sont révocables ; l’app n’est pas conçue pour être impossible à contourner.
