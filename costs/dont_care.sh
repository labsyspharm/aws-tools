#!/bin/sh

# Drop CSV rows with any of:
# * sub-penny non-negative Cost
# * a totally empty value

csvtk filter2 -f '($Cost >=  .005) || ($Cost < 0)' \
  | csvtk grep -v -r -p '^$'
