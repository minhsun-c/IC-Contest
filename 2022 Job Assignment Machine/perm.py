import itertools

# Generate all permutations of [0,1,2,3,4,5,6,7]
perms = list(itertools.permutations(range(8)))

# Print first 5 permutations
for p in perms[:10]:
    print(*p)

