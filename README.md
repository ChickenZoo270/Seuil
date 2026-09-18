# Seuil — MVP iPhone

**Nom de travail : Seuil.** Une pause entre l’impulsion et le choix. Identité porcelaine/bleu pétrole, symbole de passage, typographie système. Le nom interne du projet Xcode reste `Intention` pour conserver la cohérence des modules. La disponibilité commerciale du nom n’a pas été vérifiée.

Une démo interactive accompagne le code iOS dans `Preview/`. Elle se lance avec `npm start` depuis ce sous-dossier, puis s’ouvre sur `http://127.0.0.1:4317`. Les tests de son moteur se lancent avec `npm test`. **Elle simule les autorisations ; elle ne bloque aucune autre app et n’exécute pas l’IA Apple.** Voir `docs/AUDIT.md` pour le bilan réel des vérifications.

Une intention avant d’ouvrir une app protégée. Projet natif SwiftUI, iOS 26 minimum, avec trois extensions Screen Time. **Compilation iOS sans signature réussie sur macOS GitHub le 18 septembre 2026 ; essais sur iPhone physique encore à effectuer.** Les 22 tests web et les tests Swift passent dans [la première vérification distante](https://github.com/ChickenZoo270/Seuil/actions/runs/35349246757).

## Ce qui est implémenté

La démo propose 20 apps (Facebook, Instagram, TikTok, X, Snapchat, Threads, Reddit, Pinterest, LinkedIn, YouTube, Twitch, Netflix, Disney+, Discord, Messenger, WhatsApp, Telegram, Amazon, Vinted, Temu), avec recherche et catégories. Cette liste ne limite pas l’app iOS : celle-ci utilise les jetons d’apps choisis dans le sélecteur Apple. La démo ne détecte pas les installations du téléphone. Les choix restent conservés lors d’une recherche ou d’un rechargement.

- Autorisation personnelle Temps d’écran et sélection privée d’apps via le sélecteur Apple.
- Écran de blocage personnalisé. Sur iOS 26.5+, son bouton ouvre Seuil ; sur iOS 26.0–26.4, il faut ouvrir Seuil manuellement.
- Choix de l’app, intention écrite ou dictée avec le micro du clavier iOS, puis validation explicite. La dictée doit être activée dans Réglages > Général > Clavier. Aucun bouton d’enregistrement propre à l’app dans cette version.
- Classification avec Foundation Models si Apple Intelligence est disponible. Repli annoncé sur une grammaire locale conservatrice en cas d’indisponibilité ou d’erreur. Pas de serveur et pas de clé API.
- Règles fixes : apprentissage concret ou communication précise → 15 minutes ; défilement sans objectif → refus ; ambiguïté → clarification. En mode local, seuls certains débuts de phrases d’apprentissage sont reconnus.
- Une session simultanée, budget glissant de 45 minutes sur 24 heures, déduction de la durée entière dès l’autorisation. Ces valeurs sont les choix initiaux du MVP et peuvent évoluer.
- Extension DeviceActivity pour le rebloquage, bouton de fin anticipée et récupération à la réouverture. La programmation doit réussir avant de retirer le blocage.
- Stockage partagé atomique, verrou entre processus et identifiant unique par session pour ignorer les anciens rappels.

## Construire sur un Mac local ou distant

Prérequis : Xcode avec **SDK iOS 26.5 ou ultérieur**, Swift 6, XcodeGen et compte Apple Developer. La compilation des sources iOS ne peut pas être réalisée avec Windows seul. Le paquet de règles ne dépend pas d’iOS et se teste avec Swift 6.

1. Copier ce dossier sur le Mac, ou le placer à la racine d’un dépôt Git privé.
2. Dans `project.yml`, remplacer les quatre identifiants `com.example.intention…` par les siens et `group.com.example.intention` par son App Group.
3. Installer XcodeGen puis générer le projet :

```sh
brew install xcodegen
xcodegen generate
swift test
open Intention.xcodeproj
```

4. Dans Xcode, choisir la même équipe Apple Developer pour les quatre cibles. Vérifier Family Controls et le même App Group pour chacune. La valeur `INTENTION_APP_GROUP` alimente les entitlements et les Info.plist générés.
5. Sélectionner un iPhone iOS 26+, activer son mode développeur, puis lancer le schéma Intention.
6. Pour TestFlight, demander l’autorisation **Family Controls Distribution pour l’app et chacune des trois extensions** auprès d’Apple. Avoir un abonnement développeur ne vaut pas approbation de cette capacité. L’icône est fournie ; compléter les informations de distribution avant archivage.

Sans Mac personnel, le workflow fourni compile sur un runner macOS GitHub. Le projet est importé dans le dépôt privé `ChickenZoo270/Seuil` et sa première vérification distante est réussie. Le workflow ne signe pas et ne distribue pas l’app ; un pipeline de signature ou un Mac distant est encore nécessaire pour produire un IPA installable/TestFlight. Le runner doit proposer un Xcode avec SDK 26.5+. Voir `docs/IPHONE-NEXT-STEPS.md` pour les étapes demandant le compte Apple.

## Architecture

| Composant | Rôle |
| --- | --- |
| App | Interface SwiftUI, autorisation, classification locale, coordination des sessions |
| Core | Décision déterministe et budget, testables sans iOS |
| Shared | Jetons opaques, état JSON dans App Group, verrou système partagé |
| ShieldConfiguration | Apparence du blocage affiché par iOS |
| ShieldAction | Mémorise l’app demandée et ouvre Seuil si l’OS le permet |
| Monitor | Rebloque à la fin d’une session sans dépendre du processus principal |

Une demande est classée sans transmettre les jetons d’apps au modèle. Le résultat du modèle est limité à une catégorie et un indicateur de précision ; il ne choisit jamais une durée. Avant déblocage, le contrôleur vérifie à nouveau l’autorisation, la sélection, la session active et le budget sous verrou.

Le texte de l’intention reste en mémoire puis est effacé après autorisation. Les jetons, l’échéance et les reçus de budget restent dans le conteneur partagé. La dictée utilise le service du clavier Apple : son traitement dépend des réglages et langues iOS ; nous ne promettons pas que cette partie fonctionne toujours hors ligne.

## Vérification et limites

Voir `docs/TEST-PLAN.md` pour les essais appareil et `docs/OS-CONSTRAINTS.md` pour les références Apple.

Les tests Swift et la compilation iOS sans signature ont réussi sur GitHub Actions. Le workflow `Simulator launch smoke test` vérifie séparément l’installation, le lancement et le relancement en simulateur et conserve les captures pendant sept jours. Il ne teste ni l’autorisation Temps d’écran ni le blocage réel d’autres apps. Le MVP n’est pas annoncé comme prêt pour TestFlight : la signature, les capacités de distribution et les essais physiques restent nécessaires.

Les sessions représentent du temps écoulé, pas 15 minutes de consommation mesurée. Les rappels DeviceActivity sont gérés par iOS : Apple les déclenche lorsque l’appareil est utilisé après la fin de l’intervalle ; ne pas promettre une précision à la seconde. Tester notamment veille, fermeture forcée, redémarrage et changement d’heure. L’autorisation individuelle reste révocable par l’utilisateur : ce n’est pas un verrou inviolable.

Les catégories et sites web sont exclus du MVP : une sélection contenant ces éléments est refusée sans modifier la sélection enregistrée. Le modèle peut mal classer une intention ou être trompé ; le budget limite l’accès, mais ne garantit pas la sincérité. Les règles locales sont volontairement restreintes et peuvent demander de reformuler.
