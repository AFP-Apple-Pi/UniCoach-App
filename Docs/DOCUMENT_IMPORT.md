# Subject and assignment document import

Add subject and Add assignment use the same PDF/photo import screen. Files accepts PDF, JPG and PNG; Photos accepts an image. PDFKit reads selectable text, and Vision performs local OCR on images and PDF pages without text. Reading does not invoke a language model or send data over a network.

The review screen contains editable subject details and individually selectable assignments. Deadlines remain unset when absent. Assessment weighting is separate from earned marks. Saving commits the reviewed subject and selected assignments together, with their actual subject links and source filename/page/excerpt references. It does not create submitted work, tutor feedback, reflections or personal grades.

A matching subject code and session defaults to the existing subject. Updating its details is off until explicitly selected. Likely duplicate assignment titles or a duplicate new subject require a visible copy choice. Users can choose another destination or create a missing subject.

UTS-style outlines are parsed locally. When required structure is missing, a ready Apple model can suggest fields after the user reviews and approves the exact extracted text. Only exact source excerpts are accepted into suggested fields; suggestions still need review. There is no automatic cloud fallback. Model suggestions require a request that fits the runtime model budget and the 50,000-character ceiling; the screen asks for a shorter excerpt when necessary. Long document reading itself allows up to 24 MB, 80 pages and 100,000 extracted characters. These bounds do not change the mentor's existing long-context pipeline.

## Normal-use validation

Validation results are recorded in DEVICE_TESTING.md. This task deliberately uses one PDF, one JPG and one PNG normal-use case, without expanding incorrect-input or edge-case coverage. The PDF was the user's explicitly authorized six-page UTS subject outline. It is not included in this repository. The JPG and PNG contain fictional assessment information.

The opt-in `testDocumentImportPDFAndScreenshots` case uses real file URLs, the production PDF/image reader and OCR, the review UI and the real store save. The native Files/Photos selection interfaces are not automated. A DEBUG-only selector supplies a basename in the app's `Documents/Import Fixtures` directory, and additionally requires a `-ui-smoke` or `-ui-smoke-preserve` argument. Normal launches cannot use that selector. The test store is separate from normal data.

To reproduce on an authorized device:

1. Generate the fictional images with `swift AppTests/Fixtures/make_document_import_images.swift OUTPUT_DIRECTORY` on macOS.
2. Place the authorized UTS outline in the same directory as `Subject outline.pdf`. The image generator creates `Canvas assessment.jpg` and `Subject screenshot.png`.
3. Build for testing with your normal signing overrides and `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`. This project does not otherwise define the DEBUG symbol. No project signing settings need changing.
4. Copy the fixture directory to the app container at `Documents/Import Fixtures`.
5. Set `UNICOACH_RUN_DOCUMENT_IMPORT=1` in the test runner environment of a copied xctestrun file, then run only `UniCoachUITests/UniCoachUITests/testDocumentImportPDFAndScreenshots`.
6. Read back the isolated `ui-smoke.json` to verify saved relationships, weights, deadlines and source references. Launch normally without test flags and verify the normal store is unchanged.

The test expects the PDF to create subject 32405 and four assessments, the JPG to add Research synthesis memo to that subject, and the PNG to create subject 55501 with Prototype walkthrough. No malformed-input, scanned-PDF, Photos-picker, broad accessibility or general model-quality claim follows from these three cases.
