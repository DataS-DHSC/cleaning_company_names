# loading packages --------------------------------------------------------

if(!(require(pacman))) install.packages("pacman")

pacman::p_load(readxl, dplyr, stringi, fuzzyjoin, stringr, stringdist, writexl)

# loading example data ----------------------------------------------------

companies <- read_xlsx("./example_data/example_data.xlsx", trim_ws = FALSE)

# basic initial cleaning --------------------------------------------------

# grouping any identical names so that one row is one name
unique_names <- companies |>
  group_by(company_name) |>
  summarise(spend = sum(spend)) |>
  ungroup()

# creating new field of names and doing basic text cleaning

unique_names$company_name_clean <- unique_names$company_name

# putting to lowercase
unique_names$company_name_clean <- str_to_lower(unique_names$company_name_clean)

# removing white space
unique_names$company_name_clean <- str_squish(unique_names$company_name_clean)

# removing punctuation
unique_names$company_name_clean <- str_replace_all(unique_names$company_name_clean,
                                                   "[[:punct:]]",
                                                   " ")

# removing non-ascii characters
unique_names$company_name_clean <- stri_trans_general(unique_names$company_name_clean,
                                                      "latin-ascii")


# reviewing the dataset might reveal common stop words that you know can be cleaned
stop_words <- c("uk", "co", "ltd", "limited", "corp")

# finding stop words and removing
unique_names$company_name_clean <- gsub(paste0("\\b", stop_words, "\\b", collapse = "|"),
                                        "",
                                        unique_names$company_name_clean)

unique_names$company_name_clean <- str_squish(unique_names$company_name_clean)


# fuzzy matching the names on themselves to try and standardise -----------

# getting new list of names after the initial basic cleaning
unique_names_fuzzy <- unique_names |>
  group_by(company_name_clean) |>
  summarise(spend = sum(spend)) |>
  ungroup()

# fuzzy matching the name column on itself
# max_dist set at appropriate level for dataset
# if no matches are found (the only match is on itself) then is kept in the record
unique_names_fuzzy <- unique_names_fuzzy |>
  stringdist_inner_join(unique_names_fuzzy,
                        max_dist = 0.30,
                        distance_col = "distance",
                        method = "jw",
                        by = c(company_name_clean = "company_name_clean")) |>
  rename(company_name_clean = "company_name_clean.x",
         company_name_clean_spend = "spend.x",
         company_name_clean_match = "company_name_clean.y",
         company_name_clean_match_spend = "spend.y") |>
  arrange(company_name_clean, distance, company_name_clean_match) |>
  group_by(company_name_clean) |>
  mutate(no_match = length(unique(company_name_clean_match[distance != 0])) == 0) |>
  ungroup() |>
  filter(distance != 0 | no_match == TRUE)

# adding phonetic matching to increase confidence in matching
unique_names_fuzzy$company_name_clean_phon <- phonetic(unique_names_fuzzy$company_name_clean)
unique_names_fuzzy$company_name_clean_match_phon <- phonetic(unique_names_fuzzy$company_name_clean_match)

# taking the best match if there is only one
# some names may get matched to multiple other names with the exact same distance
# accept ties as otherwise it just picks the first (alphabetical) which is arbitrary
unique_names_fuzzy <- unique_names_fuzzy |>
  group_by(company_name_clean) |>
  slice_min(order_by = distance,
            n = 1,
            with_ties = TRUE) |>
  mutate(single_match = (n() == 1)) |>
  ungroup() |>
  select(c(company_name_clean, company_name_clean_spend,
           company_name_clean_match, company_name_clean_match_spend,
           distance, single_match, company_name_clean_phon, company_name_clean_match_phon)) |>
  arrange(company_name_clean, distance)

# logic for accepting the match
unique_names_fuzzy <- unique_names_fuzzy |>
  mutate(
    accept_match = case_when(
      (single_match == TRUE) & (distance < 0.05) ~ TRUE,
      (company_name_clean_phon == company_name_clean_match_phon) & (distance < 0.10) ~ TRUE,
      .default = FALSE)
  )

# if there is more than one equal match (same distance and both or neither phonetically identical)
# take the name with the largest spend
unique_names_fuzzy <- unique_names_fuzzy |>
  filter(single_match == TRUE | accept_match == TRUE) |>
  group_by(company_name_clean) |>
  slice_max(order_by = company_name_clean_match_spend,
            n = 1,
            with_ties = FALSE) |>
  ungroup()

# reviewing the matches and taking the final name that is largest
# if a large name is matched to a small name, the small name is absorbed into the large name
unique_names_fuzzy <- unique_names_fuzzy |>
  mutate(
    company_name_clean_final = case_when(
      (accept_match == TRUE) & (company_name_clean_spend >= company_name_clean_match_spend) ~ company_name_clean,
      (accept_match == TRUE) & (company_name_clean_spend < company_name_clean_match_spend) ~ company_name_clean_match,
      TRUE ~ company_name_clean)
  )

# getting final matches
unique_names_fuzzy <- unique_names_fuzzy |>
  select(c(company_name_clean, company_name_clean_final)) |>
  distinct()

# joining the matched names on themselves to follow the chain of matches
# e.g. if 'amazing' is matched to 'amazn' and 'amazn' is separately matched to 'amazon'
# we want 'amazing' to follow the chain and be matched to the final/largest value i.e. 'amazon'
unique_names_fuzzy <- left_join(x = unique_names_fuzzy,
                                y = unique_names_fuzzy,
                                by = c("company_name_clean_final" = "company_name_clean")) |>
  select(c(company_name_clean, company_name_clean_final.y)) |>
  rename("company_name_clean_final" = "company_name_clean_final.y") |>
  distinct()

# joining back up with original list
unique_names <- left_join(x = unique_names,
                          y = unique_names_fuzzy,
                          by = "company_name_clean") |>
  select(-c(company_name_clean))

# cleaning for manual review
unique_names_for_review <- left_join(x = companies,
                                     y = unique_names,
                                     by = "company_name") |>
  select(-c("spend.y")) |>
  rename("spend" = "spend.x")

# taking the largest original name as the final name for all matches
unique_names_for_review <- unique_names_for_review |>
  group_by(company_name_clean_final) |>
  mutate(suggested_match = company_name[which.max(spend)]) |>
  ungroup() |>
  arrange(suggested_match)

# exporting Excel file for review (if needed)
write_xlsx(unique_names_for_review, paste0("./output/unique_names_for_review ", format(Sys.time(), "%Y-%m-%d"), ".xlsx"))
