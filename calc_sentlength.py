import sys

input_file = sys.argv[1]

with open(input_file) as i_f:
    for line in i_f:
        words = line.strip().split()
        print(len(words))
