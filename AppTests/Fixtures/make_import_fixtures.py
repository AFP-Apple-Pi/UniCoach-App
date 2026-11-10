"""Write the synthetic Files picker fixtures used by testAlphaFileImport."""
from __future__ import annotations

import argparse
from pathlib import Path


def pdf(content: bytes, raster: bytes | None = None) -> bytes:
    resources = (
        b"<< /Font << /F1 5 0 R >> >>"
        if raster is None
        else b"<< /XObject << /Im0 5 0 R >> >>"
    )
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 400] /Resources "
        + resources
        + b" /Contents 4 0 R >>",
        b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
    ]
    if raster is None:
        objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    else:
        objects.append(
            b"<< /Type /XObject /Subtype /Image /Width 8 /Height 8 /ColorSpace /DeviceGray "
            b"/BitsPerComponent 8 /Length %d >>\nstream\n" % len(raster)
            + raster
            + b"\nendstream"
        )

    result = bytearray(b"%PDF-1.4\n")
    offsets = []
    for index, entry in enumerate(objects, 1):
        offsets.append(len(result))
        result += f"{index} 0 obj\n".encode() + entry + b"\nendobj\n"
    xref = len(result)
    result += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        result += f"{offset:010} 00000 n \n".encode()
    result += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    return bytes(result)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Local folder to copy as Documents/Alpha Fixtures")
    output = parser.parse_args().output
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    fixtures = {
        "Alpha brief.txt": b"Review marker: before edit.\nDescribe how readers used the library study space.",
        "Alpha work.pdf": pdf(b"BT /F1 12 Tf 40 340 Td (Selectable PDF work fixture.) Tj ET"),
        "Alpha feedback.txt": b"Explain how your sample supports the claim.",
        "Alpha reflection.txt": b"I will check for confounders before making a claim.",
        "Alpha empty.txt": b" \n\t ",
        "Alpha invalid UTF8.txt": b"\xff\xfe\x00\x80",
        "Alpha oversized bytes.txt": b"x" * 2_000_001,
        "Alpha oversized text.txt": b"y" * 100_001,
        "Alpha scanned.pdf": pdf(b"q 240 0 0 240 40 40 cm /Im0 Do Q", bytes([0, 255] * 32)),
        "Alpha unsupported.md": b"# Imported extension must be validated.\n",
    }
    for name, data in fixtures.items():
        (output / name).write_bytes(data)


if __name__ == "__main__":
    main()
