## To Do

- remove automatic variables from the summary screen when modifying a survey




- Kollect, the name of the app - or GiSTKollect
- add text backup files when writing to the database
- add an 'i' for additional information - help the end-user - might need an additional column in the spreadsheet
- set up data management website per project - create an app that listens for new data and uploads to the server
- Add 'time' question type
- examine "idconfig" - have option of entering the subjid manually
- subjid and hhid - these should be normal automatic variables - check these
- a person can sleep under more than one net - how can we check this?
- Add stats. All eligible variables in accordian type, one opens, one closes
- stats page - have it dynamic - in the data dictionary have a summary_statistics page - have a 
- revisit 'repeat' sections - maybe have them 'inline' - asked at a point in time before the 'main' survey is over - then user can go 'back' through all of them.
- Add 'button' question type?
- Add dynamic date ranges. If someone is two years old, don't let date go back now tham 2 years. This can also be logic check



### Info
For Android (APK)
Instead of flutter build apk: Run 
.\build_apk.ps1

For Windows
Instead of flutter build windows: Run 
.\build_windows.ps1

Both of these scripts will now:

Automatically increment the version in 
pubspec.yaml
 (e.g., 0.0.1 -> 0.0.2).
Run the build command for you.

## GistXConfig
- look at the code for parsing skips - add multiple logic: if xxx = 1 and yyy < 5, then skip to...


## To test
- when viewing/modifying a survey
    - are the correct changes made in the DB
    - are changes saved to the formchanges table
- does the previous button always take you to the correct question

## Instructions
- have a new version (surveyID) for each updated survey