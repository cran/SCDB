## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----library, eval = requireNamespace("tidyverse")----------------------------
library(tidyverse)

## ----setup, include = FALSE, eval = requireNamespace("tidyverse")-------------

forecasts_full <- tribble(
  ~City, ~Forecast, ~ForecastDate,
  "New York",    20, "2023-09-28",
  "Los Angeles", 23, "2023-09-28",
  "Seattle",     16, "2023-09-28",
  "Houston",     34, "2023-09-28",
  "New York",    18, "2023-09-29",
  "Los Angeles", 25, "2023-09-29",
  "Seattle",     17, "2023-09-29",
  "Houston",     34, "2023-09-29"
) %>%
  mutate(across("ForecastDate", as.Date))

forecasts_scd <- forecasts_full %>%
  mutate(ForecastFrom = ForecastDate,
         ForecastUntil = case_when(
           City == "Houston" ~ NA,
           ForecastDate == "2023-09-29" ~ NA,
           TRUE ~ "2023-09-29"
         )) %>%
  mutate(across("ForecastUntil", as.Date)) %>%
  filter(!(City == "Houston" & ForecastFrom == "2023-09-29")) %>%
  distinct() %>%
  select(!"ForecastDate") %>%
  arrange(ForecastFrom)

forecasts_dated <- filter(forecasts_full, ForecastDate == "2023-09-28")
forecasts <- select(forecasts_dated, !"ForecastDate")

forecasts2 <- filter(forecasts_full, ForecastDate == "2023-09-29") %>%
  select(!"ForecastDate")
forecasts2a <- filter(forecasts_full, ForecastDate == "2023-09-29")

## ----forecasts, eval = requireNamespace("tidyverse")--------------------------
# Current date: 2023-09-28
forecasts

## ----forecasts2a, eval = requireNamespace("tidyverse")------------------------
# Current date: 2023-09-29
forecasts2

## ----forecasts_full, eval = requireNamespace("tidyverse")---------------------
forecasts_full

## ----forecasts_full_examples, eval = requireNamespace("tidyverse")------------

# Current forecasts
forecasts_full %>%
  slice_max(ForecastDate, n = 1) %>%
  select(!"ForecastDate")

# Forecasts for a given date
forecasts_full %>%
  filter(ForecastDate == "2023-09-28")

# Full history for a given city
forecasts_full %>%
  filter(City == "New York")

## ----forecasts_scd, eval = requireNamespace("tidyverse")----------------------
forecasts_scd

## ----adresses_setup, include = FALSE, eval = requireNamespace("tidyverse")----
addresses <- tibble::tibble(
  ID = c(1,
         2,
         1,
         1),
  GivenName = c("Alice",
                "Robert",
                "Alice",
                "Alice"),
  Surname = c("Doe",
              "Tables",
              "Doe",
              "Doe"),
  Address = c("Donut Plains 1",
              "Rainbow Road 8",
              "Donut Plains 1",
              "Rainbow Road 8"),
  MovedIn = c("1989-06-26",
              "1989-12-13",
              "1989-06-26",
              "2021-03-01"),
  MovedOut = c(NA,
               NA,
               "2021-03-01",
               NA),
  ValidFrom = c("1989-06-26",
                "1989-12-13",
                "2021-03-08",
                "2021-03-08"),
  ValidUntil = c("2021-03-08",
                 NA,
                 NA,
                 NA)
) %>%
  mutate(across(c("MovedIn", "MovedOut", "ValidFrom", "ValidUntil"), as.Date))


name_change_date <- as.Date("2023-08-28")
addresses2 <- addresses %>%
  filter(ID == 1) %>%
  {
    .data <- .

    .data %>%
      filter(Address == "Rainbow Road 8") %>%
      mutate(Surname = "Tables",
             ValidFrom = !!name_change_date) %>%
      bind_rows(.data)
  } %>%
  mutate(ValidUntil = as.Date(c(NA, !!name_change_date, NA, !!name_change_date), origin = "1970-01-01")) %>%
  bind_rows(filter(addresses,
                   ID == 2)) %>%
  arrange(ValidFrom) %>%
  distinct()

## ----addresses1, eval = requireNamespace("tidyverse")-------------------------
addresses

## ----addresses1a, eval = requireNamespace("tidyverse")------------------------
slice_timestamp <- "2021-03-02"

addresses %>%
  filter(ID == 1,
         ValidFrom < !!slice_timestamp,
         ValidUntil >= !!slice_timestamp | is.na(ValidUntil)) %>%
  select(!c("ValidFrom", "ValidUntil"))

## ----addresses2, eval = requireNamespace("tidyverse")-------------------------
filter(addresses2,
       ID == 1,
       Address == "Rainbow Road 8") %>%
  select(ID, GivenName, Surname, MovedIn, MovedOut, ValidFrom, ValidUntil)

## ----addresses3, eval = requireNamespace("tidyverse")-------------------------
slice_timestamp <- "2022-03-04"

addresses2 %>%
  filter(Address == "Rainbow Road 8",
         is.na(MovedOut),
         ValidFrom < !!slice_timestamp,
         ValidUntil >= !!slice_timestamp | is.na(ValidUntil)) %>%
  select(ID, GivenName, Surname, MovedIn, MovedOut)

slice_timestamp <- "2023-09-29"

addresses2 %>%
  filter(Address == "Rainbow Road 8",
         is.na(MovedOut),
         ValidFrom < !!slice_timestamp,
         ValidUntil >= !!slice_timestamp | is.na(ValidUntil)) %>%
  select(ID, GivenName, Surname, MovedIn, MovedOut)

