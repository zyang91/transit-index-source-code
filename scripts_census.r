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

