import re
import sys

if len(sys.argv) < 3:
    print("Usage: python rl_alias.py <raylib.h> <output.h> <prefix?>")
    sys.exit(1)

header_file = sys.argv[1]
output_file = sys.argv[2]
if len(sys.argv) > 3:
    prefix = sys.argv[3]
else:
    prefix = "rl"

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
    file.write("#ifndef _RL_ALIAS_H\n")
    file.write("#define _RL_ALIAS_H\n")
    file.write("#include <raylib.h>\n\n")
    for func in raylib_functions:
        file.write(f"#define {prefix}{func} {func}\n")
    file.write("#endif // _RL_ALIAS_H")

print(f"Alias file generated: {output_file}")