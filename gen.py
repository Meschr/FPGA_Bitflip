from pathlib import Path

SOURCE_DIR = Path("src")
OUTPUT_FILE = Path("appendix_generated.tex")

EXTENSION_STYLES = {
    ".vhd": "vhdlstyle",
    ".py": "pythonstyle",
}

def make_label(path: Path):
    rel = path.relative_to(SOURCE_DIR)
    return "lst:" + rel.with_suffix("").as_posix().replace("/", "_").replace(" ", "_")

files = sorted(
    [f for f in SOURCE_DIR.rglob("*") if f.suffix in EXTENSION_STYLES],
    key=lambda p: p.as_posix(),
)

with OUTPUT_FILE.open("w", encoding="utf-8") as tex:

    tex.write("% Auto-generated appendix listings\n\n")
    tex.write("\\section{Source Files}\n\n")

    for file in files:
        style = EXTENSION_STYLES[file.suffix]
        label = make_label(file)

        tex.write(
            f"""\\lstinputlisting[
                style={style},
                caption={{{file.name.replace("_","\\_")}}},
                label={{{label}}}
            ]{{{file.as_posix()}}}

            """
        )

print(f"Generated {OUTPUT_FILE}")