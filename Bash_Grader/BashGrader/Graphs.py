import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import sys
option=sys.argv[1]
file=sys.argv[2]
if file == "total":
    # Read the contents of main.csv and store it in df
    df = pd.read_csv("main.csv")    
    # Reads every row but reads only last column (total marks are stored in the last column)
    Marks = df.iloc[:, -1].values
    # Array of Roll Number
    Roll_No = df['Roll_Number'].tolist()
else:
    df = pd.read_csv("main.csv")
    # Remove ".csv" from file name to get exam name
    examname = file[:-4]
    # Extracts the column whose header is examname
    Values = df[examname].tolist()
    # Every element is string. So convert it to float
    Values = [ 0 if x == 'a' else float(x) for x in Values ]
    Marks = np.array(Values, dtype=float)
    # Array of Roll Number
    Roll_No = df['Roll_Number'].tolist()
Len=len(Marks)
bin_size=Len//2
a=1
while(a == 1):
    a=0
    if option == "histogram":
        # Plot the histogram
        plt.hist(Marks, bins=bin_size, color='skyblue', edgecolor='black')  # Adjust the number of bins as needed
        plt.xlabel('Marks')
        plt.ylabel('Frequency')
        plt.title('Histogram of Marks')
    elif option == "stats":
        # Sample the things to be displayed
        Categories = ["Mean", "Median", "Std Dev ", "Third\nQuartile", "Min", "Max"]
        Values = [round(np.mean(Marks),2), round(np.median(Marks),2), round(np.std(Marks),2), round(np.percentile(Marks, 75),2), round(np.min(Marks),2), round(np.max(Marks),2)]

        # Ask user if he/she wants to display mark of some student along with stats to compare
        choice=input("Do you want to plot mark of some student also?(Y/n): ")
        while(True):
            if choice == "Y":
                roll_number=input("Enter the roll number of the student: ")
                while(True):
                    if roll_number in Roll_No:
                        # Extract the matching row
                        matching_row = df[df.iloc[:, 0] == roll_number]
                        # Extract the mark based on exam name 
                        if file == "total":
                            mark = matching_row["total"]
                        else:
                            mark = matching_row[examname]
                        Categories.append(roll_number)
                        # mark.iloc[0] extracts the first element of the pandas series "mark"
                        Values.append(round(float(mark.iloc[0]), 2))
                        break
                    else:
                        print("List of Roll Numbers: ")
                        print(Roll_No)
                        roll_number=input("Enter a existing roll number")
                break
            elif choice == "n":
                pass
                break
            else:
                print("Enter either \"Y\" or \"n\"")
                choice = input("")


        # Create bar chart
        bars = plt.bar(Categories, Values, color='skyblue', edgecolor='black', hatch='/')

        # Add values on top of the bars
        for bar in bars:
            height = bar.get_height()
            plt.text(bar.get_x() + bar.get_width() / 2, height, height,
                    ha='center', va='bottom')

        # Add labels and title
        plt.xlabel('Categories')
        plt.ylabel('Values')
        plt.title('Bar Chart')
    else:
        print("Enter a valid option")
        a=1

plt.tight_layout()

plt.savefig('Graph.png')

print("Graph generated successfully and is stored in Graphs.png in your folder.")
