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
- **Comparison table** of the three methods, with named profiles and an operational action for each (for example "night-time collision corridor")
- **External validation:** each cluster is cross-tabulated against severity after the fact. If the hotspots found without looking at severity are also the most severe, the structure is meaningful.

### Part B: Supervised learning (can we predict severity?)

*Question: with what is known when the report arrives, can we predict whether there will be victims?*

- **Task:** binary classification.
- **Models:** baseline, logistic regression, KNN, decision tree, Random Forest, and gradient boosting.
- **No leakage:** scalers and encoders are fit only on training data inside pipelines, and only information available at report time is used.
- **Temporal split:** train on ≤ 2022, test on 2023–2025, which mimics real deployment instead of a random split.
- **Hotspot feature:** the cluster or hotspot from Part A is added as a predictor, fit inside cross-validation, linking both parts.
- **Evaluation:** confusion matrix, accuracy, sensitivity, specificity, and ROC curves of all models in one plot with AUC. A train vs. test table is used to check overfitting.
- **Decision threshold:** chosen by the cost of errors. A false negative (not sending an ambulance to an injured person) is far costlier than a false positive. A sensitivity analysis over different cost ratios shows how the threshold changes.
- **Interpretation:** feature importances, read as association and not as causation.

## Results

_To be completed._

| Model | Test AUC | Sensitivity | Specificity |
|---|---|---|---|
| Baseline | | | |
| Logistic regression | | | |
| KNN | | | |
| Decision tree | | | |
| Random Forest | | | |
| Gradient boosting | | | |

## Limitations

- The data has no information about vehicles, people, or traffic exposure, so predictive power is limited by design.
- Features are mostly derived from time and location.
- About 6% of records lack coordinates and are excluded from spatial analysis.
- Reporting practices may have changed between 2008 and 2025. 2025 is a partial year.
- Importances describe associations, not causes.

## Repository structure

```
├── data/              # download instructions (no raw data)
├── notebooks/
│   ├── 01_eda.ipynb
│   ├── 02_clustering.ipynb
│   └── 03_classification.ipynb
├── src/               # reusable functions and pipelines
├── report/            # PDF report and poster
└── requirements.txt
```

## Reproducing

```bash
pip install -r requirements.txt
# download the dataset (see data/README.md), export to CSV, then run the notebooks in order
```

## Citation

Arango Uribe, M. L., Rúa, E. Q., & Correa Álvarez, C. D. (2026). Georeferenced Dataset on Road Traffic Incidents and Fatalities in Medellín, Colombia (2008–2025). Data, 11(4), 67. https://doi.org/10.3390/data11040067
