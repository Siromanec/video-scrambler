import csv

# Read the CSV file and remove the first 17 lines
csv_file_path = 'resource_per_entity.csv'
data = []

with open(csv_file_path, 'r') as f:
    # Skip the first 17 lines
    for _ in range(18):
        next(f)

    # Read the rest of the file
    reader = csv.reader(f)
    for row in reader:
        data.append(row)

# Process the data
flamegraph_data = []
stack = []

# Iterate over rows to collect hierarchy info and resource usage
for row in data:
    # Hierarchy node structure
    hierarchy = row[0].split("|")

    # Extract ALUTs and Block Memory Bits
    aluts = int(row[1].split('(')[0])
    block_memory_bits = int(row[3])

    # Structure the hierarchy into the flamegraph format
    if aluts > 0 or block_memory_bits > 0:
        depth = len(hierarchy[0]) // 3

        while len(stack) > depth:
            stack.pop()
        stack.append(hierarchy[1])

        node = "|".join(stack)#build from stack
        cost = f"{aluts} {block_memory_bits}"
        flamegraph_data.append((node, aluts))

# Write the flamegraph data to a file (for Shakeviz or similar tool)
with open('flamegraph_data.txt', 'w') as f:
    for node, cost in flamegraph_data:
        node = node.replace("|", "`")
        node = node.replace(":", ";")
        f.write(f"{node} {cost}\n")