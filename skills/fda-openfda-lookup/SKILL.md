---
name: fda-openfda-lookup
description: >
  Use when benchmarking internal adverse event rates against FAERS (FDA Adverse
  Event Reporting System), checking drug labels and safety information, reviewing
  recall history, or querying FDA approval data. Queries the openFDA API for
  drug-related endpoints. Useful alongside safety-signal-review for
  contextualizing internal safety findings with real-world post-market data.
---

# FDA Database (openFDA)

## API Overview

- **Base URL:** `https://api.fda.gov`
- **Auth:** Optional API key (higher rate limits)
  - Without key: 240 req/min, 1,000/day
  - With key: 240 req/min, 120,000/day
  - Register: `https://open.fda.gov/apis/authentication/`
- **Response format:** JSON

## Data Retrieval via the external-data tool

Always use the `the external-data tool` tool instead of writing inline Python
with `requests`. This caches the API response to disk for grounded citations.

Example — FAERS adverse events:
  the external-data tool(
    url: "https://api.fda.gov/drug/event.json"
    params: {search: "patient.drug.medicinalproduct:metformin", count: "patient.reaction.reactionmeddrapt.exact", limit: 20}
    source_tag: "fda"
    description: "metformin top adverse events"
  )

Then Read the returned file_path and Grep for specific values.

## Citation Rule

When referencing external data in your response:
1. Grep the cached file for the specific value you're citing
2. Never paraphrase numbers — copy exact values from the file
3. For source attribution, use the `url` field from the `the external-data tool`
   response — this is the actual URL that was fetched

**NEVER cite local file paths** (e.g. `/tmp/output_*/external/*.json`).
Users cannot access temp files. Always use the `url` from the tool response.

For reports and tables, add a "Sources" section at the end listing all
external data consulted with their `url` and `description` from the
tool response, formatted as clickable links.

## Drug Endpoints

This skill primarily uses drug-related endpoints. Other openFDA endpoints
(device, food, animal) are not relevant to clinical trial data analysis.

| Endpoint | URL Path | Use For |
|----------|----------|---------|
| Adverse Events (FAERS) | `/drug/event.json` | Post-market AE rates, MedDRA terms |
| Product Labeling | `/drug/label.json` | Prescribing info, warnings, indications |
| Recalls | `/drug/enforcement.json` | Recall history and classifications |
| Approvals (Drugs@FDA) | `/drug/drugsfda.json` | Approval dates, regulatory actions |

## FAERS Adverse Event Queries

### Top Adverse Events for a Drug

```python
import requests

url = "https://api.fda.gov/drug/event.json"
params = {
    "search": "patient.drug.medicinalproduct:metformin",
    "count": "patient.reaction.reactionmeddrapt.exact",
    "limit": 20
}

resp = requests.get(url, params=params, timeout=30)
resp.raise_for_status()
data = resp.json()

print("Top reported adverse events (MedDRA PTs):")
for result in data['results']:
    print(f"  {result['term']}: {result['count']} reports")
```

### Serious Events Only

```python
params = {
    "search": (
        "patient.drug.medicinalproduct:metformin"
        "+AND+serious:1"
    ),
    "count": "patient.reaction.reactionmeddrapt.exact",
    "limit": 20
}
```

### Temporal Trend — Monthly Report Counts

```python
params = {
    "search": "patient.drug.medicinalproduct:metformin",
    "count": "receivedate"  # counts by date
}

resp = requests.get(url, params=params, timeout=30)
data = resp.json()

# data['results'] = [{"time": "20240101", "count": 42}, ...]
# Aggregate by month for trend analysis
```

### Compare Internal AE Rates with FAERS

This is the primary use case — benchmark your study's AE profile against
real-world post-market data.

**Workflow:**
1. Query internal ADAE for AE incidence by PT and arm
2. Query FAERS for the same drug's reported AE profile
3. Compare: are your study's top AEs consistent with known post-market data?
4. Flag any AEs elevated in your study but rare in FAERS (potential new signal)

