# Plan de validation

État : tests unitaires rédigés ; exécution Swift, compilation Xcode et essais iPhone à faire. Ne pas confondre contrôles de structure sous Windows et validation fonctionnelle.

## Automatique sur Mac

```sh
swift test
xcodegen generate
xcodebuild -project Intention.xcodeproj -scheme Intention -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Les huit tests couvrent : apprentissage concret, défilement même associé à un objectif utile, négation, ambiguïté, limites de budget, session déjà active, catégorie inconnue et longueur excessive, fenêtre glissante et recul de l’horloge. Le pipeline fourni exécute les tests et une compilation non signée des quatre cibles.

## Sur iPhone (indispensable)

1. Refuser Temps d’écran : pas de sélection ni d’autorisation d’accès. Accepter ensuite et choisir TikTok et X individuellement.
2. Choisir aussi une catégorie : erreur explicite et ancienne sélection intacte.
3. Ouvrir une app protégée : shield Intention visible. Bouton principal : app Intention ouverte sur 26.5+, et bonne app présélectionnée. Sur 26.0–26.4 : ouverture manuelle après fermeture.
4. Dicter une intention avec le clavier puis corriger la transcription ; aucun accès avant validation. Tester dictée désactivée : la saisie écrite fonctionne.
5. « Je veux comprendre comment connecter Supabase à mon app » : 15 minutes. « Je m’ennuie, je vais scroller » : refus. « Nouveautés IA » : clarification.
6. Vérifier Apple Intelligence disponible, indisponible et erreur du modèle : source affichée, fonctionnement conservateur. Tester des tentatives de manipulation ; documenter les erreurs du modèle.
7. Autoriser TikTok : X reste bloqué. Impossible de changer la sélection, de démarrer une deuxième session ou de prolonger la première.
8. Annuler l’analyse, quitter l’app pendant l’analyse : aucune nouvelle session. Revenir après une session expirée : état et shield cohérents.
9. Garder TikTok au premier plan plus de 15 minutes. Refaire avec Intention fermée de force, téléphone en veille à l’échéance, puis redémarrage. Mesurer le délai réel du rebloquage après reprise d’utilisation.
10. Terminer manuellement puis démarrer une autre session : un ancien callback ne doit pas terminer la nouvelle.
11. Trois sessions réservent 45 minutes ; quatrième refusée, même si les précédentes ont été terminées tôt. Vérifier expiration de la fenêtre glissante.
12. Révoquer Temps d’écran dans les réglages : l’interface doit demander une nouvelle autorisation et ne doit pas prétendre protéger l’appareil.
13. Tester changement de fuseau, heure modifiée, panne de stockage App Group et échec de startMonitoring : aucun déblocage si l’enregistrement échoue.
14. Vérifier VoiceOver, taille de police maximale, mode sombre et clavier sur petit iPhone.

## Critère avant diffusion

Compilation des quatre cibles, tests Swift verts et essais 1–14 documentés sur appareil. Si le rebloquage n’est pas fiable, corriger avant diffusion. Ajouter icône, informations de confidentialité et autorisations Family Controls Distribution pour les quatre identifiants avant TestFlight.
