# Philadelphia Transit Accessibility Index

A data processing pipeline that calculates a Transit Accessibility Index for Philadelphia census tracts based on proximity to public transit infrastructure and commute characteristics.

## Overview

This project analyzes transit accessibility across Philadelphia by combining:
- Census tract-level commute data from the American Community Survey (ACS)
- Geographic locations of bus routes, metro stations, and trolley stops
- A weighted accessibility index based on transit infrastructure density

The output is a GeoJSON file containing transit accessibility scores and commute statistics for each census tract in Philadelphia.

## Data Sources

### Census Data (American Community Survey 2023)
- **Variables Used:**
  - B08303: Travel time to work (in various time brackets)
  - B08301: Means of transportation to work (drive, carpool, public transit, walk, bike, motorcycle, work from home)
- **Geography:** Census tracts in Philadelphia County, PA
- **Year:** 2023 5-year estimates

### Transit Infrastructure Data
1. **Bus Routes** (`data/bus.geojson`)
   - SEPTA bus route geometries
   - OWL (late-night) routes are excluded from the analysis
   
2. **Metro Stations** (`data/metro.geojson`)
   - Subway and elevated train station locations
   
3. **Trolley Stops** (Retrieved from ArcGIS Hub)
   - Lines included: T1, T2, T3, T4, T5 (trolley), G1, D1, D2 (other surface rail)
   - Source: SEPTA Regional Rail Stations dataset

4. **Philadelphia Boundary**
   - Source: OpenData ArcGIS dataset
   - Used to clip transit data to city limits

## Prerequisites

### R and Required Packages
```r
install.packages(c("tidycensus", "tidyverse", "sf"))
```

### Census API Key
You'll need a Census API key to access ACS data:
1. Register at https://api.census.gov/data/key_signup.html
2. Set your key in R: `census_api_key("YOUR_KEY_HERE", install = TRUE)`

## Transit Index Calculation Methodology

The Transit Accessibility Index is calculated through the following steps:

### Step 1: Data Collection and Preprocessing

1. **Retrieve Census Data**
   - Download ACS 2023 5-year estimates for Philadelphia census tracts
   - Filter out tracts with very low sample sizes (totalE ≤ 20)

2. **Aggregate Travel Time Categories**
   - Less than 15 minutes: 0-5, 5-9, 10-14 minute brackets
   - 15-30 minutes: 15-19, 20-24, 25-29 minute brackets
   - 30-45 minutes: 30-34, 35-39, 40-44 minute brackets
   - 45-90 minutes: 45-59, 60-89 minute brackets
   - More than 90 minutes: 90+ minutes

3. **Aggregate Transportation Modes**
   - Active transport: walking + biking + motorcycle
   - Keep separate: drive alone, carpool, public transit, work from home

4. **Convert to Percentages**
   - All commute statistics converted to percentages of total workers
   - Rounded to 4 decimal places, then multiplied by 100 for percentage display

### Step 2: Transit Infrastructure Counting

For each census tract, count the number of transit facilities that intersect with its boundaries:

1. **Bus Route Count** (`bus_station`)
   - Count unique bus routes that pass through the tract
   - Weight: 3 points per route

2. **Metro Station Count** (`metro_station`)
   - Count metro/subway stations within the tract
   - Weight: 10 points per station

3. **Trolley Stop Count** (`trolley_station`)
   - Count trolley and surface rail stops within the tract
   - Weight: 15 points per stop

### Step 3: Calculate Transit Index

The raw transit index is calculated using a weighted sum:

```
transit_index = (bus_station × 3) + (metro_station × 10) + (trolley_station × 15)
```

**Rationale for Weights:**
- **Trolley stops (15 points):** Highest weight due to fixed infrastructure, frequent service, and neighborhood-level accessibility
- **Metro stations (10 points):** High weight due to high capacity and reliability, but fewer stops mean less granular access
- **Bus routes (3 points):** Lower weight as routes are more numerous but may have less frequent service

### Step 4: Index Normalization

1. **Percentile-based Index (0-100)**
   - `index`: Divides all tracts into 100 quantiles based on raw transit_index
   - Higher values = better transit accessibility
   - Range: 1 (lowest 1%) to 100 (highest 1%)

2. **Decile Classification (1-10)**
   - `tiles`: Divides all tracts into 10 groups for visualization
   - Used to assign color codes for mapping

3. **Color Coding**
   - Each decile assigned a color from light teal (#80ffdb) to dark purple (#7400b8)
   - Creates a visual gradient from low to high accessibility

## Output Fields

| Field | Description | Type |
|-------|-------------|------|
| `NAME` | Census tract identifier | String |
| `drive` | % commuting by driving alone | Numeric (0-100) |
| `carpool` | % commuting by carpool | Numeric (0-100) |
| `public_transit` | % commuting by public transit | Numeric (0-100) |
| `WFH` | % working from home | Numeric (0-100) |
| `active_transport` | % walking, biking, or motorcycling | Numeric (0-100) |
| `less_than_15_minutes` | % with commute < 15 min | Numeric (0-100) |
| `between_15_and_30_minutes` | % with commute 15-30 min | Numeric (0-100) |
| `between_30_and_45_minutes` | % with commute 30-45 min | Numeric (0-100) |
| `between_45_and_60_minutes` | % with commute 45-90 min | Numeric (0-100) |
| `more_than_90_minutes` | % with commute > 90 min | Numeric (0-100) |
| `bus_station` | Number of bus routes in tract | Integer |
| `metro_station` | Number of metro stations in tract | Integer |
| `trolley_station` | Number of trolley stops in tract | Integer |
| `index` | Transit accessibility index (1-100) | Integer |
| `color` | Hex color code for visualization | String |

## Visualization

The output can be used to create choropleth maps showing:
- Transit accessibility by index score
- Public transit usage rates
- Commute time distributions
- Active transportation adoption

Example visualization code is included (commented out) in `scripts_census.r`.

## License

See [LICENSE](LICENSE) file for details.

## Contributing

This is a data processing pipeline. To contribute:
1. Ensure reproducibility of data sources
2. Document any changes to calculation methodology
3. Update this README if weights or formulas change

## Notes

- The index is relative to Philadelphia only and should not be compared to other cities
- Census tract boundaries and populations change over time
- Transit infrastructure data should be updated periodically for accuracy
- The weighting scheme (3-10-15) is configurable but should be justified if changed
