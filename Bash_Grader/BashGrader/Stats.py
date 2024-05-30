import pandas as pd
import numpy as np
import sys
option=sys.argv[1]
file=sys.argv[2]
if file == "total":
    # Read the contents of main.csv and store it in df
    df = pd.read_csv("main.csv")

    # Reads every row but reads only last column (total marks are stored in the last column)
    Marks = df.iloc[:, -1].values
else:
    df = pd.read_csv("main.csv")
    # Remove ".csv" from file name to get exam name
    examname = file[:-4]
    # Extracts the column whose header is examname
    Values = df[examname].tolist()
    # Every element is string. So convert it to float
    Values = [ 0 if x == 'a' else float(x) for x in Values ]
    Marks = np.array(Values, dtype=float)
a=1
b=0
while(a == 1):
    a=0    
    if option == 'mean':
        print(np.mean(Marks))
    elif option == 'median':
        print(np.median(Marks))
    elif option == 'stddev':
        print(np.std(Marks))
    elif option == 'min':
        print(np.min(Marks))
    elif option == 'max':
        print(np.max(Marks))
    elif option == 'percentile':
        while(True):  
            # If user doesn't type a number, it will go to except block
            try:
                q = float(input("Enter the percentile you want to calculate the mark: "))
                if q > 100 or q < 0:
                    print("Enter a number between 0 and 100")
                    continue
                print(np.percentile(Marks, q))
                break
            except:
                print("Enter a valid number")
    else:
        # If valid option wasn't given
        if b == 0:
            print("Oops!! Invalid option")
            print("List of Valid options:")
            print("1. mean: To calculate mean")
            print("2. median: To calculate median")
            print("3. stddev: To calculate standard deviation")
            print("4. min: To calculate the minimum mark")
            print("5. max: To calculate the maximum mark")
            print("6. percentile: To calculate the mark corresponding to a particular percentile")
            b=1
        elif b == 1:
            print("See above and enter a valid option")
        a=1
        option=input("Enter a Valid Option: ")
