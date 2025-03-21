import re
import sys

PREFIX = 'rl'

def parse_function(content):
    # Regex pattern to match function declarations
    pattern = r'RLAPI\s+(\w+)\s+(\w+)\((.*?)\);'
    matches = re.findall(pattern, content)
    
    generated_functions = []
    
    for return_type, func_name, args in matches:
        # Skip if args is just 'void'
        if args.strip() == 'void':
            args = ''

        if "..." in args:
            args = args.replace("...", "va_list args")
            
        # Generate the inline function
        inline_func = f"static inline {return_type} {PREFIX}{func_name}({args})\n"
        inline_func += "{\n"
        
        # Get argument names, handling pointer types correctly
        if args:
            arg_names = []
            for arg in args.split(','):
                arg = arg.strip()
                if arg:
                    # Get the last word in the argument, ignoring the '*' if it's there
                    name = arg.split()[-1].replace('*', '').replace("...", "")

                    arg_names.append(name)
            arg_list = ', '.join(arg_names)
        else:
            arg_list = ''
        
        # Add return statement if function returns something
        if return_type != 'void':
            inline_func += f"    return {func_name}({arg_list});\n"
        else:
            inline_func += f"    {func_name}({arg_list});\n"
            
        inline_func += "}\n"
        
        generated_functions.append(inline_func)
    
    return generated_functions

def main():
    if len(sys.argv) < 3:
        print("Usage: python rl_alias.py <raylib.h> <output.h>")
        sys.exit(1)

    header_file = sys.argv[1]
    output_file = sys.argv[2]

    # Read header file
    try:
        with open(header_file, "r") as file:
            content = file.read()
    except FileNotFoundError:
        print(f"Error: Could not find header file: {header_file}")
        sys.exit(1)

    # Generate functions
    generated_functions = parse_function(content)

    # Write to output file
    try:
        with open(output_file, "w") as file:
            file.write("// Auto-generated alias file\n\n")
            file.write("#include \"raylib.h\"\n\n")
            
            for func in generated_functions:
                file.write(func)
                file.write("\n")

        print(f"Alias file generated: {output_file}")
    except IOError:
        print(f"Error: Could not write to output file: {output_file}")
        sys.exit(1)

if __name__ == "__main__":
    main()
