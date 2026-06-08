# External Adoption Pilot Guide

> Framework for onboarding 2-3 external teams to idp-concept framework v1.0.0 with structured feedback, success metrics, and support workflows.

---

## 1. Pilot Program Overview

### 1.1 Goals

This pilot program validates idp-concept framework in external production environments and gathers feedback to guide v1.x roadmap.

| Goal | Success Criteria | Feedback Loop |
|---|---|---|
| **Functionality** | Teams successfully render YAML, Helm, Kusion in their environments | Issue tracking + weekly sync |
| **Documentation** | Teams onboard with <4 hours of support | Doc update tracker |
| **DevEx** | Teams prefer framework to hand-written manifests | Adoption survey |
| **Extensibility** | Teams create custom templates without core modifications | Custom template showcase |
| **Operations** | Framework provides observable output for teams | Dry-run metrics adoption |

### 1.2 Pilot Cohort

**Phase 1 (This program)**: 2-3 external teams, duration 8 weeks

| Team Role | Commitment | Expected Outcome |
|---|---|---|
| **Pilot Team 1** | Migrate existing webapp + database workload | Document webapp module adoption |
| **Pilot Team 2** | Build new infrastructure stack (Kafka, PostgreSQL, Redis) | Validate multi-template coordination |
| **Pilot Team 3** (optional) | Integrate with existing ArgoCD/Helmfile environment | Test GitOps integration |

**Success Definition**: ≥2 teams successfully use framework for 1+ production-like workloads with positive feedback.

---

## 2. Pre-Pilot Preparation

### 2.1 Onboarding Checklist

- [ ] Contact team leads, confirm participation
- [ ] Share GHCR access instructions (GitHub org membership or PAT)
- [ ] Share framework public documentation (docs/README.md)
- [ ] Run team through 1-hour architecture walkthrough
- [ ] Provision Slack/Discord channel for real-time support
- [ ] Set up weekly 30-min sync call (optional: async on Slack)
- [ ] Establish escalation: GitHub Issues → weekly sync → core team

### 2.2 Support Expectations

| Level | Response Time | Examples |
|---|---|---|
| Critical (production blocker) | <2 hours | Framework bug, security issue |
| High (feature not working) | <24 hours | Import error, template rendering failure |
| Medium (usage question) | <48 hours | How to set env vars, how to add custom probes |
| Low (enhancement request) | Weekly sync | New output format, new template idea |

### 2.3 Teams Should Provide

- 1-2 point of contact per team (technical + product)
- Access to their test/staging environment (may be optional)
- 2-week availability for active support period (weeks 1-4)
- Commitment to provide feedback at weeks 2, 4, 8

---

## 3. Pilot Week-by-Week Schedule

### Week 0: Kick-off (Before pilot start)

**Pilot Team Lead Actions:**
- [ ] Verify GHCR access: Pull test image
- [ ] Clone updated idp-concept repo (or use GHCR)
- [ ] Run framework unit tests locally (kcl test ./...)
- [ ] Read [../README.md](../README.md) + [../developer/DEVELOPER_QUICKSTART.md](../developer/DEVELOPER_QUICKSTART.md)

**Core Team Actions:**
- [ ] Prepare custom demo for team's use case
- [ ] Identify similar templates in framework already
- [ ] Provision pilot environment (if needed)

**Kick-off Meeting (1 hour)**
- Architecture overview (15 min): Project → Tenant → Site → Stack → Release
- Output formats overview (10 min): YAML, Helm, Crossplane, Kusion
- Team's use case walkthrough (20 min): What they want to build
- Support model and escalation (10 min): Slack + weekly sync
- Q&A (5 min)

**Deliverable**: Team has GHCR access & can pull framework v1.0.0

### Week 1: Get Familiar

**Pilot Team Objectives:**
- [ ] Set up first project using framework template
- [ ] Produce sample YAML output locally
- [ ] Ask 2-3 questions about architecture or usage

