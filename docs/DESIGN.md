# Seuil — identité et composants

Mise à jour du 18 septembre : la direction actuelle est décrite dans `DESIGN-REVISION.md` (porcelaine froide, bleu pétrole et typographie système). La palette crème/forêt ci-dessous documente la première version et est désormais remplacée. Le catalogue de la démo comporte 20 exemples recherchables ; l’app native utilise le sélecteur Apple et ses icônes réelles.

« Tu choisis. Pas ton fil. » Le nom évoque le passage entre impulsion et intention. C’est un nom de travail, sans validation juridique ou recherche de marque.

## Palette et typographie

| Élément | Valeur web | iPhone |
| --- | --- | --- |
| Fond | Ivoire `#F5F3EC` | Teinte adaptative, fond sombre la nuit |
| Texte | Vert encre `#203C32` | Texte clair en mode sombre |
| Action principale | Forêt `#244D3C` | Accent adaptatif |
| Surface | Blanc chaud `#FFFEFB` | Surfaces système natives |
| Feedback positif | Sauge pâle | Accent atténué + texte explicite |
| Refus/erreur | Terre cuite foncée | Message explicite sans dépendre de la couleur |
| Titres | Georgia, repli sérif | Police système sérif, Dynamic Type |
| Interface | Police système | Police système |

Espacements de 8/12/16/24/32 px, boutons principaux d’au moins 49 px, panneaux de 20–30 px de rayon. Le symbole est une arche ouverte et un trait de passage. Icône iOS opaque 1024 × 1024 fournie dans le catalogue d’assets.

## Composants et états

| Composant | États | Comportement et accessibilité |
| --- | --- | --- |
| App protégée | Choisie / non choisie / absente | Libellé complet, état sélectionné, icône décorative |
| Intention | Vide / saisie / trop longue / analyse | Étiquette visible, 600 caractères max, aucune validation implicite par la voix |
| Bouton principal | Disponible / désactivé / analyse | Une action principale par écran, focus clavier visible |
| Résultat | Autorisé / refusé / à préciser / budget atteint / erreur | Message écrit ; région de statut dans la démo |
| Session | En cours / expirée / terminée | Compteur basé sur une date absolue, fin anticipée explicite |
| Préférences | Ouvertes / sauvegardées / annulées | Dialogue natif web, fermeture Échap, restauration du focus |

Le ton est calme, précis et non culpabilisant. Pas de séries quotidiennes, récompenses ou animations destinées à prolonger l’utilisation. Le navigateur respecte `prefers-reduced-motion`. La démo reste marquée comme simulation, et son budget n’est jamais présenté comme du temps d’écran mesuré.

Le guide design-system a servi à formaliser les couleurs, les états, les interactions clavier et les différences assumées entre SwiftUI et l’aperçu web. L’interface native doit encore être inspectée avec VoiceOver et Dynamic Type sur iPhone.
