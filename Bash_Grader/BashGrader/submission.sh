#!/bin/bash
# Define constants
MAIN_CSV="main.csv"
REMOTE_REPO=".git_repo"
LOG_FILE=".git_log"
WD="$PWD"
# Function to combine all CSV files into main.csv
combine() {
    if [ -f main.csv ]; then
        # If total command was called, make sure total column is added
        total_present=$(head -n 1 main.csv | grep "total")
        total_it="0"
        if [ -n "$total_present" ]; then
            total_it="1"
        fi
        rm main.csv
    fi

    # Create an array of csv files other than main.csv to iterate later
    csv_files_array=( *.csv )

    # Store unique Roll number and Name pairs in Roll_Numbers.txt
    csv_files=$(ls *.csv 2>/dev/null)
    tail -q -n +2 $csv_files | awk -F, 'BEGIN{OFS=","} {print $1,$2}' | sort | uniq > Roll_Numbers.txt
    
    # Initialize main.csv with headers
    echo -n "Roll_Number,Name" > main.csv
    
    # Iterate over all CSV files
    for file in "${csv_files_array[@]}"; do
        # Get exam name from file name
        exam=$(basename "$file" .csv)
        # Add exam name to main.csv headers
        echo -n ",$exam" >> main.csv

    done
    echo "" >> main.csv

    # Iterate through all Roll numbers and get the marks from every exam
    while IFS=, read -r roll_number name; do
        # Initialise the row with roll number and name
        row="$roll_number,$name"
        for exam_file in "${csv_files_array[@]}"; do
            # Search for student's marks in current CSV file
            student_marks=$(grep -m 1 "^$roll_number," "$exam_file" | cut -d ',' -f 3)
            if [ -z "$student_marks" ]; then
                # If student is absent, mark as "a"
                row="$row,a"
            else
                row="$row,$student_marks"
            fi
        done
        # Add row to main.csv
        echo "$row" >> main.csv
    done < <(cat Roll_Numbers.txt)
    if [ "$total_it" = "1" ]; then
        total
    fi
}

# Function to upload new CSV files from the specified path
upload() {
    # Check for file existence
    if [ ! -f "$1" ]; then
        echo "File does not exist in the specified path..!!"
        exit 1
    fi
    # Copy uploaded file to current directory
    cp "$1" .
}

# Function to make the total column to main.csv
total() {
    # Check if total column is already present
    header=$(head -n 1 main.csv)
    #Search for total
    total_present=$(echo "$header" | grep "total")
    if [ -z "$total_present" ]; then
        # If total absent, let main.csv remain as main.csv
        echo -n ""
    else
        # Extract all columns except the total column from each line in main.csv
        NF=$(head -n 1 main.csv | awk -F',' '{print NF}')
        let Num=NF-1
        echo "$(cut -d ',' -f 1-$Num main.csv)" > main.csv
    fi

    # Calculate total marks for each student
    while IFS=, read -r roll_number name marks; do
        if [ "$roll_number" = "Roll_Number" ]; then
            echo "$roll_number,$name,$marks,total" > "$MAIN_CSV"
        else
            total_marks=0
            # upd_marks stores every mark in a different line (easier to iterate)
            upd_marks=$(echo "$marks" | tr ',' '\n')
            while IFS=, read -r mark; do
                # Adding marks if student wasn't absent
                if [ "$mark" != "a" ]; then
                    mark_float=$(echo "$mark" | bc)
                    total_marks=$(echo "$total_marks + $mark_float" | bc)
                fi
            done < <(echo "$upd_marks")
            # Append line to main.csv along with total
            echo "$roll_number,$name,$marks,$total_marks" >> "$MAIN_CSV"
        fi
    done < <(cat "$MAIN_CSV")
}

# Function to initialize the remote repository
git_init() {
    # Check if folder exist
    if [ ! -d "$2" ]; then
        mkdir "$2"
    fi
    # Navigate to the Remote folder to initialize remote repository
    cd "$2"
    # Initialize remote repository
    if [ ! -d ".git_repo" ]; then
        mkdir .git_repo
        mkdir .git_repo/Versions
        cd "$WD"
        echo "$2" >> AllRepos.txt
    fi
    # Store the path in Repo.txt
    echo "$2" > Repo.txt
}

