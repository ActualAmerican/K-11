@tool
extends RefCounted
class_name CaseEngineTypes

const TAB_ALIBI := "ALIBI"
const TAB_TIMELINE := "TIMELINE"
const TAB_MOTIVE := "MOTIVE"
const TAB_CAPABILITY := "CAPABILITY"
const TAB_PROFILE := "PROFILE"

const RELIABILITY_SOLID := "SOLID"
const RELIABILITY_SHAKY := "SHAKY"
const RELIABILITY_QUESTIONABLE := RELIABILITY_SHAKY
const RELIABILITY_CORRUPTED := "CORRUPTED"

const FACT_TYPE_OBSERVATION := "OBSERVATION"
const FACT_TYPE_RECORD := "RECORD"
const FACT_TYPE_STATEMENT := "STATEMENT"
const FACT_TYPE_FORENSIC := "FORENSIC"

const FACT_TIMELINE_ANCHOR := "TIMELINE_ANCHOR"
const FACT_TIMELINE_NOTE := "TIMELINE_NOTE"
const FACT_ALIBI_STATEMENT := "ALIBI_STATEMENT"
const FACT_ALIBI_WITNESS := "ALIBI_WITNESS"
const FACT_CAPABILITY_ACCESS := "CAPABILITY_ACCESS"
const FACT_CAPABILITY_TRAINING := "CAPABILITY_TRAINING"
const FACT_MOTIVE_PRESSURE := "MOTIVE_PRESSURE"
const FACT_MOTIVE_RELATIONSHIP := "MOTIVE_RELATIONSHIP"
const FACT_PROFILE_BEHAVIOR := "PROFILE_BEHAVIOR"

const ANCHOR_TIMELINE := "timeline"
const ANCHOR_ALIBI := "alibi"
const ANCHOR_CAPABILITY := "capability"
const ANCHOR_MOTIVE := "motive"
const ANCHOR_RELATIONSHIP := "relationship"
const ANCHOR_PROFILE := "profile"

const KEY_TRUTH_BUNDLE := "truth_bundle"
const KEY_CONFLICT_GROUPS := "conflict_groups"
const KEY_TABS := "tabs"
const KEY_FACTS := "facts"
const KEY_TRUTH_REFS := "truth_refs"
const KEY_TEMPLATE_ID := "template_id"
const KEY_FACT_TYPE := "fact_type"
const KEY_SLOTS := "slots"
const KEY_RELIABILITY := "reliability"
const KEY_CONFLICT_GROUP := "conflict_group"
const KEY_FACT_ID := "fact_id"

const PROFILE_AGE_BAND := "age_band"
const PROFILE_LIFE_STAGE := "life_stage"
const PROFILE_FAMILY_STATUS := "family_status"
const PROFILE_DEPENDENTS_BAND := "dependents_band"
const PROFILE_ROLE_FAMILY := "role_family"
const PROFILE_SCHEDULE_TAG := "schedule_tag"
const PROFILE_TENURE_BAND := "tenure_band"
const PROFILE_INCOME_PROXY := "income_proxy"
