# Evolution Plan Implementation Checklist

> Detailed action items and success tracking for the idp-concept 5-step strategic evolution plan (June 3 - September 2026).

---

## Executive Summary

This document tracks completion of 5 strategic evolution steps to establish idp-concept as a production-grade IDP platform with external adoption and market validation.

**Timeline**: 8 weeks (June 3 - August 27, 2026) for Pilot, then Q4 2026 for Score evaluation.
**Core Commitment**: 12-15 hours/week core team + pilot team engagement
**Success Criteria**: ≥2 external teams successfully using framework with NPS ≥ 0

---

## Step 1: Crossplane Runtime Lifecycle Testing ✅ COMPLETE

### Deliverables

- [x] docs/CROSSPLANE_TESTING_GUIDE.md (1,200+ lines)
  - 14-section comprehensive testing framework
  - Safety-first pyramid model (static → render → dry-run → reconciliation)
  - 5+ working examples per profile (smoke, lifecycle, catalog, api-lifecycle, matrix)
  - CI/CD patterns (GitHub Actions, GitLab CI, Jenkins)
  - Troubleshooting guide with 20+ scenarios

- [x] framework/tests/acceptance/cases/crossplane_advanced_lifecycle_workload.k
  - Multi-tier stateful deployment (PostgreSQL → Redis → WebApp)
  - Demonstrates complex dependency ordering
  - Production-like governance metadata propagation
  - Registered in scripts/acceptance_kind.sh RUNTIME_CASES

### Status: ✅ COMPLETE
- [x] Documentation published
- [x] Advanced fixture implemented
- [x] All 433 KCL tests passing
- [x] No regressions in framework, builders, templates

### Evidence
- Commit: 03a4265
- Test run: `cd framework && kcl test ./...` → ✅ PASS (433/433)

---

## Step 2: Framework v1.0.0 OCI Registry Publishing ⏳ IN PROGRESS

### Sub-steps

#### Phase 2a: GHCR Publishing Manual Execution (This Week)

**Document**: docs/GHCR_PUBLISHING_GUIDE.md ✅ CREATED

**Actions Required**:
- [ ] **2.a.1** Create GitHub PAT token and store it in `credentials/ghcr.env`
  - Navigate: https://github.com/settings/tokens/new
  - Scopes: write:packages, read:packages, delete:packages
  - Save it ONLY in the git-ignored `credentials/ghcr.env` (never in a commit/command):
    ```bash
    cat > credentials/ghcr.env << 'EOF'
    GHCR_USERNAME=javier-godon
    CR_PAT=<github_pat_token>
    EOF
    git check-ignore -v credentials/   # must show a .gitignore match
    ```
  - Time: <5 minutes

- [ ] **2.a.2** (No manual login needed) — `scripts/publish_oci.sh` authenticates from
  `credentials/ghcr.env` automatically. To verify manually:
  ```bash
  set -a; source credentials/ghcr.env; set +a
  printf '%s' "$CR_PAT" | docker login ghcr.io -u "${GHCR_USERNAME:-javier-godon}" --password-stdin
  ```
  - Time: <5 minutes

- [ ] **2.a.3** Install ORAS CLI
  ```bash
  # macOS
  brew install oras
  # or Linux
  curl -LO https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
  tar xzf oras_1.1.0_linux_amd64.tar.gz && sudo mv oras /usr/local/bin/
  # Verify
  oras version
  ```
  - Time: <10 minutes

- [ ] **2.a.4** Package + push framework v1.0.0 (one command, credentials from folder)
  ```bash
  cd /path/to/idp-concept
  # Authenticates from credentials/ghcr.env, packages framework/, and pushes via oras.
  ./scripts/publish_oci.sh framework v1.0.0
  # Verify
  oras ls ghcr.io/javier-godon/idp-concept-framework
  # Expected: v1.0.0 listed
  ```
  - Time: <5 minutes

- [ ] **2.a.5** (Manual fallback) Push to GHCR via ORAS
  ```bash
  # Only needed if NOT using scripts/publish_oci.sh. Auth comes from credentials/ghcr.env:
  set -a; source credentials/ghcr.env; set +a
  printf '%s' "$CR_PAT" | oras login ghcr.io -u "${GHCR_USERNAME:-javier-godon}" --password-stdin

  export IMAGE="ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
  oras push "$IMAGE" \
      /tmp/idp-publish/framework-v1.0.0.tar.gz:application/vnd.idp-concept.framework.v1+gzip
  oras ls ghcr.io/javier-godon/idp-concept-framework
  ```
  - Time: <5 minutes

