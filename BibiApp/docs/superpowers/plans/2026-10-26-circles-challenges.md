# Circles and Challenges Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The user authorized direct execution without another approval round.

**Goal:** Replace Live and Voice with Shorts, Circles, Challenges, Chats and Me.

**Architecture:** Extend the existing atomic LocalLibrary with optional community state and add focused UIKit controllers. Reuse short-video creation, profile/chat routes, native photo selection and safety storage.

**Tech Stack:** Swift 5, UIKit, AVFoundation, iOS 16+.

**Spec:** docs/superpowers/specs/2026-10-26-circles-challenges-design.md

## Global Constraints

- All project content is English; conversational replies are Chinese.
- Preserve im.seex.sao2-neiku-30 and JPTS6M4T5B.
- No build, typecheck, tests, app launch, simulator or preview; inspect source/config/resources only.
- Persist before reporting success; do not fabricate network capabilities.

## Review Focus

- Old library decoding and failed writes retain prior state.
- Deleted or reported videos cannot remain playable through new routes.
- Duplicate taps cannot create duplicate entries or lose unrelated writes.
- Image imports have bounded memory and cancellation behavior.
- Five-item dock geometry and keyboard-safe forms remain consistent.

## Tasks

- [x] 1. Add CommunityModels.swift and AppStore+Community.swift; extend LocalLibrary and safety kinds. Add join, posting, comments, save, deletion and challenge entry mutations through commit(_:).
- [x] 2. Add Circles and Challenges controllers, composition and personal activity routes. Extend queueCreation with optional challenge ID and atomic entry attachment.
- [x] 3. Replace discovery with a Shorts root, change dock to five items, remove room controllers and creation routes; preserve legacy data decoding.
- [x] 4. Regenerate Xcode metadata, update current docs and perform a fresh static review. Record unverified runtime scope.

## Execution rulings

- Work in the provided directory: the entire app is untracked, so a worktree would omit the user's implementation. No baseline commit or bulk staging is authorized by this feature request.
- Static review replaces TDD execution because AGENTS.md explicitly forbids tests/build/typecheck without a request. No test-success claim will be made.
- Existing raster art and semantic palette take precedence over generic web-oriented design recommendations.

## Completion ledger

- Tasks 1–3: implemented and inspected statically; runtime verification intentionally not performed.
- Task 4: XcodeGen metadata regeneration succeeded; static audit 425/425 checks, plist lint passed; current docs and constraints updated.
- Final reviewer findings: three confirmed, all fixed (creation/More overlap, whole-photo allocation before limit, pending-video share links).
- Review rulings: backend services, earlier call/wallet behavior and legacy serialized keys remain outside this change; device/runtime claims remain unverified by explicit workspace instruction.
- No commits, bulk staging, branch changes or baseline creation were performed because the provided application is entirely untracked.
