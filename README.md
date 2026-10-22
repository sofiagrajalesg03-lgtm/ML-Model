## FINAL PROJECT
#ML applied in industry

# Road Incidents in Medellín: Hotspots and Victim Triage

Unsupervised and supervised machine learning on 17 years of road-incident records from Medellín, Colombia. Final project for *Fundamentos de Analítica* (EIA University, 2026-2).

## Problem

Medellín's Secretaría de Movilidad receives thousands of incident reports a year. The road-safety coordinator has two decisions to make:

1. **Where and when** should patrols and prevention operations be deployed?
2. **When a report comes in**, should an ambulance be dispatched immediately, or is a traffic response enough?

Each part of the project answers one of these questions with a different approach.

## Dataset

- **Source:** Secretaría de Movilidad de Medellín, published in *Data* (MDPI) 2026, 11(4), 67, [doi:10.3390/data11040067](https://doi.org/10.3390/data11040067).
- **Repository:** Mendeley Data, [doi:10.17632/r6g5dfnpgh.1](https://doi.org/10.17632/r6g5dfnpgh.1). License: CC BY 4.0.
- **Size:** 702,540 incidents (2008-01 to 2025-08), 13 original columns. About 657,755 rows have valid coordinates.
- **Original variables:** date, time, incident class, severity, latitude, longitude, commune, neighborhood.
- **Derived variables:** weekday, month, time band, holiday flag.
- **Target (Part B):** `with_victims` = 1 if the incident involved injured or fatal victims, 0 if there was property damage only (about 57% vs. 43%).

The raw data is not stored in this repository. See `data/README.md` for download and export instructions (the original file is Excel and is converted to CSV).

## Approach

### Part A: Unsupervised learning (what structure exists?)

*Question: are there spatiotemporal hotspots with distinct incident profiles?*

- Features are scaled, and **severity is never used to cluster**.
- **K-means:** number of clusters chosen with the elbow method and silhouette score.
- **Hierarchical clustering:** dendrogram, linkage comparison, and a justified cut level (on a sample, for computational cost).
- **DBSCAN with haversine distance:** `eps` chosen with a k-distance plot and expressed in kilometers. The share of noise is reported next to silhouette. Noise is interpreted as **isolated incidents**, not discarded.
- **Comparison table** of the three methods, with named profiles and an operational action for each (for