**Suggested Path:**
1. Follow [../developer/DEVELOPER_QUICKSTART.md](../developer/DEVELOPER_QUICKSTART.md) (15 min)
2. Look at projects/erp_back sample (understand structure) (30 min)
3. Try `koncept render yaml` on sample factory (10 min)
4. Modify sample config, re-render, iterate (30 min)

**Core Team Check-in:**
- Async Slack channel: "How's onboarding going? Questions?"
- Support: Answer architecture questions, share relevant docs sections

**Deliverable**: Team has rendered sample YAML. Document questions asked → FAQ

### Week 2: First Use Case

**Pilot Team Objectives:**
- [ ] Adapt their real workload to framework templates
- [ ] Produce YAML/Helm/Kusion for 1+ real service
- [ ] Identify any missing templates or features

**Suggested Path:**
1. Map team's workload to framework templates (webapp, database, infrastructure)
2. Create project structure mirroring erp_back layout
3. Configure stack for their services
4. Render to YAML/Helm, validate with kubeconform/helm lint

**Core Team Check-in (Week 2 Sync — 30 min):**
- Review team's current progress
- Demo any custom patterns team discovered
- Identify blockers: missing templates, unclear docs, rendering errors
- Adjust support intensity based on team needs

**Feedback Focus**: 
- "What's harder than expected?" → Doc gaps
- "What's easier than expected?" → Highlight in marketing
- "What do you wish existed?" → Feature request tracking

**Deliverable**: Team has framework rendering their real workloads. Feedback documented.

### Week 3-4: Hardening

**Pilot Team Objectives:**
- [ ] Test output in staging environment (apply to cluster)
- [ ] Validate output with ArgoCD / Helmfile if those are used
- [ ] Resolve production-readiness issues

**Expected Pain Points:**
- RBAC/ServiceAccount setup
- Secret handling (how to reference external secrets?)
- Storage class selection for different environments
- Multi-release coordination (Helm chart vs direct YAML)

**Core Team Actions:**
- Provide custom solutions to pain points
- Document workarounds in docs/APPLICATION_CONFIGURATION_PATTERNS.md
- If major issue: create GitHub issue for team to reference

**Deliverable**: Workload successfully runs in team's test environment. Lessons learned documented.

### Week 5-6: External Integration

**Pilot Team Objectives:**
- [ ] Integrate framework output with team's GitOps system (ArgoCD, Flux, etc.)
- [ ] Test multi-environment workflow (dev → staging → production config)
- [ ] Validate observability output (if using konzept dry-run metrics)

**Pattern Tests:**
- Helmfile orchestration across multiple releases
- Kusion spec for multi-resource deployments
- Crossplane composition ordering if doing infrastructure-as-code
- Dry-run planning to predict cluster impact before deploy

**Feedback Focus**: 
- "How well does framework integrate with our existing tooling?"
- "What's the learning curve for team members who haven't used KCL?"
- "What's the most valuable output format for our use case?"

**Core Team Actions:**
- Set up best-practice examples for team's specific pattern
- Create case study documentation (anonymized)

**Deliverable**: Full end-to-end integration working. Integration pattern documented for case study.

### Week 7: Polish & Feedback

**Pilot Team Objectives:**
- [ ] Write up experience: what worked, what didn't
- [ ] Suggest documentation improvements (PRs welcome)
- [ ] Commit to post-pilot support model (if success)

**Feedback Survey**:
1. Overall satisfaction (scale 1-10)
2. Most valuable feature
3. Most frustrating aspect
4. Likelihood to recommend (NPS)
5. Suggested improvements (free text)
6. Interest in deep integration (workshops, trainings)

**Core Team Actions:**
- Collect all feedback
- Triage into: immediate fixes, doc updates, future features
- Prepare final wrap-up presentation

**Deliverable**: Completed survey feedback. Case study draft.

### Week 8: Graduation & Case Study

