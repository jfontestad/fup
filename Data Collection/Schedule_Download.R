

if("taskscheduleR" %in% rownames(installed.packages()) == FALSE) {
  install.packages("taskscheduleR", dependencies = TRUE)
}
library(taskscheduleR)

taskscheduler_create(taskname = "download_forms", rscript = "Y:/LHP/FUP/Impact Study/Do/Data Collection/Download_Qualtrics.R", 
                     schedule = "DAILY", 
                     starttime = "14:30", 
                     startdate = format(Sys.Date(), "%d/%m/%Y"))


## update the time, maybe 7 am 