# Function to add files to staging area
git_add() {
    if [ ! -f "$2" ]; then
        cd "$(cat Repo.txt)"
        if [ -f "$2" ]; then
            if [ ! -f "${WD}/git_add.txt" ] || ! grep -q "^$2$" "${WD}/git_add.txt"; then
                echo "$2" >> "${WD}/git_add.txt"
            fi
        else
            echo "No Such file to add"
            exit 0
        fi
    fi
    cd "$WD"
    if [ -f "$2" ]; then
        cd "$(cat Repo.txt)"
        lc=$(wc -l .git_repo/.git_log | cut -d ' ' -f 1)
        # To keep track if there has been a change
        changes="0"
        # Check if there has been a commit to compare our working directory with
        if [ "$lc" = "0" ]; then
            # Add the file name in git_add.txt only if it is not there already
            if [ ! -f "${WD}/git_add.txt" ] || ! grep -q "^$2$" "${WD}/git_add.txt"; then
                echo "$2" >> "${WD}/git_add.txt"
            fi
        else    
            # Compare between the last commit and the working directory
            previous_commit=$(cat .git_repo/.git_log | tail -n 1 | head -n 1 | cut -d ':' -f 1)
            # If file not present in the previous commit, which means file was created. So Add it.
            if [ ! -f ".git_repo/Versions/${previous_commit}/$2" ]; then
                if [ ! -f "${WD}/git_add.txt" ] || ! grep -q "^$2$" "${WD}/git_add.txt"; then
                    echo "$2" >> "${WD}/git_add.txt"
                fi
            else
                # If file existed in the previous commit, check if there has been any change to commit
                difference=$(diff ".git_repo/Versions/${previous_commit}/$2" "${WD}/$2")
                if [ -n "$difference" ]; then
                    if [ ! -f "${WD}/git_add.txt" ] || ! grep -q "^$2$" "${WD}/git_add.txt"; then    
                        echo "$2" >> "${WD}/git_add.txt"
                    fi
                else
                    echo "The file wasn't modified" 
                fi
            fi
        fi
    fi
}