**Pilot Team Objectives:**
- [ ] Promote workload to production (if appropriate)
- [ ] Provide statement of success for case study
- [ ] Commit to ongoing feedback (if willing)

**Final Presentation (1 hour):**
- Team demo: "Here's what we built with idp-concept"
- Core team demo: "Here's what we learned from pilot cohort"
- Next steps: ongoing support model, case study publication
- Q&A from broader audience (if publicizing pilot)

**Deliverable**: Case study published. Team transitioned to ongoing support or graduation.

---

## 4. Support Infrastructure

### 4.1 Communication Channels

**Synchronous (Real-time):**
- Slack channel: `#idp-concept-pilot` (monitored during business hours)
- Weekly video sync: Thursdays 10 AM UTC (30 min)
- Office hours: Wednesdays 3 PM UTC (optional drop-in)

**Asynchronous:**
- GitHub Issues (bugs & feature requests)
- Email (javier@example.com for escalations)
- Shared Google Doc: pilot feedback & action tracking

### 4.2 Core Team Support Load

| Team Member | Role | Hours/Week |
|---|---|---|
| **Technical Lead** | Architecture questions, deep debugging | 5-8 hrs |
| **Documentation Lead** | Doc updates, onboarding support | 3-5 hrs |
| **Product Lead** | Feedback collection, roadmap integration | 2-3 hrs |
| **Total** | | ~12 hrs/week for 8 weeks |

---

## 5. Success Metrics & Exit Criteria

### 5.1 Pilot Success (all must pass)

| Metric | Target | Evidence |
|---|---|---|
| **Functionality** | ≥2 teams render valid YAML/Helm/Kusion | Rendered manifests validated with kubeconform |
| **Runability** | ≥1 team deploys workload to test cluster | `kubectl apply` succeeds, pods roll out |
| **Documentation** | No more than 2 critical doc gaps per team | Team feedback survey + issue tracking |
| **Support** | Avg response time <24 hours for non-critical issues | Slack history audit |
| **Adoption Intent** | NPS score ≥ 0 (promoters > detractors) | Feedback survey, post-pilot commitment |

### 5.2 Individual Team Expectations

**By End of Week 4:**
- Team has rendered framework output to YAML/Helm
- Team has identified 1-2 feature requests or doc gaps
- Team feels confident to continue independently with async support

**By End of Week 8:**
- Team has integrated framework into their tooling (ArgoCD, Helmfile, etc.)
- Team has deployed at least 1 workload to test environment
- Team provides feedback survey & (optionally) case study

**Post-Pilot:**
- Team enters "ongoing support" model (async Slack, quarterly sync)
- Team considers framework for production workloads
- Team provides reference for future customers

---

## 6. Pilot Team Selection Criteria

### Ideal Pilot Team Profile

✅ **Good Fit:**
- Has existing K8s infrastructure to test against
- Uses one or more of: Helm, Kustomize, ArgoCD, Helmfile
- Willing to provide constructive feedback
- Has 1-2 FTE available for active participation (weeks 1-4)
- Workload matches framework strengths (web app + infrastructure)
- Trust in experimental features; comfortable with v1.0.0 maturity

❌ **Poor Fit:**
- Only interested in consuming black-box YAML (not learning KCL)
- No K8s environment to test in (dry-run only)
- Tightly coupled to specific vendor tooling (AWS-only, Azure-only)
- Workload is highly custom (unlikely to use templates)
- No time for active engagement weeks 1-4

### Recruitment Messaging

```markdown
## idp-concept Framework v1.0.0 Pilot Program — Join Us!

We're piloting the idp-concept framework (an open-source Kubernetes IDP) with 2-3 external teams.

**What You Get:**
- Access to framework v1.0.0 (pre-general availability)
- Direct support from core team (8 weeks)
- Ability to render infrastructure-as-code in YAML, Helm, Kusion (your choice)
- Workshops & training on KCL + framework patterns
- Recognition in case study (if you opt-in)

**What We Need:**
- 1-2 FTE for active engagement (weeks 1-8)
- Feedback on documentation, features, and DevX
- Willingness to share learnings (anonymized case study)
- Real workload to test (web app + infrastructure)

**Timeline:** June 3 - July 28, 2026 (8 weeks)

**Interest?** Reply with: team name, use case (1-2 sentences), and POC name + email.
```

