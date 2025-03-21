import re
import sys

PREFIX = "rl"  # Change this to customize the prefix

if len(sys.argv) < 3:
    print("Usage: python rl_alias.py <raylib.h> <output.h>")
    sys.exit(1)

header_file = sys.argv[1]
output_file = sys.argv[2]

# Regex to match function declarations
function_regex = re.compile(r"\b(RLAPI)\s+\S+\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")

# Read header file
with open(header_file, "r") as file:
    content = file.read()

# Find all Raylib function names
functions = function_regex.findall(content)
raylib_functions = [func[1] for func in functions if not func[1].startswith("prefix")]

# Generate macro definitions
with open(output_file, "w") as file:
    file.write("// Auto-generated alias file\n\n")
    file.write("#include \"raylib.h\"\n\n")
    for func in raylib_functions:
        file.write(f"#define {PREFIX}{func} {func}\n")

print(f"Alias file generated: {output_file}")