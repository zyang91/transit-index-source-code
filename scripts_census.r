library(tidycensus)
library(tidyverse)
library(sf)

phila_transit<-get_acs(geography = "tract",
                        state = "PA",
                        county = "Philadelphia",
                        variables = c(total = "B08303_001",
                                      less_5_minutes = "B08303_002",
                                      five_to_9_minutes = "B08303_003",
                                      ten_to_14_minutes = "B08303_004",
                                      fifteen_to_19_minutes = "B08303_005",
                                      twenty_to_24_minutes = "B08303_006",
                                      twentyfive_to_29_minutes = "B08303_007",
                                      thirty_to_34_minutes = "B08303_008",
                                      thirtyfive_to_39_minutes = "B08303_009",
                                      forty_to_44_minutes = "B08303_010",
                                      fortyfive_to_59_minutes = "B08303_011",
                                      sixty_to_89_minutes = "B08303_012",
                                      ninty_plus_minutes = "B08303_013",
                                      drive= "B08301_003",
                                      carpool = "B08301_004",
                                      public_transit = "B08301_010",
                                      walk = "B08301_019",
                                      bike = "B08301_018",
                                      motorcycle = "B08301_017",
                                      WFH = "B08301_021"),
                        geometry = TRUE,
                        year = 2023,
                        output = "wide") 

phila_transit<-phila_transit %>%
  select(ends_with("E")) %>%
  filter(totalE > 20)

# ggplot(data = phila_transit) +
#   geom_sf(aes(fill = public_transitE/totalE), color = NA) +
#   scale_fill_viridis_c(option = "plasma", labels = scales::percent_format(accuracy = 1)) +
#   labs(title = "Proportion of Workers Using Public Transit in Philadelphia",
#        subtitle = "American Community Survey 2023 5-year estimates",
#        fill = "Proportion of Workers") +
#   theme_minimal() +
#   theme(axis.text = element_blank(),
#         axis.ticks = element_blank())

# vars <- load_variables(2023, "acs5", cache = TRUE)
# tracts<-vars %>%
#   filter(geography == "tract")

# aggregate travel timeinto 15 minutes interval
phila_transit<-phila_transit %>%
  mutate(less_than_15_minutes = less_5_minutesE + five_to_9_minutesE + ten_to_14_minutesE,
         between_15_and_30_minutes = fifteen_to_19_minutesE + twenty_to_24_minutesE + twentyfive_to_29_minutesE,
         between_30_and_45_minutes = thirty_to_34_minutesE + thirtyfive_to_39_minutesE + forty_to_44_minutesE,
         between_45_and_60_minutes = fortyfive_to_59_minutesE + sixty_to_89_minutesE,
         more_than_90_minutes = ninty_plus_minutesE) %>%
  select(NAME, totalE, driveE, carpoolE, public_transitE, walkE, bikeE, motorcycleE, WFHE,
         less_than_15_minutes, between_15_and_30_minutes,
         between_30_and_45_minutes, between_45_and_60_minutes,
         more_than_90_minutes)

# aggregate motorcycle and bikes
phila_transit<-phila_transit %>%
  mutate(bike_motorcycle = bikeE + motorcycleE) %>%
  select(-bikeE, -motorcycleE)

phila_transit<-phila_transit %>%
  mutate(active_transport= walkE + bike_motorcycle)%>%
  select(-walkE, -bike_motorcycle)

# convert all to percentage and get rid of absolute numbers
phila_transit<-phila_transit %>%
  mutate(across(c(driveE, carpoolE, public_transitE, WFHE,
                  less_than_15_minutes, between_15_and_30_minutes,
                  between_30_and_45_minutes, between_45_and_60_minutes,
                  more_than_90_minutes, active_transport),
                ~ .x/totalE)) %>%
  select(-totalE)

# round all two 2 decimal point
phila_transit<-phila_transit %>%
  mutate(across(c(
driveE, carpoolE, public_transitE, WFHE,
                  less_than_15_minutes, between_15_and_30_minutes,
                  between_30_and_45_minutes, between_45_and_60_minutes,
                  more_than_90_minutes, active_transport
  ), ~ round(.x, 4)))

