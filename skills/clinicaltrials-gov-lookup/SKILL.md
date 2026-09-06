---
name: clinicaltrials-gov-lookup
description: >
  Use when cross-referencing internal study data with ClinicalTrials.gov, looking
  up trial design or endpoints for a specific NCT ID, comparing study populations,
  or finding competing trials for a drug or condition. Queries the ClinicalTrials.gov
  API v2 (public, no auth required). Useful alongside adam-explorer and
  oncology-endpoints for contextualizing internal analyses.
---

# ClinicalTrials.gov Database

## API Overview

- **Base URL:** `https://clinicaltrials.gov/api/v2`
- **Auth:** None required (public API)
- **Rate limit:** ~50 requests/minute per IP
- **Max page size:** 1000 studies per request
- **Response format:** JSON (default) or CSV
- **Date format:** ISO 8601

## Data Retrieval via the external-data tool

Always use the `the external-data tool` tool instead of writing inline Python
with `requests`. This caches the API response to disk for grounded citations.

Example — search trials:
  the external-data tool(
    url: "https://clinicaltrials.gov/api/v2/studies"
    params: {query.cond: "breast cancer", query.intr: "pembrolizumab", pageSize: 10}
    source_tag: "ctgov"
    description: "<what you're looking for>"
  )

Example — get trial by NCT ID:
  the external-data tool(
    url: "https://clinicaltrials.gov/api/v2/studies/NCT04852770"
    params: {}
    source_tag: "ctgov"
    description: "NCT04852770 trial details"
  )

Then Read the returned file_path and Grep for specific values.

## Citation Rule

When referencing external data in your response:
1. Grep the cached file for the specific value you're citing
2. Never paraphrase numbers — copy exact values from the file
3. For source attribution, use the `url` field from the `the external-data tool`
   response — this is the actual URL that was fetched

**NEVER construct or fabricate API URLs.** The `the external-data tool` tool
returns a `url` field with the exact URL used. Cite that URL, not the
local `file_path` (temp file paths are meaningless to users).

For reports and tables, add a "Sources" section at the end listing all
external data consulted with their `url` and `description` from the
tool response, formatted as clickable links.

## Core Queries

### Search Trials

```python
import requests

url = "https://clinicaltrials.gov/api/v2/studies"
params = {
    "query.cond": "breast cancer",        # condition
    "query.intr": "pembrolizumab",        # intervention/drug
    "filter.overallStatus": "RECRUITING",  # status filter
    "pageSize": 10,
    "sort": "LastUpdatePostDate:desc"
}

resp = requests.get(url, params=params, timeout=30)
resp.raise_for_status()
data = resp.json()

print(f"Found {data['totalCount']} trials")
for study in data['studies']:
    proto = study['protocolSection']
    nct = proto['identificationModule']['nctId']
    title = proto['identificationModule']['briefTitle']
    print(f"  {nct}: {title}")
```

### Get Trial by NCT ID

```python
nct_id = "NCT04852770"
url = f"https://clinicaltrials.gov/api/v2/studies/{nct_id}"

resp = requests.get(url, timeout=30)
study = resp.json()

proto = study['protocolSection']
title = proto['identificationModule']['briefTitle']
status = proto['statusModule']['overallStatus']
phase = proto.get('designModule', {}).get('phases', [])
```

## Query Parameters

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `query.cond` | Condition/disease | `"type 2 diabetes"` |
| `query.intr` | Intervention/drug | `"Keytruda"` |
| `query.term` | General search | `"EGFR mutation NSCLC"` |
| `query.locn` | Location | `"New York"` |
| `query.spons` | Sponsor | `"Pfizer"` |
| `filter.overallStatus` | Status filter | `"RECRUITING"` |
| `pageSize` | Results per page (max 1000) | `100` |
| `sort` | Sort order | `"LastUpdatePostDate:desc"` |
| `pageToken` | Pagination token | From previous response |

## Status Values

| Status | Meaning |
|--------|---------|
| `RECRUITING` | Currently enrolling |
| `NOT_YET_RECRUITING` | Approved but not yet open |
| `ENROLLING_BY_INVITATION` | Invitation-only enrollment |
| `ACTIVE_NOT_RECRUITING` | Active, enrollment closed |
| `SUSPENDED` | Temporarily halted |
| `TERMINATED` | Stopped prematurely |
| `COMPLETED` | Study concluded |
| `WITHDRAWN` | Withdrawn before enrollment |

