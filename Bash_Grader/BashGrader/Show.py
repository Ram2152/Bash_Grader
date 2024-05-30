import csv
import sys
from tabulate import tabulate
from scipy import stats

def print_table(data):
    # Calculate the maximum length of each column
    max_lengths = [max(map(len, col)) for col in zip(*data)]
    
    # Iterate over each row in the data
    for row in data:
        # Format and print each cell in the row
        # zip(row, max_lengths) pairs each cell with its corresponding max length
        # "{:{}}" is a format specifier that allows formatting with a dynamic width
        # It ensures that each cell is printed with a width equal to the maximum width of its column
        print(" | ".join("{:{}}".format(cell, length) for cell, length in zip(row, max_lengths)))

def display_student_marks(roll_number):
    data=[] # Stores data to be displayed in the table
    Marks=[] # Stores marks to calculate percentile later
    present=0 # To calculate attendance
    total=0
    data.append(["Exam","Marks"])
    with open('main.csv', newline='') as csvfile:
        reader = csv.reader(csvfile)
        header = next(reader)  # Skip header
        for row in reader:
            row_list = list(row)
            if row_list[-1] == 'a':
                Marks.append(0)
            else:
                Marks.append(float(row_list[-1]))
            if row[0] == roll_number:
                tot_mark = float(row_list[-1])
                print("-" * 20)
                print(f"Roll Number: {row[0]}")
                print(f"Name: {row[1]}")
                print("-" * 20)
                print("Marks:")
                for exam, mark in zip(header[2:], row[2:]):
                    if mark == "a":
                        total+=1
                        data.append([exam.capitalize(), "Absent"])
                    else:
                        total+=1
                        present+=1
                        data.append([exam.capitalize(), mark])
    print(tabulate(data, headers="firstrow", tablefmt="grid", stralign=["center","right"]))
    percentile = stats.percentileofscore(Marks, tot_mark)
    print("Percentile :", percentile)
    attendance = (present-1) / (total-1) * 100
    print("Attendance : ",attendance,"%", sep="")
roll_number=sys.argv[1]
display_student_marks(roll_number)
        