---

## 7. Roadmap Integration

### 7.1 Feedback→Feature Cycle

All feedback collected during pilot feeds into v1.1.0 planning:

**Week 8 → Week 9:**
- Core team reviews all feedback
- Triage into: docs-only fixes, bugsv1.0.1, features→v1.1.0 backlog
- Publish "Here's what we learned" blog post + roadmap update

**High Priority Features** (likely from pilot):
- Custom template scaffolding tool (ako `kcl init template`)
- Better secret reference patterns (integration with ArgoCD secrets)
- Multi-environment config override simplification
- KCL language feature requests (if any revealed)

### 7.2 Case Study Publication

**For Teams That Opt In:**

1. **Blog Post** (~1000 words)
   - Team intro (anonymized if preferred)
   - Their workload: services + constraints
   - "Before framework" vs "After framework"
   - Key metrics (YAML lines reduced, deployment time, learning curve)
   - Key learnings & tips for other teams

2. **Short Video** (optional, 5-10 min)
   - "Day 1" team member: "I've never used KCL before"
   - "Day 30" team member: "Here's the stack we built"
   - Quick demo of rendered output
   - Testimonial

3. **Reference Profile** (on website/GitHub)
   - Logo + link to team
   - Use case summary
   - Output formats used
   - GitHub link to team's public project (if willing)

---

## 8. Escalation & Issue Resolution

### 8.1 Issue Triage

All issues go through this flow:

```
New Issue
    ↓
[In Slack] Quick analysis: known issue? doc gap? real bug?
    ↓
    ├─→ Known doc gap? → Link docs, create docs PR
    ├─→ Framework bug? → GitHub Issue + Priority triage
    └─→ Team misunderstanding? → Explain + doc for FAQ
         ↓
         Next sync: team lead decides if docs need update
```

### 8.2 Critical Issue Escalation

If a team encounters a blocking issue:

1. **Immediate** (<30 min): Acknowledge in Slack, tag core team lead
2. **Debugging** (<2 hours): Core team attempts reproduction
3. **Workaround** (<4 hours): Provide workaround or rollback suggestion
4. **Fix**: If bug confirmed, create GitHub issue + pull request
5. **Release**: If critical, prepare v1.0.1 patch with fix

**Example Critical Issues:**
- Framework fails to render any output (compilation error)
- Security vulnerability in dependencies
- Generated manifests fail to apply to K8s

---

## 9. Post-Pilot Transition

### 9.1 Transition Path

**Successful Pilot Teams → Ongoing Support:**

| Phase | Duration | Engagement | Cost |
|---|---|---|---|
| **Intensive (Pilot)** | 8 weeks | 1x sync/week + async | Core team time |
| **Transition** | 2 weeks | Handoff to async + monthly sync | Core team time (reduced) |
| **Ongoing** | Indefinite | Async Slack + quarterly sync | Core team time (minimal) |

### 9.2 Ongoing Support SLA

**For Post-Pilot Teams:**

| Issue Type | Response Time | Channel |
|---|---|---|
| Critical (down) | <4 hours | GitHub issue + Slack |
| High (feature broken) | <24 hours | GitHub issue |
| Medium (usage question) | <48 hours | Slack |
| Low (feature request) | <1 week | GitHub discussion |

---

## 10. Resource Template

### 10.1 Sample Kick-off Agenda

