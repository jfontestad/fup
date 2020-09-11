# http://www.jason-french.com/blog/2012/03/27/integrating-r-and-qualtrics/
  # figure out how to download this once
# then do the cron job 

# Reading in packages 
if("qualtRics" %in% rownames(installed.packages()) == FALSE) {
  install.packages("qualtRics", dependencies = TRUE)
  }
library(qualtRics)
library(tidyverse)

# Reading in and setting credentiasl 
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
  
  today <- Sys.Date()
  filepath <- paste0("Y:/LHP/FUP/Impact Study/", location, today, ".csv")
  write.csv(survey, filepath)
  
  print(paste0("file saved to ", filepath, "!!!!"))
  
}

# Do the thing 
get_forms(name = "Kate Test Survey", location = "Temp/IceCream")



