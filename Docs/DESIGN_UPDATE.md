# UniCoach final design update

## Design references

The source is the user-supplied `UniCoach final.fig` export from 10 November 2026 and the matching [UniCoach Figma file](https://www.figma.com/design/yODJZhleuTYI4bKW0NTChD/UniCoach?node-id=19-733). The design was inspected read-only with the Figma plugin.

High-fidelity design context and reference screenshots were obtained for Home (`19:733`), Learning Overview (`19:491`), Subjects (`47:611`), Add Subject (`49:3177`), Assignments Overview (`47:2407`), subject assignments (`53:4232`), assignment Details (`61:326`), Questions (`64:777`, `65:1399`) and Progress (`4:9265`).

Figma's Starter-plan tool limit blocked the final Feedback and Review frames (`66:1898`, `66:2317`, `68:119`). Their field names and copy were inspected in the local export. Their mobile layout follows the verified Details and Questions screens; an exact visual comparison of those three frames remains unverified.

Desktop sidebars and tables are adapted to native iPhone navigation, stacked cards and forms. Existing Inter typography and adaptive colors are retained. Example names, grades, dates and progress values in the design are replaced by the student's local records. UniCoach remains the app name.

The design's automatic analysis on assignment confirmation is intentionally separated from saving. Students must still select and approve their sources and engine before each analysis. Native keyboard dictation remains available; the app does not add a cloud speech service. Import controls identify their supported file types.

## Bundled illustrations

All illustration files are local assets. Figma download URLs are never used at runtime.

| Asset | Design source | Placement |
| --- | --- | --- |
| SubjectActionHero | `47:611`, imgImage4 | Subject action card |
| SubjectBookHero | `49:3177`, imgImage6 | Add/edit subject introduction |
| AssignmentsHero | `47:2407`, imgImage7 | Assignment dashboard header |
| AssignmentOverviewHero | `47:2407`, imgImage9 | Overall assignment insight |
| AssignmentSubjectHero | `53:4232`, imgImage9 | Selected subject insight |
| AssignmentDocumentHero | `61:326`, imgImage6 | Assignment wizard introduction |
| MentorMascot | Generated illustration | Mentor welcome and message avatars |

The white Scottish terrier is the AI mentor mascot. It has a gentle idle greeting animation and remains still with Reduce Motion enabled. Small message avatars use restrained styling. The mascot does not imply that a human tutor is typing. It was created using the built-in image-generation tool and saved as `App/Assets.xcassets/MentorMascot.imageset/image.png` with transparency.

Generation prompt:

> Use case: stylized-concept. Asset type: transparent production mascot for UniCoach, an iPhone study mentor chat. Primary request: one friendly WHITE SCOTTISH TERRIER dog mascot. Recognizable Scottie proportions: long rectangular bearded muzzle, jaunty upright triangular ears, expressive small dark eyes beneath shaggy eyebrows, short legs, compact long body, upright short tail. White fur with delicate warm grey and cream shadows, dark charcoal nose and fine forest-green outline details. Friendly, alert, supportive personality suitable for university students. Style: polished simple flat vector-like illustration with soft shading, rounded forms, crisp readable silhouette, minimal chunky fur details. Three-quarter front view seated, head gently tilted toward viewer, small mint-green neckerchief matching forest-green and pale-mint app colors. Single dog centered in square, all ears, paws and tail fully visible with 8 percent transparent breathing room. Should remain recognizable as a 40-pixel chat avatar and a 100-pixel welcome mascot; will receive gentle breathing and greeting motion in app code. True alpha transparency, no background, no disc, no ground shadow, no scenery, no text, no watermark, no speech bubble, no owl, no props, no human features, no 3D plastic, no photorealism.
