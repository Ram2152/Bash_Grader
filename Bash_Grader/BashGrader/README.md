# Bash Grader Project

## Overview

The *Bash Grader Project* is a comprehensive solution for managing and interpreting CSV files containing student data for various exams. It includes a set of Bash scripts and Python modules to perform various operations on these files, enhancing efficiency and usability.

## Features

### Basic Functionalities

- *CSV Processing*:
  - combine: Compiles marks from multiple CSV files into main.csv.
  - upload: Uploads a new CSV file to the script's directory.
  - total: Adds a column for total marks in main.csv.
  - update: Updates student marks in main.csv and individual files.

- *Git Integration*:
  - git init: Initializes a remote directory for version control.
  - git commit: Commits changes to the remote directory.
  - git checkout: Reverts to a specified commit.
  - Extended Git functionalities including git add, git log, git status, git clone, git amend, switchrepo, and currrepo.

### Customizations

- *Statistics and Visualization*:
  - Calculation of mean, median, standard deviation, minimum, maximum, and percentiles.
  - Graph generation using Python modules (Matplotlib) for histograms and bar charts.

- *Reporting*:
  - show: Displays a mini report card for a student, including percentile and attendance.

### Error Handling

- Personalized error messages for common mistakes such as invalid commands or roll numbers.
- Error handling for Git operations, ensuring user-friendly messages for issues like non-existent directories or invalid commit IDs.

## Pre-Requisites

- *Bash Utilities*: sed, awk, bc
- *Python3* and Libraries: numpy, matplotlib, pandas, sys, scipy, tabulate


## Conclusion

The Bash Grader Project is designed to be a modular and flexible tool for educators to manage student exam data efficiently. It leverages both Bash scripting and Python for enhanced functionality and ease of use.

## References

- [Bash Documentation](https://www.javatpoint.com/bash)
- [Python Libraries Documentation](https://www.w3schools.com)

## Acknowledgments

Special thanks to Saksham Rathi for guidance and support, and to peers and mentors for their valuable feedback during the project implementation.

---

Feel free to explore and contribute to this project to make it even better!