```
## idp-concept Framework Pilot — Kick-off Meeting

**When:** {date} 10 AM UTC
**Duration:** 1 hour
**Attendees:** Core team + 3 pilot teams

### Agenda

1. **Welcome & introductions** (5 min)
   - Core team intro
   - Each team: name, 1-sentence mission, POC

2. **Architecture overview** (15 min)
   - Project ← Tenant ← Site ← Stack ← Release
   - 9 output formats (YAML, Helm, Kusion, etc.)
   - KCL language 101 (not mandatory to write, can copy templates)

3. **Framework walkthrough** (10 min)
   - Models (domain schemas)
   - Templates (high-level abstractions)
   - Procedures (output converters)
   - Builders (manifest generators)

4. **Team use case presentations** (20 min, ~5-7 min each)
   - Team 1: "We want to build X"
   - Team 2: "We want to build Y"
   - Team 3: "We want to build Z"

5. **Support expectations & escalation** (5 min)
   - Slack channel: #idp-concept-pilot
   - Weekly sync: Thursdays 10 AM UTC
   - GitHub issues for bugs/feature requests
   - Response time targets

6. **Resources & next steps** (5 min)
   - Shared folder: {link}
   - Docs: {link}
   - GHCR access: {instructions}
   - Week 1 objectives: get familiar, run samples

7. **Q&A** (5 min)

### Before Next Sync (Week 2)
- Teams complete Week 1 objectives
- Teams post progress in #idp-concept-pilot
- Core team prepares customized demos for each team's use case
```

### 10.2 Sample Weekly Sync Agenda

```
## idp-concept Framework Pilot — Week 2 Sync

**When:** Thursday 10 AM UTC
**Duration:** 30 minutes
**Format:** Video call

### Agenda

1. **Status check** (10 min)
   - Team 1: What's working? What's blocked?
   - Team 2: What's working? What's blocked?
   - Team 3: What's working? What's blocked?

2. **Deep dive on blockers** (12 min)
   - Prioritize: which issue affects most teams?
   - Brainstorm solutions or workarounds
   - Core team assigns follow-up if needed

3. **Highlight wins** (5 min)
   - Celebrate any "aha!" moments or clever uses
   - Share discoveries with other teams

4. **Preview next week** (3 min)
   - Week 3 objectives
   - Any prep core team can do

### Action Items
- [ ] Core team: {issue} due by Tuesday
- [ ] Team 1: Try {workaround} by next sync
- [ ] Team 2: Provide {feedback} by next sync
- [ ] All: Post progress in Slack by Wednesday

### Notes
{fill in after call}
```

### 10.3 Sample Feedback Survey

```markdown
# idp-concept Framework Pilot — Feedback Survey (Week 8)

**Team Name:** ________________
**POC Name:** ________________
**Feedback Date:** ________________

## Questions

### 1. Overall Satisfaction
On a scale of 1-10, how satisfied are you with the idp-concept framework?
**Score: ___ / 10**

### 2. Most Valuable Feature
What single framework feature provided the most value to your team?
**Answer:** ________________

### 3. Most Frustrating Aspect
What was the most frustrating aspect of using the framework?
**Answer:** ________________

### 4. Likelihood to Recommend (NPS)
How likely are you to recommend idp-concept to other teams?
**Score: ___ / 10** (0=not likely, 10=very likely)

Why did you give this score?
**Answer:** ________________

### 5. Would You Use in Production?
Would you use idp-concept framework for production workloads?
- [ ] Yes, immediately
- [ ] Yes, with minor improvements
- [ ] Maybe, needs more maturity
- [ ] No, not suitable for our use case

**Why?** ________________

### 6. Learning Curve
How difficult was it for your team to learn the framework?
- [ ] Easy (< 4 hours to productive)
- [ ] Moderate (4-20 hours)
- [ ] Difficult (> 20 hours)
- [ ] Very difficult (team gave up)

**Feedback:** ________________

### 7. Output Formats
Which output formats did you use? Rank by usefulness:
- [ ] YAML (1=most, 5=least)
- [ ] Helm (1=most, 5=least)
- [ ] Kusion (1=most, 5=least)
- [ ] Kustomize (1=most, 5=least)
- [ ] Dry-run planning (1=most, 5=least)

### 8. Documentation Quality
Rate documentation quality in these areas:
- Architecture overview: ___ / 5
- Getting started guide: ___ / 5
- Template reference: ___ / 5
- Troubleshooting: ___ / 5

**Most helpful doc:** ________________
**Most confusing doc:** ________________

### 9. Improvement Suggestions
What's the #1 thing we should improve for v1.1.0?
**Answer:** ________________

### 10. Next Steps
Would you like to:
- [ ] Continue using framework in production (ongoing support)
- [ ] Participate in case study (blog post + video)
- [ ] Provide testimonial (short quote)
- [ ] Join framework advisory board (quarterly strategy calls)
- [ ] Nothing further (thanks for pilot!)

---

Thank you for participating in the idp-concept pilot program!
```

