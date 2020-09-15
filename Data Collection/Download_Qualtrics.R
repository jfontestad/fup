

# Reading in packages 
if("qualtRics" %in% rownames(installed.packages()) == FALSE) {
  install.packages("qualtRics", dependencies = TRUE)
  }
library(qualtRics)
library(tidyverse)

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
get_forms <- function(name, location) {
  
  id = surveys %>%
    filter(name == name) %>%
    .$id
  
  survey <- fetch_survey(surveyID = id, 
                         force_request = TRUE)
  
  today <- as.character(Sys.Date())
 
  filepath <- paste0("Y:/LHP/FUP/Impact Study/RData/Qualtrics/", location, today, ".csv")
  write.csv(survey, filepath)
  
  print(paste0("file saved to ", filepath, "!!!!"))
  
}

# Do the thing 
get_forms(name = "Housing Application and Search Assistance Questionnaire - PHX", location = "PHX_HAQ/PHX_HAQ")
get_forms(name = "FUP Housing Status Form - PHX", location = "PHX_HSF/PHX_HSF")
get_forms(name = "Ongoing Services Questionnaire - OC", location = "OC_OSQ/OC_OSQ")
get_forms(name = "Housing Application and Search Assistance Questionnaire - OC", location = "OC_HAQ/OC_HAQ")