## Response Structure — Key Paths

Navigate the nested JSON to extract common fields:

| Field | JSON Path |
|-------|-----------|
| NCT ID | `protocolSection.identificationModule.nctId` |
| Title | `protocolSection.identificationModule.briefTitle` |
| Status | `protocolSection.statusModule.overallStatus` |
| Phase | `protocolSection.designModule.phases` |
| Enrollment | `protocolSection.designModule.enrollmentInfo.count` |
| Arms | `protocolSection.armsInterventionsModule.armGroups` |
| Interventions | `protocolSection.armsInterventionsModule.interventions` |
| Eligibility | `protocolSection.eligibilityModule.eligibilityCriteria` |
| Primary outcomes | `protocolSection.outcomesModule.primaryOutcomes` |
| Locations | `protocolSection.contactsLocationsModule.locations` |
| Sponsor | `protocolSection.sponsorCollaboratorsModule.leadSponsor.name` |
| Results | `resultsSection` (if `hasResults` is true) |

## Pagination

For large result sets, paginate using the `pageToken` from each response:

```python
all_studies = []
page_token = None

for _ in range(10):  # safety limit
    params = {"query.cond": "cancer", "pageSize": 1000}
    if page_token:
        params["pageToken"] = page_token

    resp = requests.get(url, params=params, timeout=30)
    data = resp.json()
    all_studies.extend(data['studies'])

    page_token = data.get('nextPageToken')
    if not page_token:
        break
```

## Cross-Referencing with Internal Data

The primary value here is contextualizing internal study data with
registry information.

### Look Up Your Study's Registry Entry

```python
# If you know the NCT ID from the protocol
nct_id = "NCT04852770"  # from study metadata or ADSL
study = requests.get(f"{url}/{nct_id}", timeout=30).json()

# Compare registered endpoints vs internal ADTTE PARAMCDs
registered_primary = study['protocolSection']['outcomesModule']['primaryOutcomes']
for outcome in registered_primary:
    print(f"  {outcome['measure']} — {outcome['timeFrame']}")
```

### Find Competing Trials

```python
# Identify trials testing the same drug in the same indication
params = {
    "query.cond": "HER2-positive breast cancer",
    "query.intr": "trastuzumab deruxtecan",
    "filter.overallStatus": "RECRUITING,ACTIVE_NOT_RECRUITING",
    "pageSize": 50
}
resp = requests.get(url, params=params, timeout=30)
competitors = resp.json()
```

### Compare Study Populations

Extract eligibility criteria to compare your study's population with
similar trials:

```python
eligibility = study['protocolSection']['eligibilityModule']
print(f"Ages: {eligibility.get('minimumAge')} – {eligibility.get('maximumAge')}")
print(f"Sex: {eligibility.get('sex')}")
print(f"Criteria:\n{eligibility.get('eligibilityCriteria')}")
```

## Rate Limit Handling

```python
import time

def fetch_with_backoff(url, params, max_retries=3):
    for attempt in range(max_retries):
        resp = requests.get(url, params=params, timeout=30)
        if resp.status_code == 429:
            wait = 60 * (attempt + 1)
            print(f"Rate limited. Waiting {wait}s...")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp.json()
    raise RuntimeError("Rate limit exceeded after retries")
```

## Error Handling

Always check for errors — not all trials have complete data:

```python
# Safe field access
phases = study['protocolSection'].get('designModule', {}).get('phases', [])
enrollment = (study['protocolSection']
              .get('designModule', {})
              .get('enrollmentInfo', {})
              .get('count', 'N/A'))

# Check for results section
if study.get('hasResults'):
    results = study['resultsSection']
```

## Related Skills

- `adam-explorer` — internal ADaM dataset reference (compare with registry endpoints)
- `oncology-endpoints` — endpoint definitions (OS, PFS, ORR) for interpreting registry outcomes
- `fda-openfda-lookup` — FDA drug approvals, FAERS safety data for the same drug
- `safety-signal-review` — internal safety analysis to contextualize with registry data
