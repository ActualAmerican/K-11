# Chapter 4 Case Engine Rulebook

## Authority Order
- `K11_Case_Engine_Spec_v2.0` is the primary source for Chapter 4 structure.
- The Chapter 4 checklist is the tracker, not the schema authority.
- Repo-local contracts in `Scripts/case_engine/CaseEngineContracts.gd` are the machine-enforced source of truth for current schemas and visible render rules.

## Current Status
- `4.1` done
- `4.2` done
- `4.8` reopened
- `4.11` done for now, re-verify later
- all other Chapter 4 items remain open unless explicitly re-verified

## Non-Negotiables
- truth-first generation
- deterministic output for `(run_seed, suspect_index, reroll_index)`
- no guilt tells in player-facing text
- bad cases reject before gameplay
- authored pools must pass contract validation before generation begins
- typed, append-only authored pools
- no ad hoc free-form pool shapes

## Profile Card Rules
- The fixed profile card is a subject sheet, not an evidence dump.
- Visible profile card fields are contract-controlled.
- Hidden/internal fields stay off the player-facing card.
- `PROFILE` fact atoms are separate from the fixed card.
- `PROFILE` notes render as a separate evidence/observations surface.

## Visible vs Hidden Profile Fields
- Visible card fields:
  - `full_name`
  - `age_years`
  - `birth_month`
  - `birth_day`
  - `occupation_label`
  - `assignment_label`
  - `family_status`
  - `dependents_band`
  - `schedule_label`
  - `tenure_label`
  - `temperament`
  - `criminal_history_label`
- Optional visible field:
  - `subject_marker`
- Hidden from the player-facing card:
  - `age_band`
  - `life_stage`
  - `latent_axes`
  - `guilt_state`
  - truth internals
  - conflict audit internals

## Authoring Schema Summary
- Names:
  - typed entries with stable `id`, `label`, `kind`, `weight`, `tags`
- Occupations / role families:
  - typed rows with `id`, `label`, `weight`, role tags, occupation pool, and allowed schedule/location/tool/access/contact tags
- Crime types:
  - typed rows with `id`, `crime_family`, `label`, `tags`, `weight`
- Locations / tools / access:
  - represented as append-only tagged arrays on profile/role rows
- Motives / relationships:
  - relationship archetypes use typed rows with `id`, `contact_role`, `label`, `tags`, `weight`
- Skeletons:
  - typed entries with required atoms, optional atoms, conflict seeds, chains
- Templates:
  - typed entries with `tab`, `template_id`, `fact_type`, `text_tpl`, `slot_keys`, `truth_refs`, `anchor`, `reliability`

## Current Work Order
1. contracts and schema enforcement first
2. starter content-pack expansion second
3. anti-repeat and fairness hardening third
4. remaining Chapter 4 outputs after the contract layer is stable

## Backbone Acceptance Gate
- `4.3`, `4.4`, `4.5`, and `4.6` are not candidates for completion until the starter pack passes the backbone gate.
- The backbone gate requires:
  - anchor guarantees on generated cases
  - skeleton-required atom presence that is traceable in generation output
  - conflict groups that are explicitly resolvable
  - no reliability markup on the fixed profile card
  - no guilt tells on player-facing rendered surfaces