phila_transit<-phila_transit %>%
  mutate(across(c(
    driveE, carpoolE, public_transitE, WFHE,
    less_than_15_minutes, between_15_and_30_minutes,
    between_30_and_45_minutes, between_45_and_60_minutes,
    more_than_90_minutes, active_transport
  ), ~ .x*100))

phila_transit<-phila_transit %>%
  rename(
    drive = driveE,
    carpool = carpoolE,
    public_transit = public_transitE,
    WFH = WFHE
  )  

bus<-st_read("data/bus.geojson")

boundary<-"https://opendata.arcgis.com/datasets/405ec3da942d4e20869d4e1449a2be48_0.geojson"
phila_boundary<-st_read(boundary)

bus_phila<-st_intersection(bus, phila_boundary)

#filter out OWL routes
bus_phila<-bus_phila %>%
  filter(!str_detect(Route, "OWL"))
bus_phila<-bus_phila %>%
  st_transform(st_crs(phila_transit))

idx1 <- st_intersects(phila_transit, bus_phila) 
phila_transit$bus_station <- lengths(idx1)

# bus<-st_join(phila_transit, bus_phila, join = st_intersects)%>%
#   group_by(NAME)%>%
#   summarise(station=n())
# 
# bus<-bus%>%
#   st_drop_geometry()


metro <- st_read("data/metro.geojson", quiet = TRUE)
metro_phila <- st_filter(metro, phila_boundary)%>%
  st_transform(st_crs(phila_transit))

idx <- st_intersects(phila_transit, metro_phila) 
phila_transit$metro_station <- lengths(idx)

complete<- "https://hub.arcgis.com/api/v3/datasets/b227f3ddbe3e47b4bcc7b7c65ef2cef6_0/downloads/data?format=csv&spatialRefId=3857&where=1%3D1"

phila_complete<-read_csv(complete)
trolley_phila<-phila_complete %>%
  filter(LineAbbr %in% c("T1", "T2", "T3", "T4", "T5","G1","D1","D2")) %>%
  st_as_sf(coords = c("Lon", "Lat"), crs = 4326)%>%
  st_transform(st_crs(phila_boundary))%>%
  st_filter(phila_boundary)
trolley_phila<-st_transform(trolley_phila, st_crs(phila_transit))
idx2 <- st_intersects(phila_transit, trolley_phila)
phila_transit$trolley_station <- lengths(idx2)

# index processing
#weighted matrix: bus*1/10 + metro*1/3 + trolley*1/5
# assigned index based on quantiles from 100 to 0
phila_transit<-phila_transit %>%
  mutate(transit_index = bus_station*3 + metro_station*15 + trolley_station*10,
         tiles=ntile(transit_index, n = 10),
         index=ntile(transit_index, n = 100)) 

phila_transit<-phila_transit%>%
  mutate(color=case_when(
    tiles==1 ~ "#80ffdb",
    tiles==2 ~ "#72efdd",
    tiles==3 ~ "#64dfdf",
    tiles==4 ~ "#56cfe1",
    tiles==5 ~ "#48bfe3",
    tiles==6 ~ "#4ea8de",
    tiles==7 ~ "#5390d9",
    tiles==8 ~ "#5e60ce",
    tiles==9 ~ "#6930c3",
    tiles==10 ~ "#7400b8"
  ))

phila_transit<-phila_transit %>%
  select(NAME, drive, carpool, public_transit, WFH,
         less_than_15_minutes, between_15_and_30_minutes,
         between_30_and_45_minutes, between_45_and_60_minutes,
         more_than_90_minutes, active_transport,
         bus_station, metro_station, trolley_station,index, color)

st_write(phila_transit, "data/phila_transit_index.geojson", delete_dsn = TRUE)
# ggplot(data = phila_transit) +
#   geom_sf(aes(fill = color), color = NA) +
#   scale_fill_identity() +
#   labs(title = "Transit Accessibility Index in Philadelphia",
#        fill = "Transit Accessibility Index") +
#   theme_void()
