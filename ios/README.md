# SplitTheBill pour iPhone

La version native (SwiftUI) de la web app « essai » (`test/index.html`) : même parcours en 5 étapes, même logique de calcul au centime près, même identité « Spritz ».

1. **Ticket** : photo avec le scanner de documents d'iOS, photo de la galerie, texte collé, saisie à la main ou exemple.
2. **Articles** : corriger ce qui a été lu, quantités, pourboire et frais, contrôle avec le total du ticket (« Il manque 2,00 € → Ajouter en frais »).
3. **Participants** : prénoms, avec les noms récents en un toucher.
4. **Attribution** : un toucher = une part (ou une unité pour un article en plusieurs exemplaires), « − » pour corriger, « Tous » pour partager.
5. **Résultat** : la part de chacun, le détail par personne, et le partage par Messages, WhatsApp, la feuille de partage ou le presse-papiers.

## Lecture du ticket

```
Photo ──► Vision (texte, sur l'iPhone) ──► Apple Intelligence ──► articles + total
                                            1. Private Cloud Compute (iOS 27)
                                            2. modèle sur l'iPhone (iOS 26)
                                            3. lecture classique (règles de la web app)
```

- `Scan/ReceiptOCR.swift` : reconnaissance du texte avec Vision, puis recollage des blocs (nom à gauche, prix à droite) ligne par ligne.
- `Scan/ReceiptAI.swift` : génération guidée (`@Generable`) avec le framework Foundation Models. Le modèle **Private Cloud Compute** (`PrivateCloudComputeLanguageModel`) est toujours essayé en premier. Si le cloud ne répond pas (pas de réseau, quota atteint), l’app passe au modèle sur l'iPhone, puis à la lecture classique. L'écran des articles indique quel moteur a lu le ticket.
- `Core/TicketParser.swift` : portage fidèle de `parseTicket` et `cleanOcr` de la web app.

### Activer Private Cloud Compute

Apple réserve le modèle cloud aux apps qui ont l'entitlement géré `com.apple.developer.private-cloud-compute`. Sans lui, iOS ferme l'app dès qu'elle appelle le modèle cloud. Le projet est donc livré avec le drapeau `NO_PCC`, qui retire cet appel. L'app lit alors les tickets avec le modèle sur l'iPhone, ce qui marche avec un compte Apple gratuit (Personal Team).

Pour activer le cloud :

1. Il faut un compte Apple Developer Program payant. Demande l'entitlement sur le site Apple Developer (Certificates, Identifiers & Profiles → ton App ID → *Capability Requests*).
2. Une fois accordé, dans Xcode : cible **SplitTheBill** → *Build Settings* :
   - **Code Signing Entitlements** = `SplitTheBill/SplitTheBill.entitlements` (le fichier est déjà prêt) ;
   - **Active Compilation Conditions** : retire `NO_PCC`.

## Lancer l'app

- Xcode 27 (SDK iOS 27, pour `PrivateCloudComputeLanguageModel`), iPhone sous iOS 26 ou plus récent.
- Apple Intelligence : iPhone 15 Pro ou plus récent, Apple Intelligence activée.
- Ouvre `ios/SplitTheBill.xcodeproj`, choisis ton équipe dans *Signing & Capabilities* (et change l'identifiant `be.splitthebill.app` si besoin), branche ton iPhone, ▶︎.

## Lien depuis le raccourci iPhone

L'app ouvre `splitthebill://ticket?t=<texte du ticket>` : le raccourci peut envoyer le texte lu directement à l'app au lieu du site.

## Tests de la logique

```
cd ios
swift test
```

`Package.swift` ne sert qu'aux tests : il compile `SplitTheBill/Core` (lecture du ticket, attribution, calcul et arrondi) sans simulateur. Les résultats attendus ont été vérifiés avec le code JavaScript de la web app.
