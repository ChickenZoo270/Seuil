# Vérifications OS — 17 septembre 2026

## Décisions retenues

Application native SwiftUI, iOS 26+. L’IA Foundation Models est locale et optionnelle selon l’éligibilité Apple Intelligence. Le minimum iOS 26 simplifie ce premier prototype ; une compatibilité iOS 16–18 peut être étudiée ensuite.

Le shield système ne contient pas notre éditeur ni notre dialogue IA. Ces éléments vivent dans l’app principale. Apple documente `ShieldActionResponse.openParentalControlsApp` depuis **iOS 26.5** ; version vérifiée dans les métadonnées officielles du symbole. La branche antérieure ferme le shield et demande une ouverture manuelle. Ne pas utiliser d’API privée ou d’astuce de chaîne de répondeurs.

Une plage DeviceActivity a une durée minimale de **quinze minutes**. Le MVP accorde donc toujours 15 minutes. Des sessions de 5/10 minutes nécessiteraient une autre stratégie et une validation spécifique ; elles ne sont pas simulées par un simple minuteur d’arrière-plan.

`intervalDidEnd` est appelé lorsque l’appareil est utilisé en dehors de l’intervalle, et peut aussi être appelé lors de l’arrêt de la surveillance. Chaque session possède un nom unique ; le callback ne modifie que la session correspondante. Le processus principal réconcilie également les échéances lorsqu’il est actif. Les garanties de délai et la persistance au redémarrage demandent des tests réels.

Family Controls en mode individuel s’obtient avec le consentement du propriétaire. Celui-ci peut révoquer l’autorisation ou supprimer Intention. Les tokens Apple sont opaques : la sélection reste dans le stockage local, et les noms/icônes sont affichés avec `Label(token)`.

## Sources primaires

- [Family Controls](https://developer.apple.com/documentation/familycontrols)
- [Autorisation individuelle](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))
- [Ouvrir l’app depuis le shield](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp)
- [Métadonnées officielles du symbole](https://developer.apple.com/tutorials/data/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp.json)
- [Minimum de quinze minutes](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)
- [Sémantique de fin de surveillance](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))
- [Distribution : demande pour l’app et les extensions](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Disponibilité du modèle local](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