- [ ] **2.a.6** Test consuming project can pull
  ```bash
  cd /tmp && mkdir test-import && cd test-import
  # Create kcl.mod with GHCR reference
  cat > kcl.mod << 'EOF'
  [package]
  name = "test_consumer"
  edition = "v0.10.0"
  version = "0.0.1"
  
  [dependencies]
  framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"
  k8s = "1.31.2"
  EOF
  
  # Try import
  kcl run main.k --quiet
  # Should work without errors
  ```
  - Time: <10 minutes

**Total Time for Phase 2a**: ~45 minutes

#### Phase 2b: Update Internal Consuming Projects

**Actions Required**:
- [ ] **2.b.1** Update projects/video_streaming/kcl.mod
  - Replace: `framework = { path = "../../framework" }`
  - With: `framework = "oras://ghcr.io/javier-godon/idp-concept-framework:v1.0.0"`
  - Time: <5 minutes

- [ ] **2.b.2** Update projects/erp_back/kcl.mod
  - Same replacement as 2.b.1
  - Time: <5 minutes

- [ ] **2.b.3** Update projects/pokedex/kcl.mod (if exists)
  - Same replacement
  - Time: <5 minutes

- [ ] **2.b.4** Run tests on updated projects
  ```bash
  cd projects/video_streaming && kcl run factory/main.k --quiet
  cd projects/erp_back && kcl run pre_releases/factory/main.k --quiet
  # Both should complete without errors
  ```
  - Time: <10 minutes

**Total Time for Phase 2b**: ~30 minutes

#### Phase 2c: CI/CD Automation (Deferred to Q3 2026)

**Document**: GHCR_PUBLISHING_GUIDE.md section 5.1 ✅ TEMPLATE PROVIDED
**Timeline**: Blocked on KPM v2.0 release (expected Q3 2026)
**Action**: Monitor https://github.com/kcl-lang/kpm and implement CI/CD workflow when KPM v2.0 shipped

### Deliverables Status

- [x] docs/GHCR_PUBLISHING_GUIDE.md (comprehensive step-by-step)
- [ ] Framework published to ghcr.io/javier-godon/idp-concept-framework:v1.0.0 (manual task)
- [ ] Internal projects updated to use GHCR reference (manual task)
- [ ] GitHub Actions CI/CD template provided (done; awaiting KPM v2.0)

### Status: ⏳ IN PROGRESS
- [x] Documentation complete
- [ ] Manual ORAS publishing execution (awaiting user execution)
- [ ] Internal project updates (awaiting publishing)
- [ ] CI/CD automation (blocked on KPM v2.0, Q3 2026)

### Estimated Time to Complete Phase 2
- Manual publishing + testing: ~1.5 hours
- Internal project updates: ~0.5 hours
- **Total: 2 hours** (can be done in one session)

---

## Step 3: Observability & Monitoring Dashboard ✅ COMPLETE

### Deliverables

- [x] docs/FRAMEWORK_OBSERVABILITY.md (comprehensive integration guide)
  - Quick start for generating observability data
  - Prometheus metrics collection + visualization
  - Grafana dashboard JSON (ready to import)
  - Custom integration examples (ServiceNow, Datadog, Splunk)
  - Alerting strategies
  - Roadmap for future enhancements

- [x] scripts/framework-observability-export.sh (executable tool)
  - Converts dry-run inventory to Prometheus metrics
  - Generates Grafana dashboard JSON
  - Exports inventory as JSON for custom tools
  - Usage: `./scripts/framework-observability-export.sh <dry-run.yaml> prometheus`

### Status: ✅ COMPLETE
- [x] Documentation published
- [x] Export script implemented
- [x] Tested with sample dry-run output
- [x] Grafana dashboard JSON tested

### Evidence
- Commit: 03a4265
- Script: `bash scripts/framework-observability-export.sh --help` → ✅ Works

---

## Step 4: External Adoption Pilot ⏳ READY TO LAUNCH

### Document

- [x] docs/ADOPTION_PILOT_GUIDE.md (8,000+ words)
  - Week-by-week schedule (8 weeks)
  - Success metrics & exit criteria
  - Support infrastructure & SLA
  - Risk mitigation
  - Team selection criteria
  - Kick-off + sync agendas (templates provided)
  - Feedback survey template
  - Case study publication path

