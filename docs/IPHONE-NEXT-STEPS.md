# Installer Seuil sur ton iPhone : ce qui reste

## Situation au 18 septembre 2026

Le code est dans le dépôt privé [ChickenZoo270/Seuil](https://github.com/ChickenZoo270/Seuil). Les tests web, les tests Swift et la compilation iOS sans signature ont réussi. Ni Vercel ni Supabase ne sont nécessaires : pas de serveur, de compte utilisateur Seuil ou de clé API de classification. Le modèle Apple est local quand disponible ; sinon l’app utilise ses règles locales.

Ce dépôt n’est pas encore une app installable. Un fichier compilé sans signature ne s’installe pas sur un iPhone physique. Le simulateur ne remplace pas les essais de protection réelle.

## Étapes nécessitant ton compte Apple

1. Ouvrir le compte Apple Developer et relever l’équipe de développement (Team ID). Ne pas envoyer de mot de passe, code 2FA, certificat privé ou clé API dans la conversation.
2. Choisir et enregistrer un identifiant unique pour l’app, trois identifiants pour les extensions et un App Group commun. Les valeurs `com.example.intention…` dans le projet sont des exemples, pas des identifiants de distribution prêts.
3. Activer les capacités Family Controls et App Groups appropriées sur les quatre cibles et associer le même groupe. Mettre à jour `project.yml` avec ces valeurs.
4. Demander à Apple Family Controls Distribution pour l’app **et chacune des trois extensions**. L’abonnement Developer ne remplace pas ces approbations. Prévoir un délai et une éventuelle demande d’informations d’Apple.
5. Créer la fiche de l’app dans App Store Connect, puis préparer les certificats et profils de distribution. Leur configuration doit être validée par le propriétaire du compte.
6. Configurer un build signé sur Mac distant ou CI. Si des secrets sont nécessaires, les entrer directement dans le gestionnaire de secrets du service, jamais dans les sources ni dans le chat. Restreindre ces accès au strict nécessaire.
7. Archiver, exporter et envoyer vers TestFlight, puis installer via l’invitation Apple sur l’iPhone 16 Pro. Une validation Apple supplémentaire peut s’appliquer selon le type de testeurs.

## Première vraie séance de test

- Autoriser Temps d’écran, choisir une app de test peu importante, vérifier son écran de blocage.
- Depuis le blocage, ouvrir Seuil, saisir puis dicter une intention, vérifier refus, précision et autorisation.
- Vérifier que seule l’app choisie est débloquée, puis qu’elle est rebloquée après la session de 15 minutes et après une fin anticipée.
- Répéter avec Seuil fermée, écran éteint et après redémarrage ; vérifier les notifications/autorisation révoquée et la restauration.
- Essayer Apple Intelligence disponible puis indisponible, le budget de 45 minutes, VoiceOver et les grandes tailles de texte.

Consigner les résultats dans `TEST-PLAN.md`. Aucun résultat physique n’est actuellement déclaré réussi.

## Coûts et limites

Aucun appel à une API IA payante n’est intégré. Le compte développeur Apple, les minutes macOS de CI au-delà du quota du compte et un éventuel Mac distant sont des postes distincts. Aucun achat ou abonnement supplémentaire n’a été activé par l’agent. Vérifier le quota GitHub avant des campagnes répétées de compilation.

Le propriétaire peut révoquer Temps d’écran : Seuil est un outil d’engagement personnel, pas un verrou inviolable. Une classification IA peut se tromper ; le budget reste déterministe. La disponibilité commerciale du nom reste à vérifier avant lancement.