# Function to commit current version to remote repository
git_commit() {
    # Check if any file has been changed 
    if [ "$(bash submission.sh git_status )" = "No Change in files with the previous commit" ]; then
        echo "No file has been changed/added/removed"
        echo "Nothing to Commit!"
        exit 0
    fi

    # If git_add was called before, then commit only those files
    if [ -f 'git_add.txt' ]; then
        cd "$(cat Repo.txt)"
        commit_message="$2"
        # Generate random hash value
        hash_value=$(openssl rand -hex 8)
        # Make a directory for the hash value
        mkdir ".git_repo/Versions/${hash_value}"
        echo "$hash_value: $commit_message" >> .git_repo/.git_log
        cd "$WD"
        # Read git_add.txt line by line to get list of files to be committed
        while read -r filename; do
            # If file is there in git_add.txt, but not in working directory, it means we have removed it and we want to commit that change
            if [ ! -f "$filename" ]; then
                cd "$(cat Repo.txt)"
                rm "$filename"
                cd "$WD"
            else
                # If file is created or modified, the below takes care of both cases
                cd "$(cat Repo.txt)"
                cat "${WD}/$filename" > "$filename"
                cd "$WD"
            fi
        done < <(cat 'git_add.txt')
        cd "$(cat Repo.txt)"
        # Copy from Remote Repository to the git folder for storing it in Versions
        cp *.csv ".git_repo/Versions/${hash_value}"
        echo "Files committed with message: $commit_message and hash: $hash_value"
        cd "$WD"
        rm git_add.txt
        exit 0
    fi

    cd "$WD"

    # Navigate to the remote repository
    cd "$(cat Repo.txt)"
    cp ${WD}/*.csv .

    commit_message="$2"
    # Generate random hash value
    hash_value=$(openssl rand -hex 8)
    # Make a directory for the hash value
    mkdir ".git_repo/Versions/${hash_value}"
    # Copy current version of files to remote repository
    cp ${WD}/*.csv ".git_repo/Versions/${hash_value}"
    echo "Files committed with message: $commit_message and hash: $hash_value"
    # Add the commit details to .git_log file
    echo "$hash_value: $commit_message" >> .git_repo/.git_log

    lc=$(wc -l .git_repo/.git_log | cut -d ' ' -f 1)
    # To keep track if there has been a change
    changes="0"
    # Check for number of commits
    if [ "$lc" -eq 1 ]; then
        echo "This is the first commit. No Previous Commits to compare modification"
    else    
        # Compare between last commit and last but one commit
        latest_commit=$(cat .git_repo/.git_log | tail -n 1 | cut -d ':' -f 1)
        previous_commit=$(cat .git_repo/.git_log | tail -n 2 | head -n 1 | cut -d ':' -f 1)
        # For files in the recent commit
        for file in .git_repo/Versions/${latest_commit}/*.csv; do
            file=$(echo "$file" | cut -d '/' -f 4)
            # If a file is present in recent commmit but not the previous commit
            if [ ! -f ".git_repo/Versions/${previous_commit}/$file" ]; then
                echo "Added ${file}"
                echo "-----"
                cat ".git_repo/Versions/${latest_commit}/$file"
                echo ""
                echo "-----"
                changes="1"
                continue
            fi
            difference=$(diff ".git_repo/Versions/${previous_commit}/$file" ".git_repo/Versions/${latest_commit}/$file")
            # If diff returns some non empty string, then there has been some change
            if [ -n "$difference" ]; then
                echo "${file} was changed"
                echo "-----"
                cat ".git_repo/Versions/${latest_commit}/$file"
                echo ""
                echo "-----"
                changes="1"
            fi
        done
        # For files in the previous commit to check if it is removed
        for file in .git_repo/Versions/${previous_commit}/*.csv; do
            file=$(echo "$file" | cut -d '/' -f 4)
            if [ ! -f ".git_repo/Versions/${latest_commit}/$file" ]; then
                echo "Removed ${file}"
                echo "-----"
                cat .git_repo/Versions/${previous_commit}/$file
                echo "-----"
                changes="1"
            fi
        done
        # If no change, convey the same to the user
        if [ "$changes" = "0" ]; then
            echo "No Change in files with the previous commit"
        fi
    fi
}

# Function to checkout to a specific commit
git_checkout() {
    # Navigate to the remote repository
    cd "$(cat Repo.txt)"
    if [ "$2" != "-m" ]; then
        commit_identifier="$2"
        # Search for commit with specified message or hash value
        commit=$(grep -E "^$commit_identifier" .git_repo/.git_log | cut -d ':' -f 1)
        if [ -n "$commit" ]; then
            # Count the number of lines in the string
            line_count=$(echo "$commit" | wc -l)

            # Check if the number of lines is more than 1
            if [ "$line_count" -gt 1 ]; then
                echo "CONFLICT! More than 1 Commit ids start with the same sequence"
                echo "The Commits starting with the specified sequence are:"
                echo "$commit"
            else
                # Copy files from specified commit to current directory
                cd "$WD"
                rm *.csv
                cd "$(cat Repo.txt)"
                cp $REMOTE_REPO/Versions/$commit/*.csv $WD
                echo "Checked out to commit: $commit"
            fi
        else
            echo "Commit not found..!!"
            echo "Try using git_log to see the commit history"
            echo "Usage: \"bash submission.sh git_log\""
        fi
    else
        commit_identifier="$3"
        # Search for commit with specified message or hash value
        commit=$(grep -E ": $commit_identifier$" .git_repo/.git_log | cut -d ':' -f 1)
        if [ -n "$commit" ]; then
            # Count the number of lines in the string
            line_count=$(echo "$commit" | wc -l)

            # Check if the number of lines is more than 1
            if [ "$line_count" -gt 1 ]; then
                echo "CONFLICT! More than 1 Commit ids have the same Commit message"
                echo "The Commits with the specified Commit message are:"
                echo "$commit"
            else
                # Copy files from specified commit to current directory
                cd $WD
                rm *.csv
                cd "$(cat Repo.txt)"
                cp .git_repo/Versions/$commit/*.csv $WD
                echo "Checked out to commit: $commit"
            fi
        else
            # Redirecting the user to git_log
            echo "Commit not found..!!"
            echo "Try using git_log to see the commit history"
            echo "Usage: \"bash submission.sh git_log\""
        fi
    fi
}

# Function to update marks for a student
update() {
    # Read Roll No., Name, Exam_name, Mark 
    read -p "Enter Roll Number: " roll_number
    read -p "Enter Name: " name
    read -p "Enter Exam Name: " exam
    read -p "Enter Mark: " mark
    
    # Extract file from exam name
    file=$(ls *.csv | grep -i "^${exam}.csv")
    # Error if no such exam file exist
    if [ ! -n "$file" ]; then
        echo "Enter a valid exam name..!!"
        echo "List of valid exam names are"
        ls *.csv | grep -v "main.csv" | grep -n "^.*$" | sed "s/.csv//"
        exit 1
    fi
    # Update individual file
    rno_present=$(grep -E "^$roll_number" "$file")
    # If student roll_number not present, add a new row
    if [ -n "$rno_present" ]; then
        sed -i -E "/^$roll_number/ s/^([^,]*),([^,]*),([^,]*)$/\1,\2,$mark/" "$file"
    else
        echo "$roll_number,$name,$mark" >> "$file"
    fi

    # Check if main.csv is present
    if [ ! -f "main.csv" ]; then
        echo "main.csv file is not present..!!"
        # Ask the user if main.csv should be created
        read -p "Do you want to create main.csv with the updated marks?[Y/n]:" choice
        a="Loop"
        while [ "$a" = "Loop" ]
        do
            case "$choice" in
                Y)
                    a="Done"  
                    combine
                    ;;
                n)
                    a="Done"
                    echo -n ""
                    ;;
                *)
                    read -p "Enter a valid choice [Y/n]:" choice
                    ;;
            esac
        done
        exit 1
    fi
    if [ -f "main.csv" ]; then
        # Ask if user wants to update main.csv
        read -p "Do you want to update main.csv?[Y/n]:" choice
        a="Loop"
        while [ "$a" = "Loop" ]
        do
            case "$choice" in
                Y)
                    a="Done"
                    combine
                    ;;
                n)
                    a="Done"
                    echo -n ""
                    ;;
                *)
                    read -p "Enter a valid choice [Y/n]:" choice
                    ;;
            esac
        done
        exit 1
    fi

}

# Function to list all functions
list() {
    echo "List of Commands Available:"
    echo "1. \"bash submission.sh combine\": Combines all .csv files and creates main.csv"
    echo "2. \"bash submission.sh upload <path-to-csv-file>\": Copies the csv file to the current working directory"
    echo "3. \"bash submission.sh total\": Creates a column total in main.csv"
    echo "4. \"bash submission.sh update\": Updates the mark of a student in a particular exam"
    echo "5. \"bash submission.sh stats <operation>\": Does the specified operation on marks of a particular exam or total marks"
    echo "6. \"bash submission.sh show <roll_number>\": Displays the mark of a particular student in every exam" 
    echo "7. \"bash submission.sh display\": To plot the graph of marks and store it in Graph.png"
    echo "8. \"bash submission.sh git_init <path-to-the-remote-folder>\": Initializes a remote repository in the remote folder"
    echo "9. \"bash submission.sh git_add <file-to-be-added>\": Adds the file to staging area"
    echo "10. \"bash submission.sh git_commit -m \"<Commit-message>\"\": Stores the current versions of all csv files to the remote directory"
    echo "11. \"bash submission.sh git_checkout <Commit-id> | bash submission.sh git_checkout -m \"<Commit-message>\" | bash submission.sh git_checkout master\": Reverts our current directory to the commit we specify"
    echo "12. \"bash submission.sh git_log\": Prints the commit history"
    echo "13. \"bash submission.sh git_status\": Print the changes done to working directory compared to the most recent commit"
    echo "14. \"bash submission.sh git_clone <Path-of-the-git-repo> <Output-dir-to-clone-the-repo>\": Clones the git repo in the output directory"
    echo "15. \"bash submission.sh git_currrepo\": Prints the path to the Current Repo the user is working on"
    echo "16. \"bash submission.sh git_switchrepo <Path-to-the-repo>\": Switches Repository to make the user work with more than one repo at a time"
    echo "17. \"bash submission.sh git_amend -m \"<commit-message>\"\": Changes the latest commit with the current version of files and the new Commit message"
}

# Function to show marks of a particular student
show() {
    main_present="0"
    # If main.csv not present, create and delete it
    if [ ! -f 'main.csv' ]; then
        main_present="1"
    fi

    #Check if roll number exist
    list_of_rollno=$(cat Roll_Numbers.txt | cut -d ',' -f 1)
    found=$(echo "$list_of_rollno" | grep "^$2$")
    if [ -n "$found" ]; then
        echo "Report Loading..."
        # To be upto date with roll numbers
        combine
        # To have total column
        total
        # Call Show.py with the roll number as an command line argument
        python3 Show.py "$2"
    else
        echo "The mentioned Roll Number is not in the list of student roll numbers..!!"
        echo "The List of Roll Numbers:"
        echo "$list_of_rollno"
    fi

    # Remove main.csv if it wasn't present earlier
    if [ "$main_present" = "1" ]; then
        rm main.csv
    fi
}

git_clone() {
    # Store the repository and output directory
    dir="$2"
    opdir="$3"

    # Check for existence of Repository
    if [ ! -d "$dir" ]; then
        echo "The Specified argument is not a directory"
        exit 1
    fi

    # Check if Git was initialised
    if [ ! -d "${dir}/.git_repo" ]; then
        echo "Git wasn't initialised in the directory"
        echo "List of directories where Git was initialised is as follows"
        cat AllRepos.txt
        exit 1
    fi

    # Check if output directory exist
    if [ ! -d "$opdir" ]; then
        echo "The final destination is not a directory"
        exit 1
    fi

    # Copy the contents of GitRepo to the Output Directory
    cp -r "$dir" "$opdir"
}

git_currrepo() {
    # Check if there has been a Git initialised
    if [ ! -f 'Repo.txt' ]; then
        echo "Git wasn't initialised in any repository"
        echo "Try using git_init"
        echo "Usage: \"bash submission.sh git_init <path-to-the-remote-folder>\""
        exit 1
    fi

    # Print the Current Repo
    echo "$(cat Repo.txt)"
}

git_switchrepo() {
    # Check if Repository exist
    if [ ! -d "$2" ]; then
        echo "Repository doesn't exist"
        exit 1
    fi

    # Check if Git was initialised
    if [ ! -d "$2/.git_repo" ]; then
        echo "Git wasn't initialised in the repo"

        # Print all Repos where Git was initialised so far
        echo "List of repositories where Git was initialised is as follows"
        cat AllRepos.txt
        exit 1
    fi
    echo "$2" > Repo.txt
}

git_amend() {
    cd "$(cat Repo.txt)"
    # Check if there has already been a commit to amend
    lc=$(wc -l .git_repo/.git_log | cut -d ' ' -f 1)
    if [ "$lc" = "0" ]; then
        echo "No Previous Commits to amend"
    else
        # Commit the files to the Remote Repository
        rm *.csv
        cp ${WD}/*.csv .

        # Extract the latest commit and add the files to the corresponding directory in Versions
        previous_commit=$(cat .git_repo/.git_log | tail -n 1 | head -n 1 | cut -d ':' -f 1)
        cd ".git_repo/Versions/$previous_commit"
        rm *.csv
        cp ${WD}/*.csv .

        # Change the commit message of the latest commit
        cd ../../
        sed -i '$ d' .git_log
        echo "$previous_commit: $3" >> .git_log
    fi
}

git_status() {
    cd "$(cat Repo.txt)"
    if [ ! -f ".git_repo/.git_log" ]; then
        echo "No Commits yet to check status"
        exit 1
    fi
    lc=$(wc -l .git_repo/.git_log | cut -d ' ' -f 1)
    # To keep track if there has been a change
    changes="0"
    # Check if there has been a commit to compare our working directory with
    if [ "$lc" = "0" ]; then
        echo "No Previous Commits to check status"
    else    
        # Compare between the last commit and the working directory
        previous_commit=$(cat .git_repo/.git_log | tail -n 1 | head -n 1 | cut -d ':' -f 1)
        cd "$WD"
        # For files in the working directory
        for file in *.csv; do
            if [ "${PWD}" = "${WD}" ]; then
                cd "$(cat Repo.txt)"
            fi

            # If a file is present in working directory but not the recent commit
            if [ ! -f ".git_repo/Versions/${previous_commit}/$file" ]; then
                echo "Created ${file}"
                changes="1"
                continue
            fi
            difference=$(diff ".git_repo/Versions/${previous_commit}/$file" "${WD}/$file")
            # If diff returns some non empty string, then there has been some change
            if [ -n "$difference" ]; then
                echo "${file} was changed"
                changes="1"
            fi
        done
        if [ "${PWD}" = "${WD}" ]; then
            cd "$(cat Repo.txt)"
        fi
        # For files in the recent commit to check if it is removed
        for file in .git_repo/Versions/${previous_commit}/*.csv; do
            file=$(echo "$file" | cut -d '/' -f 4)
            if [ ! -f "${WD}/$file" ]; then
                echo "Removed ${file}"
                changes="1"
            fi
        done
        # If no change, convey the same to the user
        if [ "$changes" = "0" ]; then
            echo "No Change in files with the previous commit"
        fi
    fi
}

stats() {
    # Store the operation to be done
    option="$2"

    # Read the exam marks on which the operation is going to be performed
    read -p "Do you want to perform the function on the total scores or some particular exam?:" choice
    b='0'
    a="Loop" # Variable to keep track for the termination of the below while loop
    while [ "$a" = "Loop" ]; do
        if [ "$choice" = "total" ]; then
            # Call Stats.py file to perform option on total scores
            python3 Stats.py "$option" total
            a="Done"
        else
            # Store list of exams and check if the user has inputted a valid exam name
            list_of_exams=$(ls | grep ".csv" | grep -v "main.csv" | sed 's/.csv//')
            found=$(echo "$list_of_exams" | grep "\b$choice$")
            if [ -n "$found" ]; then
                exam=$(ls | grep -i "\b$choice.csv")
                # Call Stats.py to perform option on "$exam"
                python3 Stats.py "$option" "$exam"
                a="Done"
            else
                if [ "$b" = "0" ]; then
                    echo "No Such Exam..!! List of exams:"
                    echo "------"
                    echo "$list_of_exams"
                    echo "Enter \"total\" if you want to perform the function on the total scores"
                    echo "------"
                    b="1"
                else
                    echo "No such exam!!"
                    echo "See above for list of exams"
                fi
                read -p "On which exam marks do you want to perform the operation: " choice
            fi
        fi
    done
}

# Function to display graphs
display() {
    read -p "What graph do you want to plot (histogram/stats): " option
    a="Loop"
    b='0'
    while [ "$a" = "Loop" ]; do
        case "$option" in
            histogram)
                a="Done"
                continue
                ;;
            stats)
                a="Done"
                continue
                ;;
            *)
                if [ "$b" = "0" ]; then
                    echo "Enter a Valid Graph Option"
                    echo "List of Valid options"
                    echo "1. histogram: Plots the mark of every student"
                    echo "2. stats: Plots the mean, median, std dev, min, max, third quartile"
                    b='1'
                else
                    echo "Refer above for the available graphs and choose one"
                fi
                read -p "What graph do you want to plot (histogram/stats): " option
                ;;
        esac
    done
    # Read the exam marks on which the graph is to be displayed
    read -p "Do you want to display graphs on the total scores or some particular exam?:" choice
    b='0'
    a="Loop" # Variable to keep track for the termination of the below while loop
    while [ "$a" = "Loop" ]; do
        if [ "$choice" = "total" ]; then
            # Call Graphs.py file to plot graph on total scores
            python3 Graphs.py "$option" total
            a="Done"
        else
            # Store list of exams and check if the user has inputted a valid exam name
            list_of_exams=$(ls | grep ".csv" | grep -v "main.csv" | sed 's/.csv//')
            found=$(echo "$list_of_exams" | grep "\b$choice$")
            if [ -n "$found" ]; then
                exam=$(ls | grep -i "\b$choice.csv")
                # Call Graphs.py to perform option on "$exam"
                python3 Graphs.py "$option" "$exam"
                a="Done"
            else
                if [ "$b" = "0" ]; then
                    echo "No Such Exam..!! List of exams:"
                    echo "------"
                    echo "$list_of_exams"
                    echo "Enter \"total\" if you want to perform the function on the total scores"
                    echo "------"
                    b="1"
                else
                    echo "No such exam!!"
                    echo "See above for list of exams"
                fi
                read -p "On which exam marks do you want to perform the operation: " choice
            fi
        fi
    done
}

# Main script logic
case "$1" in
    combine)
        # Check for files to combine
        file_present=$(ls | grep -v "main.csv" | grep -E ".csv")
        if [ ! -n "$file_present" ]; then
            echo "No File to Combine..!! Try Uploading Files and then combining"
            echo "Usage: \"bash submission.sh upload <path-to-csv-file>\""
            exit 1
        fi
        combine
        ;;
    upload)
        # Check for Proper Usage of command
        if [ "$#" -ne 2 ]; then
            echo "Oops! Looks like you've not used to the command how it's supposed to be"
            echo "Usage: \"bash submission.sh upload <path-to-csv-file>\""
            exit 1
        fi
        upload "$2"
        ;;
    total)
        # Check for files to combine and total
        file_present=$(ls | grep -v "main.csv" | grep -E ".csv")
        if [ ! -n "$file_present" ]; then
            echo "No File to Combine and total..!! Try Uploading Files and then combining"
            echo "Usage: \"bash submission.sh upload <path-to-csv-file>\""
            exit 1
        fi
        # Check for main.csv existence
        if [ ! -f "main.csv" ]; then
            combine
        fi
        total
        ;;
    git_init)
        # Check for Proper Usage of command
        if [ "$#" -ne 2 ]; then
            echo "Oh Oh! Try looking at the Usage to see how to use command"
            echo "Usage: \"bash submission.sh git_init <path-to-the-remote-folder>\""
            exit 1
        fi
        git_init "$@"
        ;;
    git_add)
        # Check if number of arguments is 2
        if [ "$#" -eq 1 ]; then
            echo "Enter a file name to add it"
            echo "Usage: \"bash submission.sh git_add <file-to-be-added>\""
            exit 1
        elif [ "$#" -ne 2 ]; then
            echo "Some extra arguments have been entered"
            echo "Usage: \"bash submission.sh git_add <file-to-be-added>\""
            exit 1
        fi
        git_add "$@"
        ;;
    git_commit)
        # Check if git_init was called before calling git_commit
        if [ ! -f "Repo.txt" ]; then
            echo "Initialize a Git Repository before Committing"
            echo "Usage: \"bash submission.sh git_init <path-to-the-remote-folder>\""
            exit 1
        fi

        # Check if the number of command-line arguments is 3 and the second argument is "-m"
        if [ "$#" -eq 3 ] && [ "$2" = "-m" ]; then
            git_commit "$2" "$3"
            exit 0
        fi

        echo "Usage: \"bash submission.sh git_commit -m \"<Commit-message>\"\""
        ;;
    git_checkout)
        # Check if git_init was called before calling git_checkout
        if [ ! -f "Repo.txt" ]; then
            echo "You need to commit before Checkout and Looks like you haven't initialized a git repository"
            echo "Initialize a Git Repository before Committing"
            echo "Usage: \"bash submission.sh git_init <path-to-the-remote-folder>\""
            exit 1
        fi

        cd $(cat Repo.txt)/.git_repo
        # Check if there were any previous commits
        if [ ! -f ".git_log" ]; then
            echo "You need to commit before using Checkout..!!"
            echo "Usage: \"bash submission.sh git_commit -m \"<Commit-message>\"\""
            exit 1
        fi
        
        # If Checkout is done using Commit-ID
        if [ "$#" -eq 2 ]; then
            if [ "$2" = "master" ]; then
                commit_id=$(cat .git_log | tail -n 1 | cut -d ':' -f 1)
                cd "$WD"
                rm *.csv
                cd "$(cat Repo.txt)"
                cp .git_repo/Versions/$commit_id/*.csv $WD
                echo "Checked out to master"
                exit 0
            fi
            cd "$WD"
            git_checkout "$@"
            exit 0
        fi
        # If Checkout is done using Commit message
        if [ "$#" -eq 3 ] && [ "$2" = "-m" ]; then
            cd "$WD"
            git_checkout "$@"
            exit 0
        fi

        echo "Usage: \"bash submission.sh git_checkout <Commit-id> | bash submission.sh git_checkout -m \"<Commit-message>\"\""
        ;;
    git_log)
        # Check if git_init was called before calling git_log
        if [ ! -f "Repo.txt" ]; then
            echo "Looks like there is no repository to commit and view the commit history..!!"
            echo "Try using git_init to Initialize a repository"
            echo "Usage: \"bash submission.sh git_init <path-to-the-remote-folder>\""
            exit 1
        fi

        # Check if there has been a commit
        cd $(cat Repo.txt)/.git_repo
        if [ ! -f .git_log ]; then
            echo "There hasn't been any commits"
            echo "Try commiting the current versions"
            echo "Usage: \"bash submission.sh git_commit -m \"<Commit-message>\"\""
            exit 1
        fi
        echo "Hash Value: Commit Message"
        # Prints the Hash Values with respective Commit messages
        cat .git_log
        ;;
    git_clone)
        # Check if the number of arguments is 3
        if [ "$#" -ne 3 ]; then
            echo "Usage: \"bash submission.sh git_clone <Git_repo_path> <Directory_where_cloning_to_be_done>\""
            exit 1
        fi
        git_clone "$@"
        ;;
    git_status)
        # Check if number of arguments is 1
        if [ "$#" -ne 1 ]; then
            echo "Some extra arguments typed"
            echo "Usage: \"bash submission.sh git_status\""
            exit 1
        fi
        git_status
        ;;
    git_switchrepo)
        # Check if number of arguments is 2
        if [ "$#" -ne 2 ]; then
            echo "Wrong Usage of command"
            echo "Usage: \"bash submission.sh git_switchrepo <Path-to-the-Repository\""
            exit 1
        fi
        git_switchrepo "$@"
        ;;
    git_currrepo)
        # Check if number of argument is 1
        if [ "$#" -ne 1 ]; then
            echo "Oops!! Looks like you have entered some extra arguments"
            echo "Usage: \"bash submission.sh git_currrepo\""
            exit 1
        fi
        git_currrepo
        ;;
    git_amend)
        # Check if git_init was called
        if [ ! -f "Repo.txt" ]; then
            echo "Initialise a Repository and Commit before trying to amend"
            echo "Check list function to see how to initialise and commit"
            echo "Usage: \"bash submission.sh list\""
            exit 1
        fi
        # Check if there has been a commit
        cd $(cat Repo.txt)/.git_repo
        if [ ! -f .git_log ]; then
            echo "Commit nefore trying to amend"
            echo "Usage: \"bash submission.sh git_commit -m \"<Commit-message>\"\""
            exit 1
        fi
        if [ "$#" -eq 3 ] && [ "$2" = "-m" ]; then
            cd "$WD"
            git_amend "$@"
            exit 0
        fi
        echo "Usage: \"bash submission.sh git_amend -m \"<commit-message>\"\""
        exit 1
        ;;
    update)
        update
        ;;
    list)
        list
        ;;
    stats)
        # Check if the user has typed the command as expected
        if [ "$#" -ne 2 ]; then
            echo "Uh-Oh!! Wrong Usage of command"
            echo "Usage: \"bash submission.sh stats <function-to-be-performed>\""
            exit 1
        fi
        # To be upto date with marks
        combine
        stats "$@"
        ;;
    mean)
        # Check for proper usage of command
        if [ $# -ne 1 ]; then
            echo "Some extra command line arguments are passsed!!"
            echo "Usage: \"bash submission.sh mean\""
            exit 1
        fi
        mean
        ;;
    show)
        if [ "$#" -ne 2 ]; then
            echo "Wrong usage of command!!"
            echo "Usage: \"bash submission show <roll_number>\""
            exit 1
        fi
        show "$@"
        ;;
    display)
        if [ "$#" -ne 1 ]; then
            echo "Some extra arguments have been provided!!"
            echo "Usage: \"bash submission.sh display\""
            exit 1
        fi
        combine
        display
        ;;
    *)
        echo "Invalid Command..!! Try using list function to see the list of all functions available"
        echo "Usage: \"bash submission.sh list\""
        ;;
esac