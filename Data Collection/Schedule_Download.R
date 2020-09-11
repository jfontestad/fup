

if("taskscheduleR" %in% rownames(installed.packages()) == FALSE) {
  install.packages("taskscheduleR", dependencies = TRUE)
}
library(taskscheduleR)

taskscheduler_delete("download_forms")

taskscheduler_create(taskname = "download_forms", rscript = "Y:/LHP/FUP/Impact Study/Do/Data Collection/Download_Qualtrics.R", 
                     schedule = "DAILY", 
                     starttime = "07:00", 
                     startdate = format(Sys.Date(), "%m/%d/%Y"))

