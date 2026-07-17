#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


C_KEYWORDS = {
    "auto",
    "break",
    "case",
    "char",
    "const",
    "continue",
    "default",
    "do",
    "double",
    "else",
    "enum",
    "extern",
    "float",
    "for",
    "goto",
    "if",
    "inline",
    "int",
    "long",
    "register",
    "restrict",
    "return",
    "short",
    "signed",
    "sizeof",
    "static",
    "struct",
    "switch",
    "typedef",
    "union",
    "unsigned",
    "void",
    "volatile",
    "while",
}


class Node:
    def __init__(self):
        self.directories = {}
        self.directory_names = {}
        self.files = {}


def c_identifier(name):
    identifier = re.sub(r"[^0-9A-Za-z]+", "_", name).strip("_").lower()
    identifier = re.sub(r"_+", "_", identifier)

    if not identifier:
        identifier = "asset"
    if identifier[0].isdigit():
        identifier = f"asset_{identifier}"
    if identifier in C_KEYWORDS:
        identifier = f"{identifier}_asset"

    return identifier


def c_string(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def asset_literal(relative_path):
    return f'GAME_RUNTIME_ASSET_DIR "/{c_string(relative_path)}"'


def fail(message):
    print(f"generate_game_assets.py: {message}", file=sys.stderr)
    return 1


def add_file(root, relative_path):
    parts = relative_path.split("/")
    node = root
    path_identifiers = []

    for part in parts[:-1]:
        field = c_identifier(part)
        if field in node.files:
            raise ValueError(f"directory '{'/'.join(path_identifiers + [part])}' collides with a file")
        if field in node.directory_names and node.directory_names[field] != part:
            existing = "/".join(path_identifiers + [node.directory_names[field]])
            current = "/".join(path_identifiers + [part])
            raise ValueError(f"directories '{existing}' and '{current}' map to the same C field '{field}'")
        if field not in node.directories:
            node.directories[field] = Node()
            node.directory_names[field] = part
        node = node.directories[field]
        path_identifiers.append(field)

    file_field = c_identifier(parts[-1])
    if file_field in node.directories:
        raise ValueError(f"file '{relative_path}' collides with a directory")
    if file_field in node.files and node.files[file_field] != relative_path:
        raise ValueError(
            f"files '{node.files[file_field]}' and '{relative_path}' map to the same C field '{file_field}'"
        )
    node.files[file_field] = relative_path


def collect_assets(assets_dir):
    root = Node()
    if not assets_dir.exists():
        return root

    for path in sorted(assets_dir.rglob("*")):
        if not path.is_file():
            continue

        relative = path.relative_to(assets_dir)
        parts = relative.parts
        if any(part.startswith(".") for part in parts):
            continue

        add_file(root, relative.as_posix())

    return root


def emit_struct_members(node, output, indent):
    if not node.directories and not node.files:
        output.append(f"{indent}int _unused;")
        return

    for field in sorted(node.directories):
        output.append(f"{indent}struct {{")
        emit_struct_members(node.directories[field], output, indent + "  ")
        output.append(f"{indent}}} {field};")
    for field in sorted(node.files):
        output.append(f"{indent}const char {field}[sizeof({asset_literal(node.files[field])})];")


def emit_typedef(node, output):
    output.append("typedef struct GAME_AssetPaths {")
    emit_struct_members(node, output, "  ")
    output.append("} GAME_AssetPaths;")
    output.append("")


def emit_initializer(node, output, indent):
    output.append(f"{indent}{{")
    child_indent = indent + "  "

    if not node.directories and not node.files:
        output.append(f"{child_indent}._unused = 0,")
    else:
        for field in sorted(node.directories):
            output.append(f"{child_indent}.{field} =")
            emit_initializer(node.directories[field], output, child_indent)
            output[-1] += ","
        for field in sorted(node.files):
            output.append(f"{child_indent}.{field} = {asset_literal(node.files[field])},")

    output.append(f"{indent}}}")


def write_if_changed(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets-dir", required=True, type=Path)
    parser.add_argument("--header", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--include-name", default="game_assets.h")
    args = parser.parse_args()

    try:
        root = collect_assets(args.assets_dir)
    except ValueError as error:
        return fail(str(error))

    header_lines = [
        "/* Generated by scripts/generate_game_assets.py. Do not edit. */",
        "#ifndef GAME_ASSETS_H",
        "#define GAME_ASSETS_H",
        "",
        "#ifndef GAME_RUNTIME_ASSET_DIR",
        '#define GAME_RUNTIME_ASSET_DIR "assets"',
        "#endif",
        "",
    ]
    emit_typedef(root, header_lines)
    header_lines.extend(
        [
            "extern const GAME_AssetPaths AssetPaths;",
            "",
            "#endif",
            "",
        ]
    )

    source_lines = [
        "/* Generated by scripts/generate_game_assets.py. Do not edit. */",
        f'#include "{args.include_name}"',
        "",
        "const GAME_AssetPaths AssetPaths =",
    ]
    emit_initializer(root, source_lines, "")
    source_lines[-1] += ";"
    source_lines.append("")

    write_if_changed(args.header, "\n".join(header_lines))
    write_if_changed(args.source, "\n".join(source_lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
