#!/usr/bin/env python3
"""Generates assets/sample/splitmind_welcome.pdf: the bundled sample document.

Dependency-free: writes a minimal PDF 1.4 with the standard Helvetica font so
the text is selectable in the reader. Re-run after editing PAGES:

    python3 tool/generate_sample_pdf.py
"""
import os
import textwrap

PAGES = [
    (
        "Welcome to SplitMind",
        [
            "SplitMind puts your reading on one side and your thinking on the other. "
            "Select any passage in this document, then choose Explain, Summarize or "
            "Flashcards. The result appears in the AI Notes pane with a link back to "
            "the page it came from.",
            "On an unfolded iPhone Duo the two panes sit side by side. Half-fold the "
            "device like a laptop and the document moves to the top while your notes "
            "take the bottom. On a standard iPhone, tap AI Notes to slide the panel up "
            "over the page.",
            "You can also drag a selection straight into the notes pane, or use Send to "
            "AI from the selection menu. Nothing is sent until you choose an action.",
        ],
    ),
    (
        "Practice passage: how memory consolidates",
        [
            "Spaced repetition is a learning technique in which reviews of material are "
            "scheduled at increasing intervals. Each successful recall strengthens the "
            "memory trace and lengthens the time before it decays, so the next review "
            "can be pushed further into the future.",
            "The forgetting curve, first described by Hermann Ebbinghaus in 1885, shows "
            "that retention drops steeply within hours of learning and then levels off. "
            "Reviewing just before a memory would otherwise be lost produces a larger "
            "gain than reviewing material that is still fresh.",
            "Active recall amplifies the effect. Retrieving an answer from memory, "
            "rather than rereading it, forces the brain to reconstruct the knowledge. "
            "That effortful reconstruction is what makes the memory durable. Flashcards "
            "combine both ideas: they prompt recall, and a scheduler decides when each "
            "card should return.",
            "Try it: select this paragraph and tap Flashcards.",
        ],
    ),
]

WIDTH, HEIGHT, MARGIN = 612, 792, 72


def escape(text):
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def page_stream(title, paragraphs):
    ops = ["BT", "/F2 20 Tf", "%d %d Td" % (MARGIN, HEIGHT - MARGIN), "(%s) Tj" % escape(title)]
    ops += ["/F1 12 Tf", "16 TL", "0 -34 Td"]
    for para in paragraphs:
        for line in textwrap.wrap(para, 78):
            ops += ["(%s) Tj" % escape(line), "T*"]
        ops.append("T*")
    ops.append("ET")
    return "\n".join(ops).encode("latin-1")


def build():
    objects = []

    def add(body):
        objects.append(body)
        return len(objects)

    catalog = add(None)
    pages = add(None)
    regular = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    bold = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
    kids = []
    for title, paragraphs in PAGES:
        stream = page_stream(title, paragraphs)
        content = add(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
        kids.append(
            add(
                (
                    "<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] "
                    "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> >> /Contents %d 0 R >>"
                    % (pages, WIDTH, HEIGHT, regular, bold, content)
                ).encode()
            )
        )
    objects[catalog - 1] = b"<< /Type /Catalog /Pages %d 0 R >>" % pages
    objects[pages - 1] = (
        "<< /Type /Pages /Kids [%s] /Count %d >>" % (" ".join("%d 0 R" % k for k in kids), len(kids))
    ).encode()

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root %d 0 R /Info << /Title (Welcome to SplitMind) >> >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objects) + 1,
        catalog,
        xref,
    )
    return bytes(out)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = os.path.join(root, "assets", "sample", "splitmind_welcome.pdf")
    with open(target, "wb") as f:
        f.write(build())
    print("wrote", target)