```sql
-- Step 1: Internal AE incidence (top 20 PTs in drug arm)
SELECT AEDECOD AS preferred_term,
       COUNT(DISTINCT CASE WHEN TRT01A = 'Drug' THEN a.USUBJID END) AS n_drug,
       COUNT(DISTINCT CASE WHEN TRT01A = 'Placebo' THEN a.USUBJID END) AS n_placebo
FROM adae a
JOIN adsl s ON a.USUBJID = s.USUBJID
WHERE s.SAFFL = 'Y' AND a.TRTEMFL = 'Y'
GROUP BY AEDECOD
ORDER BY n_drug DESC
LIMIT 20
```

```python
# Step 2: FAERS data for the same drug
faers_top = requests.get(url, params={
    "search": f"patient.drug.medicinalproduct:{drug_name}",
    "count": "patient.reaction.reactionmeddrapt.exact",
    "limit": 50
}).json()

# Step 3: Compare — merge on MedDRA PT
faers_pts = {r['term']: r['count'] for r in faers_top['results']}
# Match internal PTs against FAERS; flag discrepancies
```

## Drug Label Lookup

Retrieve prescribing information including warnings, indications, and
contraindications:

```python
url = "https://api.fda.gov/drug/label.json"
params = {
    "search": "openfda.brand_name:Keytruda",
    "limit": 1
}

resp = requests.get(url, params=params, timeout=30)
label = resp.json()['results'][0]

# Key sections
print("Indications:", label.get('indications_and_usage', ['N/A'])[0][:200])
print("Warnings:", label.get('warnings_and_cautions', ['N/A'])[0][:200])
print("Adverse Reactions:", label.get('adverse_reactions', ['N/A'])[0][:200])
```

## Drug Recall History

```python
url = "https://api.fda.gov/drug/enforcement.json"
params = {
    "search": "openfda.brand_name:metformin",
    "limit": 10,
    "sort": "report_date:desc"
}

resp = requests.get(url, params=params, timeout=30)
data = resp.json()

for recall in data.get('results', []):
    print(f"  {recall['report_date']}: Class {recall['classification']}")
    print(f"  Reason: {recall['reason_for_recall'][:100]}")
```

## MedDRA Term Aggregation

FAERS uses MedDRA Preferred Terms (PTs). To aggregate by System Organ Class
(SOC), you need a MedDRA dictionary. FAERS does not directly return SOC, but
you can:

1. Query by specific MedDRA PTs from your internal data
2. Use the `patient.reaction.reactionmeddrapt.exact` count field
3. Map PTs to SOCs using your internal MedDRA dictionary if available

```python
# Query FAERS for specific PTs found in your study
pts_of_interest = ["Nausea", "Headache", "Diarrhoea", "Fatigue"]
for pt in pts_of_interest:
    params = {
        "search": (
            f"patient.drug.medicinalproduct:{drug_name}"
            f"+AND+patient.reaction.reactionmeddrapt:\"{pt}\""
        ),
        "limit": 1
    }
    resp = requests.get("https://api.fda.gov/drug/event.json",
                        params=params, timeout=30)
    total = resp.json().get('meta', {}).get('results', {}).get('total', 0)
    print(f"  {pt}: {total} FAERS reports")
```

## Rate Limiting

```python
import time

def fda_query(url, params, max_retries=3):
    for attempt in range(max_retries):
        resp = requests.get(url, params=params, timeout=30)
        if resp.status_code == 429:
            wait = 60 * (attempt + 1)
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp.json()
    raise RuntimeError("FDA API rate limit exceeded")
```

## Limitations

- **FAERS is spontaneous reporting** — report counts ≠ incidence rates.
  Cannot directly compare FAERS counts with controlled trial incidence.
  Use for signal detection context, not statistical comparison.
- **Reporting bias** — serious events overrepresented, common events
  underreported. Known drugs have more reports due to market exposure.
- **Duplicate reports** — FAERS contains duplicates. Use `receiptdate` and
  `safetyreportid` for de-duplication when doing trend analysis.
- **Drug name matching** — use `medicinalproduct` for brand names,
  `activesubstance.activesubstancename` for generic names.

## Related Skills

- `safety-signal-review` — internal safety signal framework (use FAERS to contextualize)
- `clinicaltrials-gov-lookup` — ClinicalTrials.gov registry for the same drug
- `oncology-endpoints` — endpoint definitions for interpreting label indications
- `adam-explorer` — ADAE variable reference for internal AE data