### Phase 4a: Pre-Pilot Preparation (Weeks of June 3-10)

**Actions Required**:
- [ ] **4.a.1** Finalize pilot team candidates
  - Target: 2-3 teams
  - Selection criteria: Section 6 of ADOPTION_PILOT_GUIDE.md
  - Suggested: 1 webapp + DB, 1 infrastructure stack, 1 GitOps integration
  - Time: <2 hours

- [ ] **4.a.2** Send recruitment message (template provided)
  - Use template from Section 6 (ADOPTION_PILOT_GUIDE.md)
  - Send via email + Slack to candidates
  - Time: <1 hour

- [ ] **4.a.3** Collect commitment forms
  - Confirm: team name, POC, use case, FTE availability
  - Expected response: 1 week
  - Time: Async

- [ ] **4.a.4** Set up communication infrastructure
  - [ ] Create Slack channel: #idp-concept-pilot
  - [ ] Create shared Google Doc: Feedback tracking
  - [ ] Schedule weekly syncs: Thursdays 10 AM UTC
  - [ ] Provision GitHub project (optional): Pilot tracking
  - Time: <1 hour

- [ ] **4.a.5** Publish GHCR v1.0.0 (prerequisite: Step 2)
  - Follow docs/GHCR_PUBLISHING_GUIDE.md
  - Generate GHCR access instructions for pilot teams
  - Time: ~1.5 hours

- [ ] **4.a.6** Schedule kick-off meeting
  - When: 1 week after team commitment (suggested: June 10)
  - Duration: 1 hour
  - Attendees: Core team + 3 pilot teams
  - Use agenda template from ADOPTION_PILOT_GUIDE.md section 10.1
  - Time: <1 hour (planning)

**Total Time for Phase 4a**: ~7 hours

### Phase 4b: Active Pilot Execution (Weeks of June 17 - August 12)

**Weekly Activities**:
- [ ] **Weeks 1-2**: Async onboarding + Week 1 sync (documentation handoff)
- [ ] **Weeks 2-4**: Weekly syncs + active support (high engagement)
- [ ] **Weeks 5-6**: External integration testing + Helmfile/Crossplane validation
- [ ] **Week 7**: Polish + feedback survey completion
- [ ] **Week 8**: Graduation + case study kickoff

**Time Commitment**: 12-15 hours/week (core team) × 8 weeks

### Phase 4c: Pilot Wrap-up & Case Studies (Week of August 19-27)

- [ ] **4.c.1** Collect feedback surveys (due: Week 8, August 19)
  - Use template from ADOPTION_PILOT_GUIDE.md section 10.3
  - Target: completion rate ≥80%
  - Time: <2 hours (collection + triage)

- [ ] **4.c.2** Triage feedback to GitHub issues
  - Critical/High: v1.0.1 patch or GitHub issues
  - Medium: v1.1.0 backlog
  - Low/Enhancement: Future roadmap
  - Time: ~4 hours

- [ ] **4.c.3** Draft blog posts + case studies (for opt-in teams)
  - Blog post: ~1000 words per team
  - Timeline: 2 weeks post-pilot
  - Time: ~6 hours per team

- [ ] **4.c.4** Prepare final presentation (all teams)
  - What we learned
  - Key metrics + NPS
  - Roadmap adjustments
  - Time: ~3 hours

**Total Time for Phase 4c**: ~15 hours

### Status: ⏳ READY TO LAUNCH
- [x] Documentation complete & comprehensive (8K words)
- [x] Week-by-week agenda templates provided
- [x] Support SLA defined
- [x] Success metrics explicit
- [ ] Pilot teams identified (action item)
- [ ] Kick-off scheduled (action item)

### Timeline
- **June 3-10**: Pre-pilot prep (Phase 4a)
- **June 17 - August 12**: Active pilot (Phase 4b, 8 weeks)
- **August 19-27**: Wrap-up (Phase 4c)
- **September**: Final analysis + roadmap adjustment

### Estimated Core Team Hours: ~50 hours total (12-15/week × 8)

---

## Step 5: Score Specification Evaluation ✅ COMPLETE

### Deliverables

- [x] docs/SCORE_SPECIFICATION_EVALUATION.md (5,000+ words)
  - Executive summary with recommendation (⏸️ DEFER)
  - Score deep-dive: What is it, how it works, data model
  - Comparison with idp-concept architecture
  - 3 integration scenarios analyzed (A: Input, B: Output, C: Scaffolding)
  - Maturity & adoption assessment
  - Decision framework & recommendation
  - FAQ + decision record

