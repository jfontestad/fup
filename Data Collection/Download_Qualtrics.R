# test

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
credentials <- read.csv("Y:/LHP/FUP/Impact Study/Do/Data Collection/credentials.txt", 
                        sep="",
                        stringsAsFactors =  FALSE)

key <- credentials %>% 
  filter(name == "qualtrics") %>%
  .$key

qualtrics_api_credentials(
  api_key = key,
  base_url = "iad1.qualtrics.com"
)

# Tibble of all ma surveys
surveys <- all_surveys()

# Function for reading in and saving the survey to the Y 
get_forms <- function(surveyname, location) {
  
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
  
  # maybe skip certain days of the week for certain surveys if I only want this weekly
}

# Do the thing 
get_forms(surveyname = "Housing Application and Search Assistance Questionnaire - PHX", location = "PHX_HAQ/PHX_HAQ")
get_forms(surveyname = "FUP Housing Status Form - PHX", location = "PHX_HSF/PHX_HSF")
get_forms(surveyname = "Ongoing Services Questionnaire - OC", location = "OC_OSQ/OC_OSQ")
get_forms(surveyname = "Housing Application and Search Assistance Questionnaire - OC", location = "OC_HAQ/OC_HAQ")

# Only do these once a week on Fridays 
today <- as.character(Sys.Date())
today_date <- ymd(today)
today_day <- wday(today_date)

if(today_day == 6) {
  get_forms(surveyname = "Referral Form Pt. 1-PHX", location = "PHX_Referral/PHX_Referral1_")
  get_forms(surveyname = "Referral Form Pt. 2-PHX", location = "PHX_Referral/PHX_Referral2_")
  
}