---

## 11. Risk Mitigation

### 11.1 Potential Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Teams delay onboarding | Medium | Schedule slips | Send kick-off reminder 1 week before |
| Team doesn't have K8s env to test | Low | Can't validate | Provide kind/minikube setup guide |
| Framework bug blocks team progress | Low | Critical | Maintain dev branch with hotfixes |
| Core team doesn't have capacity | Medium | Support lags | Front-load scheduling, hire temp support |
| Teams request incompatible features | Medium | Scope creep | Triage features into v1.1.0 backlog |
| NPS < 0 (pilot considered failure) | Low | Reputational risk | Iterate fast, fix issues before week 4 |

### 11.2 Exit Strategy

If pilot is failing by Week 4:

1. **Assess root cause**: Is it a framework issue or support issue?
2. **Quick pivot**: If docs gap → fast doc updates. If bug → hotfix.
3. **Communicate honestly**: Tell teams "we hit a blocker, here's our plan to fix it"
4. **Options**:
   - Extend pilot 2 weeks to allow recovery
   - End pilot early with honest feedback & roadmap updates
   - Bring in external consulting to unblock

---

## 12. Success Stories to Highlight

After successful pilot, showcase:

- **"Team X went from 500 lines of hand-written YAML to 50 lines of KCL configuration"** → DevX win
- **"Team Y integrated with their existing Helmfile pipeline in 1 day"** → Tooling compatibility
- **"Team Z caught configuration drift earlier thanks to framework's dry-run planning"** → Operations value
- **"New team member was productive in KCL after 4-hour onboarding"** → Learning curve
- **"We maintain all 3 output formats (YAML, Helm, Kusion) from single source of truth"** → Operational efficiency

---

## 13. Next Steps

### Immediate (Now)

- [ ] Finalize 2-3 pilot team candidates
- [ ] Send recruitment message (Section 6 template)
- [ ] Confirm commit from teams (participation form)
- [ ] Schedule kick-off for June 10 (example date)

### Pre-Kick-off (By June 10)

- [ ] Publish GHCR_PUBLISHING_GUIDE.md
- [ ] Package framework v1.0.0 to GHCR (see GHCR_PUBLISHING_GUIDE.md §3)
- [ ] Set up Slack channel
- [ ] Create shared folder (meeting notes, resources)
- [ ] Schedule core team support calendar (blocks for syncs)

### Post-Kick-off (During Pilot)

- [ ] Weekly sync Thursdays 10 AM UTC
- [ ] Triage feedback → issues/PRs
- [ ] Monthly blog post on progress
- [ ] Week 8: collect final feedback + start case studies

---

## References

- DEVELOPER_QUICKSTART.md — 30-min onboarding
- PROJECT_ARCHITECTURE.md — Deep dive
- APPLICATION_CONFIGURATION_PATTERNS.md — Config examples
- docs/README.md — Feature overview
- GitHub Issues: https://github.com/Javier-Godon/idp-concept/issues

---

**Pilot Program Owner:** Javier Godon
**Last Updated:** 2026-06-03
**Framework Version:** v1.0.0
**Status:** Ready to launch

