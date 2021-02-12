# test
library(here)
library(tidyverse)
library(foreign)

# Reading in packages 
if("qualtRics" %in% rownames(installed.packages()) == FALSE) {
  install.packages("qualtRics", dependencies = TRUE)
}
if("xlsx" %in% rownames(installed.packages()) == FALSE) {
  install.packages("xlsx", dependencies = TRUE)
}
if("lubridate" %in% rownames(installed.packages()) == FALSE) {
  install.packages("lubridate", dependencies = TRUE)
}
library(qualtRics)
library(xlsx)
library(tidyverse)
library(lubridate)

# Reading in and setting credentials
credentials <- read.csv(file = here::here("Data Collection/", "credentials.txt"),
                        sep= "",
                        stringsAsFactors =  FALSE)

key <- credentials %>% 
  filter(name == "qualtrics") %>%
  .$key

qualtrics_api_credentials(
  api_key = key,
  base_url = "iad1.qualtrics.com",
  install = TRUE
)

# Tibble of all ma surveys
surveys <- all_surveys()

# Function for reading in and saving the survey to the Y 
get_and_save_forms <- function(surveyname, return = TRUE, location) {
  
  ## Add something that only downloads it if last modified recently 
  ## and is currently active 
  id = surveys %>%
    filter(name == surveyname) %>%
    .$id
  
  survey <- fetch_survey(surveyID = id, 
                         force_request = TRUE) 
  
  question_text <- survey_questions(id) %>%
    select(qname, question) 
    
  
  today <- as.character(Sys.Date())
  filepath <- paste0("Y:/LHP/FUP/Impact Study/RData/Qualtrics/",location, today, ".xlsx")
  
  xlsx::write.xlsx(x = survey, 
             file = filepath, 
             sheetName = "Responses")
  xlsx::write.xlsx(x = question_text, 
             file = filepath, 
             sheetName = "Question Text", 
             append = TRUE)
  
  print(paste0("file saved to ", filepath, "!!!!"))
  
  if(return == TRUE) {
    return(survey)
  }
}

# Do the thing 
get_and_save_forms(surveyname = "FUP Housing Status Form - PHX", location = "PHX_HSF/PHX_HSF", return = FALSE)

phx_haq <- get_and_save_forms(surveyname = "Housing Application and Search Assistance Questionnaire - PHX",  location = "PHX_HAQ/PHX_HAQ")
phx_osq <- get_and_save_forms(surveyname = "Ongoing Services Questionnaire - PHX", location = "PHX_OSQ/PHX_OSQ")
oc_osq <- get_and_save_forms(surveyname = "Ongoing Services Questionnaire - OC", location = "OC_OSQ/OC_OSQ")
oc_haq <- get_and_save_forms(surveyname = "Housing Application and Search Assistance Questionnaire - OC", location = "OC_HAQ/OC_HAQ")

# Only do these once a week on Fridays 
today <- as.character(Sys.Date())
today_date <- ymd(today)
today_day <- wday(today_date)

if(today_day == 6) {
  get_and_save_forms(surveyname = "Referral Form Pt. 1-PHX", location = "PHX_Referral/PHX_Referral1_", return = FALSE)
  get_and_save_forms(surveyname = "Referral Form Pt. 2-PHX", location = "PHX_Referral/PHX_Referral2_", return = FALSE)
  
}


## Making a .dta with who is in what survey -- one for HAF one for OSQ
## take a look at surveys to see if this is accurately representing them 

phx_haq_ids <- phx_haq %>%
  # removing test cases per rule instructed by Audrey as noted in Y:\LHP\FUP\Impact Study\RData\Qualtrics\PHX_HAQ\PHX_HAQ_2021_02_05_flagged.csv 
  mutate(Q5 = tolower(Q5), 
         is_test = ifelse(str_detect(Q5, "test") == TRUE, 1, 0)) %>%
  filter(is_test == 0 | is.na(is_test)) %>%
  # removing incomplete entries as specified in the same file 
  mutate(num_na = rowSums(is.na(.)),
         is_incomplete = ifelse(num_na > 51, 1, 0))  %>%    # this flags the same number of incomplete entries as in Audrey's test .csv above 
  assertr::verify(is_incomplete == 0 | is_incomplete == 1) %>%
  filter(is_incomplete == 0) %>%
  # getting just list of IDs
  rename(p_id = caseid) %>%
  select(p_id) %>% 
  distinct() %>%
  mutate(site = 2)

oc_haq_ids <- oc_haq %>% 
  # doesn't seem like there's any tests in here?
  select(p_id) %>%
  filter(!is.na(p_id)) %>%
  distinct() %>%
  mutate(site = 3, 
         p_id = tolower(p_id))

haq_ids <- phx_haq_ids %>%
  bind_rows(oc_haq_ids)

write.dta(haq_ids, "Y:/LHP/FUP/Impact Study/Temp/HAF_Completed.dta")


phx_osq_ids <- phx_osq %>%
  # removing test cases per rule instructed by Audrey as noted in Y:\LHP\FUP\Impact Study\RData\Qualtrics\PHX_HAQ\PHX_OSQ_2021_02_05_flagged.csv 
  mutate(StartDate = date(StartDate)) %>%
  filter(StartDate >= date("2021-01-05")) %>%
  # removing incompletes 
  mutate(num_na = rowSums(is.na(.)),
         is_incomplete = ifelse(num_na >= 93, 1, 0)) %>% # this flags the same number of incomplete entries as in Audrey's file above 
  assertr::verify(is_incomplete == 1 | is_incomplete == 0) %>%
  filter(is_incomplete == 0) %>%
# getting list of IDs
  rename(p_id = caseid) %>%
  select(p_id) %>%
  mutate(p_id = as.character(p_id)) %>%
  distinct() %>%
  mutate(site = 2)

oc_osq_ids <- oc_osq %>%
  # remove testing before Jan 12
  mutate(startDate = date(StartDate)) %>%
  filter(StartDate >= date("2021-01-12")) %>%
  select(p_id) %>%
  filter(!is.na(p_id)) %>%
  distinct() %>%
  mutate(site = 3, 
         p_id = tolower(p_id))

osq_ids <- phx_osq_ids %>%
  bind_rows(oc_osq_ids)

write.dta(osq_ids, "Y:/LHP/FUP/Impact Study/Temp/OSQ_Completed.dta")






