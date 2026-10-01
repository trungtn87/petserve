# Game Petserve — Project Source of Truth

Canonical design + implementation checklist:
https://docs.google.com/document/d/12AaKFQDsXhy-Is5clRDwzzmJFMVocb4ztG1R9qfcLKg/edit

## Mandatory sync rule

Every commit must update the Google Drive project document in the same work session.

Every design change must update the document even when no code is committed.

For each update:
- update the affected Stage / Milestone checklist;
- mark superseded decisions instead of silently replacing them;
- add a CHANGE LOG entry with date, commit SHA (or DESIGN-ONLY), scope and status;
- if code and document disagree, mark the mismatch as CONFLICT until resolved.

The active development branch is `pethome`.
