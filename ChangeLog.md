### 0.0.8


### 0.0.7
* Added 'startdate' automatic field type
* Added `date_offset` calculation type to calculate date-diff between two dates
* Added optional regex formatting (input masking) for text fileds
* Changed the exit prompt when modifying a survey to: "Are you sure you want to cancel. All edits/modifications will be lost!"
* Implemented cascading clear logic for dependent fields so that changing a 'parent' field clears 'child' fields
* Implemented a "Review Changes" system for survey modifications that generates a logical summary replacing technical IDs with human-readable labels and expanding placeholders like `[[participantsname]]`.
* Integrated numeric-aware logic into the summary system to highlight genuine data changes while ignoring benign differences like numeric padding.
* Added three options to the review dialog: Save Changes, Back to Edit, or Discard & Exit, with a secondary confirmation for the discard option.