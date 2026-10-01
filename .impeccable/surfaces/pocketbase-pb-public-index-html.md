---
version: 1
slug: "pocketbase-pb-public-index-html"
primary_target: "pocketbase/pb_public/index.html"
related_targets: []
---

## Scope and mode
The admin page: Home Assistant sidebar panel at `/_setup/` (or `/` with no app UI). Operate.

## Audience, job, action
The Home Assistant owner, already signed in to Home Assistant. Job: know what runs and what needs
attention, then act: commit or apply a drop-in migration, hand an app its login (QR / link), move
the app UI (update, or change its source), open the dashboard.

## Proof and content
Real state only, from the backend: version + commit, add-on update, drop-ins with their state and
path, setup link (password masked), app UI release and source. No counts or claims beyond that.

## Constraints
Inside an ingress iframe; relative URLs; works at 320 px in the Home Assistant phone app; secrets
only after the Home Assistant sign-in; Apply restarts the add-on and says so.

## Direction and memorable moment
Release notes (seed b54e97d7): "Running 0.1.8" as the page's heading, then **Unreleased**: what
exists only on this device, in amber, with the action that makes it released.

## Unresolved
A light variant for Home Assistant's light theme (the page is dark-only).