### Recommendation: ⏸️ DEFER

**Rationale**:
- Score is developer-centric; idp-concept is platform-centric (misaligned)
- No customer demand signals (yet)
- Score still in v1b1; ecosystem adoption unclear
- Opportunity cost: resources better spent on adoption pilot
- Revisit with data in Q4 2026

### Re-evaluation Triggers

Reconsider Score integration IF (Q4 2026):
- ✅ Adoption pilot reveals teams want Score output
- ✅ Score reaches v1.0.0 + 20K+ GitHub stars
- ✅ Major cloud platforms adopt Score
- ✅ Humanitec or similar vendor becomes key customer

### Status: ✅ COMPLETE
- [x] Research completed
- [x] Scenarios analyzed
- [x] Decision documented
- [x] Re-evaluation timeline set (September 2026)
- [x] Team knowledge base updated

---

## Summary: All 5 Steps Status

| Step | Status | Documentation | Implementation | Notes |
|---|---|---|---|---|
| 1: Crossplane Testing | ✅ COMPLETE | ✅ GHCR_PUBLISHING_GUIDE.md | ✅ Advanced fixture | Ready for ops teams |
| 2: OCI Publishing | ⏳ IN PROGRESS | ✅ GHCR_PUBLISHING_GUIDE.md | ⏳ Manual execution pending | 2 hours to complete |
| 3: Observability | ✅ COMPLETE | ✅ FRAMEWORK_OBSERVABILITY.md | ✅ Export script | Ready for use |
| 4: Adoption Pilot | ⏳ READY TO LAUNCH | ✅ ADOPTION_PILOT_GUIDE.md | ⏳ Teams to be identified | 50 hours core team |
| 5: Score Evaluation | ✅ COMPLETE | ✅ SCORE_SPECIFICATION_EVALUATION.md | — | Deferred until Q4 2026 |

---

## Immediate Action Items (This Week)

### Priority 1: Complete Step 2 (OCI Publishing) - ~2 hours

```
1. [ ] Create GitHub PAT token (5 min)
2. [ ] Authenticate with GHCR (5 min)
3. [ ] Install ORAS CLI (10 min)
4. [ ] Package framework v1.0.0 (5 min)
5. [ ] Push to GHCR (5 min)
6. [ ] Verify pull works (10 min)
7. [ ] Update internal projects to use GHCR (30 min)
8. [ ] Run tests on updated projects (10 min)
```

**Outcome**: ghcr.io/javier-godon/idp-concept-framework:v1.0.0 published

### Priority 2: Prepare Step 4 (Adoption Pilot) - ~7 hours

```
1. [ ] Identify 2-3 pilot team candidates
2. [ ] Send recruitment message with template
3. [ ] Collect team commitments
4. [ ] Create Slack channel + communication infrastructure
5. [ ] Schedule kick-off meeting (June 10 proposed)
6. [ ] Prepare kick-off materials (agenda, docs links)
```

**Outcome**: Pilot teams confirmed, kick-off scheduled for June 10

---

## Success Metrics (Overall)

### By End of June 2026
- ✅ Step 1: Crossplane testing guide published (✅ DONE)
- ✅ Step 3: Observability export tool released (✅ DONE)
- ✅ Step 2: Framework v1.0.0 published to GHCR
- ✅ Step 4: Pilot teams identified + kick-off scheduled
- ✅ All 433 KCL tests passing
- ✅ All 5 golden snapshots passing (YAML, Helm, Kusion, etc.)

### By End of August 2026
- ✅ ≥2 external teams successfully render framework configs
- ✅ ≥1 team deploys workload to test environment
- ✅ NPS ≥ 0 (promoters > detractors)
- ✅ Feedback survey completed by all 3 teams
- ✅ Zero regressions in framework

### By End of September 2026
- ✅ Case studies published (if teams opt-in)
- ✅ Roadmap adjusted based on pilot feedback
- ✅ Score + other Q4 objectives re-evaluated with data

---

## Resource Allocation

### Core Team Capacity (Weeks 1-4)

| Role | Hours/Week | Responsibilities |
|---|---|---|
| **Technical Lead** | 3-4 hrs | GHCR publishing, pilot technical support, blocking issue debug |
| **Documentation Lead** | 2-3 hrs | Pilot materials, feedback triage, doc updates |
| **Product Lead** | 1-2 hrs | Pilot coordination, feedback analysis, roadmap planning |
| **Total** | 6-9 hrs/week | (ramping to 12-15 hrs/week during active pilot weeks 2-4) |

