# UniCoach final design update

## Design references

The source is the user-supplied `UniCoach final.fig` export from 10 November 2026 and the matching [UniCoach Figma file](https://www.figma.com/design/yODJZhleuTYI4bKW0NTChD/UniCoach?node-id=19-733). The design was inspected read-only with the Figma plugin.

High-fidelity design context and reference screenshots were obtained for Home (`19:733`), Learning Overview (`19:491`), Subjects (`47:611`), Add Subject (`49:3177`), Assignments Overview (`47:2407`), subject assignments (`53:4232`), assignment Details (`61:326`), Questions (`64:777`, `65:1399`) and Progress (`4:9265`).

Figma's Starter-plan tool limit blocked the final Feedback and Review frames (`66:1898`, `66:2317`, `68:119`). Their field names and copy were inspected in the local export. Their mobile layout follows the verified Details and Questions screens; an exact visual comparison of those three frames remains unverified.

Desktop sidebars and tables are adapted to native iPhone navigation, stacked cards and forms. Existing Inter typography and adaptive colors are retained. Example names, grades, dates and progress values in the design are replaced by the student's local records. UniCoach remains the app name.

The design's automatic analysis on assignment confirmation is intentionally separated from saving. Students must still select and approve their sources and request before each analysis. Native keyboard dictation remains available; the app does not add a cloud speech service. Import controls identify their supported file types.

## Bundled illustrations

All illustration files are local assets. Figma download URLs are never used at runtime.

| Asset | Design source | Placement |
| --- | --- | --- |
| SubjectActionHero | `47:611`, imgImage4 | Subjects tab header |
| SubjectBookHero | `49:3177`, imgImage6 | Add/edit subject introduction |
| AssignmentsHero | `47:2407`, imgImage7 | Assignment dashboard header |
| AssignmentOverviewHero | `47:2407`, imgImage9 | Goals tab header |
| AssignmentSubjectHero | `53:4232`, imgImage9 | Retained artwork; former insight banner removed |
| AssignmentDocumentHero | `61:326`, imgImage6 | Assignment wizard introduction |
| MentorBrandIcon | Exact copy of the bundled AppIcon image | Static mentor welcome and message avatars |

The mentor now uses the UniCoach app icon, copied unchanged into a regular image set for runtime use. Welcome and message icons are static, retain their existing frame sizes and do not imply a human tutor is present. The earlier generated terrier and its animation were removed at the user's request on 11 November 2026; its generation provenance remains in Git history.

## Requested layout refinement, 11 November 2026

The Assignments section now places its illustration immediately after the title and add action, followed by Assignment progress and all four status cards. Subject and feedback filters remain below the cards, followed by marks, calendar and assignment records. The Overall insights and Subject insights banners were removed. Subjects and Goals each begin with a matching illustrated header beneath their title and add action. These changes follow the user's later layout request and reuse the approved local artwork; no new Figma assets or generated artwork were needed.