### Budget (If consulting support needed)

- GHCR publishing: ~$0 (self-service via GitHub Packages)
- Pilot coordination: ~$0 (internal team)
- Pilot support (if over capacity): up to $5K for contract engineer weeks 2-4
- Case study production (video + blog): ~$0 (internal) or ~$2K (agency)

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Teams delay onboarding | Medium | Schedule slip | 1-week reminder before kick-off |
| GHCR publishing fails | Low | Delays pilot start | Fallback: Docker Hub via ORAS |
| Framework bug blocks team | Low | Critical | Prepare v1.0.1 hotfix branch |
| Core team capacity shortage | Medium | Support lags | Consider contract engineer |
| NPS < 0 (pilot fails) | Low | Reputational risk | Iterate fast on feedback (days 1-4) |

---

## Next Checkpoints

### Checkpoint 1: Step 2 Complete (June 10)
- [ ] Framework v1.0.0 successfully published to GHCR
- [ ] Internal projects updated + tests passing
- [ ] Pilot teams have GHCR access
- **Owner**: Technical Lead

### Checkpoint 2: Pilot Kick-off (June 10)
- [ ] All 3 teams confirmed participation
- [ ] Kick-off meeting 1 hour, all materials ready
- [ ] Week 1 objectives communicated
- **Owner**: Product Lead

### Checkpoint 3: Mid-Pilot Review (July 15 — Week 4)
- [ ] ≥2 teams have rendered framework output
- [ ] Feedback being collected (no blockers so far)
- [ ] Case study candidates identified
- **Owner**: Technical Lead

### Checkpoint 4: Pilot Wrap-up (August 27)
- [ ] All feedback surveys completed
- [ ] NPS calculated (target: ≥0)
- [ ] Issues triaged for v1.0.1 / v1.1.0
- **Owner**: Product Lead

### Checkpoint 5: Post-Pilot Analysis (September 3)
- [ ] Case studies drafted (if teams opt-in)
- [ ] Roadmap adjustments finalized
- [ ] Score evaluation completed with adoption signals
- [ ] Q4 2026 priorities set based on learnings
- **Owner**: Product Lead + Technical Lead

---

## Documentation References

### Core Documents (5 Steps)

1. **docs/GHCR_PUBLISHING_GUIDE.md** — Step 2 detailed manual + CI/CD template
2. **docs/ADOPTION_PILOT_GUIDE.md** — Step 4 comprehensive 8-week framework
3. **docs/SCORE_SPECIFICATION_EVALUATION.md** — Step 5 decision record

### Supporting Documents (Steps 1+3)

4. **docs/CROSSPLANE_TESTING_GUIDE.md** — Step 1 (already published)
5. **docs/FRAMEWORK_OBSERVABILITY.md** — Step 3 (already published)

### Execution Materials (Provided)

6. **Kick-off agenda template** — ADOPTION_PILOT_GUIDE.md §10.1
7. **Weekly sync agenda template** — ADOPTION_PILOT_GUIDE.md §10.2
8. **Feedback survey template** — ADOPTION_PILOT_GUIDE.md §10.3
9. **GitHub Actions CI/CD workflow** — GHCR_PUBLISHING_GUIDE.md §5.1

---

## Final Notes

### What's Done
✅ **All strategic planning, documentation, and design complete.** 5 comprehensive documents provide clear path forward.

### What's Next (User Actions Required)
1. Execute GHCR publishing (follow GHCR_PUBLISHING_GUIDE.md §3)
2. Identify + contact pilot teams (use ADOPTION_PILOT_GUIDE.md §6 template)
3. Schedule kick-off meeting (use agenda template from §10.1)
4. Run active pilot weeks (reference week-by-week schedule from §3)

### Support
- All templates provided; copy-paste ready
- All processes documented; step-by-step instructions included
- All success criteria explicit; easy to measure progress

### Timeline to Production Readiness
- **June**: Publish v1.0.0, launch pilot
- **August**: Pilot data collected
- **September**: Roadmap updated, Score re-evaluated
- **Q4 2026**: External teams deploying to production, case studies published, framework regarded as production-grade IDP solution

---

**Prepared by**: GitHub Copilot Framework Team
**Date**: 2026-06-03
**Framework Version**: v1.0.0
**Team**: Ready for external adoption pilot

